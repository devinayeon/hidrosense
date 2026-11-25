from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw
import pytest

from ml.prepare_dataset import (
    CANONICAL_CLASSES,
    canonicalize_label_name,
    deduplicate_and_merge_sources,
    parse_and_sanitize_yolo_line,
)
from ml.export_tflite import build_model_metadata, decode_yolov11_output


def _draw_sample(path: Path, bg: tuple[int, int, int], fg: tuple[int, int, int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img = Image.new("RGB", (128, 128), color=bg)
    draw = ImageDraw.Draw(img)
    draw.ellipse((24, 24, 96, 88), fill=fg)
    img.save(path)


class TestTwoClassAndOodGuardrails:
    def test_canonical_classes_strictly_whitefly_and_aphids_without_molted_skin_or_thrips(self) -> None:
        assert CANONICAL_CLASSES == {0: "whitefly", 1: "aphids"}
        assert canonicalize_label_name("whitefly") == 0
        assert canonicalize_label_name("kutu kebul") == 0
        assert canonicalize_label_name("aphids") == 1
        assert canonicalize_label_name("aphid") == 1
        assert canonicalize_label_name("molted skin") is None
        assert canonicalize_label_name("molted_skin") is None
        assert canonicalize_label_name("exuviae") is None
        assert canonicalize_label_name("thrips") is None

    def test_molted_skin_polygons_are_stripped_and_molted_only_images_become_background_negatives(
        self, tmp_path: Path
    ) -> None:
        ds = tmp_path / "aphids_new"
        (ds / "train" / "images").mkdir(parents=True)
        (ds / "train" / "labels").mkdir(parents=True)
        (ds / "data.yaml").write_text("nc: 2\nnames: ['aphids', 'molted skin']\n", encoding="utf-8")

        # Image 1: both aphids (0) and molted skin (1) polygons -> keep only aphids (canonical 1)
        _draw_sample(ds / "train" / "images" / "both.jpg", (40, 130, 50), (180, 210, 90))
        (ds / "train" / "labels" / "both.txt").write_text(
            "0 0.2 0.2 0.4 0.2 0.4 0.4 0.2 0.4\n1 0.6 0.6 0.8 0.6 0.8 0.8 0.6 0.8\n",
            encoding="utf-8",
        )

        # Image 2: ONLY molted skin (1) with distinct geometry -> RETAINED with 0 boxes (hard negative!)
        img2 = Image.new("RGB", (128, 128), color=(50, 140, 60))
        d2 = ImageDraw.Draw(img2)
        d2.rectangle((5, 70, 55, 120), fill=(245, 245, 245))
        d2.polygon([(80, 10), (120, 45), (90, 65)], fill=(20, 70, 25))
        img2.save(ds / "train" / "images" / "molted_only.jpg")
        (ds / "train" / "labels" / "molted_only.txt").write_text(
            "1 0.3 0.3 0.5 0.3 0.5 0.5 0.3 0.5\n",
            encoding="utf-8",
        )

        # Image 3: Pure empty background with distinct vertical bottle-like geometry -> RETAINED with 0 boxes
        img3 = Image.new("RGB", (128, 128), color=(200, 200, 210))
        d3 = ImageDraw.Draw(img3)
        d3.rectangle((52, 8, 76, 122), fill=(30, 90, 200))
        img3.save(ds / "train" / "images" / "empty_bg.jpg")
        (ds / "train" / "labels" / "empty_bg.txt").write_text("", encoding="utf-8")

        records, stats = deduplicate_and_merge_sources([ds])
        assert len(records) == 3
        by_name = {r.image_path.name: r for r in records}
        assert len(by_name["both.jpg"].boxes) == 1
        assert by_name["both.jpg"].boxes[0].class_id == 1
        assert len(by_name["molted_only.jpg"].boxes) == 0
        assert len(by_name["empty_bg.jpg"].boxes) == 0
        assert stats["molted_skin_boxes_removed"] == 2
        assert stats["negative_images_kept"] == 2

    def test_visual_pipeline_covers_all_nine_required_visual_axes(self) -> None:
        from ml.visual_pipeline import VISUAL_AXES, build_visual_training_hyperparams

        expected_axes = {
            "color",
            "shape",
            "density",
            "lighting",
            "background",
            "exposure",
            "size",
            "edges",
            "texture",
        }
        assert set(VISUAL_AXES.keys()) == expected_axes
        hparams = build_visual_training_hyperparams()
        assert hparams["scale"] >= 0.7
        assert hparams["mosaic"] == 1.0
        assert hparams["copy_paste"] > 0.0

    def test_two_class_decoder_and_metadata_contract_is_six_channels(self) -> None:
        # [6, 2] -> cx, cy, w, h, score_whitefly, score_aphids
        tensor = [
            [320.0, 100.0],
            [320.0, 100.0],
            [64.0, 32.0],
            [64.0, 32.0],
            [0.91, 0.04],
            [0.03, 0.87],
        ]
        dets = decode_yolov11_output(tensor, img_size=640, conf_threshold=0.45, iou_threshold=0.45)
        assert len(dets) == 2
        assert {d["class_name"] for d in dets} == {"whitefly", "aphids"}

        meta = build_model_metadata(model_version="yolo11n-fp16-test1234", img_size=640)
        assert meta["output_shape"] == [1, 6, 8400]
        assert meta["classes"] == {"0": "whitefly", "1": "aphids"}

    def test_classification_and_ood_metrics_include_accuracy_specificity_fpr_mcc_and_loss(self) -> None:
        from ml.evaluate import compute_classification_and_ood_metrics

        metrics = compute_classification_and_ood_metrics(
            confusion_3x3=[
                [45, 2, 3],   # pred whitefly: 45 TP, 2 true aphids, 3 background FP
                [1, 80, 2],   # pred aphids:   1 true whitefly, 80 TP, 2 background FP
                [4, 5, 0],    # missed FN:     4 whitefly FN, 5 aphids FN
            ],
            image_outcomes=[
                # (has_gt_pest, has_pred_pest, source_group)
                *[(True, True, "in_domain_positive")] * 58,
                *[(True, False, "in_domain_positive")] * 2,
                *[(False, False, "leaf_negative")] * 10,
                *[(False, False, "ood_people")] * 10,
                *[(False, False, "ood_drink_bottles_cups")] * 10,
                *[(False, False, "ood_healthy_food")] * 10,
                *[(False, False, "ood_random_objects")] * 10,
            ],
        )
        assert metrics["matched_box_classification_accuracy"] > 0.95
        assert metrics["image_level"]["specificity_tnr"] == pytest.approx(1.0)
        assert metrics["image_level"]["false_positive_rate"] == pytest.approx(0.0)
        assert metrics["image_level"]["accuracy"] > 0.95
        assert metrics["image_level"]["mcc"] > 0.90
        assert metrics["ood_breakdown"]["ood_people"]["false_positives"] == 0
        assert metrics["ood_breakdown"]["ood_drink_bottles_cups"]["false_positives"] == 0
        assert metrics["ood_breakdown"]["ood_healthy_food"]["false_positives"] == 0
        assert metrics["ood_breakdown"]["ood_random_objects"]["false_positives"] == 0
