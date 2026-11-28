from __future__ import annotations

import json
from pathlib import Path
import pytest

from ml.evaluate import (
    PROMOTION_GATES,
    assert_promotion_ready,
    evaluate_calibration_and_tide,
    evaluate_domain_shift_stress,
)
from ml.kaggle_train_entry import (
    _build_albumentations_list,
    _generate_zoomout_small_pest_views,
    build_isolated_dataset_views,
)
from ml.prepare_dataset import (
    deduplicate_and_merge_sources,
    export_merged_dataset,
    extract_loose_scene_family,
    extract_temporal_session_key,
    stratified_split_records,
    verify_exported_dataset,
)


class TestV4LeakageAndNonF1Gates:
    def test_v4_promotion_gates_enforce_map75_and_overexposure_recall(self) -> None:
        assert PROMOTION_GATES["map75"] == ("min", 0.72)
        assert PROMOTION_GATES["overexposure_recall"] == ("min", 0.85)

        # Reproduce exact v3 failure signature: high F1 (0.966), but mobile mAP@75=0.6338 and overexposure=0.775
        v3_signature = {
            "map50": 0.9845,
            "map75": 0.6338,
            "recall": 0.9552,
            "f1": 0.9660,
            "small_scale_recall": 0.9907,
            "overexposure_recall": 0.7750,
            "tflite_map50_drop": 0.0,
            "ood_false_positive_rate": 0.0056,
            "model_size_mb": 5.158,
        }
        with pytest.raises(ValueError, match="map75"):
            assert_promotion_ready(v3_signature)
        with pytest.raises(ValueError, match="overexposure_recall"):
            assert_promotion_ready({**v3_signature, "map75": 0.85})

    def test_temporal_session_key_groups_same_day_lab_bursts(self) -> None:
        assert extract_temporal_session_key("pos__20220916-163112.rf.70239e767b.jpg") == "session_20220916"
        assert extract_temporal_session_key("neg__leaf_empty__20220916-163110.rf.5399c14d78.jpg") == "session_20220916"
        assert extract_temporal_session_key("20220919-174954.rf.126c020555") == "session_20220919"
        assert extract_temporal_session_key("cam1.20220916-163112") == "session_20220916"
        assert extract_temporal_session_key("pos__whitefly_-21-.rf.4fffa9dd58.jpg") is None
        assert extract_temporal_session_key("neg__ood_people__000000000139.jpg") is None

    def test_loose_scene_family_groups_field_colony_siblings(self) -> None:
        assert extract_loose_scene_family("pos__aphids_n_11_1_jpg.rf.aaa.jpg") == "fam_aphids_n_11"
        assert extract_loose_scene_family("aphids_n_11_3_rot180_jpg.rf.bbb") == "fam_aphids_n_11"
        assert extract_loose_scene_family("whitefly_newer_09_2_jpg.rf.ccc") == "fam_whitefly_newer_09"
        assert extract_loose_scene_family("neg__leaf_empty__null_137.rf.ddd.jpg") == "fam_null_137"
        assert extract_loose_scene_family("neg__ood_people__ood_people_2bc5.jpg") is None

    def test_unverified_empty_and_white_mesh_negatives_are_filtered(self, tmp_path: Path) -> None:
        import numpy as np
        from PIL import Image

        rng = np.random.default_rng(7)

        # Source 1: aphids_new_v1 with 1 positive, 1 unannotated empty, 1 molted_skin-only
        src_aphids = tmp_path / "aphids_new_v1"
        (src_aphids / "images").mkdir(parents=True)
        (src_aphids / "labels").mkdir(parents=True)
        (src_aphids / "data.yaml").write_text("names:\n  0: aphids\n  1: molted skin\n", encoding="utf-8")

        def _write_textured(path: Path, base_rgb: tuple[int, int, int]) -> None:
            arr = np.clip(
                np.asarray(base_rgb, dtype=np.int16)[None, None, :] + rng.integers(-25, 25, size=(128, 128, 3)),
                0,
                255,
            ).astype(np.uint8)
            Image.fromarray(arr).save(path)

        _write_textured(src_aphids / "images" / "a_pos.jpg", (90, 140, 60))
        (src_aphids / "labels" / "a_pos.txt").write_text("0 0.5 0.5 0.2 0.2\n", encoding="utf-8")
        _write_textured(src_aphids / "images" / "a_unlabeled.jpg", (85, 135, 55))
        (src_aphids / "labels" / "a_unlabeled.txt").write_text("", encoding="utf-8")
        _write_textured(src_aphids / "images" / "a_molted_only.jpg", (95, 145, 65))
        (src_aphids / "labels" / "a_molted_only.txt").write_text("1 0.4 0.4 0.1 0.1\n", encoding="utf-8")

        # Source 2: clean field dataset with 1 genuine green empty leaf + 1 blown-out white-mesh screenshot
        src_field = tmp_path / "field_v6"
        (src_field / "images").mkdir(parents=True)
        (src_field / "labels").mkdir(parents=True)
        (src_field / "data.yaml").write_text("names:\n  0: whitefly\n  1: aphids\n", encoding="utf-8")

        _write_textured(src_field / "images" / "null_clean.jpg", (70, 130, 50))
        (src_field / "labels" / "null_clean.txt").write_text("", encoding="utf-8")
        white_mesh = np.full((128, 128, 3), 255, dtype=np.uint8)
        white_mesh[30:70, 30:70] = [10, 10, 10]
        Image.fromarray(white_mesh).save(src_field / "images" / "null_76_corrupt.jpg")
        (src_field / "labels" / "null_76_corrupt.txt").write_text("", encoding="utf-8")

        records, stats = deduplicate_and_merge_sources(
            [src_aphids, src_field],
            keep_negatives=True,
            filter_collage_artifacts=True,
            drop_unverified_empty_sources=frozenset({"aphids_new_v1"}),
        )
        kept_stems = {r.image_path.stem for r in records}
        assert kept_stems == {"a_pos", "null_clean"}
        assert stats["collages_filtered"] == 1
        assert stats["molted_skin_boxes_removed"] == 1
        assert stats["negative_images_kept"] == 1

    def test_end_to_end_session_and_family_split_blocks_cross_split_leakage(self, tmp_path: Path) -> None:
        import shutil
        import numpy as np
        from PIL import Image

        rng = np.random.default_rng(123)
        src = tmp_path / "mixed_src"
        (src / "images").mkdir(parents=True)
        (src / "labels").mkdir(parents=True)
        (src / "data.yaml").write_text("names:\n  0: whitefly\n  1: aphids\n", encoding="utf-8")

        def _make_unique_img(path: Path, seed_offset: int) -> None:
            # Distinct low-frequency geometric patterns so DCT pHash differs cleanly across groups (Hamming >> 4)
            yy, xx = np.mgrid[0:128, 0:128].astype(np.float32)
            fx = float((seed_offset % 5) + 1) * 0.14
            fy = float(((seed_offset // 5) % 5) + 1) * 0.17
            phase = float(seed_offset) * 1.1
            wave = (np.sin(xx * fx + phase) * np.cos(yy * fy - phase) * 90.0 + 128.0).clip(0, 255)
            arr = np.stack([wave, np.roll(wave, seed_offset * 7, axis=0), np.roll(wave, seed_offset * 11, axis=1)], axis=2).astype(np.uint8)
            Image.fromarray(arr).save(path)

        idx = 0
        # 4 distinct lab days (2 frames each) for aphids + 4 distinct field whitefly families (2 frames each)
        for day in ("20220916", "20220917", "20220918", "20220919"):
            for sec in ("120001", "120010"):
                idx += 1
                stem = f"{day}-{sec}.rf.{idx:010x}"
                _make_unique_img(src / "images" / f"{stem}.jpg", idx)
                (src / "labels" / f"{stem}.txt").write_text("1 0.5 0.5 0.15 0.15\n", encoding="utf-8")
        for fam_id in ("10", "11", "12", "13"):
            for shot in ("1", "2"):
                idx += 1
                stem = f"whitefly_newer_{fam_id}_{shot}_jpg.rf.{idx:010x}"
                _make_unique_img(src / "images" / f"{stem}.jpg", idx)
                (src / "labels" / f"{stem}.txt").write_text("0 0.4 0.4 0.12 0.12\n", encoding="utf-8")

        records, scan_stats = deduplicate_and_merge_sources([src], keep_negatives=True)
        splits = stratified_split_records(records, train_ratio=0.5, val_ratio=0.25, seed=42)
        out_dir = tmp_path / "exported"
        export_merged_dataset(splits, out_dir, scan_stats)
        ver = verify_exported_dataset(out_dir, max_hamming_distance=2, group_hamming_distance=4, require_all_classes=True)
        assert ver["cross_split_temporal_session_overlaps"] == 0
        assert ver["cross_split_loose_scene_family_overlaps"] == 0

        # Deliberately leak a temporal session frame from train into test -> verify_exported_dataset must reject
        train_session_img = next(p for p in (out_dir / "train" / "images").glob("*.jpg") if "2022" in p.name)
        leaked_stem = train_session_img.stem.replace("1200", "1300")
        rng_img = Image.fromarray(rng.integers(20, 220, size=(96, 96, 3), dtype=np.uint8))
        rng_img.save(out_dir / "test" / "images" / f"{leaked_stem}.jpg")
        shutil.copy2(out_dir / "train" / "labels" / f"{train_session_img.stem}.txt", out_dir / "test" / "labels" / f"{leaked_stem}.txt")
        with pytest.raises(ValueError, match="temporal session"):
            verify_exported_dataset(out_dir, max_hamming_distance=2, group_hamming_distance=4, require_all_classes=True)

        # Clean up temporal leak and deliberately leak a loose scene-family sibling -> verify_exported_dataset must reject
        (out_dir / "test" / "images" / f"{leaked_stem}.jpg").unlink()
        (out_dir / "test" / "labels" / f"{leaked_stem}.txt").unlink()
        train_fam_img = next(p for p in (out_dir / "train" / "images").glob("*.jpg") if "whitefly_newer_" in p.name)
        leaked_fam_stem = train_fam_img.stem.replace("_1_jpg", "_9_jpg").replace("_2_jpg", "_9_jpg")
        Image.fromarray(rng.integers(25, 225, size=(96, 96, 3), dtype=np.uint8)).save(
            out_dir / "test" / "images" / f"{leaked_fam_stem}.jpg"
        )
        shutil.copy2(
            out_dir / "train" / "labels" / f"{train_fam_img.stem}.txt",
            out_dir / "test" / "labels" / f"{leaked_fam_stem}.txt",
        )
        with pytest.raises(ValueError, match="loose scene-family"):
            verify_exported_dataset(out_dir, max_hamming_distance=2, group_hamming_distance=4, require_all_classes=True)

    def test_domain_shift_stress_rejects_wrong_class_and_off_target_and_accepts_localized_hits(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        import numpy as np
        from PIL import Image
        import ai_edge_litert.interpreter as litert_mod
        import ml.evaluate as eval_mod

        test_imgs = tmp_path / "test" / "images"
        test_lbls = tmp_path / "test" / "labels"
        test_imgs.mkdir(parents=True)
        test_lbls.mkdir(parents=True)
        Image.fromarray(np.full((640, 640, 3), 100, dtype=np.uint8)).save(test_imgs / "pos_aphid.jpg")
        (test_lbls / "pos_aphid.txt").write_text("1 0.5 0.5 0.2 0.2\n", encoding="utf-8")
        data_yaml = tmp_path / "data.yaml"
        data_yaml.write_text(
            f"path: {tmp_path.as_posix()}\ntrain: test/images\nval: test/images\ntest: test/images\nnames:\n  0: whitefly\n  1: aphids\n",
            encoding="utf-8",
        )

        class _StubInterpreter:
            def __init__(self, *args, **kwargs) -> None:
                pass
            def allocate_tensors(self) -> None:
                pass
            def get_input_details(self):
                return [{"index": 0}]
            def get_output_details(self):
                return [{"index": 0}]
            def set_tensor(self, idx, val) -> None:
                pass
            def invoke(self) -> None:
                pass
            def get_tensor(self, idx):
                return np.zeros((1, 6, 1), dtype=np.float32)

        monkeypatch.setattr(litert_mod, "Interpreter", _StubInterpreter)

        # Case A: wrong class (whitefly=0 on aphids GT) + off-target aphids box far from center -> 0 hits
        monkeypatch.setattr(
            eval_mod,
            "decode_yolov11_output",
            lambda *a, **kw: [
                {"class_id": 0, "confidence": 0.9, "box": [0.4, 0.4, 0.6, 0.6]},
                {"class_id": 1, "confidence": 0.9, "box": [0.02, 0.02, 0.08, 0.08]},
            ],
        )
        res_bad = evaluate_domain_shift_stress(tmp_path / "stub.tflite", data_yaml, conf_thres=0.50)
        assert res_bad["overexposure_recall"] == 0.0
        assert all(v["hits"] == 0 for v in res_bad["scenarios"].values())

        # Case B: localized aphids hit matching both full-frame (0.5, 0.5, 0.2x0.2) AND portrait_9x16_nft_border ROI
        # In 720x1280 letterboxed to 640x640: scale=0.5 -> new_w=360, new_h=640, pad_l=140, pad_t=0;
        # ROI center (150+210, 430+210)=(360, 640) -> letterbox (320/640, 320/640)=(0.5, 0.5), size (210*0.2/640=0.0656)
        call_idx = {"n": 0}
        def _good_decode(*a, **kw):
            idx = call_idx["n"]
            call_idx["n"] += 1
            if idx == 5:  # portrait_9x16_nft_border
                return [{"class_id": 1, "confidence": 0.85, "box": [0.467, 0.467, 0.533, 0.533]}]
            return [{"class_id": 1, "confidence": 0.85, "box": [0.40, 0.40, 0.60, 0.60]}]

        monkeypatch.setattr(eval_mod, "decode_yolov11_output", _good_decode)
        res_good = evaluate_domain_shift_stress(tmp_path / "stub.tflite", data_yaml, conf_thres=0.50)
        assert res_good["overexposure_recall"] == 1.0
        assert res_good["scenarios"]["portrait_9x16_nft_border"]["image_recall"] == 1.0
        assert all(v["hits"] == 1 for v in res_good["scenarios"].values())

    def test_calibration_and_tide_bins_sub_030_and_classifies_all_error_types(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        import numpy as np
        from PIL import Image
        import ai_edge_litert.interpreter as litert_mod
        import ml.evaluate as eval_mod

        test_imgs = tmp_path / "test" / "images"
        test_lbls = tmp_path / "test" / "labels"
        test_imgs.mkdir(parents=True)
        test_lbls.mkdir(parents=True)
        Image.fromarray(np.full((640, 640, 3), 120, dtype=np.uint8)).save(test_imgs / "img0.jpg")
        # 3 GT boxes: small (<32px, cls 0), medium (64px, cls 1), large (128px, cls 0)
        (test_lbls / "img0.txt").write_text(
            "0 0.10 0.10 0.03 0.03\n"
            "1 0.50 0.50 0.10 0.10\n"
            "0 0.80 0.80 0.20 0.20\n",
            encoding="utf-8",
        )
        data_yaml = tmp_path / "data.yaml"
        data_yaml.write_text(
            f"path: {tmp_path.as_posix()}\ntrain: test/images\nval: test/images\ntest: test/images\nnames:\n  0: whitefly\n  1: aphids\n",
            encoding="utf-8",
        )

        class _StubInterpreter:
            def __init__(self, *args, **kwargs) -> None:
                pass
            def allocate_tensors(self) -> None:
                pass
            def get_input_details(self):
                return [{"index": 0}]
            def get_output_details(self):
                return [{"index": 0}]
            def set_tensor(self, idx, val) -> None:
                pass
            def invoke(self) -> None:
                pass
            def get_tensor(self, idx):
                return np.zeros((1, 6, 1), dtype=np.float32)

        monkeypatch.setattr(litert_mod, "Interpreter", _StubInterpreter)
        # 5 detections exercising TP (small cls 0), duplicate_fp (same small cls 0), class_confusion_fp (cls 0 on medium cls 1),
        # localization_fp (shifted cls 0 on large cls 0, IoU ~0.25), background_fp (conf=0.27 in [0.2, 0.3) bin)
        fake_dets = [
            {"class_id": 0, "confidence": 0.85, "box": [0.085, 0.085, 0.115, 0.115]},  # TP small
            {"class_id": 0, "confidence": 0.75, "box": [0.085, 0.085, 0.115, 0.115]},  # duplicate_fp
            {"class_id": 0, "confidence": 0.65, "box": [0.45, 0.45, 0.55, 0.55]},      # class_confusion_fp (cls 0 on GT cls 1)
            {"class_id": 0, "confidence": 0.55, "box": [0.76, 0.76, 0.96, 0.96]},      # localization_fp (IoU ~0.35 on large cls 0)
            {"class_id": 1, "confidence": 0.27, "box": [0.01, 0.90, 0.05, 0.95]},      # background_fp in [0.2, 0.3)
        ]
        monkeypatch.setattr(eval_mod, "decode_yolov11_output", lambda *a, **kw: fake_dets)

        res = evaluate_calibration_and_tide(tmp_path / "stub.tflite", data_yaml, conf_thres=0.25)
        assert res["tide_errors"] == {
            "tp": 1,
            "background_fp": 1,
            "localization_fp": 1,
            "duplicate_fp": 1,
            "class_confusion_fp": 1,
            "missed_fn": 2,
        }
        assert res["size_bucket_recall"]["small_lt_32px"] == 1.0
        assert res["size_bucket_recall"]["medium_32_96px"] == 0.0
        assert res["size_bucket_recall"]["large_ge_96px"] == 0.0
        assert res["count_mae"] == 2.0
        assert res["fppi"] == 4.0
        bin_ranges = {b["range"] for b in res["reliability_bins"]}
        assert "0.2-0.3" in bin_ranges
        assert sum(b["count"] for b in res["reliability_bins"]) == 5

    def test_v4_albumentations_validated_by_ultralytics_and_zoomout_boxes_valid(self, tmp_path: Path) -> None:
        import inspect
        import numpy as np
        from PIL import Image
        from ultralytics.cfg import get_cfg

        # Default leaf_empty_oversample_factor matches CLI default (1)
        sig = inspect.signature(build_isolated_dataset_views)
        assert sig.parameters["leaf_empty_oversample_factor"].default == 1

        # Custom Albumentations list accepted cleanly by live Ultralytics get_cfg
        augs = _build_albumentations_list()
        assert len(augs) == 8
        cfg = get_cfg(overrides={"augmentations": augs})
        assert len(cfg.augmentations) == 8

        # Zoom-out & NFT portrait generator keeps all bbox coordinates strictly inside [0, 1] and preserves class IDs
        src_imgs = tmp_path / "src" / "images"
        src_lbls = tmp_path / "src" / "labels"
        dst_imgs = tmp_path / "dst" / "images"
        dst_lbls = tmp_path / "dst" / "labels"
        for d in (src_imgs, src_lbls, dst_imgs, dst_lbls):
            d.mkdir(parents=True)
        rng = np.random.default_rng(9)
        for name, lbl in (
            ("pos__wf1.jpg", "0 0.5 0.5 0.25 0.25\n"),
            ("pos__wf2.jpg", "0 0.4 0.6 0.25 0.25\n"),
            ("pos__ap1.jpg", "1 0.3 0.7 0.20 0.20\n"),
            ("pos__ap2.jpg", "1 0.6 0.4 0.20 0.20\n"),
            ("neg__leaf_empty__bg1.jpg", ""),
        ):
            Image.fromarray(rng.integers(50, 180, size=(320, 320, 3), dtype=np.uint8)).save(src_imgs / name)
            (src_lbls / f"{Path(name).stem}.txt").write_text(lbl, encoding="utf-8")

        stats = _generate_zoomout_small_pest_views(
            sorted(src_imgs.glob("*.jpg")), src_lbls, dst_imgs, dst_lbls, max_zoomout_per_class=6, seed=42
        )
        assert stats["zoomout_total"] == 12
        assert stats["zoomout_whitefly"] == 6 and stats["zoomout_aphids"] == 6
        generated_lbls = sorted(dst_lbls.glob("*.txt"))
        assert len(generated_lbls) == 12
        assert any(p.name.startswith("nftzoom_c") for p in generated_lbls)
        for lp in generated_lbls:
            lines = [ln.strip() for ln in lp.read_text(encoding="utf-8").splitlines() if ln.strip()]
            assert lines, f"Empty zoomout label: {lp.name}"
            for ln in lines:
                cid, cx, cy, bw, bh = [float(x) for x in ln.split()]
                assert int(cid) in (0, 1)
                assert 0.0 < cx < 1.0 and 0.0 < cy < 1.0
                assert 0.0 < bw <= 1.0 and 0.0 < bh <= 1.0

    @pytest.mark.production_artifact
    def test_production_dataset_provenance_has_zero_temporal_and_family_leakage(self) -> None:
        repo_root = Path(__file__).resolve().parents[2]
        prov_path = repo_root / "ml" / "reports" / "dataset_provenance.json"
        prov = json.loads(prov_path.read_text(encoding="utf-8"))
        ver = prov.get("verification", {})
        assert ver.get("cross_split_temporal_session_overlaps") == 0, f"Temporal session leakage found: {ver}"
        assert ver.get("cross_split_loose_scene_family_overlaps") == 0, f"Loose scene-family leakage found: {ver}"
        assert int(ver.get("group_hamming_distance", 0)) >= 4

    @pytest.mark.production_artifact
    def test_production_tflite_passes_map75_and_overexposure_stress_gates(self) -> None:
        repo_root = Path(__file__).resolve().parents[2]
        report = json.loads((repo_root / "ml" / "reports" / "evaluation_report.json").read_text(encoding="utf-8"))
        tflite_metrics = report.get("tflite_eval", {}).get("metrics", {})
        assert float(tflite_metrics.get("map75", 0.0)) >= PROMOTION_GATES["map75"][1], (
            f"Mobile 640x640 TFLite mAP@75 below v4 gate: {tflite_metrics}"
        )

        tflite_path = repo_root / "apps" / "mobile" / "assets" / "ml" / "yolo11n_lettuce_pests.tflite"
        data_yaml = repo_root / "ml" / "data" / "merged_lettuce_pests" / "data.yaml"
        if not data_yaml.is_file():
            pytest.skip("Local merged test split not present")
        meta = json.loads((repo_root / "apps" / "mobile" / "assets" / "ml" / "model_metadata.json").read_text(encoding="utf-8"))
        stress = evaluate_domain_shift_stress(
            tflite_path,
            data_yaml,
            conf_thres=float(meta["confidence_threshold"]),
        )
        assert stress["overexposure_recall"] >= PROMOTION_GATES["overexposure_recall"][1], (
            f"Mobile TFLite failed midday sunlight overexposure stress gate: {stress}"
        )
