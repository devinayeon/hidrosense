from __future__ import annotations

import json
import math
import subprocess
import sys
import zipfile
from pathlib import Path
from types import SimpleNamespace
from typing import Any

import numpy as np
import pytest
import yaml
from PIL import Image, ImageDraw

from ml import evaluate as ml_evaluate
from ml import export_tflite as ml_export
from ml import kaggle_train_entry as k_entry
from ml import prepare_dataset as ml_prep
from ml import train as ml_train


def _make_rgb_image(path: Path, size: tuple[int, int] = (128, 128), color: tuple[int, int, int] = (40, 120, 60)) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img = Image.new("RGB", size, color=color)
    draw = ImageDraw.Draw(img)
    draw.rectangle((10, 10, max(20, size[0] // 2), max(20, size[1] // 2)), fill=(220, 200, 40))
    img.save(path)


# =============================================================================
# 1. Decoder & Metadata Scale Guards (B2, B9)
# =============================================================================


def test_t5_decode_yolov11_rejects_nan_inf_and_invalid_img_size() -> None:
    """B2: NaN scores/coords, Inf boxes, invalid img_size, and mixed pixel scaling."""
    nan = float("nan")
    inf = float("inf")
    ninf = float("-inf")

    adversarial_rows = [
        [0.5, 0.5, 0.2, 0.2, nan, 0.9, 0.1],
        [0.5, 0.5, 0.2, 0.2, 0.1, nan, 0.9],
        [0.5, 0.5, 0.2, 0.2, 0.1, 0.2, nan],
        [nan, 0.5, 0.2, 0.2, 0.95, 0.0, 0.0],
        [0.5, nan, 0.2, 0.2, 0.95, 0.0, 0.0],
        [0.5, 0.5, inf, 0.2, 0.95, 0.0, 0.0],
        [0.5, 0.5, 0.2, ninf, 0.95, 0.0, 0.0],
    ]
    assert ml_export.decode_yolov11_output(adversarial_rows, img_size=640) == []

    for bad_size in (0, -1, -640, True):
        with pytest.raises(ValueError, match="img_size"):
            ml_export.decode_yolov11_output([[320.0, 320.0, 64.0, 64.0, 0.9, 0.0, 0.0]], img_size=bad_size)

    # Tensor-wide pixel scaling consistency: row 0 has coords <= 1.5 but row 1 is in pixel space
    mixed_pixel_rows = [
        [1.2, 1.2, 1.0, 1.0, 0.9, 0.0, 0.0],
        [320.0, 320.0, 64.0, 64.0, 0.8, 0.0, 0.0],
    ]
    dets = ml_export.decode_yolov11_output(mixed_pixel_rows, img_size=640, conf_threshold=0.35)
    assert len(dets) == 2
    assert dets[0]["box"] == pytest.approx((0.7 / 640.0, 0.7 / 640.0, 1.7 / 640.0, 1.7 / 640.0), abs=1e-6)
    assert dets[1]["box"] == pytest.approx((0.45, 0.45, 0.55, 0.55), abs=1e-6)


@pytest.mark.parametrize(
    ("img_size", "expected_anchors"),
    [
        (320, 2100),
        (640, 8400),
        (300, 8400),
    ],
)
def test_t5_build_model_metadata_scales_anchors_with_img_size(img_size: int, expected_anchors: int) -> None:
    """B9: Default anchor count scales with img_size when divisible by 32."""
    meta = ml_export.build_model_metadata("v1", img_size=img_size)
    assert meta["input_shape"] == [1, img_size, img_size, 3]
    assert meta["output_shape"] == [1, 7, expected_anchors]


# =============================================================================
# 2. Promotion Gates & Non-Finite Metric Guards (B1)
# =============================================================================


@pytest.mark.parametrize("bad_value", [float("nan"), float("inf"), float("-inf"), True, False, "0.9"])
@pytest.mark.parametrize("gate_key", ["map50", "recall", "tflite_map50_drop", "model_size_mb"])
def test_t5_assert_promotion_ready_rejects_nan_inf_and_bool(gate_key: str, bad_value: Any) -> None:
    """B1: Promotion gates must reject NaN, +/-Inf, bool, and non-numeric values."""
    valid = {
        "map50": 0.85,
        "recall": 0.80,
        "tflite_map50_drop": 0.005,
        "model_size_mb": 5.0,
    }
    valid[gate_key] = bad_value
    with pytest.raises(ValueError, match="finite numbers"):
        ml_evaluate.assert_promotion_ready(valid)


def test_t5_evaluate_main_rejects_nan_map50_before_clamping(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """B1: main() must raise ValueError when tflite or finetuned map50 is NaN instead of clamping to 0.0."""
    base_pt = tmp_path / "base.pt"
    best_pt = tmp_path / "best.pt"
    fake_tflite = tmp_path / "model.tflite"
    base_pt.write_bytes(b"\x00" * 32)
    best_pt.write_bytes(b"\x00" * 32)
    fake_tflite.write_bytes(b"DUMMY_MOCK_TFLITE")
    data_yaml = tmp_path / "data.yaml"
    data_yaml.write_text("nc: 3\nnames: [thrips, whitefly, aphids]\n", encoding="utf-8")

    def _fake_eval(path: Path, d_yaml: Path, imgsz: int = 640) -> dict[str, Any]:
        if path.suffix == ".tflite":
            return {"map50": float("nan"), "map50_95": 0.5, "precision": 0.8, "recall": 0.8, "f1": 0.8}
        return {"map50": 0.85, "map50_95": 0.5, "precision": 0.85, "recall": 0.80, "f1": 0.82}

    monkeypatch.setattr(ml_evaluate, "evaluate_ultralytics_model", _fake_eval)
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "ml.evaluate",
            "--baseline",
            str(base_pt),
            "--weights",
            str(best_pt),
            "--tflite",
            str(fake_tflite),
            "--data",
            str(data_yaml),
            "--output",
            str(tmp_path / "report.json"),
        ],
    )
    with pytest.raises(ValueError, match="Non-finite map50"):
        ml_evaluate.main()


# =============================================================================
# 3. Letterbox & LiteRT Evaluation Edge Paths (B3, B4, B5, G4, G5)
# =============================================================================


def test_t5_letterbox_extreme_aspect_ratio_and_corrupt_test_split(tmp_path: Path) -> None:
    """B3, B5, G4: Extreme aspect ratios don't crash cv2.resize; empty/corrupt test splits raise clearly."""
    for h, w in ((2000, 1), (1, 2000)):
        img = np.zeros((h, w, 3), dtype=np.uint8)
        rgb, (new_w, new_h), (left, top) = ml_evaluate._letterbox_bgr_to_rgb_float(img, 640, 640)
        assert rgb.shape == (640, 640, 3)
        assert rgb.dtype == np.float32
        assert np.all(np.isfinite(rgb))
        assert new_w >= 1 and new_h >= 1
        assert left >= 0 and top >= 0

    real_tflite = Path(__file__).resolve().parents[2] / "artifacts" / "yolo11n_lettuce_pests.tflite"

    # Empty test/images -> FileNotFoundError
    empty_ds = tmp_path / "empty_ds"
    (empty_ds / "test" / "images").mkdir(parents=True)
    empty_yaml = empty_ds / "data.yaml"
    empty_yaml.write_text(
        yaml.safe_dump(
            {
                "path": str(empty_ds),
                "train": "test/images",
                "val": "test/images",
                "test": "test/images",
                "nc": 3,
                "names": {0: "thrips", 1: "whitefly", 2: "aphids"},
            },
            sort_keys=False,
        ),
        encoding="utf-8",
    )
    with pytest.raises(FileNotFoundError, match="No test images found"):
        ml_evaluate.evaluate_tflite_litert(real_tflite, empty_yaml)

    # All test images corrupt -> explicit ValueError instead of DetMetrics.process crash
    corrupt_ds = tmp_path / "corrupt_ds"
    (corrupt_ds / "test" / "images").mkdir(parents=True)
    (corrupt_ds / "test" / "labels").mkdir(parents=True)
    (corrupt_ds / "test" / "images" / "bad.jpg").write_bytes(b"corrupt_jpeg_bytes")
    (corrupt_ds / "test" / "labels" / "bad.txt").write_text("0 0.5 0.5 0.2 0.2\n", encoding="utf-8")
    corrupt_yaml = corrupt_ds / "data.yaml"
    corrupt_yaml.write_text(
        yaml.safe_dump(
            {
                "path": str(corrupt_ds),
                "train": "test/images",
                "val": "test/images",
                "test": "test/images",
                "nc": 3,
                "names": {0: "thrips", 1: "whitefly", 2: "aphids"},
            },
            sort_keys=False,
        ),
        encoding="utf-8",
    )
    with pytest.raises(ValueError, match="failed to decode"):
        ml_evaluate.evaluate_tflite_litert(real_tflite, corrupt_yaml)


def test_t5_evaluate_main_forwards_imgsz_and_litert_edge_paths(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """B4, B5, B9, G4, G5: main forwards --imgsz, handles non-TFL3, INT8 quant, non-finite out, provenance."""
    base_pt = tmp_path / "base.pt"
    best_pt = tmp_path / "best.pt"
    fake_tflite = tmp_path / "non_tfl3.tflite"
    base_pt.write_bytes(b"\x00" * 64)
    best_pt.write_bytes(b"\x00" * 64)
    fake_tflite.write_bytes(b"MOCK_TFLITE_PAYLOAD")
    data_yaml = tmp_path / "data.yaml"
    data_yaml.write_text("nc: 3\nnames: [thrips, whitefly, aphids]\n", encoding="utf-8")
    out_report = tmp_path / "eval_report.json"

    observed_imgsz: list[tuple[str, int]] = []

    def _fake_eval(path: Path, d_yaml: Path, imgsz: int = 640) -> dict[str, Any]:
        observed_imgsz.append((path.name, imgsz))
        per_cls = {
            "thrips": {"precision": 0.8, "recall": 0.7, "map50": 0.75, "map50_95": 0.4, "f1": 0.75},
            "whitefly": {"precision": 0.9, "recall": 0.9, "map50": 0.92, "map50_95": 0.6, "f1": 0.9},
            "aphids": {"precision": 0.88, "recall": 0.85, "map50": 0.89, "map50_95": 0.55, "f1": 0.86},
        }
        if path.suffix == ".tflite":
            return {"map50": 0.88, "map50_95": 0.5, "precision": 0.87, "recall": 0.82, "f1": 0.84, "per_class": per_cls}
        if "best" in path.name:
            return {"map50": 0.89, "map50_95": 0.52, "precision": 0.88, "recall": 0.84, "f1": 0.86, "per_class": per_cls}
        return {"map50": 0.80, "map50_95": 0.45, "precision": 0.82, "recall": 0.78, "f1": 0.80, "per_class": per_cls}

    monkeypatch.setattr(ml_evaluate, "evaluate_ultralytics_model", _fake_eval)
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "ml.evaluate",
            "--baseline",
            str(base_pt),
            "--weights",
            str(best_pt),
            "--tflite",
            str(fake_tflite),
            "--data",
            str(data_yaml),
            "--imgsz",
            "320",
            "--output",
            str(out_report),
        ],
    )
    ml_evaluate.main()
    assert observed_imgsz == [("base.pt", 320), ("best.pt", 320), ("non_tfl3.tflite", 320)]
    report = json.loads(out_report.read_text(encoding="utf-8"))
    assert report["tflite_eval"]["input_shape"] == [1, 320, 320, 3]
    assert report["tflite_eval"]["output_shape"] == [1, 7, 2100]

    # build_provenance_payload branches (G5)
    assert ml_evaluate.build_provenance_payload(None, None) is None

    k_sum = tmp_path / "k_sum.json"
    k_sum.write_text(
        json.dumps({"provenance": {"device": "Tesla T4", "enable_gpu": True, "split_leakage": 0}}),
        encoding="utf-8",
    )
    ds_prov = tmp_path / "ds_prov.json"
    ds_prov.write_text(
        json.dumps(
            {
                "zero_synthetic_confirmed": True,
                "synthetic_images_count": 0,
                "sources_probed": [
                    {
                        "slug": "ws/proj",
                        "version": 1,
                        "format": "yolov11",
                        "required": True,
                        "accessible": True,
                        "status": "downloaded",
                        "raw_split_image_counts": {"train": 10},
                    }
                ],
                "deduplication": {"total_scanned": 10, "duplicates_removed": 0, "boxes_kept": 10},
                "splits": {
                    "train": {
                        "images": 8,
                        "groups": 8,
                        "instances": 8,
                        "per_class_instances": {"thrips": 3, "whitefly": 3, "aphids": 2},
                        "manifest_sha256": "abc",
                    }
                },
                "verification": {"status": "passed", "cross_split_sha256_overlaps": 0},
            }
        ),
        encoding="utf-8",
    )
    prov = ml_evaluate.build_provenance_payload(k_sum, ds_prov)
    assert prov is not None
    assert prov["roboflow_sources"][0]["slug"] == "ws/proj"
    assert prov["deduplication"]["total_scanned"] == 10
    assert prov["split_manifests"]["train"]["images"] == 8
    assert prov["dataset_verification"]["status"] == "passed"

    # Synthetic/spoofed provenance must raise rather than silently masking
    for bad_prov in (
        {"provenance": {"dataset_origin": "synthetic_fallback", "zero_synthetic_confirmed": True}},
        {"provenance": {"dataset_origin": "SYNTHETIC_SOURCE"}},
        {"provenance": {"zero_synthetic_confirmed": False}},
        {"provenance": {"synthetic_images_count": 5}},
    ):
        bad_k = tmp_path / "bad_k.json"
        bad_k.write_text(json.dumps(bad_prov), encoding="utf-8")
        with pytest.raises(ValueError):
            ml_evaluate.build_provenance_payload(bad_k, None)

    # evaluate_tflite_litert with fake Interpreter: INT8 quant/dequant, zero scale guard, non-finite output, multi-GT
    litert_ds = tmp_path / "litert_ds"
    (litert_ds / "test" / "labels").mkdir(parents=True, exist_ok=True)
    for idx, lbl_txt in enumerate(
        (
            "0 0.5 0.5 0.25 0.25\n0 0.2 0.2 0.1 0.1\n",
            "",  # empty label file
        )
    ):
        _make_rgb_image(litert_ds / "test" / "images" / f"img_{idx}.jpg", (160, 160))
        (litert_ds / "test" / "labels" / f"img_{idx}.txt").write_text(lbl_txt, encoding="utf-8")
    litert_yaml = litert_ds / "data.yaml"
    litert_yaml.write_text(
        yaml.safe_dump(
            {
                "path": str(litert_ds),
                "train": "test/images",
                "val": "test/images",
                "test": "test/images",
                "nc": 3,
                "names": {0: "thrips", 1: "whitefly", 2: "aphids"},
            },
            sort_keys=False,
        ),
        encoding="utf-8",
    )

    class _MockInterpreter:
        mode = "int8"

        def __init__(self, model_path: str, num_threads: int = 1) -> None:
            self._in_tensor = None

        def allocate_tensors(self) -> None:
            pass

        def get_input_details(self) -> list[dict[str, Any]]:
            if self.mode == "zero_in_scale":
                return [{"index": 0, "shape": np.array([1, 64, 64, 3]), "dtype": np.int8, "quantization": (0.0, -128)}]
            return [{"index": 0, "shape": np.array([1, 64, 64, 3]), "dtype": np.int8, "quantization": (1.0 / 255.0, -128)}]

        def get_output_details(self) -> list[dict[str, Any]]:
            if self.mode == "zero_out_scale":
                return [{"index": 0, "shape": np.array([1, 7, 4]), "dtype": np.int8, "quantization": (0.0, -128)}]
            if self.mode == "nan_out":
                return [{"index": 0, "shape": np.array([1, 7, 4]), "dtype": np.float32, "quantization": (0.0, 0)}]
            return [{"index": 0, "shape": np.array([1, 7, 4]), "dtype": np.int8, "quantization": (0.01, -128)}]

        def set_tensor(self, idx: int, arr: np.ndarray) -> None:
            self._in_tensor = arr

        def invoke(self) -> None:
            pass

        def get_tensor(self, idx: int) -> np.ndarray:
            if self.mode == "nan_out":
                out = np.zeros((1, 7, 4), dtype=np.float32)
                out[0, 4, 0] = float("nan")
                return out
            out_q = np.full((1, 7, 4), -128, dtype=np.int8)
            # Anchor 0: box (0.5, 0.5, 0.25, 0.25) -> raw 0.5 -> int8 = 0.5/0.01 - 128 = -78; score 0.9 -> -38
            out_q[0, 0, 0] = -78
            out_q[0, 1, 0] = -78
            out_q[0, 2, 0] = -103
            out_q[0, 3, 0] = -103
            out_q[0, 4, 0] = -38
            return out_q

    import ai_edge_litert.interpreter as litert_mod

    monkeypatch.setattr(litert_mod, "Interpreter", _MockInterpreter)

    _MockInterpreter.mode = "int8"
    res_int8 = ml_evaluate.evaluate_tflite_litert(fake_tflite, litert_yaml, imgsz=64)
    assert res_int8["images_evaluated"] == 2
    assert res_int8["input_dtype"] == "int8"
    assert res_int8["output_dtype"] == "int8"

    _MockInterpreter.mode = "zero_in_scale"
    with pytest.raises(ValueError, match="Invalid input quantization scale"):
        ml_evaluate.evaluate_tflite_litert(fake_tflite, litert_yaml, imgsz=64)

    _MockInterpreter.mode = "zero_out_scale"
    with pytest.raises(ValueError, match="Invalid output quantization scale"):
        ml_evaluate.evaluate_tflite_litert(fake_tflite, litert_yaml, imgsz=64)

    _MockInterpreter.mode = "nan_out"
    with pytest.raises(ValueError, match="Non-finite TFLite inference output"):
        ml_evaluate.evaluate_tflite_litert(fake_tflite, litert_yaml, imgsz=64)


# =============================================================================
# 4. Kaggle Poll & Train Resolution Paths (B7, G3)
# =============================================================================


def test_t5_poll_kaggle_kernel_slug_with_error_and_retry_timeout(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """B7, G3: poll_kaggle_kernel handles error/complete slugs, retries, timeout, resolve_dataset_yaml, --kaggle-push."""
    monkeypatch.setattr(ml_train.time, "sleep", lambda _: None)

    # 1. Slug containing "error" and "cancel" during RUNNING -> COMPLETE succeeds
    responses = iter(
        [
            subprocess.CompletedProcess(["kaggle"], 0, stdout='user/error-cancel-kernel has status "KernelWorkerStatus.RUNNING"\n', stderr=""),
            subprocess.CompletedProcess(["kaggle"], 0, stdout='user/error-cancel-kernel has status "KernelWorkerStatus.COMPLETE"\n', stderr=""),
        ]
    )
    monkeypatch.setattr(ml_train.subprocess, "run", lambda *a, **kw: next(responses))
    status = ml_train.poll_kaggle_kernel("user/error-cancel-kernel", poll_interval_s=0)
    assert "COMPLETE" in status

    # 2. Slug containing "complete" while QUEUED does NOT prematurely return COMPLETE
    queued_then_complete = iter(
        [
            subprocess.CompletedProcess(["kaggle"], 0, stdout='user/complete-v2 has status "KernelWorkerStatus.QUEUED"\n', stderr=""),
            subprocess.CompletedProcess(["kaggle"], 0, stdout='user/complete-v2 has status "KernelWorkerStatus.COMPLETE"\n', stderr=""),
        ]
    )
    calls = 0

    def _run_q(*a: Any, **kw: Any) -> subprocess.CompletedProcess[str]:
        nonlocal calls
        calls += 1
        return next(queued_then_complete)

    monkeypatch.setattr(ml_train.subprocess, "run", _run_q)
    assert "COMPLETE" in ml_train.poll_kaggle_kernel("user/complete-v2", poll_interval_s=0)
    assert calls == 2

    # 3. ERROR and CANCEL statuses raise RuntimeError
    for fail_status in ("KernelWorkerStatus.ERROR", "KernelWorkerStatus.CANCEL_ACKNOWLEDGED"):
        monkeypatch.setattr(
            ml_train.subprocess,
            "run",
            lambda *a, fs=fail_status, **kw: subprocess.CompletedProcess(["kaggle"], 0, stdout=f'u/k has status "{fs}"', stderr=""),
        )
        with pytest.raises(RuntimeError, match="failed"):
            ml_train.poll_kaggle_kernel("u/k", poll_interval_s=0)

    # 4. Transient CalledProcessError (< max_consecutive_errors) recovers
    transient_seq = iter(
        [
            subprocess.CalledProcessError(1, ["kaggle"], stderr="503 Service Unavailable"),
            subprocess.CompletedProcess(["kaggle"], 0, stdout='u/k has status "KernelWorkerStatus.COMPLETE"', stderr=""),
        ]
    )

    def _run_transient(*a: Any, **kw: Any) -> subprocess.CompletedProcess[str]:
        item = next(transient_seq)
        if isinstance(item, Exception):
            raise item
        return item

    monkeypatch.setattr(ml_train.subprocess, "run", _run_transient)
    assert "COMPLETE" in ml_train.poll_kaggle_kernel("u/k", poll_interval_s=0, max_consecutive_errors=3)

    # 5. Exceeding max_consecutive_errors raises RuntimeError
    def _always_err(*a: Any, **kw: Any) -> subprocess.CompletedProcess[str]:
        raise subprocess.CalledProcessError(1, ["kaggle"], stderr="network down")

    monkeypatch.setattr(ml_train.subprocess, "run", _always_err)
    with pytest.raises(RuntimeError, match="failed 2 times"):
        ml_train.poll_kaggle_kernel("u/k", poll_interval_s=0, max_consecutive_errors=2)

    # 6. TimeoutError when deadline expires while RUNNING
    with monkeypatch.context() as mp:
        tick = iter([0.0, 1000.0])
        mp.setattr(ml_train.time, "monotonic", lambda: next(tick))
        mp.setattr(
            ml_train.subprocess,
            "run",
            lambda *a, **kw: subprocess.CompletedProcess(["kaggle"], 0, stdout='u/k has status "KernelWorkerStatus.RUNNING"', stderr=""),
        )
        with pytest.raises(TimeoutError, match="Timed out"):
            ml_train.poll_kaggle_kernel("u/k", poll_interval_s=0, timeout_minutes=1)

    # 7. resolve_dataset_yaml all 5 branches
    missing_yaml = tmp_path / "does_not_exist.yaml"
    assert ml_train.resolve_dataset_yaml(missing_yaml, tmp_path / "o1") == missing_yaml

    list_yaml = tmp_path / "list.yaml"
    list_yaml.write_text("- a\n- b\n", encoding="utf-8")
    assert ml_train.resolve_dataset_yaml(list_yaml, tmp_path / "o2") == list_yaml

    omitted_yaml = tmp_path / "omitted.yaml"
    omitted_yaml.write_text("train: train/images\nval: val/images\nnc: 3\n", encoding="utf-8")
    resolved_omitted = yaml.safe_load(ml_train.resolve_dataset_yaml(omitted_yaml, tmp_path / "o3").read_text(encoding="utf-8"))
    assert Path(resolved_omitted["path"]) == tmp_path.resolve()

    abs_ds = tmp_path / "abs_ds"
    abs_ds.mkdir()
    abs_yaml = tmp_path / "abs.yaml"
    abs_yaml.write_text(yaml.safe_dump({"path": str(abs_ds), "val": "val/images"}), encoding="utf-8")
    resolved_abs = yaml.safe_load(ml_train.resolve_dataset_yaml(abs_yaml, tmp_path / "o4").read_text(encoding="utf-8"))
    assert Path(resolved_abs["path"]) == abs_ds.resolve()

    cwd_root = tmp_path / "cwd_root"
    (cwd_root / "rel_ds" / "val" / "images").mkdir(parents=True)
    rel_yaml = tmp_path / "sub" / "rel.yaml"
    rel_yaml.parent.mkdir(parents=True)
    rel_yaml.write_text("path: rel_ds\nval: val/images\n", encoding="utf-8")
    monkeypatch.chdir(cwd_root)
    resolved_rel = yaml.safe_load(ml_train.resolve_dataset_yaml(rel_yaml, tmp_path / "o5").read_text(encoding="utf-8"))
    assert Path(resolved_rel["path"]) == (cwd_root / "rel_ds").resolve()

    # 8. download_kaggle_kernel_output and main --kaggle-push --poll
    recorded_cmds: list[list[str]] = []

    def _mock_kaggle_cli(cmd: list[str], **kw: Any) -> subprocess.CompletedProcess[str]:
        recorded_cmds.append(list(cmd))
        if cmd[1:3] == ["kernels", "status"]:
            return subprocess.CompletedProcess(cmd, 0, stdout='u/slug has status "KernelWorkerStatus.COMPLETE"', stderr="")
        return subprocess.CompletedProcess(cmd, 0, stdout="ok", stderr="")

    monkeypatch.setattr(ml_train.subprocess, "run", _mock_kaggle_cli)
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "ml.train",
            "--kaggle-push",
            "--poll",
            "--kaggle-username",
            "u",
            "--kaggle-slug",
            "slug",
            "--kaggle-bundle-dir",
            str(tmp_path / "bundle"),
            "--kaggle-output-dir",
            str(tmp_path / "k_out"),
        ],
    )
    ml_train.main()
    assert any(c[1:3] == ["kernels", "push"] for c in recorded_cmds)
    assert any(c[1:3] == ["kernels", "status"] for c in recorded_cmds)
    assert any(c[1:3] == ["kernels", "output"] for c in recorded_cmds)


