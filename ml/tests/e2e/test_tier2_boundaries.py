from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any

import numpy as np
import pytest
from ai_edge_litert.interpreter import Interpreter

from ml import evaluate as ml_evaluate
from ml.evaluate import PROMOTION_GATES, assert_promotion_ready, compare_baseline_vs_finetuned
from ml.export_tflite import decode_yolov11_output
from ml.prepare_dataset import (
    CANONICAL_CLASSES,
    MIN_BOX_DIMENSION,
    canonicalize_label_name,
    deduplicate_and_merge_sources,
    export_merged_dataset,
    load_source_class_map,
    parse_and_sanitize_yolo_line,
    stratified_split_records,
)
from ml.train import push_kaggle_kernel, write_kaggle_kernel_bundle

try:
    from ml.tests.e2e.test_tier1_features import (
        is_ml_test_path,
        scan_ml_bytes_for_secrets,
        scan_ml_git_diff_for_secrets,
        scan_ml_text_for_secrets,
    )
except ImportError:  # pragma: no cover
    from test_tier1_features import (
        is_ml_test_path,
        scan_ml_bytes_for_secrets,
        scan_ml_git_diff_for_secrets,
        scan_ml_text_for_secrets,
    )


# =============================================================================
# F1 — Dataset Preparation Boundaries (5 tests)
# =============================================================================


def test_f1_t2_corrupt_image_empty_label_malformed_and_degenerate_skipped(
    tmp_path: Path,
    make_yolo_source: Any,
) -> None:
    samples = [
        {"stem": "corrupt_img", "corrupt_image": True, "labels": ["0 0.5 0.5 0.2 0.2"]},
        {"stem": "empty_lbl", "pattern_seed": 1, "labels": []},
        {"stem": "malformed_lbl", "pattern_seed": 2, "labels": ["bad line", "0 abc 0.5 0.2 0.2", "0 0.1 0.2 0.3 0.4 0.5"]},
        {"stem": "degenerate_box", "pattern_seed": 3, "labels": ["0 0.5 0.5 0.0 0.2", "0 0.5 0.5 0.2 -0.1"]},
        {"stem": "valid_one", "pattern_seed": 4, "labels": ["0 0.5 0.5 0.2 0.2"]},
    ]
    src = make_yolo_source(tmp_path / "src", ["thrips", "whitefly", "aphids"], samples)
    records, stats = deduplicate_and_merge_sources([src])
    assert len(records) == 1
    assert stats["total_scanned"] == 5
    assert stats["empty_or_unmapped_skipped"] == 4
    assert stats["boxes_kept"] == 1


def test_f1_t2_min_box_dimension_exact_boundary() -> None:
    assert MIN_BOX_DIMENSION == pytest.approx(0.002)
    src_map = {0: "thrips"}

    # Strictly below MIN_BOX_DIMENSION on width or height -> rejected
    assert parse_and_sanitize_yolo_line("0 0.5 0.5 0.0019 0.1", src_map) is None
    assert parse_and_sanitize_yolo_line("0 0.5 0.5 0.1 0.0019", src_map) is None

    # Strictly above MIN_BOX_DIMENSION -> accepted
    accepted = parse_and_sanitize_yolo_line("0 0.5 0.5 0.0021 0.0021", src_map)
    assert accepted is not None
    assert accepted.w == pytest.approx(0.0021)
    assert accepted.h == pytest.approx(0.0021)


def test_f1_t2_out_of_scope_and_unmapped_classes_excluded() -> None:
    for excluded in ("caterpillar", "slug", "healthy", "background", "", "   "):
        assert canonicalize_label_name(excluded) is None

    src_map = {0: "thrips", 1: "caterpillar"}
    assert parse_and_sanitize_yolo_line("1 0.5 0.5 0.2 0.2", src_map) is None
    assert parse_and_sanitize_yolo_line("99 0.5 0.5 0.2 0.2", src_map) is None


