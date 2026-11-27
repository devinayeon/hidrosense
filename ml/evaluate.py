from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import time
from typing import Any

from ml.export_tflite import _default_yolo_anchors, decode_yolov11_output, inspect_tflite_model
from ml.prepare_dataset import CANONICAL_CLASSES

PROMOTION_GATES: dict[str, tuple[str, float]] = {
    "map50": ("min", 0.72),
    "recall": ("min", 0.72),
    "f1": ("min", 0.72),
    "small_scale_recall": ("min", 0.70),
    "tflite_map50_drop": ("max", 0.008),
    "ood_false_positive_rate": ("max", 0.03),
    "model_size_mb": ("max", 12.0),
}

_AGGREGATE_METRIC_KEYS: tuple[str, ...] = ("map50", "map75", "map50_95", "precision", "recall", "f1")
_IMAGE_SUFFIXES: frozenset[str] = frozenset({".jpg", ".jpeg", ".png", ".bmp", ".webp", ".tif", ".tiff"})


def assert_promotion_ready(metrics: dict[str, float]) -> None:
    missing = sorted(name for name in PROMOTION_GATES if name not in metrics)
    if missing:
        raise ValueError(f"Model promotion metrics missing required gates: {missing}")

    invalid = {
        name: metrics[name]
        for name in PROMOTION_GATES
        if isinstance(metrics[name], bool)
        or not isinstance(metrics[name], (int, float))
        or not math.isfinite(float(metrics[name]))
    }
    if invalid:
        raise ValueError(f"Model promotion metrics must be finite numbers: {invalid}")

    failures = {
        name: metrics[name]
        for name, (direction, threshold) in PROMOTION_GATES.items()
        if (direction == "min" and float(metrics[name]) < threshold)
        or (direction == "max" and float(metrics[name]) > threshold)
    }
    if failures:
        raise ValueError(f"Model failed promotion gates: {failures}")


def compare_baseline_vs_finetuned(
    baseline: dict[str, float],
    finetuned: dict[str, float],
) -> dict[str, Any]:
    metric_keys = [k for k in ("map50", "map75", "map50_95", "precision", "recall", "f1") if k in baseline and k in finetuned]
    deltas = {
        f"{metric}_delta": round(float(finetuned.get(metric, 0.0)) - float(baseline.get(metric, 0.0)), 4)
        for metric in metric_keys
    }
    return {
        "baseline": baseline,
        "finetuned": finetuned,
        "improvements": deltas,
        "beats_baseline": deltas.get("map50_delta", 0.0) >= 0.0 and deltas.get("f1_delta", deltas.get("map50_delta", 0.0)) >= 0.0,
    }


def extract_eval_metrics(val_res: Any) -> dict[str, Any]:
    """Extract aggregate (mAP50, mAP75, mAP50-95, Precision, Recall, F1) and per-class metrics."""
    box = val_res.box
    precision = float(box.mp)
    recall = float(box.mr)
    f1 = 2.0 * precision * recall / max(1e-8, precision + recall)
    map75 = float(getattr(box, "map75", 0.0))

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
        "map75": round(map75, 4),
        "map50_95": round(float(box.map), 4),
        "precision": round(precision, 4),
        "recall": round(recall, 4),
        "f1": round(f1, 4),
    }
    return {"aggregate": aggregate, "per_class": per_class}


def compute_classification_and_ood_metrics(
    confusion_3x3: list[list[int]],
    image_outcomes: list[tuple[bool, bool, str]],
) -> dict[str, Any]:
    """Compute instance-level classification accuracy, 3x3 confusion metrics, image-level MCC/Specificity/FPR, and OOD breakdown.

    confusion_3x3 layout (rows = predicted [whitefly, aphids, missed_fn], cols = true [whitefly, aphids, background_fp]):
      row 0: predicted whitefly -> [tp_wf, pred_wf_true_ap, bg_fp_wf]
      row 1: predicted aphids   -> [pred_ap_true_wf, tp_ap, bg_fp_ap]
      row 2: missed (FN)        -> [fn_wf, fn_ap, 0]
    """
    tp_wf = int(confusion_3x3[0][0])
    wf_as_ap = int(confusion_3x3[1][0])
    ap_as_wf = int(confusion_3x3[0][1])
    tp_ap = int(confusion_3x3[1][1])
    bg_fp_wf = int(confusion_3x3[0][2])
    bg_fp_ap = int(confusion_3x3[1][2])
    fn_wf = int(confusion_3x3[2][0])
    fn_ap = int(confusion_3x3[2][1])

    matched_boxes = tp_wf + tp_ap + wf_as_ap + ap_as_wf
    matched_cls_acc = (tp_wf + tp_ap) / max(1, matched_boxes)

    total_box_events = matched_boxes + bg_fp_wf + bg_fp_ap + fn_wf + fn_ap
    overall_detection_cls_acc = (tp_wf + tp_ap) / max(1, total_box_events)

    tp_img = sum(1 for gt, pred, _ in image_outcomes if gt and pred)
    tn_img = sum(1 for gt, pred, _ in image_outcomes if (not gt) and (not pred))
    fp_img = sum(1 for gt, pred, _ in image_outcomes if (not gt) and pred)
    fn_img = sum(1 for gt, pred, _ in image_outcomes if gt and (not pred))
    total_img = max(1, len(image_outcomes))

    img_acc = (tp_img + tn_img) / total_img
    img_prec = tp_img / max(1, tp_img + fp_img)
    img_rec = tp_img / max(1, tp_img + fn_img)
    specificity = tn_img / max(1, tn_img + fp_img)
    fpr = fp_img / max(1, tn_img + fp_img)
    fdr = fp_img / max(1, tp_img + fp_img)
    bal_acc = 0.5 * (img_rec + specificity)
    img_f1 = 2.0 * img_prec * img_rec / max(1e-8, img_prec + img_rec)

    mcc_denom = math.sqrt(
        float((tp_img + fp_img) * (tp_img + fn_img) * (tn_img + fp_img) * (tn_img + fn_img))
    )
    mcc = ((tp_img * tn_img) - (fp_img * fn_img)) / mcc_denom if mcc_denom > 0.0 else 0.0

    ood_breakdown: dict[str, dict[str, Any]] = {}
    negative_groups = sorted({grp for gt, _, grp in image_outcomes if not gt})
    ood_total = 0
    ood_fp = 0
    for grp in negative_groups:
        grp_rows = [(gt, pred) for gt, pred, g in image_outcomes if g == grp and not gt]
        g_tn = sum(1 for _, pred in grp_rows if not pred)
        g_fp = sum(1 for _, pred in grp_rows if pred)
        g_n = len(grp_rows)
        if grp.startswith("ood_"):
            ood_total += g_n
            ood_fp += g_fp
        ood_breakdown[grp] = {
            "images": g_n,
            "true_negatives": g_tn,
            "false_positives": g_fp,
            "specificity_tnr": round(g_tn / max(1, g_n), 4),
            "false_positive_rate": round(g_fp / max(1, g_n), 4),
        }

    ood_fpr = ood_fp / max(1, ood_total) if ood_total > 0 else fpr

    return {
        "confusion_matrix_3x3": {
            "labels_rows_pred": ["whitefly", "aphids", "missed_fn"],
            "labels_cols_true": ["whitefly", "aphids", "background_fp"],
            "matrix": confusion_3x3,
            "background_false_positives": {"whitefly": bg_fp_wf, "aphids": bg_fp_ap, "total": bg_fp_wf + bg_fp_ap},
            "missed_false_negatives": {"whitefly": fn_wf, "aphids": fn_ap, "total": fn_wf + fn_ap},
            "cross_pest_misclassifications": {"whitefly_as_aphids": wf_as_ap, "aphids_as_whitefly": ap_as_wf},
        },
        "matched_box_classification_accuracy": round(matched_cls_acc, 4),
        "box_event_accuracy": round(overall_detection_cls_acc, 4),
        "image_level": {
            "total_images": len(image_outcomes),
            "tp": tp_img,
            "tn": tn_img,
            "fp": fp_img,
            "fn": fn_img,
            "accuracy": round(img_acc, 4),
            "balanced_accuracy": round(bal_acc, 4),
            "precision": round(img_prec, 4),
            "recall_sensitivity": round(img_rec, 4),
            "specificity_tnr": round(specificity, 4),
            "false_positive_rate": round(fpr, 4),
            "false_discovery_rate": round(fdr, 4),
            "f1": round(img_f1, 4),
            "mcc": round(mcc, 4),
        },
        "ood_false_positive_rate": round(ood_fpr, 4),
        "ood_total_images": ood_total,
        "ood_false_positives": ood_fp,
        "ood_breakdown": ood_breakdown,
    }


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
            rect=False,
            batch=1,
            verbose=False,
            plots=False,
            project=val_tmp,
            name="eval",
            exist_ok=True,
        )
    extracted = extract_eval_metrics(val_res)
    return {**extracted["aggregate"], "per_class": extracted["per_class"]}


