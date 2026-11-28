# HidroSense YOLOv11n (`whitefly` & `aphids`) Evaluation Summary

- **Promotion Gate Status**: `PASSED`
- **Calibrated Production Confidence Threshold**: `0.5`
- **Mobile TFLite Embedding `mAP@50` Drop (`rect=False, batch=1`)**: `0.0000`

## 1. Object Detection Metrics (Held-Out Test Split)

| Model & Inference Geometry | `mAP@50` | `mAP@75` | `mAP@50-95` | `Precision` | `Recall` | `F1-Score` |
|---|---:|---:|---:|---:|---:|---:|
| Stage 1 Baseline (Kaggle T4 GPU, `rect=True`) | `0.9954` | `0.8535` | `0.6957` | `0.9844` | `0.9854` | `0.9849` |
| Stage 2 Production (Kaggle T4 GPU, `rect=True`) | **`0.9987`** | **`0.9051`** | **`0.7381`** | **`0.9928`** | **`0.9928`** | **`0.9928`** |
| Stage 1 Baseline (`640x640` `rect=False`, PyTorch) | `0.9944` | `0.8717` | `0.7061` | `0.9850` | `0.9862` | `0.9856` |
| Stage 2 Production (`640x640` `rect=False`, PyTorch) | **`0.9946`** | **`0.9228`** | **`0.7352`** | **`0.9905`** | **`0.9903`** | **`0.9904`** |
| Embedded Mobile TFLite (`640x640` `ai_edge_litert`) | **`0.9946`** | **`0.9221`** | **`0.7358`** | **`0.9897`** | **`0.9916`** | **`0.9906`** |

- **Direct Tensor Parity (PyTorch vs FP16 TFLite)**: `max_abs_diff = 0.009538`, `mean_abs_diff = 0.000105`, `cls_score_max_abs_diff = 8e-06`

## 2. Classification, Specificity & Anti-Hallucination (OOD) Metrics

- **Matched-Box Pest Classification Accuracy (`whitefly` vs `aphids`)**: `1.0000`
- **Image-Level Presence/Absence Accuracy**: `0.9924` (`Balanced Accuracy = 0.9924`)
- **Specificity / True Negative Rate (All Negatives)**: `0.9848`
- **Real-Life OOD False Positive Rate (`people`, `bottles`, `healthy_food`, `random_objects`)**: `0.0000` (`0` / `28`)
- **Matthews Correlation Coefficient (MCC)**: `0.9850`

| Negative / OOD Group | Images | True Negatives | False Positives | Specificity (TNR) | FPR |
|---|---:|---:|---:|---:|---:|
| `leaf_empty` | `38` | `37` | `1` | `0.9737` | `0.0263` |
| `ood_drink_bottles_cups` | `3` | `3` | `0` | `1.0000` | `0.0000` |
| `ood_healthy_food` | `2` | `2` | `0` | `1.0000` | `0.0000` |
| `ood_people` | `12` | `12` | `0` | `1.0000` | `0.0000` |
| `ood_random_objects` | `11` | `11` | `0` | `1.0000` | `0.0000` |

## 2b. Multi-Scale Recall, Calibration (ECE/TIDE), & Smartphone Stress Audit

- **Local TFLite `0.25x` Phone-Distance Localized Recall (`IoU >= 0.3`)**: **`1.0000`** (`66` / `66` | `whitefly = 1.0`, `aphids = 1.0`, `box_level = 0.6312`)
- **Kaggle Extended COCO `val2017` + `coco128` OOD False Positive Rate**: **`0.0056`** (`1` / `180` held-out real-world OOD photos)
- **Calibration (ECE)**: `0.1855` | **FPPI**: `0.1136` | **Count MAE**: `0.1970`
- **TIDE Errors**: `TP=1506`, `Background_FP=15`, `Loc_FP=0`, `Class_FP=0`, `Missed_FN=15`
- **Size-Bucket Box Recall**: `<32px = 0.966`, `32-96px = 0.9923`, `>=96px = 1.0`

| Smartphone Domain-Shift Scenario | Hits / Total | Image Recall |
|---|---:|---:|
| `clean_orig` | `40 / 40` | `1.0000` |
| `bright_sunlight_1_55x` | `36 / 40` | `0.9000` |
| `dark_lowlight_0_45x` | `39 / 40` | `0.9750` |
| `blur_9x9_defocus` | `40 / 40` | `1.0000` |
| `jpeg_q25` | `40 / 40` | `1.0000` |
| `portrait_9x16_nft_border` | `40 / 40` | `1.0000` |

## 3. Training & Validation Loss Convergence

- **Best Epoch / Total Trained**: `79` / `90`
- **Train Losses (`box` / `cls` / `dfl`)**: `1.0529` / `0.50395` / `0.97971`
- **Val Losses (`box` / `cls` / `dfl`)**: `0.72041` / `0.82211` / `0.79211`