def test_f1_t2_small_class_n2_and_stale_output_dir_overwrite(
    tmp_path: Path,
    make_yolo_source: Any,
) -> None:
    samples = [
        {"stem": "tiny_0", "pattern_seed": 11, "labels": ["0 0.5 0.5 0.2 0.2"]},
        {"stem": "tiny_1", "pattern_seed": 12, "labels": ["0 0.4 0.4 0.2 0.2"]},
    ]
    src = make_yolo_source(tmp_path / "src", ["thrips", "whitefly", "aphids"], samples)
    records, stats = deduplicate_and_merge_sources([src])
    assert len(records) == 2

    splits = stratified_split_records(records, seed=42)
    assert len(splits["train"]) == 2

    out_dir = tmp_path / "stale_out"
    (out_dir / "train" / "images").mkdir(parents=True)
    stale_marker = out_dir / "stale_leftover.txt"
    stale_marker.write_text("stale", encoding="utf-8")

    export_merged_dataset(splits, out_dir, stats)
    assert not stale_marker.exists()
    assert (out_dir / "data.yaml").exists()


def test_f1_t2_empty_source_dir_and_missing_data_yaml_handled_cleanly(tmp_path: Path) -> None:
    empty_dir = tmp_path / "empty_ds"
    empty_dir.mkdir()
    missing_dir = tmp_path / "does_not_exist"

    assert load_source_class_map(empty_dir) == CANONICAL_CLASSES

    records, stats = deduplicate_and_merge_sources([missing_dir, empty_dir])
    assert records == []
    assert stats["total_scanned"] == 0

    try:
        splits = stratified_split_records(records)
        assert all(len(v) == 0 for v in splits.values())
        report = export_merged_dataset(splits, tmp_path / "empty_out", stats)
        assert all(report["splits"][s]["images"] == 0 for s in ("train", "val", "test"))
    except ValueError:
        # Strict M2 behavior may raise ValueError on empty records/splits
        pass


# =============================================================================
# F2 — Kaggle Training Config & Bundle Boundaries (5 tests)
# =============================================================================


def test_f2_t2_push_kaggle_kernel_propagates_missing_cli_and_failure(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError):
        push_kaggle_kernel(tmp_path, kaggle_exe="nonexistent_kaggle_cli_xyz_999")

    failing_cmd = tmp_path / "fake_kaggle.cmd"
    failing_cmd.write_text("@echo mock kaggle failure 1>&2\n@exit /b 1\n", encoding="utf-8")
    with pytest.raises(subprocess.CalledProcessError) as exc_info:
        push_kaggle_kernel(tmp_path, kaggle_exe=str(failing_cmd))
    assert exc_info.value.returncode == 1


def test_f2_t2_write_kaggle_bundle_creates_nested_directories(tmp_path: Path) -> None:
    nested = tmp_path / "deep" / "nested" / "kaggle_dir"
    assert not nested.exists()
    meta_path = write_kaggle_kernel_bundle(nested, "adityadwiferdiansyah")
    assert nested.is_dir()
    assert meta_path == nested / "kernel-metadata.json"
    assert meta_path.exists()


def test_f2_t2_write_kaggle_bundle_none_dataset_sources_writes_empty_list(tmp_path: Path) -> None:
    meta_path = write_kaggle_kernel_bundle(tmp_path / "k", "adityadwiferdiansyah", dataset_sources=None)
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    assert isinstance(meta["dataset_sources"], list)
    assert meta["dataset_sources"] == []


def test_f2_t2_train_cli_invalid_epochs_exits_nonzero(run_cli: Any) -> None:
    proc = run_cli("ml.train", ["--epochs", "not_an_int"], {"ROBOFLOW_API_KEY": None})
    assert proc.returncode == 2
    assert "epochs" in proc.stderr.lower()


def test_f2_t2_overwrite_stale_kaggle_bundle_cleans_old_keys(tmp_path: Path) -> None:
    bundle_dir = tmp_path / "bundle"
    bundle_dir.mkdir()
    meta_file = bundle_dir / "kernel-metadata.json"
    meta_file.write_text(json.dumps({"stale_legacy_field": "old_value", "id": "wrong/old"}), encoding="utf-8")

    write_kaggle_kernel_bundle(
        bundle_dir,
        "adityadwiferdiansyah",
        dataset_sources=["adityadwiferdiansyah/updated-ds"],
    )
    meta = json.loads(meta_file.read_text(encoding="utf-8"))
    assert "stale_legacy_field" not in meta
    assert meta["dataset_sources"] == ["adityadwiferdiansyah/updated-ds"]


