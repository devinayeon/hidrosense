from __future__ import annotations

import argparse
import copy
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import tempfile
from typing import Any
import zipfile

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

    num_classes = len(CANONICAL_CLASSES)
    expected_channels = 4 + num_classes

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
        best_cls = max(range(num_classes), key=lambda idx: scores[idx])
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


def inspect_tflite_model(tflite_path: Path) -> dict[str, Any]:
    """Inspect a TFLite/LiteRT flatbuffer using ai_edge_litert Interpreter."""
    import numpy as np
    from ai_edge_litert.interpreter import Interpreter

    raw_bytes = tflite_path.read_bytes()
    interp = Interpreter(model_path=str(tflite_path))
    interp.allocate_tensors()
    in_detail = interp.get_input_details()[0]
    out_detail = interp.get_output_details()[0]

    in_quant = in_detail.get("quantization", (0.0, 0))
    out_quant = out_detail.get("quantization", (0.0, 0))
    return {
        "input_shape": [int(x) for x in in_detail["shape"]],
        "input_dtype": np.dtype(in_detail["dtype"]).name,
        "input_quantization": [float(in_quant[0]), int(in_quant[1])],
        "output_shape": [int(x) for x in out_detail["shape"]],
        "output_dtype": np.dtype(out_detail["dtype"]).name,
        "output_quantization": [float(out_quant[0]), int(out_quant[1])],
        "size_bytes": len(raw_bytes),
        "size_mb": round(len(raw_bytes) / (1024 * 1024), 3),
        "sha256": hashlib.sha256(raw_bytes).hexdigest(),
    }


