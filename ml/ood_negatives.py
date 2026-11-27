from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import io
import json
from pathlib import Path
import random
import shutil
from typing import Any
import zipfile

import requests
import yaml

COCO128_URL = "https://github.com/ultralytics/assets/releases/download/v0.0.0/coco128.zip"
COCO2017_LABELS_URL = "https://github.com/ultralytics/assets/releases/download/v0.0.0/coco2017labels.zip"
COCO_VAL2017_IMAGE_BASE = "http://images.cocodataset.org/val2017"

# COCO class indices grouped into the exact real-life false-positive categories reported in field testing.
COCO_PERSON_CLASSES: frozenset[int] = frozenset({0})
COCO_BOTTLE_CUP_CLASSES: frozenset[int] = frozenset({39, 40, 41})  # bottle, wine glass, cup
COCO_HEALTHY_FOOD_CLASSES: frozenset[int] = frozenset(
    {45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55}  # bowl, banana, apple, sandwich, orange, broccoli, carrot, etc.
)
# Exclude potted plant (58) and vase (75) to guarantee zero unannotated plant/foliage pests in OOD negatives.
COCO_EXCLUDED_CLASSES: frozenset[int] = frozenset({58, 75})

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


def _init_ood_category_dirs(ood_root: Path) -> None:
    for cat in OOD_CATEGORIES:
        (ood_root / cat / "train" / "images").mkdir(parents=True, exist_ok=True)
        (ood_root / cat / "train" / "labels").mkdir(parents=True, exist_ok=True)
        (ood_root / cat / "data.yaml").write_text(
            yaml.safe_dump({"nc": 0, "names": []}, sort_keys=False),
            encoding="utf-8",
        )


def _download_single_val2017(
    stem: str,
    category: str,
    ood_root: Path,
    base_url: str,
    timeout_s: int,
) -> tuple[str, bool]:
    out_img = ood_root / category / "train" / "images" / f"{category}_{stem}.jpg"
    out_lbl = ood_root / category / "train" / "labels" / f"{category}_{stem}.txt"
    if out_img.is_file() and out_img.stat().st_size > 1024 and out_lbl.is_file():
        return category, True
    url = f"{base_url.rstrip('/')}/{stem}.jpg"
    for _ in range(2):
        try:
            resp = requests.get(url, timeout=timeout_s)
            if resp.status_code == 200 and len(resp.content) > 1024 and resp.content[:2] == b"\xff\xd8":
                out_img.write_bytes(resp.content)
                out_lbl.write_text("", encoding="utf-8")
                return category, True
        except Exception:
            continue
    return category, False


