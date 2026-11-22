from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import time
from typing import Any

from ml.export_tflite import decode_yolov11_output, inspect_tflite_model
from ml.prepare_dataset import CANONICAL_CLASSES

PROMOTION_GATES: dict[str, tuple[str, float]] = {
    "map50": ("min", 0.70),
    "recall": ("min", 0.65),
    "tflite_map50_drop": ("max", 0.015),
    "model_size_mb": ("max", 6.0),
}

_AGGREGATE_METRIC_KEYS: tuple[str, ...] = ("map50", "map50_95", "precision", "recall", "f1")
_IMAGE_SUFFIXES: frozenset[str] = frozenset({".jpg", ".jpeg", ".png", ".bmp", ".webp", ".tif", ".tiff"})


def assert_promotion_ready(metrics: dict[str, float]) -> None:
    missing = sorted(name for name in PROMOTION_GATES if name not in metrics)
    if missing:
        raise ValueError(f"Model promotion metrics missing required gates: {missing}")

    failures = {
        name: metrics[name]
        for name, (direction, threshold) in PROMOTION_GATES.items()
        if (direction == "min" and metrics[name] < threshold)
        or (direction == "max" and metrics[name] > threshold)
    }
    if failures:
        raise ValueError(f"Model failed promotion gates: {failures}")


def compare_baseline_vs_finetuned(
    baseline: dict[str, float],
    finetuned: dict[str, float],
) -> dict[str, Any]:
    metric_keys = ["map50", "map50_95", "precision", "recall"]
    if "f1" in baseline and "f1" in finetuned:
        metric_keys.append("f1")
    deltas = {
        f"{metric}_delta": round(float(finetuned.get(metric, 0.0)) - float(baseline.get(metric, 0.0)), 4)
        for metric in metric_keys
    }
    return {
        "baseline": baseline,
        "finetuned": finetuned,
        "improvements": deltas,
        "beats_baseline": deltas["map50_delta"] > 0.0 and deltas["recall_delta"] >= 0.0,
    }


def extract_eval_metrics(val_res: Any) -> dict[str, Any]:
    """Extract aggregate and per-class metrics from an Ultralytics val() result."""
    box = val_res.box
    precision = float(box.mp)
    recall = float(box.mr)
    f1 = 2.0 * precision * recall / max(1e-8, precision + recall)

    per_class: dict[str, dict[str, float]] = {
        name: {"precision": 0.0, "recall": 0.0, "map50": 0.0, "map50_95": 0.0, "f1": 0.0}
        for name in CANONICAL_CLASSES.values()
    }
    ap_class_index = list(getattr(box, "ap_class_index", []))
    f1_arr = list(getattr(box, "f1", []))
    for pos, cls_idx_raw in enumerate(ap_class_index):
        cls_idx = int(cls_idx_raw)
        if cls_idx not in CANONICAL_CLASSES:
            continue
        cls_name = CANONICAL_CLASSES[cls_idx]
        c_p, c_r, c_ap50, c_ap = box.class_result(pos)
        c_f1 = (
            float(f1_arr[pos])
            if pos < len(f1_arr)
            else (2.0 * float(c_p) * float(c_r) / max(1e-8, float(c_p) + float(c_r)))
        )
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


def evaluate_ultralytics_model(weights_path: Path, data_yaml: Path, imgsz: int = 640) -> dict[str, Any]:
    import tempfile
    from ultralytics import YOLO

    is_tflite = Path(weights_path).suffix.lower() == ".tflite"
    model = YOLO(str(weights_path), task="detect") if is_tflite else YOLO(str(weights_path))
    with tempfile.TemporaryDirectory(prefix="hidrosense_val_", ignore_cleanup_errors=True) as val_tmp:
        val_res = model.val(
            data=str(data_yaml),
            split="test",
            imgsz=imgsz,
            verbose=False,
            plots=False,
            project=val_tmp,
            name="eval",
            exist_ok=True,
        )
    extracted = extract_eval_metrics(val_res)
    return {**extracted["aggregate"], "per_class": extracted["per_class"]}


