from __future__ import annotations

from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image


@dataclass(frozen=True)
class VisualAxisSpec:
    name: str
    indonesian_label: str
    rationale: str
    techniques: tuple[str, ...]
    parameters: dict[str, Any]


VISUAL_AXES: dict[str, VisualAxisSpec] = {
    "color": VisualAxisSpec(
        name="color",
        indonesian_label="Warna",
        rationale=(
            "Prevent false reliance on raw white/green pixels so white bottle reflections "
            "or green salad ingredients are not confused with whitefly or aphids."
        ),
        techniques=("hsv_hue_saturation_shift", "color_jitter", "probabilistic_to_gray"),
        parameters={"hsv_h": 0.02, "hsv_s": 0.55, "to_gray_p": 0.05},
    ),
    "shape": VisualAxisSpec(
        name="shape",
        indonesian_label="Bentuk",
        rationale=(
            "Preserve tight insect contour from polygon segmentation and enforce rotational/shear "
            "invariance for triangular winged whiteflies vs pear-shaped aphids."
        ),
        techniques=("polygon_to_tight_aabb", "random_rotation", "shear", "dihedral_flips"),
        parameters={"degrees": 20.0, "shear": 5.0, "fliplr": 0.5, "flipud": 0.3},
    ),
    "density": VisualAxisSpec(
        name="density",
        indonesian_label="Kepadatan",
        rationale=(
            "Handle both isolated single scouts and dense overlapping colonies on leaf undersides."
        ),
        techniques=("mosaic_4tile", "copy_paste_instances", "mixup", "high_max_det_nms"),
        parameters={"mosaic": 1.0, "close_mosaic": 15, "copy_paste": 0.15, "mixup": 0.08, "max_det": 300},
    ),
    "lighting": VisualAxisSpec(
        name="lighting",
        indonesian_label="Cahaya",
        rationale=(
            "Stabilize local contrast under harsh hydroponic LED grow-lights, sun glare, and leaf shade."
        ),
        techniques=("clahe_local_contrast", "specular_glare_hard_negatives"),
        parameters={"clahe_clip_limit": 3.0, "clahe_tile_grid": [8, 8], "clahe_p": 0.25},
    ),
    "background": VisualAxisSpec(
        name="background",
        indonesian_label="Latar Belakang",
        rationale=(
            "Reject non-pest backgrounds including people, drink bottles, healthy food, indoor objects, "
            "healthy lettuce leaves, and shed molted skins."
        ),
        techniques=("in_domain_empty_leaves", "molted_skin_hard_negatives", "coco_real_life_ood_negatives", "random_erasing"),
        parameters={"target_negative_ratio": 0.22, "erasing": 0.15},
    ),
    "exposure": VisualAxisSpec(
        name="exposure",
        indonesian_label="Gelap Terang",
        rationale=(
            "Maintain detection sensitivity across underexposed leaf undersides and overexposed phone flash photos."
        ),
        techniques=("hsv_value_gain", "random_brightness_contrast", "random_gamma"),
        parameters={"hsv_v": 0.45, "brightness_limit": 0.30, "contrast_limit": 0.30, "gamma_range": [75, 130], "exposure_p": 0.30},
    ),
    "size": VisualAxisSpec(
        name="size",
        indonesian_label="Ukuran",
        rationale=(
            "Bridge close-up macro dataset boxes (~114-133 px) down to distant mobile camera shots (~20-40 px) "
            "using multi-scale zoom-out and YOLOv11n C2PSA spatial attention."
        ),
        techniques=("multi_scale_zoom", "c2psa_spatial_attention", "imgsz_640"),
        parameters={"imgsz": 640, "scale": 0.75, "translate": 0.15},
    ),
    "edges": VisualAxisSpec(
        name="edges",
        indonesian_label="Tepian",
        rationale=(
            "Keep insect leg/wing/antenna boundary cues resilient to phone autofocus blur or sharpening halos."
        ),
        techniques=("unsharp_sharpen", "motion_and_gaussian_blur", "perspective_warp"),
        parameters={"sharpen_p": 0.15, "blur_p": 0.15, "perspective": 0.0003},
    ),
    "texture": VisualAxisSpec(
        name="texture",
        indonesian_label="Tekstur",
        rationale=(
            "Prevent false triggers from leaf vein texture, sensor ISO grain, WhatsApp/JPEG compression, "
            "or flaky white molted-skin exuviae."
        ),
        techniques=("jpeg_compression", "iso_gauss_noise", "salt_pepper_deduplication"),
        parameters={"jpeg_quality_min": 55, "jpeg_quality_max": 95, "jpeg_p": 0.20, "noise_p": 0.15},
    ),
}


