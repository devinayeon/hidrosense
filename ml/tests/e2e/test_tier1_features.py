from __future__ import annotations

import hashlib
import json
import posixpath
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable
from unittest.mock import patch

try:
    from ml.tests.e2e.conftest import SECRET_PATTERNS
except ImportError:  # pragma: no cover
    from conftest import SECRET_PATTERNS

import numpy as np
import pytest
import yaml
from ai_edge_litert.interpreter import Interpreter
from PIL import Image

from ml import evaluate as ml_evaluate
from ml.evaluate import PROMOTION_GATES, assert_promotion_ready, compare_baseline_vs_finetuned, evaluate_ultralytics_model
from ml.export_tflite import build_model_metadata, decode_yolov11_output, export_model_to_flutter_assets
from ml.prepare_dataset import (
    CANONICAL_CLASSES,
    canonicalize_label_name,
    deduplicate_and_merge_sources,
    export_merged_dataset,
    stratified_split_records,
)
from ml.train import Yolo11TrainingConfig, write_kaggle_kernel_bundle


@pytest.mark.parametrize(
    ("raw_name", "expected_id"),
    [
        ("whitefly", 0),
        ("Whiteflies", 0),
        ("white-fly", 0),
        ("white_fly", 0),
        ("white fly", 0),
        ("Bemisia", 0),
        ("kutu kebul", 0),
        ("Kutu_Kebul", 0),
        ("kutu-kebul", 0),
        ("aphids", 1),
        ("Aphid", 1),
        ("Aphidoidea", 1),
        ("Myzus", 1),
        ("kutu daun", 1),
        ("Kutu_Daun", 1),
        ("kutu-daun", 1),
    ],
)
def test_f1_t1_canonical_mapping_synonyms_and_indonesian(raw_name: str, expected_id: int) -> None:
    assert CANONICAL_CLASSES == {0: "whitefly", 1: "aphids"}
    assert canonicalize_label_name(raw_name) == expected_id


def test_f1_t1_merge_split_export_end_to_end(tmp_path: Path, make_yolo_source: Any) -> None:
    src1_samples = [
        {"stem": f"s1_{i}", "pattern_seed": i + 1, "labels": [f"{i % 2} 0.5 0.5 0.25 0.25"]}
        for i in range(10)
    ]
    src2_samples = [
        {"stem": f"s2_{i}", "pattern_seed": 20 + i, "labels": [f"{i % 2} 0.4 0.6 0.2 0.3"]}
        for i in range(10)
    ]
    src1 = make_yolo_source(tmp_path / "src1", ["kutu kebul", "kutu daun", "molted skin"], src1_samples)
    src2 = make_yolo_source(tmp_path / "src2", {0: "white-fly", 1: "myzus"}, src2_samples)

    records, stats = deduplicate_and_merge_sources([src1, src2])
    assert len(records) == 20
    assert stats["boxes_kept"] == 20

    splits = stratified_split_records(records, train_ratio=0.8, val_ratio=0.1, seed=42)
    out_dir = tmp_path / "merged"
    report = export_merged_dataset(splits, out_dir, stats)

    data_yaml = yaml.safe_load((out_dir / "data.yaml").read_text(encoding="utf-8"))
    assert data_yaml["nc"] == 2
    assert data_yaml["names"] == {0: "whitefly", 1: "aphids"}
    assert data_yaml["train"] == "train/images"
    assert data_yaml["val"] == "val/images"
    assert data_yaml["test"] == "test/images"

    disk_report = json.loads((out_dir / "dataset_report.json").read_text(encoding="utf-8"))
    assert disk_report["splits"] == report["splits"]

    for split_name in ("train", "val", "test"):
        imgs = list((out_dir / split_name / "images").glob("*"))
        lbls = list((out_dir / split_name / "labels").glob("*.txt"))
        assert len(imgs) == report["splits"][split_name]["images"]
        assert len(lbls) == len(imgs)
        for lbl_file in lbls:
            for line in lbl_file.read_text(encoding="utf-8").splitlines():
                parts = line.split()
                assert int(parts[0]) in {0, 1}
                vals = [float(v) for v in parts[1:]]
                assert all(0.0 <= v <= 1.0 for v in vals)


