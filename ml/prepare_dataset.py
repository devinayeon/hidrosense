from __future__ import annotations

import argparse
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import io
import json
import math
import os
from pathlib import Path
import random
import re
import shutil
import subprocess
import sys
from typing import Any
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit
import zipfile

import numpy as np
from PIL import Image
import requests
import scipy.fftpack
import yaml

from ml.ood_negatives import OOD_CATEGORIES, prepare_coco_ood_negatives
from ml.visual_pipeline import compute_image_visual_profile, export_visual_pipeline_manifest

CANONICAL_CLASSES: dict[int, str] = {
    0: "whitefly",
    1: "aphids",
}

SYNONYM_MAP: dict[str, int] = {
    "whitefly": 0,
    "whiteflies": 0,
    "white_fly": 0,
    "white-fly": 0,
    "white fly": 0,
    "bemisia": 0,
    "kutu_kebul": 0,
    "kutu-kebul": 0,
    "kutu kebul": 0,
    "aphids": 1,
    "aphid": 1,
    "aphidoidea": 1,
    "myzus": 1,
    "kutu_daun": 1,
    "kutu-daun": 1,
    "kutu daun": 1,
}

EXCLUDED_CLASS_NAMES: frozenset[str] = frozenset(
    {
        "molted skin",
        "molted_skin",
        "molted-skin",
        "molted",
        "moulted skin",
        "exuviae",
        "cast skin",
        "thrips",
        "thrip",
        "frankliniella",
        "thysanoptera",
    }
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
        "molted",
        "moulted",
        "exuviae",
    }
)

ROBOFLOW_DIRECT_SOURCES: tuple[dict[str, Any], ...] = (
    {
        "name": "whitefly_0tong_v1",
        "slug": "jini-nkjjt/whitefly-0tong",
        "version": 1,
        "dataset_id": "rOfgg1CNHN",
        "env_url_key": "ROBOFLOW_WHITEFLY_URL",
        "required": True,
    },
    {
        "name": "aphids_new_v1",
        "slug": "jiwons-workspace-syfav/aphids-new",
        "version": 1,
        "dataset_id": "PaVtWyiDBO",
        "env_url_key": "ROBOFLOW_APHIDS_URL",
        "required": True,
    },
)

DEFAULT_KAGGLE_DATASET_SLUG = "adityadwiferdiansyah/hidrosense-whitefly-aphids-v2"


