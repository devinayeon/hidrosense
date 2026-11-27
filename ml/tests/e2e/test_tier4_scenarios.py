from __future__ import annotations

import hashlib
import json
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
    ROBOFLOW_DIRECT_SOURCES,
    canonicalize_label_name,
    deduplicate_and_merge_sources,
    download_roboflow_direct_sources,
)
from ml.train import write_kaggle_kernel_bundle


def test_tier4_scenario_multi_pest_greenhouse_leaf_workflow() -> None:
    """Simulate Flutter multi-pest 2-class detection (whitefly + aphids) + NMS suppression."""
    predictions = [
        [0.25, 0.26, 0.65, 0.80],  # cx
        [0.30, 0.31, 0.55, 0.20],  # cy
        [0.14, 0.14, 0.12, 0.10],  # w
        [0.14, 0.14, 0.12, 0.10],  # h
        [0.87, 0.61, 0.04, 0.48],  # whitefly (0.87 high, 0.61 duplicate overlapping, 0.48 distinct)
        [0.04, 0.02, 0.74, 0.05],  # aphids (0.74 distinct)
    ]
    detections = decode_yolov11_output(predictions, img_size=640, conf_threshold=0.45, iou_threshold=0.45)

    assert len(detections) == 3
    assert [d["class_name"] for d in detections] == ["whitefly", "aphids", "whitefly"]
    assert detections[0]["confidence"] == pytest.approx(0.87)
    assert detections[1]["confidence"] == pytest.approx(0.74)
    assert detections[2]["confidence"] == pytest.approx(0.48)


def test_tier4_scenario_healthy_lettuce_and_real_world_ood_zero_detections() -> None:
    """Simulate healthy leaf or non-pest OOD photo with all scores below threshold."""
    predictions = np.zeros((6, 100), dtype=np.float32)
    predictions[0, :] = 0.5
    predictions[1, :] = 0.5
    predictions[2, :] = 0.15
    predictions[3, :] = 0.15
    predictions[4, 0] = 0.449
    predictions[5, 1] = 0.28

    detections = decode_yolov11_output(predictions.tolist(), img_size=640, conf_threshold=0.45, iou_threshold=0.45)
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
        "assert labels == ['whitefly', 'aphids']\n"
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


def test_tier4_scenario_audited_kaggle_regression_guard(ml_root: Path) -> None:
    """Reject CPU/non-GPU, synthetic data, OOD false positive spikes, and tensor shape mismatch."""
    bad_ood_metrics = {
        "map50": 0.90,
        "recall": 0.85,
        "f1": 0.87,
        "small_scale_recall": 0.85,
        "tflite_map50_drop": 0.002,
        "ood_false_positive_rate": 0.25,
        "model_size_mb": 5.5,
    }
    with pytest.raises(ValueError, match="ood_false_positive_rate"):
        assert_promotion_ready(bad_ood_metrics)

    v4_provenance = {
        "enable_gpu": False,
        "device": "CPU (Intel Xeon CPU @ 2.20GHz)",
        "dataset_origin": "synthetic_fallback",
        "split_leakage": 0,
        "total_images": 108,
    }
    with pytest.raises(AssertionError):
        _assert_valid_production_provenance(v4_provenance)

    for cpu_disguised in (
        {"device": "gpu_none", "split_leakage": 0, "total_images": 785},
        {"device": "no_gpu", "split_leakage": 0, "total_images": 785},
        {"device": "CPU (Tesla T4)", "split_leakage": 0, "total_images": 785},
        {"device": "simulated_t4", "split_leakage": 0, "total_images": 785},
        {"enable_gpu": True, "gpu_count": 0, "split_leakage": 0, "total_images": 785},
        {"enable_gpu": True, "split_leakage": 0, "total_images": 785},
    ):
        with pytest.raises(AssertionError):
            _assert_valid_production_provenance(cpu_disguised)

    for valid_gpu in ("Tesla T4", "NVIDIA Tesla P100-PCIE-16GB", "cuda:0", "Tesla T4 x2", "NVIDIA L4"):
        _assert_valid_production_provenance(
            {"enable_gpu": True, "device": valid_gpu, "split_leakage": 0, "total_images": 785}
        )

    interp = Interpreter(model_path=str(ml_root / "artifacts" / "yolo11n_lettuce_pests.tflite"))
    interp.allocate_tensors()
    in_detail = interp.get_input_details()[0]
    actual_shape = [int(x) for x in in_detail["shape"]]
    mismatched_shape = (1, 3, 320, 320) if actual_shape != [1, 3, 320, 320] else (1, 640, 640, 3)
    with pytest.raises(ValueError):
        interp.set_tensor(in_detail["index"], np.zeros(mismatched_shape, dtype=np.float32))


