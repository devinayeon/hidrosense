from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

import numpy as np
import pytest
from ai_edge_litert.interpreter import Interpreter
from PIL import Image

from ml.evaluate import PROMOTION_GATES, assert_promotion_ready
from ml.export_tflite import decode_yolov11_output
from ml.prepare_dataset import (
    ROBOFLOW_SOURCES,
    canonicalize_label_name,
    deduplicate_and_merge_sources,
    download_roboflow_sources,
)
from ml.train import write_kaggle_kernel_bundle


# =============================================================================
# Immediate Real-World & Regression Scenarios (4 tests)
# =============================================================================


def test_tier4_scenario_multi_pest_greenhouse_leaf_workflow() -> None:
    """Simulate Flutter V2RawatHasilPage.beberapa multi-pest detection + NMS suppression."""
    # [7, 4] channel-first predictions on 720x1280 leaf preprocessed to 640x640
    predictions = [
        [0.25, 0.26, 0.65, 0.80],  # cx
        [0.30, 0.31, 0.55, 0.20],  # cy
        [0.14, 0.14, 0.12, 0.10],  # w
        [0.14, 0.14, 0.12, 0.10],  # h
        [0.87, 0.61, 0.04, 0.03],  # thrips (0.87 high, 0.61 duplicate overlapping)
        [0.02, 0.03, 0.05, 0.42],  # whitefly (0.42 low confidence >= 0.35)
        [0.04, 0.02, 0.64, 0.05],  # aphids (0.64 medium confidence)
    ]
    detections = decode_yolov11_output(predictions, img_size=640, conf_threshold=0.35, iou_threshold=0.45)

    assert len(detections) == 3
    assert [d["class_name"] for d in detections] == ["thrips", "aphids", "whitefly"]
    assert detections[0]["confidence"] == pytest.approx(0.87)  # >= 0.80 high
    assert detections[1]["confidence"] == pytest.approx(0.64)  # >= 0.50 medium
    assert detections[2]["confidence"] == pytest.approx(0.42)  # [0.35, 0.50) low


def test_tier4_scenario_healthy_lettuce_zero_detections() -> None:
    """Simulate Flutter V2RawatHasilPage.sehat healthy leaf with all scores below 0.35."""
    predictions = np.zeros((7, 100), dtype=np.float32)
    predictions[0, :] = 0.5
    predictions[1, :] = 0.5
    predictions[2, :] = 0.15
    predictions[3, :] = 0.15
    predictions[4, 0] = 0.349
    predictions[5, 1] = 0.28
    predictions[6, 2] = 0.19

    detections = decode_yolov11_output(predictions.tolist(), img_size=640, conf_threshold=0.35, iou_threshold=0.45)
    assert detections == []


def test_tier4_scenario_offline_mobile_bundle_inference_no_ultralytics(
    repo_root: Path,
    ml_root: Path,
) -> None:
    """Run offline mobile inference using only ai_edge_litert, PIL, numpy, json, and labels/metadata."""
    tflite_path = ml_root / "artifacts" / "yolo11n_lettuce_pests.tflite"
    labels_path = ml_root / "artifacts" / "labels.txt"
    metadata_path = ml_root / "artifacts" / "model_metadata.json"

    script = (
        "import json, sys\n"
        "from pathlib import Path\n"
        "import numpy as np\n"
        "from PIL import Image\n"
        "from ai_edge_litert.interpreter import Interpreter\n"
        "from ml.export_tflite import decode_yolov11_output\n"
        f"tflite = Path({str(tflite_path)!r})\n"
        f"labels = Path({str(labels_path)!r}).read_text(encoding='utf-8').splitlines()\n"
        f"meta = json.loads(Path({str(metadata_path)!r}).read_text(encoding='utf-8'))\n"
        "assert labels == ['thrips', 'whitefly', 'aphids']\n"
        "interp = Interpreter(model_path=str(tflite))\n"
        "interp.allocate_tensors()\n"
        "in_det = interp.get_input_details()[0]\n"
        "out_det = interp.get_output_details()[0]\n"
        "shape = [int(x) for x in in_det['shape']]\n"
        "is_nchw = (shape[1] == 3 and shape[3] != 3)\n"
        "h, w = (shape[2], shape[3]) if is_nchw else (shape[1], shape[2])\n"
        "img = Image.new('RGB', (w, h), color=(int(meta['letterbox_pad_value']),) * 3)\n"
        "arr = np.asarray(img, dtype=np.float32) / 255.0\n"
        "if is_nchw: arr = np.transpose(arr, (2, 0, 1))\n"
        "interp.set_tensor(in_det['index'], np.expand_dims(arr, 0))\n"
        "interp.invoke()\n"
        "out = interp.get_tensor(out_det['index'])\n"
        "assert np.all(np.isfinite(out))\n"
        "dets = decode_yolov11_output(out[0].tolist(), img_size=max(h, w), conf_threshold=float(meta['confidence_threshold']), iou_threshold=float(meta['iou_threshold']))\n"
        "assert isinstance(dets, list)\n"
        "assert 'ultralytics' not in sys.modules\n"
        "assert 'torch' not in sys.modules\n"
    )
    proc = subprocess.run(
        [sys.executable, "-c", script],
        cwd=repo_root,
        capture_output=True,
        text=True,
        check=False,
    )
    assert proc.returncode == 0, f"Offline mobile script failed:\nSTDOUT:{proc.stdout}\nSTDERR:{proc.stderr}"


