from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path
from typing import Any
from unittest.mock import patch

import numpy as np
import pytest
import yaml
from ai_edge_litert.interpreter import Interpreter
from PIL import Image

from ml import evaluate as ml_evaluate
from ml.evaluate import assert_promotion_ready, evaluate_ultralytics_model
from ml.export_tflite import build_model_metadata, decode_yolov11_output, export_model_to_flutter_assets
from ml.prepare_dataset import (
    CANONICAL_CLASSES,
    canonicalize_label_name,
    deduplicate_and_merge_sources,
    export_merged_dataset,
    stratified_split_records,
)
from ml.train import Yolo11TrainingConfig, write_kaggle_kernel_bundle

LOCAL_PATH_MARKERS: tuple[str, ...] = (
    "C:\\Users\\",
    "C:/Users/",
    "d:\\Dev\\",
    "D:\\Dev\\",
    "/home/",
    "/Users/",
)


def test_tier3_f1_to_f2_exported_data_yaml_matches_training_contract(
    tmp_path: Path,
    ml_root: Path,
    make_yolo_source: Any,
) -> None:
    samples = [{"stem": f"t3_{i}", "pattern_seed": 10 + i, "labels": [f"{i % 2} 0.5 0.5 0.25 0.25"]} for i in range(16)]
    src = make_yolo_source(tmp_path / "src", ["whitefly", "aphids"], samples)
    records, stats = deduplicate_and_merge_sources([src])
    splits = stratified_split_records(records, seed=42)
    out_dir = tmp_path / "merged"
    export_merged_dataset(splits, out_dir, stats)

    exported_yaml_path = out_dir / "data.yaml"
    exported_yaml = yaml.safe_load(exported_yaml_path.read_text(encoding="utf-8"))
    ref_yaml = yaml.safe_load((ml_root / "configs" / "lettuce_pests.yaml").read_text(encoding="utf-8"))

    cfg = Yolo11TrainingConfig(data=str(exported_yaml_path))
    assert cfg.imgsz == 640
    assert exported_yaml["nc"] == ref_yaml["nc"] == 2
    assert exported_yaml["names"] == ref_yaml["names"]

    raw_path = exported_yaml.get("path")
    base_dir = exported_yaml_path.parent if not raw_path else (Path(raw_path) if Path(raw_path).is_absolute() else (exported_yaml_path.parent / raw_path).resolve())

    for split_key in ("train", "val", "test"):
        assert exported_yaml[split_key] == ref_yaml[split_key]
        assert (base_dir / exported_yaml[split_key]).is_dir()


def test_tier3_f1_to_f4_canonical_classes_match_labels_metadata_and_decoder(ml_root: Path) -> None:
    mapped = {
        canonicalize_label_name("kutu kebul"): "whitefly",
        canonicalize_label_name("kutu daun"): "aphids",
    }
    assert mapped == {0: "whitefly", 1: "aphids"}
    assert mapped == CANONICAL_CLASSES

    labels = [line.strip() for line in (ml_root / "artifacts" / "labels.txt").read_text(encoding="utf-8").splitlines() if line.strip()]
    assert labels == [CANONICAL_CLASSES[0], CANONICAL_CLASSES[1]]

    built_meta = build_model_metadata(model_version="yolo11n-test")
    disk_meta = json.loads((ml_root / "artifacts" / "model_metadata.json").read_text(encoding="utf-8"))
    expected_classes = {"0": "whitefly", "1": "aphids"}
    assert built_meta["classes"] == expected_classes
    assert disk_meta["classes"] == expected_classes

    anchors = [
        [0.2, 0.2, 0.1, 0.1, 0.90, 0.01],
        [0.8, 0.8, 0.1, 0.1, 0.01, 0.85],
    ]
    dets = decode_yolov11_output(anchors)
    assert [(d["class_id"], d["class_name"]) for d in dets] == [(0, "whitefly"), (1, "aphids")]


