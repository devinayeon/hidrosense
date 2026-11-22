from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

CANONICAL_NAMES: dict[int, str] = {0: "thrips", 1: "whitefly", 2: "aphids"}
EXPECTED_SPLIT_COUNTS: dict[str, int] = {"train": 1245, "val": 178, "test": 153}
IMAGE_EXTENSIONS: frozenset[str] = frozenset({".jpg", ".jpeg", ".png", ".bmp", ".webp"})
KAGGLE_KERNEL_ID = "adityadwiferdiansyah/hidrosense-yolov11n-lettuce-pests-training"
KAGGLE_DATASET_ID = "adityadwiferdiansyah/hidrosense-lettuce-pests-real"


def _parse_version_tuple(raw: str) -> tuple[int, int, int]:
    parts: list[int] = []
    for token in raw.split("+")[0].split(".")[:3]:
        match = re.match(r"(\d+)", token.strip())
        parts.append(int(match.group(1)) if match else 0)
    while len(parts) < 3:
        parts.append(0)
    return (parts[0], parts[1], parts[2])


def ensure_packages() -> None:
    """Install ultralytics and pyyaml quietly only if missing or out of range."""
    missing: list[str] = []
    try:
        import yaml  # noqa: F401
    except ImportError:
        missing.append("pyyaml")

    try:
        import ultralytics

        ver = _parse_version_tuple(getattr(ultralytics, "__version__", "0.0.0"))
        if not ((8, 3, 0) <= ver < (8, 5, 0)):
            missing.append("ultralytics>=8.3.0,<8.5.0")
    except ImportError:
        missing.append("ultralytics>=8.3.0,<8.5.0")

    if missing:
        print(f"[bootstrap] Installing missing packages: {missing}", flush=True)
        subprocess.run(
            [sys.executable, "-m", "pip", "install", "-q", *missing],
            check=True,
        )


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
    return (
        candidate.is_dir()
        and (candidate / "data.yaml").is_file()
        and (candidate / "dataset_provenance.json").is_file()
        and (candidate / "train" / "images").is_dir()
        and (candidate / "val" / "images").is_dir()
        and (candidate / "test" / "images").is_dir()
    )


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


def locate_dataset_dir(
    dataset_dir: Path | None = None,
    allow_local: bool = False,
) -> Path:
    """Locate the mounted real Roboflow dataset; fail fast if missing (zero synthetic fallback)."""
    candidates: list[Path] = []
    if dataset_dir is not None:
        candidates.append(Path(dataset_dir))

    env_dir = os.environ.get("HIDROSENSE_DATASET_DIR", "").strip()
    if env_dir:
        candidates.append(Path(env_dir))

    candidates.extend(
        [
            Path("/kaggle/input/datasets/adityadwiferdiansyah/hidrosense-lettuce-pests-real"),
            Path("/kaggle/input/hidrosense-lettuce-pests-real"),
        ]
    )

    for candidate in candidates:
        if _is_dataset_dir(candidate):
            return candidate.resolve()

    scanned = _scan_bounded(Path("/kaggle/input"), max_depth=4)
    if scanned:
        return scanned[0].resolve()

    if allow_local:
        local_candidate = Path("ml/data/merged_lettuce_pests")
        if _is_dataset_dir(local_candidate):
            return local_candidate.resolve()

    raise FileNotFoundError(
        "Real Roboflow dataset (data.yaml + dataset_provenance.json) not found. "
        "Checked HIDROSENSE_DATASET_DIR and /kaggle/input. Synthetic fallback is disabled."
    )


def _list_images(images_dir: Path) -> list[Path]:
    if not images_dir.is_dir():
        return []
    return sorted(
        p for p in images_dir.iterdir() if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS
    )


