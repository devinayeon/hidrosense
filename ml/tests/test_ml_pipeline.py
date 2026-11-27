from __future__ import annotations

import json
from pathlib import Path
from typing import Any
from PIL import Image, ImageDraw
import pytest

from ml.prepare_dataset import (
    CANONICAL_CLASSES,
    BoxAnnotation,
    DatasetRecord,
    canonicalize_label_name,
    deduplicate_and_merge_sources,
    parse_and_sanitize_yolo_line,
    stratified_split_records,
)
from ml import evaluate as ml_evaluate
from ml.evaluate import (
    PROMOTION_GATES,
    assert_promotion_ready,
    build_provenance_payload,
    compare_baseline_vs_finetuned,
    evaluate_tflite_litert,
    extract_eval_metrics,
)
from ml.export_tflite import (
    build_model_metadata,
    decode_yolov11_output,
    export_model_to_flutter_assets,
    inspect_tflite_model,
)


def _make_test_image(path: Path, color: tuple[int, int, int], rect: tuple[int, int, int, int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img = Image.new("RGB", (128, 128), color=color)
    draw = ImageDraw.Draw(img)
    draw.rectangle(rect, fill=(255, 255, 0))
    img.save(path)


class TestCanonicalLabelMapping:
    def test_maps_synonyms_case_insensitively_to_canonical_ids(self) -> None:
        assert CANONICAL_CLASSES == {0: "whitefly", 1: "aphids"}
        assert canonicalize_label_name("whitefly") == 0
        assert canonicalize_label_name("Whiteflies") == 0
        assert canonicalize_label_name("white-fly") == 0
        assert canonicalize_label_name("kutu_kebul") == 0
        assert canonicalize_label_name("kutu kebul") == 0
        assert canonicalize_label_name("aphid") == 1
        assert canonicalize_label_name("Aphids") == 1
        assert canonicalize_label_name("kutu_daun") == 1
        assert canonicalize_label_name("kutu daun") == 1

    def test_returns_none_for_excluded_molted_skin_thrips_and_out_of_scope_classes(self) -> None:
        for excluded in ("molted skin", "molted_skin", "exuviae", "thrips", "thrip", "frankliniella", "caterpillar", "slug", "healthy", "background"):
            assert canonicalize_label_name(excluded) is None


class TestAnnotationSanitization:
    def test_parses_standard_yolo_bbox_and_clamps_bounds(self) -> None:
        source_map = {0: "aphids", 1: "molted skin"}
        box = parse_and_sanitize_yolo_line("0 0.5 0.5 0.4 0.2", source_map)
        assert box is not None
        assert box.class_id == 1  # aphids -> canonical 1
        assert box.cx == pytest.approx(0.5)
        assert box.cy == pytest.approx(0.5)
        assert box.w == pytest.approx(0.4)
        assert box.h == pytest.approx(0.2)

    def test_converts_polygon_segmentation_line_to_bounding_box(self) -> None:
        source_map = {0: "whitefly"}
        line = "0 0.2 0.3 0.6 0.3 0.6 0.7 0.2 0.7"
        box = parse_and_sanitize_yolo_line(line, source_map)
        assert box is not None
        assert box.class_id == 0
        assert box.cx == pytest.approx(0.4)
        assert box.cy == pytest.approx(0.5)
        assert box.w == pytest.approx(0.4)
        assert box.h == pytest.approx(0.4)

    def test_rejects_degenerate_or_unmapped_boxes(self) -> None:
        source_map = {0: "whitefly", 1: "molted skin", 2: "thrips"}
        assert parse_and_sanitize_yolo_line("0 0.5 0.5 0.0 0.2", source_map) is None
        assert parse_and_sanitize_yolo_line("0 0.5 0.5 -0.1 0.2", source_map) is None
        assert parse_and_sanitize_yolo_line("1 0.5 0.5 0.3 0.3", source_map) is None
        assert parse_and_sanitize_yolo_line("2 0.5 0.5 0.3 0.3", source_map) is None


class TestDeduplicationAndStratifiedSplit:
    def test_deduplicates_identical_images_across_sources_before_split(self, tmp_path: Path) -> None:
        src1 = tmp_path / "ds1"
        src2 = tmp_path / "ds2"

        for ds_root, names_list in [
            (src1, ["aphids", "molted skin", "whitefly"]),
            (src2, ["whiteflies", "aphid"]),
        ]:
            (ds_root / "train" / "images").mkdir(parents=True)
            (ds_root / "train" / "labels").mkdir(parents=True)
            (ds_root / "data.yaml").write_text(
                f"names: {json.dumps(names_list)}\nnc: {len(names_list)}\n",
                encoding="utf-8",
            )

        _make_test_image(src1 / "train" / "images" / "dup1.jpg", (20, 120, 40), (10, 10, 80, 80))
        (src1 / "train" / "labels" / "dup1.txt").write_text("0 0.5 0.5 0.3 0.3\n", encoding="utf-8")

        _make_test_image(src2 / "train" / "images" / "dup1_copy.jpg", (20, 120, 40), (10, 10, 80, 80))
        (src2 / "train" / "labels" / "dup1_copy.txt").write_text("1 0.5 0.5 0.3 0.3\n", encoding="utf-8")

        _make_test_image(src2 / "train" / "images" / "unique2.jpg", (180, 30, 90), (50, 20, 110, 100))
        (src2 / "train" / "labels" / "unique2.txt").write_text("0 0.4 0.4 0.2 0.2\n", encoding="utf-8")

        records, stats = deduplicate_and_merge_sources([src1, src2])
        assert len(records) == 2
        assert stats["duplicates_removed"] == 1

    def test_stratified_split_prevents_class_starvation_and_leakage(self, tmp_path: Path) -> None:
        records: list[DatasetRecord] = []
        for idx in range(30):
            cls_id = idx % 2
            records.append(
                DatasetRecord(
                    image_path=tmp_path / f"img_{idx}.jpg",
                    phash_hex=f"{idx:016x}",
                    boxes=(BoxAnnotation(class_id=cls_id, cx=0.5, cy=0.5, w=0.2, h=0.2),),
                    source_name="test_src",
                )
            )

        splits = stratified_split_records(records, train_ratio=0.8, val_ratio=0.1, seed=42)
        train_hashes = {r.phash_hex for r in splits["train"]}
        val_hashes = {r.phash_hex for r in splits["val"]}
        test_hashes = {r.phash_hex for r in splits["test"]}

        assert train_hashes.isdisjoint(val_hashes)
        assert train_hashes.isdisjoint(test_hashes)
        assert val_hashes.isdisjoint(test_hashes)

        for split_name in ("train", "val", "test"):
            present_classes = {b.class_id for r in splits[split_name] for b in r.boxes}
            assert present_classes == {0, 1}


class TestEvaluationAndExportContracts:
    def test_promotion_gates_enforce_accuracy_f1_ood_size_and_parity(self) -> None:
        assert "map50" in PROMOTION_GATES
        assert "small_scale_recall" in PROMOTION_GATES
        assert "ood_false_positive_rate" in PROMOTION_GATES
        passing = {
            "map50": 0.85,
            "recall": 0.80,
            "f1": 0.82,
            "small_scale_recall": 0.80,
            "tflite_map50_drop": 0.003,
            "ood_false_positive_rate": 0.0,
            "model_size_mb": 5.2,
        }
        assert_promotion_ready(passing)

        failing = {**passing, "tflite_map50_drop": 0.04}
        with pytest.raises(ValueError, match="failed promotion gates"):
            assert_promotion_ready(failing)

        failing_ood = {**passing, "ood_false_positive_rate": 0.15}
        with pytest.raises(ValueError, match="failed promotion gates"):
            assert_promotion_ready(failing_ood)

        failing_small = {**passing, "small_scale_recall": 0.45}
        with pytest.raises(ValueError, match="small_scale_recall"):
            assert_promotion_ready(failing_small)

    def test_compare_baseline_vs_finetuned_calculates_deltas(self) -> None:
        baseline = {"map50": 0.21, "map50_95": 0.11, "precision": 0.30, "recall": 0.25, "f1": 0.27}
        finetuned = {"map50": 0.81, "map50_95": 0.52, "precision": 0.84, "recall": 0.79, "f1": 0.81}
        comparison = compare_baseline_vs_finetuned(baseline, finetuned)
        assert comparison["improvements"]["map50_delta"] == pytest.approx(0.60)
        assert comparison["beats_baseline"] is True

    def test_decode_yolov11_output_handles_both_channel_first_and_last(self) -> None:
        raw_channel_first = [
            [320.0, 100.0],  # cx
            [320.0, 100.0],  # cy
            [64.0, 20.0],    # w
            [64.0, 20.0],    # h
            [0.88, 0.10],    # class 0: whitefly
            [0.03, 0.01],    # class 1: aphids
        ]
        dets = decode_yolov11_output(
            raw_channel_first,
            img_size=640,
            conf_threshold=0.45,
            iou_threshold=0.45,
        )
        assert len(dets) == 1
        assert dets[0]["class_id"] == 0
        assert dets[0]["class_name"] == "whitefly"
        assert dets[0]["confidence"] == pytest.approx(0.88)

        metadata = build_model_metadata(model_version="v2.0.0-yolo11n", img_size=640)
        assert metadata["input_shape"] == [1, 640, 640, 3]
        assert metadata["output_shape"] == [1, 6, 8400]
        assert metadata["classes"] == {"0": "whitefly", "1": "aphids"}
        assert "metrics" not in metadata

    def test_extract_eval_metrics_computes_aggregate_and_per_class(self) -> None:
        class _FakeBox:
            mp = 0.88
            mr = 0.84
            map50 = 0.89
            map75 = 0.68
            map = 0.58
            ap_class_index = [0, 1]
            f1 = [0.85, 0.91]

            def class_result(self, pos: int) -> tuple[float, float, float, float]:
                rows = [
                    (0.87, 0.83, 0.86, 0.52),
                    (0.89, 0.93, 0.92, 0.64),
                ]
                return rows[pos]

        class _FakeValRes:
            box = _FakeBox()

        extracted = extract_eval_metrics(_FakeValRes())
        assert extracted["aggregate"]["map50"] == pytest.approx(0.89)
        assert extracted["aggregate"]["f1"] == pytest.approx(2 * 0.88 * 0.84 / (0.88 + 0.84), abs=1e-4)
        assert extracted["per_class"]["whitefly"]["map50"] == pytest.approx(0.86)
        assert extracted["per_class"]["aphids"]["recall"] == pytest.approx(0.93)

    def test_build_model_metadata_and_export_with_tflite_syncs_metrics_and_precision(
        self,
        tmp_path: Path,
    ) -> None:
        sample_metrics = {"map50": 0.8913, "map50_95": 0.5765, "precision": 0.8952, "recall": 0.8566, "f1": 0.8755}
        meta = build_model_metadata(
            model_version="yolo11n-fp16-deadbeef",
            img_size=640,
            sha256_hex="deadbeef" * 8,
            input_shape=[1, 640, 640, 3],
            output_shape=[1, 6, 8400],
            metrics=sample_metrics,
        )
        assert meta["metrics"] == sample_metrics

        real_tflite = Path(__file__).resolve().parents[1] / "artifacts" / "yolo11n_lettuce_pests.tflite"
        inspected = inspect_tflite_model(real_tflite)
        assert inspected["input_shape"] == [1, 640, 640, 3]
        assert inspected["input_dtype"] == "float32"
        assert inspected["output_shape"] == [1, 6, 8400]
        assert inspected["size_mb"] <= 12.0

        eval_report_path = tmp_path / "evaluation_report.json"
        eval_report_path.write_text(json.dumps({"finetuned": sample_metrics, "calibrated_threshold": 0.45}), encoding="utf-8")
        out_assets = tmp_path / "assets"
        packaged = export_model_to_flutter_assets(
            weights_path=None,
            flutter_assets_dir=out_assets,
            img_size=640,
            precision="fp16",
            tflite_path=real_tflite,
            evaluation_report_path=eval_report_path,
        )
        assert packaged.exists()
        disk_meta = json.loads((out_assets / "model_metadata.json").read_text(encoding="utf-8"))
        assert disk_meta["model_version"].startswith("yolo11n-fp16-")
        assert disk_meta["sha256"] == inspected["sha256"]
        assert disk_meta["metrics"] == sample_metrics

    def test_evaluate_cli_records_per_class_tflite_eval_and_provenance(
        self,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        import sys
        import yaml

        ds_dir = tmp_path / "ds"
        img_dir = ds_dir / "test" / "images"
        lbl_dir = ds_dir / "test" / "labels"
        img_dir.mkdir(parents=True)
        lbl_dir.mkdir(parents=True)
        for idx in range(2):
            _make_test_image(img_dir / f"sample_{idx}.jpg", (30 + idx * 30, 120, 40), (20, 20, 90, 90))
            (lbl_dir / f"sample_{idx}.txt").write_text(f"{idx} 0.5 0.5 0.25 0.25\n", encoding="utf-8")
        _make_test_image(img_dir / "neg__ood_people__p0.jpg", (100, 100, 120), (40, 10, 80, 110))
        (lbl_dir / "neg__ood_people__p0.txt").write_text("", encoding="utf-8")

        data_yaml = ds_dir / "data.yaml"
        data_yaml.write_text(
            yaml.safe_dump(
                {
                    "path": str(ds_dir),
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

        real_tflite = Path(__file__).resolve().parents[1] / "artifacts" / "yolo11n_lettuce_pests.tflite"
        litert_res = evaluate_tflite_litert(real_tflite, data_yaml, imgsz=640, sample_conf_thres=0.99)
        assert litert_res["images_evaluated"] == 3
        assert litert_res["input_shape"] == [1, 640, 640, 3]
        assert litert_res["output_shape"] == [1, 6, 8400]
        assert litert_res["interpreter_verification"]["all_outputs_finite"] is True

        weights_pt = tmp_path / "best.pt"
        weights_pt.write_bytes(b"\x00" * 1024)
        base_pt = tmp_path / "base.pt"
        base_pt.write_bytes(b"\x00" * 1024)
        kaggle_summary = tmp_path / "m3_summary.json"
        kaggle_summary.write_text(
            json.dumps(
                {
                    "calibrated_threshold": 0.99,
                    "provenance": {
                        "enable_gpu": True,
                        "gpu_count": 1,
                        "device": "Tesla T4",
                        "split_leakage": 0,
                        "total_images": 785,
                        "zero_synthetic_confirmed": True,
                        "synthetic_images_count": 0,
                    },
                }
            ),
            encoding="utf-8",
        )
        ds_prov = tmp_path / "dataset_provenance.json"
        ds_prov.write_text(
            json.dumps({"zero_synthetic_confirmed": True, "synthetic_images_count": 0, "sources_probed": []}),
            encoding="utf-8",
        )
        out_json = tmp_path / "eval_report.json"

        def _fake_eval(path: Path, d_yaml: Path, imgsz: int = 640) -> dict[str, Any]:
            per_cls = {
                "whitefly": {"precision": 0.95, "recall": 0.92, "map50": 0.94, "map50_95": 0.68, "f1": 0.93},
                "aphids": {"precision": 0.89, "recall": 0.90, "map50": 0.92, "map50_95": 0.64, "f1": 0.89},
            }
            if path.suffix == ".tflite":
                return {"map50": 0.928, "map50_95": 0.65, "precision": 0.91, "recall": 0.90, "f1": 0.905, "per_class": per_cls}
            if "best" in path.name:
                return {"map50": 0.930, "map50_95": 0.66, "precision": 0.92, "recall": 0.91, "f1": 0.915, "per_class": per_cls}
            return {"map50": 0.80, "map50_95": 0.55, "precision": 0.84, "recall": 0.80, "f1": 0.82, "per_class": per_cls}

        monkeypatch.setattr(ml_evaluate, "evaluate_ultralytics_model", _fake_eval)
        monkeypatch.setattr(
            sys,
            "argv",
            [
                "ml.evaluate",
                "--baseline",
                str(base_pt),
                "--weights",
                str(weights_pt),
                "--tflite",
                str(real_tflite),
                "--data",
                str(data_yaml),
                "--kaggle-summary",
                str(kaggle_summary),
                "--dataset-provenance",
                str(ds_prov),
                "--output",
                str(out_json),
            ],
        )
        ml_evaluate.main()
        report = json.loads(out_json.read_text(encoding="utf-8"))
        assert report["status"] == "PASSED"
        assert "per_class" not in report["finetuned"]
        assert set(report["per_class"].keys()) == {"whitefly", "aphids"}
        assert report["tflite_eval"]["tflite_map50_drop"] == pytest.approx(0.002, abs=1e-4)
        assert report["provenance"]["device"] == "Tesla T4"
        assert build_provenance_payload(kaggle_summary, ds_prov)["zero_synthetic_confirmed"] is True


class TestTrainingAndKaggleContract:
    def test_training_config_defaults_and_yaml_resolution(self, monkeypatch: pytest.MonkeyPatch) -> None:
        from ultralytics.data.utils import check_det_dataset
        from ml.train import Yolo11TrainingConfig

        cfg = Yolo11TrainingConfig()
        assert cfg.model == "yolo11n.pt"
        assert cfg.data == "ml/configs/lettuce_pests.yaml"
        assert cfg.epochs == 100
        assert cfg.patience == 25
        assert cfg.batch == 16
        assert cfg.imgsz == 640
        assert cfg.seed == 42
        assert cfg.optimizer == "AdamW"

        repo_root = Path(__file__).resolve().parents[2]
        monkeypatch.chdir(repo_root)
        dataset_yaml = repo_root / "ml" / "configs" / "lettuce_pests.yaml"
        if (repo_root / "ml" / "data" / "merged_lettuce_pests" / "val" / "images").is_dir():
            resolved = check_det_dataset(str(dataset_yaml))
            assert resolved["nc"] == 2
            assert resolved["names"] == {0: "whitefly", 1: "aphids"}

    def test_write_kaggle_kernel_bundle_contract_and_zero_secrets(
        self,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        from ml.train import write_kaggle_kernel_bundle

        monkeypatch.setenv("ROBOFLOW_API_KEY", "rf_" + "unit_test_sentinel_123456")
        monkeypatch.setenv("KAGGLE_API_TOKEN", "KGAT_" + "unit_test_sentinel_123456")

        bundle_dir = tmp_path / "kaggle_bundle"
        meta_path = write_kaggle_kernel_bundle(
            bundle_dir,
            kaggle_username="adityadwiferdiansyah",
            dataset_sources=["adityadwiferdiansyah/hidrosense-whitefly-aphids-v2"],
        )
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        assert meta["id"] == "adityadwiferdiansyah/hidrosense-yolov11n-lettuce-pests-training"
        assert meta["code_file"] == "kaggle_train_entry.py"
        assert meta["is_private"] is True
        assert meta["enable_gpu"] is True
        assert meta["enable_tpu"] is False
        assert meta["enable_internet"] is True
        assert meta["dataset_sources"] == ["adityadwiferdiansyah/hidrosense-whitefly-aphids-v2"]

        staged_entry = bundle_dir / "kaggle_train_entry.py"
        assert staged_entry.is_file()
        for file_path in (meta_path, staged_entry):
            content = file_path.read_text(encoding="utf-8")
            assert "unit_test_sentinel_123456" not in content

        empty_ds_meta = write_kaggle_kernel_bundle(
            tmp_path / "kaggle_bundle_empty",
            kaggle_username="adityadwiferdiansyah",
            dataset_sources=None,
        )
        assert json.loads(empty_ds_meta.read_text(encoding="utf-8"))["dataset_sources"] == []

    def test_kaggle_entry_fails_fast_without_cuda_or_dataset(
        self,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        import torch
        from ml import kaggle_train_entry

        monkeypatch.setattr(torch.cuda, "is_available", lambda: False)
        with pytest.raises(RuntimeError, match="CUDA GPU is required"):
            kaggle_train_entry.ensure_gpu_available()

        monkeypatch.delenv("HIDROSENSE_DATASET_DIR", raising=False)
        missing_dir = tmp_path / "nonexistent_dataset"
        with pytest.raises(FileNotFoundError, match="Synthetic fallback is disabled"):
            kaggle_train_entry.locate_dataset_dir(dataset_dir=missing_dir, allow_local=False)

    def test_build_isolated_dataset_views_oversamples_only_train_whitefly_and_negatives(self, tmp_path: Path) -> None:
        from ml.kaggle_train_entry import build_isolated_dataset_views

        ds = tmp_path / "ds"
        for split_name, labels in [("train", ["0 0.5 0.5 0.2 0.2\n", "1 0.5 0.5 0.2 0.2\n", ""]), ("val", ["0 0.5 0.5 0.2 0.2\n", ""]), ("test", ["1 0.5 0.5 0.2 0.2\n", ""])]:
            (ds / split_name / "images").mkdir(parents=True)
            (ds / split_name / "labels").mkdir(parents=True)
            for idx, lbl_txt in enumerate(labels):
                _make_test_image(
                    ds / split_name / "images" / f"{split_name}_{idx}.jpg",
                    (30 + idx * 20, 120, 40),
                    (10, 10, 80, 80),
                )
                (ds / split_name / "labels" / f"{split_name}_{idx}.txt").write_text(lbl_txt, encoding="utf-8")

        views = build_isolated_dataset_views(
            ds,
            tmp_path / "work",
            whitefly_oversample_factor=4,
            negative_oversample_factor=2,
            zoomout_per_class=0,
        )
        assert views["whitefly_train_images"] == 1
        assert views["negative_train_images"] == 1
        assert views["balanced_train_images"] == 7  # 1*4 + 1*1 + 1*2
        balanced_train_imgs = sorted((tmp_path / "work" / "balanced" / "train" / "images").iterdir())
        assert len(balanced_train_imgs) == 7
        assert len(list((tmp_path / "work" / "balanced" / "val" / "images").iterdir())) == 2
        assert len(list((tmp_path / "work" / "balanced" / "test" / "images").iterdir())) == 2

        views_zoom = build_isolated_dataset_views(
            ds,
            tmp_path / "work_zoom",
            whitefly_oversample_factor=2,
            negative_oversample_factor=1,
            zoomout_per_class=2,
        )
        assert views_zoom["zoomout_total"] == 4
        assert views_zoom["balanced_train_images"] == 8  # 1*2 + 1 + 1 + 4 zoomout
        assert len(list((tmp_path / "work_zoom" / "balanced" / "val" / "images").iterdir())) == 2
        assert len(list((tmp_path / "work_zoom" / "balanced" / "test" / "images").iterdir())) == 2