def test_tier3_f1_f2_f5_env_secrets_never_leaked_into_outputs(
    tmp_path: Path,
    make_yolo_source: Any,
    monkeypatch: pytest.MonkeyPatch,
    secret_scanner: Any,
) -> None:
    rf_sentinel = "rf_" + "cross_feature_secret_sentinel_12345"
    kg_sentinel = "KGAT_" + "cross_feature_secret_sentinel_12345"
    monkeypatch.setenv("ROBOFLOW_API_KEY", rf_sentinel)
    monkeypatch.setenv("KAGGLE_API_TOKEN", kg_sentinel)

    samples = [{"stem": f"sec_{i}", "pattern_seed": 30 + i, "labels": [f"{i % 2} 0.5 0.5 0.2 0.2"]} for i in range(10)]
    src = make_yolo_source(tmp_path / "src", ["whitefly", "aphids"], samples)
    records, stats = deduplicate_and_merge_sources([src])
    splits = stratified_split_records(records, seed=42)
    merged_dir = tmp_path / "merged"
    export_merged_dataset(splits, merged_dir, stats)

    kernel_dir = tmp_path / "kernel"
    write_kaggle_kernel_bundle(kernel_dir, "adityadwiferdiansyah", dataset_sources=["adityadwiferdiansyah/ds"])

    for artifact_dir in (merged_dir, kernel_dir):
        for path in artifact_dir.rglob("*"):
            if path.is_file() and path.suffix in {".json", ".yaml", ".yml", ".py", ".txt"}:
                text = path.read_text(encoding="utf-8")
                assert rf_sentinel not in text
                assert kg_sentinel not in text
                assert secret_scanner(text) == []


def test_tier3_f4_portrait_1080x1920_letterbox_to_interpreter_to_decoder(
    ml_root: Path,
    letterbox_fn: Any,
    adapt_input_fn: Any,
    spatial_hw_fn: Any,
) -> None:
    tflite_path = ml_root / "artifacts" / "yolo11n_lettuce_pests.tflite"
    interp = Interpreter(model_path=str(tflite_path))
    interp.allocate_tensors()

    in_detail = interp.get_input_details()[0]
    out_detail = interp.get_output_details()[0]
    in_h, in_w = spatial_hw_fn(in_detail["shape"])

    portrait = Image.new("RGB", (1080, 1920), color=(35, 115, 45))
    hwc, meta = letterbox_fn(portrait, (in_h, in_w), pad_value=114)
    assert hwc.shape == (in_h, in_w, 3)
    assert hwc.dtype == np.float32
    assert 0.0 <= float(hwc.min()) <= float(hwc.max()) <= 1.0
    assert meta["pad_x"] > 0
    assert hwc[in_h // 2, 0, 0] == pytest.approx(114.0 / 255.0, abs=1e-4)

    tensor_in = adapt_input_fn(hwc, in_detail["shape"])
    interp.set_tensor(in_detail["index"], tensor_in)
    interp.invoke()
    raw_out = interp.get_tensor(out_detail["index"])

    assert np.all(np.isfinite(raw_out))
    dets = decode_yolov11_output(raw_out[0].tolist(), img_size=max(in_h, in_w), conf_threshold=0.45, iou_threshold=0.45)
    for det in dets:
        x1, y1, x2, y2 = det["box"]
        assert 0.0 <= x1 < x2 <= 1.0
        assert 0.0 <= y1 < y2 <= 1.0


def test_tier3_f3_to_f4_exported_bundle_passes_sha256_and_promotion_gates(
    tmp_path: Path,
    ml_root: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    real_tflite = ml_root / "artifacts" / "yolo11n_lettuce_pests.tflite"
    weights_pt = tmp_path / "best.pt"
    weights_pt.write_bytes(b"pt_placeholder")
    assets_dir = tmp_path / "assets"

    class _FakeYOLO:
        def __init__(self, weights: str) -> None:
            pass

        def export(self, **kwargs: Any) -> str:
            exported = tmp_path / "exported.tflite"
            exported.write_bytes(real_tflite.read_bytes())
            return str(exported)

    with patch("ultralytics.YOLO", _FakeYOLO):
        target_tflite = export_model_to_flutter_assets(weights_pt, assets_dir, img_size=640)

    metadata = json.loads((assets_dir / "model_metadata.json").read_text(encoding="utf-8"))
    actual_sha = hashlib.sha256(target_tflite.read_bytes()).hexdigest()
    assert metadata["sha256"] == actual_sha
    assert (assets_dir / "labels.txt").read_text(encoding="utf-8").splitlines() == ["whitefly", "aphids"]

    promo_candidate = tmp_path / "candidate_quantized.tflite"
    promo_candidate.write_bytes(b"\x00" * (4 * 1024 * 1024))
    out_report = tmp_path / "eval_report.json"

    def _fake_eval(path: Path, data_yaml: Path, imgsz: int = 640) -> dict[str, Any]:
        if path.suffix == ".tflite":
            return {"map50": 0.808, "map50_95": 0.55, "precision": 0.84, "recall": 0.77, "f1": 0.8035}
        if "best" in path.name:
            return {"map50": 0.812, "map50_95": 0.56, "precision": 0.85, "recall": 0.78, "f1": 0.8135}
        return {"map50": 0.18, "map50_95": 0.09, "precision": 0.25, "recall": 0.22, "f1": 0.234}

    monkeypatch.setattr(ml_evaluate, "evaluate_ultralytics_model", _fake_eval)
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "ml.evaluate",
            "--baseline",
            str(tmp_path / "base.pt"),
            "--weights",
            str(weights_pt),
            "--tflite",
            str(promo_candidate),
            "--output",
            str(out_report),
        ],
    )
    ml_evaluate.main()
    report = json.loads(out_report.read_text(encoding="utf-8"))
    assert report["status"] == "PASSED"
    assert_promotion_ready(report["gates"])