def validate_real_dataset(dataset_dir: Path) -> dict[str, Any]:
    """Validate provenance, canonical class mapping, zero synthetic images, and exact split counts."""
    import yaml

    data_yaml_path = dataset_dir / "data.yaml"
    prov_path = dataset_dir / "dataset_provenance.json"
    if not data_yaml_path.is_file() or not prov_path.is_file():
        raise FileNotFoundError(f"Missing data.yaml or dataset_provenance.json in {dataset_dir}")

    data_cfg = yaml.safe_load(data_yaml_path.read_text(encoding="utf-8"))
    if not isinstance(data_cfg, dict) or int(data_cfg.get("nc", -1)) != 3:
        raise ValueError(f"Expected nc == 3 in {data_yaml_path}, got {data_cfg!r}")

    raw_names = data_cfg.get("names", {})
    normalized_names: dict[int, str] = {}
    if isinstance(raw_names, dict):
        normalized_names = {int(k): str(v).strip().lower() for k, v in raw_names.items()}
    elif isinstance(raw_names, list):
        normalized_names = {idx: str(v).strip().lower() for idx, v in enumerate(raw_names)}
    if normalized_names != CANONICAL_NAMES:
        raise ValueError(f"Expected canonical names {CANONICAL_NAMES}, got {normalized_names!r}")

    provenance = json.loads(prov_path.read_text(encoding="utf-8"))
    if provenance.get("zero_synthetic_confirmed") is not True:
        raise ValueError("dataset_provenance.json must confirm zero_synthetic_confirmed is True")
    if int(provenance.get("synthetic_images_count", -1)) != 0:
        raise ValueError("dataset_provenance.json must have synthetic_images_count == 0")

    verification = provenance.get("verification", {})
    leakage_keys = (
        "cross_split_sha256_overlaps",
        "cross_split_phash_overlaps",
        "cross_split_group_phash_overlaps",
        "cross_split_base_stem_overlaps",
    )
    split_leakage = int(provenance.get("split_leakage", 0))
    for key in leakage_keys:
        if key in verification and int(verification[key]) != 0:
            raise ValueError(f"Cross-split leakage detected in {key}: {verification[key]}")
    if split_leakage != 0:
        raise ValueError(f"Dataset split_leakage must be 0, got {split_leakage}")

    split_counts: dict[str, int] = {}
    for split_name, expected_count in EXPECTED_SPLIT_COUNTS.items():
        imgs = _list_images(dataset_dir / split_name / "images")
        lbl_dir = dataset_dir / split_name / "labels"
        lbls = sorted(p for p in lbl_dir.iterdir() if p.is_file() and p.suffix == ".txt")
        if len(imgs) != expected_count or len(lbls) != expected_count:
            raise ValueError(
                f"Split {split_name!r} expected {expected_count} images/labels, "
                f"found {len(imgs)} images and {len(lbls)} labels"
            )
        img_stems = {p.stem for p in imgs}
        lbl_stems = {p.stem for p in lbls}
        if img_stems != lbl_stems:
            raise ValueError(f"Split {split_name!r} image/label stem mismatch")
        split_counts[split_name] = len(imgs)

    return {
        "dataset_dir": str(dataset_dir),
        "split_counts": split_counts,
        "total_images": sum(split_counts.values()),
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
    """Create a real directory tree at dst with file-level symlinks (or copies) from src."""
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
        files = sorted(p for p in sub_dir.iterdir() if p.is_file())
        for file_path in files:
            hasher.update(f"{sub}/{file_path.name}\n".encode("utf-8"))
            hasher.update(hashlib.sha256(file_path.read_bytes()).digest())
    return hasher.hexdigest()


def _label_has_class(label_path: Path, target_class: int) -> bool:
    for line in label_path.read_text(encoding="utf-8").splitlines():
        parts = line.strip().split()
        if not parts:
            continue
        if int(float(parts[0])) == target_class:
            return True
    return False


def _write_data_yaml(yaml_path: Path, dataset_root: Path) -> None:
    import yaml

    payload = {
        "path": str(dataset_root.resolve()),
        "train": "train/images",
        "val": "val/images",
        "test": "test/images",
        "nc": 3,
        "names": dict(CANONICAL_NAMES),
    }
    yaml_path.parent.mkdir(parents=True, exist_ok=True)
    yaml_path.write_text(yaml.safe_dump(payload, sort_keys=False), encoding="utf-8")


def build_isolated_dataset_views(
    dataset_dir: Path,
    work_root: Path,
    thrips_oversample_factor: int = 4,
) -> dict[str, Any]:
    """Create isolated writable baseline and train-only thrips-oversampled dataset views."""
    if thrips_oversample_factor < 1:
        raise ValueError("thrips_oversample_factor must be >= 1")

    baseline_dir = work_root / "baseline"
    balanced_dir = work_root / "balanced"
    shutil.rmtree(baseline_dir, ignore_errors=True)
    shutil.rmtree(balanced_dir, ignore_errors=True)

    for split_name in ("train", "val", "test"):
        _link_or_copy_dir_files(dataset_dir / split_name, baseline_dir / split_name)

    for split_name in ("val", "test"):
        _link_or_copy_dir_files(dataset_dir / split_name, balanced_dir / split_name)

    val_sha_base = _split_manifest_sha256(baseline_dir / "val")
    val_sha_bal = _split_manifest_sha256(balanced_dir / "val")
    test_sha_base = _split_manifest_sha256(baseline_dir / "test")
    test_sha_bal = _split_manifest_sha256(balanced_dir / "test")
    if val_sha_base != val_sha_bal or test_sha_base != test_sha_bal:
        raise AssertionError("Balanced view altered val or test split manifest")

    src_train_imgs = _list_images(dataset_dir / "train" / "images")
    src_train_lbl_dir = dataset_dir / "train" / "labels"
    bal_img_dir = balanced_dir / "train" / "images"
    bal_lbl_dir = balanced_dir / "train" / "labels"
    bal_img_dir.mkdir(parents=True, exist_ok=True)
    bal_lbl_dir.mkdir(parents=True, exist_ok=True)

    thrips_train_images = 0
    balanced_train_images = 0
    for img_path in src_train_imgs:
        lbl_path = src_train_lbl_dir / f"{img_path.stem}.txt"
        _link_or_copy_file(img_path, bal_img_dir / img_path.name)
        _link_or_copy_file(lbl_path, bal_lbl_dir / lbl_path.name)
        balanced_train_images += 1

        if _label_has_class(lbl_path, 0):
            thrips_train_images += 1
            for rep_idx in range(1, thrips_oversample_factor):
                prefix = f"rep{rep_idx}__"
                _link_or_copy_file(img_path, bal_img_dir / f"{prefix}{img_path.name}")
                _link_or_copy_file(lbl_path, bal_lbl_dir / f"{prefix}{lbl_path.name}")
                balanced_train_images += 1

    data_baseline_yaml = work_root / "data_baseline.yaml"
    data_balanced_yaml = work_root / "data_balanced.yaml"
    _write_data_yaml(data_baseline_yaml, baseline_dir)
    _write_data_yaml(data_balanced_yaml, balanced_dir)

    return {
        "baseline_yaml": data_baseline_yaml,
        "balanced_yaml": data_balanced_yaml,
        "thrips_train_images": thrips_train_images,
        "balanced_train_images": balanced_train_images,
        "thrips_oversample_factor": thrips_oversample_factor,
        "val_manifest_sha256": val_sha_base,
        "test_manifest_sha256": test_sha_base,
    }


def extract_eval_metrics(val_res: Any) -> dict[str, Any]:
    """Extract aggregate and per-class metrics from an Ultralytics val() result."""
    box = val_res.box
    precision = float(box.mp)
    recall = float(box.mr)
    f1 = 2.0 * precision * recall / max(1e-8, precision + recall)

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
        "map50_95": round(float(box.map), 4),
        "precision": round(precision, 4),
        "recall": round(recall, 4),
        "f1": round(f1, 4),
    }
    return {"aggregate": aggregate, "per_class": per_class}


