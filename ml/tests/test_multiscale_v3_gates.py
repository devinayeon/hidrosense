from __future__ import annotations

from pathlib import Path
from PIL import Image
import pytest

from ml.evaluate import PROMOTION_GATES, assert_promotion_ready, evaluate_small_scale_recall
from ml.ood_negatives import COCO_EXCLUDED_CLASSES, classify_coco_ood_category
from ml.prepare_dataset import extract_roboflow_base_stem, is_synthetic_collage_image


class TestMultiScaleV3Contracts:
    def test_v3_promotion_gates_require_small_scale_recall_and_strict_ood_fpr(self) -> None:
        assert "small_scale_recall" in PROMOTION_GATES
        assert PROMOTION_GATES["small_scale_recall"] == ("min", 0.70)
        assert PROMOTION_GATES["ood_false_positive_rate"] == ("max", 0.03)

        # Simulate v2 failure signature: high in-domain mAP50 (0.94), but 17% small-scale recall and 4.17% OOD FPR
        v2_failure_metrics = {
            "map50": 0.9423,
            "recall": 0.9114,
            "f1": 0.8970,
            "small_scale_recall": 0.17,
            "tflite_map50_drop": 0.0,
            "ood_false_positive_rate": 0.0417,
            "model_size_mb": 5.158,
        }
        with pytest.raises(ValueError, match="small_scale_recall"):
            assert_promotion_ready(v2_failure_metrics)

    def test_synthetic_collage_filter_rejects_mosaic_and_white_background_grids(self, tmp_path: Path) -> None:
        mosaic_path = tmp_path / "mosaic_2_0_0_jpg.rf.abc.jpg"
        natural_img = Image.new("RGB", (64, 64), color=(50, 130, 45))
        assert is_synthetic_collage_image(mosaic_path, natural_img) is True

        white_bg_path = tmp_path / "whitefly_grid.jpg"
        white_img = Image.new("RGB", (64, 64), color=(255, 255, 255))
        assert is_synthetic_collage_image(white_bg_path, white_img) is True

        real_leaf_path = tmp_path / "whitefly_-1-_jpg.rf.xyz.jpg"
        assert is_synthetic_collage_image(real_leaf_path, natural_img) is False

    def test_base_stem_strips_rotation_and_flip_suffixes_to_prevent_split_leakage(self) -> None:
        assert extract_roboflow_base_stem("aphids_n_40_1_jpg.rf.1bec39.jpg") == "aphids_n_40_1"
        assert extract_roboflow_base_stem("aphids_n_40_1_rot180_jpg.rf.0d69f3.jpg") == "aphids_n_40_1"
        assert extract_roboflow_base_stem("aphids_n_40_1_rot90_jpg.rf.999aaa.jpg") == "aphids_n_40_1"

    def test_coco_ood_excludes_potted_plant_and_vase(self) -> None:
        assert 58 in COCO_EXCLUDED_CLASSES
        assert 75 in COCO_EXCLUDED_CLASSES
        assert classify_coco_ood_category({58, 39}) is None
        assert classify_coco_ood_category({75, 0}) is None
        assert classify_coco_ood_category({39, 0}) == "ood_drink_bottles_cups"

    def test_small_scale_recall_returns_zero_when_no_positive_images(self, tmp_path: Path) -> None:
        import yaml

        ds_dir = tmp_path / "empty_pos_ds"
        (ds_dir / "test" / "images").mkdir(parents=True)
        (ds_dir / "test" / "labels").mkdir(parents=True)
        Image.new("RGB", (64, 64), color=(40, 120, 45)).save(ds_dir / "test" / "images" / "neg__leaf_empty__0.jpg")
        (ds_dir / "test" / "labels" / "neg__leaf_empty__0.txt").write_text("", encoding="utf-8")
        data_yaml = ds_dir / "data.yaml"
        data_yaml.write_text(
            yaml.safe_dump(
                {"path": str(ds_dir), "train": "test/images", "val": "test/images", "test": "test/images", "nc": 2, "names": {0: "whitefly", 1: "aphids"}},
                sort_keys=False,
            ),
            encoding="utf-8",
        )
        tflite_path = Path(__file__).resolve().parents[2] / "apps" / "mobile" / "assets" / "ml" / "yolo11n_lettuce_pests.tflite"
        res = evaluate_small_scale_recall(tflite_path, data_yaml, scale=0.25, conf_thres=0.40)
        assert res["images_evaluated"] == 0
        assert res["overall_recall"] == 0.0

    @pytest.mark.production_artifact
    def test_production_tflite_passes_phone_distance_small_scale_recall_gate(self) -> None:
        repo_root = Path(__file__).resolve().parents[2]
        tflite_path = repo_root / "apps" / "mobile" / "assets" / "ml" / "yolo11n_lettuce_pests.tflite"
        data_yaml = repo_root / "ml" / "data" / "merged_lettuce_pests" / "data.yaml"
        if not data_yaml.is_file():
            pytest.skip("Local merged test split not present")
        meta_path = repo_root / "apps" / "mobile" / "assets" / "ml" / "model_metadata.json"
        import json

        conf_thr = float(json.loads(meta_path.read_text(encoding="utf-8"))["confidence_threshold"])
        res = evaluate_small_scale_recall(
            tflite_path,
            data_yaml,
            scale=0.25,
            conf_thres=conf_thr,
            max_images=None,
        )
        assert res["per_class_counts"]["whitefly"]["total"] >= 20, f"Expected full whitefly coverage, got {res}"
        assert res["per_class_recall"]["whitefly"] >= PROMOTION_GATES["small_scale_recall"][1], (
            f"Whitefly small-scale recall below gate: {res}"
        )
        assert res["per_class_recall"]["aphids"] >= PROMOTION_GATES["small_scale_recall"][1], (
            f"Aphids small-scale recall below gate: {res}"
        )
        assert res["overall_recall"] >= PROMOTION_GATES["small_scale_recall"][1], (
            f"Mobile TFLite failed phone-distance (0.25x) small-scale recall gate: {res}"
        )