def test_tier3_f1_to_f3_disjoint_test_split_evaluated_by_litert(
    tmp_path: Path,
    ml_root: Path,
    make_yolo_source: Any,
    monkeypatch: pytest.MonkeyPatch,
    spatial_hw_fn: Any,
) -> None:
    samples = [{"stem": f"eval_{i}", "pattern_seed": 40 + i, "labels": [f"{i % 2} 0.5 0.5 0.25 0.25"]} for i in range(16)]
    src = make_yolo_source(tmp_path / "src", ["whitefly", "aphids"], samples)
    records, stats = deduplicate_and_merge_sources([src])
    splits = stratified_split_records(records, seed=42)
    merged_dir = tmp_path / "merged"
    export_merged_dataset(splits, merged_dir, stats)

    tflite_path = ml_root / "artifacts" / "yolo11n_lettuce_pests.tflite"
    interp = Interpreter(model_path=str(tflite_path))
    interp.allocate_tensors()
    in_h, in_w = spatial_hw_fn(interp.get_input_details()[0]["shape"])

    monkeypatch.chdir(tmp_path)
    metrics = evaluate_ultralytics_model(tflite_path, merged_dir / "data.yaml", imgsz=max(in_h, in_w))
    assert 0.0 <= metrics["map50"] <= 1.0
    assert 0.0 <= metrics["recall"] <= 1.0


def test_tier3_f4_f5_artifacts_and_reports_free_of_secrets_and_local_paths(
    ml_root: Path,
    secret_scanner: Any,
) -> None:
    files_to_check = [
        ml_root / "artifacts" / "labels.txt",
        ml_root / "artifacts" / "model_metadata.json",
        ml_root / "reports" / "evaluation_report.json",
    ]
    for file_path in files_to_check:
        text = file_path.read_text(encoding="utf-8")
        assert secret_scanner(text) == [], f"Secret leaked in {file_path}"
        for marker in LOCAL_PATH_MARKERS:
            assert marker not in text, f"Local machine path {marker!r} leaked in {file_path}"