def test_f1_t1_cross_source_phash_dedup_and_disjoint_splits(tmp_path: Path, make_yolo_source: Any) -> None:
    src1_samples = [{"stem": f"a_{i}", "pattern_seed": i, "labels": [f"{i % 2} 0.5 0.5 0.2 0.2"]} for i in range(16)]
    src2_samples = [{"stem": "dup_0", "pattern_seed": 0, "labels": ["0 0.5 0.5 0.2 0.2"]}] + [
        {"stem": f"b_{i}", "pattern_seed": 100 + i, "labels": [f"{i % 2} 0.5 0.5 0.2 0.2"]} for i in range(14)
    ]

    src1 = make_yolo_source(tmp_path / "ds1", ["whitefly", "aphids"], src1_samples)
    src2 = make_yolo_source(tmp_path / "ds2", ["whitefly", "aphids"], src2_samples)

    records, stats = deduplicate_and_merge_sources([src1, src2])
    assert stats["duplicates_removed"] >= 1
    assert len(records) == 30

    splits = stratified_split_records(records, train_ratio=0.8, val_ratio=0.1, seed=42)
    train_hashes = {r.phash_hex for r in splits["train"]}
    val_hashes = {r.phash_hex for r in splits["val"]}
    test_hashes = {r.phash_hex for r in splits["test"]}

    assert train_hashes.isdisjoint(val_hashes)
    assert train_hashes.isdisjoint(test_hashes)
    assert val_hashes.isdisjoint(test_hashes)

    for split_name in ("train", "val", "test"):
        classes_present = {box.class_id for rec in splits[split_name] for box in rec.boxes}
        assert classes_present == {0, 1}


def test_f1_t1_polygon_and_edge_clipping_bbox_clamped_on_export(tmp_path: Path, make_yolo_source: Any) -> None:
    samples = [
        {
            "stem": "poly_and_clip",
            "pattern_seed": 7,
            "labels": [
                "0 0.1 0.2 0.5 0.2 0.5 0.6 0.1 0.6",
                "1 0.95 0.05 0.20 0.20",
            ],
        }
    ]
    src = make_yolo_source(tmp_path / "src", ["whitefly", "aphids"], samples)
    records, stats = deduplicate_and_merge_sources([src])
    assert len(records) == 1
    assert stats["boxes_kept"] == 2

    out_dir = tmp_path / "out"
    export_merged_dataset({"train": records, "val": [], "test": []}, out_dir, stats)
    lbl_files = list((out_dir / "train" / "labels").glob("*.txt"))
    assert len(lbl_files) == 1
    lines = lbl_files[0].read_text(encoding="utf-8").splitlines()
    assert len(lines) == 2

    for line in lines:
        cls_s, cx_s, cy_s, w_s, h_s = line.split()
        cx, cy, w, h = float(cx_s), float(cy_s), float(w_s), float(h_s)
        assert int(cls_s) in {0, 1}
        assert 0.0 <= cx - w / 2.0 <= 1.0
        assert 0.0 <= cy - h / 2.0 <= 1.0
        assert 0.0 <= cx + w / 2.0 <= 1.0
        assert 0.0 <= cy + h / 2.0 <= 1.0
        assert w > 0.0 and h > 0.0


