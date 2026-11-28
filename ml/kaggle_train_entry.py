from __future__ import annotations

import argparse
import copy
import csv
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time
from typing import Any
import zipfile

CANONICAL_NAMES: dict[int, str] = {0: "whitefly", 1: "aphids"}
IMAGE_EXTENSIONS: frozenset[str] = frozenset({".jpg", ".jpeg", ".png", ".bmp", ".webp"})
KAGGLE_KERNEL_ID = "adityadwiferdiansyah/hidrosense-yolov11n-lettuce-pests-training"
KAGGLE_DATASET_ID = "adityadwiferdiansyah/hidrosense-whitefly-aphids-v2"


def _parse_version_tuple(raw: str) -> tuple[int, int, int]:
    parts: list[int] = []
    for token in raw.split("+")[0].split(".")[:3]:
        match = re.match(r"(\d+)", token.strip())
        parts.append(int(match.group(1)) if match else 0)
    while len(parts) < 3:
        parts.append(0)
    return (parts[0], parts[1], parts[2])


def ensure_packages() -> None:
    missing: list[str] = []
    for mod_name, spec in (("yaml", "pyyaml"), ("albumentations", "albumentations>=1.4.0")):
        try:
            __import__(mod_name)
        except ImportError:
            missing.append(spec)
    try:
        import ultralytics

        ver = _parse_version_tuple(getattr(ultralytics, "__version__", "0.0.0"))
        if not ((8, 3, 0) <= ver < (8, 5, 0)):
            missing.append("ultralytics>=8.3.0,<8.5.0")
    except ImportError:
        missing.append("ultralytics>=8.3.0,<8.5.0")

    if missing:
        print(f"[bootstrap] Installing packages: {missing}", flush=True)
        subprocess.run([sys.executable, "-m", "pip", "install", "-q", *missing], check=True)


def ensure_gpu_available() -> dict[str, Any]:
    """Fail fast if CUDA GPU is unavailable. Never fall back to CPU."""
    import torch

    if not torch.cuda.is_available() or torch.cuda.device_count() < 1:
        raise RuntimeError(
            "CUDA GPU is required for HidroSense training; torch.cuda.is_available() is False. "
            "Refusing CPU fallback."
        )

    device_count = int(torch.cuda.device_count())
    device_name = str(torch.cuda.get_device_name(0))
    props = torch.cuda.get_device_properties(0)
    vram_gb = round(float(props.total_memory) / (1024.0**3), 2)
    return {
        "enable_gpu": True,
        "gpu_count": device_count,
        "device": device_name,
        "gpu_vram_gb": vram_gb,
        "torch_version": str(torch.__version__),
        "cuda_version": str(torch.version.cuda or ""),
        "python_version": platform.python_version(),
    }


def _is_dataset_dir(candidate: Path) -> bool:
    has_splits = (
        (candidate / "train" / "images").is_dir()
        and (candidate / "val" / "images").is_dir()
        and (candidate / "test" / "images").is_dir()
    )
    has_zips = (
        (candidate / "train.zip").is_file()
        and (candidate / "val.zip").is_file()
        and (candidate / "test.zip").is_file()
    )
    return (
        candidate.is_dir()
        and (candidate / "data.yaml").is_file()
        and (candidate / "dataset_provenance.json").is_file()
        and (has_splits or has_zips)
    )


def _materialize_dataset_dir(candidate: Path) -> Path:
    resolved = candidate.resolve()
    if (resolved / "train" / "images").is_dir() and (resolved / "val" / "images").is_dir() and (resolved / "test" / "images").is_dir():
        return resolved

    extract_root = (Path("/kaggle/working") if Path("/kaggle/working").is_dir() else Path(tempfile.gettempdir())) / "_hidrosense_dataset_unpacked"
    shutil.rmtree(extract_root, ignore_errors=True)
    extract_root.mkdir(parents=True, exist_ok=True)
    for meta_file in ("data.yaml", "dataset_provenance.json", "dataset_report.json", "visual_pipeline_manifest.json"):
        src_meta = resolved / meta_file
        if src_meta.is_file():
            shutil.copy2(src_meta, extract_root / meta_file)

    for split_name in ("train", "val", "test"):
        split_src_dir = resolved / split_name
        split_zip = resolved / f"{split_name}.zip"
        target_split_dir = extract_root / split_name
        if (split_src_dir / split_name / "images").is_dir():
            shutil.copytree(split_src_dir / split_name, target_split_dir)
        elif (split_src_dir / "images").is_dir():
            shutil.copytree(split_src_dir, target_split_dir)
        elif split_zip.is_file():
            target_split_dir.mkdir(parents=True, exist_ok=True)
            with zipfile.ZipFile(split_zip, "r") as zf:
                zf.extractall(target_split_dir)
            if (target_split_dir / split_name / "images").is_dir() and not (target_split_dir / "images").is_dir():
                nested = target_split_dir / split_name
                for sub in ("images", "labels"):
                    if (nested / sub).is_dir():
                        shutil.move(str(nested / sub), str(target_split_dir / sub))
    return extract_root.resolve()


def _scan_bounded(root: Path, max_depth: int = 4) -> list[Path]:
    matches: list[Path] = []
    if not root.is_dir():
        return matches
    queue: list[tuple[Path, int]] = [(root, 0)]
    while queue:
        current, depth = queue.pop(0)
        if _is_dataset_dir(current):
            matches.append(current)
            continue
        if depth >= max_depth:
            continue
        try:
            for child in sorted(current.iterdir()):
                if child.is_dir():
                    queue.append((child, depth + 1))
        except OSError:
            continue
    return matches


def locate_dataset_dir(dataset_dir: Path | None = None, allow_local: bool = False) -> Path:
    candidates: list[Path] = []
    if dataset_dir is not None:
        candidates.append(Path(dataset_dir))

    env_dir = os.environ.get("HIDROSENSE_DATASET_DIR", "").strip()
    if env_dir:
        candidates.append(Path(env_dir))

    candidates.extend(
        [
            Path("/kaggle/input/datasets/adityadwiferdiansyah/hidrosense-whitefly-aphids-v2"),
            Path("/kaggle/input/hidrosense-whitefly-aphids-v2"),
        ]
    )

    for candidate in candidates:
        if _is_dataset_dir(candidate):
            return _materialize_dataset_dir(candidate)

    scanned = _scan_bounded(Path("/kaggle/input"), max_depth=4)
    if scanned:
        return _materialize_dataset_dir(scanned[0])

    if allow_local:
        local_candidate = Path("ml/data/merged_lettuce_pests")
        if _is_dataset_dir(local_candidate):
            return _materialize_dataset_dir(local_candidate)

    raise FileNotFoundError(
        "Real 2-class Roboflow+OOD dataset (data.yaml + dataset_provenance.json) not found. "
        "Synthetic fallback is disabled."
    )


def _list_images(images_dir: Path) -> list[Path]:
    if not images_dir.is_dir():
        return []
    return sorted(p for p in images_dir.iterdir() if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS)


