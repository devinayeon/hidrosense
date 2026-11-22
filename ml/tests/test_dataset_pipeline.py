from __future__ import annotations

import json
import sys
from pathlib import Path
from types import SimpleNamespace
from typing import Any

from PIL import Image, ImageDraw
import pytest
import yaml

from ml.prepare_dataset import (
    CANONICAL_CLASSES,
    ROBOFLOW_SOURCES,
    _DihedralHashIndex,
    _classify_dropped_yolo_line,
    _clamp01,
    _iter_source_image_label_pairs,
    _min_dihedral_distance,
    canonicalize_label_name,
    compute_dihedral_phashes,
    deduplicate_and_merge_sources,
    download_roboflow_sources,
    export_merged_dataset,
    load_env_file,
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

    def test_roboflow_sources_match_confirmed_versions_and_optional_probe(self) -> None:
        by_slug = {f"{s['workspace']}/{s['project']}": s for s in ROBOFLOW_SOURCES}
        assert by_slug["puzzle-piece-detection/lettuce-pests"]["version"] == 6
        assert by_slug["puzzle-piece-detection/lettuce-pests"]["required"] is True
        assert by_slug["puzzle-piece-detection/lettuce-pest-detection"]["version"] == 1
        assert by_slug["puzzle-piece-detection/lettuce-pest-detection"]["required"] is True
        assert by_slug["agrivision-2025/lettuce-pests-wieje"]["required"] is False

    def test_download_raises_without_api_key_even_if_local_dirs_exist(
        self,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        raw_root = tmp_path / "raw_roboflow"
        existing = raw_root / "puzzle-piece-detection_lettuce-pests_v6"
        existing.mkdir(parents=True)
        (existing / "data.yaml").write_text("nc: 3\nnames: [thrips, whitefly, aphids]\n", encoding="utf-8")

        monkeypatch.delenv("ROBOFLOW_API_KEY", raising=False)
        missing_env = tmp_path / "nonexistent.env"

        with pytest.raises(RuntimeError, match="ROBOFLOW_API_KEY is required"):
            download_roboflow_sources(raw_root, api_key=None, env_file=missing_env)

    def test_download_probes_optional_404_gracefully_and_redacts_secrets(
        self,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        secret_key = "rf_super_secret_test_key_999"
        overwrite_calls: list[bool] = []

        class _FakeVersion:
            def __init__(self, dest_slug: str) -> None:
                self._slug = dest_slug

            def download(self, fmt: str, location: str, overwrite: bool = False) -> None:
                overwrite_calls.append(overwrite)
                dest = Path(location)
                (dest / "train" / "images").mkdir(parents=True, exist_ok=True)
                (dest / "train" / "labels").mkdir(parents=True, exist_ok=True)
                _make_distinct_image(dest / "train" / "images" / "a.jpg", 1)
                (dest / "train" / "labels" / "a.txt").write_text("0 0.5 0.5 0.2 0.2\n", encoding="utf-8")
                (dest / "data.yaml").write_text("names: [thrips, whitefly, aphids]\nnc: 3\n", encoding="utf-8")

        class _FakeProject:
            def __init__(self, ws: str, proj: str) -> None:
                self._ws = ws
                self._proj = proj

            def version(self, ver: int) -> _FakeVersion:
                return _FakeVersion(f"{self._ws}/{self._proj}_v{ver}")

        class _FakeWorkspace:
            def __init__(self, ws: str) -> None:
                self._ws = ws

            def project(self, proj: str) -> _FakeProject:
                if self._ws == "agrivision-2025":
                    err = RuntimeError(f"404 Not Found for https://api.roboflow.com/x?api_key={secret_key}")
                    setattr(err, "status_code", 404)
                    raise err
                return _FakeProject(self._ws, proj)

        class _FakeRoboflow:
            def __init__(self, api_key: str) -> None:
                self.onboarding = False

            def workspace(self, ws: str) -> _FakeWorkspace:
                return _FakeWorkspace(ws)

        monkeypatch.setitem(sys.modules, "roboflow", SimpleNamespace(Roboflow=_FakeRoboflow))

        raw_root = tmp_path / "raw"
        # Pre-create an empty/partial dir to verify overwrite=True runs instead of skipping!
        partial_dir = raw_root / "puzzle-piece-detection_lettuce-pests_v6"
        partial_dir.mkdir(parents=True)

        probe_results: list[dict[str, Any]] = []
        downloaded = download_roboflow_sources(
            raw_root=raw_root,
            api_key=secret_key,
            probe_results_out=probe_results,
        )

        assert len(downloaded) == 2
        assert overwrite_calls == [True, True]
        assert len(probe_results) == 3

        wieje = [p for p in probe_results if p["slug"] == "agrivision-2025/lettuce-pests-wieje"][0]
        assert wieje["accessible"] is False
        assert wieje["status"] == "unavailable"
        assert wieje["status_code"] == 404
        assert secret_key not in json.dumps(probe_results)
        assert "[REDACTED]" in str(wieje["error"])

    def test_download_fails_fast_when_required_source_errors_and_redacts_key(
        self,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        secret_key = "rf_required_secret_abc"

        class _FakeRoboflow:
            def __init__(self, api_key: str) -> None:
                self.onboarding = False

            def workspace(self, ws: str) -> Any:
                raise RuntimeError(f"500 Server Error api_key={secret_key}")

        monkeypatch.setitem(sys.modules, "roboflow", SimpleNamespace(Roboflow=_FakeRoboflow))
        with pytest.raises(RuntimeError) as exc_info:
            download_roboflow_sources(raw_root=tmp_path / "raw", api_key=secret_key)
        assert secret_key not in str(exc_info.value)
        assert "[REDACTED]" in str(exc_info.value)


def os_getenv(name: str) -> str | None:
    import os

    return os.environ.get(name)


class TestPathAndLabelHardening:
    def test_iter_source_image_label_pairs_uses_last_images_segment(self, tmp_path: Path) -> None:
        # Ancestor dir named "images" AND nested "images" dir inside source_dir
        src = tmp_path / "images" / "raw" / "my_source"
        img_path = src / "images" / "train" / "images" / "sample.jpg"
        lbl_path = src / "images" / "train" / "labels" / "sample.txt"
        _make_distinct_image(img_path, 3)
        lbl_path.parent.mkdir(parents=True, exist_ok=True)
        lbl_path.write_text("0 0.5 0.5 0.2 0.2\n", encoding="utf-8")

        pairs = _iter_source_image_label_pairs(src)
        assert pairs == [(img_path, lbl_path)]

    def test_canonicalize_label_name_rejects_false_positives_negations_and_ambiguous(self) -> None:
        # Compound positives still work
        assert canonicalize_label_name("western_flower_thrips") == 0
        assert canonicalize_label_name("green-peach-aphid") == 2
        assert canonicalize_label_name("silverleaf whitefly") == 1

        # Substring false positives must be rejected
        assert canonicalize_label_name("rhaphidophora") is None
        assert canonicalize_label_name("scaphidium") is None
        assert canonicalize_label_name("thripsidae_unknown") is None

        # Negation / exclusion tokens must be rejected
        assert canonicalize_label_name("non-aphids") is None
        assert canonicalize_label_name("not whitefly") is None
        assert canonicalize_label_name("no_thrips") is None
        assert canonicalize_label_name("aphid_mummy") is None
        assert canonicalize_label_name("aphid_predator") is None

        # Multi-class ambiguity must be rejected
        assert canonicalize_label_name("thrips_whitefly") is None
        assert canonicalize_label_name("aphids and thrips") is None


class TestDedupExportAndVerification:
    def _build_source(self, root: Path, names: list[str], samples: list[tuple[str, int, str]]) -> Path:
        root.mkdir(parents=True, exist_ok=True)
        (root / "data.yaml").write_text(f"names: {json.dumps(names)}\nnc: {len(names)}\n", encoding="utf-8")
        for rel_stem, img_seed, label_text in samples:
            img_path = root / f"{rel_stem}".replace("/labels/", "/images/")
            lbl_path = root / f"{rel_stem}".replace("/images/", "/labels/")
            img_path = img_path.with_suffix(".jpg")
            lbl_path = lbl_path.with_suffix(".txt")
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
            ["thrips", "whitefly", "aphids", "caterpillar"],
            [
                ("train/images/t1", 1, "0 0.5 0.5 0.3 0.3\n3 0.2 0.2 0.1 0.1\n"),
                ("train/images/t2", 2, "0 0.5 0.5 0.3 0.3\n"),
                ("train/images/t3", 3, "0 0.5 0.5 0.3 0.3\n"),
                ("train/images/w1", 4, "1 0.5 0.5 0.3 0.3\n"),
                ("train/images/w2", 5, "1 0.5 0.5 0.3 0.3\n"),
                ("train/images/w3", 6, "1 0.5 0.5 0.3 0.3\n"),
                ("train/images/a1", 7, "2 0.5 0.5 0.3 0.3\n"),
                ("train/images/a2", 8, "2 0.5 0.5 0.3 0.3\n"),
                ("train/images/a3", 9, "2 0.5 0.5 0.3 0.3\n"),
                ("train/images/only_unmapped", 10, "3 0.5 0.5 0.2 0.2\n"),
            ],
        )
        src2 = self._build_source(
            tmp_path / "src2",
            ["aphids", "whitefly", "thrips"],
            [
                # Exact duplicate of t1 (seed 1)
                ("valid/images/dup_exact", 1, "2 0.5 0.5 0.3 0.3\n"),
            ],
        )
        # Near-duplicate (pHash <= 2) of w1 (seed 4) with a 1-pixel corner change
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
        assert stats["empty_or_unmapped_skipped"] == 1
        assert stats["boxes_kept"] == 9
        assert stats["boxes_dropped_unmapped"] == 2
        assert details["src1"]["unmapped_class_names_seen"] == ["caterpillar"]

        splits = stratified_split_records(records, train_ratio=0.8, val_ratio=0.1, seed=42)
        out_dir = tmp_path / "merged"
        export_report = export_merged_dataset(splits, out_dir, stats)

        data_yaml = yaml.safe_load((out_dir / "data.yaml").read_text(encoding="utf-8"))
        assert "path" not in data_yaml
        assert data_yaml["train"] == "train/images"
        assert data_yaml["val"] == "val/images"
        assert data_yaml["test"] == "test/images"
        assert data_yaml["nc"] == 3
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
        assert verif["data_yaml_path_omitted"] is True
        assert verif["all_canonical_classes_present_in_all_splits"] is True

        json_path, md_path = write_provenance_reports(
            report_dir=tmp_path / "reports",
            output_dir=out_dir,
            probe_results=[
                {
                    "slug": "puzzle-piece-detection/lettuce-pests",
                    "version": 6,
                    "required": True,
                    "status": "downloaded",
                    "status_code": 200,
                    "error_type": None,
                    "error": None,
                    "raw_split_image_counts": {"train": 9},
                    "raw_class_map": {"0": "thrips"},
                }
            ],
            scan_stats=stats,
            source_details=details,
            export_report=export_report,
            verification_result=verif,
            max_hamming_distance=2,
            seed=42,
            train_ratio=0.8,
            val_ratio=0.1,
        )
        assert json_path.is_file()
        assert md_path.is_file()
        assert (out_dir / "dataset_provenance.json").is_file()

    def test_verify_exported_dataset_catches_leaks_and_corrupt_labels(self, tmp_path: Path) -> None:
        src = self._build_source(
            tmp_path / "src",
            ["thrips", "whitefly", "aphids"],
            [
                (f"train/images/img_{i}", i + 1, f"{i % 3} 0.5 0.5 0.3 0.3\n")
                for i in range(9)
            ],
        )
        records, stats = deduplicate_and_merge_sources([src])
        splits = stratified_split_records(records, seed=42)
        out_dir = tmp_path / "merged"
        export_merged_dataset(splits, out_dir, stats)

        # 1. Inject cross-split SHA-256 leak
        train_img = next((out_dir / "train" / "images").iterdir())
        train_lbl = (out_dir / "train" / "labels" / f"{train_img.stem}.txt")
        leak_img = out_dir / "val" / "images" / f"leaked_{train_img.name}"
        leak_lbl = out_dir / "val" / "labels" / f"leaked_{train_img.stem}.txt"
        leak_img.write_bytes(train_img.read_bytes())
        leak_lbl.write_text(train_lbl.read_text(encoding="utf-8"), encoding="utf-8")

        with pytest.raises(ValueError, match="Cross-split SHA-256 overlap"):
            verify_exported_dataset(out_dir)

        # Clean leak, then inject out-of-bounds label
        leak_img.unlink()
        leak_lbl.unlink()
        val_lbl = next((out_dir / "val" / "labels").iterdir())
        orig_lbl = val_lbl.read_text(encoding="utf-8")
        val_lbl.write_text("0 1.25 0.5 0.3 0.3\n", encoding="utf-8")
        with pytest.raises(ValueError, match="Out-of-bounds box"):
            verify_exported_dataset(out_dir)

        # Restore valid label, then inject non-portable path: . in data.yaml
        val_lbl.write_text(orig_lbl, encoding="utf-8")
        yaml_path = out_dir / "data.yaml"
        yaml_payload = yaml.safe_load(yaml_path.read_text(encoding="utf-8"))
        yaml_payload["path"] = "."
        yaml_path.write_text(yaml.safe_dump(yaml_payload, sort_keys=False), encoding="utf-8")
        with pytest.raises(ValueError, match="must omit 'path'"):
            verify_exported_dataset(out_dir)


class TestCommittedProvenanceArtifact:
    def test_dataset_provenance_json_if_present_has_zero_synthetic_and_zero_leaks(self) -> None:
        prov_path = Path("ml/reports/dataset_provenance.json")
        if not prov_path.is_file():
            pytest.skip("ml/reports/dataset_provenance.json not generated yet")
        raw_text = prov_path.read_text(encoding="utf-8")
        assert "ROBOFLOW_API_KEY" not in raw_text
        data = json.loads(raw_text)
        assert data["zero_synthetic_confirmed"] is True
        assert data["synthetic_images_count"] == 0
        assert data["verification"]["status"] == "passed"
        assert data["verification"]["cross_split_sha256_overlaps"] == 0
        assert data["verification"]["cross_split_phash_overlaps"] == 0
        assert data["verification"]["data_yaml_path_omitted"] is True
        for split_name in ("train", "val", "test"):
            assert data["splits"][split_name]["images"] > 0
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
            (src / "data.yaml").write_text("names: [thrips, whitefly, aphids]\nnc: 3\n", encoding="utf-8")

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

        # Verify symmetric MIH lookup handles median-boundary shifts regardless of insertion order
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
        (src / "data.yaml").write_text("names: [thrips, whitefly, aphids]\nnc: 3\n", encoding="utf-8")

        # 9 distinct base scenes (3 per canonical class) well separated in 8-dihedral pHash
        base_seeds = [1, 7, 13, 21, 29, 37, 45, 53, 61]
        for idx, seed_val in enumerate(base_seeds):
            img = self._make_asymmetric_image(seed_val)
            stem = f"scene_{idx}_jpg.rf.base{idx:04d}"
            img.save(src / "train" / "images" / f"{stem}.png")
            (src / "train" / "labels" / f"{stem}.txt").write_text(f"{idx % 3} 0.5 0.5 0.25 0.25\n", encoding="utf-8")

        # 1) Rescaled/cropped variant of scene_0 with 2 < 8-dihedral pHash <= 4
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

        # 2) Same .rf. base stem as scene_1 but heavy zoom/crop (pHash > 4)
        scene1_img = self._make_asymmetric_image(base_seeds[1])
        scene1_crop = scene1_img.crop((28, 28, 108, 108)).resize((128, 128), Image.Resampling.BILINEAR)
        assert _min_dihedral_distance(compute_dihedral_phashes(scene1_img), compute_dihedral_phashes(scene1_crop)) > 4
        scene1_crop.save(src / "train" / "images" / "scene_1_jpg.rf.crop9999.png")
        (src / "train" / "labels" / "scene_1_jpg.rf.crop9999.txt").write_text("1 0.5 0.5 0.25 0.25\n", encoding="utf-8")

        # 3) Transitive bridge: orig.rf.111 --(ROTATE_90, d=0)--> orig_rot90.rf.222 --(base_stem)--> orig_rot90.rf.333 (cropped, d>4)
        bridge_orig = self._make_asymmetric_image(99)
        bridge_rot90 = bridge_orig.transpose(Image.Transpose.ROTATE_90)
        bridge_crop = bridge_rot90.crop((28, 28, 108, 108)).resize((128, 128), Image.Resampling.BILINEAR)
        assert _min_dihedral_distance(compute_dihedral_phashes(bridge_orig), compute_dihedral_phashes(bridge_crop)) > 4
        bridge_orig.save(src / "train" / "images" / "orig_jpg.rf.111.png")
        (src / "train" / "labels" / "orig_jpg.rf.111.txt").write_text("2 0.5 0.5 0.25 0.25\n", encoding="utf-8")
        bridge_rot90.save(src / "train" / "images" / "orig_rot90_jpg.rf.222.png")
        (src / "train" / "labels" / "orig_rot90_jpg.rf.222.txt").write_text("2 0.5 0.5 0.25 0.25\n", encoding="utf-8")
        bridge_crop.save(src / "train" / "images" / "orig_rot90_jpg.rf.333.png")
        (src / "train" / "labels" / "orig_rot90_jpg.rf.333.txt").write_text("2 0.5 0.5 0.25 0.25\n", encoding="utf-8")

        records, stats = deduplicate_and_merge_sources([src])
        # orig_rot90.rf.222 is dropped by 8-dihedral hard dedup (d=0), while bridge_crop survives (d>4)
        # and MUST still share the same group_id as orig.rf.111 via pre-dedup Union-Find!
        by_stem = {r.image_path.stem: r for r in records}
        assert "orig_jpg.rf.111" in by_stem
        assert "orig_rot90_jpg.rf.333" in by_stem
        assert "orig_rot90_jpg.rf.222" not in by_stem
        assert by_stem["orig_jpg.rf.111"].group_id == by_stem["orig_rot90_jpg.rf.333"].group_id
        assert by_stem["scene_0_jpg.rf.base0000"].group_id == by_stem["scene0_rescaled_jpg.rf.var0001"].group_id
        assert by_stem["scene_1_jpg.rf.base0001"].group_id == by_stem["scene_1_jpg.rf.crop9999"].group_id

        splits = stratified_split_records(records, train_ratio=0.8, val_ratio=0.1, seed=42)
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
        source_map = {0: "thrips", 1: "whitefly", 2: "aphids"}
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
        (src / "data.yaml").write_text("names: [thrips, whitefly, aphids]\nnc: 3\n", encoding="utf-8")

        for i in range(9):
            img = self._make_asymmetric_image(i * 7 + 1)
            img.save(src / "train" / "images" / f"clean_{i}.png")
            (src / "train" / "labels" / f"clean_{i}.txt").write_text(f"{i % 3} 0.5 0.5 0.25 0.25\n", encoding="utf-8")

        records, stats = deduplicate_and_merge_sources([src])
        splits = stratified_split_records(records, seed=42)
        out_dir = tmp_path / "merged"
        export_merged_dataset(splits, out_dir, stats)
        assert verify_exported_dataset(out_dir, require_all_classes=True)["status"] == "passed"

        train_img_path = next((out_dir / "train" / "images").iterdir())
        train_lbl_text = (out_dir / "train" / "labels" / f"{train_img_path.stem}.txt").read_text(encoding="utf-8")

        # 1. ROTATE_90 copy of train image in val
        rot_img = out_dir / "val" / "images" / "leak_rot90.png"
        rot_lbl = out_dir / "val" / "labels" / "leak_rot90.txt"
        with Image.open(train_img_path) as im:
            im.transpose(Image.Transpose.ROTATE_90).save(rot_img)
        rot_lbl.write_text(train_lbl_text, encoding="utf-8")
        with pytest.raises(ValueError, match="Cross-split.*pHash"):
            verify_exported_dataset(out_dir)
        rot_img.unlink()
        rot_lbl.unlink()

        # 2. FLIP_LEFT_RIGHT copy of train image in test
        flip_img = out_dir / "test" / "images" / "leak_hflip.png"
        flip_lbl = out_dir / "test" / "labels" / "leak_hflip.txt"
        with Image.open(train_img_path) as im:
            im.transpose(Image.Transpose.FLIP_LEFT_RIGHT).save(flip_img)
        flip_lbl.write_text(train_lbl_text, encoding="utf-8")
        with pytest.raises(ValueError, match="Cross-split.*pHash"):
            verify_exported_dataset(out_dir)
        flip_img.unlink()
        flip_lbl.unlink()

        # 3. Rescaled/cropped pHash=3..4 copy of train image in val
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
        with pytest.raises(ValueError, match="Cross-split.*4"):
            verify_exported_dataset(out_dir)
        ph4_img.unlink()
        ph4_lbl.unlink()

        # 4. Distinct images sharing Roboflow .rf. base stem across train and val
        rf_train_img = out_dir / "train" / "images" / "sample_x.rf.aaaa1111.png"
        rf_train_lbl = out_dir / "train" / "labels" / "sample_x.rf.aaaa1111.txt"
        rf_val_img = out_dir / "val" / "images" / "sample_x.rf.bbbb2222.png"
        rf_val_lbl = out_dir / "val" / "labels" / "sample_x.rf.bbbb2222.txt"
        self._make_asymmetric_image(121).save(rf_train_img)
        rf_train_lbl.write_text("0 0.5 0.5 0.25 0.25\n", encoding="utf-8")
        self._make_asymmetric_image(157).save(rf_val_img)
        rf_val_lbl.write_text("1 0.5 0.5 0.25 0.25\n", encoding="utf-8")
        with pytest.raises(ValueError, match="Cross-split Roboflow base-stem overlap"):
            verify_exported_dataset(out_dir)
        rf_train_img.unlink()
        rf_train_lbl.unlink()
        rf_val_img.unlink()
        rf_val_lbl.unlink()