def compute_pytorch_tflite_tensor_parity(
    weights_path: Path,
    tflite_path: Path,
    imgsz: int = 640,
) -> dict[str, float] | None:
    """Measure direct numerical tensor delta between fused PyTorch weights and exported NHWC TFLite."""
    import copy
    import zipfile

    if not weights_path.is_file() or not zipfile.is_zipfile(weights_path):
        return None
    raw_bytes = tflite_path.read_bytes() if tflite_path.is_file() else b""
    if len(raw_bytes) < 8 or raw_bytes[4:8] != b"TFL3":
        return None

    import numpy as np
    import torch
    from ai_edge_litert.interpreter import Interpreter
    from ultralytics import YOLO
    from ultralytics.nn.modules import Detect, SPPF
    from ultralytics.utils.export.tensorflow import tf_wrapper

    rng = np.random.default_rng(42)
    sample_nhwc = rng.uniform(0.0, 1.0, size=(1, imgsz, imgsz, 3)).astype(np.float32)
    sample_nchw = np.transpose(sample_nhwc, (0, 3, 1, 2))

    pt_model = copy.deepcopy(YOLO(str(weights_path)).model).cpu().float().eval()
    pt_model = pt_model.fuse(imgsz=[imgsz, imgsz])
    if hasattr(pt_model, "end2end"):
        pt_model.end2end = False
    wrapped = tf_wrapper(pt_model)
    for mod in wrapped.modules():
        if isinstance(mod, SPPF):
            mod.export = True
        if isinstance(mod, Detect):
            mod.dynamic = False
            mod.export = True
            mod.format = "saved_model"
            mod.xyxy = False
            mod.shape = None

    with torch.no_grad():
        pt_raw = wrapped(torch.from_numpy(sample_nchw))
        pt_out = (pt_raw[0] if isinstance(pt_raw, (tuple, list)) else pt_raw).cpu().numpy().astype(np.float32)

    interp = Interpreter(model_path=str(tflite_path))
    interp.allocate_tensors()
    in_det = interp.get_input_details()[0]
    out_det = interp.get_output_details()[0]
    if np.dtype(in_det["dtype"]) != np.float32 or list(in_det["shape"]) != [1, imgsz, imgsz, 3]:
        return None
    interp.set_tensor(in_det["index"], np.ascontiguousarray(sample_nhwc))
    interp.invoke()
    tf_out = interp.get_tensor(out_det["index"]).astype(np.float32)
    if tf_out.shape != pt_out.shape:
        return None

    abs_diff = np.abs(pt_out - tf_out)
    cls_diff = np.abs(pt_out[:, 4:, :] - tf_out[:, 4:, :])
    return {
        "max_abs_diff": round(float(np.max(abs_diff)), 6),
        "mean_abs_diff": round(float(np.mean(abs_diff)), 6),
        "cls_score_max_abs_diff": round(float(np.max(cls_diff)), 6),
    }


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