def test_tier4_scenario_audited_kaggle_v4_regression_guard(ml_root: Path) -> None:
    """Reject every audited Kaggle v4 defect signature (size > 6 MB, CPU/non-GPU, synthetic data, shape mismatch)."""
    # 1. Size gate rejects 10.121 MB v4 export
    v4_metrics = {
        "map50": 0.982,
        "recall": 0.9944,
        "tflite_map50_drop": 0.0,
        "model_size_mb": 10.121,
    }
    with pytest.raises(ValueError, match="model_size_mb"):
        assert_promotion_ready(v4_metrics)

    # 2. v4 GPU & synthetic provenance signature + CPU-disguised payloads must fail production readiness
    v4_provenance = {
        "enable_gpu": False,
        "device": "CPU (Intel Xeon CPU @ 2.20GHz)",
        "dataset_origin": "synthetic_fallback",
        "split_leakage": 0,
        "total_images": 108,
    }
    assert v4_provenance["enable_gpu"] is False
    assert v4_provenance["dataset_origin"] != "roboflow"
    assert v4_provenance["total_images"] <= 108
    with pytest.raises(AssertionError):
        _assert_valid_production_provenance(v4_provenance)

    for cpu_disguised in (
        {"device": "gpu_none", "split_leakage": 0, "total_images": 2000},
        {"device": "no_gpu", "split_leakage": 0, "total_images": 2000},
        {"device": "CPU (no NVIDIA GPU)", "split_leakage": 0, "total_images": 2000},
        {"device": "CPU (Tesla T4)", "split_leakage": 0, "total_images": 2000},
        {"device": "CPU fallback (Tesla T4)", "split_leakage": 0, "total_images": 2000},
        {"device": "cpu_instead_of_t4", "split_leakage": 0, "total_images": 2000},
        {"device": "0_gpu", "split_leakage": 0, "total_images": 2000},
        {"device": "0-gpu", "split_leakage": 0, "total_images": 2000},
        {"device": "gpu=0", "split_leakage": 0, "total_images": 2000},
        {"device": "simulated_t4", "split_leakage": 0, "total_images": 2000},
        {"device": "unavailable", "split_leakage": 0, "total_images": 2000},
        {"enable_gpu": True, "gpu_count": 0, "split_leakage": 0, "total_images": 2000},
        {"enable_gpu": True, "split_leakage": 0, "total_images": 2000},
    ):
        with pytest.raises(AssertionError):
            _assert_valid_production_provenance(cpu_disguised)

    for valid_gpu in (
        "Tesla T4",
        "NVIDIA Tesla P100-PCIE-16GB",
        "cuda:0",
        "Tesla P100",
        "Tesla T4 x2",
        "NVIDIA L4",
        "NVIDIA A100-SXM4-40GB",
        "cuda:0 (Tesla T4)",
        "kaggle_gpu_t4",
    ):
        _assert_valid_production_provenance(
            {"enable_gpu": True, "device": valid_gpu, "split_leakage": 0, "total_images": 2000}
        )

    # 3. Shape mismatch signature: [1, 3, 320, 320] vs [1, 640, 640, 3]
    v4_claimed_metadata_shape = [1, 640, 640, 3]
    v4_actual_flatbuffer_shape = [1, 3, 320, 320]
    assert v4_claimed_metadata_shape != v4_actual_flatbuffer_shape

    # Confirm live Interpreter strictly rejects mismatched shapes relative to the loaded flatbuffer
    interp = Interpreter(model_path=str(ml_root / "artifacts" / "yolo11n_lettuce_pests.tflite"))
    interp.allocate_tensors()
    in_detail = interp.get_input_details()[0]
    actual_shape = [int(x) for x in in_detail["shape"]]
    mismatched_shape = (1, 3, 320, 320) if actual_shape != [1, 3, 320, 320] else (1, 640, 640, 3)
    with pytest.raises(ValueError):
        interp.set_tensor(in_detail["index"], np.zeros(mismatched_shape, dtype=np.float32))