@pytest.mark.production_artifact
def test_tier4_prod_m2_dataset_prep_fail_fast_and_cli_contract(
    tmp_path: Path,
    make_yolo_source: Any,
    monkeypatch: pytest.MonkeyPatch,
    run_cli: Any,
) -> None:
    monkeypatch.delenv("ROBOFLOW_WHITEFLY_URL", raising=False)
    monkeypatch.delenv("ROBOFLOW_APHIDS_URL", raising=False)
    empty_raw = tmp_path / "raw_empty"
    empty_raw.mkdir()
    with pytest.raises(RuntimeError):
        download_roboflow_direct_sources(empty_raw, env_file=tmp_path / "missing.env")

    by_id = {spec["dataset_id"]: spec["slug"] for spec in ROBOFLOW_DIRECT_SOURCES}
    assert by_id == {
        "rOfgg1CNHN": "jini-nkjjt/whitefly-0tong",
        "PaVtWyiDBO": "jiwons-workspace-syfav/aphids-new",
    }

    src = make_yolo_source(
        tmp_path,
        ["whitefly", "aphids"],
        [{"stem": "leaf_bug", "pattern_seed": 9, "labels": ["0 0.5 0.5 0.2 0.2"]}],
        prefix_dirs=("images", "ds1"),
    )
    records, _ = deduplicate_and_merge_sources([src])
    assert len(records) == 1

    assert canonicalize_label_name("non_aphid") is None
    assert canonicalize_label_name("molted skin") is None
    assert canonicalize_label_name("thrips") is None

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
        dataset_sources=["adityadwiferdiansyah/hidrosense-whitefly-aphids-v2"],
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
    assert size_mb <= PROMOTION_GATES["model_size_mb"][1]

    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    actual_sha = hashlib.sha256(tflite_path.read_bytes()).hexdigest()
    assert metadata["sha256"] == actual_sha

    labels = [line.strip() for line in labels_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    assert labels == ["whitefly", "aphids"]

    interp = Interpreter(model_path=str(tflite_path))
    interp.allocate_tensors()
    in_detail = interp.get_input_details()[0]
    out_detail = interp.get_output_details()[0]

    actual_in_shape = [int(x) for x in in_detail["shape"]]
    actual_out_shape = [int(x) for x in out_detail["shape"]]
    assert actual_in_shape == [1, 640, 640, 3], f"Expected NHWC [1, 640, 640, 3] input, got {actual_in_shape}"
    assert metadata["input_shape"] == actual_in_shape
    assert actual_out_shape == metadata["output_shape"] == [1, 6, 8400]
    assert in_detail["dtype"] == np.float32
    assert metadata["input_dtype"] == "float32"

    eval_report = json.loads(eval_path.read_text(encoding="utf-8"))
    assert "metrics" in metadata and metadata["metrics"] == eval_report["finetuned"]

    in_h, in_w = spatial_hw_fn(actual_in_shape)
    assert (in_h, in_w) == (640, 640)
    sample_img = Image.new("RGB", (640, 640), color=(45, 130, 50))
    hwc, _ = letterbox_fn(sample_img, (640, 640), pad_value=int(metadata["letterbox_pad_value"]))
    tensor_in = adapt_input_fn(hwc, actual_in_shape)
    interp.set_tensor(in_detail["index"], tensor_in)
    interp.invoke()
    raw_out = interp.get_tensor(out_detail["index"])
    assert list(raw_out.shape) == [1, 6, 8400]
    assert np.all(np.isfinite(raw_out))


_DEVICE_PROVENANCE_KEYS: frozenset[str] = frozenset({"device", "accelerator", "hardware", "gpu_device"})
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
    if not text or "cpu" in text or _NEGATIVE_DEVICE_RE.search(text):
        return False
    return bool(_GPU_DEVICE_TOKEN_RE.search(text))


def _assert_valid_production_provenance(provenance: dict[str, Any]) -> None:
    assert isinstance(provenance, dict) and provenance, "Missing provenance block in evaluation_report.json"

    str_values = _iter_string_values(provenance)
    synthetic_hits = [val for val in str_values if "synthetic" in val.lower()]
    assert not synthetic_hits, f"Synthetic provenance value detected: {synthetic_hits}"
    for syn_key, syn_val in _iter_key_values(provenance, frozenset({"synthetic_images", "synthetic_images_count"})):
        assert isinstance(syn_val, int) and not isinstance(syn_val, bool) and syn_val == 0
    for _, zero_syn_confirmed in _iter_key_values(provenance, frozenset({"zero_synthetic_confirmed"})):
        assert zero_syn_confirmed is True

    for _, gpu_flag in _iter_key_values(provenance, frozenset({"enable_gpu"})):
        assert gpu_flag is True

    for _, cnt_val in _iter_key_values(provenance, frozenset({"gpu_count", "num_gpus"})):
        assert isinstance(cnt_val, int) and not isinstance(cnt_val, bool) and cnt_val > 0

    device_entries = _iter_key_values(provenance, _DEVICE_PROVENANCE_KEYS)
    assert device_entries, "Provenance must include a GPU device field"
    for dev_key, dev_val in device_entries:
        assert _is_explicit_gpu_device(dev_val), f"Expected GPU device in provenance[{dev_key!r}], got {dev_val!r}"

    assert "split_leakage" in provenance
    split_leakage = provenance["split_leakage"]
    assert isinstance(split_leakage, int) and not isinstance(split_leakage, bool) and split_leakage == 0
    assert int(provenance.get("total_images", 0)) > 108


@pytest.mark.production_artifact
def test_tier4_prod_m4_evaluation_report_real_provenance_per_class_and_gates(ml_root: Path) -> None:
    report_path = ml_root / "reports" / "evaluation_report.json"
    report = json.loads(report_path.read_text(encoding="utf-8"))

    assert report.get("status") == "PASSED"
    assert report.get("beats_baseline") is True
    assert "gates" in report
    assert_promotion_ready(report["gates"])

    per_class = report.get("per_class", {})
    for cls_name in ("whitefly", "aphids"):
        assert cls_name in per_class, f"Missing per_class entry for {cls_name}"
        assert per_class[cls_name]["map50"] > 0.0
        assert per_class[cls_name]["recall"] > 0.0

    tflite_eval = report.get("tflite_eval", {})
    assert "tflite_map50_drop" in tflite_eval
    assert tflite_eval["tflite_map50_drop"] <= PROMOTION_GATES["tflite_map50_drop"][1]
    cls_ood = tflite_eval.get("classification_and_ood", {})
    assert cls_ood.get("ood_false_positive_rate", 1.0) <= PROMOTION_GATES["ood_false_positive_rate"][1]

    _assert_valid_production_provenance(report.get("provenance", {}))