def _normalize_label_text(raw_name: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", raw_name.strip().lower()).strip()


_NORMALIZED_SYNONYMS: dict[str, int] = {
    _normalize_label_text(token): class_id for token, class_id in SYNONYM_MAP.items()
}
_NORMALIZED_EXCLUDED: frozenset[str] = frozenset(_normalize_label_text(x) for x in EXCLUDED_CLASS_NAMES)
_MOLTED_SKIN_LABELS: frozenset[str] = frozenset(
    _normalize_label_text(x)
    for x in ("molted skin", "molted_skin", "molted-skin", "molted", "moulted skin", "exuviae", "cast skin")
)

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
        dct,
        dt * _DCT_SIGN_U,
        dct * _DCT_SIGN_UV,
        dt * _DCT_SIGN_V,
        dct * _DCT_SIGN_V,
        dct * _DCT_SIGN_U,
        dt * _DCT_SIGN_UV,
        dt,
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
    negative_kind: str = ""

    @property
    def primary_class(self) -> int:
        if not self.boxes:
            return -1
        counts: dict[int, int] = {}
        for box in self.boxes:
            counts[box.class_id] = counts.get(box.class_id, 0) + 1
        return max(counts.items(), key=lambda item: (item[1], -item[0]))[0]

    @property
    def stratum_key(self) -> str:
        if self.boxes:
            return f"pos_{self.primary_class}"
        return f"neg_{self.negative_kind or 'background'}"


def is_molted_skin_label(raw_name: str) -> bool:
    cleaned = _normalize_label_text(raw_name)
    return cleaned in _MOLTED_SKIN_LABELS or "molted" in cleaned.split() or "exuviae" in cleaned.split()


def canonicalize_label_name(raw_name: str) -> int | None:
    cleaned = _normalize_label_text(raw_name)
    if not cleaned or cleaned in _NORMALIZED_EXCLUDED:
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
            raise ValueError(f"Invalid YAML root in {yaml_path}: expected mapping")
        names = content.get("names", {})
        if isinstance(names, list):
            return {idx: str(name) for idx, name in enumerate(names)}
        if isinstance(names, dict):
            return {int(k): str(v) for k, v in names.items()}
        raise ValueError(f"Invalid 'names' field in {yaml_path}")
    return dict(CANONICAL_CLASSES)


def _sanitize_text(text: str, extra_secrets: tuple[str, ...] = ()) -> str:
    sanitized = str(text)
    env_secrets: list[str] = []
    for k in ("ROBOFLOW_API_KEY", "KAGGLE_KEY", "KAGGLE_API_TOKEN", "ROBOFLOW_WHITEFLY_URL", "ROBOFLOW_APHIDS_URL"):
        val = os.environ.get(k, "").strip()
        if val:
            if "key=" in val:
                for qk, qv in parse_qsl(urlsplit(val).query):
                    if qk.lower() in {"key", "api_key", "token"} and qv:
                        env_secrets.append(qv)
            else:
                env_secrets.append(val)
    for secret in (*extra_secrets, *env_secrets):
        if secret and secret.strip():
            sanitized = sanitized.replace(secret.strip(), "[REDACTED]")
    sanitized = re.sub(r"([?&](?:key|api_key|token)=)[^&\s\"'`]+", r"\1[REDACTED]", sanitized, flags=re.IGNORECASE)
    sanitized = re.sub(r"(?i)\b(Bearer[ \t]+)[A-Za-z0-9._\-+/=]+", r"\1[REDACTED]", sanitized)
    sanitized = re.sub(
        r'(?i)(["\']?\b(?:api_key|roboflow_api_key|access_token|kaggle_key|kaggle_api_token|secret_key|token|secret)\b["\']?\s*[=:]\s*)(?:(["\'])(?:(?!\2).)+\2|([^\s&"\'`,;}]+))',
        lambda m: f"{m.group(1)}{m.group(2) or ''}[REDACTED]{m.group(2) or ''}",
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
        key, val = key.strip(), val.strip()
        if not key:
            continue
        if len(val) >= 2 and val[0] == val[-1] and val[0] in ("'", '"'):
            val = val[1:-1]
        if override or not os.environ.get(key):
            os.environ[key] = val
            loaded_names.append(key)
    return sorted(set(loaded_names))


def normalize_roboflow_ds_url(raw_url: str) -> tuple[str, str]:
    """Convert universe.roboflow.com/ds/<id>?key=<k> to app.roboflow.com/ds/<id>?key=<k> and return (url, key)."""
    parts = urlsplit(raw_url.strip())
    qdict = dict(parse_qsl(parts.query, keep_blank_values=True))
    secret_key = qdict.get("key", "").strip()
    if not secret_key:
        raise ValueError("Roboflow dataset direct link must include ?key= parameter in .env or environment.")
    host = "app.roboflow.com" if parts.netloc.lower() in {"universe.roboflow.com", "app.roboflow.com"} else parts.netloc
    clean_query = urlencode(qdict)
    return urlunsplit((parts.scheme or "https", host, parts.path, clean_query, "")), secret_key


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
        coords = [float(v) for v in parts[1:]]
        if not all(math.isfinite(c) for c in coords):
            return ("invalid", None)
    except (ValueError, OverflowError):
        return ("invalid", None)
    raw_name = source_id_to_name.get(raw_class_id)
    if raw_name is None:
        return ("unmapped", f"class_id_{raw_class_id}")
    if is_molted_skin_label(raw_name):
        return ("molted_skin", raw_name)
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
    negative_kind: str
    src_entry: dict[str, Any]


def deduplicate_and_merge_sources(
    source_dirs: list[Path],
    max_hamming_distance: int = 2,
    *,
    group_hamming_distance: int = 4,
    keep_negatives: bool = True,
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
        "negative_images_kept": 0,
        "molted_skin_boxes_removed": 0,
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
                "negative_images_kept": 0,
                "sha256_duplicates_removed": 0,
                "phash_duplicates_removed": 0,
                "empty_or_unmapped_skipped": 0,
                "unreadable_images_skipped": 0,
                "boxes_total_lines": 0,
                "boxes_kept": 0,
                "boxes_dropped": 0,
                "molted_skin_boxes_removed": 0,
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
            had_invalid_line = False
            had_molted_line = False
            had_unmapped_line = False

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
                    if reason == "molted_skin":
                        had_molted_line = True
                        stats["molted_skin_boxes_removed"] += 1
                        src_entry["molted_skin_boxes_removed"] += 1
                        stats["boxes_dropped_unmapped"] += 1
                        src_entry["boxes_dropped_unmapped"] += 1
                        if raw_name:
                            unmapped_names_seen.add(raw_name)
                    elif reason == "unmapped":
                        had_unmapped_line = True
                        stats["boxes_dropped_unmapped"] += 1
                        src_entry["boxes_dropped_unmapped"] += 1
                        if raw_name:
                            unmapped_names_seen.add(raw_name)
                    else:
                        had_invalid_line = True
                        stats["boxes_dropped_invalid"] += 1
                        src_entry["boxes_dropped_invalid"] += 1

            boxes = tuple(parsed_boxes)
            negative_kind = ""
            if not boxes:
                if had_invalid_line or had_unmapped_line or not keep_negatives:
                    stats["empty_or_unmapped_skipped"] += 1
                    src_entry["empty_or_unmapped_skipped"] += 1
                    continue
                if had_molted_line:
                    negative_kind = "molted_skin_only"
                elif source_dir.name in OOD_CATEGORIES:
                    negative_kind = source_dir.name
                else:
                    negative_kind = "leaf_empty"

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
                    negative_kind=negative_kind,
                    src_entry=src_entry,
                )
            )

        src_entry["mapped_class_names_seen"] = sorted(mapped_names_seen)
        src_entry["unmapped_class_names_seen"] = sorted(unmapped_names_seen)

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
        if not cand.boxes:
            stats["negative_images_kept"] += 1
            cand.src_entry["negative_images_kept"] += 1
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
                negative_kind=cand.negative_kind,
            )
        )

    stats["groups_formed"] = len({r.group_id for r in merged})
    stats["roboflow_base_stems_grouped"] = len({r.base_stem for r in merged if r.base_stem})

    if source_details_out is not None:
        source_details_out.clear()
        source_details_out.update(per_source)

    return merged, stats