# =============================================================================
# M5 Production Acceptance Gates (@pytest.mark.production_artifact) (4 tests)
# =============================================================================


@pytest.mark.production_artifact
def test_tier4_prod_m2_dataset_prep_fail_fast_and_cli_contract(
    tmp_path: Path,
    make_yolo_source: Any,
    monkeypatch: pytest.MonkeyPatch,
    run_cli: Any,
) -> None:
    import inspect

    # 1. Missing ROBOFLOW_API_KEY must fail fast (zero synthetic fallback), without reading ml/.env
    monkeypatch.delenv("ROBOFLOW_API_KEY", raising=False)
    empty_raw = tmp_path / "raw_empty"
    empty_raw.mkdir()
    missing_env = tmp_path / "missing.env"
    kwargs: dict[str, Any] = {"api_key": None}
    if "env_file" in inspect.signature(download_roboflow_sources).parameters:
        kwargs["env_file"] = missing_env
    with pytest.raises(Exception):
        download_roboflow_sources(empty_raw, **kwargs)

    # 2. Confirmed Roboflow sources & versions (6 and 1)
    by_project = {spec["project"]: str(spec["version"]) for spec in ROBOFLOW_SOURCES}
    assert by_project.get("lettuce-pests") == "6"
    assert by_project.get("lettuce-pest-detection") == "1"

    # 3. Ancestor "images/" segment must not break label lookup
    src = make_yolo_source(
        tmp_path,
        ["thrips", "whitefly", "aphids"],
        [{"stem": "leaf_bug", "pattern_seed": 9, "labels": ["0 0.5 0.5 0.2 0.2"]}],
        prefix_dirs=("images", "ds1"),
    )
    records, _ = deduplicate_and_merge_sources([src])
    assert len(records) == 1

    # 4. Negation guard: non_aphid must not map to aphids
    assert canonicalize_label_name("non_aphid") is None

    # 5. CLI entrypoint --help exits 0
    proc = run_cli("ml.prepare_dataset", ["--help"], {"ROBOFLOW_API_KEY": None})
    assert proc.returncode == 0, f"prepare_dataset --help failed: {proc.stderr}"


@pytest.mark.production_artifact
def test_tier4_prod_m3_kaggle_gpu_kernel_bundle_contract(
    tmp_path: Path,
    ml_root: Path,
    secret_scanner: Any,
) -> None:
    meta_path = write_kaggle_kernel_bundle(
        tmp_path / "prod_kernel",
        kaggle_username="adityadwiferdiansyah",
        dataset_sources=["adityadwiferdiansyah/hidrosense-lettuce-pests-real"],
    )
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    assert meta["enable_gpu"] is True
    assert meta["enable_tpu"] is False
    assert meta["is_private"] is True
    assert meta["id"] == "adityadwiferdiansyah/hidrosense-yolov11n-lettuce-pests-training"
    assert meta["code_file"] == "kaggle_train_entry.py"

    entry_file = ml_root / "kaggle_train_entry.py"
    assert entry_file.exists(), "ml/kaggle_train_entry.py missing"
    assert secret_scanner(entry_file.read_text(encoding="utf-8")) == []


