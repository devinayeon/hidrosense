from __future__ import annotations

import hashlib
import json
import os
import random
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from PIL import Image
import imagehash
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

ROBOFLOW_SOURCES: tuple[dict[str, str], ...] = (
    {
        "workspace": "puzzle-piece-detection",
        "project": "lettuce-pests",
        "version": "1",
    },
    {
        "workspace": "agrivision-2025",
        "project": "lettuce-pests-wieje",
        "version": "1",
    },
    {
        "workspace": "puzzle-piece-detection",
        "project": "lettuce-pest-detection",
        "version": "1",
    },
)

IMAGE_EXTENSIONS: frozenset[str] = frozenset({".jpg", ".jpeg", ".png", ".bmp", ".webp"})
MIN_BOX_DIMENSION: float = 0.002


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

    @property
    def primary_class(self) -> int:
        if not self.boxes:
            return -1
        counts: dict[int, int] = {}
        for box in self.boxes:
            counts[box.class_id] = counts.get(box.class_id, 0) + 1
        return max(counts.items(), key=lambda item: (item[1], -item[0]))[0]


def canonicalize_label_name(raw_name: str) -> int | None:
    cleaned = raw_name.strip().lower().replace("_", " ").replace("-", " ")
    if cleaned in SYNONYM_MAP:
        return SYNONYM_MAP[cleaned]
    for token, class_id in SYNONYM_MAP.items():
        if token in cleaned:
            return class_id
    return None


def _clamp01(value: float) -> float:
    return max(0.0, min(1.0, value))


def parse_and_sanitize_yolo_line(
    line: str,
    source_id_to_name: dict[int, str],
) -> BoxAnnotation | None:
    parts = line.strip().split()
    if len(parts) < 5:
        return None
    try:
        raw_class_id = int(float(parts[0]))
        coords = [float(val) for val in parts[1:]]
    except ValueError:
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
        content = yaml.safe_load(yaml_path.read_text(encoding="utf-8")) or {}
        names = content.get("names", {})
        if isinstance(names, list):
            return {idx: str(name) for idx, name in enumerate(names)}
        if isinstance(names, dict):
            return {int(k): str(v) for k, v in names.items()}
    return dict(CANONICAL_CLASSES)


def _iter_source_image_label_pairs(source_dir: Path) -> list[tuple[Path, Path]]:
    pairs: list[tuple[Path, Path]] = []
    for img_path in sorted(source_dir.rglob("*")):
        if not img_path.is_file() or img_path.suffix.lower() not in IMAGE_EXTENSIONS:
            continue
        if "images" in img_path.parts:
            idx = list(img_path.parts).index("images")
            rel_parts = list(img_path.parts)
            rel_parts[idx] = "labels"
            label_path = Path(*rel_parts).with_suffix(".txt")
        else:
            label_path = img_path.with_suffix(".txt")
        if label_path.exists():
            pairs.append((img_path, label_path))
    return pairs


def _hamming_distance(hex_a: str, hex_b: str) -> int:
    return (int(hex_a, 16) ^ int(hex_b, 16)).bit_count()


def deduplicate_and_merge_sources(
    source_dirs: list[Path],
    max_hamming_distance: int = 2,
) -> tuple[list[DatasetRecord], dict[str, int]]:
    merged: list[DatasetRecord] = []
    stats = {
        "total_scanned": 0,
        "duplicates_removed": 0,
        "empty_or_unmapped_skipped": 0,
        "boxes_kept": 0,
    }

    for source_dir in source_dirs:
        if not source_dir.exists():
            continue
        class_map = load_source_class_map(source_dir)
        for img_path, label_path in _iter_source_image_label_pairs(source_dir):
            stats["total_scanned"] += 1
            try:
                with Image.open(img_path) as img:
                    phash_hex = str(imagehash.phash(img.convert("RGB")))
            except Exception:
                stats["empty_or_unmapped_skipped"] += 1
                continue

            raw_lines = label_path.read_text(encoding="utf-8", errors="ignore").splitlines()
            boxes = tuple(
                box
                for line in raw_lines
                if (box := parse_and_sanitize_yolo_line(line, class_map)) is not None
            )
            if not boxes:
                stats["empty_or_unmapped_skipped"] += 1
                continue

            is_duplicate = any(
                _hamming_distance(phash_hex, existing.phash_hex) <= max_hamming_distance
                for existing in merged
            )
            if is_duplicate:
                stats["duplicates_removed"] += 1
                continue

            stats["boxes_kept"] += len(boxes)
            merged.append(
                DatasetRecord(
                    image_path=img_path,
                    phash_hex=phash_hex,
                    boxes=boxes,
                    source_name=source_dir.name,
                )
            )
    return merged, stats