def _evaluate_split(weights_or_model: str | Path, data_yaml: Path, split: str, imgsz: int = 640) -> dict[str, Any]:
    from ultralytics import YOLO

    model = YOLO(str(weights_or_model))
    val_res = model.val(data=str(data_yaml), split=split, imgsz=imgsz, device=0, verbose=True)
    return extract_eval_metrics(val_res)


def _compute_improvements(baseline_test: dict[str, Any], improved_test: dict[str, Any]) -> dict[str, Any]:
    b_agg = baseline_test["aggregate"]
    i_agg = improved_test["aggregate"]
    b_cls = baseline_test["per_class"]
    i_cls = improved_test["per_class"]

    deltas = {
        f"{k}_delta": round(float(i_agg[k]) - float(b_agg[k]), 4)
        for k in ("map50", "map50_95", "precision", "recall", "f1")
    }
    deltas["thrips_map50_delta"] = round(
        float(i_cls["thrips"]["map50"]) - float(b_cls["thrips"]["map50"]), 4
    )
    deltas["thrips_recall_delta"] = round(
        float(i_cls["thrips"]["recall"]) - float(b_cls["thrips"]["recall"]), 4
    )
    deltas["whitefly_map50_delta"] = round(
        float(i_cls["whitefly"]["map50"]) - float(b_cls["whitefly"]["map50"]), 4
    )
    deltas["aphids_map50_delta"] = round(
        float(i_cls["aphids"]["map50"]) - float(b_cls["aphids"]["map50"]), 4
    )
    deltas["beats_baseline"] = deltas["map50_delta"] > 0.0 and deltas["recall_delta"] >= 0.0
    return deltas