def _group_stratum(group_recs: list[DatasetRecord]) -> str:
    counts: dict[int, int] = {}
    for rec in group_recs:
        for box in rec.boxes:
            counts[box.class_id] = counts.get(box.class_id, 0) + 1
    if counts:
        primary = max(counts.items(), key=lambda item: (item[1], -item[0]))[0]
        return f"pos_{primary}"
    neg_counts: dict[str, int] = {}
    for rec in group_recs:
        nk = rec.negative_kind or "leaf_empty"
        neg_counts[nk] = neg_counts.get(nk, 0) + 1
    best_neg = max(neg_counts.items(), key=lambda item: (item[1], item[0]))[0]
    return f"neg_{best_neg}"


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

    by_stratum: dict[str, list[list[DatasetRecord]]] = {}
    for group_recs in grouped.values():
        by_stratum.setdefault(_group_stratum(group_recs), []).append(group_recs)

    splits: dict[str, list[DatasetRecord]] = {"train": [], "val": [], "test": []}
    for stratum_key, stratum_groups in sorted(by_stratum.items()):
        ordered_groups = sorted(
            stratum_groups,
            key=lambda g: (
                g[0].group_id or g[0].phash_hex,
                tuple(r.sha256_hex or r.phash_hex or str(r.image_path) for r in g),
            ),
        )
        rng.shuffle(ordered_groups)
        n = len(ordered_groups)
        if n == 0:
            continue
        # Give OOD negative strata at least 20% in held-out test when abundant so real-life OOD evaluation is thorough
        is_ood = stratum_key.startswith("neg_ood_")
        eff_val_ratio = 0.15 if is_ood and n >= 10 else val_ratio
        eff_test_ratio = 0.20 if is_ood and n >= 10 else max(0.0, 1.0 - train_ratio - val_ratio)

        if n >= 3:
            n_val = max(1, int(round(n * eff_val_ratio)))
            n_test = max(1, int(round(n * eff_test_ratio)))
            while n_val + n_test >= n:
                if n_val >= n_test and n_val > 1:
                    n_val -= 1
                elif n_test > 1:
                    n_test -= 1
                else:
                    break
            n_train = n - n_val - n_test
        elif n == 2:
            n_train, n_val, n_test = 1, 0, 1
        else:
            n_train, n_val, n_test = 1, 0, 0

        for grp in ordered_groups[:n_train]:
            splits["train"].extend(grp)
        for grp in ordered_groups[n_train : n_train + n_val]:
            splits["val"].extend(grp)
        for grp in ordered_groups[n_train + n_val :]:
            splits["test"].extend(grp)

    return splits


