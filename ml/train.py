from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

import yaml

DEFAULT_KAGGLE_USERNAME = "adityadwiferdiansyah"
DEFAULT_KAGGLE_SLUG = "hidrosense-yolov11n-lettuce-pests-training"
DEFAULT_KAGGLE_DATASET = "adityadwiferdiansyah/hidrosense-lettuce-pests-real"


@dataclass(frozen=True)
class Yolo11TrainingConfig:
    model: str = "yolo11n.pt"
    data: str = "ml/configs/lettuce_pests.yaml"
    epochs: int = 80
    patience: int = 20
    batch: int = 16
    imgsz: int = 640
    seed: int = 42
    optimizer: str = "AdamW"
    lr0: float = 0.001
    lrf: float = 0.01
    cos_lr: bool = True
    mosaic: float = 1.0
    close_mosaic: int = 15
    scale: float = 0.5
    fliplr: float = 0.5
    flipud: float = 0.2
    hsv_h: float = 0.015
    hsv_s: float = 0.5
    hsv_v: float = 0.4
    copy_paste: float = 0.1
    project: str = "ml/runs"
    name: str = "yolo11n_lettuce_pests"


def resolve_dataset_yaml(data_yaml_path: Path, output_dir: Path) -> Path:
    """Resolve relative dataset `path:` against yaml parent, CWD, or repo root."""
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


def run_local_or_kernel_training(config: Yolo11TrainingConfig) -> dict[str, Any]:
    from ultralytics import YOLO

    run_dir = Path(config.project) / config.name
    data_path = resolve_dataset_yaml(Path(config.data), run_dir)
    model = YOLO(config.model)
    results = model.train(
        data=str(data_path),
        epochs=config.epochs,
        patience=config.patience,
        batch=config.batch,
        imgsz=config.imgsz,
        seed=config.seed,
        deterministic=True,
        optimizer=config.optimizer,
        lr0=config.lr0,
        lrf=config.lrf,
        cos_lr=config.cos_lr,
        mosaic=config.mosaic,
        close_mosaic=config.close_mosaic,
        scale=config.scale,
        fliplr=config.fliplr,
        flipud=config.flipud,
        hsv_h=config.hsv_h,
        hsv_s=config.hsv_s,
        hsv_v=config.hsv_v,
        copy_paste=config.copy_paste,
        project=config.project,
        name=config.name,
    )
    save_dir = Path(results.save_dir)
    return {
        "save_dir": str(save_dir),
        "best_weights": str(save_dir / "weights" / "best.pt"),
        "config": asdict(config),
    }


def write_kaggle_kernel_bundle(
    kernel_dir: Path,
    kaggle_username: str = DEFAULT_KAGGLE_USERNAME,
    kernel_slug: str = DEFAULT_KAGGLE_SLUG,
    dataset_sources: list[str] | None = None,
) -> Path:
    """Create a clean Kaggle GPU kernel bundle without embedding any API secrets."""
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
    proc = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        check=True,
    )
    return proc.stdout.strip()


def poll_kaggle_kernel(
    kernel_ref: str,
    kaggle_exe: str = "kaggle",
    poll_interval_s: int = 20,
    timeout_minutes: int = 60,
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
        upper = status_text.upper()
        if "COMPLETE" in upper:
            return status_text
        if "ERROR" in upper or "CANCEL" in upper:
            raise RuntimeError(f"Kaggle kernel {kernel_ref} failed: {status_text}")
        if time.monotonic() >= deadline:
            raise TimeoutError(
                f"Timed out waiting {timeout_minutes}m for Kaggle kernel {kernel_ref}: {status_text}"
            )
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


def main() -> None:
    parser = argparse.ArgumentParser(description="Train YOLOv11n lettuce pest detection model.")
    parser.add_argument("--data", type=str, default="ml/configs/lettuce_pests.yaml")
    parser.add_argument("--epochs", type=int, default=80)
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--kaggle-push", action="store_true")
    parser.add_argument("--kaggle-username", type=str, default=DEFAULT_KAGGLE_USERNAME)
    parser.add_argument("--kaggle-slug", type=str, default=DEFAULT_KAGGLE_SLUG)
    parser.add_argument("--kaggle-bundle-dir", type=Path, default=Path("ml/kaggle_work"))
    parser.add_argument("--kaggle-output-dir", type=Path, default=Path("ml/kaggle_remote_output"))
    parser.add_argument("--kaggle-dataset", type=str, default=DEFAULT_KAGGLE_DATASET)
    parser.add_argument("--accelerator", type=str, default="NvidiaTeslaT4")
    parser.add_argument("--poll", action="store_true")
    parser.add_argument("--timeout-minutes", type=int, default=60)
    args = parser.parse_args()

    if args.kaggle_push:
        sibling_kaggle = Path(sys.executable).with_name(
            "kaggle.exe" if sys.platform.startswith("win") else "kaggle"
        )
        resolved_kaggle = (
            str(sibling_kaggle)
            if sibling_kaggle.is_file()
            else (shutil.which("kaggle") or "kaggle")
        )

        bundle_meta = write_kaggle_kernel_bundle(
            kernel_dir=args.kaggle_bundle_dir,
            kaggle_username=args.kaggle_username,
            kernel_slug=args.kaggle_slug,
            dataset_sources=[args.kaggle_dataset] if args.kaggle_dataset else [],
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
        return

    cfg = Yolo11TrainingConfig(
        data=args.data,
        epochs=args.epochs,
        batch=args.batch,
        imgsz=args.imgsz,
    )
    summary = run_local_or_kernel_training(cfg)
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
