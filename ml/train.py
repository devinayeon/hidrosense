from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
from typing import Any

import yaml

from ml.visual_pipeline import build_visual_training_hyperparams

DEFAULT_KAGGLE_USERNAME = "adityadwiferdiansyah"
DEFAULT_KAGGLE_SLUG = "hidrosense-yolov11n-lettuce-pests-training"
DEFAULT_KAGGLE_DATASET = "adityadwiferdiansyah/hidrosense-whitefly-aphids-v2"


@dataclass(frozen=True)
class Yolo11TrainingConfig:
    model: str = "yolo11n.pt"
    data: str = "ml/configs/lettuce_pests.yaml"
    epochs: int = 100
    patience: int = 25
    batch: int = 16
    imgsz: int = 640
    seed: int = 42
    optimizer: str = "AdamW"
    lr0: float = 0.001
    lrf: float = 0.01
    cos_lr: bool = True
    cls: float = 1.2
    box: float = 7.5
    dfl: float = 1.5
    mosaic: float = 1.0
    close_mosaic: int = 15
    scale: float = 0.75
    translate: float = 0.15
    degrees: float = 20.0
    shear: float = 5.0
    perspective: float = 0.0003
    fliplr: float = 0.5
    flipud: float = 0.3
    hsv_h: float = 0.02
    hsv_s: float = 0.55
    hsv_v: float = 0.45
    copy_paste: float = 0.15
    mixup: float = 0.08
    erasing: float = 0.15
    project: str = "ml/runs"
    name: str = "yolo11n_whitefly_aphids"


def resolve_dataset_yaml(data_yaml_path: Path, output_dir: Path) -> Path:
    if not data_yaml_path.is_file():
        return data_yaml_path

    cfg = yaml.safe_load(data_yaml_path.read_text(encoding="utf-8"))
    if not isinstance(cfg, dict):
        return data_yaml_path

    raw_path = cfg.get("path")
    val_rel = str(cfg.get("val", "val/images"))
    repo_root = Path(__file__).resolve().parent.parent

    if not raw_path:
        resolved_base = data_yaml_path.resolve().parent
    else:
        raw_p = Path(str(raw_path))
        if raw_p.is_absolute():
            resolved_base = raw_p
        else:
            candidates = [
                (data_yaml_path.resolve().parent / raw_p).resolve(),
                (Path.cwd() / raw_p).resolve(),
                (repo_root / raw_p).resolve(),
            ]
            resolved_base = next(
                (cand for cand in candidates if (cand / val_rel).is_dir()),
                next((cand for cand in candidates if cand.is_dir()), candidates[0]),
            )

    resolved_cfg = dict(cfg)
    resolved_cfg["path"] = str(resolved_base)
    output_dir.mkdir(parents=True, exist_ok=True)
    out_yaml = output_dir / "resolved_data.yaml"
    out_yaml.write_text(yaml.safe_dump(resolved_cfg, sort_keys=False), encoding="utf-8")
    return out_yaml


def write_kaggle_kernel_bundle(
    kernel_dir: Path,
    kaggle_username: str = DEFAULT_KAGGLE_USERNAME,
    kernel_slug: str = DEFAULT_KAGGLE_SLUG,
    dataset_sources: list[str] | None = None,
) -> Path:
    """Create a secret-free Kaggle GPU kernel bundle targeting the remote notebook."""
    entry_src = Path(__file__).resolve().parent / "kaggle_train_entry.py"
    if not entry_src.is_file():
        raise FileNotFoundError(f"Kaggle entry script not found: {entry_src}")

    kernel_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(entry_src, kernel_dir / "kaggle_train_entry.py")

    metadata = {
        "id": f"{kaggle_username}/{kernel_slug}",
        "title": "HidroSense YOLOv11n Lettuce Pests Training",
        "code_file": "kaggle_train_entry.py",
        "language": "python",
        "kernel_type": "script",
        "is_private": True,
        "enable_gpu": True,
        "enable_tpu": False,
        "enable_internet": True,
        "dataset_sources": list(dataset_sources) if dataset_sources else [],
        "competition_sources": [],
        "kernel_sources": [],
        "model_sources": [],
    }
    meta_path = kernel_dir / "kernel-metadata.json"
    meta_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    return meta_path


def push_kaggle_kernel(
    kernel_dir: Path,
    kaggle_exe: str = "kaggle",
    accelerator: str | None = "NvidiaTeslaT4",
) -> str:
    cmd = [kaggle_exe, "kernels", "push", "-p", str(kernel_dir)]
    if accelerator:
        cmd.extend(["--accelerator", accelerator])
    proc = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return proc.stdout.strip()


