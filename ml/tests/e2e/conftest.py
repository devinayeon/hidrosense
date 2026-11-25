from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable

import numpy as np
import pytest
import yaml
from PIL import Image, ImageDraw

_SECRET_KEY_NAMES = r"(?:ROBOFLOW_API_KEY|KAGGLE_KEY|KAGGLE_API_TOKEN|API_KEY|SECRET_KEY)"

SECRET_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("kaggle_api_token", re.compile(r"KGAT_[A-Za-z0-9]{16,}")),
    ("roboflow_api_token", re.compile(r"\brf_[A-Za-z0-9_-]{15,}")),
    ("roboflow_ds_key_param", re.compile(r"[?&]key=(?!\[REDACTED\])[A-Za-z0-9_-]{8,}")),
    (
        "hardcoded_secret_assignment",
        re.compile(
            rf"""(?im)(?:["']?{_SECRET_KEY_NAMES}["']?[ \t]*[:=][ \t]*(?:"[^\s"]{{8,}}"|'[^\s']{{8,}}')|^[ \t]*(?:[+-]+[ \t]*)?export[ \t]+{_SECRET_KEY_NAMES}[ \t]*=[ \t]*(?!None\b|True\b|False\b)[A-Za-z0-9_\-+/=.]{{8,}}(?=[ \t]*(?:$|#|\r|\n))|^[ \t]*(?:[+-]+[ \t]*)?{_SECRET_KEY_NAMES}[ \t]*[:=][ \t]*(?!None\b|True\b|False\b)(?=[A-Za-z0-9_\-+/=.]*[0-9+/=])[A-Za-z0-9_\-+/=.]{{12,}}(?=[ \t]*(?:$|#|\r|\n)))"""
        ),
    ),
    ("bearer_token", re.compile(r"(?i)\bBearer[ \t]+(?!\[REDACTED\])[A-Za-z0-9._\-+/=]{12,}")),
    ("private_key_block", re.compile(r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----")),
)

BINARY_SUFFIXES: frozenset[str] = frozenset(
    {
        ".tflite",
        ".pt",
        ".onnx",
        ".png",
        ".jpg",
        ".jpeg",
        ".webp",
        ".bmp",
        ".ico",
        ".pdf",
        ".zip",
        ".pyc",
    }
)


def pytest_configure(config: pytest.Config) -> None:
    config.addinivalue_line(
        "markers",
        "production_artifact: Acceptance checks against real M2/M3/M4 deliverables and ml/artifacts or ml/reports (deselect with '-m \"not production_artifact\"').",
    )


@pytest.fixture(scope="session", autouse=True)
def _isolate_ultralytics_runs_dir(tmp_path_factory: pytest.TempPathFactory):
    """Prevent Ultralytics from writing runs/ into the repository root regardless of test order."""
    runs_dir = tmp_path_factory.mktemp("ultralytics_runs")
    already_loaded = "ultralytics" in sys.modules
    prev_yolo_cfg = os.environ.get("YOLO_CONFIG_DIR")
    if not already_loaded:
        cfg_dir = tmp_path_factory.mktemp("ultralytics_cfg")
        os.environ["YOLO_CONFIG_DIR"] = str(cfg_dir)

    from ultralytics.utils import SETTINGS

    prev_runs_dir = SETTINGS.get("runs_dir")
    dict.__setitem__(SETTINGS, "runs_dir", str(runs_dir))
    try:
        yield
    finally:
        if prev_runs_dir is not None:
            dict.__setitem__(SETTINGS, "runs_dir", prev_runs_dir)
        if not already_loaded:
            if prev_yolo_cfg is None:
                os.environ.pop("YOLO_CONFIG_DIR", None)
            else:
                os.environ["YOLO_CONFIG_DIR"] = prev_yolo_cfg


def scan_text_for_secrets(text: str) -> list[str]:
    """Return descriptions of any secret-like tokens found in text."""
    findings: list[str] = []
    for label, pattern in SECRET_PATTERNS:
        for match in pattern.finditer(text):
            findings.append(f"{label}: {match.group(0)[:16]}...")
    return findings


def scan_bytes_for_secrets(raw: bytes) -> list[str]:
    """Safely scan arbitrary bytes for secret patterns without raising UnicodeDecodeError."""
    return scan_text_for_secrets(raw.decode("utf-8", errors="ignore"))


def validate_ml_only_paths(paths: list[str]) -> list[str]:
    """Return any repository-relative paths outside approved Opsi B scope (ml/, apps/mobile/, and AST graphify-out/)."""
    return [p for p in paths if p and not p.startswith(("ml/", "apps/mobile/", "graphify-out/"))]


def letterbox_rgb_image(
    image: Image.Image,
    target_size: int | tuple[int, int] = 640,
    pad_value: int = 114,
) -> tuple[np.ndarray, dict[str, float]]:
    """Letterbox-resize an RGB image and normalize to float32 [0.0, 1.0] HWC."""
    if isinstance(target_size, int):
        target_h, target_w = target_size, target_size
    else:
        target_h, target_w = target_size

    rgb = image.convert("RGB")
    src_w, src_h = rgb.size
    scale = min(target_w / max(1, src_w), target_h / max(1, src_h))
    new_w = max(1, int(round(src_w * scale)))
    new_h = max(1, int(round(src_h * scale)))

    resized = rgb.resize((new_w, new_h), Image.Resampling.BILINEAR)
    canvas = Image.new("RGB", (target_w, target_h), color=(pad_value, pad_value, pad_value))
    pad_x = (target_w - new_w) // 2
    pad_y = (target_h - new_h) // 2
    canvas.paste(resized, (pad_x, pad_y))

    arr = np.asarray(canvas, dtype=np.float32) / 255.0
    return arr, {"scale": scale, "pad_x": float(pad_x), "pad_y": float(pad_y)}


def adapt_hwc_to_model_input(hwc_float: np.ndarray, input_shape: list[int] | tuple[int, ...]) -> np.ndarray:
    """Adapt an [H, W, 3] float32 array to either NHWC [1, H, W, 3] or NCHW [1, 3, H, W]."""
    if len(input_shape) != 4:
        raise ValueError(f"Expected 4D tensor shape, got {input_shape}")
    if input_shape[1] == 3 and input_shape[3] != 3:
        chw = np.transpose(hwc_float, (2, 0, 1))
        return np.expand_dims(chw, axis=0).astype(np.float32)
    return np.expand_dims(hwc_float, axis=0).astype(np.float32)


def spatial_hw_from_input_shape(input_shape: list[int] | tuple[int, ...]) -> tuple[int, int]:
    """Extract (height, width) from a 4D NHWC or NCHW tensor shape."""
    if len(input_shape) != 4:
        raise ValueError(f"Expected 4D tensor shape, got {input_shape}")
    if input_shape[1] == 3 and input_shape[3] != 3:
        return int(input_shape[2]), int(input_shape[3])
    return int(input_shape[1]), int(input_shape[2])


@pytest.fixture(scope="session")
def binary_suffixes() -> frozenset[str]:
    return BINARY_SUFFIXES


@pytest.fixture(scope="session")
def secret_scanner():
    return scan_text_for_secrets


@pytest.fixture(scope="session")
def bytes_secret_scanner():
    return scan_bytes_for_secrets


@pytest.fixture(scope="session")
def ml_only_path_validator():
    return validate_ml_only_paths


@pytest.fixture(scope="session")
def letterbox_fn():
    return letterbox_rgb_image


@pytest.fixture(scope="session")
def adapt_input_fn():
    return adapt_hwc_to_model_input


@pytest.fixture(scope="session")
def spatial_hw_fn():
    return spatial_hw_from_input_shape


@pytest.fixture(scope="session")
def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


@pytest.fixture(scope="session")
def ml_root(repo_root: Path) -> Path:
    return repo_root / "ml"


@pytest.fixture
def run_cli(repo_root: Path) -> Callable[[str, list[str], dict[str, str | None] | None], subprocess.CompletedProcess[str]]:
    def _runner(
        module: str,
        args: list[str],
        env_overrides: dict[str, str | None] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        if env_overrides:
            for key, val in env_overrides.items():
                if val is None:
                    env.pop(key, None)
                else:
                    env[key] = val
        return subprocess.run(
            [sys.executable, "-m", module, *args],
            cwd=repo_root,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )

    return _runner


@pytest.fixture
def make_yolo_source() -> Callable[..., Path]:
    def _factory(
        base_dir: Path,
        names: list[str] | dict[int, str] | None,
        samples: list[dict[str, Any]],
        yaml_filename: str | None = "data.yaml",
        prefix_dirs: tuple[str, ...] = (),
    ) -> Path:
        root = base_dir.joinpath(*prefix_dirs) if prefix_dirs else base_dir
        root.mkdir(parents=True, exist_ok=True)

        if yaml_filename is not None and names is not None:
            nc = len(names)
            payload = {
                "train": "train/images",
                "val": "valid/images",
                "test": "test/images",
                "nc": nc,
                "names": names,
            }
            (root / yaml_filename).write_text(yaml.safe_dump(payload, sort_keys=False), encoding="utf-8")

        for idx, sample in enumerate(samples):
            split = sample.get("split", "train")
            stem = sample.get("stem", f"sample_{idx:03d}")
            ext = sample.get("ext", ".jpg")
            img_path = root / split / "images" / f"{stem}{ext}"
            lbl_path = root / split / "labels" / f"{stem}.txt"
            img_path.parent.mkdir(parents=True, exist_ok=True)
            lbl_path.parent.mkdir(parents=True, exist_ok=True)

            if sample.get("corrupt_image"):
                img_path.write_bytes(b"corrupt_not_an_image_payload")
            else:
                size = sample.get("size", (160, 160))
                bg = sample.get("bg_color", ((idx * 53) % 255, (idx * 97) % 255, (idx * 131) % 255))
                img = Image.new("RGB", size, color=bg)
                draw = ImageDraw.Draw(img)
                # Draw a 4x4 deterministic bit-grid + diagonal accent so distinct pattern_seeds yield distinct pHashes
                pattern_seed = int(sample.get("pattern_seed", idx))
                cell_w = max(8, size[0] // 4)
                cell_h = max(8, size[1] // 4)
                for bit_idx in range(16):
                    if ((pattern_seed * 2654435761) >> bit_idx) & 1:
                        gx = bit_idx % 4
                        gy = bit_idx // 4
                        x0 = gx * cell_w + 2
                        y0 = gy * cell_h + 2
                        draw.rectangle(
                            (x0, y0, x0 + cell_w - 4, y0 + cell_h - 4),
                            fill=((pattern_seed * 41 + bit_idx * 37) % 255, (255 - bit_idx * 15) % 255, (bit_idx * 29) % 255),
                        )
                img.save(img_path)

            if not sample.get("omit_label", False):
                lines = sample.get("labels", [])
                lbl_path.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")

        return root

    return _factory