def _add_ultralytics_tflite_metadata(
    tflite_path: Path,
    img_size: int = 640,
    names: dict[int, str] | None = None,
    task: str = "detect",
    stride: int = 32,
    channels: int = 3,
) -> None:
    """Embed Ultralytics metadata.json zip trailer so LiteRTBackend can load and evaluate the model."""
    try:
        with zipfile.ZipFile(tflite_path, "r") as existing_zf:
            if "metadata.json" in existing_zf.namelist():
                return
    except zipfile.BadZipFile:
        pass

    ultralytics_version = "8.4.0"
    try:
        from ultralytics import __version__ as _uv

        ultralytics_version = str(_uv)
    except Exception:
        pass

    resolved_names = {int(k): str(v) for k, v in (names or CANONICAL_CLASSES).items()}
    metadata_payload = {
        "description": "Ultralytics YOLO11n lettuce pests detection model",
        "author": "HidroSense",
        "date": datetime.now(timezone.utc).isoformat(),
        "version": ultralytics_version,
        "stride": int(stride),
        "task": task,
        "head": "Detect",
        "batch": 1,
        "imgsz": [int(img_size), int(img_size)],
        "names": resolved_names,
        "channels": int(channels),
        "end2end": False,
    }
    with zipfile.ZipFile(tflite_path, "a", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("metadata.json", json.dumps(metadata_payload, indent=2))


def _patch_onnx_and_onnx2tf_compat() -> None:
    """Apply runtime compatibility shims for onnx>=1.17 + onnx_graphsurgeon + onnx2tf."""
    import onnx.helper

    if not hasattr(onnx.helper, "float32_to_bfloat16"):
        def float32_to_bfloat16(fval: float) -> int:
            ival = struct.unpack("=I", struct.pack("=f", fval))[0]
            return ival >> 16

        onnx.helper.float32_to_bfloat16 = float32_to_bfloat16  # type: ignore[attr-defined]


def _export_nhwc_tflite_via_onnx2tf(
    yolo_model: Any,
    output_tflite: Path,
    img_size: int = 640,
    precision: str = "fp16",
) -> Path:
    """Export a real Ultralytics YOLO model to NHWC float32-I/O TFLite via tf_wrapper -> ONNX -> onnx2tf."""
    import numpy as np
    import onnx
    import onnx2tf
    import onnxslim
    import tensorflow as tf
    import torch
    from ultralytics.nn.modules import Detect, SPPF
    from ultralytics.utils.export.tensorflow import tf_wrapper

    pt_model = copy.deepcopy(yolo_model.model).cpu().float()
    for param in pt_model.parameters():
        param.requires_grad = False
    pt_model.eval()
    pt_model = pt_model.fuse(imgsz=[img_size, img_size])

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

    dummy_input = torch.zeros(1, 3, img_size, img_size, dtype=torch.float32)
    with torch.no_grad():
        dry_out = pt_model(dummy_input)
        dry_tensor = dry_out[0] if isinstance(dry_out, (tuple, list)) else dry_out
        if tuple(dry_tensor.shape) != (1, 4 + len(CANONICAL_CLASSES), 8400 * (img_size // 640) ** 2) and img_size == 640:
            raise ValueError(f"Unexpected wrapped PyTorch export shape: {tuple(dry_tensor.shape)}")

    _patch_onnx_and_onnx2tf_compat()

    with tempfile.TemporaryDirectory(prefix="hidrosense_tflite_export_", ignore_cleanup_errors=True) as tmp_dir_str:
        work_dir = Path(tmp_dir_str)
        onnx_path = work_dir / "model.onnx"
        saved_model_dir = work_dir / "saved_model"

        torch.onnx.export(
            pt_model,
            dummy_input,
            str(onnx_path),
            opset_version=17,
            dynamo=False,
            input_names=["images"],
            output_names=["output0"],
        )
        slim_model = onnxslim.slim(onnx.load(str(onnx_path)))
        onnx.save(slim_model, str(onnx_path))

        # Pre-seed dummy calibration sample file in temp dir so onnx2tf never writes into repo root
        calib_sample = work_dir / "calibration_image_sample_data_20x128x128x3_float32.npy"
        if not calib_sample.exists():
            np.save(str(calib_sample), np.zeros((20, 128, 128, 3), dtype=np.float32))

        prev_cwd = Path.cwd()
        try:
            os.chdir(work_dir)
            onnx2tf.convert(
                input_onnx_file_path=str(onnx_path),
                output_folder_path=str(saved_model_dir),
                not_use_onnxsim=True,
                verbosity="error",
                output_integer_quantized_tflite=(precision == "int8"),
                enable_batchmatmul_unfold=(precision != "int8"),
                output_signaturedefs=True,
            )
        finally:
            os.chdir(prev_cwd)

        if precision == "int8":
            candidates = sorted(saved_model_dir.glob("*_dynamic_range_quant.tflite")) or sorted(
                saved_model_dir.glob("*_integer_quant.tflite")
            )
            if not candidates:
                raise FileNotFoundError(f"onnx2tf did not produce INT8 TFLite inside {saved_model_dir}")
            output_tflite.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(candidates[0], output_tflite)
        else:
            converter = tf.lite.TFLiteConverter.from_saved_model(str(saved_model_dir))
            if precision == "fp16":
                converter.optimizations = [tf.lite.Optimize.DEFAULT]
                converter.target_spec.supported_types = [tf.float16]
            tflite_bytes = converter.convert()
            output_tflite.parent.mkdir(parents=True, exist_ok=True)
            output_tflite.write_bytes(tflite_bytes)

    names = getattr(yolo_model, "names", None) or CANONICAL_CLASSES
    _add_ultralytics_tflite_metadata(output_tflite, img_size=img_size, names=names)
    return output_tflite


def build_model_metadata(
    model_version: str,
    img_size: int = 640,
    conf_threshold: float = 0.35,
    iou_threshold: float = 0.45,
    sha256_hex: str | None = None,
    input_shape: list[int] | None = None,
    input_dtype: str = "float32",
    output_shape: list[int] | None = None,
    metrics: dict[str, Any] | None = None,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "architecture": "yolo11n",
        "model_version": model_version,
        "input_shape": input_shape or [1, img_size, img_size, 3],
        "input_dtype": input_dtype,
        "input_normalization": "0_to_1",
        "letterbox_pad_value": 114,
        "output_shape": output_shape or [1, 4 + len(CANONICAL_CLASSES), 8400],
        "confidence_threshold": conf_threshold,
        "iou_threshold": iou_threshold,
        "classes": {str(k): v for k, v in CANONICAL_CLASSES.items()},
        "sha256": sha256_hex or "",
    }
    if metrics is not None:
        payload["metrics"] = metrics
    return payload


def export_model_to_flutter_assets(
    weights_path: Path | None,
    flutter_assets_dir: Path,
    img_size: int = 640,
    quantize_int8: bool = False,
    data_yaml: Path | None = None,
    precision: str = "fp16",
    metrics: dict[str, Any] | None = None,
    tflite_path: Path | None = None,
    evaluation_report_path: Path | None = None,
) -> Path:
    flutter_assets_dir.mkdir(parents=True, exist_ok=True)
    target_tflite = flutter_assets_dir / "yolo11n_lettuce_pests.tflite"

    resolved_precision = "int8" if quantize_int8 else precision.lower().strip()
    if resolved_precision not in {"fp16", "fp32", "int8"}:
        raise ValueError(f"Unsupported TFLite export precision: {precision!r}")

    if tflite_path is not None:
        if tflite_path.resolve() != target_tflite.resolve():
            shutil.copy2(tflite_path, target_tflite)
    else:
        if weights_path is None:
            raise ValueError("Either weights_path or tflite_path must be provided.")
        import torch
        from ultralytics import YOLO

        model = YOLO(str(weights_path))
        if hasattr(model, "model") and isinstance(getattr(model, "model"), torch.nn.Module):
            _export_nhwc_tflite_via_onnx2tf(
                model,
                output_tflite=target_tflite,
                img_size=img_size,
                precision=resolved_precision,
            )
        else:
            # Preserves _FakeYOLO mock compatibility in unit/E2E tests
            exported = Path(
                model.export(
                    format="tflite",
                    imgsz=img_size,
                    int8=quantize_int8,
                    data=str(data_yaml) if data_yaml else None,
                )
            )
            if exported.is_dir():
                pattern = "*_int8.tflite" if quantize_int8 else "*_float16.tflite"
                matches = sorted(exported.glob(pattern)) or sorted(exported.glob("*.tflite"))
                if not matches:
                    raise FileNotFoundError(f"No .tflite file found in exported directory {exported}")
                exported = matches[0]
            shutil.copy2(exported, target_tflite)

    resolved_metrics = metrics
    if resolved_metrics is None and evaluation_report_path is not None and evaluation_report_path.exists():
        eval_payload = json.loads(evaluation_report_path.read_text(encoding="utf-8"))
        resolved_metrics = eval_payload.get("finetuned")

    raw_bytes = target_tflite.read_bytes()
    digest = hashlib.sha256(raw_bytes).hexdigest()

    input_shape = [1, img_size, img_size, 3]
    input_dtype = "float32"
    output_shape = [1, 4 + len(CANONICAL_CLASSES), 8400]
    if len(raw_bytes) >= 8 and raw_bytes[4:8] == b"TFL3":
        inspected = inspect_tflite_model(target_tflite)
        input_shape = inspected["input_shape"]
        input_dtype = inspected["input_dtype"]
        output_shape = inspected["output_shape"]
        digest = inspected["sha256"]

    labels_txt = "\n".join(CANONICAL_CLASSES[idx] for idx in sorted(CANONICAL_CLASSES)) + "\n"
    (flutter_assets_dir / "labels.txt").write_text(labels_txt, encoding="utf-8")

    metadata = build_model_metadata(
        model_version=f"yolo11n-{resolved_precision}-{digest[:8]}",
        img_size=img_size,
        sha256_hex=digest,
        input_shape=input_shape,
        input_dtype=input_dtype,
        output_shape=output_shape,
        metrics=resolved_metrics,
    )
    (flutter_assets_dir / "model_metadata.json").write_text(
        json.dumps(metadata, indent=2),
        encoding="utf-8",
    )
    return target_tflite


def main() -> None:
    parser = argparse.ArgumentParser(description="Export YOLOv11n weights to Flutter TFLite assets.")
    parser.add_argument("--weights", type=Path, default=None)
    parser.add_argument("--tflite", type=Path, default=None)
    parser.add_argument(
        "--assets-dir",
        type=Path,
        default=Path("ml/artifacts"),
    )
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--precision", choices=("fp16", "fp32", "int8"), default="fp16")
    parser.add_argument("--int8", action="store_true")
    parser.add_argument("--data", type=Path, default=Path("ml/configs/lettuce_pests.yaml"))
    parser.add_argument("--evaluation-report", type=Path, default=None)
    args = parser.parse_args()

    if args.weights is None and args.tflite is None:
        parser.error("one of --weights or --tflite is required")

    export_model_to_flutter_assets(
        weights_path=args.weights,
        flutter_assets_dir=args.assets_dir,
        img_size=int(args.imgsz),
        quantize_int8=args.int8,
        data_yaml=args.data,
        precision=args.precision,
        tflite_path=args.tflite,
        evaluation_report_path=args.evaluation_report,
    )


if __name__ == "__main__":
    main()