def poll_kaggle_kernel(
    kernel_ref: str,
    kaggle_exe: str = "kaggle",
    poll_interval_s: int = 20,
    timeout_minutes: int = 90,
    max_consecutive_errors: int = 5,
) -> str:
    deadline = time.monotonic() + timeout_minutes * 60
    consecutive_errors = 0
    while True:
        try:
            proc = subprocess.run(
                [kaggle_exe, "kernels", "status", kernel_ref],
                capture_output=True,
                text=True,
                check=True,
            )
            consecutive_errors = 0
        except subprocess.CalledProcessError as exc:
            consecutive_errors += 1
            if consecutive_errors >= max_consecutive_errors or time.monotonic() >= deadline:
                raise RuntimeError(
                    f"Kaggle status check failed {consecutive_errors} times for {kernel_ref}: "
                    f"{(exc.stderr or exc.stdout or str(exc)).strip()}"
                ) from exc
            time.sleep(poll_interval_s)
            continue

        status_text = (proc.stdout or "").strip()
        worker_match = re.search(r"KernelWorkerStatus\.([A-Z_]+)", status_text, re.IGNORECASE)
        if worker_match:
            status_token = worker_match.group(1).upper()
        else:
            quoted_match = re.search(r'has status\s+"([^"]+)"', status_text, re.IGNORECASE)
            status_token = quoted_match.group(1).upper() if quoted_match else status_text.upper()

        print(f"[kaggle-poll] {status_text}", flush=True)
        if "COMPLETE" in status_token:
            return status_text
        if "ERROR" in status_token or "CANCEL" in status_token:
            raise RuntimeError(f"Kaggle kernel {kernel_ref} failed: {status_text}")
        if time.monotonic() >= deadline:
            raise TimeoutError(f"Timed out waiting {timeout_minutes}m for {kernel_ref}: {status_text}")
        time.sleep(poll_interval_s)


def download_kaggle_kernel_output(
    kernel_ref: str,
    output_dir: Path,
    kaggle_exe: str = "kaggle",
) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [kaggle_exe, "kernels", "output", kernel_ref, "-p", str(output_dir)],
        capture_output=True,
        text=True,
        check=True,
    )
    return output_dir


def main(argv: list[str] | None = None) -> dict[str, Any]:
    parser = argparse.ArgumentParser(description="Orchestrate remote Kaggle GPU training for 2-class YOLOv11n.")
    parser.add_argument("--kaggle-push", action="store_true", default=True)
    parser.add_argument("--kaggle-username", type=str, default=DEFAULT_KAGGLE_USERNAME)
    parser.add_argument("--kaggle-slug", type=str, default=DEFAULT_KAGGLE_SLUG)
    parser.add_argument("--kaggle-bundle-dir", type=Path, default=Path("ml/kaggle_work"))
    parser.add_argument("--kaggle-output-dir", type=Path, default=Path("ml/kaggle_remote_output"))
    parser.add_argument("--kaggle-dataset", type=str, default=DEFAULT_KAGGLE_DATASET)
    parser.add_argument(
        "--extra-kaggle-datasets",
        type=str,
        nargs="*",
        default=["xthink/coco-2017-val-images", "minhtngbi/instances-val2017"],
    )
    parser.add_argument("--accelerator", type=str, default="NvidiaTeslaT4")
    parser.add_argument("--poll", action="store_true")
    parser.add_argument("--timeout-minutes", type=int, default=90)
    args = parser.parse_args(argv)

    sibling_kaggle = Path(sys.executable).with_name("kaggle.exe" if sys.platform.startswith("win") else "kaggle")
    resolved_kaggle = str(sibling_kaggle) if sibling_kaggle.is_file() else (shutil.which("kaggle") or "kaggle")

    ds_sources = [args.kaggle_dataset] if args.kaggle_dataset else []
    for extra_ds in args.extra_kaggle_datasets or []:
        if extra_ds and extra_ds not in ds_sources:
            ds_sources.append(extra_ds)

    bundle_meta = write_kaggle_kernel_bundle(
        kernel_dir=args.kaggle_bundle_dir,
        kaggle_username=args.kaggle_username,
        kernel_slug=args.kaggle_slug,
        dataset_sources=ds_sources,
    )
    push_out = push_kaggle_kernel(
        kernel_dir=args.kaggle_bundle_dir,
        kaggle_exe=resolved_kaggle,
        accelerator=args.accelerator or None,
    )
    kernel_ref = f"{args.kaggle_username}/{args.kaggle_slug}"
    result: dict[str, Any] = {
        "kernel_ref": kernel_ref,
        "metadata_path": str(bundle_meta),
        "push_output": push_out,
        "visual_hyperparameters": build_visual_training_hyperparams(),
        "config": asdict(Yolo11TrainingConfig()),
    }
    if args.poll:
        status_text = poll_kaggle_kernel(
            kernel_ref=kernel_ref,
            kaggle_exe=resolved_kaggle,
            timeout_minutes=args.timeout_minutes,
        )
        download_kaggle_kernel_output(
            kernel_ref=kernel_ref,
            output_dir=args.kaggle_output_dir,
            kaggle_exe=resolved_kaggle,
        )
        result["status"] = status_text
        result["output_dir"] = str(args.kaggle_output_dir)
    print(json.dumps(result, indent=2))
    return result


if __name__ == "__main__":
    main()