def test_f1_t1_seed_determinism_produces_identical_export(tmp_path: Path, make_yolo_source: Any) -> None:
    samples = [{"stem": f"det_{i}", "pattern_seed": i + 5, "labels": [f"{i % 2} 0.5 0.5 0.2 0.2"]} for i in range(18)]
    src = make_yolo_source(tmp_path / "src", ["whitefly", "aphids"], samples)
    records, stats = deduplicate_and_merge_sources([src])

    out_a = tmp_path / "out_a"
    out_b = tmp_path / "out_b"
    splits_a = stratified_split_records(records, seed=42)
    splits_b = stratified_split_records(records, seed=42)
    rep_a = export_merged_dataset(splits_a, out_a, stats)
    rep_b = export_merged_dataset(splits_b, out_b, stats)

    assert rep_a["splits"] == rep_b["splits"]
    assert rep_a["scan_stats"] == rep_b["scan_stats"]
    for split_name in ("train", "val", "test"):
        files_a = sorted(p.name for p in (out_a / split_name / "labels").glob("*.txt"))
        files_b = sorted(p.name for p in (out_b / split_name / "labels").glob("*.txt"))
        assert files_a == files_b


def test_f2_t1_training_config_defaults_match_visual_pipeline_spec() -> None:
    cfg = Yolo11TrainingConfig()
    assert cfg.model == "yolo11n.pt"
    assert cfg.data == "ml/configs/lettuce_pests.yaml"
    assert cfg.epochs == 100
    assert cfg.patience == 25
    assert cfg.batch == 16
    assert cfg.imgsz == 640
    assert cfg.seed == 42
    assert cfg.optimizer == "AdamW"
    assert cfg.scale == pytest.approx(0.75)


def test_f2_t1_lettuce_pests_yaml_matches_canonical_classes(ml_root: Path) -> None:
    cfg = yaml.safe_load((ml_root / "configs" / "lettuce_pests.yaml").read_text(encoding="utf-8"))
    assert cfg["nc"] == 2
    assert cfg["names"] == {0: "whitefly", 1: "aphids"}
    assert cfg["train"] == "train/images"
    assert cfg["val"] == "val/images"
    assert cfg["test"] == "test/images"


def test_f2_t1_write_kaggle_kernel_bundle_metadata_and_sources(tmp_path: Path) -> None:
    ds_slug = "adityadwiferdiansyah/hidrosense-whitefly-aphids-v2"
    meta_path = write_kaggle_kernel_bundle(
        tmp_path / "bundle",
        kaggle_username="adityadwiferdiansyah",
        dataset_sources=[ds_slug],
    )
    assert meta_path.exists()
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    assert meta["id"].startswith("adityadwiferdiansyah/")
    assert meta["code_file"] == "kaggle_train_entry.py"
    assert meta["language"] == "python"
    assert meta["kernel_type"] == "script"
    assert meta["dataset_sources"] == [ds_slug]
    assert str(meta["enable_gpu"]).lower() == "true"
    assert str(meta["enable_tpu"]).lower() == "false"


def test_f2_t1_kaggle_bundle_contains_zero_secrets_even_when_env_set(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    secret_scanner: Any,
) -> None:
    dummy_rf = "rf_" + "sentinel_secret_value_999999999"
    dummy_kg = "KGAT_" + "sentinel_secret_value_999999999"
    monkeypatch.setenv("ROBOFLOW_API_KEY", dummy_rf)
    monkeypatch.setenv("KAGGLE_API_TOKEN", dummy_kg)

    bundle_dir = tmp_path / "kernel_bundle"
    write_kaggle_kernel_bundle(bundle_dir, "adityadwiferdiansyah", dataset_sources=["adityadwiferdiansyah/ds"])

    for file_path in bundle_dir.rglob("*"):
        if file_path.is_file():
            content = file_path.read_text(encoding="utf-8")
            assert dummy_rf not in content
            assert dummy_kg not in content
            assert secret_scanner(content) == []


def test_f2_t1_train_cli_help_exits_zero_offline(run_cli: Any) -> None:
    proc = run_cli("ml.train", ["--help"], {"ROBOFLOW_API_KEY": None})
    assert proc.returncode == 0
    for flag in ("--kaggle-push", "--kaggle-dataset", "--poll", "--timeout-minutes"):
        assert flag in proc.stdout


