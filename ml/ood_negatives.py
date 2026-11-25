from __future__ import annotations

import hashlib
import io
import json
from pathlib import Path
import shutil
from typing import Any
import zipfile

import requests
import yaml

COCO128_URL = "https://github.com/ultralytics/assets/releases/download/v0.0.0/coco128.zip"

# COCO class indices grouped into the exact real-life false-positive categories reported in field testing.
COCO_PERSON_CLASSES: frozenset[int] = frozenset({0})
COCO_BOTTLE_CUP_CLASSES: frozenset[int] = frozenset({39, 40, 41})  # bottle, wine glass, cup
COCO_HEALTHY_FOOD_CLASSES: frozenset[int] = frozenset(
    {45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55}  # bowl, banana, apple, sandwich, orange, broccoli, carrot, etc.
)
# Exclude potted plant (58) to guarantee zero unannotated plant pests in OOD negatives.
COCO_EXCLUDED_CLASSES: frozenset[int] = frozenset({58})

OOD_CATEGORIES: tuple[str, ...] = (
    "ood_people",
    "ood_drink_bottles_cups",
    "ood_healthy_food",
    "ood_random_objects",
)


def classify_coco_ood_category(coco_class_ids: set[int]) -> str | None:
    """Assign a COCO image to a real-life OOD negative category, or None if excluded."""
    if coco_class_ids & COCO_EXCLUDED_CLASSES:
        return None
    if coco_class_ids & COCO_BOTTLE_CUP_CLASSES:
        return "ood_drink_bottles_cups"
    if coco_class_ids & COCO_HEALTHY_FOOD_CLASSES:
        return "ood_healthy_food"
    if coco_class_ids & COCO_PERSON_CLASSES:
        return "ood_people"
    return "ood_random_objects"


def prepare_coco_ood_negatives(
    raw_root: Path,
    *,
    coco128_url: str = COCO128_URL,
    force_download: bool = False,
    timeout_s: int = 60,
) -> tuple[list[Path], dict[str, Any]]:
    """Download and materialize categorized real-life non-pest OOD background directories with empty labels."""
    ood_root = raw_root / "ood_coco128_negatives"
    manifest_path = ood_root / "ood_manifest.json"

    if not force_download and manifest_path.is_file():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        dirs = [ood_root / cat for cat in OOD_CATEGORIES if (ood_root / cat / "data.yaml").is_file()]
        if len(dirs) == len(OOD_CATEGORIES):
            return dirs, manifest

    if ood_root.exists():
        shutil.rmtree(ood_root)
    ood_root.mkdir(parents=True, exist_ok=True)

    resp = requests.get(coco128_url, timeout=timeout_s)
    resp.raise_for_status()
    archive_bytes = resp.content
    archive_sha256 = hashlib.sha256(archive_bytes).hexdigest()

    zf = zipfile.ZipFile(io.BytesIO(archive_bytes))
    names = set(zf.namelist())
    img_entries = sorted(
        n
        for n in names
        if "/images/" in n and not n.endswith("/") and Path(n).suffix.lower() in {".jpg", ".jpeg", ".png"}
    )

    counts: dict[str, int] = {cat: 0 for cat in OOD_CATEGORIES}
    excluded_count = 0

    for cat in OOD_CATEGORIES:
        (ood_root / cat / "train" / "images").mkdir(parents=True, exist_ok=True)
        (ood_root / cat / "train" / "labels").mkdir(parents=True, exist_ok=True)
        (ood_root / cat / "data.yaml").write_text(
            yaml.safe_dump({"nc": 0, "names": []}, sort_keys=False),
            encoding="utf-8",
        )

    for img_entry in img_entries:
        stem = Path(img_entry).stem
        lbl_entry = img_entry.replace("/images/", "/labels/").rsplit(".", 1)[0] + ".txt"
        coco_cls_ids: set[int] = set()
        if lbl_entry in names:
            txt = zf.read(lbl_entry).decode("utf-8", errors="ignore")
            for line in txt.splitlines():
                parts = line.strip().split()
                if parts:
                    try:
                        coco_cls_ids.add(int(float(parts[0])))
                    except ValueError:
                        continue

        category = classify_coco_ood_category(coco_cls_ids)
        if category is None:
            excluded_count += 1
            continue

        out_img = ood_root / category / "train" / "images" / f"{category}_{stem}{Path(img_entry).suffix.lower()}"
        out_lbl = ood_root / category / "train" / "labels" / f"{category}_{stem}.txt"
        out_img.write_bytes(zf.read(img_entry))
        # Empty YOLO label file explicitly teaches background / zero pest objects
        out_lbl.write_text("", encoding="utf-8")
        counts[category] += 1

    manifest = {
        "source": "ultralytics/coco128 (COCO 2017 real photographs)",
        "archive_sha256": archive_sha256,
        "excluded_coco_classes": sorted(COCO_EXCLUDED_CLASSES),
        "excluded_images": excluded_count,
        "category_counts": counts,
        "total_ood_images": sum(counts.values()),
    }
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    dirs = [ood_root / cat for cat in OOD_CATEGORIES]
    return dirs, manifest