# =============================================================================
# 5. Kaggle Train Entry Validation & Helpers (G1, G2)
# =============================================================================


def test_t5_kaggle_train_entry_validation_and_views_boundaries(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """G1, G2: validate_real_dataset, _parse_version_tuple, ensure_gpu_available, locate_dataset_dir, metrics."""
    # _parse_version_tuple handles rc suffixes cleanly
    assert k_entry._parse_version_tuple("8.3rc1") == (8, 3, 0)
    assert k_entry._parse_version_tuple("8.4.216+cu130") == (8, 4, 216)

    # ensure_gpu_available happy path and device_count == 0
    import torch

    monkeypatch.setattr(torch.cuda, "is_available", lambda: True)
    monkeypatch.setattr(torch.cuda, "device_count", lambda: 0)
    with pytest.raises(RuntimeError, match="CUDA GPU is required"):
        k_entry.ensure_gpu_available()

    monkeypatch.setattr(torch.cuda, "device_count", lambda: 1)
    monkeypatch.setattr(torch.cuda, "get_device_name", lambda idx: "Tesla T4")
    monkeypatch.setattr(torch.cuda, "get_device_properties", lambda idx: SimpleNamespace(total_memory=16 * (1024**3)))
    gpu_info = k_entry.ensure_gpu_available()
    assert gpu_info["enable_gpu"] is True
    assert gpu_info["device"] == "Tesla T4"
    assert gpu_info["gpu_vram_gb"] == pytest.approx(16.0)

    # Build a small valid real-format dataset and test validate_real_dataset
    def _make_ds(root: Path, counts: dict[str, int] | None = None) -> Path:
        counts = counts or {"train": 2, "val": 1, "test": 1}
        for split_name, cnt in counts.items():
            (root / split_name / "images").mkdir(parents=True, exist_ok=True)
            (root / split_name / "labels").mkdir(parents=True, exist_ok=True)
            for i in range(cnt):
                _make_rgb_image(root / split_name / "images" / f"{split_name}_{i}.jpg")
                (root / split_name / "labels" / f"{split_name}_{i}.txt").write_text("0 0.5 0.5 0.2 0.2\n", encoding="utf-8")
        (root / "data.yaml").write_text(
            yaml.safe_dump({"nc": 3, "names": {0: "thrips", 1: "whitefly", 2: "aphids"}}, sort_keys=False),
            encoding="utf-8",
        )
        (root / "dataset_provenance.json").write_text(
            json.dumps(
                {
                    "zero_synthetic_confirmed": True,
                    "synthetic_images_count": 0,
                    "split_leakage": 0,
                    "verification": {"cross_split_sha256_overlaps": 0, "cross_split_phash_overlaps": 0},
                }
            ),
            encoding="utf-8",
        )
        return root

    ds_dir = _make_ds(tmp_path / "valid_ds")
    monkeypatch.setattr(k_entry, "EXPECTED_SPLIT_COUNTS", {"train": 2, "val": 1, "test": 1})

    summary = k_entry.validate_real_dataset(ds_dir)
    assert summary["total_images"] == 4
    assert summary["zero_synthetic_confirmed"] is True

    # locate_dataset_dir via HIDROSENSE_DATASET_DIR and allow_local=True
    monkeypatch.setenv("HIDROSENSE_DATASET_DIR", str(ds_dir))
    assert k_entry.locate_dataset_dir() == ds_dir.resolve()

    monkeypatch.delenv("HIDROSENSE_DATASET_DIR", raising=False)
    local_ws = tmp_path / "local_ws"
    _make_ds(local_ws / "ml" / "data" / "merged_lettuce_pests")
    monkeypatch.chdir(local_ws)
    assert k_entry.locate_dataset_dir(allow_local=True) == (local_ws / "ml" / "data" / "merged_lettuce_pests").resolve()

    # build_isolated_dataset_views(thrips_oversample_factor=0) -> ValueError
    with pytest.raises(ValueError, match="thrips_oversample_factor"):
        k_entry.build_isolated_dataset_views(ds_dir, tmp_path / "views_bad", thrips_oversample_factor=0)

    # validate_real_dataset rejection branches
    (ds_dir / "data.yaml").write_text(yaml.safe_dump({"nc": 2, "names": [0, 1]}), encoding="utf-8")
    with pytest.raises(ValueError, match="nc == 3"):
        k_entry.validate_real_dataset(ds_dir)

    (ds_dir / "data.yaml").write_text(yaml.safe_dump({"nc": 3, "names": ["a", "b", "c"]}), encoding="utf-8")
    with pytest.raises(ValueError, match="canonical names"):
        k_entry.validate_real_dataset(ds_dir)
    (ds_dir / "data.yaml").write_text(yaml.safe_dump({"nc": 3, "names": {0: "thrips", 1: "whitefly", 2: "aphids"}}), encoding="utf-8")

    for bad_prov, err_re in (
        ({"zero_synthetic_confirmed": False, "synthetic_images_count": 0}, "zero_synthetic_confirmed"),
        ({"zero_synthetic_confirmed": True, "synthetic_images_count": 2}, "synthetic_images_count"),
        ({"zero_synthetic_confirmed": True, "synthetic_images_count": 0, "verification": {"cross_split_phash_overlaps": 1}}, "leakage"),
        ({"zero_synthetic_confirmed": True, "synthetic_images_count": 0, "split_leakage": 1}, "split_leakage"),
    ):
        (ds_dir / "dataset_provenance.json").write_text(json.dumps(bad_prov), encoding="utf-8")
        with pytest.raises(ValueError, match=err_re):
            k_entry.validate_real_dataset(ds_dir)

    # Restore valid provenance, break stem match & split count
    (ds_dir / "dataset_provenance.json").write_text(
        json.dumps({"zero_synthetic_confirmed": True, "synthetic_images_count": 0, "split_leakage": 0}),
        encoding="utf-8",
    )
    (ds_dir / "val" / "labels" / "val_0.txt").rename(ds_dir / "val" / "labels" / "wrong_stem.txt")
    with pytest.raises(ValueError, match="stem mismatch"):
        k_entry.validate_real_dataset(ds_dir)
    (ds_dir / "val" / "labels" / "wrong_stem.txt").unlink()
    with pytest.raises(ValueError, match="expected 1 images/labels"):
        k_entry.validate_real_dataset(ds_dir)

    # extract_eval_metrics & _compute_improvements
    class _FakeBox:
        mp, mr, map50, map = 0.85, 0.80, 0.88, 0.55
        ap_class_index = [0, 1, 2]
        f1 = [0.75, 0.90, 0.85]

        def class_result(self, pos: int) -> tuple[float, float, float, float]:
            return [(0.78, 0.72, 0.76, 0.40), (0.91, 0.89, 0.94, 0.65), (0.86, 0.84, 0.90, 0.58)][pos]

    base_eval = k_entry.extract_eval_metrics(SimpleNamespace(box=_FakeBox()))
    imp_eval = {
        "aggregate": {"map50": 0.91, "map50_95": 0.60, "precision": 0.88, "recall": 0.84, "f1": 0.86},
        "per_class": {
            "thrips": {"map50": 0.82, "recall": 0.78},
            "whitefly": {"map50": 0.95, "recall": 0.90},
            "aphids": {"map50": 0.92, "recall": 0.86},
        },
    }
    deltas = k_entry._compute_improvements(base_eval, imp_eval)
    assert deltas["beats_baseline"] is True
    assert deltas["thrips_recall_delta"] == pytest.approx(0.06)


# =============================================================================
# 6. Dataset Prep Hardening, Secret Redaction, Image Modes & Roboflow (B6, B8, B10, G7, G8)
# =============================================================================


def test_t5_prepare_dataset_malformed_yaml_non_int_class_and_sanitize_text(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    secret_scanner: Any,
) -> None:
    """B6, B8, B10, G7, G8: secret redaction, malformed YAML, float class IDs, image modes, dihedral numpy, download."""
    # B6: _sanitize_text redacts quoted/JSON secrets, Bearer tokens, and KAGGLE_KEY/KAGGLE_API_TOKEN from env
    kg_val = "KGAT_" + "env_secret_value_000111222"
    kg_key_val = "kgkey_" + "env_secret_value_333444"
    monkeypatch.setenv("KAGGLE_API_TOKEN", kg_val)
    monkeypatch.setenv("KAGGLE_KEY", kg_key_val)

    quoted_api = "api_" + 'key="my_secret_' + '12345"'
    json_api = '{"api_' + 'key": "my_secret_' + '12345"}'
    bearer_hdr = "Authorization: " + "Bearer " + "sk_live_9876543210abcdef"
    assert "my_secret_" not in ml_prep._sanitize_text(quoted_api)
    assert "my_secret_" not in ml_prep._sanitize_text(json_api)
    assert "[REDACTED]" in ml_prep._sanitize_text(json_api)
    assert "sk_live_" not in ml_prep._sanitize_text(bearer_hdr)
    assert "[REDACTED]" in ml_prep._sanitize_text(bearer_hdr)
    assert kg_val not in ml_prep._sanitize_text(f"leak={kg_val}")
    assert kg_key_val not in ml_prep._sanitize_text(f"leak={kg_key_val}")

    # B10: SECRET_PATTERNS catches JSON-quoted keys & Bearer tokens
    json_rf = '{"ROBOFLOW_API_' + 'KEY": "super_secret_' + 'value_1234"}'
    json_kg = '{"KAGGLE_' + 'KEY": "0123456789abcdef_' + '0123456789"}'
    assert len(secret_scanner(json_rf)) >= 1
    assert len(secret_scanner(json_kg)) >= 1
    assert len(secret_scanner(bearer_hdr)) >= 1

    # B10: parse_and_sanitize_yolo_line rejects non-integer float class IDs
    assert ml_prep.parse_and_sanitize_yolo_line("0.9 0.5 0.5 0.2 0.2", {0: "thrips"}) is None
    assert ml_prep._classify_dropped_yolo_line("0.9 0.5 0.5 0.2 0.2", {0: "thrips"}) == ("invalid", None)

    # B8: load_source_class_map rejects non-dict YAML, names: null, non-int keys
    for idx, bad_yaml in enumerate(("- thrips\n- whitefly\n", "names: null\n", "names:\n  zero: thrips\n")):
        bad_dir = tmp_path / f"bad_src_{idx}"
        bad_dir.mkdir()
        (bad_dir / "data.yaml").write_text(bad_yaml, encoding="utf-8")
        with pytest.raises(ValueError):
            ml_prep.load_source_class_map(bad_dir)

    # B8 & G8: verify_exported_dataset handles malformed data.yaml + structure errors without AttributeError/TypeError
    bad_export = tmp_path / "bad_export"
    for sp in ("train", "val", "test"):
        (bad_export / sp / "images").mkdir(parents=True)
        (bad_export / sp / "labels").mkdir(parents=True)
    for bad_yaml in ("- thrips\n", "nc: 3\nnames: null\n", "nc: 3\nnames:\n  zero: thrips\n"):
        (bad_export / "data.yaml").write_text(bad_yaml, encoding="utf-8")
        with pytest.raises(ValueError, match="Dataset verification failed"):
            ml_prep.verify_exported_dataset(bad_export)

    # G8: duplicate image stems, unpaired files, empty label, missing split dir, require_all_classes
    (bad_export / "data.yaml").write_text(
        yaml.safe_dump({"train": "train/images", "val": "val/images", "test": "test/images", "nc": 3, "names": {0: "thrips", 1: "whitefly", 2: "aphids"}}),
        encoding="utf-8",
    )
    _make_rgb_image(bad_export / "train" / "images" / "dup.jpg")
    _make_rgb_image(bad_export / "train" / "images" / "dup.png")
    (bad_export / "train" / "labels" / "dup.txt").write_text("", encoding="utf-8")
    (bad_export / "train" / "labels" / "orphan.txt").write_text("0 0.5 0.5 0.2 0.2\n", encoding="utf-8")
    with pytest.raises(ValueError, match="duplicate image stem"):
        ml_prep.verify_exported_dataset(bad_export, require_all_classes=True)

    # G8: Non-RGB modes (RGBA, L, P, CMYK, I;16), EXIF Orientation=6, truncated JPEG, _DihedralHashIndex numpy path
    mode_src = tmp_path / "mode_src"
    (mode_src / "train" / "images").mkdir(parents=True)
    (mode_src / "train" / "labels").mkdir(parents=True)
    (mode_src / "data.yaml").write_text("names: [thrips, whitefly, aphids]\nnc: 3\n", encoding="utf-8")

    # Save distinct patterns across RGBA, L, P, CMYK, I;16
    base_patterns = [
        ("rgba.png", "RGBA", (255, 40, 40, 200), (10, 10, 70, 70)),
        ("gray.png", "L", 80, (40, 20, 110, 90)),
        ("palette.png", "P", 3, (15, 60, 95, 115)),
        ("cmyk.jpg", "CMYK", (10, 180, 220, 20), (20, 40, 100, 110)),
    ]
    for fname, mode, fill_val, rect in base_patterns:
        im = Image.new(mode, (128, 128), color=0 if mode in {"L", "P"} else (30, 60, 90, 255)[: len(mode)])
        draw = ImageDraw.Draw(im)
        draw.rectangle(rect, fill=fill_val)
        im.save(mode_src / "train" / "images" / fname)
        (mode_src / "train" / "labels" / f"{Path(fname).stem}.txt").write_text("0 0.5 0.5 0.3 0.3\n", encoding="utf-8")

    arr_16 = np.zeros((128, 128), dtype=np.uint16)
    arr_16[10:60, 60:110] = 50000
    Image.fromarray(arr_16).save(mode_src / "train" / "images" / "u16.png")
    (mode_src / "train" / "labels" / "u16.txt").write_text("1 0.5 0.5 0.3 0.3\n", encoding="utf-8")

    # EXIF Orientation=6 JPEG
    exif_img = Image.new("RGB", (128, 128), color=(90, 20, 170))
    ImageDraw.Draw(exif_img).polygon([(10, 10), (120, 30), (40, 120)], fill=(20, 240, 180))
    exif_obj = exif_img.getexif()
    exif_obj[274] = 6  # Orientation=6
    exif_img.save(mode_src / "train" / "images" / "exif6.jpg", exif=exif_obj)
    (mode_src / "train" / "labels" / "exif6.txt").write_text("2 0.5 0.5 0.3 0.3\n", encoding="utf-8")

    # Truncated/corrupt JPEG
    (mode_src / "train" / "images" / "corrupt.jpg").write_bytes(b"\xff\xd8\xff\xe0truncated_garbage")
    (mode_src / "train" / "labels" / "corrupt.txt").write_text("0 0.5 0.5 0.3 0.3\n", encoding="utf-8")

    details: dict[str, Any] = {}
    records, _ = ml_prep.deduplicate_and_merge_sources([mode_src], source_details_out=details)
    assert details["mode_src"]["unreadable_images_skipped"] == 1
    assert len(records) >= 4

    # _DihedralHashIndex numpy path (threshold > 4)
    np_idx = ml_prep._DihedralHashIndex(threshold=6)
    h0 = (0x0000000000000000,) * 8
    h_near = (0x000000000000001F,) * 8  # Hamming distance 5 <= 6
    h_far = (0xFFFFFFFFFFFFFFFF,) * 8
    np_idx.add(h0)
    assert np_idx.has_match(h_near) is True
    assert np_idx.find_matches(h_near) == [0]
    assert np_idx.has_match(h_far) is False
    assert np_idx.find_matches(h_far) == []

    # G7: download_roboflow_sources edge paths (onboarding=True, constructor error, invalid downloaded dir, cache hit, env_file)
    rf_key = "rf_" + "tier5_test_key_000111"

    class _OnboardingRF:
        def __init__(self, api_key: str) -> None:
            self.onboarding = True

    monkeypatch.delenv("ROBOFLOW_API_KEY", raising=False)
    env_file = tmp_path / "rf.env"
    env_file.write_text(f"ROBOFLOW_API_KEY={rf_key}\n", encoding="utf-8")
    monkeypatch.setitem(sys.modules, "roboflow", SimpleNamespace(Roboflow=_OnboardingRF))
    with pytest.raises(RuntimeError, match="onboarding mode"):
        ml_prep.download_roboflow_sources(tmp_path / "r1", env_file=env_file)

    monkeypatch.delenv("ROBOFLOW_API_KEY", raising=False)

    class _CtorErrRF:
        def __init__(self, api_key: str) -> None:
            raise RuntimeError(f"Auth boom api_key={api_key}")

    monkeypatch.setitem(sys.modules, "roboflow", SimpleNamespace(Roboflow=_CtorErrRF))
    with pytest.raises(RuntimeError) as ctor_exc:
        ml_prep.download_roboflow_sources(tmp_path / "r2", api_key=rf_key)
    assert rf_key not in str(ctor_exc.value)
    assert "[REDACTED]" in str(ctor_exc.value)

    # Empty downloaded directory -> fails required source check
    class _EmptyDownloadRF:
        def __init__(self, api_key: str) -> None:
            self.onboarding = False

        def workspace(self, ws: str) -> Any:
            return SimpleNamespace(
                project=lambda p: SimpleNamespace(
                    version=lambda v: SimpleNamespace(download=lambda fmt, location, overwrite=True: Path(location).mkdir(parents=True, exist_ok=True))
                )
            )

    monkeypatch.setitem(sys.modules, "roboflow", SimpleNamespace(Roboflow=_EmptyDownloadRF))
    with pytest.raises(RuntimeError, match="lacks valid data.yaml"):
        ml_prep.download_roboflow_sources(
            tmp_path / "r3",
            api_key=rf_key,
            sources=[{"workspace": "ws", "project": "p", "version": 1, "required": True}],
        )

    # Cache hit when force_download=False and valid source dir exists
    cache_root = tmp_path / "r_cache"
    cached_src = cache_root / "ws_p_v1"
    (cached_src / "train" / "images").mkdir(parents=True)
    (cached_src / "train" / "labels").mkdir(parents=True)
    _make_rgb_image(cached_src / "train" / "images" / "ok.jpg")
    (cached_src / "train" / "labels" / "ok.txt").write_text("0 0.5 0.5 0.2 0.2\n", encoding="utf-8")
    (cached_src / "data.yaml").write_text("names: [thrips, whitefly, aphids]\nnc: 3\n", encoding="utf-8")

    probe_out: list[dict[str, Any]] = []
    downloaded = ml_prep.download_roboflow_sources(
        cache_root,
        api_key=rf_key,
        sources=[{"workspace": "ws", "project": "p", "version": 1, "required": True}],
        probe_results_out=probe_out,
        force_download=False,
    )
    assert downloaded == [cached_src]
    assert probe_out[0]["status"] == "cached"


# =============================================================================
# 7. TFLite Metadata & Export Precision Edge Cases (G6)
# =============================================================================


def test_t5_export_tflite_metadata_and_precision_edge_cases(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """G6: _add_ultralytics_tflite_metadata idempotency, quantize_int8 override, dir exports, same-file copy."""
    # _add_ultralytics_tflite_metadata embeds metadata.json and is idempotent
    synth_tflite = tmp_path / "synth.tflite"
    synth_tflite.write_bytes(b"\x00\x00\x00\x00TFL3" + b"\x00" * 32)
    ml_export._add_ultralytics_tflite_metadata(synth_tflite, img_size=320)
    ml_export._add_ultralytics_tflite_metadata(synth_tflite, img_size=320)
    with zipfile.ZipFile(synth_tflite, "r") as zf:
        assert zf.namelist().count("metadata.json") == 1
        meta_json = json.loads(zf.read("metadata.json").decode("utf-8"))
        assert meta_json["imgsz"] == [320, 320]

    # Invalid precision -> ValueError; both weights_path and tflite_path None -> ValueError
    with pytest.raises(ValueError, match="Unsupported TFLite export precision"):
        ml_export.export_model_to_flutter_assets(None, tmp_path / "a1", precision="bf16")
    with pytest.raises(ValueError, match="Either weights_path or tflite_path"):
        ml_export.export_model_to_flutter_assets(None, tmp_path / "a2")

    # quantize_int8=True overrides precision="fp16" and selects *_int8.tflite from exported dir
    exp_dir = tmp_path / "exported_saved_model"
    exp_dir.mkdir()
    real_tflite = Path(__file__).resolve().parents[2] / "artifacts" / "yolo11n_lettuce_pests.tflite"
    (exp_dir / "best_float16.tflite").write_bytes(b"FP16_DUMMY")
    (exp_dir / "best_int8.tflite").write_bytes(real_tflite.read_bytes())

    class _FakeDirYOLO:
        def __init__(self, weights: str) -> None:
            pass

        def export(self, **kwargs: Any) -> str:
            return str(exp_dir)

    import ultralytics

    monkeypatch.setattr(ultralytics, "YOLO", _FakeDirYOLO)
    weights_pt = tmp_path / "best.pt"
    weights_pt.write_bytes(b"\x00" * 16)
    assets_int8 = tmp_path / "assets_int8"
    out_int8 = ml_export.export_model_to_flutter_assets(
        weights_pt,
        assets_int8,
        img_size=640,
        quantize_int8=True,
        precision="fp16",
    )
    disk_meta = json.loads((assets_int8 / "model_metadata.json").read_text(encoding="utf-8"))
    assert disk_meta["model_version"].startswith("yolo11n-int8-")
    assert out_int8.is_file()

    # Empty exported directory -> FileNotFoundError
    empty_exp_dir = tmp_path / "empty_exported_dir"
    empty_exp_dir.mkdir()

    class _FakeEmptyDirYOLO:
        def __init__(self, weights: str) -> None:
            pass

        def export(self, **kwargs: Any) -> str:
            return str(empty_exp_dir)

    monkeypatch.setattr(ultralytics, "YOLO", _FakeEmptyDirYOLO)
    with pytest.raises(FileNotFoundError, match="No .tflite file found"):
        ml_export.export_model_to_flutter_assets(weights_pt, tmp_path / "assets_empty")

    # Same-file copy (tflite_path == target_tflite) succeeds without SameFileError
    same_dir = tmp_path / "same_dir"
    same_dir.mkdir()
    target = same_dir / "yolo11n_lettuce_pests.tflite"
    target.write_bytes(real_tflite.read_bytes())
    ml_export.export_model_to_flutter_assets(None, same_dir, tflite_path=target, precision="fp16")
    assert (same_dir / "model_metadata.json").is_file()