def test_f3_t1_assert_promotion_ready_accepts_valid_metrics() -> None:
    assert_promotion_ready(
        {
            "map50": 0.85,
            "recall": 0.80,
            "f1": 0.82,
            "tflite_map50_drop": 0.004,
            "ood_false_positive_rate": 0.0,
            "model_size_mb": 5.2,
        }
    )


def test_f3_t1_compare_baseline_vs_finetuned_four_decimal_deltas() -> None:
    baseline = {"map50": 0.21345, "map50_95": 0.11111, "precision": 0.30001, "recall": 0.25004, "f1": 0.2727}
    finetuned = {"map50": 0.81349, "map50_95": 0.52229, "precision": 0.84009, "recall": 0.79009, "f1": 0.8143}
    result = compare_baseline_vs_finetuned(baseline, finetuned)
    assert result["beats_baseline"] is True
    assert result["improvements"]["map50_delta"] == pytest.approx(round(0.81349 - 0.21345, 4))
    assert result["improvements"]["map50_95_delta"] == pytest.approx(round(0.52229 - 0.11111, 4))
    assert result["improvements"]["precision_delta"] == pytest.approx(round(0.84009 - 0.30001, 4))
    assert result["improvements"]["recall_delta"] == pytest.approx(round(0.79009 - 0.25004, 4))


def test_f3_t1_evaluate_cli_writes_passed_report_json(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    weights = tmp_path / "best.pt"
    weights.write_bytes(b"\x00" * (2 * 1024 * 1024))
    out_json = tmp_path / "reports" / "evaluation_report.json"

    def _fake_eval(path: Path, data_yaml: Path, imgsz: int = 640) -> dict[str, Any]:
        if "best" in path.name:
            return {"map50": 0.84, "map50_95": 0.58, "precision": 0.86, "recall": 0.79, "f1": 0.8235}
        return {"map50": 0.22, "map50_95": 0.12, "precision": 0.31, "recall": 0.28, "f1": 0.2942}

    monkeypatch.setattr(ml_evaluate, "evaluate_ultralytics_model", _fake_eval)
    monkeypatch.setattr(
        sys,
        "argv",
        ["ml.evaluate", "--baseline", str(tmp_path / "base.pt"), "--weights", str(weights), "--output", str(out_json)],
    )
    ml_evaluate.main()

    assert out_json.exists()
    report = json.loads(out_json.read_text(encoding="utf-8"))
    assert report["status"] == "PASSED"
    assert report["beats_baseline"] is True
    assert set(report["gates"].keys()) == set(PROMOTION_GATES.keys())
    assert report["improvements"]["map50_delta"] == pytest.approx(0.62)


def test_f3_t1_evaluate_cli_uses_tflite_size_and_drop(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    weights = tmp_path / "best.pt"
    weights.write_bytes(b"\x00" * (14 * 1024 * 1024))
    tflite = tmp_path / "model.tflite"
    tflite.write_bytes(b"\x00" * int(5.1 * 1024 * 1024))
    out_json = tmp_path / "eval_tflite.json"

    def _fake_eval(path: Path, data_yaml: Path, imgsz: int = 640) -> dict[str, Any]:
        if path.suffix == ".tflite":
            return {"map50": 0.815, "map50_95": 0.54, "precision": 0.83, "recall": 0.76, "f1": 0.7935}
        if "best" in path.name:
            return {"map50": 0.820, "map50_95": 0.55, "precision": 0.85, "recall": 0.77, "f1": 0.808}
        return {"map50": 0.15, "map50_95": 0.08, "precision": 0.20, "recall": 0.19, "f1": 0.1949}

    monkeypatch.setattr(ml_evaluate, "evaluate_ultralytics_model", _fake_eval)
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "ml.evaluate",
            "--baseline",
            str(tmp_path / "base.pt"),
            "--weights",
            str(weights),
            "--tflite",
            str(tflite),
            "--output",
            str(out_json),
        ],
    )
    ml_evaluate.main()

    report = json.loads(out_json.read_text(encoding="utf-8"))
    assert report["status"] == "PASSED"
    assert report["gates"]["model_size_mb"] == pytest.approx(5.1, abs=0.01)
    assert report["gates"]["tflite_map50_drop"] == pytest.approx(0.005, abs=1e-4)