def _compute_count_quantiles(counts: list[int]) -> dict[str, int]:
    if not counts:
        return {"images": 0, "p50": 0, "p75": 0, "p90": 0, "max": 0}
    arr = np.asarray(sorted(counts), dtype=np.float64)
    return {
        "images": len(counts),
        "p50": max(1, int(round(float(np.percentile(arr, 50))))),
        "p75": max(2, int(round(float(np.percentile(arr, 75))))),
        "p90": max(3, int(round(float(np.percentile(arr, 90))))),
        "max": int(arr[-1]),
    }


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
        "train_count_quantiles": {},
    }

    train_per_image_counts: dict[str, list[int]] = {name: [] for name in CANONICAL_CLASSES.values()}

    for split_name, records in splits.items():
        img_out = output_dir / split_name / "images"
        lbl_out = output_dir / split_name / "labels"
        img_out.mkdir(parents=True, exist_ok=True)
        lbl_out.mkdir(parents=True, exist_ok=True)

        class_counts = {name: 0 for name in CANONICAL_CLASSES.values()}
        negative_breakdown: dict[str, int] = {}
        per_source_images: dict[str, int] = {}
        manifest_entries: list[str] = []
        small_boxes = 0
        medium_boxes = 0
        large_boxes = 0
        total_boxes = 0
        positive_images = 0
        negative_images = 0

        for idx, rec in enumerate(records):
            id_seed = f"{rec.sha256_hex or rec.phash_hex}_{idx}"
            digest = hashlib.sha1(id_seed.encode("utf-8")).hexdigest()[:10]
            raw_base = rec.base_stem or extract_roboflow_base_stem(rec.image_path.stem)
            prefix = f"neg__{rec.negative_kind}__" if not rec.boxes else "pos__"
            if raw_base:
                safe_base = re.sub(r"[^A-Za-z0-9_.-]+", "_", raw_base).lstrip(".") or "image"
                stem = f"{prefix}{safe_base}.rf.{digest}"
            else:
                safe_src = re.sub(r"[^A-Za-z0-9_.-]+", "_", rec.source_name).lstrip(".") or "src"
                stem = f"{prefix}{safe_src}_{digest}"

            target_img = img_out / f"{stem}{rec.image_path.suffix.lower()}"
            target_lbl = lbl_out / f"{stem}.txt"

            shutil.copy2(rec.image_path, target_img)
            if rec.boxes:
                positive_images += 1
                target_lbl.write_text(
                    "\n".join(b.to_yolo_line() for b in rec.boxes) + "\n",
                    encoding="utf-8",
                )
            else:
                negative_images += 1
                nk = rec.negative_kind or "leaf_empty"
                negative_breakdown[nk] = negative_breakdown.get(nk, 0) + 1
                target_lbl.write_text("", encoding="utf-8")

            img_sha = rec.sha256_hex or hashlib.sha256(target_img.read_bytes()).hexdigest()
            manifest_entries.append(f"{target_img.name}:{img_sha}")
            per_source_images[rec.source_name] = per_source_images.get(rec.source_name, 0) + 1

            per_img_cls: dict[int, int] = {}
            for box in rec.boxes:
                total_boxes += 1
                class_counts[CANONICAL_CLASSES[box.class_id]] += 1
                per_img_cls[box.class_id] = per_img_cls.get(box.class_id, 0) + 1
                area_px = (box.w * 640.0) * (box.h * 640.0)
                if area_px < 32.0 * 32.0:
                    small_boxes += 1
                elif area_px < 96.0 * 96.0:
                    medium_boxes += 1
                else:
                    large_boxes += 1

            if split_name == "train":
                for cid, cnt in per_img_cls.items():
                    train_per_image_counts[CANONICAL_CLASSES[cid]].append(cnt)

        manifest_sha256 = hashlib.sha256("\n".join(sorted(manifest_entries)).encode("utf-8")).hexdigest()
        report["splits"][split_name] = {
            "images": len(records),
            "positive_images": positive_images,
            "negative_images": negative_images,
            "negative_breakdown": dict(sorted(negative_breakdown.items())),
            "groups": len({r.group_id for r in records if r.group_id}) or len(records),
            "instances": total_boxes,
            "per_class_instances": class_counts,
            "per_source_images": dict(sorted(per_source_images.items())),
            "scale_distribution": {
                "small_lt_32px": small_boxes,
                "medium_32_96px": medium_boxes,
                "large_ge_96px": large_boxes,
                "small_ratio": round(small_boxes / max(1, total_boxes), 4),
            },
            "manifest_sha256": manifest_sha256,
        }

    report["train_count_quantiles"] = {
        cls_name: _compute_count_quantiles(cnts)
        for cls_name, cnts in train_per_image_counts.items()
    }

    yaml_payload = {
        "train": "train/images",
        "val": "val/images",
        "test": "test/images",
        "nc": len(CANONICAL_CLASSES),
        "names": CANONICAL_CLASSES,
    }
    (output_dir / "data.yaml").write_text(yaml.safe_dump(yaml_payload, sort_keys=False), encoding="utf-8")
    (output_dir / "visual_pipeline_manifest.json").write_text(
        json.dumps(export_visual_pipeline_manifest(), indent=2),
        encoding="utf-8",
    )
    (output_dir / "dataset_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    return report


def download_roboflow_direct_sources(
    raw_root: Path,
    sources: tuple[dict[str, Any], ...] = ROBOFLOW_DIRECT_SOURCES,
    probe_results_out: list[dict[str, Any]] | None = None,
    env_file: Path | None = None,
    force_download: bool = False,
) -> list[Path]:
    load_env_file(env_file)
    raw_root.mkdir(parents=True, exist_ok=True)
    downloaded: list[Path] = []
    if probe_results_out is not None:
        probe_results_out.clear()

    for spec in sources:
        name = str(spec["name"])
        slug = str(spec["slug"])
        version_num = int(spec["version"])
        env_key = str(spec["env_url_key"])
        required = bool(spec.get("required", True))
        dest = raw_root / name

        raw_url = os.environ.get(env_key, "").strip()
        if not raw_url:
            if required:
                raise RuntimeError(f"Missing required environment variable {env_key} in ml/.env or environment.")
            continue

        resolved_url, secret_key = normalize_roboflow_ds_url(raw_url)
        used_cache = False
        try:
            if not force_download and (dest / "data.yaml").is_file() and _iter_source_image_label_pairs(dest):
                used_cache = True
            else:
                if dest.exists():
                    shutil.rmtree(dest)
                dest.mkdir(parents=True, exist_ok=True)
                resp = requests.get(resolved_url, timeout=90)
                resp.raise_for_status()
                with zipfile.ZipFile(io.BytesIO(resp.content)) as zf:
                    zf.extractall(dest)
                if not (dest / "data.yaml").is_file():
                    raise RuntimeError(f"Downloaded archive for {slug} lacks data.yaml")
        except Exception as exc:
            sanitized_err = _sanitize_text(str(exc), (secret_key,))
            entry = {
                "name": name,
                "slug": slug,
                "version": version_num,
                "required": required,
                "accessible": False,
                "status": "failed",
                "error_type": type(exc).__name__,
                "error": sanitized_err,
                "raw_class_map": {},
                "raw_split_image_counts": {},
            }
            if probe_results_out is not None:
                probe_results_out.append(entry)
            if required:
                raise RuntimeError(f"Failed downloading {slug}: {sanitized_err}") from None
            continue

        raw_class_map = {str(k): v for k, v in sorted(load_source_class_map(dest).items())}
        raw_split_counts = {
            sp: sum(1 for p in (dest / sp / "images").rglob("*") if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS)
            for sp in ("train", "valid", "val", "test")
            if (dest / sp / "images").is_dir()
        }
        entry = {
            "name": name,
            "slug": slug,
            "version": version_num,
            "required": required,
            "accessible": True,
            "status": "cached" if used_cache else "downloaded",
            "status_code": 200,
            "error_type": None,
            "error": None,
            "raw_class_map": raw_class_map,
            "raw_split_image_counts": raw_split_counts,
        }
        if probe_results_out is not None:
            probe_results_out.append(entry)
        downloaded.append(dest)

    return downloaded


def verify_exported_dataset(
    output_dir: Path,
    max_hamming_distance: int = 2,
    require_all_classes: bool = True,
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
        violations.append("data.yaml must be a YAML mapping")
    else:
        if "path" in yaml_data:
            violations.append("data.yaml must omit 'path' for portable resolution")
        if yaml_data.get("nc") != len(CANONICAL_CLASSES):
            violations.append(f"data.yaml nc must be {len(CANONICAL_CLASSES)}, got {yaml_data.get('nc')!r}")
        raw_names = yaml_data.get("names")
        norm_names: dict[int, str] | None = None
        if isinstance(raw_names, dict):
            try:
                norm_names = {int(k): str(v) for k, v in raw_names.items()}
            except (TypeError, ValueError):
                violations.append(f"data.yaml names keys must be integers: {raw_names!r}")
        elif isinstance(raw_names, list):
            norm_names = {idx: str(v) for idx, v in enumerate(raw_names)}
        else:
            violations.append(f"data.yaml names must be a mapping or list, got {raw_names!r}")
        if norm_names is not None and norm_names != CANONICAL_CLASSES:
            violations.append(f"data.yaml names mismatch: {norm_names!r}")

    if violations:
        raise ValueError("Dataset verification failed:\n- " + "\n- ".join(violations[:20]))

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
            violations.append(f"Missing images/ or labels/ directory for split {split_name}")
            continue
        img_files = sorted(p for p in img_dir.iterdir() if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS)
        lbl_files = sorted(p for p in lbl_dir.iterdir() if p.is_file() and p.suffix.lower() == ".txt")
        if not img_files:
            violations.append(f"Split {split_name} has 0 images")

        img_by_stem: dict[str, Path] = {}
        for p in img_files:
            if p.stem in img_by_stem:
                violations.append(f"Split {split_name} has duplicate image stem across extensions: {p.stem}")
            img_by_stem[p.stem] = p
        lbl_by_stem = {p.stem: p for p in lbl_files}
        missing_lbls = set(img_by_stem) - set(lbl_by_stem)
        extra_lbls = set(lbl_by_stem) - set(img_by_stem)
        if missing_lbls or extra_lbls:
            unpaired_files += len(missing_lbls) + len(extra_lbls)
            violations.append(f"Split {split_name} image/label mismatch")

        seen_split_sha: set[str] = set()
        split_dihedral_list: list[tuple[int, ...]] = []
        intra_index = _DihedralHashIndex(max_hamming_distance)
        seen_base_stems: set[str] = set()
        per_class_instances = {name: 0 for name in CANONICAL_CLASSES.values()}
        total_boxes = 0
        positive_imgs = 0
        negative_imgs = 0

        for stem, img_path in sorted(img_by_stem.items()):
            lbl_path = lbl_by_stem.get(stem)
            if lbl_path is None:
                continue
            sha256_hex = hashlib.sha256(img_path.read_bytes()).hexdigest()
            with Image.open(img_path) as img:
                dihedral_phs = compute_dihedral_phashes(img)

            if sha256_hex in seen_split_sha:
                intra_sha256_duplicates += 1
                violations.append(f"Intra-split SHA-256 duplicate in {split_name}: {img_path.name}")
            seen_split_sha.add(sha256_hex)

            if intra_index.has_match(dihedral_phs):
                intra_phash_duplicates += 1
                violations.append(f"Intra-split pHash duplicate in {split_name}: {img_path.name}")
            intra_index.add(dihedral_phs)
            split_dihedral_list.append(dihedral_phs)

            base_stem = extract_roboflow_base_stem(img_path.stem)
            if base_stem:
                # Strip prefix tag pos__/neg__... before checking raw base stem
                clean_base = re.sub(r"^(?:pos|neg__[A-Za-z0-9_]+)__", "", base_stem)
                seen_base_stems.add(clean_base)

            lines = [ln.strip() for ln in lbl_path.read_text(encoding="utf-8").splitlines() if ln.strip()]
            if not lines:
                negative_imgs += 1
                continue

            positive_imgs += 1
            for line in lines:
                parts = line.split()
                if len(parts) != 5:
                    invalid_labels += 1
                    violations.append(f"Invalid YOLO token count in {split_name}/{lbl_path.name}")
                    continue
                cls_id = int(parts[0])
                cx, cy, w, h = (float(parts[1]), float(parts[2]), float(parts[3]), float(parts[4]))
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
                    violations.append(f"Out-of-bounds box in {split_name}/{lbl_path.name}")
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
            "positive_images": positive_imgs,
            "negative_images": negative_imgs,
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
            violations.append(f"Cross-split SHA-256 overlap {left}/{right}: {len(sha_overlap)}")

        right_dedup_idx = _DihedralHashIndex(max_hamming_distance)
        for rp in split_dihedral_phashes[right]:
            right_dedup_idx.add(rp)
        phash_matches = sum(1 for lp in split_dihedral_phashes[left] if right_dedup_idx.has_match(lp))
        if phash_matches:
            cross_split_phash_overlaps += phash_matches
            violations.append(f"Cross-split pHash overlap {left}/{right}: {phash_matches}")

        right_group_idx = _DihedralHashIndex(effective_group_hamming)
        for rp in split_dihedral_phashes[right]:
            right_group_idx.add(rp)
        group_matches = sum(1 for lp in split_dihedral_phashes[left] if right_group_idx.has_match(lp))
        if group_matches:
            cross_split_group_phash_overlaps += group_matches
            violations.append(f"Cross-split group pHash overlap {left}/{right}: {group_matches}")

        stem_overlap = split_base_stems[left] & split_base_stems[right]
        if stem_overlap:
            cross_split_base_stem_overlaps += len(stem_overlap)
            violations.append(f"Cross-split base-stem overlap {left}/{right}: {len(stem_overlap)}")

    if violations:
        raise ValueError("Dataset verification failed:\n- " + "\n- ".join(violations[:20]))

    return {
        "status": "passed",
        "data_yaml_path_omitted": True,
        "data_yaml_portable_relative_paths": True,
        "molted_skin_surviving_instances": 0,
        "thrips_surviving_instances": 0,
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
        "all_canonical_classes_present_in_all_splits": True,
        "splits": split_summaries,
    }


def write_provenance_reports(
    report_dir: Path,
    output_dir: Path,
    probe_results: list[dict[str, Any]],
    ood_manifest: dict[str, Any] | None,
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
    total_images = sum(v["images"] for v in export_report["splits"].values())
    total_pos = sum(v["positive_images"] for v in export_report["splits"].values())
    total_neg = sum(v["negative_images"] for v in export_report["splits"].values())
    total_instances = sum(v["instances"] for v in export_report["splits"].values())
    total_per_class = {
        cls_name: sum(sp["per_class_instances"][cls_name] for sp in export_report["splits"].values())
        for cls_name in CANONICAL_CLASSES.values()
    }

    # Sample visual profile summary across exported train images (up to 80 deterministic samples)
    sample_imgs = sorted((output_dir / "train" / "images").iterdir())[:80]
    vis_profiles = [compute_image_visual_profile(p) for p in sample_imgs if p.is_file()]
    visual_summary = {
        "mean_brightness": round(float(np.mean([v["brightness"] for v in vis_profiles])), 4) if vis_profiles else 0.0,
        "mean_contrast": round(float(np.mean([v["contrast"] for v in vis_profiles])), 4) if vis_profiles else 0.0,
        "mean_saturation": round(float(np.mean([v["saturation"] for v in vis_profiles])), 4) if vis_profiles else 0.0,
        "mean_edge_energy": round(float(np.mean([v["edge_energy"] for v in vis_profiles])), 6) if vis_profiles else 0.0,
    }

    provenance_payload: dict[str, Any] = {
        "generated_at_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "zero_synthetic_confirmed": True,
        "synthetic_images_count": 0,
        "canonical_classes": {str(k): v for k, v in CANONICAL_CLASSES.items()},
        "excluded_classes_stripped": sorted(EXCLUDED_CLASS_NAMES),
        "molted_skin_boxes_removed": scan_stats["molted_skin_boxes_removed"],
        "split_config": {
            "train_ratio": train_ratio,
            "val_ratio": val_ratio,
            "test_ratio": round(1.0 - train_ratio - val_ratio, 4),
            "seed": seed,
            "max_hamming_distance": max_hamming_distance,
            "group_hamming_distance": max(group_hamming_distance, max_hamming_distance),
            "dihedral_orientations_checked": 8,
            "group_aware_split": True,
        },
        "sources_probed": probe_results,
        "ood_negatives": ood_manifest or {},
        "deduplication": {
            **scan_stats,
            "per_source_details": source_details,
        },
        "visual_profile_sample": visual_summary,
        "train_count_quantiles": export_report["train_count_quantiles"],
        "splits": export_report["splits"],
        "totals": {
            "images": total_images,
            "positive_images": total_pos,
            "negative_images": total_neg,
            "instances": total_instances,
            "per_class_instances": total_per_class,
        },
        "verification": verification_result,
    }

    json_text = _sanitize_text(json.dumps(provenance_payload, indent=2))
    md_lines = [
        "# HidroSense 2-Class (`whitefly` & `aphids`) + Real-Life OOD Dataset Provenance",
        "",
        f"- **Generated (UTC)**: `{provenance_payload['generated_at_utc']}`",
        "- **Canonical Classes (`nc = 2`)**: `0: whitefly`, `1: aphids`",
        f"- **`molted skin` annotations stripped**: `{scan_stats['molted_skin_boxes_removed']}` (`0` surviving)",
        f"- **Zero Synthetic Confirmed**: `{provenance_payload['zero_synthetic_confirmed']}`",
        f"- **Total Clean Unique Images**: `{total_images}` (`{total_pos}` positive + `{total_neg}` negative/OOD background)",
        "",
        "## Split Distribution",
        "",
        "| Split | Total Images | Positive | Negative (Leaf + OOD) | Instances | `whitefly` | `aphids` |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for sp_name in ("train", "val", "test"):
        sp = export_report["splits"][sp_name]
        pci = sp["per_class_instances"]
        md_lines.append(
            f"| `{sp_name}` | {sp['images']} | {sp['positive_images']} | {sp['negative_images']} | "
            f"{sp['instances']} | {pci['whitefly']} | {pci['aphids']} |"
        )
    md_text = _sanitize_text("\n".join(md_lines) + "\n")

    json_path = report_dir / "dataset_provenance.json"
    md_path = report_dir / "dataset_provenance.md"
    json_path.write_text(json_text, encoding="utf-8")
    md_path.write_text(md_text, encoding="utf-8")
    (output_dir / "dataset_provenance.json").write_text(json_text, encoding="utf-8")
    return json_path, md_path


def upload_private_kaggle_dataset(
    dataset_dir: Path,
    dataset_slug: str = DEFAULT_KAGGLE_DATASET_SLUG,
    version_notes: str = "HidroSense 2-class whitefly & aphids + OOD hard negatives (molted skin stripped)",
) -> str:
    sibling_kaggle = Path(sys.executable).with_name("kaggle.exe" if sys.platform.startswith("win") else "kaggle")
    kaggle_exe = str(sibling_kaggle) if sibling_kaggle.is_file() else (shutil.which("kaggle") or "kaggle")

    meta = {
        "title": "HidroSense Whitefly & Aphids v2 (OOD Hardened)",
        "id": dataset_slug,
        "licenses": [{"name": "CC0-1.0"}],
    }
    meta_path = dataset_dir / "dataset-metadata.json"
    meta_path.write_text(json.dumps(meta, indent=2), encoding="utf-8")

    status_proc = subprocess.run(
        [kaggle_exe, "datasets", "status", dataset_slug],
        capture_output=True,
        text=True,
        check=False,
    )
    if status_proc.returncode == 0 and "ready" in (status_proc.stdout or "").lower():
        cmd = [kaggle_exe, "datasets", "version", "-p", str(dataset_dir), "-m", version_notes, "--dir-mode", "zip"]
    else:
        cmd = [kaggle_exe, "datasets", "create", "-p", str(dataset_dir), "--dir-mode", "zip"]

    proc = subprocess.run(cmd, capture_output=True, text=True, check=True)
    meta_path.unlink(missing_ok=True)
    return (proc.stdout or "").strip()


def main(argv: list[str] | None = None) -> dict[str, Any]:
    parser = argparse.ArgumentParser(description="Prepare 2-class whitefly & aphids + real-life OOD negative dataset.")
    parser.add_argument("--raw-root", type=Path, default=Path("ml/data/raw_v2"))
    parser.add_argument("--output-dir", type=Path, default=Path("ml/data/merged_lettuce_pests"))
    parser.add_argument("--report-dir", type=Path, default=Path("ml/reports"))
    parser.add_argument("--env-file", type=Path, default=Path("ml/.env"))
    parser.add_argument("--max-hamming-distance", type=int, default=2)
    parser.add_argument("--group-hamming-distance", type=int, default=4)
    parser.add_argument("--train-ratio", type=float, default=0.8)
    parser.add_argument("--val-ratio", type=float, default=0.1)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--skip-ood", action="store_true")
    parser.add_argument("--force-download", action="store_true")
    parser.add_argument("--upload-kaggle", action="store_true")
    parser.add_argument("--kaggle-dataset", type=str, default=DEFAULT_KAGGLE_DATASET_SLUG)
    args = parser.parse_args(argv)

    probe_results: list[dict[str, Any]] = []
    source_dirs = download_roboflow_direct_sources(
        raw_root=args.raw_root,
        probe_results_out=probe_results,
        env_file=args.env_file,
        force_download=args.force_download,
    )

    ood_manifest: dict[str, Any] | None = None
    if not args.skip_ood:
        ood_dirs, ood_manifest = prepare_coco_ood_negatives(
            raw_root=args.raw_root,
            force_download=args.force_download,
        )
        source_dirs.extend(ood_dirs)

    source_details: dict[str, Any] = {}
    records, scan_stats = deduplicate_and_merge_sources(
        source_dirs=source_dirs,
        max_hamming_distance=args.max_hamming_distance,
        group_hamming_distance=args.group_hamming_distance,
        keep_negatives=True,
        source_details_out=source_details,
    )

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
    verification = verify_exported_dataset(
        output_dir=args.output_dir,
        max_hamming_distance=args.max_hamming_distance,
        require_all_classes=True,
        group_hamming_distance=args.group_hamming_distance,
    )
    json_path, md_path = write_provenance_reports(
        report_dir=args.report_dir,
        output_dir=args.output_dir,
        probe_results=probe_results,
        ood_manifest=ood_manifest,
        scan_stats=scan_stats,
        source_details=source_details,
        export_report=export_report,
        verification_result=verification,
        max_hamming_distance=args.max_hamming_distance,
        seed=args.seed,
        train_ratio=args.train_ratio,
        val_ratio=args.val_ratio,
        group_hamming_distance=args.group_hamming_distance,
    )

    upload_out = ""
    if args.upload_kaggle:
        upload_out = upload_private_kaggle_dataset(args.output_dir, dataset_slug=args.kaggle_dataset)

    return {
        "provenance_json": str(json_path),
        "provenance_md": str(md_path),
        "output_dir": str(args.output_dir),
        "molted_skin_boxes_removed": scan_stats["molted_skin_boxes_removed"],
        "negative_images_kept": scan_stats["negative_images_kept"],
        "totals": {
            "images": sum(v["images"] for v in export_report["splits"].values()),
            "instances": sum(v["instances"] for v in export_report["splits"].values()),
        },
        "train_count_quantiles": export_report["train_count_quantiles"],
        "kaggle_upload": upload_out,
    }


if __name__ == "__main__":
    print(json.dumps(main(), indent=2))