@pytest.mark.production_artifact
def test_tier4_prod_m4_artifacts_640_layout_size_sha256_and_inference(
    ml_root: Path,
    letterbox_fn: Any,
    adapt_input_fn: Any,
    spatial_hw_fn: Any,
) -> None:
    artifacts_dir = ml_root / "artifacts"
    tflite_path = artifacts_dir / "yolo11n_lettuce_pests.tflite"
    labels_path = artifacts_dir / "labels.txt"
    metadata_path = artifacts_dir / "model_metadata.json"
    eval_path = ml_root / "reports" / "evaluation_report.json"

    assert tflite_path.exists()
    size_mb = tflite_path.stat().st_size / (1024.0 * 1024.0)
    assert size_mb <= PROMOTION_GATES["model_size_mb"][1], f"TFLite size {size_mb:.3f} MB > 6.0 MB"

    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    actual_sha = hashlib.sha256(tflite_path.read_bytes()).hexdigest()
    assert metadata["sha256"] == actual_sha

    labels = [line.strip() for line in labels_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    assert labels == ["thrips", "whitefly", "aphids"]

    interp = Interpreter(model_path=str(tflite_path))
    interp.allocate_tensors()
    in_detail = interp.get_input_details()[0]
    out_detail = interp.get_output_details()[0]

    actual_in_shape = [int(x) for x in in_detail["shape"]]
    actual_out_shape = [int(x) for x in out_detail["shape"]]
    assert actual_in_shape == [1, 640, 640, 3], f"Expected NHWC [1, 640, 640, 3] input, got {actual_in_shape}"
    assert metadata["input_shape"] == actual_in_shape
    assert actual_out_shape == metadata["output_shape"] == [1, 7, 8400]
    assert in_detail["dtype"] == np.float32
    assert metadata["input_dtype"] == "float32"

    eval_report = json.loads(eval_path.read_text(encoding="utf-8"))
    assert "metrics" in metadata and metadata["metrics"] == eval_report["finetuned"]

    # Live 640x640 letterboxed inference pass
    in_h, in_w = spatial_hw_fn(actual_in_shape)
    assert (in_h, in_w) == (640, 640)
    sample_img = Image.new("RGB", (640, 640), color=(45, 130, 50))
    hwc, _ = letterbox_fn(sample_img, (640, 640), pad_value=int(metadata["letterbox_pad_value"]))
    tensor_in = adapt_input_fn(hwc, actual_in_shape)
    interp.set_tensor(in_detail["index"], tensor_in)
    interp.invoke()
    raw_out = interp.get_tensor(out_detail["index"])
    assert list(raw_out.shape) == [1, 7, 8400]
    assert np.all(np.isfinite(raw_out))


_DEVICE_PROVENANCE_KEYS: frozenset[str] = frozenset(
    {"device", "accelerator", "hardware", "gpu_device"}
)
_GPU_DEVICE_TOKEN_RE = re.compile(
    r"(?:^|[^a-z0-9])(?:gpu[0-9]*|cuda[0-9]*|tesla|t4|p100|l4|a100|v100|h100|rtx|gtx|quadro|geforce|nvidia)(?:$|[^a-z0-9])"
)
_NEGATIVE_DEVICE_RE = re.compile(
    r"(?:^|[^a-z0-9])(?:none|null|nil|false|disabled|unavailable|no|not|without|non|never|zero|n/a|off|nogpu|nocuda|cpu|cpu_only|cpuonly|simulated|mock|emulated|fake|dummy)(?:$|[^a-z0-9])"
    r"|(?:^|[^a-z0-9])(?:0+[\s_-]*gpus?|gpus?\s*[:=]\s*0+|cpu[\s_-]+only)(?:$|[^a-z0-9])"
)


def _iter_string_values(obj: Any) -> list[str]:
    if isinstance(obj, str):
        return [obj]
    if isinstance(obj, dict):
        values: list[str] = []
        for val in obj.values():
            values.extend(_iter_string_values(val))
        return values
    if isinstance(obj, (list, tuple, set)):
        values = []
        for item in obj:
            values.extend(_iter_string_values(item))
        return values
    return []


def _iter_key_values(obj: Any, target_keys: frozenset[str]) -> list[tuple[str, Any]]:
    matches: list[tuple[str, Any]] = []
    if isinstance(obj, dict):
        for key, val in obj.items():
            key_lower = str(key).lower()
            if key_lower in target_keys:
                matches.append((key_lower, val))
            matches.extend(_iter_key_values(val, target_keys))
    elif isinstance(obj, (list, tuple)):
        for item in obj:
            matches.extend(_iter_key_values(item, target_keys))
    return matches


def _is_explicit_gpu_device(value: Any) -> bool:
    if not isinstance(value, str):
        return False
    text = value.strip().lower()
    if not text:
        return False
    if "cpu" in text:
        return False
    if _NEGATIVE_DEVICE_RE.search(text):
        return False
    if not _GPU_DEVICE_TOKEN_RE.search(text):
        return False
    return True


def _assert_valid_production_provenance(provenance: dict[str, Any]) -> None:
    assert isinstance(provenance, dict) and provenance, "Missing provenance block in evaluation_report.json"

    # 1. Reject synthetic string values anywhere in provenance (keys excluded) and check numeric counts if present
    str_values = _iter_string_values(provenance)
    synthetic_hits = [val for val in str_values if "synthetic" in val.lower()]
    assert not synthetic_hits, f"Synthetic provenance value detected: {synthetic_hits}"
    for syn_key, syn_val in _iter_key_values(
        provenance, frozenset({"synthetic_images", "synthetic_images_count"})
    ):
        assert isinstance(syn_val, int) and not isinstance(syn_val, bool) and syn_val == 0, (
            f"Expected {syn_key} == 0, got {syn_val!r}"
        )
    for _, zero_syn_confirmed in _iter_key_values(provenance, frozenset({"zero_synthetic_confirmed"})):
        assert zero_syn_confirmed is True, (
            f"Expected zero_synthetic_confirmed is True, got {zero_syn_confirmed!r}"
        )

    # 2. Enforce explicit GPU execution values (never substring-matching serialized JSON keys)
    enable_gpu_entries = _iter_key_values(provenance, frozenset({"enable_gpu"}))
    for _, gpu_flag in enable_gpu_entries:
        assert gpu_flag is True, f"Expected enable_gpu is True, got {gpu_flag!r}"

    for cnt_key, cnt_val in _iter_key_values(provenance, frozenset({"gpu_count", "num_gpus"})):
        assert isinstance(cnt_val, int) and not isinstance(cnt_val, bool) and cnt_val > 0, (
            f"Expected {cnt_key} > 0, got {cnt_val!r}"
        )

    device_entries = _iter_key_values(provenance, _DEVICE_PROVENANCE_KEYS)
    assert device_entries, (
        "Provenance must include a non-empty GPU device/accelerator field "
        "(device, gpu_device, accelerator, or hardware)"
    )
    for dev_key, dev_val in device_entries:
        assert _is_explicit_gpu_device(dev_val), (
            f"Expected GPU device in provenance[{dev_key!r}], got CPU/invalid value {dev_val!r}"
        )

    # 3. Require explicit split_leakage == 0 (reject omitted or boolean values)
    assert "split_leakage" in provenance, "Missing provenance['split_leakage']"
    split_leakage = provenance["split_leakage"]
    assert isinstance(split_leakage, int) and not isinstance(split_leakage, bool) and split_leakage == 0, (
        f"Expected provenance['split_leakage'] == 0, got {split_leakage!r}"
    )

    # 4. Real Roboflow dataset must exceed the audited 108-image synthetic v4 baseline
    total_images = int(provenance.get("total_images", 0))
    assert total_images > 108, f"Expected real Roboflow dataset > 108 synthetic baseline, got {total_images}"


@pytest.mark.production_artifact
def test_tier4_prod_m4_evaluation_report_real_provenance_per_class_and_gates(ml_root: Path) -> None:
    report_path = ml_root / "reports" / "evaluation_report.json"
    report = json.loads(report_path.read_text(encoding="utf-8"))

    assert report.get("status") == "PASSED"
    assert report.get("beats_baseline") is True
    assert report["finetuned"]["map50"] > report["baseline"]["map50"]
    assert report["finetuned"]["recall"] >= report["baseline"]["recall"]
    assert "gates" in report
    assert_promotion_ready(report["gates"])

    per_class = report.get("per_class", {})
    for cls_name in ("thrips", "whitefly", "aphids"):
        assert cls_name in per_class, f"Missing per_class entry for {cls_name}"
        assert per_class[cls_name]["map50"] > 0.0
        assert per_class[cls_name]["recall"] > 0.0

    tflite_eval = report.get("tflite_eval", {})
    assert "tflite_map50_drop" in tflite_eval, "Missing tflite_eval['tflite_map50_drop']"
    assert tflite_eval["tflite_map50_drop"] <= PROMOTION_GATES["tflite_map50_drop"][1]
    assert report["gates"]["map50"] == pytest.approx(report["finetuned"]["map50"], abs=1e-4)
    assert report["gates"]["recall"] == pytest.approx(report["finetuned"]["recall"], abs=1e-4)
    assert report["gates"]["tflite_map50_drop"] == pytest.approx(tflite_eval["tflite_map50_drop"], abs=1e-4)

    _assert_valid_production_provenance(report.get("provenance", {}))
