from __future__ import annotations

import argparse
from collections import defaultdict
from datetime import datetime, timezone
import hashlib
import json
import math
import os
import random
import re
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Any
import numpy as np
from PIL import Image
import imagehash
import scipy.fftpack
import yaml

CANONICAL_CLASSES: dict[int, str] = {
    0: "thrips",
    1: "whitefly",
    2: "aphids",
}

SYNONYM_MAP: dict[str, int] = {
    "thrips": 0,
    "thrip": 0,
    "frankliniella": 0,
    "thysanoptera": 0,
    "whitefly": 1,
    "whiteflies": 1,
    "white_fly": 1,
    "white-fly": 1,
    "white fly": 1,
    "bemisia": 1,
    "kutu_kebul": 1,
    "kutu-kebul": 1,
    "kutu kebul": 1,
    "aphids": 2,
    "aphid": 2,
    "aphidoidea": 2,
    "myzus": 2,
    "kutu_daun": 2,
    "kutu-daun": 2,
    "kutu daun": 2,
}

ROBOFLOW_SOURCES: tuple[dict[str, Any], ...] = (
    {
        "workspace": "puzzle-piece-detection",
        "project": "lettuce-pests",
        "version": 6,
        "format": "yolov11",
        "required": True,
    },
    {
        "workspace": "puzzle-piece-detection",
        "project": "lettuce-pest-detection",
        "version": 1,
        "format": "yolov11",
        "required": True,
    },
    {
        "workspace": "agrivision-2025",
        "project": "lettuce-pests-wieje",
        "version": 1,
        "format": "yolov11",
        "required": False,
    },
)

NEGATION_EXCLUSION_TOKENS: frozenset[str] = frozenset(
    {
        "non",
        "not",
        "no",
        "without",
        "predator",
        "parasitoid",
        "mummy",
        "healthy",
        "background",
        "negative",
        "unlabeled",
        "unknown",
        "none",
        "other",
    }
)


