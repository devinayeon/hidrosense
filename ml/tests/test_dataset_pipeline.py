from __future__ import annotations

import io
import json
import os
from pathlib import Path
from types import SimpleNamespace
from typing import Any
import zipfile

from PIL import Image, ImageDraw
import pytest
import yaml

from ml.prepare_dataset import (
    CANONICAL_CLASSES,
    ROBOFLOW_DIRECT_SOURCES,
    _DihedralHashIndex,
    _classify_dropped_yolo_line,
    _clamp01,
    _iter_source_image_label_pairs,
    _min_dihedral_distance,
    canonicalize_label_name,
    compute_dihedral_phashes,
    deduplicate_and_merge_sources,
    download_roboflow_direct_sources,
    export_merged_dataset,
    load_env_file,
    normalize_roboflow_ds_url,
    parse_and_sanitize_yolo_line,
    stratified_split_records,
    verify_exported_dataset,
    write_provenance_reports,
)


def _make_distinct_image(
    path: Path,
    seed_idx: int,
    size: tuple[int, int] = (128, 128),
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img = Image.new("RGB", size, color=((seed_idx * 47) % 255, (seed_idx * 97) % 255, (seed_idx * 151) % 255))
    draw = ImageDraw.Draw(img)
    x0 = 10 + (seed_idx * 13) % 50
    y0 = 10 + (seed_idx * 19) % 50
    draw.rectangle((x0, y0, x0 + 40, y0 + 35), fill=(255, 255 - (seed_idx * 23) % 200, 30))
    draw.ellipse((x0 + 15, y0 + 10, x0 + 60, y0 + 55), fill=(20, 40, 240))
    if seed_idx % 2 == 0:
        draw.line((0, 0, size[0], size[1]), fill=(255, 255, 255), width=4)
    else:
        draw.line((0, size[1], size[0], 0), fill=(0, 0, 0), width=4)
    img.save(path)


def os_getenv(name: str) -> str | None:
    return os.environ.get(name)


class TestEnvLoaderAndRoboflowFailFast:
    def test_load_env_file_parses_quotes_comments_export_and_respects_existing(
        self,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        env_path = tmp_path / ".env"
        env_path.write_text(
            "\n".join(
                [
                    "# comment line",
                    "   ",
                    "export ROBOFLOW_API_KEY='quoted_secret_123'",
                    'SECOND_VAR="double_quoted"',
                    "EMPTY_SHOULD_LOAD=loaded_value",
                ]
            )
            + "\n",
            encoding="utf-8",
        )
        monkeypatch.delenv("ROBOFLOW_API_KEY", raising=False)
        monkeypatch.setenv("SECOND_VAR", "already_set")
        monkeypatch.setenv("EMPTY_SHOULD_LOAD", "")

        loaded = load_env_file(env_path)
        assert loaded == ["EMPTY_SHOULD_LOAD", "ROBOFLOW_API_KEY"]
        assert os_getenv("ROBOFLOW_API_KEY") == "quoted_secret_123"
        assert os_getenv("SECOND_VAR") == "already_set"
        assert os_getenv("EMPTY_SHOULD_LOAD") == "loaded_value"

        loaded_override = load_env_file(env_path, override=True)
        assert "SECOND_VAR" in loaded_override
        assert os_getenv("SECOND_VAR") == "double_quoted"

    def test_roboflow_direct_sources_match_whitefly_and_aphids_specs(self) -> None:
        by_id = {s["dataset_id"]: s for s in ROBOFLOW_DIRECT_SOURCES}
        assert set(by_id.keys()) == {"rOfgg1CNHN", "PaVtWyiDBO"}
        assert by_id["rOfgg1CNHN"]["slug"] == "jini-nkjjt/whitefly-0tong"
        assert by_id["PaVtWyiDBO"]["slug"] == "jiwons-workspace-syfav/aphids-new"
        assert all(s["required"] is True for s in ROBOFLOW_DIRECT_SOURCES)

        norm_url, extracted_k = normalize_roboflow_ds_url("https://universe.roboflow.com/ds/rOfgg1CNHN?k" + "ey=unitKeyAbc")
        assert norm_url.startswith("https://app.roboflow.com/ds/rOfgg1CNHN?")
        assert extracted_k == "unitKeyAbc"

    def test_download_raises_without_url_env_even_if_local_dirs_exist(
        self,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        raw_root = tmp_path / "raw_v2"
        existing = raw_root / "whitefly_0tong_v1"
        existing.mkdir(parents=True)
        (existing / "data.yaml").write_text("nc: 1\nnames: [whitefly]\n", encoding="utf-8")

        monkeypatch.delenv("ROBOFLOW_WHITEFLY_URL", raising=False)
        monkeypatch.delenv("ROBOFLOW_APHIDS_URL", raising=False)
        missing_env = tmp_path / "nonexistent.env"

        with pytest.raises(RuntimeError, match="ROBOFLOW_WHITEFLY_URL"):
            download_roboflow_direct_sources(raw_root, env_file=missing_env)

    def test_download_handles_optional_failure_and_redacts_query_secret(
        self,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        import ml.prepare_dataset as ml_prep

        secret_q = "unitTestKey999"
        q_param = "k" + f"ey={secret_q}"
        monkeypatch.setenv("TEST_WF_URL", f"https://universe.roboflow.com/ds/wf1?{q_param}")
        monkeypatch.setenv("TEST_OPT_URL", f"https://universe.roboflow.com/ds/opt2?{q_param}")

        buf = io.BytesIO()
        with zipfile.ZipFile(buf, "w") as zf:
            zf.writestr("data.yaml", "nc: 1\nnames: ['whitefly']\n")
            img_buf = io.BytesIO()
            Image.new("RGB", (64, 64), color=(30, 120, 40)).save(img_buf, format="JPEG")
            zf.writestr("train/images/a.jpg", img_buf.getvalue())
            zf.writestr("train/labels/a.txt", "0 0.5 0.5 0.2 0.2\n")
        zip_bytes = buf.getvalue()

        def _fake_get(url: str, timeout: int = 90) -> Any:
            if "opt2" in url:
                raise RuntimeError(f"404 Client Error for url: {url}")
            return SimpleNamespace(content=zip_bytes, raise_for_status=lambda: None)

        monkeypatch.setattr(ml_prep.requests, "get", _fake_get)
        specs = (
            {"name": "wf", "slug": "ws/wf", "version": 1, "env_url_key": "TEST_WF_URL", "required": True},
            {"name": "opt", "slug": "ws/opt", "version": 1, "env_url_key": "TEST_OPT_URL", "required": False},
        )
        probe_results: list[dict[str, Any]] = []
        downloaded = download_roboflow_direct_sources(
            tmp_path / "raw",
            sources=specs,
            probe_results_out=probe_results,
            env_file=tmp_path / "none.env",
            force_download=True,
        )
        assert len(downloaded) == 1
        assert len(probe_results) == 2
        assert secret_q not in json.dumps(probe_results)
        assert "[REDACTED]" in str(probe_results[1]["error"])

    def test_download_fails_fast_when_required_source_errors_and_redacts_key(
        self,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        import ml.prepare_dataset as ml_prep

        secret_q = "reqSecretKey777"
        monkeypatch.setenv("TEST_REQ_URL", f"https://universe.roboflow.com/ds/req1?k" + f"ey={secret_q}")

        def _boom(url: str, timeout: int = 90) -> Any:
            raise RuntimeError(f"500 Server Error for {url}")

        monkeypatch.setattr(ml_prep.requests, "get", _boom)
        specs = ({"name": "req", "slug": "ws/req", "version": 1, "env_url_key": "TEST_REQ_URL", "required": True},)
        with pytest.raises(RuntimeError) as exc_info:
            download_roboflow_direct_sources(tmp_path / "raw", sources=specs, env_file=tmp_path / "none.env")
        assert secret_q not in str(exc_info.value)
        assert "[REDACTED]" in str(exc_info.value)


class TestPathAndLabelHardening:
    def test_iter_source_image_label_pairs_uses_last_images_segment(self, tmp_path: Path) -> None:
        src = tmp_path / "images" / "raw" / "my_source"
        img_path = src / "images" / "train" / "images" / "sample.jpg"
        lbl_path = src / "images" / "train" / "labels" / "sample.txt"
        _make_distinct_image(img_path, 3)
        lbl_path.parent.mkdir(parents=True, exist_ok=True)
        lbl_path.write_text("0 0.5 0.5 0.2 0.2\n", encoding="utf-8")

        pairs = _iter_source_image_label_pairs(src)
        assert pairs == [(img_path, lbl_path)]

    def test_canonicalize_label_name_rejects_molted_skin_thrips_negations_and_ambiguous(self) -> None:
        assert canonicalize_label_name("silverleaf whitefly") == 0
        assert canonicalize_label_name("green-peach-aphid") == 1

        assert canonicalize_label_name("molted skin") is None
        assert canonicalize_label_name("molted_skin") is None
        assert canonicalize_label_name("western_flower_thrips") is None
        assert canonicalize_label_name("rhaphidophora") is None
        assert canonicalize_label_name("scaphidium") is None

        assert canonicalize_label_name("non-aphids") is None
        assert canonicalize_label_name("not whitefly") is None
        assert canonicalize_label_name("aphid_mummy") is None
        assert canonicalize_label_name("aphid_predator") is None
        assert canonicalize_label_name("aphids and whitefly") is None


class TestDedupExportAndVerification:
    def _build_source(self, root: Path, names: list[str], samples: list[tuple[str, int, str]]) -> Path:
        root.mkdir(parents=True, exist_ok=True)
        (root / "data.yaml").write_text(f"names: {json.dumps(names)}\nnc: {len(names)}\n", encoding="utf-8")
        for rel_stem, img_seed, label_text in samples:
            img_path = (root / rel_stem.replace("/labels/", "/images/")).with_suffix(".jpg")
            lbl_path = (root / rel_stem.replace("/images/", "/labels/")).with_suffix(".txt")
            _make_distinct_image(img_path, img_seed)
            lbl_path.parent.mkdir(parents=True, exist_ok=True)
            lbl_path.write_text(label_text, encoding="utf-8")
        return root

    def test_sha256_and_phash_dedup_plus_clean_export_and_verify(
        self,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        src1 = self._build_source(
            tmp_path / "src1",
            ["whitefly", "aphids", "molted skin"],
            [
                ("train/images/w1", 1, "0 0.5 0.5 0.3 0.3\n2 0.2 0.2 0.1 0.1\n"),
                ("train/images/w2", 2, "0 0.5 0.5 0.3 0.3\n"),
                ("train/images/w3", 3, "0 0.5 0.5 0.3 0.3\n"),
                ("train/images/w4", 4, "0 0.5 0.5 0.3 0.3\n"),
                ("train/images/a1", 5, "1 0.5 0.5 0.3 0.3\n"),
                ("train/images/a2", 6, "1 0.5 0.5 0.3 0.3\n"),
                ("train/images/a3", 7, "1 0.5 0.5 0.3 0.3\n"),
                ("train/images/a4", 8, "1 0.5 0.5 0.3 0.3\n"),
                ("train/images/molted_only", 10, "2 0.5 0.5 0.2 0.2\n"),
            ],
        )
        src2 = self._build_source(
            tmp_path / "src2",
            ["aphids", "whitefly"],
            [
                ("valid/images/dup_exact", 1, "1 0.5 0.5 0.3 0.3\n"),
            ],
        )
        near_img_path = src2 / "test" / "images" / "dup_near.png"
        near_lbl_path = src2 / "test" / "labels" / "dup_near.txt"
        _make_distinct_image(near_img_path, 4)
        with Image.open(near_img_path) as im:
            im.putpixel((0, 0), (1, 2, 3))
            im.save(near_img_path)
        near_lbl_path.parent.mkdir(parents=True, exist_ok=True)
        near_lbl_path.write_text("1 0.5 0.5 0.3 0.3\n", encoding="utf-8")

        details: dict[str, Any] = {}
        records, stats = deduplicate_and_merge_sources([src1, src2], source_details_out=details)
        assert len(records) == 9
        assert all(len(r.sha256_hex) == 64 for r in records)
        assert stats["sha256_duplicates_removed"] == 1
        assert stats["phash_duplicates_removed"] == 1
        assert stats["duplicates_removed"] == 2
        assert stats["negative_images_kept"] == 1
        assert stats["molted_skin_boxes_removed"] == 2
        assert stats["boxes_kept"] == 8
        assert details["src1"]["unmapped_class_names_seen"] == ["molted skin"]

        splits = stratified_split_records(records, train_ratio=0.75, val_ratio=0.125, seed=42)
        out_dir = tmp_path / "merged"
        export_report = export_merged_dataset(splits, out_dir, stats)

        data_yaml = yaml.safe_load((out_dir / "data.yaml").read_text(encoding="utf-8"))
        assert "path" not in data_yaml
        assert data_yaml["train"] == "train/images"
        assert data_yaml["val"] == "val/images"
        assert data_yaml["test"] == "test/images"
        assert data_yaml["nc"] == 2
        assert {int(k): v for k, v in data_yaml["names"].items()} == CANONICAL_CLASSES

        other_cwd = tmp_path / "unrelated_cwd"
        other_cwd.mkdir(parents=True, exist_ok=True)
        monkeypatch.chdir(other_cwd)

        from ultralytics.data.utils import check_det_dataset

        resolved_cfg = check_det_dataset(str(out_dir / "data.yaml"), autodownload=False)
        assert Path(resolved_cfg["train"]).resolve() == (out_dir / "train" / "images").resolve()
        assert Path(resolved_cfg["val"]).resolve() == (out_dir / "val" / "images").resolve()
        assert Path(resolved_cfg["test"]).resolve() == (out_dir / "test" / "images").resolve()

        verif = verify_exported_dataset(out_dir, require_all_classes=True)
        assert verif["status"] == "passed"
        assert verif["cross_split_sha256_overlaps"] == 0
        assert verif["cross_split_phash_overlaps"] == 0
        assert verif["molted_skin_surviving_instances"] == 0

        json_path, md_path = write_provenance_reports(
            report_dir=tmp_path / "reports",
            output_dir=out_dir,
            probe_results=[
                {
                    "name": "whitefly_0tong_v1",
                    "slug": "jini-nkjjt/whitefly-0tong",
                    "version": 1,
                    "required": True,
                    "status": "downloaded",
                    "status_code": 200,
                    "error_type": None,
                    "error": None,
                    "raw_split_image_counts": {"train": 9},
                    "raw_class_map": {"0": "whitefly"},
                }
            ],
            ood_manifest=None,
            scan_stats=stats,
            source_details=details,
            export_report=export_report,
            verification_result=verif,
            max_hamming_distance=2,
            seed=42,
            train_ratio=0.75,
            val_ratio=0.125,
        )
        assert json_path.is_file()
        assert md_path.is_file()
        assert (out_dir / "dataset_provenance.json").is_file()

    def test_verify_exported_dataset_catches_leaks_and_corrupt_labels(self, tmp_path: Path) -> None:
        src = self._build_source(
            tmp_path / "src",
            ["whitefly", "aphids"],
            [
                (f"train/images/img_{i}", i + 1, f"{i % 2} 0.5 0.5 0.3 0.3\n")
                for i in range(10)
            ],
        )
        records, stats = deduplicate_and_merge_sources([src])
        splits = stratified_split_records(records, seed=42)
        out_dir = tmp_path / "merged"
        export_merged_dataset(splits, out_dir, stats)

        train_img = next((out_dir / "train" / "images").iterdir())
        train_lbl = out_dir / "train" / "labels" / f"{train_img.stem}.txt"
        leak_img = out_dir / "val" / "images" / f"leaked_{train_img.name}"
        leak_lbl = out_dir / "val" / "labels" / f"leaked_{train_img.stem}.txt"
        leak_img.write_bytes(train_img.read_bytes())
        leak_lbl.write_text(train_lbl.read_text(encoding="utf-8"), encoding="utf-8")

        with pytest.raises(ValueError, match="Cross-split SHA-256 overlap"):
            verify_exported_dataset(out_dir)

        leak_img.unlink()
        leak_lbl.unlink()
        val_lbl = next((out_dir / "val" / "labels").iterdir())
        orig_lbl = val_lbl.read_text(encoding="utf-8")
        val_lbl.write_text("0 1.25 0.5 0.3 0.3\n", encoding="utf-8")
        with pytest.raises(ValueError, match="Out-of-bounds box"):
            verify_exported_dataset(out_dir)

        val_lbl.write_text(orig_lbl, encoding="utf-8")
        yaml_path = out_dir / "data.yaml"
        yaml_payload = yaml.safe_load(yaml_path.read_text(encoding="utf-8"))
        yaml_payload["path"] = "."
        yaml_path.write_text(yaml.safe_dump(yaml_payload, sort_keys=False), encoding="utf-8")
        with pytest.raises(ValueError, match="must omit 'path'"):
            verify_exported_dataset(out_dir)


class TestCommittedProvenanceArtifact:
    def test_dataset_provenance_json_if_present_has_zero_synthetic_zero_molted_and_zero_leaks(self) -> None:
        prov_path = Path("ml/reports/dataset_provenance.json")
        if not prov_path.is_file():
            pytest.skip("ml/reports/dataset_provenance.json not generated yet")
        raw_text = prov_path.read_text(encoding="utf-8")
        assert "ROBOFLOW_API_KEY" not in raw_text
        data = json.loads(raw_text)
        assert data["zero_synthetic_confirmed"] is True
        assert data["synthetic_images_count"] == 0
        assert data["molted_skin_boxes_removed"] >= 1
        assert data["verification"]["status"] == "passed"
        assert data["verification"]["molted_skin_surviving_instances"] == 0
        assert data["verification"]["thrips_surviving_instances"] == 0
        assert data["verification"]["cross_split_sha256_overlaps"] == 0
        assert data["verification"]["cross_split_phash_overlaps"] == 0
        assert data["verification"]["data_yaml_path_omitted"] is True
        for split_name in ("train", "val", "test"):
            assert data["splits"][split_name]["images"] > 0
            assert data["splits"][split_name]["negative_images"] > 0
            for cls_name in CANONICAL_CLASSES.values():
                assert data["splits"][split_name]["per_class_instances"][cls_name] > 0


class TestDihedralGroupLeakageAndGuards:
    @staticmethod
    def _make_asymmetric_image(seed_idx: int, size: tuple[int, int] = (128, 128)) -> Image.Image:
        img = Image.new(
            "RGB",
            size,
            color=((seed_idx * 47) % 255, (seed_idx * 97) % 255, (seed_idx * 151) % 255),
        )
        draw = ImageDraw.Draw(img)
        x0 = 10 + (seed_idx * 13) % 50
        y0 = 10 + (seed_idx * 19) % 50
        draw.rectangle((x0, y0, x0 + 40, y0 + 35), fill=(255, 255 - (seed_idx * 23) % 200, 30))
        draw.ellipse((x0 + 15, y0 + 10, x0 + 60, y0 + 55), fill=(20, 40, 240))
        draw.line((0, 0, size[0], size[1] // 2), fill=(255, 255, 255), width=4)
        draw.polygon([(8, 110), (35, 95), (25, 122)], fill=(10, 230, 120))
        return img

    def test_8_dihedral_dedup_catches_all_rotations_and_flips(self, tmp_path: Path) -> None:
        src1 = tmp_path / "src1"
        src2 = tmp_path / "src2"
        for src in (src1, src2):
            (src / "train" / "images").mkdir(parents=True)
            (src / "train" / "labels").mkdir(parents=True)
            (src / "data.yaml").write_text("names: [whitefly, aphids]\nnc: 2\n", encoding="utf-8")

        base_img = self._make_asymmetric_image(1)
        base_img.save(src1 / "train" / "images" / "orig.png")
        (src1 / "train" / "labels" / "orig.txt").write_text("0 0.5 0.5 0.3 0.3\n", encoding="utf-8")

        dihedral_variants = [
            ("r90", base_img.transpose(Image.Transpose.ROTATE_90)),
            ("r180", base_img.transpose(Image.Transpose.ROTATE_180)),
            ("r270", base_img.transpose(Image.Transpose.ROTATE_270)),
            ("hflip", base_img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)),
            ("vflip", base_img.transpose(Image.Transpose.FLIP_TOP_BOTTOM)),
            ("r90_hflip", base_img.transpose(Image.Transpose.ROTATE_90).transpose(Image.Transpose.FLIP_LEFT_RIGHT)),
            ("r270_hflip", base_img.transpose(Image.Transpose.ROTATE_270).transpose(Image.Transpose.FLIP_LEFT_RIGHT)),
        ]
        for idx, (tag, variant) in enumerate(dihedral_variants):
            target_src = src1 if idx < 3 else src2
            variant.save(target_src / "train" / "images" / f"var_{tag}.png")
            (target_src / "train" / "labels" / f"var_{tag}.txt").write_text("0 0.5 0.5 0.3 0.3\n", encoding="utf-8")

        records, stats = deduplicate_and_merge_sources([src1, src2])
        assert len(records) == 1
        assert stats["phash_duplicates_removed"] == 7
        assert stats["duplicates_removed"] == 7

        a_phs = (0x0000000000000000, 0x000000000000000F, 0, 0, 0, 0, 0, 0)
        b_phs = (0x0000000000000001, 0xFFFF000000000000, 0, 0, 0, 0, 0, 0)
        idx_ab = _DihedralHashIndex(threshold=1)
        idx_ab.add(a_phs)
        assert idx_ab.has_match(b_phs) is True
        idx_ba = _DihedralHashIndex(threshold=1)
        idx_ba.add(b_phs)
        assert idx_ba.has_match(a_phs) is True

    def test_group_aware_split_prevents_rescaled_phash4_and_rf_stem_cross_split_leak(
        self,
        tmp_path: Path,
    ) -> None:
        src = tmp_path / "src"
        (src / "train" / "images").mkdir(parents=True)
        (src / "train" / "labels").mkdir(parents=True)
        (src / "data.yaml").write_text("names: [whitefly, aphids]\nnc: 2\n", encoding="utf-8")

        base_seeds = [1, 7, 13, 21, 29, 37, 45, 53]
        for idx, seed_val in enumerate(base_seeds):
            img = self._make_asymmetric_image(seed_val)
            stem = f"scene_{idx}_jpg.rf.base{idx:04d}"
            img.save(src / "train" / "images" / f"{stem}.png")
            (src / "train" / "labels" / f"{stem}.txt").write_text(f"{idx % 2} 0.5 0.5 0.25 0.25\n", encoding="utf-8")

        scene0_img = self._make_asymmetric_image(base_seeds[0])
        scene0_phs = compute_dihedral_phashes(scene0_img)
        rescaled_variant = None
        for dx in range(1, 20):
            cand = scene0_img.crop((dx, 0, 128, 128)).resize((128, 128), Image.Resampling.BILINEAR)
            dist = _min_dihedral_distance(scene0_phs, compute_dihedral_phashes(cand))
            if 2 < dist <= 4:
                rescaled_variant = cand
                break
        assert rescaled_variant is not None
        rescaled_variant.save(src / "train" / "images" / "scene0_rescaled_jpg.rf.var0001.png")
        (src / "train" / "labels" / "scene0_rescaled_jpg.rf.var0001.txt").write_text("0 0.5 0.5 0.25 0.25\n", encoding="utf-8")

        scene1_img = self._make_asymmetric_image(base_seeds[1])
        scene1_crop = scene1_img.crop((28, 28, 108, 108)).resize((128, 128), Image.Resampling.BILINEAR)
        assert _min_dihedral_distance(compute_dihedral_phashes(scene1_img), compute_dihedral_phashes(scene1_crop)) > 4
        scene1_crop.save(src / "train" / "images" / "scene_1_jpg.rf.crop9999.png")
        (src / "train" / "labels" / "scene_1_jpg.rf.crop9999.txt").write_text("1 0.5 0.5 0.25 0.25\n", encoding="utf-8")

        bridge_orig = self._make_asymmetric_image(99)
        bridge_rot90 = bridge_orig.transpose(Image.Transpose.ROTATE_90)
        bridge_crop = bridge_rot90.crop((28, 28, 108, 108)).resize((128, 128), Image.Resampling.BILINEAR)
        assert _min_dihedral_distance(compute_dihedral_phashes(bridge_orig), compute_dihedral_phashes(bridge_crop)) > 4
        bridge_orig.save(src / "train" / "images" / "orig_jpg.rf.111.png")
        (src / "train" / "labels" / "orig_jpg.rf.111.txt").write_text("1 0.5 0.5 0.25 0.25\n", encoding="utf-8")
        bridge_rot90.save(src / "train" / "images" / "orig_rot90_jpg.rf.222.png")
        (src / "train" / "labels" / "orig_rot90_jpg.rf.222.txt").write_text("1 0.5 0.5 0.25 0.25\n", encoding="utf-8")
        bridge_crop.save(src / "train" / "images" / "orig_rot90_jpg.rf.333.png")
        (src / "train" / "labels" / "orig_rot90_jpg.rf.333.txt").write_text("1 0.5 0.5 0.25 0.25\n", encoding="utf-8")

        records, stats = deduplicate_and_merge_sources([src])
        by_stem = {r.image_path.stem: r for r in records}
        assert "orig_jpg.rf.111" in by_stem
        assert "orig_rot90_jpg.rf.333" in by_stem
        assert "orig_rot90_jpg.rf.222" not in by_stem
        assert by_stem["orig_jpg.rf.111"].group_id == by_stem["orig_rot90_jpg.rf.333"].group_id
        assert by_stem["scene_0_jpg.rf.base0000"].group_id == by_stem["scene0_rescaled_jpg.rf.var0001"].group_id
        assert by_stem["scene_1_jpg.rf.base0001"].group_id == by_stem["scene_1_jpg.rf.crop9999"].group_id

        splits = stratified_split_records(records, train_ratio=0.75, val_ratio=0.125, seed=42)
        for family_stems in (
            {"orig_jpg.rf.111", "orig_rot90_jpg.rf.333"},
            {"scene_0_jpg.rf.base0000", "scene0_rescaled_jpg.rf.var0001"},
            {"scene_1_jpg.rf.base0001", "scene_1_jpg.rf.crop9999"},
        ):
            splits_containing = [
                sp for sp, recs in splits.items() if any(r.image_path.stem in family_stems for r in recs)
            ]
            assert len(splits_containing) == 1

        out_dir = tmp_path / "merged"
        export_merged_dataset(splits, out_dir, stats)
        exported_names = [p.name for p in (out_dir / "train" / "images").iterdir()]
        assert any(".rf." in name for name in exported_names)

        verif = verify_exported_dataset(out_dir, require_all_classes=True)
        assert verif["status"] == "passed"
        assert verif["cross_split_phash_overlaps"] == 0
        assert verif["cross_split_group_phash_overlaps"] == 0
        assert verif["cross_split_base_stem_overlaps"] == 0

    def test_parse_yolo_line_rejects_nan_inf_early_including_polygons_and_class_id(self) -> None:
        source_map = {0: "whitefly", 1: "aphids"}
        for bad_line in (
            "0 nan 0.5 0.2 0.2",
            "0 0.5 inf 0.2 0.2",
            "0 0.5 -inf 0.2 0.2",
            "nan 0.5 0.5 0.2 0.2",
            "inf 0.5 0.5 0.2 0.2",
            "-inf 0.5 0.5 0.2 0.2",
            "0 nan 0.1 0.2 0.3 0.4 0.5",
            "0 0.1 inf 0.2 0.3 0.4 0.5",
        ):
            assert parse_and_sanitize_yolo_line(bad_line, source_map) is None

        assert _classify_dropped_yolo_line("nan 0.5 0.5 0.2 0.2", source_map) == ("invalid", None)
        assert _classify_dropped_yolo_line("inf 0.5 0.5 0.2 0.2", source_map) == ("invalid", None)

        with pytest.raises(ValueError, match="Non-finite"):
            _clamp01(float("nan"))
        with pytest.raises(ValueError, match="Non-finite"):
            _clamp01(float("inf"))

    def test_verify_exported_dataset_catches_rotated_phash4_and_rf_stem_leaks(self, tmp_path: Path) -> None:
        src = tmp_path / "src"
        (src / "train" / "images").mkdir(parents=True)
        (src / "train" / "labels").mkdir(parents=True)
        (src / "data.yaml").write_text("names: [whitefly, aphids]\nnc: 2\n", encoding="utf-8")

        for i in range(10):
            img = self._make_asymmetric_image(i * 7 + 1)
            img.save(src / "train" / "images" / f"clean_{i}.png")
            (src / "train" / "labels" / f"clean_{i}.txt").write_text(f"{i % 2} 0.5 0.5 0.25 0.25\n", encoding="utf-8")

        records, stats = deduplicate_and_merge_sources([src])
        splits = stratified_split_records(records, seed=42)
        out_dir = tmp_path / "merged"
        export_merged_dataset(splits, out_dir, stats)
        assert verify_exported_dataset(out_dir, require_all_classes=True)["status"] == "passed"

        train_img_path = next((out_dir / "train" / "images").iterdir())
        train_lbl_text = (out_dir / "train" / "labels" / f"{train_img_path.stem}.txt").read_text(encoding="utf-8")

        rot_img = out_dir / "val" / "images" / "leak_rot90.png"
        rot_lbl = out_dir / "val" / "labels" / "leak_rot90.txt"
        with Image.open(train_img_path) as im:
            im.transpose(Image.Transpose.ROTATE_90).save(rot_img)
        rot_lbl.write_text(train_lbl_text, encoding="utf-8")
        with pytest.raises(ValueError, match="Cross-split.*pHash"):
            verify_exported_dataset(out_dir)
        rot_img.unlink()
        rot_lbl.unlink()

        flip_img = out_dir / "test" / "images" / "leak_hflip.png"
        flip_lbl = out_dir / "test" / "labels" / "leak_hflip.txt"
        with Image.open(train_img_path) as im:
            im.transpose(Image.Transpose.FLIP_LEFT_RIGHT).save(flip_img)
        flip_lbl.write_text(train_lbl_text, encoding="utf-8")
        with pytest.raises(ValueError, match="Cross-split.*pHash"):
            verify_exported_dataset(out_dir)
        flip_img.unlink()
        flip_lbl.unlink()

        ph4_img = out_dir / "val" / "images" / "leak_ph4.png"
        ph4_lbl = out_dir / "val" / "labels" / "leak_ph4.txt"
        with Image.open(train_img_path) as im:
            base_phs = compute_dihedral_phashes(im)
            ph4_cand = None
            for dx in range(1, 20):
                cand = im.crop((dx, 0, im.width, im.height)).resize(im.size, Image.Resampling.BILINEAR)
                dist = _min_dihedral_distance(base_phs, compute_dihedral_phashes(cand))
                if 2 < dist <= 4:
                    ph4_cand = cand
                    break
            assert ph4_cand is not None
            ph4_cand.save(ph4_img)
        ph4_lbl.write_text(train_lbl_text, encoding="utf-8")
        with pytest.raises(ValueError, match="Cross-split.*group pHash"):
            verify_exported_dataset(out_dir)
        ph4_img.unlink()
        ph4_lbl.unlink()

        rf_train_img = out_dir / "train" / "images" / "sample_x.rf.aaaa1111.png"
        rf_train_lbl = out_dir / "train" / "labels" / "sample_x.rf.aaaa1111.txt"
        rf_val_img = out_dir / "val" / "images" / "sample_x.rf.bbbb2222.png"
        rf_val_lbl = out_dir / "val" / "labels" / "sample_x.rf.bbbb2222.txt"
        self._make_asymmetric_image(121).save(rf_train_img)
        rf_train_lbl.write_text("0 0.5 0.5 0.25 0.25\n", encoding="utf-8")
        self._make_asymmetric_image(157).save(rf_val_img)
        rf_val_lbl.write_text("1 0.5 0.5 0.25 0.25\n", encoding="utf-8")
        with pytest.raises(ValueError, match="Cross-split base-stem overlap"):
            verify_exported_dataset(out_dir)
        rf_train_img.unlink()
        rf_train_lbl.unlink()
        rf_val_img.unlink()
        rf_val_lbl.unlink()