def _probe_tflite_candidate(
    tflite_path: Path,
    data_baseline_yaml: Path,
    imgsz: int = 640,
) -> dict[str, Any]:
    info: dict[str, Any] = {
        "path": str(tflite_path),
        "file_name": tflite_path.name,
        "size_bytes": tflite_path.stat().st_size,
        "size_mb": round(tflite_path.stat().st_size / (1024.0 * 1024.0), 3),
    }

    interpreter_cls = None
    try:
        from ai_edge_litert.interpreter import Interpreter  # type: ignore

        interpreter_cls = Interpreter
    except ImportError:
        try:
            import tensorflow as tf  # type: ignore

            interpreter_cls = tf.lite.Interpreter
        except ImportError:
            interpreter_cls = None

    if interpreter_cls is not None:
        interp = interpreter_cls(model_path=str(tflite_path))
        interp.allocate_tensors()
        in_det = interp.get_input_details()[0]
        out_det = interp.get_output_details()[0]
        info["input_shape"] = [int(x) for x in in_det["shape"]]
        info["input_dtype"] = str(getattr(in_det["dtype"], "__name__", in_det["dtype"]))
        info["output_shape"] = [int(x) for x in out_det["shape"]]
        info["output_dtype"] = str(getattr(out_det["dtype"], "__name__", out_det["dtype"]))

    try:
        from ultralytics import YOLO

        tflite_model = YOLO(str(tflite_path), task="detect")
        val_res = tflite_model.val(data=str(data_baseline_yaml), split="test", imgsz=imgsz, verbose=False)
        info["test_eval"] = extract_eval_metrics(val_res)
    except Exception as exc:
        info["test_eval_error"] = f"{type(exc).__name__}: {exc}"

    return info