def stratified_split_records(
    records: list[DatasetRecord],
    train_ratio: float = 0.8,
    val_ratio: float = 0.1,
    seed: int = 42,
) -> dict[str, list[DatasetRecord]]:
    rng = random.Random(seed)
    by_class: dict[int, list[DatasetRecord]] = {0: [], 1: [], 2: []}
    for rec in records:
        by_class.setdefault(rec.primary_class, []).append(rec)

    splits: dict[str, list[DatasetRecord]] = {"train": [], "val": [], "test": []}
    for _, group in sorted(by_class.items()):
        shuffled = list(group)
        rng.shuffle(shuffled)
        n = len(shuffled)
        if n == 0:
            continue
        if n >= 3:
            n_val = max(1, int(round(n * val_ratio)))
            n_test = max(1, int(round(n * (1.0 - train_ratio - val_ratio))))
            n_train = max(1, n - n_val - n_test)
        else:
            n_train, n_val, n_test = n, 0, 0

        splits["train"].extend(shuffled[:n_train])
        splits["val"].extend(shuffled[n_train : n_train + n_val])
        splits["test"].extend(shuffled[n_train + n_val :])

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
        small_boxes = 0
        total_boxes = 0

        for idx, rec in enumerate(records):
            digest = hashlib.sha1(f"{rec.phash_hex}_{idx}".encode("utf-8")).hexdigest()[:10]
            stem = f"{rec.source_name}_{digest}"
            target_img = img_out / f"{stem}{rec.image_path.suffix.lower()}"
            target_lbl = lbl_out / f"{stem}.txt"

            shutil.copy2(rec.image_path, target_img)
            target_lbl.write_text(
                "\n".join(b.to_yolo_line() for b in rec.boxes) + "\n",
                encoding="utf-8",
            )
            for box in rec.boxes:
                total_boxes += 1
                class_counts[CANONICAL_CLASSES[box.class_id]] += 1
                if box.w * box.h < (32.0 / 640.0) ** 2:
                    small_boxes += 1

        report["splits"][split_name] = {
            "images": len(records),
            "instances": total_boxes,
            "per_class_instances": class_counts,
            "small_object_ratio": round(small_boxes / max(1, total_boxes), 4),
        }

    yaml_payload = {
        "path": str(output_dir.resolve()),
        "train": "train/images",
        "val": "val/images",
        "test": "test/images",
        "nc": 3,
        "names": CANONICAL_CLASSES,
    }
    (output_dir / "data.yaml").write_text(yaml.safe_dump(yaml_payload, sort_keys=False), encoding="utf-8")
    (output_dir / "dataset_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    return report


def download_roboflow_sources(raw_root: Path, api_key: str | None = None) -> list[Path]:
    key = api_key or os.environ.get("ROBOFLOW_API_KEY")
    downloaded: list[Path] = []
    if not key:
        return [p for p in sorted(raw_root.iterdir()) if p.is_dir()] if raw_root.exists() else []

    from roboflow import Roboflow

    rf = Roboflow(api_key=key)
    for spec in ROBOFLOW_SOURCES:
        dest = raw_root / f"{spec['workspace']}_{spec['project']}"
        if not dest.exists():
            project = rf.workspace(spec["workspace"]).project(spec["project"])
            version = project.version(int(spec["version"]))
            version.download("yolov11", location=str(dest))
        downloaded.append(dest)
    return downloaded