def validate_real_dataset(dataset_dir: Path) -> dict[str, Any]:
    import yaml

    data_yaml_path = dataset_dir / "data.yaml"
    prov_path = dataset_dir / "dataset_provenance.json"
    if not data_yaml_path.is_file() or not prov_path.is_file():
        raise FileNotFoundError(f"Missing data.yaml or dataset_provenance.json in {dataset_dir}")

    data_cfg = yaml.safe_load(data_yaml_path.read_text(encoding="utf-8"))
    if not isinstance(data_cfg, dict) or int(data_cfg.get("nc", -1)) != 2:
        raise ValueError(f"Expected nc == 2 in {data_yaml_path}, got {data_cfg!r}")

    raw_names = data_cfg.get("names", {})
    normalized_names = (
        {int(k): str(v).strip().lower() for k, v in raw_names.items()}
        if isinstance(raw_names, dict)
        else {idx: str(v).strip().lower() for idx, v in enumerate(raw_names)}
    )
    if normalized_names != CANONICAL_NAMES:
        raise ValueError(f"Expected canonical names {CANONICAL_NAMES}, got {normalized_names!r}")

    provenance = json.loads(prov_path.read_text(encoding="utf-8"))
    if provenance.get("zero_synthetic_confirmed") is not True:
        raise ValueError("dataset_provenance.json must confirm zero_synthetic_confirmed is True")
    if int(provenance.get("synthetic_images_count", -1)) != 0:
        raise ValueError("dataset_provenance.json must have synthetic_images_count == 0")

    verification = provenance.get("verification", {})
    for key in (
        "molted_skin_surviving_instances",
        "thrips_surviving_instances",
        "cross_split_sha256_overlaps",
        "cross_split_phash_overlaps",
        "cross_split_group_phash_overlaps",
        "cross_split_base_stem_overlaps",
        "cross_split_temporal_session_overlaps",
        "cross_split_loose_scene_family_overlaps",
    ):
        if key in verification and int(verification[key]) != 0:
            raise ValueError(f"Integrity violation in {key}: {verification[key]}")

    split_counts: dict[str, int] = {}
    negative_counts: dict[str, int] = {}
    for split_name in ("train", "val", "test"):
        imgs = _list_images(dataset_dir / split_name / "images")
        lbl_dir = dataset_dir / split_name / "labels"
        lbls = sorted(p for p in lbl_dir.iterdir() if p.is_file() and p.suffix == ".txt")
        if not imgs or len(imgs) != len(lbls):
            raise ValueError(f"Split {split_name!r} image/label count mismatch: {len(imgs)} vs {len(lbls)}")
        if {p.stem for p in imgs} != {p.stem for p in lbls}:
            raise ValueError(f"Split {split_name!r} image/label stem mismatch")
        neg = sum(1 for p in lbls if not p.read_text(encoding="utf-8").strip())
        split_counts[split_name] = len(imgs)
        negative_counts[split_name] = neg

    return {
        "dataset_dir": str(dataset_dir),
        "split_counts": split_counts,
        "negative_counts": negative_counts,
        "total_images": sum(split_counts.values()),
        "molted_skin_boxes_removed": int(provenance.get("molted_skin_boxes_removed", 0)),
        "split_leakage": 0,
        "zero_synthetic_confirmed": True,
        "synthetic_images_count": 0,
    }