# =============================================================================
# F3 — Evaluation & Promotion Gate Boundaries (6 tests)
# =============================================================================


def test_f3_t2_promotion_gates_exact_inclusive_thresholds() -> None:
    exact_pass = {
        "map50": 0.70,
        "recall": 0.65,
        "tflite_map50_drop": 0.015,
        "model_size_mb": 6.0,
    }
    assert_promotion_ready(exact_pass)

    for key, bad_val in [
        ("map50", 0.6999),
        ("recall", 0.6499),
        ("tflite_map50_drop", 0.0151),
        ("model_size_mb", 6.001),
    ]:
        with pytest.raises(ValueError, match="failed promotion gates"):
            assert_promotion_ready({**exact_pass, key: bad_val})


def test_f3_t2_assert_promotion_ready_missing_keys_raise_value_error() -> None:
    with pytest.raises(ValueError, match="missing required gates"):
        assert_promotion_ready({})

    complete = {"map50": 0.80, "recall": 0.75, "tflite_map50_drop": 0.005, "model_size_mb": 4.5}
    for missing_key in PROMOTION_GATES:
        partial = {k: v for k, v in complete.items() if k != missing_key}
        with pytest.raises(ValueError, match=missing_key):
            assert_promotion_ready(partial)


@pytest.mark.parametrize(
    ("gate_name", "bad_value"),
    [
        ("map50", 0.55),
        ("recall", 0.40),
        ("tflite_map50_drop", 0.05),
        ("model_size_mb", 10.121),
    ],
)
def test_f3_t2_assert_promotion_ready_rejects_each_failing_gate(gate_name: str, bad_value: float) -> None:
    valid = {"map50": 0.85, "recall": 0.80, "tflite_map50_drop": 0.004, "model_size_mb": 4.0}
    with pytest.raises(ValueError, match=gate_name):
        assert_promotion_ready({**valid, gate_name: bad_value})


def test_f3_t2_compare_baseline_non_improvement_and_ties() -> None:
    base = {"map50": 0.60, "map50_95": 0.40, "precision": 0.65, "recall": 0.60}

    tie = compare_baseline_vs_finetuned(base, dict(base))
    assert tie["beats_baseline"] is False

    lower_map = compare_baseline_vs_finetuned(base, {**base, "map50": 0.59, "recall": 0.70})
    assert lower_map["beats_baseline"] is False

    lower_recall = compare_baseline_vs_finetuned(base, {**base, "map50": 0.75, "recall": 0.59})
    assert lower_recall["beats_baseline"] is False


