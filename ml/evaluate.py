from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

PROMOTION_GATES: dict[str, tuple[str, float]] = {
    "map50": ("min", 0.70),
    "recall": ("min", 0.65),
    "tflite_map50_drop": ("max", 0.015),
    "model_size_mb": ("max", 6.0),
}


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
    deltas = {
        f"{metric}_delta": round(finetuned.get(metric, 0.0) - baseline.get(metric, 0.0), 4)
        for metric in ("map50", "map50_95", "precision", "recall")
    }
    return {
        "baseline": baseline,
        "finetuned": finetuned,
        "improvements": deltas,
        "beats_baseline": deltas["map50_delta"] > 0.0 and deltas["recall_delta"] >= 0.0,
    }


def evaluate_ultralytics_model(weights_path: Path, data_yaml: Path, imgsz: int = 640) -> dict[str, Any]:
    from ultralytics import YOLO

    model = YOLO(str(weights_path))
    val_res = model.val(data=str(data_yaml), split="test", imgsz=imgsz, verbose=False)
    box = val_res.box
    precision = float(box.mp)
    recall = float(box.mr)
    f1 = 2 * precision * recall / max(1e-8, precision + recall)
    return {
        "map50": round(float(box.map50), 4),
        "map50_95": round(float(box.map), 4),
        "precision": round(precision, 4),
        "recall": round(recall, 4),
        "f1": round(f1, 4),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Evaluate YOLOv11n lettuce pest detection model.")
    parser.add_argument("--baseline", type=Path, default=Path("yolo11n.pt"))
    parser.add_argument("--weights", type=Path, required=True)
    parser.add_argument("--tflite", type=Path, default=None)
    parser.add_argument("--data", type=Path, default=Path("ml/configs/lettuce_pests.yaml"))
    parser.add_argument("--output", type=Path, default=Path("ml/reports/evaluation_report.json"))
    args = parser.parse_args()

    baseline_metrics = evaluate_ultralytics_model(args.baseline, args.data)
    finetuned_metrics = evaluate_ultralytics_model(args.weights, args.data)

    tflite_drop = 0.0
    model_size_mb = round(args.weights.stat().st_size / (1024 * 1024), 3)
    if args.tflite and args.tflite.exists():
        tflite_metrics = evaluate_ultralytics_model(args.tflite, args.data)
        tflite_drop = round(max(0.0, finetuned_metrics["map50"] - tflite_metrics["map50"]), 4)
        model_size_mb = round(args.tflite.stat().st_size / (1024 * 1024), 3)

    gate_payload = {
        "map50": finetuned_metrics["map50"],
        "recall": finetuned_metrics["recall"],
        "tflite_map50_drop": tflite_drop,
        "model_size_mb": model_size_mb,
    }
    assert_promotion_ready(gate_payload)

    report = {
        **compare_baseline_vs_finetuned(baseline_metrics, finetuned_metrics),
        "gates": gate_payload,
        "status": "PASSED",
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