def build_visual_training_hyperparams() -> dict[str, Any]:
    """Return Ultralytics YOLOv11n training hyperparameters derived from VISUAL_AXES."""
    return {
        "imgsz": int(VISUAL_AXES["size"].parameters["imgsz"]),
        "scale": float(VISUAL_AXES["size"].parameters["scale"]),
        "translate": float(VISUAL_AXES["size"].parameters["translate"]),
        "mosaic": float(VISUAL_AXES["density"].parameters["mosaic"]),
        "close_mosaic": int(VISUAL_AXES["density"].parameters["close_mosaic"]),
        "copy_paste": float(VISUAL_AXES["density"].parameters["copy_paste"]),
        "mixup": float(VISUAL_AXES["density"].parameters["mixup"]),
        "degrees": float(VISUAL_AXES["shape"].parameters["degrees"]),
        "shear": float(VISUAL_AXES["shape"].parameters["shear"]),
        "fliplr": float(VISUAL_AXES["shape"].parameters["fliplr"]),
        "flipud": float(VISUAL_AXES["shape"].parameters["flipud"]),
        "perspective": float(VISUAL_AXES["edges"].parameters["perspective"]),
        "hsv_h": float(VISUAL_AXES["color"].parameters["hsv_h"]),
        "hsv_s": float(VISUAL_AXES["color"].parameters["hsv_s"]),
        "hsv_v": float(VISUAL_AXES["exposure"].parameters["hsv_v"]),
        "erasing": float(VISUAL_AXES["background"].parameters["erasing"]),
    }


def build_albumentations_transforms() -> list[Any]:
    """Construct custom Albumentations pixel-level transforms for lighting, edges, color, and texture."""
    import albumentations as A

    try:
        jpeg_tf = A.ImageCompression(quality_range=(55, 95), p=0.20)
    except TypeError:
        jpeg_tf = A.ImageCompression(quality_lower=55, quality_upper=95, p=0.20)

    transforms: list[Any] = [
        A.CLAHE(clip_limit=3.0, tile_grid_size=(8, 8), p=0.25),
        A.RandomBrightnessContrast(brightness_limit=0.28, contrast_limit=0.28, p=0.30),
        A.RandomGamma(gamma_limit=(75, 130), p=0.20),
        A.OneOf(
            [
                A.GaussianBlur(blur_limit=(3, 5), p=1.0),
                A.MotionBlur(blur_limit=(3, 5), p=1.0),
            ],
            p=0.15,
        ),
        A.Sharpen(alpha=(0.15, 0.35), lightness=(0.8, 1.1), p=0.15),
        A.GaussNoise(p=0.15),
        jpeg_tf,
        A.ToGray(p=0.05),
    ]
    return transforms


def compute_image_visual_profile(
    image_path: Path,
    boxes: tuple[tuple[float, float, float, float], ...] = (),
) -> dict[str, float | int | str]:
    """Measure empirical brightness, contrast, saturation, edge sharpness, density, and scale tier."""
    with Image.open(image_path) as raw_img:
        rgb = np.asarray(raw_img.convert("RGB"), dtype=np.float32) / 255.0

    gray = 0.299 * rgb[:, :, 0] + 0.587 * rgb[:, :, 1] + 0.114 * rgb[:, :, 2]
    brightness = float(np.mean(gray))
    contrast = float(np.std(gray))

    max_c = np.max(rgb, axis=2)
    min_c = np.min(rgb, axis=2)
    saturation = float(np.mean(np.where(max_c > 1e-5, (max_c - min_c) / np.maximum(max_c, 1e-5), 0.0)))

    # Discrete 2D Laplacian variance as focus / edge-energy indicator
    if gray.shape[0] >= 3 and gray.shape[1] >= 3:
        lap = (
            -4.0 * gray[1:-1, 1:-1]
            + gray[:-2, 1:-1]
            + gray[2:, 1:-1]
            + gray[1:-1, :-2]
            + gray[1:-1, 2:]
        )
        edge_energy = float(np.var(lap))
    else:
        edge_energy = 0.0

    count = len(boxes)
    if count == 0:
        density_tier = "negative"
    elif count <= 3:
        density_tier = "sparse"
    elif count <= 10:
        density_tier = "moderate"
    else:
        density_tier = "dense"

    mean_area = float(np.mean([w * h for _, _, w, h in boxes])) if boxes else 0.0
    return {
        "brightness": round(brightness, 4),
        "contrast": round(contrast, 4),
        "saturation": round(saturation, 4),
        "edge_energy": round(edge_energy, 6),
        "box_count": count,
        "density_tier": density_tier,
        "mean_box_area": round(mean_area, 5),
    }


def export_visual_pipeline_manifest() -> dict[str, Any]:
    return {
        "axes_count": len(VISUAL_AXES),
        "axes": {k: asdict(v) for k, v in VISUAL_AXES.items()},
        "yolo_hyperparameters": build_visual_training_hyperparams(),
    }
