from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path
from typing import Any

from ml.prepare_dataset import CANONICAL_CLASSES


def _iou(box_a: tuple[float, float, float, float], box_b: tuple[float, float, float, float]) -> float:
    x1 = max(box_a[0], box_b[0])
    y1 = max(box_a[1], box_b[1])
    x2 = min(box_a[2], box_b[2])
    y2 = min(box_a[3], box_b[3])
    inter = max(0.0, x2 - x1) * max(0.0, y2 - y1)
    if inter <= 0.0:
        return 0.0
    area_a = max(0.0, box_a[2] - box_a[0]) * max(0.0, box_a[3] - box_a[1])
    area_b = max(0.0, box_b[2] - box_b[0]) * max(0.0, box_b[3] - box_b[1])
    return inter / max(1e-8, area_a + area_b - inter)


def decode_yolov11_output(
    tensor_2d: list[list[float]],
    img_size: int = 640,
    conf_threshold: float = 0.35,
    iou_threshold: float = 0.45,
) -> list[dict[str, Any]]:
    """Decode anchor-free YOLOv11 output [4 + num_classes, N] or [N, 4 + num_classes]."""
    if not tensor_2d or not tensor_2d[0]:
        return []

    num_Classes = len(CANONICAL_CLASSES)
    expected_channels = 4 + num_Classes

    if len(tensor_2d) == expected_channels and len(tensor_2d[0]) != expected_channels:
        num_anchors = len(tensor_2d[0])
        anchors = [[tensor_2d[ch][idx] for ch in range(expected_channels)] for idx in range(num_anchors)]
    else:
        anchors = tensor_2d

    candidates: list[dict[str, Any]] = []
    scale = float(img_size)
    for row in anchors:
        if len(row) < expected_channels:
            continue
        cx, cy, w, h = row[0], row[1], row[2], row[3]
        scores = row[4:expected_channels]
        best_cls = max(range(num_Classes), key=lambda idx: scores[idx])
        best_score = float(scores[best_cls])
        if best_score < conf_threshold:
            continue

        # Normalize pixel coordinates if exported in [0..img_size] space
        if cx > 1.5 or cy > 1.5 or w > 1.5 or h > 1.5:
            cx, cy, w, h = cx / scale, cy / scale, w / scale, h / scale

        x1 = max(0.0, min(1.0, cx - w / 2.0))
        y1 = max(0.0, min(1.0, cy - h / 2.0))
        x2 = max(0.0, min(1.0, cx + w / 2.0))
        y2 = max(0.0, min(1.0, cy + h / 2.0))
        if x2 <= x1 or y2 <= y1:
            continue

        candidates.append(
            {
                "class_id": best_cls,
                "class_name": CANONICAL_CLASSES[best_cls],
                "confidence": round(best_score, 4),
                "box": (x1, y1, x2, y2),
            }
        )

    candidates.sort(key=lambda item: item["confidence"], reverse=True)
    selected: list[dict[str, Any]] = []
    for cand in candidates:
        if any(
            cand["class_id"] == kept["class_id"] and _iou(cand["box"], kept["box"]) > iou_threshold
            for kept in selected
        ):
            continue
        selected.append(cand)
    return selected


def build_model_metadata(
    model_version: str,
    img_size: int = 640,
    conf_threshold: float = 0.35,
    iou_threshold: float = 0.45,
    sha256_hex: str | None = None,
) -> dict[str, Any]:
    return {
        "architecture": "yolo11n",
        "model_version": model_version,
        "input_shape": [1, img_size, img_size, 3],
        "input_dtype": "float32",
        "input_normalization": "0_to_1",
        "letterbox_pad_value": 114,
        "output_shape": [1, 4 + len(CANONICAL_CLASSES), 8400],
        "confidence_threshold": conf_threshold,
        "iou_threshold": iou_threshold,
        "classes": {str(k): v for k, v in CANONICAL_CLASSES.items()},
        "sha256": sha256_hex or "",
    }


def export_model_to_flutter_assets(
    weights_path: Path,
    flutter_assets_dir: Path,
    img_size: int = 640,
    quantize_int8: bool = False,
    data_yaml: Path | None = None,
) -> Path:
    from ultralytics import YOLO

    model = YOLO(str(weights_path))
    exported = Path(
        model.export(
            format="tflite",
            imgsz=img_size,
            int8=quantize_int8,
            data=str(data_yaml) if data_yaml else None,
        )
    )
    flutter_assets_dir.mkdir(parents=True, exist_ok=True)
    target_tflite = flutter_assets_dir / "yolo11n_lettuce_pests.tflite"
    shutil.copy2(exported, target_tflite)

    digest = hashlib.sha256(target_tflite.read_bytes()).hexdigest()
    labels_txt = "\n".join(CANONICAL_CLASSES[idx] for idx in sorted(CANONICAL_CLASSES)) + "\n"
    (flutter_assets_dir / "labels.txt").write_text(labels_txt, encoding="utf-8")

    metadata = build_model_metadata(
        model_version=f"yolo11n-fp16-{digest[:8]}",
        img_size=img_size,
        sha256_hex=digest,
    )
    (flutter_assets_dir / "model_metadata.json").write_text(
        json.dumps(metadata, indent=2),
        encoding="utf-8",
    )
    return target_tflite


def main() -> None:
    parser = argparse.ArgumentParser(description="Export YOLOv11n weights to Flutter TFLite assets.")
    parser.add_argument("--weights", type=Path, required=True)
    parser.add_argument(
        "--assets-dir",
        type=Path,
        default=Path("ml/artifacts"),
    )
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--int8", action="store_true")
    parser.add_argument("--data", type=Path, default=Path("ml/configs/lettuce_pests.yaml"))
    args = parser.parse_args()

    export_model_to_flutter_assets(
        weights_path=args.weights,
        flutter_assets_dir=args.assets_dir,
        img_size=int(args.imgsz),
        quantize_int8=args.int8,
        data_yaml=args.data,
    )


if __name__ == "__main__":
    main()