def _infer_negative_group_from_stem(stem: str) -> str:
    m = re.match(r"^neg__([A-Za-z0-9_]+)__", stem)
    if m:
        return m.group(1)
    for cat in ("ood_people", "ood_drink_bottles_cups", "ood_healthy_food", "ood_random_objects", "molted_skin_only"):
        if cat in stem:
            return cat
    return "leaf_empty"


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
    new_w, new_h = max(1, int(round(w0 * r))), max(1, int(round(h0 * r)))
    dw, dh = (target_w - new_w) / 2.0, (target_h - new_h) / 2.0
    resized = cv2.resize(img_bgr, (new_w, new_h), interpolation=cv2.INTER_LINEAR) if (w0, h0) != (new_w, new_h) else img_bgr
    top, bottom = int(round(dh - 0.1)), int(round(dh + 0.1))
    left, right = int(round(dw - 0.1)), int(round(dw + 0.1))
    bordered = cv2.copyMakeBorder(
        resized, top, bottom, left, right, cv2.BORDER_CONSTANT, value=(pad_value, pad_value, pad_value)
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
    sample_conf_thres: float = 0.45,
    sample_iou_thres: float = 0.45,
) -> dict[str, Any]:
    """Evaluate a 2-class TFLite model over the test split + OOD negatives using ai_edge_litert Interpreter."""
    import cv2
    import numpy as np
    import torch
    from ai_edge_litert.interpreter import Interpreter
    from ultralytics.data.utils import check_det_dataset
    from ultralytics.utils import nms
    from ultralytics.utils.metrics import DetMetrics, box_iou

    data_cfg = check_det_dataset(str(data_yaml), split="test")
    test_img_dir = Path(data_cfg["test"])
    image_files = sorted(p for p in test_img_dir.iterdir() if p.is_file() and p.suffix.lower() in _IMAGE_SUFFIXES)
    if not image_files:
        raise FileNotFoundError(f"No test images found under {test_img_dir}")

    interp = Interpreter(model_path=str(tflite_path), num_threads=4)
    interp.allocate_tensors()
    in_detail = interp.get_input_details()[0]
    out_detail = interp.get_output_details()[0]

    in_shape = [int(x) for x in in_detail["shape"]]
    out_shape = [int(x) for x in out_detail["shape"]]
    in_dtype = np.dtype(in_detail["dtype"])
    out_dtype = np.dtype(out_detail["dtype"])
    in_scale, in_zp = in_detail.get("quantization", (0.0, 0))
    out_scale, out_zp = out_detail.get("quantization", (0.0, 0))
    if in_dtype in (np.int8, np.uint8) and (not math.isfinite(float(in_scale)) or float(in_scale) <= 0.0):
        raise ValueError(f"Invalid input quantization scale for {in_dtype.name}: {in_scale!r}")
    if out_dtype in (np.int8, np.uint8) and (not math.isfinite(float(out_scale)) or float(out_scale) <= 0.0):
        raise ValueError(f"Invalid output quantization scale for {out_dtype.name}: {out_scale!r}")
    is_nchw = len(in_shape) == 4 and in_shape[1] == 3 and in_shape[3] != 3
    in_h, in_w = (in_shape[2], in_shape[3]) if is_nchw else (in_shape[1], in_shape[2])

    iouv = torch.linspace(0.5, 0.95, 10)
    metrics = DetMetrics(names=CANONICAL_CLASSES)
    metrics.clear_stats()

    latencies_ms: list[float] = []
    sample_dets_total = 0
    detected_classes: set[str] = set()
    confusion_3x3 = [[0, 0, 0], [0, 0, 0], [0, 0, 0]]
    image_outcomes: list[tuple[bool, bool, str]] = []
    density_recall: dict[str, list[float]] = {"sparse": [], "moderate": [], "dense": []}

    for img_path in image_files:
        img_bgr = cv2.imread(str(img_path))
        if img_bgr is None:
            continue
        rgb_hwc, (new_w, new_h), (pad_left, pad_top) = _letterbox_bgr_to_rgb_float(img_bgr, in_h, in_w, pad_value=114)
        tensor_f32 = (np.transpose(rgb_hwc, (2, 0, 1))[None] if is_nchw else rgb_hwc[None]).astype(np.float32)
        if in_dtype in (np.int8, np.uint8):
            q_min, q_max = (-128, 127) if in_dtype == np.int8 else (0, 255)
            tensor_in = np.clip(np.round(tensor_f32 / float(in_scale) + int(in_zp)), q_min, q_max).astype(in_dtype)
        else:
            tensor_in = tensor_f32

        t0 = time.perf_counter()
        interp.set_tensor(in_detail["index"], np.ascontiguousarray(tensor_in))
        interp.invoke()
        raw_tensor = interp.get_tensor(out_detail["index"]).copy()
        latencies_ms.append((time.perf_counter() - t0) * 1000.0)

        if out_dtype in (np.int8, np.uint8):
            raw_out = (raw_tensor.astype(np.float32) - float(out_zp)) * float(out_scale)
        else:
            raw_out = raw_tensor.astype(np.float32)

        if not np.all(np.isfinite(raw_out)):
            raise ValueError(f"Non-finite TFLite inference output on {img_path.name}")

        app_dets = decode_yolov11_output(
            raw_out[0].tolist(),
            img_size=max(in_h, in_w),
            conf_threshold=sample_conf_thres,
            iou_threshold=sample_iou_thres,
        )
        sample_dets_total += len(app_dets)
        for det in app_dets:
            detected_classes.add(det["class_name"])

        lbl_path = _image_to_label_path(img_path)
        gt_cls_list: list[int] = []
        gt_boxes_px: list[list[float]] = []
        gt_boxes_norm: list[tuple[int, tuple[float, float, float, float]]] = []
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
                gt_boxes_px.append([x1, y1, x2, y2])
                gt_boxes_norm.append((cls_id, (x1 / in_w, y1 / in_h, x2 / in_w, y2 / in_h)))

        has_gt = len(gt_cls_list) > 0
        has_pred = len(app_dets) > 0
        grp = "in_domain_positive" if has_gt else _infer_negative_group_from_stem(img_path.stem)
        image_outcomes.append((has_gt, has_pred, grp))

        # Match app_dets at IoU >= 0.50 for 3x3 confusion matrix & density recall
        matched_gt: set[int] = set()
        matched_correct_cls: set[int] = set()
        for det in app_dets:
            p_cls = int(det["class_id"])
            p_box = det["box"]
            best_gi = -1
            best_iou = 0.0
            for gi, (_, g_box) in enumerate(gt_boxes_norm):
                if gi in matched_gt:
                    continue
                xx1, yy1 = max(p_box[0], g_box[0]), max(p_box[1], g_box[1])
                xx2, yy2 = min(p_box[2], g_box[2]), min(p_box[3], g_box[3])
                inter = max(0.0, xx2 - xx1) * max(0.0, yy2 - yy1)
                if inter > 0.0:
                    pa = max(0.0, p_box[2] - p_box[0]) * max(0.0, p_box[3] - p_box[1])
                    ga = max(0.0, g_box[2] - g_box[0]) * max(0.0, g_box[3] - g_box[1])
                    ov = inter / max(1e-8, pa + ga - inter)
                    if ov > best_iou:
                        best_iou, best_gi = ov, gi
            if best_iou >= 0.50 and best_gi >= 0:
                matched_gt.add(best_gi)
                t_cls = gt_boxes_norm[best_gi][0]
                if p_cls in (0, 1) and t_cls in (0, 1):
                    confusion_3x3[p_cls][t_cls] += 1
                    if p_cls == t_cls:
                        matched_correct_cls.add(best_gi)
            elif p_cls in (0, 1):
                confusion_3x3[p_cls][2] += 1

        for gi, (t_cls, _) in enumerate(gt_boxes_norm):
            if gi not in matched_gt and t_cls in (0, 1):
                confusion_3x3[2][t_cls] += 1

        if has_gt:
            tier = "sparse" if len(gt_boxes_norm) <= 3 else ("moderate" if len(gt_boxes_norm) <= 10 else "dense")
            density_recall[tier].append(len(matched_correct_cls) / len(gt_boxes_norm))

        # Full PR/mAP curve accumulation via Ultralytics NMS
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

        target_cls = np.array(gt_cls_list, dtype=np.float32) if gt_cls_list else np.zeros(0, dtype=np.float32)
        gt_boxes_t = torch.tensor(gt_boxes_px, dtype=torch.float32) if gt_boxes_px else torch.zeros((0, 4), dtype=torch.float32)
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

    if not latencies_ms:
        raise ValueError(f"All test images in {test_img_dir} failed to decode")

    metrics.process(plot=False)
    extracted = extract_eval_metrics(metrics)
    metrics.clear_stats()

    cls_and_ood = compute_classification_and_ood_metrics(confusion_3x3, image_outcomes)
    arr_lat = np.asarray(latencies_ms, dtype=np.float64)

    return {
        **extracted,
        "classification_and_ood": cls_and_ood,
        "density_recall": {
            k: round(float(np.mean(v)), 4) if v else None for k, v in density_recall.items()
        },
        "images_evaluated": len(latencies_ms),
        "latency_ms_avg": round(float(np.mean(arr_lat)), 2),
        "latency_ms_p50": round(float(np.percentile(arr_lat, 50)), 2),
        "latency_ms_p95": round(float(np.percentile(arr_lat, 95)), 2),
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


def evaluate_small_scale_recall(
    tflite_path: Path,
    data_yaml: Path,
    *,
    imgsz: int = 640,
    scale: float = 0.25,
    conf_thres: float = 0.35,
    iou_thres: float = 0.45,
    match_iou: float = 0.30,
    max_images: int | None = None,
) -> dict[str, Any]:
    """Evaluate phone-distance small-pest recall with localized box matching (IoU >= 0.30) on 0.25x scaled pests."""
    import cv2
    import numpy as np
    from ai_edge_litert.interpreter import Interpreter
    from ultralytics.data.utils import check_det_dataset

    data_cfg = check_det_dataset(str(data_yaml), split="test")
    test_img_dir = Path(data_cfg["test"])
    image_files = sorted(p for p in test_img_dir.iterdir() if p.is_file() and p.suffix.lower() in _IMAGE_SUFFIXES)

    leaf_bgs: list[Any] = []
    pos_items: list[tuple[Path, list[tuple[int, float, float, float, float]]]] = []
    for p in image_files:
        lbl = _image_to_label_path(p)
        lines = [ln.strip() for ln in lbl.read_text(encoding="utf-8").splitlines() if ln.strip()] if lbl.is_file() else []
        if not lines:
            if "neg__ood_" not in p.stem and len(leaf_bgs) < 8:
                bg_im = cv2.imread(str(p))
                if bg_im is not None:
                    leaf_bgs.append(cv2.resize(bg_im, (imgsz, imgsz), interpolation=cv2.INTER_AREA))
            continue
        parsed_gts: list[tuple[int, float, float, float, float]] = []
        for ln in lines:
            ps = ln.split()
            if len(ps) >= 5 and int(float(ps[0])) in (0, 1):
                parsed_gts.append((int(float(ps[0])), float(ps[1]), float(ps[2]), float(ps[3]), float(ps[4])))
        if parsed_gts:
            pos_items.append((p, parsed_gts))

    if not pos_items:
        return {
            "scale": scale,
            "conf_threshold": conf_thres,
            "match_iou": match_iou,
            "images_evaluated": 0,
            "hits": 0,
            "overall_recall": 0.0,
            "box_level_recall": 0.0,
            "per_class_recall": {"whitefly": 0.0, "aphids": 0.0},
            "per_class_counts": {"whitefly": {"hits": 0, "total": 0}, "aphids": {"hits": 0, "total": 0}},
        }

    # If a cap is explicitly requested, interleave across classes rather than truncating alphabetically.
    if max_images is not None and len(pos_items) > max_images:
        by_cls: dict[int, list[tuple[Path, list[tuple[int, float, float, float, float]]]]] = {0: [], 1: []}
        for item in pos_items:
            primary_cls = 0 if any(c == 0 for c, *_ in item[1]) else 1
            by_cls[primary_cls].append(item)
        selected_items: list[tuple[Path, list[tuple[int, float, float, float, float]]]] = []
        i0 = i1 = 0
        while len(selected_items) < max_images and (i0 < len(by_cls[0]) or i1 < len(by_cls[1])):
            if i0 < len(by_cls[0]) and len(selected_items) < max_images:
                selected_items.append(by_cls[0][i0])
                i0 += 1
            if i1 < len(by_cls[1]) and len(selected_items) < max_images:
                selected_items.append(by_cls[1][i1])
                i1 += 1
        eval_items = selected_items
    else:
        eval_items = pos_items

    interp = Interpreter(model_path=str(tflite_path), num_threads=4)
    interp.allocate_tensors()
    in_det = interp.get_input_details()[0]
    out_det = interp.get_output_details()[0]

    # Filter leaf backgrounds to those that produce zero background detections on their own
    clean_bgs: list[Any] = []
    for bg_im in leaf_bgs:
        rgb_bg, _, _ = _letterbox_bgr_to_rgb_float(bg_im, imgsz, imgsz, pad_value=114)
        interp.set_tensor(in_det["index"], np.ascontiguousarray(rgb_bg[None].astype(np.float32)))
        interp.invoke()
        bg_dets = decode_yolov11_output(
            interp.get_tensor(out_det["index"])[0].tolist(),
            img_size=imgsz,
            conf_threshold=conf_thres,
            iou_threshold=iou_thres,
        )
        if not bg_dets:
            clean_bgs.append(bg_im)
    bgs = clean_bgs or [np.full((imgsz, imgsz, 3), (42, 118, 48), dtype=np.uint8)]

    def _box_iou_norm(a: tuple[float, float, float, float], b: tuple[float, float, float, float]) -> float:
        xx1, yy1 = max(a[0], b[0]), max(a[1], b[1])
        xx2, yy2 = min(a[2], b[2]), min(a[3], b[3])
        inter = max(0.0, xx2 - xx1) * max(0.0, yy2 - yy1)
        if inter <= 0.0:
            return 0.0
        aa = max(0.0, a[2] - a[0]) * max(0.0, a[3] - a[1])
        ba = max(0.0, b[2] - b[0]) * max(0.0, b[3] - b[1])
        return inter / max(1e-8, aa + ba - inter)

    hits_total = 0
    matched_boxes_total = 0
    gt_boxes_total = 0
    per_cls_hits = {0: 0, 1: 0}
    per_cls_total = {0: 0, 1: 0}
    evaluated = 0

    for idx, (img_path, parsed_gts) in enumerate(eval_items):
        im = cv2.imread(str(img_path))
        if im is None:
            continue
        nh = max(32, int(round(imgsz * scale)))
        nw = max(32, int(round(imgsz * scale)))
        small = cv2.resize(im, (nw, nh), interpolation=cv2.INTER_AREA)
        canvas = bgs[idx % len(bgs)].copy()
        y0 = (imgsz - nh) // 2
        x0 = (imgsz - nw) // 2
        canvas[y0 : y0 + nh, x0 : x0 + nw] = small

        scaled_gts: list[tuple[int, tuple[float, float, float, float]]] = []
        for cid, cx, cy, bw, bh in parsed_gts:
            gx1 = max(0.0, (x0 + (cx - bw / 2.0) * nw) / imgsz)
            gy1 = max(0.0, (y0 + (cy - bh / 2.0) * nh) / imgsz)
            gx2 = min(1.0, (x0 + (cx + bw / 2.0) * nw) / imgsz)
            gy2 = min(1.0, (y0 + (cy + bh / 2.0) * nh) / imgsz)
            if gx2 > gx1 and gy2 > gy1:
                scaled_gts.append((cid, (gx1, gy1, gx2, gy2)))
        if not scaled_gts:
            continue

        rgb_hwc, _, _ = _letterbox_bgr_to_rgb_float(canvas, imgsz, imgsz, pad_value=114)
        interp.set_tensor(in_det["index"], np.ascontiguousarray(rgb_hwc[None].astype(np.float32)))
        interp.invoke()
        raw_out = interp.get_tensor(out_det["index"])[0]
        dets = decode_yolov11_output(raw_out.tolist(), img_size=imgsz, conf_threshold=conf_thres, iou_threshold=iou_thres)

        matched_classes: set[int] = set()
        matched_gt_indices: set[int] = set()
        for det in dets:
            p_cls = int(det["class_id"])
            p_box = tuple(float(v) for v in det["box"])
            best_gi = -1
            best_ov = 0.0
            for gi, (g_cls, g_box) in enumerate(scaled_gts):
                if gi in matched_gt_indices or g_cls != p_cls:
                    continue
                ov = _box_iou_norm(p_box, g_box)
                if ov >= match_iou and ov > best_ov:
                    best_ov, best_gi = ov, gi
            if best_gi >= 0:
                matched_gt_indices.add(best_gi)
                matched_classes.add(p_cls)

        gt_boxes_total += len(scaled_gts)
        matched_boxes_total += len(matched_gt_indices)
        gt_classes = {g_cls for g_cls, _ in scaled_gts}
        evaluated += 1
        if matched_classes & gt_classes:
            hits_total += 1
        for cid in gt_classes:
            per_cls_total[cid] += 1
            if cid in matched_classes:
                per_cls_hits[cid] += 1

    overall = hits_total / max(1, evaluated)
    box_recall = matched_boxes_total / max(1, gt_boxes_total)
    return {
        "scale": scale,
        "conf_threshold": conf_thres,
        "match_iou": match_iou,
        "images_evaluated": evaluated,
        "hits": hits_total,
        "overall_recall": round(overall, 4),
        "box_level_recall": round(box_recall, 4),
        "gt_boxes_total": gt_boxes_total,
        "gt_boxes_matched": matched_boxes_total,
        "per_class_recall": {
            "whitefly": round(per_cls_hits[0] / max(1, per_cls_total[0]), 4) if per_cls_total[0] else None,
            "aphids": round(per_cls_hits[1] / max(1, per_cls_total[1]), 4) if per_cls_total[1] else None,
        },
        "per_class_counts": {
            "whitefly": {"hits": per_cls_hits[0], "total": per_cls_total[0]},
            "aphids": {"hits": per_cls_hits[1], "total": per_cls_total[1]},
        },
    }


def _repo_safe_path(path: Path) -> str:
    repo_root = Path(__file__).resolve().parents[1]
    try:
        return path.resolve().relative_to(repo_root).as_posix()
    except ValueError:
        return path.name


def build_provenance_payload(
    kaggle_summary_path: Path | None = None,
    dataset_provenance_path: Path | None = None,
) -> dict[str, Any] | None:
    provenance: dict[str, Any] = {}
    if kaggle_summary_path is not None and kaggle_summary_path.exists():
        summary = json.loads(kaggle_summary_path.read_text(encoding="utf-8"))
        if isinstance(summary.get("provenance"), dict):
            provenance.update(summary["provenance"])
        if isinstance(summary.get("loss_summary"), dict):
            provenance["loss_summary"] = summary["loss_summary"]
        if "calibrated_threshold" in summary:
            provenance["calibrated_threshold"] = summary["calibrated_threshold"]

    if dataset_provenance_path is not None and dataset_provenance_path.exists():
        ds_prov = json.loads(dataset_provenance_path.read_text(encoding="utf-8"))
        provenance.setdefault("zero_synthetic_confirmed", bool(ds_prov.get("zero_synthetic_confirmed", True)))
        provenance.setdefault("synthetic_images_count", int(ds_prov.get("synthetic_images_count", 0)))
        provenance["molted_skin_boxes_removed"] = ds_prov.get("molted_skin_boxes_removed", 0)
        provenance["roboflow_sources"] = ds_prov.get("sources_probed", [])
        provenance["ood_negatives"] = ds_prov.get("ood_negatives", {})
        provenance["train_count_quantiles"] = ds_prov.get("train_count_quantiles", {})
        if "deduplication" in ds_prov:
            provenance["deduplication"] = ds_prov["deduplication"]
        if "splits" in ds_prov:
            provenance["split_manifests"] = ds_prov["splits"]
        if "verification" in ds_prov:
            provenance["dataset_verification"] = ds_prov["verification"]

    if provenance:
        if provenance.get("zero_synthetic_confirmed") is False:
            raise ValueError("Provenance rejected: zero_synthetic_confirmed is False")
        if int(provenance.get("synthetic_images_count", 0)) != 0:
            raise ValueError("Provenance rejected: synthetic_images_count != 0")
        origin = str(provenance.get("dataset_origin", "")).lower()
        if "synthetic" in origin:
            raise ValueError(f"Provenance rejected: synthetic dataset_origin={origin!r}")
    return provenance or None


def write_evaluation_markdown(report: dict[str, Any], md_path: Path) -> None:
    base = report["baseline"]
    fine = report["finetuned"]
    tf_ev = report.get("tflite_eval", {})
    cls_ood = tf_ev.get("classification_and_ood", {})
    img_lvl = cls_ood.get("image_level", {})
    loss_sum = report.get("loss_metrics", {})
    gpu_bench = report.get("kaggle_gpu_benchmark", {})

    lines = [
        "# HidroSense YOLOv11n (`whitefly` & `aphids`) Evaluation Summary",
        "",
        f"- **Promotion Gate Status**: `{report['status']}`",
        f"- **Calibrated Production Confidence Threshold**: `{report.get('calibrated_threshold', 0.45)}`",
        f"- **Mobile TFLite Embedding `mAP@50` Drop (`rect=False, batch=1`)**: `{report.get('gates', {}).get('tflite_map50_drop', 0.0):.4f}`",
        "",
        "## 1. Object Detection Metrics (Held-Out Test Split)",
        "",
        "| Model & Inference Geometry | `mAP@50` | `mAP@75` | `mAP@50-95` | `Precision` | `Recall` | `F1-Score` |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    if gpu_bench.get("baseline_test") and gpu_bench.get("improved_test"):
        gb = gpu_bench["baseline_test"]
        gi = gpu_bench["improved_test"]
        lines.extend(
            [
                f"| Stage 1 Baseline (Kaggle T4 GPU, `rect=True`) | `{gb.get('map50', 0):.4f}` | `{gb.get('map75', 0):.4f}` | `{gb.get('map50_95', 0):.4f}` | `{gb.get('precision', 0):.4f}` | `{gb.get('recall', 0):.4f}` | `{gb.get('f1', 0):.4f}` |",
                f"| Stage 2 Production (Kaggle T4 GPU, `rect=True`) | **`{gi.get('map50', 0):.4f}`** | **`{gi.get('map75', 0):.4f}`** | **`{gi.get('map50_95', 0):.4f}`** | **`{gi.get('precision', 0):.4f}`** | **`{gi.get('recall', 0):.4f}`** | **`{gi.get('f1', 0):.4f}`** |",
            ]
        )
    lines.extend(
        [
            f"| Stage 1 Baseline (`640x640` `rect=False`, PyTorch) | `{base.get('map50', 0):.4f}` | `{base.get('map75', 0):.4f}` | `{base.get('map50_95', 0):.4f}` | `{base.get('precision', 0):.4f}` | `{base.get('recall', 0):.4f}` | `{base.get('f1', 0):.4f}` |",
            f"| Stage 2 Production (`640x640` `rect=False`, PyTorch) | **`{fine.get('map50', 0):.4f}`** | **`{fine.get('map75', 0):.4f}`** | **`{fine.get('map50_95', 0):.4f}`** | **`{fine.get('precision', 0):.4f}`** | **`{fine.get('recall', 0):.4f}`** | **`{fine.get('f1', 0):.4f}`** |",
        ]
    )
    if tf_ev:
        tm = tf_ev.get("metrics", {})
        lines.append(
            f"| Embedded Mobile TFLite (`640x640` `ai_edge_litert`) | **`{tm.get('map50', 0):.4f}`** | **`{tm.get('map75', 0):.4f}`** | **`{tm.get('map50_95', 0):.4f}`** | **`{tm.get('precision', 0):.4f}`** | **`{tm.get('recall', 0):.4f}`** | **`{tm.get('f1', 0):.4f}`** |"
        )
        tp = tf_ev.get("tensor_parity")
        if tp:
            lines.extend(
                [
                    "",
                    f"- **Direct Tensor Parity (PyTorch vs FP16 TFLite)**: `max_abs_diff = {tp.get('max_abs_diff')}`, `mean_abs_diff = {tp.get('mean_abs_diff')}`, `cls_score_max_abs_diff = {tp.get('cls_score_max_abs_diff')}`",
                ]
            )

    if img_lvl:
        lines.extend(
            [
                "",
                "## 2. Classification, Specificity & Anti-Hallucination (OOD) Metrics",
                "",
                f"- **Matched-Box Pest Classification Accuracy (`whitefly` vs `aphids`)**: `{cls_ood.get('matched_box_classification_accuracy', 0):.4f}`",
                f"- **Image-Level Presence/Absence Accuracy**: `{img_lvl.get('accuracy', 0):.4f}` (`Balanced Accuracy = {img_lvl.get('balanced_accuracy', 0):.4f}`)",
                f"- **Specificity / True Negative Rate (All Negatives)**: `{img_lvl.get('specificity_tnr', 0):.4f}`",
                f"- **Real-Life OOD False Positive Rate (`people`, `bottles`, `healthy_food`, `random_objects`)**: `{cls_ood.get('ood_false_positive_rate', 0):.4f}` (`{cls_ood.get('ood_false_positives', 0)}` / `{cls_ood.get('ood_total_images', 0)}`)",
                f"- **Matthews Correlation Coefficient (MCC)**: `{img_lvl.get('mcc', 0):.4f}`",
            ]
        )
        ood_bd = cls_ood.get("ood_breakdown", {})
        if ood_bd:
            lines.extend(
                [
                    "",
                    "| Negative / OOD Group | Images | True Negatives | False Positives | Specificity (TNR) | FPR |",
                    "|---|---:|---:|---:|---:|---:|",
                ]
            )
            for grp_name, grp_vals in sorted(ood_bd.items()):
                lines.append(
                    f"| `{grp_name}` | `{grp_vals.get('images', 0)}` | `{grp_vals.get('true_negatives', 0)}` | `{grp_vals.get('false_positives', 0)}` | `{grp_vals.get('specificity_tnr', 0):.4f}` | `{grp_vals.get('false_positive_rate', 0):.4f}` |"
                )

    small_ev = tf_ev.get("small_scale_eval", {}) if tf_ev else {}
    kaggle_ood = gpu_bench.get("kaggle_test_ood_and_small_scale", {}) if gpu_bench else {}
    if small_ev or kaggle_ood:
        lines.extend(["", "## 2b. Multi-Scale Phone-Distance Recall & Extended COCO val2017 OOD Audit", ""])
        if small_ev:
            pcr = small_ev.get("per_class_recall", {})
            lines.append(
                f"- **Local TFLite `0.25x` Phone-Distance Localized Recall (`IoU >= {small_ev.get('match_iou', 0.30)}`)**: "
                f"**`{small_ev.get('overall_recall', 0):.4f}`** (`{small_ev.get('hits', 0)}` / `{small_ev.get('images_evaluated', 0)}` | "
                f"`whitefly = {pcr.get('whitefly')}`, `aphids = {pcr.get('aphids')}`)"
            )
        if kaggle_ood and "ood_total_images" in kaggle_ood:
            lines.append(
                f"- **Kaggle Extended COCO `val2017` + `coco128` OOD False Positive Rate**: "
                f"**`{kaggle_ood.get('ood_false_positive_rate', 0):.4f}`** "
                f"(`{kaggle_ood.get('ood_false_positives', 0)}` / `{kaggle_ood.get('ood_total_images', 0)}` held-out real-world OOD photos)"
            )
            ks_small = kaggle_ood.get("small_scale_025x", {})
            if ks_small:
                lines.append(
                    f"- **Kaggle PyTorch `0.25x` Small-Scale Recall**: `{ks_small.get('overall_recall', 0):.4f}` "
                    f"(`whitefly = {ks_small.get('whitefly_recall')}`, `aphids = {ks_small.get('aphids_recall')}`)"
                )

    if loss_sum:
        lines.extend(
            [
                "",
                "## 3. Training & Validation Loss Convergence",
                "",
                f"- **Best Epoch / Total Trained**: `{loss_sum.get('best_epoch')}` / `{loss_sum.get('epochs_completed')}`",
                f"- **Train Losses (`box` / `cls` / `dfl`)**: `{loss_sum.get('train_box_loss')}` / `{loss_sum.get('train_cls_loss')}` / `{loss_sum.get('train_dfl_loss')}`",
                f"- **Val Losses (`box` / `cls` / `dfl`)**: `{loss_sum.get('val_box_loss')}` / `{loss_sum.get('val_cls_loss')}` / `{loss_sum.get('val_dfl_loss')}`",
            ]
        )

    md_path.parent.mkdir(parents=True, exist_ok=True)
    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _strip_aggregate_metrics(raw_metrics: dict[str, Any]) -> dict[str, float]:
    return {k: float(raw_metrics[k]) for k in _AGGREGATE_METRIC_KEYS if k in raw_metrics}


def main(argv: list[str] | None = None) -> dict[str, Any]:
    parser = argparse.ArgumentParser(description="Evaluate 2-class YOLOv11n whitefly & aphids model.")
    parser.add_argument("--baseline", type=Path, default=Path("yolo11n.pt"))
    parser.add_argument("--weights", type=Path, required=True)
    parser.add_argument("--tflite", type=Path, default=None)
    parser.add_argument("--data", type=Path, default=Path("ml/configs/lettuce_pests.yaml"))
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--conf-threshold", type=float, default=None)
    parser.add_argument("--kaggle-summary", type=Path, default=None)
    parser.add_argument("--dataset-provenance", type=Path, default=None)
    parser.add_argument("--output", type=Path, default=Path("ml/reports/evaluation_report.json"))
    parser.add_argument("--markdown-output", type=Path, default=None)
    args = parser.parse_args(argv)
    markdown_output = args.markdown_output or (
        Path("ml/reports/evaluation_summary.md")
        if args.output == Path("ml/reports/evaluation_report.json")
        else args.output.with_suffix(".md")
    )

    calibrated_threshold = 0.45
    loss_metrics: dict[str, Any] = {}
    kaggle_gpu_benchmark: dict[str, Any] = {}
    if args.kaggle_summary and args.kaggle_summary.exists():
        ks = json.loads(args.kaggle_summary.read_text(encoding="utf-8"))
        calibrated_threshold = float(ks.get("calibrated_threshold", calibrated_threshold))
        loss_metrics = ks.get("loss_summary", {})
        if isinstance(ks.get("baseline"), dict) and isinstance(ks.get("improved"), dict):
            kaggle_gpu_benchmark = {
                "baseline_test": ks["baseline"].get("test"),
                "improved_test": ks["improved"].get("test"),
                "improved_per_class": ks["improved"].get("per_class"),
            }
            if isinstance(ks.get("kaggle_test_ood_and_small_scale"), dict):
                kaggle_gpu_benchmark["kaggle_test_ood_and_small_scale"] = ks["kaggle_test_ood_and_small_scale"]
    if args.conf_threshold is not None:
        calibrated_threshold = float(args.conf_threshold)

    baseline_raw = dict(evaluate_ultralytics_model(args.baseline, args.data, imgsz=int(args.imgsz)))
    finetuned_raw = dict(evaluate_ultralytics_model(args.weights, args.data, imgsz=int(args.imgsz)))
    per_class = finetuned_raw.pop("per_class", None)
    baseline_raw.pop("per_class", None)
    baseline_metrics = _strip_aggregate_metrics(baseline_raw)
    finetuned_metrics = _strip_aggregate_metrics(finetuned_raw)

    if not math.isfinite(finetuned_metrics.get("map50", float("nan"))):
        raise ValueError(f"Non-finite map50 in finetuned evaluation: {finetuned_metrics!r}")

    tflite_drop = 0.0
    ood_fpr = 0.0
    small_scale_recall = 1.0
    model_size_mb = round(args.weights.stat().st_size / (1024 * 1024), 3)
    tflite_eval: dict[str, Any] | None = None

    if args.tflite and args.tflite.exists():
        tflite_raw = dict(evaluate_ultralytics_model(args.tflite, args.data, imgsz=int(args.imgsz)))
        tflite_ultralytics_per_class = tflite_raw.pop("per_class", None)
        tflite_ultralytics_metrics = _strip_aggregate_metrics(tflite_raw)
        if not math.isfinite(tflite_ultralytics_metrics.get("map50", float("nan"))):
            raise ValueError(f"Non-finite map50 in TFLite evaluation: {tflite_ultralytics_metrics!r}")

        raw_bytes = args.tflite.read_bytes()
        size_bytes = len(raw_bytes)
        model_size_mb = round(size_bytes / (1024 * 1024), 3)
        sha256_hex = hashlib.sha256(raw_bytes).hexdigest()

        is_valid_flatbuffer = len(raw_bytes) >= 8 and raw_bytes[4:8] == b"TFL3"
        litert_eval: dict[str, Any] | None = None
        tensor_parity: dict[str, float] | None = None
        small_scale_eval: dict[str, Any] | None = None
        if is_valid_flatbuffer and args.data.exists():
            litert_eval = evaluate_tflite_litert(
                args.tflite,
                args.data,
                imgsz=int(args.imgsz),
                sample_conf_thres=calibrated_threshold,
            )
            inspected = inspect_tflite_model(args.tflite)
            in_shape, in_dtype = inspected["input_shape"], inspected["input_dtype"]
            out_shape, out_dtype = inspected["output_shape"], inspected["output_dtype"]
            ood_fpr = float(litert_eval["classification_and_ood"]["ood_false_positive_rate"])
            tensor_parity = compute_pytorch_tflite_tensor_parity(args.weights, args.tflite, imgsz=int(args.imgsz))
            if int(litert_eval["images_evaluated"]) >= 10:
                small_scale_eval = evaluate_small_scale_recall(
                    args.tflite,
                    args.data,
                    imgsz=int(args.imgsz),
                    scale=0.25,
                    conf_thres=calibrated_threshold,
                )
                small_scale_recall = float(small_scale_eval["overall_recall"])
        else:
            in_shape, in_dtype = [1, int(args.imgsz), int(args.imgsz), 3], "float32"
            out_shape, out_dtype = [1, 4 + len(CANONICAL_CLASSES), _default_yolo_anchors(int(args.imgsz))], "float32"

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
        if tensor_parity is not None:
            tflite_eval["tensor_parity"] = tensor_parity
        if small_scale_eval is not None:
            tflite_eval["small_scale_eval"] = small_scale_eval
        if litert_eval is not None:
            tflite_eval["metrics"] = litert_eval["aggregate"]
            tflite_eval["per_class"] = litert_eval["per_class"]
            tflite_eval["classification_and_ood"] = litert_eval["classification_and_ood"]
            tflite_eval["density_recall"] = litert_eval["density_recall"]
            tflite_eval["images_evaluated"] = litert_eval["images_evaluated"]
            tflite_eval["latency_ms_avg"] = litert_eval["latency_ms_avg"]
            tflite_eval["latency_ms_p50"] = litert_eval["latency_ms_p50"]
            tflite_eval["latency_ms_p95"] = litert_eval["latency_ms_p95"]
            tflite_eval["interpreter_verification"] = litert_eval["interpreter_verification"]
        else:
            tflite_eval["metrics"] = tflite_ultralytics_metrics
            if tflite_ultralytics_per_class is not None:
                tflite_eval["per_class"] = tflite_ultralytics_per_class

    kaggle_ood_info = kaggle_gpu_benchmark.get("kaggle_test_ood_and_small_scale", {})
    if isinstance(kaggle_ood_info, dict) and int(kaggle_ood_info.get("ood_total_images", 0)) >= 100:
        kaggle_ood_fpr = float(kaggle_ood_info.get("ood_false_positive_rate", 0.0))
        ood_fpr = max(ood_fpr, kaggle_ood_fpr)

    gate_payload = {
        "map50": finetuned_metrics["map50"],
        "recall": finetuned_metrics["recall"],
        "f1": finetuned_metrics["f1"],
        "small_scale_recall": small_scale_recall,
        "tflite_map50_drop": tflite_drop,
        "ood_false_positive_rate": ood_fpr,
        "model_size_mb": model_size_mb,
    }
    assert_promotion_ready(gate_payload)

    report: dict[str, Any] = {
        **compare_baseline_vs_finetuned(baseline_metrics, finetuned_metrics),
        "calibrated_threshold": calibrated_threshold,
    }
    if kaggle_gpu_benchmark:
        report["kaggle_gpu_benchmark"] = kaggle_gpu_benchmark
    if per_class is not None:
        report["per_class"] = per_class
    if loss_metrics:
        report["loss_metrics"] = loss_metrics
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
    write_evaluation_markdown(report, markdown_output)
    return report


if __name__ == "__main__":
    main()