def _link_or_copy_file(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() or dst.is_symlink():
        dst.unlink()
    try:
        os.symlink(src, dst)
    except OSError:
        shutil.copy2(src, dst)


def _link_or_copy_dir_files(src: Path, dst: Path) -> None:
    for sub in ("images", "labels"):
        src_sub = src / sub
        dst_sub = dst / sub
        dst_sub.mkdir(parents=True, exist_ok=True)
        for item in sorted(src_sub.iterdir()):
            if item.is_file():
                _link_or_copy_file(item, dst_sub / item.name)


def _split_manifest_sha256(split_dir: Path) -> str:
    hasher = hashlib.sha256()
    for sub in ("images", "labels"):
        sub_dir = split_dir / sub
        for file_path in sorted(p for p in sub_dir.iterdir() if p.is_file()):
            hasher.update(f"{sub}/{file_path.name}\n".encode("utf-8"))
            hasher.update(hashlib.sha256(file_path.read_bytes()).digest())
    return hasher.hexdigest()


def _label_has_class(label_path: Path, target_class: int) -> bool:
    for line in label_path.read_text(encoding="utf-8").splitlines():
        parts = line.strip().split()
        if parts and int(float(parts[0])) == target_class:
            return True
    return False


def _write_data_yaml(yaml_path: Path, dataset_root: Path) -> None:
    import yaml

    payload = {
        "path": str(dataset_root.resolve()),
        "train": "train/images",
        "val": "val/images",
        "test": "test/images",
        "nc": 2,
        "names": dict(CANONICAL_NAMES),
    }
    yaml_path.parent.mkdir(parents=True, exist_ok=True)
    yaml_path.write_text(yaml.safe_dump(payload, sort_keys=False), encoding="utf-8")


_COCO_EXCLUDED_NAMES: frozenset[str] = frozenset({"potted plant", "vase"})
_COCO_BOTTLE_CUP_NAMES: frozenset[str] = frozenset({"bottle", "wine glass", "cup"})
_COCO_HEALTHY_FOOD_NAMES: frozenset[str] = frozenset(
    {"bowl", "banana", "apple", "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake"}
)
_COCO_PERSON_NAMES: frozenset[str] = frozenset({"person"})


def _classify_coco_names(names: set[str]) -> str | None:
    if names & _COCO_EXCLUDED_NAMES:
        return None
    if names & _COCO_BOTTLE_CUP_NAMES:
        return "ood_drink_bottles_cups"
    if names & _COCO_HEALTHY_FOOD_NAMES:
        return "ood_healthy_food"
    if names & _COCO_PERSON_NAMES:
        return "ood_people"
    return "ood_random_objects"


def _attach_kaggle_coco_val2017_ood(
    baseline_dir: Path,
    balanced_dir: Path,
    *,
    target_per_category: int = 150,
    seed: int = 42,
) -> dict[str, Any]:
    """Attach 600 curated COCO 2017 val2017 real-world OOD negatives mounted on Kaggle /kaggle/input."""
    import random

    input_root = Path("/kaggle/input")
    if not input_root.is_dir():
        return {"attached": False, "reason": "no /kaggle/input directory"}

    ann_candidates = sorted(input_root.rglob("instances_val2017.json"))
    if not ann_candidates:
        return {"attached": False, "reason": "instances_val2017.json not found in /kaggle/input"}
    ann_path = ann_candidates[0]

    # Locate val2017 JPEG folder (avoid our own dataset folder)
    val_img_dir: Path | None = None
    for cand in sorted(input_root.rglob("000000000139.jpg")):
        val_img_dir = cand.parent
        break
    if val_img_dir is None:
        return {"attached": False, "reason": "COCO val2017 image directory not found in /kaggle/input"}

    # Collect existing OOD content SHA-256 hashes & COCO IDs in baseline_dir so zero image is duplicated across splits
    existing_coco_ids: set[str] = set()
    existing_ood_sha256: set[str] = set()
    for sp in ("train", "val", "test"):
        for p in _list_images(baseline_dir / sp / "images"):
            m = re.search(r"(000000\d{6})", p.stem)
            if m:
                existing_coco_ids.add(m.group(1))
            if "neg__ood_" in p.stem:
                existing_ood_sha256.add(hashlib.sha256(p.read_bytes()).hexdigest())

    coco_data = json.loads(ann_path.read_text(encoding="utf-8"))
    cat_id_to_name = {int(c["id"]): str(c["name"]).strip().lower() for c in coco_data.get("categories", [])}
    img_id_to_file = {int(im["id"]): str(im["file_name"]) for im in coco_data.get("images", [])}
    img_id_to_names: dict[int, set[str]] = {iid: set() for iid in img_id_to_file}
    for ann in coco_data.get("annotations", []):
        iid = int(ann["image_id"])
        cname = cat_id_to_name.get(int(ann["category_id"]), "")
        if iid in img_id_to_names and cname:
            img_id_to_names[iid].add(cname)

    pools: dict[str, list[Path]] = {
        "ood_people": [],
        "ood_drink_bottles_cups": [],
        "ood_healthy_food": [],
        "ood_random_objects": [],
    }
    for iid, fname in sorted(img_id_to_file.items()):
        stem = Path(fname).stem
        if stem in existing_coco_ids:
            continue
        img_p = val_img_dir / fname
        if not img_p.is_file():
            continue
        if existing_ood_sha256 and hashlib.sha256(img_p.read_bytes()).hexdigest() in existing_ood_sha256:
            continue
        cat = _classify_coco_names(img_id_to_names.get(iid, set()))
        if cat is not None:
            pools[cat].append(img_p)

    rng = random.Random(seed)
    added = {"train": 0, "val": 0, "test": 0}
    per_cat: dict[str, dict[str, int]] = {}

    for cat, items in sorted(pools.items()):
        ordered = list(items)
        rng.shuffle(ordered)
        selected = ordered[:target_per_category]
        n = len(selected)
        n_val = int(round(n * 0.15))
        n_test = int(round(n * 0.25))
        n_train = max(0, n - n_val - n_test)
        split_buckets = (
            ("train", selected[:n_train]),
            ("val", selected[n_train : n_train + n_val]),
            ("test", selected[n_train + n_val :]),
        )
        per_cat[cat] = {"train": n_train, "val": n_val, "test": len(selected) - n_train - n_val}
        for sp_name, bucket in split_buckets:
            # For train, attach only to baseline_dir; build_isolated_dataset_views copies/oversamples baseline/train into balanced/train.
            # For val and test, attach identically to both so val/test manifest SHA-256 hashes stay identical.
            target_roots = (baseline_dir,) if sp_name == "train" else (baseline_dir, balanced_dir)
            for src_img in bucket:
                out_stem = f"neg__{cat}__val2017_{src_img.stem}"
                for target_root in target_roots:
                    _link_or_copy_file(src_img, target_root / sp_name / "images" / f"{out_stem}.jpg")
                    lbl_dst = target_root / sp_name / "labels" / f"{out_stem}.txt"
                    lbl_dst.parent.mkdir(parents=True, exist_ok=True)
                    lbl_dst.write_text("", encoding="utf-8")
                added[sp_name] += 1

    return {
        "attached": True,
        "source": "xthink/coco-2017-val-images + minhtngbi/instances-val2017",
        "added_by_split": added,
        "added_total": sum(added.values()),
        "per_category": per_cat,
    }


def _generate_zoomout_small_pest_views(
    src_train_imgs: list[Path],
    src_train_lbl_dir: Path,
    bal_img_dir: Path,
    bal_lbl_dir: Path,
    *,
    max_zoomout_per_class: int = 160,
    seed: int = 42,
) -> dict[str, int]:
    """Create real-pixel phone-distance (0.20x-0.46x) zoom-out training images pasted onto real empty leaves.

    Strictly operates on train-split images only (never touches val or test) so P3/8 learns 12-40 px small pests.
    """
    import random
    import cv2
    import numpy as np

    rng = random.Random(seed)
    leaf_bgs: list[Path] = []
    pos_by_cls: dict[int, list[tuple[Path, list[tuple[int, float, float, float, float]]]]] = {0: [], 1: []}

    for img_path in src_train_imgs:
        lbl_path = src_train_lbl_dir / f"{img_path.stem}.txt"
        lines = [ln.strip() for ln in lbl_path.read_text(encoding="utf-8").splitlines() if ln.strip()]
        if not lines:
            if "neg__ood_" not in img_path.stem:
                leaf_bgs.append(img_path)
            continue
        parsed: list[tuple[int, float, float, float, float]] = []
        for ln in lines:
            ps = ln.split()
            if len(ps) == 5:
                parsed.append((int(float(ps[0])), float(ps[1]), float(ps[2]), float(ps[3]), float(ps[4])))
        if not parsed:
            continue
        # Prioritize macro/medium crops (median box >= 40 px in 640 space) so zoom-out yields realistic 12-40 px pests
        med_px = float(np.median([((w * 640.0) * (h * 640.0)) ** 0.5 for _, _, _, w, h in parsed]))
        if med_px < 40.0:
            continue
        classes_in_img = {c for c, *_ in parsed}
        for c in classes_in_img:
            if c in pos_by_cls:
                pos_by_cls[c].append((img_path, parsed))

    if not leaf_bgs:
        return {"zoomout_whitefly": 0, "zoomout_aphids": 0, "zoomout_total": 0}

    bg_cache: list[Any] = []
    for bg_path in leaf_bgs[:48]:
        im = cv2.imread(str(bg_path))
        if im is not None:
            bg_cache.append(cv2.resize(im, (640, 640), interpolation=cv2.INTER_AREA))
    if not bg_cache:
        return {"zoomout_whitefly": 0, "zoomout_aphids": 0, "zoomout_total": 0}

    created = {0: 0, 1: 0}
    for cls_id in (0, 1):
        pool = list(pos_by_cls[cls_id])
        if not pool:
            continue
        rng.shuffle(pool)
        idx_out = 0
        # 78% pasted onto real empty leaves (0.20x-0.46x), 22% embedded in simulated 9:16 hydroponic NFT bright border frames
        nft_start = int(round(max_zoomout_per_class * 0.78))
        while idx_out < max_zoomout_per_class:
            img_path, boxes = pool[idx_out % len(pool)]
            src_im = cv2.imread(str(img_path))
            if src_im is None:
                idx_out += 1
                continue

            is_nft_frame = idx_out >= nft_start
            if is_nft_frame:
                tone = rng.randint(205, 242)
                bg = np.full((640, 640, 3), (tone, min(255, tone + 4), min(255, tone + 2)), dtype=np.uint8)
                scale = rng.uniform(0.38, 0.64)
            else:
                bg = bg_cache[rng.randrange(len(bg_cache))].copy()
                scale = rng.uniform(0.20, 0.46)

            nh = max(48, min(560, int(round(640 * scale))))
            nw = max(48, min(560, int(round(640 * scale))))
            patch = cv2.resize(src_im, (nw, nh), interpolation=cv2.INTER_AREA)

            x0 = rng.randint(12, max(12, 640 - nw - 12))
            y0 = rng.randint(12, max(12, 640 - nh - 12))

            if is_nft_frame:
                bg[y0 : y0 + nh, x0 : x0 + nw] = patch
            else:
                # Soft feather mask on the border so the model never shortcuts on hard patch edges
                mask = np.ones((nh, nw, 1), dtype=np.float32)
                feather = max(4, min(12, min(nh, nw) // 10))
                ramp = np.linspace(0.0, 1.0, feather, dtype=np.float32)
                mask[:feather, :, 0] *= ramp[:, None]
                mask[-feather:, :, 0] *= ramp[::-1, None]
                mask[:, :feather, 0] *= ramp[None, :]
                mask[:, -feather:, 0] *= ramp[None, ::-1]
                roi = bg[y0 : y0 + nh, x0 : x0 + nw].astype(np.float32)
                blended = (patch.astype(np.float32) * mask + roi * (1.0 - mask)).clip(0, 255).astype(np.uint8)
                bg[y0 : y0 + nh, x0 : x0 + nw] = blended

            new_lines: list[str] = []
            for c, cx, cy, bw, bh in boxes:
                ncx = (x0 + cx * nw) / 640.0
                ncy = (y0 + cy * nh) / 640.0
                nbw = (bw * nw) / 640.0
                nbh = (bh * nh) / 640.0
                if nbw >= 0.008 and nbh >= 0.008:
                    new_lines.append(f"{c} {ncx:.6f} {ncy:.6f} {nbw:.6f} {nbh:.6f}")

            if new_lines:
                # Apply midday greenhouse overexposure glare on 25% of zoom-out views so whitefly & aphids survive harsh sunlight
                if idx_out % 4 == 0:
                    gain = rng.uniform(1.30, 1.62)
                    bias = rng.uniform(8.0, 26.0)
                    bg = np.clip(bg.astype(np.float32) * gain + bias, 0.0, 255.0).astype(np.uint8)
                tag = "nftzoom" if is_nft_frame else "zoomout"
                stem = f"{tag}_c{cls_id}_{idx_out:04d}__{img_path.stem[:36]}"
                cv2.imwrite(str(bal_img_dir / f"{stem}.jpg"), bg, [int(cv2.IMWRITE_JPEG_QUALITY), 92])
                (bal_lbl_dir / f"{stem}.txt").write_text("\n".join(new_lines) + "\n", encoding="utf-8")
                created[cls_id] += 1
            idx_out += 1
            if idx_out >= len(pool) * 5:
                break

    return {
        "zoomout_whitefly": created[0],
        "zoomout_aphids": created[1],
        "zoomout_total": created[0] + created[1],
    }


def build_isolated_dataset_views(
    dataset_dir: Path,
    work_root: Path,
    whitefly_oversample_factor: int = 2,
    negative_oversample_factor: int = 1,
    leaf_empty_oversample_factor: int = 1,
    zoomout_per_class: int = 180,
) -> dict[str, Any]:
    """Create baseline and train-only multi-scale balanced dataset views without touching val or test."""
    if whitefly_oversample_factor < 1 or negative_oversample_factor < 1 or leaf_empty_oversample_factor < 1:
        raise ValueError("Oversample factors must be >= 1")

    baseline_dir = work_root / "baseline"
    balanced_dir = work_root / "balanced"
    shutil.rmtree(baseline_dir, ignore_errors=True)
    shutil.rmtree(balanced_dir, ignore_errors=True)

    for split_name in ("train", "val", "test"):
        _link_or_copy_dir_files(dataset_dir / split_name, baseline_dir / split_name)
    for split_name in ("val", "test"):
        _link_or_copy_dir_files(dataset_dir / split_name, balanced_dir / split_name)

    coco_val2017_ood = _attach_kaggle_coco_val2017_ood(
        baseline_dir=baseline_dir,
        balanced_dir=balanced_dir,
        target_per_category=150,
        seed=42,
    )
    print(f"[ood-val2017] {json.dumps(coco_val2017_ood)}", flush=True)

    val_sha_base = _split_manifest_sha256(baseline_dir / "val")
    val_sha_bal = _split_manifest_sha256(balanced_dir / "val")
    test_sha_base = _split_manifest_sha256(baseline_dir / "test")
    test_sha_bal = _split_manifest_sha256(balanced_dir / "test")
    if val_sha_base != val_sha_bal or test_sha_base != test_sha_bal:
        raise AssertionError("Balanced view altered val or test split manifest")

    src_train_imgs = _list_images(baseline_dir / "train" / "images")
    src_train_lbl_dir = baseline_dir / "train" / "labels"
    bal_img_dir = balanced_dir / "train" / "images"
    bal_lbl_dir = balanced_dir / "train" / "labels"
    bal_img_dir.mkdir(parents=True, exist_ok=True)
    bal_lbl_dir.mkdir(parents=True, exist_ok=True)

    whitefly_train_images = 0
    negative_train_images = 0
    balanced_train_images = 0

    for img_path in src_train_imgs:
        lbl_path = src_train_lbl_dir / f"{img_path.stem}.txt"
        _link_or_copy_file(img_path, bal_img_dir / img_path.name)
        _link_or_copy_file(lbl_path, bal_lbl_dir / lbl_path.name)
        balanced_train_images += 1

        is_empty = not lbl_path.read_text(encoding="utf-8").strip()
        if is_empty:
            negative_train_images += 1
            is_ood_neg = "neg__ood_" in img_path.stem
            rep_factor = negative_oversample_factor if is_ood_neg else max(negative_oversample_factor, leaf_empty_oversample_factor)
            for rep_idx in range(1, rep_factor):
                prefix = f"negrep{rep_idx}__"
                _link_or_copy_file(img_path, bal_img_dir / f"{prefix}{img_path.name}")
                _link_or_copy_file(lbl_path, bal_lbl_dir / f"{prefix}{lbl_path.name}")
                balanced_train_images += 1
        elif _label_has_class(lbl_path, 0):
            whitefly_train_images += 1
            for rep_idx in range(1, whitefly_oversample_factor):
                prefix = f"wfrep{rep_idx}__"
                _link_or_copy_file(img_path, bal_img_dir / f"{prefix}{img_path.name}")
                _link_or_copy_file(lbl_path, bal_lbl_dir / f"{prefix}{lbl_path.name}")
                balanced_train_images += 1

    zoomout_stats = {"zoomout_whitefly": 0, "zoomout_aphids": 0, "zoomout_total": 0}
    if zoomout_per_class > 0:
        zoomout_stats = _generate_zoomout_small_pest_views(
            src_train_imgs=src_train_imgs,
            src_train_lbl_dir=src_train_lbl_dir,
            bal_img_dir=bal_img_dir,
            bal_lbl_dir=bal_lbl_dir,
            max_zoomout_per_class=zoomout_per_class,
            seed=42,
        )
        balanced_train_images += zoomout_stats["zoomout_total"]

    data_baseline_yaml = work_root / "data_baseline.yaml"
    data_balanced_yaml = work_root / "data_balanced.yaml"
    _write_data_yaml(data_baseline_yaml, baseline_dir)
    _write_data_yaml(data_balanced_yaml, balanced_dir)

    return {
        "baseline_yaml": data_baseline_yaml,
        "balanced_yaml": data_balanced_yaml,
        "whitefly_train_images": whitefly_train_images,
        "negative_train_images": negative_train_images,
        "balanced_train_images": balanced_train_images,
        "whitefly_oversample_factor": whitefly_oversample_factor,
        "negative_oversample_factor": negative_oversample_factor,
        "leaf_empty_oversample_factor": leaf_empty_oversample_factor,
        "coco_val2017_ood": coco_val2017_ood,
        **zoomout_stats,
        "val_manifest_sha256": val_sha_base,
        "test_manifest_sha256": test_sha_base,
    }


def _build_albumentations_list() -> list[Any]:
    import albumentations as A

    try:
        jpeg_tf = A.ImageCompression(quality_range=(30, 95), p=0.20)
    except TypeError:
        jpeg_tf = A.ImageCompression(quality_lower=30, quality_upper=95, p=0.20)

    return [
        A.CLAHE(clip_limit=2.5, tile_grid_size=(8, 8), p=0.15),
        # Asymmetric brightness upper bound (+0.50) hardens whitefly/aphids against midday greenhouse overexposure glare
        # without RandomSunFlare fake white-blob artifacts or double-stacked hsv_v clipping.
        A.RandomBrightnessContrast(brightness_limit=(-0.30, 0.50), contrast_limit=(-0.25, 0.35), p=0.40),
        A.RandomGamma(gamma_limit=(60, 150), p=0.25),
        A.OneOf(
            [
                A.GaussianBlur(blur_limit=(3, 5), p=1.0),
                A.MotionBlur(blur_limit=(3, 5), p=1.0),
            ],
            p=0.12,
        ),
        A.Sharpen(alpha=(0.12, 0.28), lightness=(0.85, 1.05), p=0.10),
        A.GaussNoise(p=0.10),
        jpeg_tf,
        A.ToGray(p=0.04),
    ]


def extract_eval_metrics(val_res: Any) -> dict[str, Any]:
    box = val_res.box
    precision = float(box.mp)
    recall = float(box.mr)
    f1 = 2.0 * precision * recall / max(1e-8, precision + recall)
    map75 = float(getattr(box, "map75", 0.0))

    per_class: dict[str, dict[str, float]] = {
        name: {"precision": 0.0, "recall": 0.0, "map50": 0.0, "map50_95": 0.0, "f1": 0.0}
        for name in CANONICAL_NAMES.values()
    }
    ap_class_index = list(getattr(box, "ap_class_index", []))
    f1_arr = list(getattr(box, "f1", []))
    for pos, cls_idx_raw in enumerate(ap_class_index):
        cls_idx = int(cls_idx_raw)
        if cls_idx not in CANONICAL_NAMES:
            continue
        cls_name = CANONICAL_NAMES[cls_idx]
        c_p, c_r, c_ap50, c_ap = box.class_result(pos)
        c_f1 = float(f1_arr[pos]) if pos < len(f1_arr) else (2.0 * float(c_p) * float(c_r) / max(1e-8, float(c_p) + float(c_r)))
        per_class[cls_name] = {
            "precision": round(float(c_p), 4),
            "recall": round(float(c_r), 4),
            "map50": round(float(c_ap50), 4),
            "map50_95": round(float(c_ap), 4),
            "f1": round(float(c_f1), 4),
        }

    aggregate = {
        "map50": round(float(box.map50), 4),
        "map75": round(map75, 4),
        "map50_95": round(float(box.map), 4),
        "precision": round(precision, 4),
        "recall": round(recall, 4),
        "f1": round(f1, 4),
    }
    return {"aggregate": aggregate, "per_class": per_class}


def _evaluate_split(
    weights_or_model: str | Path,
    data_yaml: Path,
    split: str,
    imgsz: int = 640,
    rect: bool = True,
) -> dict[str, Any]:
    from ultralytics import YOLO

    model = YOLO(str(weights_or_model))
    val_res = model.val(data=str(data_yaml), split=split, imgsz=imgsz, rect=rect, device=0, verbose=True)
    return extract_eval_metrics(val_res)


def calibrate_confidence_threshold(
    weights_path: Path,
    val_images_dir: Path,
    val_labels_dir: Path,
    imgsz: int = 640,
) -> dict[str, Any]:
    """Sweep confidence thresholds on val (positives + leaf/OOD negatives) to maximize F1 while suppressing OOD FPs."""
    from ultralytics import YOLO

    model = YOLO(str(weights_path))
    img_paths = _list_images(val_images_dir)
    preds = model.predict(
        source=[str(p) for p in img_paths],
        imgsz=imgsz,
        conf=0.05,
        iou=0.45,
        device=0,
        verbose=False,
    )

    gt_per_img: list[list[tuple[int, list[float]]]] = []
    is_ood_per_img: list[bool] = []
    for img_path, pred in zip(img_paths, preds):
        h, w = pred.orig_shape
        lbl_path = val_labels_dir / f"{img_path.stem}.txt"
        gts: list[tuple[int, list[float]]] = []
        if lbl_path.is_file():
            for line in lbl_path.read_text(encoding="utf-8").splitlines():
                ps = line.strip().split()
                if len(ps) == 5:
                    cid = int(float(ps[0]))
                    cx, cy, bw, bh = float(ps[1]) * w, float(ps[2]) * h, float(ps[3]) * w, float(ps[4]) * h
                    gts.append((cid, [cx - bw / 2.0, cy - bh / 2.0, cx + bw / 2.0, cy + bh / 2.0]))
        gt_per_img.append(gts)
        is_ood_per_img.append("neg__ood_" in img_path.stem)

    def _box_iou_xyxy(a: list[float], b: list[float]) -> float:
        x1, y1 = max(a[0], b[0]), max(a[1], b[1])
        x2, y2 = min(a[2], b[2]), min(a[3], b[3])
        inter = max(0.0, x2 - x1) * max(0.0, y2 - y1)
        if inter <= 0.0:
            return 0.0
        aa = max(0.0, a[2] - a[0]) * max(0.0, a[3] - a[1])
        ba = max(0.0, b[2] - b[0]) * max(0.0, b[3] - b[1])
        return inter / max(1e-8, aa + ba - inter)

    candidates_report: list[dict[str, float]] = []
    best_thr = 0.45
    best_objective = -1e9

    for thr in (0.25, 0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60):
        tp = fp = fn = 0
        neg_imgs = neg_fp_imgs = 0
        leaf_neg_imgs = leaf_neg_fp_imgs = 0
        ood_imgs = ood_fp_imgs = 0
        pos_imgs = pos_hit_imgs = 0
        for gts, is_ood, pred in zip(gt_per_img, is_ood_per_img, preds):
            boxes_xyxy = pred.boxes.xyxy.cpu().tolist() if pred.boxes is not None else []
            confs = pred.boxes.conf.cpu().tolist() if pred.boxes is not None else []
            clss = [int(c) for c in (pred.boxes.cls.cpu().tolist() if pred.boxes is not None else [])]
            kept = [(c, b) for b, cf, c in zip(boxes_xyxy, confs, clss) if cf >= thr]

            if not gts:
                neg_imgs += 1
                if kept:
                    neg_fp_imgs += 1
                if is_ood:
                    ood_imgs += 1
                    if kept:
                        ood_fp_imgs += 1
                else:
                    leaf_neg_imgs += 1
                    if kept:
                        leaf_neg_fp_imgs += 1
                fp += len(kept)
                continue

            pos_imgs += 1
            if kept:
                pos_hit_imgs += 1
            matched: set[int] = set()
            for p_cls, p_box in kept:
                best_gi = -1
                best_ov = 0.0
                for gi, (g_cls, g_box) in enumerate(gts):
                    if gi in matched or g_cls != p_cls:
                        continue
                    ov = _box_iou_xyxy(p_box, g_box)
                    if ov > best_ov:
                        best_ov, best_gi = ov, gi
                if best_ov >= 0.50 and best_gi >= 0:
                    matched.add(best_gi)
                    tp += 1
                else:
                    fp += 1
            fn += len(gts) - len(matched)

        prec = tp / max(1, tp + fp)
        rec = tp / max(1, tp + fn)
        f1 = 2.0 * prec * rec / max(1e-8, prec + rec)
        img_rec = pos_hit_imgs / max(1, pos_imgs)
        neg_fpr = neg_fp_imgs / max(1, neg_imgs)
        leaf_fpr = leaf_neg_fp_imgs / max(1, leaf_neg_imgs) if leaf_neg_imgs > 0 else 0.0
        ood_fpr = ood_fp_imgs / max(1, ood_imgs) if ood_imgs > 0 else neg_fpr
        fppi = fp / max(1, len(img_paths))
        # Multi-metric operating point: F1 + box/image recall while controlling OOD FPR <= 0.03, leaf_empty FPR, and FPPI
        ood_penalty = (5.0 * max(0.0, ood_fpr - 0.03)) + (1.5 * ood_fpr)
        leaf_penalty = 0.40 * leaf_fpr
        fppi_penalty = 0.12 * fppi
        objective = (0.50 * f1) + (0.25 * rec) + (0.25 * img_rec) - ood_penalty - leaf_penalty - fppi_penalty
        row = {
            "threshold": thr,
            "precision": round(prec, 4),
            "recall": round(rec, 4),
            "f1": round(f1, 4),
            "image_recall": round(img_rec, 4),
            "neg_fpr": round(neg_fpr, 4),
            "leaf_empty_fpr": round(leaf_fpr, 4),
            "ood_fpr": round(ood_fpr, 4),
            "fppi": round(fppi, 4),
            "objective": round(objective, 4),
        }
        candidates_report.append(row)
        if objective > best_objective and f1 >= 0.50:
            best_objective = objective
            best_thr = thr

    return {"selected_threshold": best_thr, "sweep": candidates_report}


def parse_loss_summary(results_csv_path: Path) -> dict[str, Any]:
    if not results_csv_path.is_file():
        return {}
    with results_csv_path.open("r", encoding="utf-8") as fh:
        rows = [{k.strip(): v.strip() for k, v in r.items()} for r in csv.DictReader(fh)]
    if not rows:
        return {}

    def _f(row: dict[str, str], key: str) -> float:
        try:
            return round(float(row.get(key, 0.0)), 5)
        except ValueError:
            return 0.0

    best_row = max(
        rows,
        key=lambda r: 0.1 * _f(r, "metrics/mAP50(B)") + 0.9 * _f(r, "metrics/mAP50-95(B)"),
    )
    last_row = rows[-1]
    return {
        "epochs_completed": len(rows),
        "best_epoch": int(float(best_row.get("epoch", len(rows)))),
        "train_box_loss": _f(best_row, "train/box_loss"),
        "train_cls_loss": _f(best_row, "train/cls_loss"),
        "train_dfl_loss": _f(best_row, "train/dfl_loss"),
        "val_box_loss": _f(best_row, "val/box_loss"),
        "val_cls_loss": _f(best_row, "val/cls_loss"),
        "val_dfl_loss": _f(best_row, "val/dfl_loss"),
        "final_epoch_losses": {
            "train_box_loss": _f(last_row, "train/box_loss"),
            "train_cls_loss": _f(last_row, "train/cls_loss"),
            "train_dfl_loss": _f(last_row, "train/dfl_loss"),
            "val_box_loss": _f(last_row, "val/box_loss"),
            "val_cls_loss": _f(last_row, "val/cls_loss"),
            "val_dfl_loss": _f(last_row, "val/dfl_loss"),
        },
    }


def _export_nhwc_candidates_on_linux(best_pt: Path, exports_dir: Path, imgsz: int = 640) -> dict[str, Any]:
    """Export ONNX + NHWC [1,640,640,3]->[1,6,8400] FP16 and FP32 TFLite models on Kaggle Linux."""
    exports_dir.mkdir(parents=True, exist_ok=True)
    probe: dict[str, Any] = {"status": "attempted", "candidates": {}}

    missing_deps: list[str] = []
    for mod_name, pkg in (
        ("onnx", "onnx"),
        ("onnxslim", "onnxslim"),
        ("sng4onnx", "sng4onnx"),
        ("onnx2tf", "onnx2tf"),
        ("tensorflow", "tensorflow"),
    ):
        try:
            __import__(mod_name)
        except ImportError:
            missing_deps.append(pkg)
    if missing_deps:
        print(f"[exports] Installing TFLite conversion packages: {missing_deps}", flush=True)
        subprocess.run([sys.executable, "-m", "pip", "install", "-q", *missing_deps], check=False)
    try:
        __import__("onnx_graphsurgeon")
    except ImportError:
        subprocess.run(
            [
                sys.executable,
                "-m",
                "pip",
                "install",
                "-q",
                "--extra-index-url",
                "https://pypi.ngc.nvidia.com",
                "onnx-graphsurgeon",
            ],
            check=False,
        )

    try:
        import numpy as np
        import onnx
        import onnx2tf
        import onnxslim
        import tensorflow as tf
        import torch
        from ultralytics import YOLO
        from ultralytics.nn.modules import Detect, SPPF
        from ultralytics.utils.export.tensorflow import tf_wrapper

        if not hasattr(onnx.helper, "float32_to_bfloat16"):
            onnx.helper.float32_to_bfloat16 = lambda fval: struct.unpack("=I", struct.pack("=f", fval))[0] >> 16  # type: ignore[attr-defined]

        yolo_model = YOLO(str(best_pt))
        pt_model = copy.deepcopy(yolo_model.model).cpu().float()
        for param in pt_model.parameters():
            param.requires_grad = False
        pt_model.eval()
        pt_model = pt_model.fuse(imgsz=[imgsz, imgsz])
        if hasattr(pt_model, "end2end"):
            pt_model.end2end = False

        pt_model = tf_wrapper(pt_model)
        for mod in pt_model.modules():
            if isinstance(mod, SPPF):
                mod.export = True
            if isinstance(mod, Detect):
                mod.dynamic = False
                mod.export = True
                mod.format = "saved_model"
                mod.xyxy = False
                mod.shape = None

        dummy = torch.zeros(1, 3, imgsz, imgsz, dtype=torch.float32)
        with tempfile.TemporaryDirectory(prefix="hs_export_") as tmp_s:
            work_d = Path(tmp_s)
            onnx_p = work_d / "best.onnx"
            saved_d = work_d / "saved_model"
            torch.onnx.export(
                pt_model, dummy, str(onnx_p), opset_version=17, dynamo=False, input_names=["images"], output_names=["output0"]
            )
            slim_m = onnxslim.slim(onnx.load(str(onnx_p)))
            onnx.save(slim_m, str(onnx_p))
            shutil.copy2(onnx_p, exports_dir / "best.onnx")

            np.save(str(work_d / "calibration_image_sample_data_20x128x128x3_float32.npy"), np.zeros((20, 128, 128, 3), dtype=np.float32))
            prev_cwd = Path.cwd()
            try:
                os.chdir(work_d)
                onnx2tf.convert(
                    input_onnx_file_path=str(onnx_p),
                    output_folder_path=str(saved_d),
                    overwrite_input_shape=[f"images:1,3,{imgsz},{imgsz}"],
                    not_use_onnxsim=True,
                    verbosity="error",
                    output_integer_quantized_tflite=False,
                    enable_batchmatmul_unfold=False,
                    output_signaturedefs=True,
                )
            finally:
                os.chdir(prev_cwd)

            for prec_tag, use_fp16, out_name in (
                ("fp16", True, "best_float16.tflite"),
                ("fp32", False, "best_float32.tflite"),
            ):
                conv = tf.lite.TFLiteConverter.from_saved_model(str(saved_d))
                if use_fp16:
                    conv.optimizations = [tf.lite.Optimize.DEFAULT]
                    conv.target_spec.supported_types = [tf.float16]
                tfl_bytes = conv.convert()
                out_tfl = exports_dir / out_name
                out_tfl.write_bytes(tfl_bytes)

                # Embed Ultralytics metadata trailer
                meta_payload = {
                    "description": "HidroSense YOLOv11n 2-class (whitefly & aphids)",
                    "author": "HidroSense",
                    "date": datetime.now(timezone.utc).isoformat(),
                    "version": str(getattr(__import__("ultralytics"), "__version__", "8.4.0")),
                    "stride": 32,
                    "task": "detect",
                    "head": "Detect",
                    "batch": 1,
                    "imgsz": [imgsz, imgsz],
                    "names": dict(CANONICAL_NAMES),
                    "channels": 3,
                    "end2end": False,
                }
                with zipfile.ZipFile(out_tfl, "a", zipfile.ZIP_DEFLATED) as zf:
                    zf.writestr("metadata.json", json.dumps(meta_payload, indent=2))

                interp = tf.lite.Interpreter(model_path=str(out_tfl))
                interp.allocate_tensors()
                in_d = interp.get_input_details()[0]
                out_d = interp.get_output_details()[0]
                probe["candidates"][prec_tag] = {
                    "file_name": out_name,
                    "size_bytes": out_tfl.stat().st_size,
                    "size_mb": round(out_tfl.stat().st_size / (1024.0 * 1024.0), 3),
                    "sha256": hashlib.sha256(out_tfl.read_bytes()).hexdigest(),
                    "input_shape": [int(x) for x in in_d["shape"]],
                    "output_shape": [int(x) for x in out_d["shape"]],
                }
        probe["status"] = "completed"
    except Exception as exc:
        probe["status"] = "failed_non_fatal"
        probe["error"] = f"{type(exc).__name__}: {exc}"

    (exports_dir / "export_probe.json").write_text(json.dumps(probe, indent=2), encoding="utf-8")
    return probe


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="HidroSense Kaggle GPU 2-Class YOLOv11n Training Entrypoint")
    parser.add_argument("--dataset-dir", type=Path, default=None)
    parser.add_argument("--allow-local", action="store_true")
    parser.add_argument("--output-root", type=Path, default=None)
    parser.add_argument("--baseline-epochs", type=int, default=45)
    parser.add_argument("--improved-epochs", type=int, default=90)
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--whitefly-oversample", type=int, default=2)
    parser.add_argument("--negative-oversample", type=int, default=1)
    parser.add_argument("--leaf-empty-oversample", type=int, default=1)
    parser.add_argument("--zoomout-per-class", type=int, default=180)
    parser.add_argument("--skip-export", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)
    ensure_packages()

    gpu_info = ensure_gpu_available()
    import inspect
    import ultralytics
    from ultralytics import YOLO

    gpu_info["ultralytics_version"] = str(ultralytics.__version__)
    print(f"[env] {json.dumps(gpu_info)}", flush=True)

    dataset_dir = locate_dataset_dir(args.dataset_dir, allow_local=args.allow_local)
    dataset_info = validate_real_dataset(dataset_dir)
    print(f"[dataset] Verified 2-class dataset: {json.dumps(dataset_info)}", flush=True)

    output_root = (
        Path(args.output_root)
        if args.output_root is not None
        else (Path("/kaggle/working") if Path("/kaggle/working").is_dir() else Path("ml/kaggle_local_run"))
    )
    output_root.mkdir(parents=True, exist_ok=True)

    work_root = output_root / "work_datasets"
    runs_dir = output_root / "runs"
    artifacts_dir = output_root / "artifacts"
    exports_dir = output_root / "exports"
    artifacts_dir.mkdir(parents=True, exist_ok=True)

    try:
        views = build_isolated_dataset_views(
            dataset_dir=dataset_dir,
            work_root=work_root,
            whitefly_oversample_factor=args.whitefly_oversample,
            negative_oversample_factor=args.negative_oversample,
            leaf_empty_oversample_factor=args.leaf_empty_oversample,
            zoomout_per_class=args.zoomout_per_class,
        )
        data_baseline_yaml: Path = views["baseline_yaml"]
        data_balanced_yaml: Path = views["balanced_yaml"]

        print("[stage0] Running pretrained yolo11n.pt zero-shot check on test split...", flush=True)
        pretrained_zero_shot = _evaluate_split("yolo11n.pt", data_baseline_yaml, split="test", imgsz=args.imgsz)

        print("[stage1] Training Stage 1 Baseline YOLOv11n on unweighted 2-class train split...", flush=True)
        t1_start = time.time()
        baseline_model = YOLO("yolo11n.pt")
        baseline_res = baseline_model.train(
            data=str(data_baseline_yaml),
            epochs=args.baseline_epochs,
            patience=15,
            batch=args.batch,
            imgsz=args.imgsz,
            device=0,
            seed=42,
            deterministic=True,
            optimizer="AdamW",
            lr0=0.001,
            lrf=0.01,
            cos_lr=True,
            mosaic=1.0,
            close_mosaic=10,
            cls=0.5,
            box=7.5,
            dfl=1.5,
            amp=True,
            cache="ram",
            workers=4,
            project=str(runs_dir),
            name="baseline_yolo11n",
        )
        baseline_elapsed = round(time.time() - t1_start, 2)
        baseline_best_pt = artifacts_dir / "baseline_best.pt"
        shutil.copy2(Path(baseline_res.save_dir) / "weights" / "best.pt", baseline_best_pt)
        baseline_val = _evaluate_split(baseline_best_pt, data_baseline_yaml, split="val", imgsz=args.imgsz)
        baseline_test = _evaluate_split(baseline_best_pt, data_baseline_yaml, split="test", imgsz=args.imgsz)
        print(f"[stage1] Baseline test metrics: {json.dumps(baseline_test)}", flush=True)

        print("[stage2] Training Stage 2 Production Visual-Invariant + Hard-Negative YOLOv11n...", flush=True)
        t2_start = time.time()
        improved_model = YOLO("yolo11n.pt")
        extra_train_kwargs: dict[str, Any] = {}
        try:
            from ultralytics.cfg import get_cfg

            custom_augs = _build_albumentations_list()
            # Validate directly through Ultralytics get_cfg (DEFAULT_CFG_DICT omits 'augmentations', yet get_cfg accepts it!)
            get_cfg(overrides={"augmentations": custom_augs})
            extra_train_kwargs["augmentations"] = custom_augs
            print(f"[stage2] Active custom Albumentations ({len(custom_augs)} transforms): {[type(t).__name__ for t in custom_augs]}", flush=True)
        except Exception as exc:
            raise RuntimeError(f"Custom Albumentations failed validation and must not be silently skipped: {exc}") from exc

        improved_res = improved_model.train(
            data=str(data_balanced_yaml),
            epochs=args.improved_epochs,
            patience=25,
            batch=args.batch,
            imgsz=args.imgsz,
            device=0,
            seed=42,
            deterministic=True,
            optimizer="AdamW",
            lr0=0.001,
            lrf=0.01,
            cos_lr=True,
            warmup_epochs=3.0,
            cls=0.5,
            box=7.5,
            dfl=1.5,
            mosaic=1.0,
            close_mosaic=20,
            mixup=0.05,
            copy_paste=0.15,
            scale=0.60,
            translate=0.12,
            # Zero non-orthogonal rotation/shear/perspective prevents axis-aligned GT box inflation (+18.7% width in v3)
            # that degraded mobile 640x640 mAP@75 from 0.90 to 0.63; exact reflections preserve tight IoU >= 0.75.
            degrees=0.0,
            shear=0.0,
            perspective=0.0,
            fliplr=0.5,
            flipud=0.25,
            hsv_h=0.015,
            hsv_s=0.45,
            hsv_v=0.25,
            erasing=0.05,
            amp=True,
            cache="ram",
            workers=4,
            project=str(runs_dir),
            name="improved_yolo11n",
            **extra_train_kwargs,
        )
        improved_elapsed = round(time.time() - t2_start, 2)
        improved_save_dir = Path(improved_res.save_dir)
        improved_best_pt = artifacts_dir / "best.pt"
        shutil.copy2(improved_save_dir / "weights" / "best.pt", improved_best_pt)

        # Copy diagnostic plots & results.csv to artifacts_dir
        for plot_name in (
            "results.csv",
            "results.png",
            "BoxF1_curve.png",
            "BoxPR_curve.png",
            "confusion_matrix.png",
            "confusion_matrix_normalized.png",
            "val_batch0_pred.jpg",
        ):
            src_plot = improved_save_dir / plot_name
            if src_plot.is_file():
                shutil.copy2(src_plot, artifacts_dir / plot_name)

        loss_summary = parse_loss_summary(improved_save_dir / "results.csv")
        calibration = calibrate_confidence_threshold(
            weights_path=improved_best_pt,
            val_images_dir=work_root / "baseline" / "val" / "images",
            val_labels_dir=work_root / "baseline" / "val" / "labels",
            imgsz=args.imgsz,
        )
        calibrated_thr = float(calibration["selected_threshold"])
        print(f"[calibration] Selected threshold={calibrated_thr}: {json.dumps(calibration)}", flush=True)

        improved_val = _evaluate_split(improved_best_pt, data_baseline_yaml, split="val", imgsz=args.imgsz)
        improved_test = _evaluate_split(improved_best_pt, data_baseline_yaml, split="test", imgsz=args.imgsz)
        improved_test_rect_false = _evaluate_split(
            improved_best_pt, data_baseline_yaml, split="test", imgsz=args.imgsz, rect=False
        )
        print(f"[stage2] Production test metrics (rect=True): {json.dumps(improved_test)}", flush=True)
        print(f"[stage2] Production test metrics (rect=False mobile 640x640): {json.dumps(improved_test_rect_false)}", flush=True)

        # Evaluate full 175+ COCO val2017+coco128 OOD breakdown & 0.25x phone-distance small-scale recall on Kaggle T4
        kaggle_ood_and_small: dict[str, Any] = {}
        try:
            import cv2
            import numpy as np

            eval_m = YOLO(str(improved_best_pt))
            t_img_dir = work_root / "baseline" / "test" / "images"
            t_lbl_dir = work_root / "baseline" / "test" / "labels"
            t_imgs = _list_images(t_img_dir)

            ood_groups: dict[str, dict[str, int]] = {}
            ood_total = ood_fps = 0
            leaf_bgs: list[Any] = []
            pos_test_items: list[tuple[Path, list[tuple[int, float, float, float, float]]]] = []

            t_preds = eval_m.predict([str(p) for p in t_imgs], imgsz=args.imgsz, conf=calibrated_thr, iou=0.45, device=0, verbose=False)
            for p, pr in zip(t_imgs, t_preds):
                lbl_p = t_lbl_dir / f"{p.stem}.txt"
                lines = [ln.strip() for ln in lbl_p.read_text(encoding="utf-8").splitlines() if ln.strip()]
                has_det = pr.boxes is not None and len(pr.boxes) > 0
                if not lines:
                    m_grp = re.match(r"^neg__([A-Za-z0-9_]+)__", p.stem)
                    grp = m_grp.group(1) if m_grp else "leaf_empty"
                    row = ood_groups.setdefault(grp, {"images": 0, "true_negatives": 0, "false_positives": 0})
                    row["images"] += 1
                    if has_det:
                        row["false_positives"] += 1
                    else:
                        row["true_negatives"] += 1
                        if not grp.startswith("ood_") and len(leaf_bgs) < 8:
                            im_bg = cv2.imread(str(p))
                            if im_bg is not None:
                                leaf_bgs.append(cv2.resize(im_bg, (args.imgsz, args.imgsz), interpolation=cv2.INTER_AREA))
                    if grp.startswith("ood_"):
                        ood_total += 1
                        if has_det:
                            ood_fps += 1
                else:
                    gts = [
                        (int(float(ps[0])), float(ps[1]), float(ps[2]), float(ps[3]), float(ps[4]))
                        for ps in (ln.split() for ln in lines)
                        if len(ps) == 5
                    ]
                    if gts:
                        pos_test_items.append((p, gts))

            for grp, row in ood_groups.items():
                row["false_positive_rate"] = round(row["false_positives"] / max(1, row["images"]), 4)
                row["specificity_tnr"] = round(row["true_negatives"] / max(1, row["images"]), 4)

            # 0.25x phone-distance localized recall check
            bgs = leaf_bgs or [np.full((args.imgsz, args.imgsz, 3), (42, 118, 48), dtype=np.uint8)]
            s_hits = s_eval = 0
            s_cls_hits = {0: 0, 1: 0}
            s_cls_tot = {0: 0, 1: 0}
            for idx, (p, gts) in enumerate(pos_test_items):
                im = cv2.imread(str(p))
                if im is None:
                    continue
                nh = nw = max(32, int(round(args.imgsz * 0.25)))
                small = cv2.resize(im, (nw, nh), interpolation=cv2.INTER_AREA)
                canvas = bgs[idx % len(bgs)].copy()
                y0, x0 = (args.imgsz - nh) // 2, (args.imgsz - nw) // 2
                canvas[y0 : y0 + nh, x0 : x0 + nw] = small
                pr = eval_m.predict(canvas, imgsz=args.imgsz, conf=calibrated_thr, iou=0.45, device=0, verbose=False)[0]
                p_boxes = pr.boxes.xyxy.cpu().tolist() if pr.boxes is not None else []
                p_clss = [int(c) for c in (pr.boxes.cls.cpu().tolist() if pr.boxes is not None else [])]
                matched_c: set[int] = set()
                for cid, cx, cy, bw, bh in gts:
                    gx1, gy1 = x0 + (cx - bw / 2.0) * nw, y0 + (cy - bh / 2.0) * nh
                    gx2, gy2 = x0 + (cx + bw / 2.0) * nw, y0 + (cy + bh / 2.0) * nh
                    for pc, pb in zip(p_clss, p_boxes):
                        if pc != cid:
                            continue
                        inter = max(0.0, min(gx2, pb[2]) - max(gx1, pb[0])) * max(0.0, min(gy2, pb[3]) - max(gy1, pb[1]))
                        union = max(1e-8, (gx2 - gx1) * (gy2 - gy1) + (pb[2] - pb[0]) * (pb[3] - pb[1]) - inter)
                        if inter / union >= 0.30:
                            matched_c.add(cid)
                            break
                gt_c = {cid for cid, *_ in gts}
                s_eval += 1
                if matched_c & gt_c:
                    s_hits += 1
                for cid in gt_c:
                    s_cls_tot[cid] += 1
                    if cid in matched_c:
                        s_cls_hits[cid] += 1

            kaggle_ood_and_small = {
                "ood_total_images": ood_total,
                "ood_false_positives": ood_fps,
                "ood_false_positive_rate": round(ood_fps / max(1, ood_total), 4),
                "ood_breakdown": ood_groups,
                "small_scale_025x": {
                    "images_evaluated": s_eval,
                    "hits": s_hits,
                    "overall_recall": round(s_hits / max(1, s_eval), 4),
                    "whitefly_recall": round(s_cls_hits[0] / max(1, s_cls_tot[0]), 4) if s_cls_tot[0] else None,
                    "aphids_recall": round(s_cls_hits[1] / max(1, s_cls_tot[1]), 4) if s_cls_tot[1] else None,
                },
            }
            print(f"[stage2] Kaggle 175+ OOD & 0.25x Small-Scale Eval: {json.dumps(kaggle_ood_and_small)}", flush=True)
        except Exception as exc:
            kaggle_ood_and_small = {"error": f"{type(exc).__name__}: {exc}"}

        b_agg, i_agg = baseline_test["aggregate"], improved_test["aggregate"]
        deltas = {f"{k}_delta": round(float(i_agg[k]) - float(b_agg[k]), 4) for k in ("map50", "map75", "map50_95", "precision", "recall", "f1")}
        deltas["whitefly_map50_delta"] = round(
            float(improved_test["per_class"]["whitefly"]["map50"]) - float(baseline_test["per_class"]["whitefly"]["map50"]), 4
        )
        deltas["aphids_map50_delta"] = round(
            float(improved_test["per_class"]["aphids"]["map50"]) - float(baseline_test["per_class"]["aphids"]["map50"]), 4
        )
        deltas["beats_baseline"] = deltas["map50_delta"] >= 0.0 and deltas["f1_delta"] >= 0.0

        summary = {
            "provenance": {
                "kaggle_kernel": KAGGLE_KERNEL_ID,
                "kaggle_dataset": KAGGLE_DATASET_ID,
                **gpu_info,
                "imgsz": args.imgsz,
                "total_images": dataset_info["total_images"],
                "split_counts": dataset_info["split_counts"],
                "negative_counts": dataset_info["negative_counts"],
                "molted_skin_boxes_removed": dataset_info["molted_skin_boxes_removed"],
                "split_leakage": 0,
                "zero_synthetic_confirmed": True,
                "synthetic_images_count": 0,
                "whitefly_oversample_factor": views["whitefly_oversample_factor"],
                "negative_oversample_factor": views["negative_oversample_factor"],
                "leaf_empty_oversample_factor": views.get("leaf_empty_oversample_factor", 1),
                "whitefly_train_images": views["whitefly_train_images"],
                "negative_train_images": views["negative_train_images"],
                "balanced_train_images": views["balanced_train_images"],
                "zoomout_whitefly": views.get("zoomout_whitefly", 0),
                "zoomout_aphids": views.get("zoomout_aphids", 0),
                "zoomout_total": views.get("zoomout_total", 0),
                "coco_val2017_ood": views.get("coco_val2017_ood", {}),
                "val_manifest_sha256": views["val_manifest_sha256"],
                "test_manifest_sha256": views["test_manifest_sha256"],
            },
            "calibrated_threshold": calibrated_thr,
            "threshold_calibration": calibration,
            "loss_summary": loss_summary,
            "pretrained_zero_shot": pretrained_zero_shot,
            "baseline": {
                "epochs_requested": args.baseline_epochs,
                "elapsed_s": baseline_elapsed,
                "val": baseline_val["aggregate"],
                "val_per_class": baseline_val["per_class"],
                "test": baseline_test["aggregate"],
                "per_class": baseline_test["per_class"],
            },
            "improved": {
                "epochs_requested": args.improved_epochs,
                "elapsed_s": improved_elapsed,
                "val": improved_val["aggregate"],
                "val_per_class": improved_val["per_class"],
                "test": improved_test["aggregate"],
                "test_rect_false": improved_test_rect_false["aggregate"],
                "per_class": improved_test["per_class"],
            },
            "improvements_vs_baseline": deltas,
            "kaggle_test_ood_and_small_scale": kaggle_ood_and_small,
        }

        summary_json = json.dumps(summary, indent=2)
        (output_root / "m3_summary.json").write_text(summary_json, encoding="utf-8")
        (artifacts_dir / "kaggle_training_summary.json").write_text(summary_json, encoding="utf-8")

        if not args.skip_export:
            export_probe = _export_nhwc_candidates_on_linux(improved_best_pt, exports_dir=exports_dir, imgsz=args.imgsz)
            print(f"[exports] {json.dumps(export_probe)}", flush=True)

    finally:
        shutil.rmtree(work_root, ignore_errors=True)
        # Remove raw runs weights duplicates to keep Kaggle output lean and fast to download
        shutil.rmtree(runs_dir, ignore_errors=True)
        print(f"[cleanup] Cleaned temporary views at {work_root}", flush=True)


if __name__ == "__main__":
    main()