def test_f3_t1_promotion_gates_contract_keys_and_directions() -> None:
    assert PROMOTION_GATES == {
        "map50": ("min", 0.72),
        "recall": ("min", 0.68),
        "f1": ("min", 0.72),
        "tflite_map50_drop": ("max", 0.008),
        "ood_false_positive_rate": ("max", 0.05),
        "model_size_mb": ("max", 12.0),
    }


def test_f3_t1_evaluate_ultralytics_model_runs_real_tflite_test_split(
    tmp_path: Path,
    ml_root: Path,
    monkeypatch: pytest.MonkeyPatch,
    spatial_hw_fn: Any,
) -> None:
    tflite_path = ml_root / "artifacts" / "yolo11n_lettuce_pests.tflite"
    interp = Interpreter(model_path=str(tflite_path))
    interp.allocate_tensors()
    in_h, in_w = spatial_hw_fn(interp.get_input_details()[0]["shape"])
    model_imgsz = max(in_h, in_w)

    test_img_dir = tmp_path / "ds" / "test" / "images"
    test_lbl_dir = tmp_path / "ds" / "test" / "labels"
    test_img_dir.mkdir(parents=True)
    test_lbl_dir.mkdir(parents=True)

    for idx in range(2):
        Image.new("RGB", (model_imgsz, model_imgsz), color=(40, 120 + idx * 20, 40)).save(test_img_dir / f"t_{idx}.jpg")
        (test_lbl_dir / f"t_{idx}.txt").write_text(f"{idx} 0.5 0.5 0.25 0.25\n", encoding="utf-8")

    data_yaml = tmp_path / "ds" / "data.yaml"
    data_yaml.write_text(
        yaml.safe_dump(
            {
                "path": str((tmp_path / "ds").resolve()),
                "train": "test/images",
                "val": "test/images",
                "test": "test/images",
                "nc": 2,
                "names": {0: "whitefly", 1: "aphids"},
            },
            sort_keys=False,
        ),
        encoding="utf-8",
    )

    monkeypatch.chdir(tmp_path)
    metrics = evaluate_ultralytics_model(tflite_path, data_yaml, imgsz=model_imgsz)
    for key in ("map50", "map50_95", "precision", "recall", "f1"):
        assert key in metrics
        assert np.isfinite(metrics[key])
        assert 0.0 <= metrics[key] <= 1.0


def test_f4_t1_decode_yolov11_channel_first_last_norm_and_pixel() -> None:
    ch_first_px = [
        [320.0, 100.0],
        [320.0, 100.0],
        [64.0, 20.0],
        [64.0, 20.0],
        [0.88, 0.10],
        [0.03, 0.01],
    ]
    dets_cf = decode_yolov11_output(ch_first_px, img_size=640, conf_threshold=0.45, iou_threshold=0.45)
    assert len(dets_cf) == 1
    assert dets_cf[0]["class_id"] == 0
    assert dets_cf[0]["class_name"] == "whitefly"
    assert dets_cf[0]["confidence"] == pytest.approx(0.88)
    assert dets_cf[0]["box"] == pytest.approx((0.45, 0.45, 0.55, 0.55))

    ch_last_norm = [
        [0.5, 0.5, 0.1, 0.1, 0.88, 0.03],
        [0.2, 0.2, 0.05, 0.05, 0.10, 0.01],
    ]
    dets_cl = decode_yolov11_output(ch_last_norm, img_size=640, conf_threshold=0.45, iou_threshold=0.45)
    assert len(dets_cl) == 1
    assert dets_cl[0]["class_id"] == 0
    assert dets_cl[0]["box"] == pytest.approx((0.45, 0.45, 0.55, 0.55))