def attempt_candidate_exports(
    best_pt: Path,
    data_baseline_yaml: Path,
    exports_dir: Path,
    imgsz: int = 640,
) -> dict[str, Any]:
    """Attempt non-fatal Linux ONNX + NHWC FP16/INT8 TFLite candidate exports for M4."""
    exports_dir.mkdir(parents=True, exist_ok=True)
    probe: dict[str, Any] = {"status": "attempted", "candidates": {}}

    try:
        from ultralytics import YOLO

        # Export ONNX first
        try:
            onnx_model = YOLO(str(best_pt))
            exported_onnx = Path(onnx_model.export(format="onnx", imgsz=imgsz, opset=17))
            target_onnx = exports_dir / "best.onnx"
            shutil.copy2(exported_onnx, target_onnx)
            probe["candidates"]["onnx"] = {
                "file_name": target_onnx.name,
                "size_bytes": target_onnx.stat().st_size,
                "size_mb": round(target_onnx.stat().st_size / (1024.0 * 1024.0), 3),
            }
        except Exception as exc:
            probe["candidates"]["onnx_error"] = f"{type(exc).__name__}: {exc}"

        # Ensure TFLite export dependencies are available on Linux if needed
        missing_export_deps: list[str] = []
        for mod_name, pkg_spec in (
            ("onnx", "onnx"),
            ("onnx2tf", "onnx2tf"),
            ("sng4onnx", "sng4onnx"),
            ("onnx_graphsurgeon", "onnx_graphsurgeon"),
            ("tensorflow", "tensorflow"),
        ):
            try:
                __import__(mod_name)
            except ImportError:
                missing_export_deps.append(pkg_spec)
        if missing_export_deps:
            print(f"[exports] Installing optional TFLite export deps: {missing_export_deps}", flush=True)
            subprocess.run(
                [sys.executable, "-m", "pip", "install", "-q", *missing_export_deps],
                check=False,
            )

        # Export FP16 TFLite (typically ~5.2 MB <= 6.0 MB gate with minimal accuracy drop)
        for variant, export_kwargs, target_name in (
            ("fp16", {"format": "tflite", "imgsz": imgsz, "half": True}, "best_float16.tflite"),
            (
                "int8",
                {"format": "tflite", "imgsz": imgsz, "int8": True, "data": str(data_baseline_yaml)},
                "best_int8.tflite",
            ),
        ):
            try:
                model = YOLO(str(best_pt))
                exported_path = Path(model.export(**export_kwargs))
                target_tflite = exports_dir / target_name
                shutil.copy2(exported_path, target_tflite)
                probe["candidates"][variant] = _probe_tflite_candidate(
                    target_tflite, data_baseline_yaml, imgsz=imgsz
                )
            except Exception as exc:
                probe["candidates"][f"{variant}_error"] = f"{type(exc).__name__}: {exc}"

        # Clean up large intermediate saved_model folders created next to best_pt
        saved_model_dir = best_pt.parent / f"{best_pt.stem}_saved_model"
        if saved_model_dir.is_dir():
            shutil.rmtree(saved_model_dir, ignore_errors=True)
        side_onnx = best_pt.with_suffix(".onnx")
        if side_onnx.is_file():
            side_onnx.unlink(missing_ok=True)

        probe["status"] = "completed"
    except Exception as exc:
        probe["status"] = "failed_non_fatal"
        probe["error"] = f"{type(exc).__name__}: {exc}"

    (exports_dir / "export_probe.json").write_text(json.dumps(probe, indent=2), encoding="utf-8")
    return probe


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="HidroSense Kaggle GPU YOLOv11n Training Entrypoint")
    parser.add_argument("--dataset-dir", type=Path, default=None)
    parser.add_argument("--allow-local", action="store_true")
    parser.add_argument("--output-root", type=Path, default=None)
    parser.add_argument("--baseline-epochs", type=int, default=45)
    parser.add_argument("--improved-epochs", type=int, default=80)
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--thrips-oversample", type=int, default=4)
    parser.add_argument("--skip-export", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)
    ensure_packages()

    gpu_info = ensure_gpu_available()
    import ultralytics
    from ultralytics import YOLO

    gpu_info["ultralytics_version"] = str(ultralytics.__version__)
    print(f"[env] {json.dumps(gpu_info)}", flush=True)

    dataset_dir = locate_dataset_dir(args.dataset_dir, allow_local=args.allow_local)
    dataset_info = validate_real_dataset(dataset_dir)
    print(f"[dataset] Verified real Roboflow dataset: {json.dumps(dataset_info)}", flush=True)

    if args.output_root is not None:
        output_root = Path(args.output_root)
    elif Path("/kaggle/working").is_dir():
        output_root = Path("/kaggle/working")
    else:
        output_root = Path("ml/kaggle_local_run")
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
            thrips_oversample_factor=args.thrips_oversample,
        )
        data_baseline_yaml: Path = views["baseline_yaml"]
        data_balanced_yaml: Path = views["balanced_yaml"]
        print(
            f"[views] baseline={data_baseline_yaml}, balanced={data_balanced_yaml}, "
            f"balanced_train_images={views['balanced_train_images']}",
            flush=True,
        )

        # 0. Pretrained COCO zero-shot check on real held-out test split
        print("[stage0] Running pretrained yolo11n.pt zero-shot check on test split...", flush=True)
        pretrained_zero_shot = _evaluate_split("yolo11n.pt", data_baseline_yaml, split="test", imgsz=args.imgsz)

        # 1. Stage 1 — Real-Data Baseline (unweighted 1,245 train images)
        print("[stage1] Training baseline YOLOv11n on unweighted real train split...", flush=True)
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
        baseline_best_src = Path(baseline_res.save_dir) / "weights" / "best.pt"
        baseline_best_pt = artifacts_dir / "baseline_best.pt"
        shutil.copy2(baseline_best_src, baseline_best_pt)

        baseline_val = _evaluate_split(baseline_best_pt, data_baseline_yaml, split="val", imgsz=args.imgsz)
        baseline_test = _evaluate_split(baseline_best_pt, data_baseline_yaml, split="test", imgsz=args.imgsz)
        print(f"[stage1] Baseline test metrics: {json.dumps(baseline_test)}", flush=True)

        # 2. Stage 2 — Improved Class-Balanced Model (4x train-only thrips oversampling)
        print("[stage2] Training improved YOLOv11n on class-balanced train split...", flush=True)
        t2_start = time.time()
        improved_model = YOLO("yolo11n.pt")
        improved_res = improved_model.train(
            data=str(data_balanced_yaml),
            epochs=args.improved_epochs,
            patience=20,
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
            cls=1.0,
            box=7.5,
            dfl=1.5,
            mosaic=1.0,
            close_mosaic=15,
            mixup=0.1,
            scale=0.5,
            degrees=15.0,
            fliplr=0.5,
            flipud=0.2,
            hsv_h=0.015,
            hsv_s=0.5,
            hsv_v=0.4,
            amp=True,
            cache="ram",
            workers=4,
            project=str(runs_dir),
            name="improved_yolo11n",
        )
        improved_elapsed = round(time.time() - t2_start, 2)
        improved_best_src = Path(improved_res.save_dir) / "weights" / "best.pt"
        improved_best_pt = artifacts_dir / "best.pt"
        shutil.copy2(improved_best_src, improved_best_pt)

        improved_val = _evaluate_split(improved_best_pt, data_baseline_yaml, split="val", imgsz=args.imgsz)
        improved_test = _evaluate_split(improved_best_pt, data_baseline_yaml, split="test", imgsz=args.imgsz)
        print(f"[stage2] Improved test metrics: {json.dumps(improved_test)}", flush=True)

        improvements = _compute_improvements(baseline_test, improved_test)

        summary = {
            "provenance": {
                "kaggle_kernel": KAGGLE_KERNEL_ID,
                "kaggle_dataset": KAGGLE_DATASET_ID,
                **gpu_info,
                "imgsz": args.imgsz,
                "total_images": dataset_info["total_images"],
                "split_counts": dataset_info["split_counts"],
                "split_leakage": 0,
                "zero_synthetic_confirmed": True,
                "synthetic_images_count": 0,
                "thrips_oversample_factor": views["thrips_oversample_factor"],
                "thrips_train_images": views["thrips_train_images"],
                "balanced_train_images": views["balanced_train_images"],
                "val_manifest_sha256": views["val_manifest_sha256"],
                "test_manifest_sha256": views["test_manifest_sha256"],
            },
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
                "per_class": improved_test["per_class"],
            },
            "improvements_vs_baseline": improvements,
        }

        summary_json = json.dumps(summary, indent=2)
        (output_root / "m3_summary.json").write_text(summary_json, encoding="utf-8")
        (artifacts_dir / "kaggle_training_summary.json").write_text(summary_json, encoding="utf-8")
        print("[summary] Saved m3_summary.json and artifacts/kaggle_training_summary.json", flush=True)

        if not args.skip_export:
            export_probe = attempt_candidate_exports(
                best_pt=improved_best_pt,
                data_baseline_yaml=data_baseline_yaml,
                exports_dir=exports_dir,
                imgsz=args.imgsz,
            )
            print(f"[exports] {json.dumps(export_probe)}", flush=True)

    finally:
        shutil.rmtree(work_root, ignore_errors=True)
        print(f"[cleanup] Removed temporary dataset views at {work_root}", flush=True)


if __name__ == "__main__":
    main()
