# HidroSense YOLOv11n (`whitefly` & `aphids`) Evaluation Summary

- **Promotion Gate Status**: `PASSED`
- **Calibrated Production Confidence Threshold**: `0.4`
- **Mobile TFLite Embedding `mAP@50` Drop (`rect=False, batch=1`)**: `0.0000`

## 1. Object Detection Metrics (Held-Out Test Split)

| Model & Inference Geometry | `mAP@50` | `mAP@75` | `mAP@50-95` | `Precision` | `Recall` | `F1-Score` |
|---|---:|---:|---:|---:|---:|---:|
| Stage 1 Baseline (Kaggle T4 GPU, `rect=True`) | `0.9796` | `0.9146` | `0.7402` | `0.9707` | `0.9510` | `0.9607` |
| Stage 2 Production (Kaggle T4 GPU, `rect=True`) | **`0.9799`** | **`0.9008`** | **`0.7226`** | **`0.9756`** | **`0.9510`** | **`0.9632`** |
| Stage 1 Baseline (`640x640` `rect=False`, PyTorch) | `0.9800` | `0.9032` | `0.7251` | `0.9702` | `0.9501` | `0.9600` |
| Stage 2 Production (`640x640` `rect=False`, PyTorch) | **`0.9844`** | **`0.6317`** | **`0.5882`** | **`0.9772`** | **`0.9552`** | **`0.9660`** |
| Embedded Mobile TFLite (`640x640` `ai_edge_litert`) | **`0.9845`** | **`0.6338`** | **`0.5888`** | **`0.9772`** | **`0.9552`** | **`0.9660`** |

- **Direct Tensor Parity (PyTorch vs FP16 TFLite)**: `max_abs_diff = 0.002347`, `mean_abs_diff = 5.8e-05`, `cls_score_max_abs_diff = 1e-06`

## 2. Classification, Specificity & Anti-Hallucination (OOD) Metrics

- **Matched-Box Pest Classification Accuracy (`whitefly` vs `aphids`)**: `1.0000`
- **Image-Level Presence/Absence Accuracy**: `0.9270` (`Balanced Accuracy = 0.9147`)
- **Specificity / True Negative Rate (All Negatives)**: `0.8571`
- **Real-Life OOD False Positive Rate (`people`, `bottles`, `healthy_food`, `random_objects`)**: `0.0000` (`0` / `28`)
- **Matthews Correlation Coefficient (MCC)**: `0.8472`

| Negative / OOD Group | Images | True Negatives | False Positives | Specificity (TNR) | FPR |
|---|---:|---:|---:|---:|---:|
| `leaf_empty` | `41` | `32` | `9` | `0.7805` | `0.2195` |
| `molted_skin_only` | `1` | `0` | `1` | `0.0000` | `1.0000` |
| `ood_drink_bottles_cups` | `3` | `3` | `0` | `1.0000` | `0.0000` |
| `ood_healthy_food` | `2` | `2` | `0` | `1.0000` | `0.0000` |
| `ood_people` | `12` | `12` | `0` | `1.0000` | `0.0000` |
| `ood_random_objects` | `11` | `11` | `0` | `1.0000` | `0.0000` |

## 2b. Multi-Scale Phone-Distance Recall & Extended COCO val2017 OOD Audit

- **Local TFLite `0.25x` Phone-Distance Localized Recall (`IoU >= 0.3`)**: **`0.9907`** (`107` / `108` | `whitefly = 0.9615`, `aphids = 1.0`)
- **Kaggle Extended COCO `val2017` + `coco128` OOD False Positive Rate**: **`0.0056`** (`1` / `180` held-out real-world OOD photos)
- **Kaggle PyTorch `0.25x` Small-Scale Recall**: `0.9875` (`whitefly = 1.0`, `aphids = 0.9868`)

## 3. Training & Validation Loss Convergence

- **Best Epoch / Total Trained**: `74` / `85`
- **Train Losses (`box` / `cls` / `dfl`)**: `1.14597` / `0.49548` / `1.05827`
- **Val Losses (`box` / `cls` / `dfl`)**: `0.70454` / `1.89643` / `0.752`