def test_f4_t1_decode_yolov11_per_class_nms_preserves_distinct_pests() -> None:
    anchors = [
        [0.5, 0.5, 0.2, 0.2, 0.85, 0.02],
        [0.51, 0.51, 0.2, 0.2, 0.60, 0.01],
        [0.5, 0.5, 0.2, 0.2, 0.03, 0.72],
    ]
    dets = decode_yolov11_output(anchors, img_size=640, conf_threshold=0.45, iou_threshold=0.45)
    assert [d["class_name"] for d in dets] == ["whitefly", "aphids"]


def test_f4_t1_build_model_metadata_matches_flutter_contract() -> None:
    digest = "a" * 64
    meta = build_model_metadata(model_version="yolo11n-fp16-aaaaaaaa", img_size=640, sha256_hex=digest)
    assert meta["architecture"] == "yolo11n"
    assert meta["input_dtype"] == "float32"
    assert meta["input_normalization"] == "0_to_1"
    assert meta["letterbox_pad_value"] == 114
    assert meta["confidence_threshold"] == 0.45
    assert meta["iou_threshold"] == 0.45
    assert meta["output_shape"] == [1, 6, 8400]
    assert meta["classes"] == {"0": "whitefly", "1": "aphids"}
    assert meta["sha256"] == digest


def test_f4_t1_export_assets_writes_tflite_labels_and_sha256_metadata(
    tmp_path: Path,
    ml_root: Path,
) -> None:
    real_tflite = ml_root / "artifacts" / "yolo11n_lettuce_pests.tflite"
    weights_pt = tmp_path / "best.pt"
    weights_pt.write_bytes(b"weights")
    assets_dir = tmp_path / "flutter_assets"

    class _FakeYOLO:
        def __init__(self, weights: str) -> None:
            self.weights = weights

        def export(self, **kwargs: Any) -> str:
            exported = tmp_path / "exported_best.tflite"
            exported.write_bytes(real_tflite.read_bytes())
            return str(exported)

    with patch("ultralytics.YOLO", _FakeYOLO):
        target_tflite = export_model_to_flutter_assets(weights_pt, assets_dir, img_size=640)

    assert target_tflite.exists()
    actual_sha = hashlib.sha256(target_tflite.read_bytes()).hexdigest()
    labels = (assets_dir / "labels.txt").read_text(encoding="utf-8").splitlines()
    assert labels == ["whitefly", "aphids"]

    metadata = json.loads((assets_dir / "model_metadata.json").read_text(encoding="utf-8"))
    assert metadata["sha256"] == actual_sha
    assert metadata["classes"] == {"0": "whitefly", "1": "aphids"}


