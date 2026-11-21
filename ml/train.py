from __future__ import annotations

import argparse
import json
import subprocess
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any


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


def run_local_or_kernel_training(config: Yolo11TrainingConfig) -> dict[str, Any]:
    from ultralytics import YOLO

    model = YOLO(config.model)
    results = model.train(
        data=config.data,
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
    kaggle_username: str,
    kernel_slug: str = "hidrosense-yolo11n-lettuce-pests",
    dataset_sources: list[str] | None = None,
) -> Path:
    """Create a clean Kaggle GPU kernel bundle without embedding any API secrets."""
    kernel_dir.mkdir(parents=True, exist_ok=True)
    metadata = {
        "id": f"{kaggle_username}/{kernel_slug}",
        "title": "HidroSense YOLOv11n Lettuce Pests Training",
        "code_file": "kaggle_train_entry.py",
        "language": "python",
        "kernel_type": "script",
        "is_private": "true",
        "enable_gpu": "true",
        "enable_tpu": "false",
        "enable_internet": "true",
        "dataset_sources": dataset_sources or [],
        "competition_sources": [],
        "kernel_sources": [],
        "model_sources": [],
    }
    meta_path = kernel_dir / "kernel-metadata.json"
    meta_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    return meta_path


def push_kaggle_kernel(kernel_dir: Path, kaggle_exe: str = "kaggle") -> str:
    proc = subprocess.run(
        [kaggle_exe, "kernels", "push", "-p", str(kernel_dir)],
        capture_output=True,
        text=True,
        check=True,
    )
    return proc.stdout.strip()


def main() -> None:
    parser = argparse.ArgumentParser(description="Train YOLOv11n lettuce pest detection model.")
    parser.add_argument("--data", type=str, default="ml/configs/lettuce_pests.yaml")
    parser.add_argument("--epochs", type=int, default=80)
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument("--imgsz", type=int, default=640)
    args = parser.parse_args()

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