def _normalize_label_text(raw_name: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", raw_name.strip().lower()).strip()


_NORMALIZED_SYNONYMS: dict[str, int] = {
    _normalize_label_text(token): class_id for token, class_id in SYNONYM_MAP.items()
}

IMAGE_EXTENSIONS: frozenset[str] = frozenset({".jpg", ".jpeg", ".png", ".bmp", ".webp"})
MIN_BOX_DIMENSION: float = 0.002
_ROBOFLOW_RF_STEM_RE = re.compile(r"^(?P<base>.+?)\.rf\.[A-Za-z0-9_-]+$")
_DCT_SIGN_1D = np.array([1.0 if i % 2 == 0 else -1.0 for i in range(8)], dtype=np.float64)
_DCT_SIGN_V = _DCT_SIGN_1D[None, :]
_DCT_SIGN_U = _DCT_SIGN_1D[:, None]
_DCT_SIGN_UV = _DCT_SIGN_U * _DCT_SIGN_V
_HASH_POW2 = 1 << np.arange(63, -1, -1, dtype=np.uint64)
_MIH_5_SLICES: tuple[tuple[int, int], ...] = (
    (0, 0x1FFF),
    (13, 0x1FFF),
    (26, 0x1FFF),
    (39, 0x1FFF),
    (52, 0xFFF),
)
_POPCOUNT_LUT = np.array([bin(x).count("1") for x in range(256)], dtype=np.uint8)


def extract_roboflow_base_stem(stem_or_filename: str) -> str | None:
    lowered = stem_or_filename.lower()
    if any(lowered.endswith(ext) for ext in (*IMAGE_EXTENSIONS, ".txt")):
        stem = Path(stem_or_filename).stem
    else:
        stem = stem_or_filename
    match = _ROBOFLOW_RF_STEM_RE.match(stem)
    return match.group("base") if match else None


def compute_dihedral_phashes(img: Image.Image) -> tuple[int, ...]:
    gray32 = img.convert("RGB").convert("L").resize((32, 32), Image.Resampling.LANCZOS)
    pixels = np.asarray(gray32)
    dct = scipy.fftpack.dct(scipy.fftpack.dct(pixels, axis=0), axis=1)[:8, :8]
    dt = dct.T
    blocks = (
        dct,                # r0
        dt * _DCT_SIGN_U,   # r90
        dct * _DCT_SIGN_UV, # r180
        dt * _DCT_SIGN_V,   # r270
        dct * _DCT_SIGN_V,  # hflip
        dct * _DCT_SIGN_U,  # vflip
        dt * _DCT_SIGN_UV,  # r90 + hflip
        dt,                 # r270 + hflip
    )
    return tuple(
        int(((blk > np.median(blk)).ravel().astype(np.uint64) * _HASH_POW2).sum())
        for blk in blocks
    )


def _min_dihedral_distance(phs_a: tuple[int, ...], phs_b: tuple[int, ...]) -> int:
    r0_a = phs_a[0]
    r0_b = phs_b[0]
    return min(
        min((r0_a ^ h).bit_count() for h in phs_b),
        min((r0_b ^ h).bit_count() for h in phs_a),
    )


class _UnionFind:
    def __init__(self, size: int) -> None:
        self._parent = list(range(size))

    def find(self, idx: int) -> int:
        root = idx
        while self._parent[root] != root:
            root = self._parent[root]
        while self._parent[idx] != root:
            nxt = self._parent[idx]
            self._parent[idx] = root
            idx = nxt
        return root

    def union(self, a: int, b: int) -> None:
        ra = self.find(a)
        rb = self.find(b)
        if ra == rb:
            return
        if ra > rb:
            ra, rb = rb, ra
        self._parent[rb] = ra


class _DihedralHashIndex:
    def __init__(self, threshold: int) -> None:
        self.threshold = threshold
        self._items: list[tuple[int, ...]] = []
        self._use_mih = 0 <= threshold <= 4
        self._r0_tables: list[dict[int, list[int]]] = [defaultdict(list) for _ in _MIH_5_SLICES]
        self._all8_tables: list[dict[int, list[int]]] = [defaultdict(list) for _ in _MIH_5_SLICES]

    def add(self, phs: tuple[int, ...]) -> int:
        idx = len(self._items)
        self._items.append(phs)
        if self._use_mih:
            r0 = phs[0]
            unique_phs = set(phs)
            for slice_idx, (shift, mask) in enumerate(_MIH_5_SLICES):
                self._r0_tables[slice_idx][(r0 >> shift) & mask].append(idx)
                seen_keys: set[int] = set()
                for h in unique_phs:
                    key = (h >> shift) & mask
                    if key not in seen_keys:
                        seen_keys.add(key)
                        self._all8_tables[slice_idx][key].append(idx)
        return idx

    def _mih_candidates(self, phs_q: tuple[int, ...]) -> set[int]:
        cands: set[int] = set()
        r0_q = phs_q[0]
        unique_q = set(phs_q)
        for slice_idx, (shift, mask) in enumerate(_MIH_5_SLICES):
            r0_table = self._r0_tables[slice_idx]
            for h in unique_q:
                hits = r0_table.get((h >> shift) & mask)
                if hits:
                    cands.update(hits)
            all8_hits = self._all8_tables[slice_idx].get((r0_q >> shift) & mask)
            if all8_hits:
                cands.update(all8_hits)
        return cands

    def _numpy_matches(self, phs_q: tuple[int, ...], *, first_only: bool) -> list[int]:
        if not self._items or self.threshold < 0:
            return []
        chunk_size = 2048
        q_arr = np.asarray(phs_q, dtype=np.uint64)
        r0_q = np.uint64(phs_q[0])
        matches: list[int] = []
        total = len(self._items)
        for start in range(0, total, chunk_size):
            end = min(start + chunk_size, total)
            block = np.asarray(self._items[start:end], dtype=np.uint64)
            n = block.shape[0]
            r0_block = block[:, 0]
            xor_1 = r0_block[:, None] ^ q_arr[None, :]
            dist_1 = _POPCOUNT_LUT[xor_1.view(np.uint8).reshape(n, 8, 8)].sum(axis=-1).min(axis=-1)
            xor_2 = block ^ r0_q
            dist_2 = _POPCOUNT_LUT[xor_2.view(np.uint8).reshape(n, 8, 8)].sum(axis=-1).min(axis=-1)
            hit_indices = np.flatnonzero(np.minimum(dist_1, dist_2) <= self.threshold)
            if hit_indices.size > 0:
                if first_only:
                    return [start + int(hit_indices[0])]
                matches.extend(start + int(idx) for idx in hit_indices)
        return matches

    def find_matches(self, phs_q: tuple[int, ...]) -> list[int]:
        if self.threshold < 0 or not self._items:
            return []
        if self._use_mih:
            return [
                idx
                for idx in sorted(self._mih_candidates(phs_q))
                if _min_dihedral_distance(self._items[idx], phs_q) <= self.threshold
            ]
        return self._numpy_matches(phs_q, first_only=False)

    def has_match(self, phs_q: tuple[int, ...]) -> bool:
        if self.threshold < 0 or not self._items:
            return False
        if self._use_mih:
            for idx in self._mih_candidates(phs_q):
                if _min_dihedral_distance(self._items[idx], phs_q) <= self.threshold:
                    return True
            return False
        return bool(self._numpy_matches(phs_q, first_only=True))


@dataclass(frozen=True)
class BoxAnnotation:
    class_id: int
    cx: float
    cy: float
    w: float
    h: float

    def to_yolo_line(self) -> str:
        return f"{self.class_id} {self.cx:.6f} {self.cy:.6f} {self.w:.6f} {self.h:.6f}"


@dataclass(frozen=True)
class DatasetRecord:
    image_path: Path
    phash_hex: str
    boxes: tuple[BoxAnnotation, ...]
    source_name: str
    sha256_hex: str = ""
    group_id: str = ""
    base_stem: str = ""
    dihedral_phashes: tuple[int, ...] = ()

    @property
    def primary_class(self) -> int:
        if not self.boxes:
            return -1
        counts: dict[int, int] = {}
        for box in self.boxes:
            counts[box.class_id] = counts.get(box.class_id, 0) + 1
        return max(counts.items(), key=lambda item: (item[1], -item[0]))[0]


def canonicalize_label_name(raw_name: str) -> int | None:
    cleaned = _normalize_label_text(raw_name)
    if not cleaned:
        return None
    tokens = set(cleaned.split())
    if tokens & NEGATION_EXCLUSION_TOKENS:
        return None
    if cleaned in _NORMALIZED_SYNONYMS:
        return _NORMALIZED_SYNONYMS[cleaned]
    matched_ids = {
        class_id
        for token, class_id in _NORMALIZED_SYNONYMS.items()
        if re.search(rf"(?<![a-z0-9]){re.escape(token)}(?![a-z0-9])", cleaned)
    }
    if len(matched_ids) == 1:
        return next(iter(matched_ids))
    return None


def _clamp01(value: float) -> float:
    if not math.isfinite(value):
        raise ValueError(f"Non-finite coordinate passed to _clamp01: {value!r}")
    return max(0.0, min(1.0, value))


def parse_and_sanitize_yolo_line(
    line: str,
    source_id_to_name: dict[int, str],
) -> BoxAnnotation | None:
    parts = line.strip().split()
    if len(parts) < 5:
        return None
    try:
        raw_class_float = float(parts[0])
        if not math.isfinite(raw_class_float) or not raw_class_float.is_integer():
            return None
        raw_class_id = int(raw_class_float)
        coords = [float(val) for val in parts[1:]]
    except (ValueError, OverflowError):
        return None
    if not all(math.isfinite(c) for c in coords):
        return None

    raw_name = source_id_to_name.get(raw_class_id)
    if raw_name is None:
        return None
    canonical_id = canonicalize_label_name(raw_name)
    if canonical_id is None:
        return None

    if len(coords) == 4:
        cx, cy, w, h = coords
        x_min = _clamp01(cx - w / 2.0)
        y_min = _clamp01(cy - h / 2.0)
        x_max = _clamp01(cx + w / 2.0)
        y_max = _clamp01(cy + h / 2.0)
    elif len(coords) >= 6 and len(coords) % 2 == 0:
        xs = [_clamp01(c) for c in coords[0::2]]
        ys = [_clamp01(c) for c in coords[1::2]]
        x_min, x_max = min(xs), max(xs)
        y_min, y_max = min(ys), max(ys)
    else:
        return None

    width = x_max - x_min
    height = y_max - y_min
    if width < MIN_BOX_DIMENSION or height < MIN_BOX_DIMENSION:
        return None

    return BoxAnnotation(
        class_id=canonical_id,
        cx=(x_min + x_max) / 2.0,
        cy=(y_min + y_max) / 2.0,
        w=width,
        h=height,
    )


def load_source_class_map(dataset_dir: Path) -> dict[int, str]:
    for yaml_name in ("data.yaml", "dataset.yaml"):
        yaml_path = dataset_dir / yaml_name
        if not yaml_path.exists():
            continue
        raw_content = yaml.safe_load(yaml_path.read_text(encoding="utf-8"))
        content = {} if raw_content is None else raw_content
        if not isinstance(content, dict):
            raise ValueError(f"Invalid YAML root in {yaml_path}: expected mapping, got {type(content).__name__}")
        names = content.get("names", {})
        if isinstance(names, list):
            return {idx: str(name) for idx, name in enumerate(names)}
        if isinstance(names, dict):
            try:
                return {int(k): str(v) for k, v in names.items()}
            except (ValueError, TypeError) as exc:
                raise ValueError(f"Invalid 'names' keys in {yaml_path}: {names!r}") from exc
        raise ValueError(f"Invalid 'names' field in {yaml_path}: expected list or dict, got {type(names).__name__}")
    return dict(CANONICAL_CLASSES)


def _sanitize_text(text: str, extra_secrets: tuple[str, ...] = ()) -> str:
    sanitized = str(text)
    candidates = [
        s.strip()
        for s in (
            *extra_secrets,
            os.environ.get("ROBOFLOW_API_KEY", ""),
            os.environ.get("KAGGLE_KEY", ""),
            os.environ.get("KAGGLE_API_TOKEN", ""),
        )
        if s and s.strip()
    ]
    for secret in candidates:
        sanitized = sanitized.replace(secret, "[REDACTED]")
    sanitized = re.sub(
        r'(?i)(["\']?\b(?:api_key|roboflow_api_key|access_token|kaggle_key|kaggle_api_token|secret_key|token|secret)\b["\']?\s*[=:]\s*)(?:(["\'])(?:(?!\2).)+\2|([^\s&"\'`,;}]+))',
        lambda m: f"{m.group(1)}{m.group(2) or ''}[REDACTED]{m.group(2) or ''}",
        sanitized,
    )
    sanitized = re.sub(
        r'(?i)(["\']?\bAuthorization\b["\']?\s*:\s*["\']?\s*Bearer\s+|(?<!\w)Bearer\s+)([^\s"\'`,;}]+)',
        r"\1[REDACTED]",
        sanitized,
    )
    return sanitized


def load_env_file(env_path: Path | None = None, override: bool = False) -> list[str]:
    target = env_path if env_path is not None else (Path(__file__).resolve().parent / ".env")
    if not target.is_file():
        return []
    loaded_names: list[str] = []
    for raw_line in target.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export ") :].lstrip()
        if "=" not in line:
            continue
        key, val = line.split("=", 1)
        key = key.strip()
        val = val.strip()
        if not key:
            continue
        if len(val) >= 2 and val[0] == val[-1] and val[0] in ("'", '"'):
            val = val[1:-1]
        if override or not os.environ.get(key):
            os.environ[key] = val
            loaded_names.append(key)
    return sorted(set(loaded_names))


def _iter_source_image_label_pairs(source_dir: Path) -> list[tuple[Path, Path]]:
    pairs: list[tuple[Path, Path]] = []
    for img_path in sorted(source_dir.rglob("*")):
        if not img_path.is_file() or img_path.suffix.lower() not in IMAGE_EXTENSIONS:
            continue
        rel_parts = list(img_path.relative_to(source_dir).parts)
        if "images" in rel_parts:
            idx = len(rel_parts) - 1 - rel_parts[::-1].index("images")
            rel_parts[idx] = "labels"
            label_path = (source_dir / Path(*rel_parts)).with_suffix(".txt")
        else:
            label_path = img_path.with_suffix(".txt")
        if label_path.exists():
            pairs.append((img_path, label_path))
    return pairs


def _hamming_distance(hex_a: str, hex_b: str) -> int:
    return (int(hex_a, 16) ^ int(hex_b, 16)).bit_count()


def _classify_dropped_yolo_line(
    line: str,
    source_id_to_name: dict[int, str],
) -> tuple[str, str | None]:
    parts = line.strip().split()
    if len(parts) < 5:
        return ("invalid", None)
    try:
        raw_class_float = float(parts[0])
        if not math.isfinite(raw_class_float) or not raw_class_float.is_integer():
            return ("invalid", None)
        raw_class_id = int(raw_class_float)
    except (ValueError, OverflowError):
        return ("invalid", None)
    raw_name = source_id_to_name.get(raw_class_id)
    if raw_name is None:
        return ("unmapped", f"class_id_{raw_class_id}")
    if canonicalize_label_name(raw_name) is None:
        return ("unmapped", raw_name)
    return ("invalid", raw_name)


@dataclass(frozen=True)
class _CandidateRecord:
    image_path: Path
    phash_hex: str
    dihedral_phashes: tuple[int, ...]
    boxes: tuple[BoxAnnotation, ...]
    source_name: str
    sha256_hex: str
    base_stem: str | None
    src_entry: dict[str, Any]


def deduplicate_and_merge_sources(
    source_dirs: list[Path],
    max_hamming_distance: int = 2,
    *,
    group_hamming_distance: int = 4,
    source_details_out: dict[str, Any] | None = None,
) -> tuple[list[DatasetRecord], dict[str, int]]:
    effective_group_hamming = max(group_hamming_distance, max_hamming_distance)
    seen_sha256: set[str] = set()
    candidates: list[_CandidateRecord] = []

    stats = {
        "total_scanned": 0,
        "duplicates_removed": 0,
        "sha256_duplicates_removed": 0,
        "phash_duplicates_removed": 0,
        "empty_or_unmapped_skipped": 0,
        "boxes_kept": 0,
        "boxes_dropped": 0,
        "boxes_dropped_unmapped": 0,
        "boxes_dropped_invalid": 0,
        "groups_formed": 0,
        "roboflow_base_stems_grouped": 0,
    }
    per_source: dict[str, dict[str, Any]] = {}

    for source_dir in source_dirs:
        if not source_dir.exists():
            continue
        class_map = load_source_class_map(source_dir)
        src_entry = per_source.setdefault(
            source_dir.name,
            {
                "source_dir": str(source_dir),
                "raw_class_map": {str(k): v for k, v in sorted(class_map.items())},
                "images_scanned": 0,
                "images_kept": 0,
                "sha256_duplicates_removed": 0,
                "phash_duplicates_removed": 0,
                "empty_or_unmapped_skipped": 0,
                "unreadable_images_skipped": 0,
                "boxes_total_lines": 0,
                "boxes_kept": 0,
                "boxes_dropped": 0,
                "boxes_dropped_unmapped": 0,
                "boxes_dropped_invalid": 0,
                "mapped_class_names_seen": [],
                "unmapped_class_names_seen": [],
            },
        )
        mapped_names_seen: set[str] = set(src_entry["mapped_class_names_seen"])
        unmapped_names_seen: set[str] = set(src_entry["unmapped_class_names_seen"])

        for img_path, label_path in _iter_source_image_label_pairs(source_dir):
            stats["total_scanned"] += 1
            src_entry["images_scanned"] += 1

            raw_lines = [
                ln.strip()
                for ln in label_path.read_text(encoding="utf-8", errors="ignore").splitlines()
                if ln.strip()
            ]
            parsed_boxes: list[BoxAnnotation] = []
            for line in raw_lines:
                src_entry["boxes_total_lines"] += 1
                box = parse_and_sanitize_yolo_line(line, class_map)
                if box is not None:
                    parsed_boxes.append(box)
                    raw_cls_id = int(float(line.split()[0]))
                    if raw_cls_id in class_map:
                        mapped_names_seen.add(class_map[raw_cls_id])
                else:
                    stats["boxes_dropped"] += 1
                    src_entry["boxes_dropped"] += 1
                    reason, raw_name = _classify_dropped_yolo_line(line, class_map)
                    if reason == "unmapped":
                        stats["boxes_dropped_unmapped"] += 1
                        src_entry["boxes_dropped_unmapped"] += 1
                        if raw_name:
                            unmapped_names_seen.add(raw_name)
                    else:
                        stats["boxes_dropped_invalid"] += 1
                        src_entry["boxes_dropped_invalid"] += 1

            boxes = tuple(parsed_boxes)
            if not boxes:
                stats["empty_or_unmapped_skipped"] += 1
                src_entry["empty_or_unmapped_skipped"] += 1
                continue

            try:
                sha256_hex = hashlib.sha256(img_path.read_bytes()).hexdigest()
            except Exception:
                stats["empty_or_unmapped_skipped"] += 1
                src_entry["empty_or_unmapped_skipped"] += 1
                src_entry["unreadable_images_skipped"] += 1
                continue

            if sha256_hex in seen_sha256:
                stats["duplicates_removed"] += 1
                stats["sha256_duplicates_removed"] += 1
                src_entry["sha256_duplicates_removed"] += 1
                continue

            try:
                with Image.open(img_path) as img:
                    dihedral_phashes = compute_dihedral_phashes(img)
            except Exception:
                stats["empty_or_unmapped_skipped"] += 1
                src_entry["empty_or_unmapped_skipped"] += 1
                src_entry["unreadable_images_skipped"] += 1
                continue

            seen_sha256.add(sha256_hex)
            phash_hex = f"{dihedral_phashes[0]:016x}"
            base_stem = extract_roboflow_base_stem(img_path.stem)
            candidates.append(
                _CandidateRecord(
                    image_path=img_path,
                    phash_hex=phash_hex,
                    dihedral_phashes=dihedral_phashes,
                    boxes=boxes,
                    source_name=source_dir.name,
                    sha256_hex=sha256_hex,
                    base_stem=base_stem,
                    src_entry=src_entry,
                )
            )

        src_entry["mapped_class_names_seen"] = sorted(mapped_names_seen)
        src_entry["unmapped_class_names_seen"] = sorted(unmapped_names_seen)

    # Pass 2: Pre-dedup Union-Find over (8-dihedral pHash <= effective_group_hamming) U (.rf. base_stem)
    uf = _UnionFind(len(candidates))
    group_index = _DihedralHashIndex(effective_group_hamming)
    stem_first_idx: dict[str, int] = {}
    for idx, cand in enumerate(candidates):
        for match_idx in group_index.find_matches(cand.dihedral_phashes):
            uf.union(idx, match_idx)
        group_index.add(cand.dihedral_phashes)
        if cand.base_stem:
            existing_idx = stem_first_idx.get(cand.base_stem)
            if existing_idx is not None:
                uf.union(idx, existing_idx)
            else:
                stem_first_idx[cand.base_stem] = idx

    # Pass 3: 8-dihedral hard deduplication at <= max_hamming_distance
    merged: list[DatasetRecord] = []
    dedup_index = _DihedralHashIndex(max_hamming_distance)
    for idx, cand in enumerate(candidates):
        if dedup_index.has_match(cand.dihedral_phashes):
            stats["duplicates_removed"] += 1
            stats["phash_duplicates_removed"] += 1
            cand.src_entry["phash_duplicates_removed"] += 1
            continue

        dedup_index.add(cand.dihedral_phashes)
        stats["boxes_kept"] += len(cand.boxes)
        cand.src_entry["boxes_kept"] += len(cand.boxes)
        cand.src_entry["images_kept"] += 1
        merged.append(
            DatasetRecord(
                image_path=cand.image_path,
                phash_hex=cand.phash_hex,
                boxes=cand.boxes,
                source_name=cand.source_name,
                sha256_hex=cand.sha256_hex,
                group_id=f"grp_{uf.find(idx):06d}",
                base_stem=cand.base_stem or "",
                dihedral_phashes=cand.dihedral_phashes,
            )
        )

    stats["groups_formed"] = len({r.group_id for r in merged})
    stats["roboflow_base_stems_grouped"] = len({r.base_stem for r in merged if r.base_stem})

    if source_details_out is not None:
        source_details_out.clear()
        source_details_out.update(per_source)

    return merged, stats


def _group_primary_class(group_recs: list[DatasetRecord]) -> int:
    counts: dict[int, int] = {}
    for rec in group_recs:
        for box in rec.boxes:
            counts[box.class_id] = counts.get(box.class_id, 0) + 1
    if not counts:
        return -1
    return max(counts.items(), key=lambda item: (item[1], -item[0]))[0]


def stratified_split_records(
    records: list[DatasetRecord],
    train_ratio: float = 0.8,
    val_ratio: float = 0.1,
    seed: int = 42,
) -> dict[str, list[DatasetRecord]]:
    rng = random.Random(seed)
    grouped: dict[str, list[DatasetRecord]] = {}
    for idx, rec in enumerate(records):
        group_key = rec.group_id or rec.phash_hex or f"__idx_{idx}"
        grouped.setdefault(group_key, []).append(rec)

    by_class: dict[int, list[list[DatasetRecord]]] = {0: [], 1: [], 2: []}
    for group_recs in grouped.values():
        cls_id = _group_primary_class(group_recs)
        by_class.setdefault(cls_id, []).append(group_recs)

    splits: dict[str, list[DatasetRecord]] = {"train": [], "val": [], "test": []}
    for _, class_groups in sorted(by_class.items()):
        ordered_groups = sorted(
            class_groups,
            key=lambda g: (
                g[0].group_id or g[0].phash_hex,
                tuple(r.sha256_hex or r.phash_hex or str(r.image_path) for r in g),
            ),
        )
        rng.shuffle(ordered_groups)
        n = len(ordered_groups)
        if n == 0:
            continue
        if n >= 3:
            n_val = max(1, int(round(n * val_ratio)))
            n_test = max(1, int(round(n * (1.0 - train_ratio - val_ratio))))
            while n_val + n_test >= n:
                if n_val >= n_test and n_val > 1:
                    n_val -= 1
                elif n_test > 1:
                    n_test -= 1
                else:
                    break
            n_train = n - n_val - n_test
        else:
            n_train, n_val, n_test = n, 0, 0

        for grp in ordered_groups[:n_train]:
            splits["train"].extend(grp)
        for grp in ordered_groups[n_train : n_train + n_val]:
            splits["val"].extend(grp)
        for grp in ordered_groups[n_train + n_val :]:
            splits["test"].extend(grp)

    return splits


def export_merged_dataset(
    splits: dict[str, list[DatasetRecord]],
    output_dir: Path,
    scan_stats: dict[str, int],
) -> dict[str, Any]:
    if output_dir.exists():
        shutil.rmtree(output_dir)

    report: dict[str, Any] = {
        "classes": CANONICAL_CLASSES,
        "scan_stats": scan_stats,
        "splits": {},
    }

    for split_name, records in splits.items():
        img_out = output_dir / split_name / "images"
        lbl_out = output_dir / split_name / "labels"
        img_out.mkdir(parents=True, exist_ok=True)
        lbl_out.mkdir(parents=True, exist_ok=True)

        class_counts = {name: 0 for name in CANONICAL_CLASSES.values()}
        per_source_images: dict[str, int] = {}
        manifest_entries: list[str] = []
        small_boxes = 0
        total_boxes = 0

        for idx, rec in enumerate(records):
            id_seed = f"{rec.sha256_hex or rec.phash_hex}_{idx}"
            digest = hashlib.sha1(id_seed.encode("utf-8")).hexdigest()[:10]
            raw_base = rec.base_stem or extract_roboflow_base_stem(rec.image_path.stem)
            if raw_base:
                safe_base = re.sub(r"[^A-Za-z0-9_.-]+", "_", raw_base).lstrip(".") or "image"
                stem = f"{safe_base}.rf.{digest}"
            else:
                stem = f"{rec.source_name}_{digest}"
            target_img = img_out / f"{stem}{rec.image_path.suffix.lower()}"
            target_lbl = lbl_out / f"{stem}.txt"

            shutil.copy2(rec.image_path, target_img)
            target_lbl.write_text(
                "\n".join(b.to_yolo_line() for b in rec.boxes) + "\n",
                encoding="utf-8",
            )
            img_sha = rec.sha256_hex or hashlib.sha256(target_img.read_bytes()).hexdigest()
            manifest_entries.append(f"{target_img.name}:{img_sha}")
            per_source_images[rec.source_name] = per_source_images.get(rec.source_name, 0) + 1
            for box in rec.boxes:
                total_boxes += 1
                class_counts[CANONICAL_CLASSES[box.class_id]] += 1
                if box.w * box.h < (32.0 / 640.0) ** 2:
                    small_boxes += 1

        manifest_sha256 = hashlib.sha256("\n".join(sorted(manifest_entries)).encode("utf-8")).hexdigest()
        report["splits"][split_name] = {
            "images": len(records),
            "groups": len({r.group_id for r in records if r.group_id}) or len(records),
            "instances": total_boxes,
            "per_class_instances": class_counts,
            "per_source_images": dict(sorted(per_source_images.items())),
            "small_object_ratio": round(small_boxes / max(1, total_boxes), 4),
            "manifest_sha256": manifest_sha256,
        }

    yaml_payload = {
        "train": "train/images",
        "val": "val/images",
        "test": "test/images",
        "nc": 3,
        "names": CANONICAL_CLASSES,
    }
    (output_dir / "data.yaml").write_text(yaml.safe_dump(yaml_payload, sort_keys=False), encoding="utf-8")
    (output_dir / "dataset_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    return report


def _has_valid_source_dir(dest: Path) -> bool:
    if not dest.is_dir():
        return False
    has_yaml = (dest / "data.yaml").is_file() or (dest / "dataset.yaml").is_file()
    if not has_yaml:
        return False
    return len(_iter_source_image_label_pairs(dest)) > 0


def _count_raw_split_images(dataset_dir: Path) -> dict[str, int]:
    counts: dict[str, int] = {}
    for split_candidate in ("train", "valid", "val", "test"):
        img_dir = dataset_dir / split_candidate / "images"
        if img_dir.is_dir():
            counts[split_candidate] = sum(
                1 for p in img_dir.rglob("*") if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS
            )
    if not counts:
        counts["all"] = sum(
            1 for p in dataset_dir.rglob("*") if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS
        )
    return counts


def _extract_status_code(exc: Exception) -> int | None:
    code = getattr(exc, "status_code", None)
    if isinstance(code, int):
        return code
    match = re.search(r"\b(400|401|403|404|429|500|502|503)\b", str(exc))
    if match:
        return int(match.group(1))
    return None


def download_roboflow_sources(
    raw_root: Path,
    api_key: str | None = None,
    sources: tuple[dict[str, Any], ...] | list[dict[str, Any]] = ROBOFLOW_SOURCES,
    probe_results_out: list[dict[str, Any]] | None = None,
    env_file: Path | None = None,
    force_download: bool = False,
) -> list[Path]:
    if api_key is None and not os.environ.get("ROBOFLOW_API_KEY", "").strip():
        load_env_file(env_file)

    key = (api_key if api_key is not None else os.environ.get("ROBOFLOW_API_KEY", "")).strip()
    if not key:
        raise RuntimeError("ROBOFLOW_API_KEY is required; synthetic or local fallback is disabled.")

    from roboflow import Roboflow

    try:
        rf = Roboflow(api_key=key)
    except Exception as exc:
        raise RuntimeError(
            f"Roboflow authentication failed ({type(exc).__name__}): {_sanitize_text(str(exc), (key,))}"
        ) from None

    if getattr(rf, "onboarding", False):
        raise RuntimeError(
            "Invalid ROBOFLOW_API_KEY (Roboflow SDK entered onboarding mode); synthetic or local fallback is disabled."
        )

    raw_root.mkdir(parents=True, exist_ok=True)
    downloaded: list[Path] = []
    if probe_results_out is not None:
        probe_results_out.clear()

    for spec in sources:
        workspace = str(spec["workspace"])
        project_slug = str(spec["project"])
        version_num = int(spec["version"])
        export_format = str(spec.get("format", "yolov11"))
        required = bool(spec.get("required", True))
        slug = f"{workspace}/{project_slug}"
        dest = raw_root / f"{workspace}_{project_slug}_v{version_num}"

        used_cache = False
        try:
            if not force_download and _has_valid_source_dir(dest):
                used_cache = True
            else:
                ws = rf.workspace(workspace)
                proj = ws.project(project_slug)
                ver = proj.version(version_num)
                ver.download(export_format, location=str(dest), overwrite=True)
                if not _has_valid_source_dir(dest):
                    raise RuntimeError(
                        f"Downloaded Roboflow dataset {slug} v{version_num} lacks valid data.yaml or image/label pairs."
                    )
        except Exception as exc:
            sanitized_err = _sanitize_text(str(exc), (key,))
            status_code = _extract_status_code(exc)
            entry = {
                "workspace": workspace,
                "project": project_slug,
                "slug": slug,
                "version": version_num,
                "format": export_format,
                "required": required,
                "accessible": False,
                "status": "failed" if required else "unavailable",
                "status_code": status_code,
                "error_type": type(exc).__name__,
                "error": sanitized_err,
                "destination": str(dest),
                "raw_class_map": {},
                "raw_split_image_counts": {},
            }
            if probe_results_out is not None:
                probe_results_out.append(entry)
            if required:
                raise RuntimeError(
                    f"Required Roboflow source {slug} v{version_num} failed ({type(exc).__name__}): {sanitized_err}"
                ) from None
            continue

        raw_class_map = {str(k): v for k, v in sorted(load_source_class_map(dest).items())}
        raw_split_counts = _count_raw_split_images(dest)
        entry = {
            "workspace": workspace,
            "project": project_slug,
            "slug": slug,
            "version": version_num,
            "format": export_format,
            "required": required,
            "accessible": True,
            "status": "cached" if used_cache else "downloaded",
            "status_code": 200,
            "error_type": None,
            "error": None,
            "destination": str(dest),
            "raw_class_map": raw_class_map,
            "raw_split_image_counts": raw_split_counts,
        }
        if probe_results_out is not None:
            probe_results_out.append(entry)
        downloaded.append(dest)

    if not downloaded:
        raise RuntimeError("No Roboflow datasets were downloaded.")
    return downloaded


def verify_exported_dataset(
    output_dir: Path,
    max_hamming_distance: int = 2,
    require_all_classes: bool = False,
    group_hamming_distance: int = 4,
) -> dict[str, Any]:
    effective_group_hamming = max(group_hamming_distance, max_hamming_distance)
    violations: list[str] = []
    data_yaml_path = output_dir / "data.yaml"
    if not data_yaml_path.is_file():
        raise ValueError(f"Missing data.yaml in {output_dir}")

    raw_yaml = yaml.safe_load(data_yaml_path.read_text(encoding="utf-8"))
    yaml_data = {} if raw_yaml is None else raw_yaml
    if not isinstance(yaml_data, dict):
        violations.append(f"data.yaml must be a YAML mapping, got {type(yaml_data).__name__}")
    else:
        if "path" in yaml_data:
            violations.append(f"data.yaml must omit 'path' for portable relative resolution, got {yaml_data.get('path')!r}")
        for split_key in ("train", "val", "test"):
            expected_rel = f"{split_key}/images"
            if yaml_data.get(split_key) != expected_rel:
                violations.append(f"data.yaml {split_key} must be {expected_rel!r}, got {yaml_data.get(split_key)!r}")
        if yaml_data.get("nc") != len(CANONICAL_CLASSES):
            violations.append(f"data.yaml nc must be {len(CANONICAL_CLASSES)}, got {yaml_data.get('nc')!r}")
        raw_names = yaml_data.get("names")
        if isinstance(raw_names, dict):
            try:
                norm_names = {int(k): str(v) for k, v in raw_names.items()}
                if norm_names != CANONICAL_CLASSES:
                    violations.append(f"data.yaml names mismatch: {norm_names!r}")
            except (ValueError, TypeError):
                violations.append(f"data.yaml names has non-integer keys: {raw_names!r}")
        elif isinstance(raw_names, list):
            norm_names = {idx: str(v) for idx, v in enumerate(raw_names)}
            if norm_names != CANONICAL_CLASSES:
                violations.append(f"data.yaml names mismatch: {norm_names!r}")
        else:
            violations.append(f"data.yaml names must be a dict or list, got {type(raw_names).__name__}")

    split_sha256: dict[str, set[str]] = {}
    split_dihedral_phashes: dict[str, list[tuple[int, ...]]] = {}
    split_base_stems: dict[str, set[str]] = {}
    split_summaries: dict[str, Any] = {}
    intra_sha256_duplicates = 0
    intra_phash_duplicates = 0
    unpaired_files = 0
    invalid_labels = 0

    for split_name in ("train", "val", "test"):
        img_dir = output_dir / split_name / "images"
        lbl_dir = output_dir / split_name / "labels"
        if not img_dir.is_dir() or not lbl_dir.is_dir():
            violations.append(f"Split {split_name} missing images/ or labels/ directory")
            split_sha256[split_name] = set()
            split_dihedral_phashes[split_name] = []
            split_base_stems[split_name] = set()
            continue

        img_files = sorted(
            p for p in img_dir.iterdir() if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS
        )
        lbl_files = sorted(p for p in lbl_dir.iterdir() if p.is_file() and p.suffix.lower() == ".txt")
        if not img_files:
            violations.append(f"Split {split_name} has 0 images")

        img_by_stem: dict[str, Path] = {}
        for p in img_files:
            if p.stem in img_by_stem:
                violations.append(f"Split {split_name} duplicate image stem {p.stem}")
                unpaired_files += 1
            img_by_stem[p.stem] = p
        lbl_by_stem = {p.stem: p for p in lbl_files}

        missing_lbls = set(img_by_stem) - set(lbl_by_stem)
        extra_lbls = set(lbl_by_stem) - set(img_by_stem)
        if missing_lbls or extra_lbls:
            unpaired_files += len(missing_lbls) + len(extra_lbls)
            violations.append(
                f"Split {split_name} image/label mismatch: missing_labels={len(missing_lbls)}, extra_labels={len(extra_lbls)}"
            )

        seen_split_sha: set[str] = set()
        split_dihedral_list: list[tuple[int, ...]] = []
        intra_index = _DihedralHashIndex(max_hamming_distance)
        seen_base_stems: set[str] = set()
        per_class_instances = {name: 0 for name in CANONICAL_CLASSES.values()}
        total_boxes = 0

        for stem, img_path in sorted(img_by_stem.items()):
            lbl_path = lbl_by_stem.get(stem)
            if lbl_path is None:
                continue
            try:
                sha256_hex = hashlib.sha256(img_path.read_bytes()).hexdigest()
                with Image.open(img_path) as img:
                    dihedral_phs = compute_dihedral_phashes(img)
            except Exception as exc:
                violations.append(f"Unreadable image {img_path.name}: {exc}")
                continue

            if sha256_hex in seen_split_sha:
                intra_sha256_duplicates += 1
                violations.append(f"Intra-split SHA-256 duplicate in {split_name}: {img_path.name}")
            seen_split_sha.add(sha256_hex)

            if intra_index.has_match(dihedral_phs):
                intra_phash_duplicates += 1
                violations.append(f"Intra-split 8-dihedral pHash duplicate in {split_name}: {img_path.name}")
            intra_index.add(dihedral_phs)
            split_dihedral_list.append(dihedral_phs)

            base_stem = extract_roboflow_base_stem(img_path.stem)
            if base_stem:
                seen_base_stems.add(base_stem)

            lines = [ln.strip() for ln in lbl_path.read_text(encoding="utf-8").splitlines() if ln.strip()]
            if not lines:
                invalid_labels += 1
                violations.append(f"Empty label file {split_name}/{lbl_path.name}")
                continue
            for line in lines:
                parts = line.split()
                if len(parts) != 5:
                    invalid_labels += 1
                    violations.append(f"Invalid YOLO token count in {split_name}/{lbl_path.name}: {line!r}")
                    continue
                try:
                    cls_id = int(parts[0])
                    cx, cy, w, h = (float(parts[1]), float(parts[2]), float(parts[3]), float(parts[4]))
                except (ValueError, OverflowError):
                    invalid_labels += 1
                    violations.append(f"Non-numeric YOLO line in {split_name}/{lbl_path.name}: {line!r}")
                    continue
                if cls_id not in CANONICAL_CLASSES:
                    invalid_labels += 1
                    violations.append(f"Invalid class_id {cls_id} in {split_name}/{lbl_path.name}")
                    continue
                if not all(math.isfinite(val) for val in (cx, cy, w, h)):
                    invalid_labels += 1
                    violations.append(f"Non-finite coords in {split_name}/{lbl_path.name}")
                    continue
                if not (0.0 <= cx <= 1.0 and 0.0 <= cy <= 1.0 and MIN_BOX_DIMENSION <= w <= 1.0 and MIN_BOX_DIMENSION <= h <= 1.0):
                    invalid_labels += 1
                    violations.append(f"Out-of-bounds box in {split_name}/{lbl_path.name}: {line!r}")
                    continue
                if (cx - w / 2.0) < -1e-5 or (cx + w / 2.0) > 1.0 + 1e-5 or (cy - h / 2.0) < -1e-5 or (cy + h / 2.0) > 1.0 + 1e-5:
                    invalid_labels += 1
                    violations.append(f"Box edges exceed [0,1] in {split_name}/{lbl_path.name}: {line!r}")
                    continue
                total_boxes += 1
                per_class_instances[CANONICAL_CLASSES[cls_id]] += 1

        if require_all_classes:
            for cls_name in CANONICAL_CLASSES.values():
                if per_class_instances[cls_name] <= 0:
                    violations.append(f"Split {split_name} has 0 instances for class {cls_name!r}")

        split_sha256[split_name] = seen_split_sha
        split_dihedral_phashes[split_name] = split_dihedral_list
        split_base_stems[split_name] = seen_base_stems
        split_summaries[split_name] = {
            "images": len(img_by_stem),
            "instances": total_boxes,
            "per_class_instances": per_class_instances,
        }

    cross_split_sha256_overlaps = 0
    cross_split_phash_overlaps = 0
    cross_split_group_phash_overlaps = 0
    cross_split_base_stem_overlaps = 0
    for left, right in (("train", "val"), ("train", "test"), ("val", "test")):
        sha_overlap = split_sha256[left] & split_sha256[right]
        if sha_overlap:
            cross_split_sha256_overlaps += len(sha_overlap)
            violations.append(f"Cross-split SHA-256 overlap between {left} and {right}: {len(sha_overlap)}")

        right_dedup_idx = _DihedralHashIndex(max_hamming_distance)
        for rp in split_dihedral_phashes[right]:
            right_dedup_idx.add(rp)
        phash_matches = sum(1 for lp in split_dihedral_phashes[left] if right_dedup_idx.has_match(lp))
        if phash_matches:
            cross_split_phash_overlaps += phash_matches
            violations.append(
                f"Cross-split 8-dihedral pHash (<= {max_hamming_distance}) overlap between {left} and {right}: {phash_matches}"
            )

        right_group_idx = _DihedralHashIndex(effective_group_hamming)
        for rp in split_dihedral_phashes[right]:
            right_group_idx.add(rp)
        group_phash_matches = sum(1 for lp in split_dihedral_phashes[left] if right_group_idx.has_match(lp))
        if group_phash_matches:
            cross_split_group_phash_overlaps += group_phash_matches
            violations.append(
                f"Cross-split 8-dihedral group pHash (<= {effective_group_hamming}) overlap between {left} and {right}: {group_phash_matches}"
            )

        stem_overlap = split_base_stems[left] & split_base_stems[right]
        if stem_overlap:
            cross_split_base_stem_overlaps += len(stem_overlap)
            violations.append(f"Cross-split Roboflow base-stem overlap between {left} and {right}: {len(stem_overlap)}")

    all_classes_present = all(
        split_summaries.get(split_name, {}).get("per_class_instances", {}).get(cls_name, 0) > 0
        for split_name in ("train", "val", "test")
        for cls_name in CANONICAL_CLASSES.values()
    )

    if not violations:
        try:
            from ultralytics.data.utils import check_det_dataset

            resolved_cfg = check_det_dataset(str(data_yaml_path), autodownload=False)
            for split_key in ("train", "val", "test"):
                expected_dir = (output_dir / split_key / "images").resolve()
                if Path(resolved_cfg[split_key]).resolve() != expected_dir:
                    violations.append(
                        f"Ultralytics check_det_dataset resolved {split_key} to {resolved_cfg[split_key]!r}, expected {str(expected_dir)!r}"
                    )
        except ImportError:
            pass

    if violations:
        raise ValueError("Dataset verification failed:\n- " + "\n- ".join(violations[:20]))

    return {
        "status": "passed",
        "data_yaml_path_omitted": True,
        "data_yaml_portable_relative_paths": True,
        "cross_split_sha256_overlaps": cross_split_sha256_overlaps,
        "cross_split_phash_overlaps": cross_split_phash_overlaps,
        "cross_split_group_phash_overlaps": cross_split_group_phash_overlaps,
        "cross_split_base_stem_overlaps": cross_split_base_stem_overlaps,
        "group_hamming_distance": effective_group_hamming,
        "dihedral_orientations_checked": 8,
        "intra_split_sha256_duplicates": intra_sha256_duplicates,
        "intra_split_phash_duplicates": intra_phash_duplicates,
        "unpaired_files": unpaired_files,
        "invalid_labels": invalid_labels,
        "all_canonical_classes_present_in_all_splits": all_classes_present,
        "splits": split_summaries,
    }


def write_provenance_reports(
    report_dir: Path,
    output_dir: Path,
    probe_results: list[dict[str, Any]],
    scan_stats: dict[str, int],
    source_details: dict[str, Any],
    export_report: dict[str, Any],
    verification_result: dict[str, Any],
    *,
    max_hamming_distance: int,
    seed: int,
    train_ratio: float,
    val_ratio: float,
    group_hamming_distance: int = 4,
) -> tuple[Path, Path]:
    report_dir.mkdir(parents=True, exist_ok=True)
    effective_group_hamming = max(group_hamming_distance, max_hamming_distance)
    total_images = sum(v["images"] for v in export_report["splits"].values())
    total_instances = sum(v["instances"] for v in export_report["splits"].values())
    total_per_class = {
        cls_name: sum(split_info["per_class_instances"][cls_name] for split_info in export_report["splits"].values())
        for cls_name in CANONICAL_CLASSES.values()
    }

    provenance_payload: dict[str, Any] = {
        "generated_at_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "zero_synthetic_confirmed": True,
        "synthetic_images_count": 0,
        "canonical_classes": {str(k): v for k, v in CANONICAL_CLASSES.items()},
        "split_config": {
            "train_ratio": train_ratio,
            "val_ratio": val_ratio,
            "test_ratio": round(1.0 - train_ratio - val_ratio, 4),
            "seed": seed,
            "max_hamming_distance": max_hamming_distance,
            "group_hamming_distance": effective_group_hamming,
            "dihedral_orientations_checked": 8,
            "group_aware_split": True,
        },
        "sources_probed": probe_results,
        "deduplication": {
            **scan_stats,
            "per_source_details": source_details,
        },
        "splits": export_report["splits"],
        "totals": {
            "images": total_images,
            "instances": total_instances,
            "per_class_instances": total_per_class,
        },
        "verification": verification_result,
    }

    json_text = _sanitize_text(json.dumps(provenance_payload, indent=2))
    md_lines = [
        "# HidroSense Lettuce Pests Dataset Provenance",
        "",
        f"- **Generated (UTC)**: `{provenance_payload['generated_at_utc']}`",
        f"- **Zero Synthetic Confirmed**: `{provenance_payload['zero_synthetic_confirmed']}` (`synthetic_images_count = 0`)",
        f"- **Canonical Classes**: `0: thrips`, `1: whitefly`, `2: aphids`",
        f"- **Split Config**: `train={train_ratio}`, `val={val_ratio}`, `test={provenance_payload['split_config']['test_ratio']}`, `seed={seed}`, `phash_hamming_threshold={max_hamming_distance}`, `group_hamming_threshold={effective_group_hamming}`, `group_aware_split=True`",
        "",
        "## Roboflow Sources Probed & Downloaded",
        "",
        "| Workspace / Project | Version | Required | Status | HTTP / Error | Raw Split Images | Raw Classes |",
        "|---|---:|---|---|---|---|---|",
    ]
    for src in probe_results:
        http_info = str(src.get("status_code") or "-")
        if src.get("error"):
            http_info = f"{http_info} ({src['error_type']}: {src['error']})"
        raw_splits_str = ", ".join(f"{k}:{v}" for k, v in src.get("raw_split_image_counts", {}).items()) or "-"
        raw_cls_str = ", ".join(f"{k}:{v}" for k, v in src.get("raw_class_map", {}).items()) or "-"
        md_lines.append(
            f"| `{src['slug']}` | {src['version']} | {src['required']} | `{src['status']}` | {http_info} | {raw_splits_str} | {raw_cls_str} |"
        )

    md_lines.extend(
        [
            "",
            "## Class Mapping & Deduplication Summary",
            "",
            f"- **Total images scanned**: {scan_stats['total_scanned']}",
            f"- **Exact SHA-256 duplicates removed**: {scan_stats['sha256_duplicates_removed']}",
            f"- **8-dihedral perceptual hash (Hamming <= {max_hamming_distance}) duplicates removed**: {scan_stats['phash_duplicates_removed']}",
            f"- **Total duplicates removed**: {scan_stats['duplicates_removed']}",
            f"- **Dihedral orientations checked**: {verification_result.get('dihedral_orientations_checked', 8)}",
            f"- **Group Hamming threshold**: {effective_group_hamming}",
            f"- **Connected component groups formed**: {scan_stats.get('groups_formed', 0)}",
            f"- **Roboflow base stems grouped**: {scan_stats.get('roboflow_base_stems_grouped', 0)}",
            f"- **Empty or unmapped images skipped**: {scan_stats['empty_or_unmapped_skipped']}",
            f"- **Boxes kept**: {scan_stats['boxes_kept']}",
            f"- **Boxes dropped (total / unmapped / invalid)**: {scan_stats['boxes_dropped']} / {scan_stats['boxes_dropped_unmapped']} / {scan_stats['boxes_dropped_invalid']}",
            "",
            "| Source Dir | Scanned | Kept | SHA-256 Dup | pHash Dup | Empty/Unmapped | Boxes Kept | Boxes Dropped (Unmapped / Invalid) |",
            "|---|---:|---:|---:|---:|---:|---:|---|",
        ]
    )
    for src_name, det in source_details.items():
        md_lines.append(
            f"| `{src_name}` | {det['images_scanned']} | {det['images_kept']} | {det['sha256_duplicates_removed']} | {det['phash_duplicates_removed']} | {det['empty_or_unmapped_skipped']} | {det['boxes_kept']} | {det['boxes_dropped']} ({det['boxes_dropped_unmapped']} / {det['boxes_dropped_invalid']}) |"
        )

    md_lines.extend(
        [
            "",
            "## Final Split Counts & Class Distribution",
            "",
            "| Split | Images | Groups | Instances | thrips | whitefly | aphids | Small Obj Ratio | Manifest SHA-256 (prefix) |",
            "|---|---:|---:|---:|---:|---:|---:|---:|---|",
        ]
    )
    for split_name in ("train", "val", "test"):
        sp = export_report["splits"][split_name]
        pci = sp["per_class_instances"]
        md_lines.append(
            f"| `{split_name}` | {sp['images']} | {sp.get('groups', sp['images'])} | {sp['instances']} | {pci['thrips']} | {pci['whitefly']} | {pci['aphids']} | {sp['small_object_ratio']} | `{sp['manifest_sha256'][:12]}` |"
        )
    total_groups = sum(v.get("groups", v["images"]) for v in export_report["splits"].values())
    md_lines.append(
        f"| **Total** | **{total_images}** | **{total_groups}** | **{total_instances}** | **{total_per_class['thrips']}** | **{total_per_class['whitefly']}** | **{total_per_class['aphids']}** | - | - |"
    )

    md_lines.extend(
        [
            "",
            "## Split Integrity & Leakage Verification",
            "",
            f"- **Status**: `{verification_result['status']}`",
            f"- **`data.yaml` portable relative paths (`path` omitted)**: `{verification_result['data_yaml_path_omitted']}`",
            f"- **Dihedral orientations checked**: `{verification_result.get('dihedral_orientations_checked', 8)}`",
            f"- **Cross-split SHA-256 overlaps**: `{verification_result['cross_split_sha256_overlaps']}`",
            f"- **Cross-split 8-dihedral pHash (<= {max_hamming_distance}) overlaps**: `{verification_result['cross_split_phash_overlaps']}`",
            f"- **Cross-split 8-dihedral group pHash (<= {effective_group_hamming}) overlaps**: `{verification_result.get('cross_split_group_phash_overlaps', 0)}`",
            f"- **Cross-split Roboflow base-stem overlaps**: `{verification_result.get('cross_split_base_stem_overlaps', 0)}`",
            f"- **Intra-split SHA-256 / 8-dihedral pHash duplicates**: `{verification_result['intra_split_sha256_duplicates']}` / `{verification_result['intra_split_phash_duplicates']}`",
            f"- **Unpaired files / invalid labels**: `{verification_result['unpaired_files']}` / `{verification_result['invalid_labels']}`",
            f"- **All canonical classes present in every split**: `{verification_result['all_canonical_classes_present_in_all_splits']}`",
        ]
    )
    md_text = _sanitize_text("\n".join(md_lines) + "\n")

    json_path = report_dir / "dataset_provenance.json"
    md_path = report_dir / "dataset_provenance.md"
    json_path.write_text(json_text, encoding="utf-8")
    md_path.write_text(md_text, encoding="utf-8")
    (output_dir / "dataset_provenance.json").write_text(json_text, encoding="utf-8")
    return json_path, md_path


def _build_sources_from_args(args: argparse.Namespace) -> tuple[dict[str, Any], ...]:
    return (
        {
            "workspace": "puzzle-piece-detection",
            "project": "lettuce-pests",
            "version": args.lettuce_pests_version,
            "format": "yolov11",
            "required": True,
        },
        {
            "workspace": "puzzle-piece-detection",
            "project": "lettuce-pest-detection",
            "version": args.lettuce_pest_detection_version,
            "format": "yolov11",
            "required": True,
        },
        {
            "workspace": "agrivision-2025",
            "project": "lettuce-pests-wieje",
            "version": args.wieje_version,
            "format": "yolov11",
            "required": False,
        },
    )


def main(argv: list[str] | None = None) -> dict[str, Any]:
    parser = argparse.ArgumentParser(description="Download, deduplicate, split, and verify real Roboflow lettuce pest datasets.")
    parser.add_argument("--raw-root", type=Path, default=Path("ml/data/raw_roboflow"))
    parser.add_argument("--output-dir", type=Path, default=Path("ml/data/merged_lettuce_pests"))
    parser.add_argument("--report-dir", type=Path, default=Path("ml/reports"))
    parser.add_argument("--env-file", type=Path, default=Path("ml/.env"))
    parser.add_argument("--max-hamming-distance", type=int, default=2)
    parser.add_argument("--group-hamming-distance", type=int, default=4)
    parser.add_argument("--train-ratio", type=float, default=0.8)
    parser.add_argument("--val-ratio", type=float, default=0.1)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--force-download", action="store_true")
    parser.add_argument("--lettuce-pests-version", type=int, default=6)
    parser.add_argument("--lettuce-pest-detection-version", type=int, default=1)
    parser.add_argument("--wieje-version", type=int, default=1)
    args = parser.parse_args(argv)

    if not (0.0 < args.train_ratio < 1.0 and 0.0 < args.val_ratio < 1.0 and args.train_ratio + args.val_ratio < 1.0):
        raise ValueError("train_ratio and val_ratio must be in (0, 1) and sum to < 1.0")

    sources = _build_sources_from_args(args)
    probe_results: list[dict[str, Any]] = []
    source_dirs = download_roboflow_sources(
        raw_root=args.raw_root,
        sources=sources,
        probe_results_out=probe_results,
        env_file=args.env_file,
        force_download=args.force_download,
    )

    source_details: dict[str, Any] = {}
    records, scan_stats = deduplicate_and_merge_sources(
        source_dirs=source_dirs,
        max_hamming_distance=args.max_hamming_distance,
        group_hamming_distance=args.group_hamming_distance,
        source_details_out=source_details,
    )
    if not records:
        raise RuntimeError("No valid records remained after deduplication and class filtering.")

    splits = stratified_split_records(
        records=records,
        train_ratio=args.train_ratio,
        val_ratio=args.val_ratio,
        seed=args.seed,
    )
    export_report = export_merged_dataset(
        splits=splits,
        output_dir=args.output_dir,
        scan_stats=scan_stats,
    )
    verification_result = verify_exported_dataset(
        output_dir=args.output_dir,
        max_hamming_distance=args.max_hamming_distance,
        require_all_classes=True,
        group_hamming_distance=args.group_hamming_distance,
    )
    json_path, md_path = write_provenance_reports(
        report_dir=args.report_dir,
        output_dir=args.output_dir,
        probe_results=probe_results,
        scan_stats=scan_stats,
        source_details=source_details,
        export_report=export_report,
        verification_result=verification_result,
        max_hamming_distance=args.max_hamming_distance,
        seed=args.seed,
        train_ratio=args.train_ratio,
        val_ratio=args.val_ratio,
        group_hamming_distance=args.group_hamming_distance,
    )
    return {
        "provenance_json": str(json_path),
        "provenance_md": str(md_path),
        "output_dir": str(args.output_dir),
        "totals": {
            "images": sum(v["images"] for v in export_report["splits"].values()),
            "instances": sum(v["instances"] for v in export_report["splits"].values()),
        },
        "verification": verification_result,
    }


if __name__ == "__main__":
    summary = main()
    print(json.dumps(summary, indent=2))