def test_f4_t1_litert_interpreter_smoke_inference_and_decode(
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

    img = Image.new("RGB", (in_w, in_h), color=(45, 130, 50))
    hwc, _ = letterbox_fn(img, (in_h, in_w), pad_value=114)
    tensor_in = adapt_input_fn(hwc, in_detail["shape"])

    interp.set_tensor(in_detail["index"], tensor_in)
    interp.invoke()
    raw_out = interp.get_tensor(out_detail["index"])

    assert raw_out.shape[0] == 1
    assert raw_out.shape[1] == 6
    assert np.all(np.isfinite(raw_out))

    dets = decode_yolov11_output(raw_out[0].tolist(), img_size=max(in_h, in_w), conf_threshold=0.45, iou_threshold=0.45)
    assert isinstance(dets, list)


def test_f4_t1_labels_txt_exact_canonical_order(ml_root: Path) -> None:
    labels = [line.strip() for line in (ml_root / "artifacts" / "labels.txt").read_text(encoding="utf-8").splitlines() if line.strip()]
    assert labels == ["whitefly", "aphids"]

    metadata = json.loads((ml_root / "artifacts" / "model_metadata.json").read_text(encoding="utf-8"))
    assert metadata["classes"] == {str(k): v for k, v in CANONICAL_CLASSES.items()}


KNOWN_LEGACY_TEST_FIXTURE_MATCHES: frozenset[str] = frozenset(
    {
        "ROBOFLOW_API_KEY=" + "'quoted_secret_123'",
        "rf_" + "super_secret_test_key_999",
        'secret_key = "rf_' + 'super_secret_test_key_999"',
        "rf_" + "required_secret_abc",
        'secret_key = "rf_' + 'required_secret_abc"',
    }
)

_DIFF_GIT_RE = re.compile(r'^diff --git (?:"a/(.+?)"|a/(\S+)) (?:"b/(.+?)"|b/(\S+))$')
_COMMIT_HEADER_RE = re.compile(r"^commit [0-9a-f]{7,64}$")


def is_ml_test_path(rel_path: str) -> bool:
    cleaned = rel_path.strip().replace("\\", "/")
    if not cleaned:
        return False
    if cleaned.startswith("./"):
        cleaned = cleaned[2:]
    normalized = posixpath.normpath(cleaned)
    return normalized.startswith("ml/tests/") and normalized.endswith(".py")


def _filter_placeholder_findings_in_test_text(text: str, raw_findings: list[str]) -> list[str]:
    disallowed: list[str] = []
    matched_any_pattern = False
    for label, pattern in SECRET_PATTERNS:
        for match in pattern.finditer(text):
            matched_any_pattern = True
            matched_text = match.group(0)
            if matched_text not in KNOWN_LEGACY_TEST_FIXTURE_MATCHES:
                disallowed.append(f"{label}: {matched_text[:16]}...")
    if not matched_any_pattern:
        return list(raw_findings)
    return disallowed


def scan_ml_text_for_secrets(
    rel_path: str,
    text: str,
    secret_scanner: Callable[[str], list[str]],
) -> list[str]:
    raw_findings = secret_scanner(text)
    if not raw_findings or not is_ml_test_path(rel_path):
        return raw_findings
    return _filter_placeholder_findings_in_test_text(text, raw_findings)


def scan_ml_bytes_for_secrets(
    rel_path: str,
    raw: bytes,
    bytes_secret_scanner: Callable[[bytes], list[str]],
) -> list[str]:
    raw_findings = bytes_secret_scanner(raw)
    if not raw_findings or not is_ml_test_path(rel_path):
        return raw_findings
    return _filter_placeholder_findings_in_test_text(raw.decode("utf-8", errors="ignore"), raw_findings)


def scan_ml_git_diff_for_secrets(
    diff_raw: bytes | str,
    bytes_secret_scanner: Callable[[bytes], list[str]],
    secret_scanner: Callable[[str], list[str]],
) -> list[str]:
    diff_text = diff_raw.decode("utf-8", errors="ignore") if isinstance(diff_raw, bytes) else diff_raw
    findings: list[str] = []
    current_path = "<git-diff-header>"
    in_ml_tests = False
    in_hunk = False
    non_test_lines: list[str] = []
    test_hunk_lines: list[str] = []

    def _flush() -> None:
        if non_test_lines:
            joined = "\n".join(non_test_lines)
            for finding in bytes_secret_scanner(joined.encode("utf-8", errors="ignore")):
                findings.append(f"{current_path}: {finding}")
            non_test_lines.clear()
        if test_hunk_lines:
            joined = "\n".join(test_hunk_lines)
            for finding in scan_ml_text_for_secrets(current_path, joined, secret_scanner):
                findings.append(f"{current_path}: {finding}")
            test_hunk_lines.clear()

    for line in diff_text.splitlines():
        if _COMMIT_HEADER_RE.match(line):
            _flush()
            current_path = "<commit-header>"
            in_ml_tests = False
            in_hunk = False
            non_test_lines.append(line)
            continue

        diff_match = _DIFF_GIT_RE.match(line)
        if diff_match:
            _flush()
            old_path = diff_match.group(1) or diff_match.group(2)
            new_path = diff_match.group(3) or diff_match.group(4)
            in_ml_tests = is_ml_test_path(new_path) and (old_path == new_path or is_ml_test_path(old_path))
            current_path = new_path
            in_hunk = False
            non_test_lines.append(line)
            continue

        if line.startswith("diff --"):
            _flush()
            current_path = "<diff-header>"
            in_ml_tests = False
            in_hunk = False
            non_test_lines.append(line)
            continue

        if not in_ml_tests:
            non_test_lines.append(line)
            continue

        if line.startswith("@@ "):
            in_hunk = True
            non_test_lines.append(line)
            continue

        if not in_hunk:
            non_test_lines.append(line)
            continue

        if line.startswith(("+", "-", " ")):
            test_hunk_lines.append(line[1:])
        else:
            test_hunk_lines.append(line)

    _flush()
    return findings


def test_f5_t1_committed_branch_diff_strictly_inside_approved_scope(repo_root: Path, ml_only_path_validator: Any) -> None:
    proc = subprocess.run(
        ["git", "diff", "--name-only", "main"],
        cwd=repo_root,
        capture_output=True,
        text=True,
        check=True,
    )
    paths = [line.strip() for line in proc.stdout.splitlines() if line.strip()]
    violations = ml_only_path_validator(paths)
    assert violations == [], f"Branch diff contains paths outside ml/ and apps/mobile/: {violations}"


@pytest.mark.parametrize(
    "ignored_candidate",
    [
        "ml/.env",
        "ml/.kaggle/access_token",
        "ml/data/x",
        "ml/runs/y",
        "ml/kaggle_work/z",
        "ml/temp.pt",
        "ml/temp.onnx",
    ],
)
def test_f5_t1_ml_gitignore_blocks_secrets_and_artifacts(repo_root: Path, ignored_candidate: str) -> None:
    proc = subprocess.run(
        ["git", "check-ignore", "--no-index", ignored_candidate],
        cwd=repo_root,
        capture_output=True,
        text=True,
        check=False,
    )
    assert proc.returncode == 0, f"Expected {ignored_candidate} to be gitignored, stderr={proc.stderr!r}"


def test_f5_t1_tracked_ml_files_have_zero_secrets(
    repo_root: Path,
    binary_suffixes: frozenset[str],
    bytes_secret_scanner: Any,
) -> None:
    proc = subprocess.run(
        ["git", "ls-files", "ml/"],
        cwd=repo_root,
        capture_output=True,
        text=True,
        check=True,
    )
    tracked = [line.strip() for line in proc.stdout.splitlines() if line.strip()]
    assert len(tracked) >= 10
    for rel_path in tracked:
        full_path = repo_root / rel_path
        if not full_path.is_file() or full_path.suffix.lower() in binary_suffixes:
            continue
        findings = scan_ml_bytes_for_secrets(rel_path, full_path.read_bytes(), bytes_secret_scanner)
        assert findings == [], f"Secret-like pattern found in {rel_path}: {findings}"


def test_f5_t1_commit_history_main_to_head_clean_of_secrets_and_backend_paths(
    repo_root: Path,
    ml_only_path_validator: Any,
    secret_scanner: Any,
    bytes_secret_scanner: Any,
) -> None:
    names_proc = subprocess.run(
        ["git", "log", "main..HEAD", "--name-only", "--pretty=format:"],
        cwd=repo_root,
        capture_output=True,
        text=True,
        check=True,
    )
    committed_paths = [line.strip() for line in names_proc.stdout.splitlines() if line.strip()]
    assert ml_only_path_validator(committed_paths) == []

    msg_proc = subprocess.run(
        ["git", "log", "main..HEAD", "--format=%B"],
        cwd=repo_root,
        capture_output=True,
        text=True,
        check=True,
    )
    assert secret_scanner(msg_proc.stdout) == []

    diff_proc = subprocess.run(
        ["git", "log", "main..HEAD", "-p", "--", "ml/", ":(exclude)*.tflite"],
        cwd=repo_root,
        capture_output=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    assert scan_ml_git_diff_for_secrets(diff_proc.stdout, bytes_secret_scanner, secret_scanner) == []