def prepare_coco_val2017_ood_negatives(
    raw_root: Path,
    *,
    target_per_category: int = 150,
    seed: int = 42,
    labels_url: str = COCO2017_LABELS_URL,
    image_base_url: str = COCO_VAL2017_IMAGE_BASE,
    force_download: bool = False,
    timeout_s: int = 45,
    max_workers: int = 16,
) -> tuple[list[Path], dict[str, Any]]:
    """Download balanced real-world COCO 2017 val2017 OOD hard-negatives with empty YOLO labels."""
    ood_root = raw_root / "ood_coco_val2017_negatives"
    manifest_path = ood_root / "ood_manifest.json"
    if not force_download and manifest_path.is_file():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        dirs = [ood_root / cat for cat in OOD_CATEGORIES if (ood_root / cat / "data.yaml").is_file()]
        if (
            len(dirs) == len(OOD_CATEGORIES)
            and int(manifest.get("total_ood_images", 0)) >= target_per_category * len(OOD_CATEGORIES) * 0.9
        ):
            return dirs, manifest

    cache_dir = raw_root / "_cache"
    cache_dir.mkdir(parents=True, exist_ok=True)
    labels_zip_path = cache_dir / "coco2017labels.zip"
    if force_download or not labels_zip_path.is_file() or labels_zip_path.stat().st_size < 1_000_000:
        resp = requests.get(labels_url, timeout=max(timeout_s, 120))
        resp.raise_for_status()
        labels_zip_path.write_bytes(resp.content)

    labels_sha256 = hashlib.sha256(labels_zip_path.read_bytes()).hexdigest()
    candidates_by_cat: dict[str, list[str]] = {cat: [] for cat in OOD_CATEGORIES}
    excluded_count = 0

    with zipfile.ZipFile(labels_zip_path, "r") as zf:
        val_entries = sorted(
            n
            for n in zf.namelist()
            if "/labels/val2017/" in n and n.endswith(".txt")
        )
        for entry in val_entries:
            stem = Path(entry).stem
            txt = zf.read(entry).decode("utf-8", errors="ignore")
            coco_cls_ids: set[int] = set()
            for line in txt.splitlines():
                parts = line.strip().split()
                if parts:
                    try:
                        coco_cls_ids.add(int(float(parts[0])))
                    except ValueError:
                        continue
            cat = classify_coco_ood_category(coco_cls_ids)
            if cat is None:
                excluded_count += 1
                continue
            candidates_by_cat[cat].append(stem)

    if force_download and ood_root.exists():
        shutil.rmtree(ood_root)
    ood_root.mkdir(parents=True, exist_ok=True)
    _init_ood_category_dirs(ood_root)

    rng = random.Random(seed)
    selected_tasks: list[tuple[str, str]] = []
    for cat in OOD_CATEGORIES:
        pool = list(candidates_by_cat[cat])
        rng.shuffle(pool)
        # Take a small buffer above target_per_category in case any CDN image fails, then trim cleanly
        for stem in pool[: target_per_category + 12]:
            selected_tasks.append((stem, cat))

    counts: dict[str, int] = {cat: 0 for cat in OOD_CATEGORIES}
    downloaded_by_cat: dict[str, list[str]] = {cat: [] for cat in OOD_CATEGORIES}

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {
            executor.submit(
                _download_single_val2017, stem, cat, ood_root, image_base_url, timeout_s
            ): (stem, cat)
            for stem, cat in selected_tasks
        }
        for fut in as_completed(futures):
            stem, cat = futures[fut]
            _, ok = fut.result()
            if ok:
                downloaded_by_cat[cat].append(stem)

    # Trim any category above target_per_category deterministically so split sizes stay exact
    for cat in OOD_CATEGORIES:
        stems = sorted(downloaded_by_cat[cat])
        for extra_stem in stems[target_per_category:]:
            (ood_root / cat / "train" / "images" / f"{cat}_{extra_stem}.jpg").unlink(missing_ok=True)
            (ood_root / cat / "train" / "labels" / f"{cat}_{extra_stem}.txt").unlink(missing_ok=True)
        counts[cat] = min(len(stems), target_per_category)

    manifest = {
        "source": "COCO 2017 val2017 curated real photographs",
        "labels_archive_sha256": labels_sha256,
        "target_per_category": target_per_category,
        "seed": seed,
        "excluded_coco_classes": sorted(COCO_EXCLUDED_CLASSES),
        "excluded_images": excluded_count,
        "category_counts": counts,
        "total_ood_images": sum(counts.values()),
    }
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    dirs = [ood_root / cat for cat in OOD_CATEGORIES]
    return dirs, manifest


def prepare_coco_ood_negatives(
    raw_root: Path,
    *,
    source: str = "coco128",
    target_per_category: int = 150,
    seed: int = 42,
    coco128_url: str = COCO128_URL,
    force_download: bool = False,
    timeout_s: int = 60,
) -> tuple[list[Path], dict[str, Any]]:
    """Download and materialize categorized real-life non-pest OOD background directories with empty labels."""
    if source == "coco_val2017":
        return prepare_coco_val2017_ood_negatives(
            raw_root,
            target_per_category=target_per_category,
            seed=seed,
            force_download=force_download,
            timeout_s=timeout_s,
        )

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
    _init_ood_category_dirs(ood_root)

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
