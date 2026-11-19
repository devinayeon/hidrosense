from __future__ import annotations

import json
from pathlib import Path
from PIL import Image, ImageDraw
import pytest

from ml.prepare_dataset import (
    CANONICAL_CLASSES,
    canonicalize_label_name,
    parse_and_sanitize_yolo_line,
    deduplicate_and_merge_sources,
    stratified_split_records,
    DatasetRecord,
    BoxAnnotation,
)
from ml.evaluate import (
    PROMOTION_GATES,
    assert_promotion_ready,
    compare_baseline_vs_finetuned,
)
from ml.export_tflite import (
    build_model_metadata,
    decode_yolov11_output,
)


def _make_test_image(path: Path, color: tuple[int, int, int], rect: tuple[int, int, int, int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img = Image.new("RGB", (128, 128), color=color)
    draw = ImageDraw.Draw(img)
    draw.rectangle(rect, fill=(255, 255, 0))
    img.save(path)


class TestCanonicalLabelMapping:
    def test_maps_synonyms_case_insensitively_to_canonical_ids(self) -> None:
        assert CANONICAL_CLASSES == {0: "thrips", 1: "whitefly", 2: "aphids"}
        assert canonicalize_label_name("Thrips") == 0
        assert canonicalize_label_name("thrip") == 0
        assert canonicalize_label_name("frankliniella") == 0
        assert canonicalize_label_name("whitefly") == 1
        assert canonicalize_label_name("Whiteflies") == 1
        assert canonicalize_label_name("white-fly") == 1
        assert canonicalize_label_name("kutu_kebul") == 1
        assert canonicalize_label_name("kutu kebul") == 1
        assert canonicalize_label_name("aphid") == 2
        assert canonicalize_label_name("Aphids") == 2
        assert canonicalize_label_name("kutu_daun") == 2
        assert canonicalize_label_name("kutu daun") == 2

    def test_returns_none_for_out_of_scope_classes(self) -> None:
        assert canonicalize_label_name("caterpillar") is None
        assert canonicalize_label_name("slug") is None
        assert canonicalize_label_name("healthy") is None
        assert canonicalize_label_name("background") is None


class TestAnnotationSanitization:
    def test_parses_standard_yolo_bbox_and_clamps_bounds(self) -> None:
        source_map = {0: "aphids", 1: "thrips"}
        box = parse_and_sanitize_yolo_line("0 0.5 0.5 0.4 0.2", source_map)
        assert box is not None
        assert box.class_id == 2  # aphids -> canonical 2
        assert box.cx == pytest.approx(0.5)
        assert box.cy == pytest.approx(0.5)
        assert box.w == pytest.approx(0.4)
        assert box.h == pytest.approx(0.2)

    def test_converts_polygon_segmentation_line_to_bounding_box(self) -> None:
        source_map = {0: "whitefly"}
        # Polygon from (0.2, 0.3) to (0.6, 0.7)
        line = "0 0.2 0.3 0.6 0.3 0.6 0.7 0.2 0.7"
        box = parse_and_sanitize_yolo_line(line, source_map)
        assert box is not None
        assert box.class_id == 1
        assert box.cx == pytest.approx(0.4)
        assert box.cy == pytest.approx(0.5)
        assert box.w == pytest.approx(0.4)
        assert box.h == pytest.approx(0.4)

    def test_rejects_degenerate_or_unmapped_boxes(self) -> None:
        source_map = {0: "thrips", 1: "caterpillar"}
        assert parse_and_sanitize_yolo_line("0 0.5 0.5 0.0 0.2", source_map) is None
        assert parse_and_sanitize_yolo_line("0 0.5 0.5 -0.1 0.2", source_map) is None
        assert parse_and_sanitize_yolo_line("1 0.5 0.5 0.3 0.3", source_map) is None


class TestDeduplicationAndStratifiedSplit:
    def test_deduplicates_identical_images_across_sources_before_split(self, tmp_path: Path) -> None:
        src1 = tmp_path / "ds1"
        src2 = tmp_path / "ds2"

        for ds_root, names_list in [
            (src1, ["aphids", "thrips", "whitefly"]),
            (src2, ["thrips", "whiteflies", "aphid"]),
        ]:
            (ds_root / "train" / "images").mkdir(parents=True)
            (ds_root / "train" / "labels").mkdir(parents=True)
            (ds_root / "data.yaml").write_text(
                f"names: {json.dumps(names_list)}\nnc: {len(names_list)}\n",
                encoding="utf-8",
            )

        # Create identical image in both ds1 and ds2
        _make_test_image(src1 / "train" / "images" / "dup1.jpg", (20, 120, 40), (10, 10, 80, 80))
        (src1 / "train" / "labels" / "dup1.txt").write_text("0 0.5 0.5 0.3 0.3\n", encoding="utf-8")

        _make_test_image(src2 / "train" / "images" / "dup1_copy.jpg", (20, 120, 40), (10, 10, 80, 80))
        (src2 / "train" / "labels" / "dup1_copy.txt").write_text("2 0.5 0.5 0.3 0.3\n", encoding="utf-8")

        # Create distinct second image in ds2
        _make_test_image(src2 / "train" / "images" / "unique2.jpg", (180, 30, 90), (50, 20, 110, 100))
        (src2 / "train" / "labels" / "unique2.txt").write_text("0 0.4 0.4 0.2 0.2\n", encoding="utf-8")

        records, stats = deduplicate_and_merge_sources([src1, src2])
        assert len(records) == 2
        assert stats["duplicates_removed"] == 1

    def test_stratified_split_prevents_class_starvation_and_leakage(self, tmp_path: Path) -> None:
        records: list[DatasetRecord] = []
        for idx in range(30):
            cls_id = idx % 3
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
            assert present_classes == {0, 1, 2}


class TestEvaluationAndExportContracts:
    def test_promotion_gates_enforce_accuracy_size_and_parity(self) -> None:
        assert "map50" in PROMOTION_GATES
        passing = {
            "map50": 0.78,
            "recall": 0.74,
            "tflite_map50_drop": 0.008,
            "model_size_mb": 5.2,
        }
        assert_promotion_ready(passing)

        failing = {**passing, "tflite_map50_drop": 0.04}
        with pytest.raises(ValueError, match="failed promotion gates"):
            assert_promotion_ready(failing)

    def test_compare_baseline_vs_finetuned_calculates_deltas(self) -> None:
        baseline = {"map50": 0.21, "map50_95": 0.11, "precision": 0.30, "recall": 0.25}
        finetuned = {"map50": 0.81, "map50_95": 0.52, "precision": 0.84, "recall": 0.79}
        comparison = compare_baseline_vs_finetuned(baseline, finetuned)
        assert comparison["improvements"]["map50_delta"] == pytest.approx(0.60)
        assert comparison["beats_baseline"] is True

    def test_decode_yolov11_output_handles_both_channel_first_and_last(self) -> None:
        # 2 anchors: anchor 0 has high score for whitefly (class 1), anchor 1 is low score
        # Shape [7, 2] -> cx, cy, w, h, c0, c1, c2
        raw_channel_first = [
            [320.0, 100.0],  # cx
            [320.0, 100.0],  # cy
            [64.0, 20.0],    # w
            [64.0, 20.0],    # h
            [0.05, 0.02],    # class 0: thrips
            [0.88, 0.10],    # class 1: whitefly
            [0.03, 0.01],    # class 2: aphids
        ]
        dets = decode_yolov11_output(
            raw_channel_first,
            img_size=640,
            conf_threshold=0.35,
            iou_threshold=0.45,
        )
        assert len(dets) == 1
        assert dets[0]["class_id"] == 1
        assert dets[0]["class_name"] == "whitefly"
        assert dets[0]["confidence"] == pytest.approx(0.88)

        metadata = build_model_metadata(model_version="v1.0.0-yolo11n", img_size=640)
        assert metadata["input_shape"] == [1, 640, 640, 3]
        assert metadata["output_shape"] == [1, 7, 8400]
        assert metadata["classes"] == {"0": "thrips", "1": "whitefly", "2": "aphids"}