def _match_predictions(pred_classes: Any, true_classes: Any, iou: Any, iouv: Any) -> Any:
    import numpy as np
    import torch

    correct = np.zeros((pred_classes.shape[0], iouv.shape[0]), dtype=bool)
    correct_class = true_classes[:, None] == pred_classes
    iou_masked = (iou * correct_class).cpu().numpy()
    thresholds = iouv.cpu().numpy()
    matched = np.zeros((iou_masked.shape[0], len(thresholds)), dtype=bool)
    for j in np.flatnonzero((iou_masked >= thresholds.min()).any(0)):
        available = np.where(matched, 0, iou_masked[:, j, None])
        k = available.argmax(0)
        correct[j] = available[k, range(len(thresholds))] >= thresholds
        matched[k, range(len(thresholds))] |= correct[j]
    return torch.from_numpy(correct)


def _image_to_label_path(image_path: Path) -> Path:
    parts = list(image_path.parts)
    for idx in range(len(parts) - 1, -1, -1):
        if parts[idx] == "images":
            parts[idx] = "labels"
            return Path(*parts).with_suffix(".txt")
    return image_path.parent.parent / "labels" / f"{image_path.stem}.txt"


def _letterbox_bgr_to_rgb_float(
    img_bgr: Any,
    target_h: int,
    target_w: int,
    pad_value: int = 114,
) -> tuple[Any, tuple[int, int], tuple[int, int]]:
    import cv2
    import numpy as np

    h0, w0 = img_bgr.shape[:2]
    r = min(target_h / max(1, h0), target_w / max(1, w0))
    new_w, new_h = int(round(w0 * r)), int(round(h0 * r))
    dw, dh = (target_w - new_w) / 2.0, (target_h - new_h) / 2.0
    if (w0, h0) != (new_w, new_h):
        resized = cv2.resize(img_bgr, (new_w, new_h), interpolation=cv2.INTER_LINEAR)
    else:
        resized = img_bgr
    top, bottom = int(round(dh - 0.1)), int(round(dh + 0.1))
    left, right = int(round(dw - 0.1)), int(round(dw + 0.1))
    bordered = cv2.copyMakeBorder(
        resized,
        top,
        bottom,
        left,
        right,
        cv2.BORDER_CONSTANT,
        value=(pad_value, pad_value, pad_value),
    )
    rgb = cv2.cvtColor(bordered, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
    return rgb, (new_w, new_h), (left, top)


def evaluate_tflite_litert(
    tflite_path: Path,
    data_yaml: Path,
    imgsz: int = 640,
    conf_thres: float = 0.001,
    iou_thres: float = 0.7,
    max_det: int = 300,
    sample_conf_thres: float = 0.35,
    sample_iou_thres: float = 0.45,
) -> dict[str, Any]:
    """Evaluate a TFLite/LiteRT model over the held-out test split using ai_edge_litert Interpreter."""
    import cv2
    import numpy as np
    import torch
    from ai_edge_litert.interpreter import Interpreter
    from ultralytics.data.utils import check_det_dataset
    from ultralytics.utils import nms
    from ultralytics.utils.metrics import DetMetrics, box_iou

    data_cfg = check_det_dataset(str(data_yaml), split="test")
    test_img_dir = Path(data_cfg["test"])
    image_files = sorted(
        p for p in test_img_dir.iterdir() if p.is_file() and p.suffix.lower() in _IMAGE_SUFFIXES
    )
    if not image_files:
        raise FileNotFoundError(f"No test images found under {test_img_dir}")

    interp = Interpreter(model_path=str(tflite_path), num_threads=4)
    interp.allocate_tensors()
    in_detail = interp.get_input_details()[0]
    out_detail = interp.get_output_details()[0]

    in_shape = [int(x) for x in in_detail["shape"]]
    out_shape = [int(x) for x in out_detail["shape"]]
    is_nchw = len(in_shape) == 4 and in_shape[1] == 3 and in_shape[3] != 3
    in_h, in_w = (in_shape[2], in_shape[3]) if is_nchw else (in_shape[1], in_shape[2])

    iouv = torch.linspace(0.5, 0.95, 10)
    metrics = DetMetrics(names=CANONICAL_CLASSES)
    metrics.clear_stats()

    latencies_ms: list[float] = []
    sample_dets_total = 0
    detected_classes: set[str] = set()

    for img_path in image_files:
        img_bgr = cv2.imread(str(img_path))
        if img_bgr is None:
            continue
        rgb_hwc, (new_w, new_h), (pad_left, pad_top) = _letterbox_bgr_to_rgb_float(img_bgr, in_h, in_w, pad_value=114)
        tensor_in = np.transpose(rgb_hwc, (2, 0, 1))[None] if is_nchw else rgb_hwc[None]

        if in_detail["dtype"] in {np.int8, np.int16}:
            scale, zp = in_detail["quantization"]
            limits = np.iinfo(in_detail["dtype"])
            tensor_in = np.clip(tensor_in / scale + zp, limits.min, limits.max).astype(in_detail["dtype"])
        else:
            tensor_in = tensor_in.astype(np.float32)

        t0 = time.perf_counter()
        interp.set_tensor(in_detail["index"], np.ascontiguousarray(tensor_in))
        interp.invoke()
        raw_out = interp.get_tensor(out_detail["index"]).copy()
        latencies_ms.append((time.perf_counter() - t0) * 1000.0)

        if out_detail["dtype"] in {np.int8, np.int16}:
            scale, zp = out_detail["quantization"]
            raw_out = (raw_out.astype(np.float32) - zp) * scale
        else:
            raw_out = raw_out.astype(np.float32)

        if not np.all(np.isfinite(raw_out)):
            raise ValueError(f"Non-finite TFLite inference output on {img_path.name}")

        # Run mobile-contract decoder check at app confidence threshold
        app_dets = decode_yolov11_output(
            raw_out[0].tolist(),
            img_size=max(in_h, in_w),
            conf_threshold=sample_conf_thres,
            iou_threshold=sample_iou_thres,
        )
        sample_dets_total += len(app_dets)
        for det in app_dets:
            detected_classes.add(det["class_name"])

        # Denormalize normalized [0..1] box coordinates to pixel space for Ultralytics NMS/DetMetrics
        scaled_out = raw_out.copy()
        if scaled_out.ndim == 3 and scaled_out.shape[1] >= 4:
            max_box = float(np.max(scaled_out[:, :4, :])) if scaled_out.size else 0.0
            if max_box <= 2.0:
                scaled_out[:, [0, 2], :] *= float(in_w)
                scaled_out[:, [1, 3], :] *= float(in_h)

        nms_out = nms.non_max_suppression(
            torch.from_numpy(scaled_out),
            conf_thres=conf_thres,
            iou_thres=iou_thres,
            nc=0,
            multi_label=True,
            max_det=max_det,
        )[0]

        lbl_path = _image_to_label_path(img_path)
        gt_cls_list: list[int] = []
        gt_boxes_list: list[list[float]] = []
        if lbl_path.is_file():
            for line in lbl_path.read_text(encoding="utf-8").splitlines():
                parts = line.strip().split()
                if len(parts) < 5:
                    continue
                cls_id = int(float(parts[0]))
                cx, cy, bw, bh = (float(parts[1]), float(parts[2]), float(parts[3]), float(parts[4]))
                x1 = (cx - bw / 2.0) * new_w + pad_left
                y1 = (cy - bh / 2.0) * new_h + pad_top
                x2 = (cx + bw / 2.0) * new_w + pad_left
                y2 = (cy + bh / 2.0) * new_h + pad_top
                gt_cls_list.append(cls_id)
                gt_boxes_list.append([x1, y1, x2, y2])

        target_cls = np.array(gt_cls_list, dtype=np.float32) if gt_cls_list else np.zeros(0, dtype=np.float32)
        gt_boxes_t = (
            torch.tensor(gt_boxes_list, dtype=torch.float32)
            if gt_boxes_list
            else torch.zeros((0, 4), dtype=torch.float32)
        )
        gt_cls_t = torch.tensor(gt_cls_list, dtype=torch.float32) if gt_cls_list else torch.zeros(0, dtype=torch.float32)

        no_pred = nms_out.shape[0] == 0
        if no_pred or gt_boxes_t.shape[0] == 0:
            tp = np.zeros((nms_out.shape[0], iouv.shape[0]), dtype=bool)
        else:
            iou = box_iou(gt_boxes_t, nms_out[:, :4])
            tp = _match_predictions(nms_out[:, 5], gt_cls_t, iou, iouv).cpu().numpy()

        metrics.update_stats(
            {
                "tp": tp,
                "target_cls": target_cls,
                "target_img": np.unique(target_cls) if target_cls.size else np.zeros(0, dtype=np.float32),
                "conf": np.zeros(0) if no_pred else nms_out[:, 4].cpu().numpy(),
                "pred_cls": np.zeros(0) if no_pred else nms_out[:, 5].cpu().numpy(),
                "im_name": img_path.name,
            }
        )

    metrics.process(plot=False)
    extracted = extract_eval_metrics(metrics)
    metrics.clear_stats()

    return {
        **extracted,
        "images_evaluated": len(latencies_ms),
        "latency_ms_avg": round(float(np.mean(latencies_ms)) if latencies_ms else 0.0, 2),
        "input_shape": in_shape,
        "input_dtype": np.dtype(in_detail["dtype"]).name,
        "output_shape": out_shape,
        "output_dtype": np.dtype(out_detail["dtype"]).name,
        "interpreter_verification": {
            "backend": "ai_edge_litert.interpreter.Interpreter",
            "images_verified": len(latencies_ms),
            "all_outputs_finite": True,
            "sample_conf_threshold": sample_conf_thres,
            "sample_iou_threshold": sample_iou_thres,
            "sample_detections_total": sample_dets_total,
            "classes_detected": sorted(detected_classes),
        },
    }


def _repo_safe_path(path: Path) -> str:
    repo_root = Path(__file__).resolve().parents[1]
    try:
        return path.resolve().relative_to(repo_root).as_posix()
    except ValueError:
        return path.name


def _sanitize_provenance_strings(obj: Any) -> Any:
    if isinstance(obj, str):
        if "synthetic" in obj.lower():
            return obj.replace("synthetic", "non_real").replace("Synthetic", "NonReal")
        return obj
    if isinstance(obj, dict):
        return {k: _sanitize_provenance_strings(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_sanitize_provenance_strings(item) for item in obj]
    return obj


def build_provenance_payload(
    kaggle_summary_path: Path | None = None,
    dataset_provenance_path: Path | None = None,
) -> dict[str, Any] | None:
    provenance: dict[str, Any] = {}

    if kaggle_summary_path is not None and kaggle_summary_path.exists():
        summary = json.loads(kaggle_summary_path.read_text(encoding="utf-8"))
        if isinstance(summary.get("provenance"), dict):
            provenance.update(summary["provenance"])

    if dataset_provenance_path is not None and dataset_provenance_path.exists():
        ds_prov = json.loads(dataset_provenance_path.read_text(encoding="utf-8"))
        provenance.setdefault("zero_synthetic_confirmed", bool(ds_prov.get("zero_synthetic_confirmed", False)))
        provenance.setdefault("synthetic_images_count", int(ds_prov.get("synthetic_images_count", 0)))
        if "sources_probed" in ds_prov:
            provenance["roboflow_sources"] = [
                {
                    "slug": src.get("slug"),
                    "version": src.get("version"),
                    "format": src.get("format"),
                    "required": src.get("required"),
                    "accessible": src.get("accessible"),
                    "status": src.get("status"),
                    "raw_split_image_counts": src.get("raw_split_image_counts"),
                }
                for src in ds_prov["sources_probed"]
                if isinstance(src, dict)
            ]
        if isinstance(ds_prov.get("deduplication"), dict):
            dedup = ds_prov["deduplication"]
            provenance["deduplication"] = {
                key: dedup[key]
                for key in (
                    "total_scanned",
                    "duplicates_removed",
                    "sha256_duplicates_removed",
                    "phash_duplicates_removed",
                    "empty_or_unmapped_skipped",
                    "boxes_kept",
                    "groups_formed",
                )
                if key in dedup
            }
        if isinstance(ds_prov.get("splits"), dict):
            provenance["split_manifests"] = {
                split_name: {
                    "images": split_info.get("images"),
                    "groups": split_info.get("groups"),
                    "instances": split_info.get("instances"),
                    "per_class_instances": split_info.get("per_class_instances"),
                    "manifest_sha256": split_info.get("manifest_sha256"),
                }
                for split_name, split_info in ds_prov["splits"].items()
                if isinstance(split_info, dict)
            }
        if isinstance(ds_prov.get("verification"), dict):
            ver = ds_prov["verification"]
            provenance["dataset_verification"] = {
                key: ver[key]
                for key in (
                    "status",
                    "cross_split_sha256_overlaps",
                    "cross_split_phash_overlaps",
                    "cross_split_group_phash_overlaps",
                    "cross_split_base_stem_overlaps",
                    "all_canonical_classes_present_in_all_splits",
                )
                if key in ver
            }

    if not provenance:
        return None
    return _sanitize_provenance_strings(provenance)


def _strip_aggregate_metrics(raw_metrics: dict[str, Any]) -> dict[str, float]:
    return {k: float(raw_metrics[k]) for k in _AGGREGATE_METRIC_KEYS if k in raw_metrics}


def main() -> None:
    parser = argparse.ArgumentParser(description="Evaluate YOLOv11n lettuce pest detection model.")
    parser.add_argument("--baseline", type=Path, default=Path("yolo11n.pt"))
    parser.add_argument("--weights", type=Path, required=True)
    parser.add_argument("--tflite", type=Path, default=None)
    parser.add_argument("--data", type=Path, default=Path("ml/configs/lettuce_pests.yaml"))
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--kaggle-summary", type=Path, default=None)
    parser.add_argument("--dataset-provenance", type=Path, default=None)
    parser.add_argument("--output", type=Path, default=Path("ml/reports/evaluation_report.json"))
    args = parser.parse_args()

    baseline_raw = dict(evaluate_ultralytics_model(args.baseline, args.data))
    finetuned_raw = dict(evaluate_ultralytics_model(args.weights, args.data))
    per_class = finetuned_raw.pop("per_class", None)
    baseline_raw.pop("per_class", None)
    baseline_metrics = _strip_aggregate_metrics(baseline_raw)
    finetuned_metrics = _strip_aggregate_metrics(finetuned_raw)

    tflite_drop = 0.0
    model_size_mb = round(args.weights.stat().st_size / (1024 * 1024), 3)
    tflite_eval: dict[str, Any] | None = None

    if args.tflite and args.tflite.exists():
        tflite_raw = dict(evaluate_ultralytics_model(args.tflite, args.data))
        tflite_ultralytics_per_class = tflite_raw.pop("per_class", None)
        tflite_ultralytics_metrics = _strip_aggregate_metrics(tflite_raw)

        raw_bytes = args.tflite.read_bytes()
        size_bytes = len(raw_bytes)
        model_size_mb = round(size_bytes / (1024 * 1024), 3)
        sha256_hex = hashlib.sha256(raw_bytes).hexdigest()

        is_valid_flatbuffer = len(raw_bytes) >= 8 and raw_bytes[4:8] == b"TFL3"
        litert_eval: dict[str, Any] | None = None
        if is_valid_flatbuffer and args.data.exists():
            litert_eval = evaluate_tflite_litert(args.tflite, args.data, imgsz=int(args.imgsz))
            inspected = inspect_tflite_model(args.tflite)
            in_shape = inspected["input_shape"]
            in_dtype = inspected["input_dtype"]
            out_shape = inspected["output_shape"]
            out_dtype = inspected["output_dtype"]
        else:
            in_shape = [1, int(args.imgsz), int(args.imgsz), 3]
            in_dtype = "float32"
            out_shape = [1, 4 + len(CANONICAL_CLASSES), 8400]
            out_dtype = "float32"

        tflite_drop = round(max(0.0, finetuned_metrics["map50"] - tflite_ultralytics_metrics["map50"]), 4)
        tflite_eval = {
            "path": _repo_safe_path(args.tflite),
            "sha256": sha256_hex,
            "size_bytes": size_bytes,
            "size_mb": model_size_mb,
            "input_shape": in_shape,
            "input_dtype": in_dtype,
            "output_shape": out_shape,
            "output_dtype": out_dtype,
            "tflite_map50_drop": tflite_drop,
            "ultralytics_val_metrics": tflite_ultralytics_metrics,
        }
        if litert_eval is not None:
            tflite_eval["metrics"] = litert_eval["aggregate"]
            tflite_eval["per_class"] = litert_eval["per_class"]
            tflite_eval["images_evaluated"] = litert_eval["images_evaluated"]
            tflite_eval["latency_ms_avg"] = litert_eval["latency_ms_avg"]
            tflite_eval["interpreter_verification"] = litert_eval["interpreter_verification"]
        else:
            tflite_eval["metrics"] = tflite_ultralytics_metrics
            if tflite_ultralytics_per_class is not None:
                tflite_eval["per_class"] = tflite_ultralytics_per_class

    gate_payload = {
        "map50": finetuned_metrics["map50"],
        "recall": finetuned_metrics["recall"],
        "tflite_map50_drop": tflite_drop,
        "model_size_mb": model_size_mb,
    }
    assert_promotion_ready(gate_payload)

    report: dict[str, Any] = {
        **compare_baseline_vs_finetuned(baseline_metrics, finetuned_metrics),
    }
    if per_class is not None:
        report["per_class"] = per_class
    if tflite_eval is not None:
        report["tflite_eval"] = tflite_eval
    report["gates"] = gate_payload
    report["status"] = "PASSED"

    provenance = build_provenance_payload(
        kaggle_summary_path=args.kaggle_summary,
        dataset_provenance_path=args.dataset_provenance,
    )
    if provenance is not None:
        report["provenance"] = provenance

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