def test_f3_t2_evaluate_cli_leaves_output_unwritten_on_gate_failure(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    import sys

    weights = tmp_path / "weak.pt"
    weights.write_bytes(b"\x00" * (2 * 1024 * 1024))
    out_json = tmp_path / "should_not_exist.json"

    monkeypatch.setattr(
        ml_evaluate,
        "evaluate_ultralytics_model",
        lambda path, data_yaml, imgsz=640: {"map50": 0.50, "map50_95": 0.30, "precision": 0.55, "recall": 0.50, "f1": 0.52},
    )
    monkeypatch.setattr(
        sys,
        "argv",
        ["ml.evaluate", "--baseline", str(tmp_path / "b.pt"), "--weights", str(weights), "--output", str(out_json)],
    )
    with pytest.raises(ValueError, match="failed promotion gates"):
        ml_evaluate.main()
    assert not out_json.exists()


def test_f3_t2_evaluate_cli_clamps_negative_tflite_drop_to_zero(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    import sys

    weights = tmp_path / "best.pt"
    weights.write_bytes(b"\x00" * (3 * 1024 * 1024))
    tflite = tmp_path / "model.tflite"
    tflite.write_bytes(b"\x00" * (3 * 1024 * 1024))
    out_json = tmp_path / "eval_clamped.json"

    def _fake_eval(path: Path, data_yaml: Path, imgsz: int = 640) -> dict[str, Any]:
        if path.suffix == ".tflite":
            return {"map50": 0.85, "map50_95": 0.58, "precision": 0.86, "recall": 0.80, "f1": 0.829}
        if "best" in path.name:
            return {"map50": 0.82, "map50_95": 0.56, "precision": 0.84, "recall": 0.79, "f1": 0.814}
        return {"map50": 0.20, "map50_95": 0.10, "precision": 0.25, "recall": 0.20, "f1": 0.222}

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
    assert report["gates"]["tflite_map50_drop"] == 0.0


# =============================================================================
# F4 — LiteRT Decoder & Interpreter Boundaries (6 tests)
# =============================================================================


def test_f4_t2_decode_yolov11_empty_malformed_and_conf_threshold_boundary() -> None:
    assert decode_yolov11_output([]) == []
    assert decode_yolov11_output([[]]) == []
    assert decode_yolov11_output([[0.5, 0.5, 0.1]]) == []

    # 0.3499 rejected, exact 0.35 kept
    anchors = [
        [0.5, 0.5, 0.2, 0.2, 0.3499, 0.1, 0.1],
        [0.2, 0.2, 0.2, 0.2, 0.1, 0.35, 0.1],
    ]
    dets = decode_yolov11_output(anchors, conf_threshold=0.35, iou_threshold=0.45)
    assert len(dets) == 1
    assert dets[0]["class_id"] == 1
    assert dets[0]["confidence"] == pytest.approx(0.35)


def test_f4_t2_decode_yolov11_oob_clamping_and_zero_area_rejection() -> None:
    anchors = [
        [1.02, 0.5, 0.2, 0.2, 0.8, 0.1, 0.1],  # partially OOB -> clamped to x2=1.0
        [1.5, 1.5, 0.1, 0.1, 0.9, 0.1, 0.1],   # completely OOB -> zero area -> rejected
        [0.5, 0.5, 0.0, 0.2, 0.9, 0.1, 0.1],   # zero width -> rejected
    ]
    dets = decode_yolov11_output(anchors, conf_threshold=0.35, iou_threshold=0.45)
    assert len(dets) == 1
    x1, y1, x2, y2 = dets[0]["box"]
    assert 0.0 <= x1 < x2 <= 1.0
    assert x2 == pytest.approx(1.0)


def test_f4_t2_decode_yolov11_exact_iou_boundary() -> None:
    # Box A: [0.0, 0.0, 0.5, 0.2] (area 0.10)
    # Box B: [0.0, 0.0, 0.225, 0.2] (area 0.045) -> IoU = 0.045 / 0.10 = 0.45 (kept: <= 0.45)
    at_boundary = [
        [0.25, 0.1, 0.5, 0.2, 0.90, 0.01, 0.01],
        [0.1125, 0.1, 0.225, 0.2, 0.80, 0.01, 0.01],
    ]
    assert len(decode_yolov11_output(at_boundary, conf_threshold=0.35, iou_threshold=0.45)) == 2

    # Box C: [0.0, 0.0, 0.23, 0.2] (area 0.046) -> IoU = 0.046 / 0.10 = 0.46 > 0.45 -> suppressed
    above_boundary = [
        [0.25, 0.1, 0.5, 0.2, 0.90, 0.01, 0.01],
        [0.115, 0.1, 0.23, 0.2, 0.80, 0.01, 0.01],
    ]
    kept = decode_yolov11_output(above_boundary, conf_threshold=0.35, iou_threshold=0.45)
    assert len(kept) == 1
    assert kept[0]["confidence"] == pytest.approx(0.90)


def test_f4_t2_litert_interpreter_rejects_wrong_shape_layout_and_uint8_dtype(ml_root: Path) -> None:
    tflite_path = ml_root / "artifacts" / "yolo11n_lettuce_pests.tflite"
    interp = Interpreter(model_path=str(tflite_path))
    interp.allocate_tensors()
    in_detail = interp.get_input_details()[0]
    shape = [int(x) for x in in_detail["shape"]]

    # 1. Wrong spatial size
    with pytest.raises(ValueError):
        interp.set_tensor(in_detail["index"], np.zeros((1, 3, 128, 128), dtype=np.float32))

    # 2. Swapped NCHW <-> NHWC layout
    swapped = (shape[0], shape[2], shape[3], shape[1]) if shape[1] == 3 else (shape[0], shape[3], shape[1], shape[2])
    with pytest.raises(ValueError):
        interp.set_tensor(in_detail["index"], np.zeros(swapped, dtype=np.float32))

    # 3. Wrong dtype (uint8 instead of float32)
    with pytest.raises(ValueError):
        interp.set_tensor(in_detail["index"], np.zeros(tuple(shape), dtype=np.uint8))


def test_f4_t2_litert_interpreter_rejects_missing_or_corrupt_flatbuffer(tmp_path: Path) -> None:
    missing = tmp_path / "missing_model.tflite"
    with pytest.raises((ValueError, RuntimeError)):
        Interpreter(model_path=str(missing))

    corrupt = tmp_path / "corrupt.tflite"
    corrupt.write_bytes(b"NOT_A_VALID_TFLITE_FLATBUFFER_BYTES")
    with pytest.raises((ValueError, RuntimeError)):
        interp = Interpreter(model_path=str(corrupt))
        interp.allocate_tensors()


def test_f4_t2_decode_yolov11_single_anchor_and_2100_8400_layouts() -> None:
    # Single anchor [7, 1] and [1, 7]
    single_cf = [[0.5], [0.5], [0.2], [0.2], [0.80], [0.05], [0.05]]
    single_cl = [[0.5, 0.5, 0.2, 0.2, 0.80, 0.05, 0.05]]
    assert len(decode_yolov11_output(single_cf)) == 1
    assert len(decode_yolov11_output(single_cl)) == 1

    # Full anchor grids [7, 2100] and [7, 8400]
    for n_anchors in (2100, 8400):
        grid = np.zeros((7, n_anchors), dtype=np.float32)
        grid[0, 5] = 0.5
        grid[1, 5] = 0.5
        grid[2, 5] = 0.2
        grid[3, 5] = 0.2
        grid[6, 5] = 0.91  # aphids
        dets = decode_yolov11_output(grid.tolist(), img_size=640)
        assert len(dets) == 1
        assert dets[0]["class_name"] == "aphids"


# =============================================================================
# F5 — Scope & Security Scanner Boundaries (5 tests)
# =============================================================================


def test_f5_t2_secret_scanner_catches_synthetic_tokens(secret_scanner: Any) -> None:
    kaggle_leak = "token = 'KGAT_" + "0123456789abcdef0123456789abcdef'"
    rf_assign = "ROBOFLOW_API_" + 'KEY="fake_token_1234567890"'
    rf_prefix = "key = 'rf_" + "abcdefghijklmno'"
    rf_underscores = "key = 'rf_" + "abc_def_1234567890'"
    rf_hyphens = "key = 'rf_" + "abc-def-1234567890'"
    unquoted_rf = "ROBOFLOW_API_" + "KEY=my_plain_secret_value_12345"
    unquoted_kg = "KAGGLE_" + "KEY=abcd1234efgh5678ijkl"
    unquoted_kg_tok = "KAGGLE_API_" + "TOKEN=plain_kaggle_token_123"
    quoted_b64 = "ROBOFLOW_API_" + 'KEY="abc+def/' + '12345=="'
    unquoted_b64 = "ROBOFLOW_API_" + "KEY=abc+def/" + "12345=="
    yaml_unquoted = "ROBOFLOW_API_" + "KEY: my_plain_secret_" + "value_12345"
    export_alpha = "export ROBOFLOW_API_" + "KEY=plain_alpha_only_" + "secret"
    assert len(secret_scanner(kaggle_leak)) >= 1
    assert len(secret_scanner(rf_assign)) >= 1
    assert len(secret_scanner(rf_prefix)) >= 1
    assert len(secret_scanner(rf_underscores)) >= 1
    assert len(secret_scanner(rf_hyphens)) >= 1
    assert len(secret_scanner(unquoted_rf)) >= 1
    assert len(secret_scanner(unquoted_kg)) >= 1
    assert len(secret_scanner(unquoted_kg_tok)) >= 1
    assert len(secret_scanner(quoted_b64)) >= 1
    assert len(secret_scanner(unquoted_b64)) >= 1
    assert len(secret_scanner(yaml_unquoted)) >= 1
    assert len(secret_scanner(export_alpha)) >= 1


def test_f5_t2_secret_scanner_ignores_env_lookups_and_sha256(secret_scanner: Any) -> None:
    safe_text = """
    api_key = os.environ.get("ROBOFLOW_API_KEY")
    kaggle_key = os.getenv("KAGGLE_KEY")
    download_roboflow_sources(raw_root, api_key=secret_key)
    download_roboflow_sources(raw_root, api_key=roboflow_key)
    download_roboflow_sources(raw_root, api_key=resolved_api_key)
    ROBOFLOW_API_KEY = get_roboflow_api_key()
    KAGGLE_KEY = load_kaggle_key()
    api_key: CustomSecretType
    api_key = None
    # Credentials live outside repo in ~/.kaggle/access_token
    sha256: a65a43cf450097e4417e5c59ab0e4e71c17906e0fbd580bb2639175ed368d963
    """
    assert secret_scanner(safe_text) == []


def test_f5_t2_scope_validator_rejects_apps_and_root_gitignore_in_isolated_repo(
    tmp_path: Path,
    ml_only_path_validator: Any,
) -> None:
    repo = tmp_path / "isolated_repo"
    repo.mkdir()
    (repo / "ml").mkdir()
    (repo / "apps" / "backend").mkdir(parents=True)

    def _git(*args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True, check=True)

    _git("init", "-b", "main")
    _git("config", "user.email", "test@example.com")
    _git("config", "user.name", "Test User")
    (repo / ".gitignore").write_text("*.log\n", encoding="utf-8")
    (repo / "ml" / "init.py").write_text("# init\n", encoding="utf-8")
    _git("add", ".")
    _git("commit", "-m", "chore: baseline")

    _git("checkout", "-b", "feature/test")
    (repo / "ml" / "ok.py").write_text("x = 1\n", encoding="utf-8")
    (repo / "apps" / "backend" / "bad.ts").write_text("export const x = 1;\n", encoding="utf-8")
    (repo / ".gitignore").write_text("*.log\nml/runs/\n", encoding="utf-8")
    _git("add", ".")
    _git("commit", "-m", "test: mixed paths")

    diff_out = _git("diff", "--name-only", "main", "HEAD").stdout
    changed = [line.strip() for line in diff_out.splitlines() if line.strip()]
    violations = ml_only_path_validator(changed)
    assert set(violations) == {".gitignore", "apps/backend/bad.ts"}


@pytest.mark.parametrize(
    "ignored_path",
    [
        "ml/.env.local",
        "ml/.env.test",
        "ml/kaggle_remote_output/run.log",
        "ml/dataset/raw/x",
    ],
)
def test_f5_t2_ml_gitignore_catches_env_variants_and_remote_outputs(repo_root: Path, ignored_path: str) -> None:
    proc = subprocess.run(
        ["git", "check-ignore", "--no-index", ignored_path],
        cwd=repo_root,
        capture_output=True,
        text=True,
        check=False,
    )
    assert proc.returncode == 0, f"Expected {ignored_path} to be ignored"


def test_f5_t2_secret_scanner_handles_binary_and_non_utf8_bytes(bytes_secret_scanner: Any) -> None:
    raw = b"\xff\xfe\x00TFL3\x80\x99\xaa\xbb" + b"\x00" * 64
    assert bytes_secret_scanner(raw) == []


def test_f5_t2_ml_test_placeholder_filter_boundaries(
    secret_scanner: Any,
    bytes_secret_scanner: Any,
) -> None:
    assert is_ml_test_path("ml/tests/foo.py") is True
    assert is_ml_test_path("ml\\tests\\e2e\\bar.py") is True
    assert is_ml_test_path("./ml/tests/foo.py") is True
    assert is_ml_test_path("ml/tests/.env") is False
    assert is_ml_test_path("ml/tests/secrets.env") is False
    assert is_ml_test_path("ml/tests/data.txt") is False
    assert is_ml_test_path("ml/train.py") is False
    assert is_ml_test_path("ml/tests_fake/foo.py") is False
    assert is_ml_test_path("ml/tests/../train.py") is False
    assert is_ml_test_path("apps/ml/tests/foo.py") is False

    real_rf = "rf_" + "AbCdEfGhIjKlMnOpQrSt"
    real_kg = "KGAT_" + "0123456789abcdef0123456789abcdef"
    real_assign = "ROBOFLOW_API_KEY=" + '"real_9xK2AbCdEfGh"'
    disguised_var = f'dummy_key = "{real_rf}"'
    disguised_comment = f"{real_assign}  # example"
    disguised_rf_dummy = "ROBOFLOW_API_KEY=" + "'rf_" + "dummy_REAL9876543210'"
    disguised_rf_test_key = "key = 'rf_" + "test_key_LIVE9876543210'"
    disguised_kg_example = "tok = 'KGAT_" + "012345example0123456789abcdef'"
    disguised_fake_assign = "ROBOFLOW_API_KEY=" + "'fake_" + "LiveProdSecret98765'"
    disguised_sentinel_assign = "API_KEY=" + "'sentinel_" + "LiveProdSecret98765'"
    disguised_unquoted_dummy = "ROBOFLOW_API_KEY=" + "dummy_LiveProdSecret98765"

    # Real or placeholder-disguised tokens MUST fail even inside ml/tests/*.py
    for bad_line in (
        real_rf,
        real_kg,
        real_assign,
        disguised_var,
        disguised_comment,
        disguised_rf_dummy,
        disguised_rf_test_key,
        disguised_kg_example,
        disguised_fake_assign,
        disguised_sentinel_assign,
        disguised_unquoted_dummy,
    ):
        assert scan_ml_text_for_secrets("ml/tests/foo.py", bad_line, secret_scanner) != []
        assert scan_ml_bytes_for_secrets("ml/tests/foo.py", bad_line.encode("utf-8"), bytes_secret_scanner) != []

    quoted_placeholder = "export ROBOFLOW_API_KEY=" + "'quoted_secret_123'"
    test_key_placeholder = 'secret_key = "rf_' + 'super_secret_test_key_999"'
    required_placeholder = 'secret_key = "rf_' + 'required_secret_abc"'

    # Only exact legacy test fixture strings are allowed strictly inside ml/tests/*.py
    for ok_line in (quoted_placeholder, test_key_placeholder, required_placeholder):
        assert scan_ml_text_for_secrets("ml/tests/foo.py", ok_line, secret_scanner) == []
        assert scan_ml_bytes_for_secrets("ml/tests/foo.py", ok_line.encode("utf-8"), bytes_secret_scanner) == []

    # Outside ml/tests/*.py (including ml/tests/.env, traversal & sibling dirs), zero-tolerance rejects legacy fixtures too
    for non_test_path in (
        "ml/tests/.env",
        "ml/tests/secrets.env",
        "ml/train.py",
        "ml/reports/audit_report.md",
        "ml/tests/../train.py",
        "ml/tests_fake/foo.py",
    ):
        for placeholder_line in (quoted_placeholder, test_key_placeholder, disguised_fake_assign):
            assert scan_ml_text_for_secrets(non_test_path, placeholder_line, secret_scanner) != []
            assert (
                scan_ml_bytes_for_secrets(non_test_path, placeholder_line.encode("utf-8"), bytes_secret_scanner) != []
            )


def test_f5_t2_ml_git_diff_secret_scanner_section_boundaries(
    secret_scanner: Any,
    bytes_secret_scanner: Any,
) -> None:
    quoted_placeholder = "export ROBOFLOW_API_KEY=" + "'quoted_secret_123'"
    test_key_placeholder = 'secret_key = "rf_' + 'super_secret_test_key_999"'
    real_rf = "rf_" + "AbCdEfGhIjKlMnOpQrSt"
    real_kg = "KGAT_" + "0123456789abcdef0123456789abcdef"
    disguised_rf_dummy = "ROBOFLOW_API_KEY=" + "'rf_" + "dummy_REAL9876543210'"

    clean_diff = "\n".join(
        [
            "commit 1111111111111111111111111111111111111111",
            "diff --git a/ml/train.py b/ml/train.py",
            "--- a/ml/train.py",
            "+++ b/ml/train.py",
            "@@ -1,1 +1,2 @@",
            "+epochs = 80",
            "diff --git a/ml/tests/test_dataset_pipeline.py b/ml/tests/test_dataset_pipeline.py",
            "--- /dev/null",
            "+++ b/ml/tests/test_dataset_pipeline.py",
            "@@ -0,0 +1,2 @@",
            f"+{quoted_placeholder}",
            f"+{test_key_placeholder}",
        ]
    )
    assert scan_ml_git_diff_for_secrets(clean_diff, bytes_secret_scanner, secret_scanner) == []

    real_in_test_diff = "\n".join(
        [
            "diff --git a/ml/tests/foo.py b/ml/tests/foo.py",
            "--- /dev/null",
            "+++ b/ml/tests/foo.py",
            "@@ -0,0 +1,2 @@",
            f"+token = '{real_rf}'",
            f"+kaggle = '{real_kg}'",
        ]
    )
    assert len(scan_ml_git_diff_for_secrets(real_in_test_diff, bytes_secret_scanner, secret_scanner)) == 2

    disguised_in_test_diff = "\n".join(
        [
            "diff --git a/ml/tests/test_dataset_pipeline.py b/ml/tests/test_dataset_pipeline.py",
            "@@ -0,0 +1,1 @@",
            f"+{disguised_rf_dummy}",
        ]
    )
    assert scan_ml_git_diff_for_secrets(disguised_in_test_diff, bytes_secret_scanner, secret_scanner) != []

    non_py_test_env_diff = "\n".join(
        [
            "diff --git a/ml/tests/.env b/ml/tests/.env",
            "@@ -0,0 +1,1 @@",
            f"+{quoted_placeholder}",
        ]
    )
    assert scan_ml_git_diff_for_secrets(non_py_test_env_diff, bytes_secret_scanner, secret_scanner) != []

    placeholder_in_train_diff = "\n".join(
        [
            "diff --git a/ml/tests/foo.py b/ml/tests/foo.py",
            "@@ -0,0 +1,1 @@",
            f"+{quoted_placeholder}",
            "diff --git a/ml/train.py b/ml/train.py",
            "@@ -0,0 +1,2 @@",
            f"+{quoted_placeholder}",
            f"+{test_key_placeholder}",
        ]
    )
    assert scan_ml_git_diff_for_secrets(placeholder_in_train_diff, bytes_secret_scanner, secret_scanner) != []

    space_header_after_test_diff = "\n".join(
        [
            "diff --git a/ml/tests/foo.py b/ml/tests/foo.py",
            "@@ -0,0 +1,1 @@",
            f"+{quoted_placeholder}",
            "diff --git a/ml/my file.py b/ml/my file.py",
            "@@ -0,0 +1,1 @@",
            f"+{quoted_placeholder}",
        ]
    )
    assert scan_ml_git_diff_for_secrets(space_header_after_test_diff, bytes_secret_scanner, secret_scanner) != []

    merge_cc_after_test_diff = "\n".join(
        [
            "diff --git a/ml/tests/foo.py b/ml/tests/foo.py",
            "@@ -0,0 +1,1 @@",
            f"+{quoted_placeholder}",
            "diff --cc ml/train.py",
            "@@ -0,0 +1,1 @@",
            f"++{test_key_placeholder}",
        ]
    )
    assert scan_ml_git_diff_for_secrets(merge_cc_after_test_diff, bytes_secret_scanner, secret_scanner) != []

    secret_in_next_commit_header = "\n".join(
        [
            "commit 1111111111111111111111111111111111111111",
            "diff --git a/ml/tests/foo.py b/ml/tests/foo.py",
            "@@ -0,0 +1,1 @@",
            f"+{quoted_placeholder}",
            "commit 2222222222222222222222222222222222222222",
            "Author: Test <test@example.com>",
            f"    chore: accidental {test_key_placeholder}",
        ]
    )
    assert scan_ml_git_diff_for_secrets(secret_in_next_commit_header, bytes_secret_scanner, secret_scanner) != []

    renamed_from_non_test_diff = "\n".join(
        [
            "diff --git a/ml/train.py b/ml/tests/moved.py",
            "@@ -0,0 +1,1 @@",
            f"+{test_key_placeholder}",
        ]
    )
    assert scan_ml_git_diff_for_secrets(renamed_from_non_test_diff, bytes_secret_scanner, secret_scanner) != []
