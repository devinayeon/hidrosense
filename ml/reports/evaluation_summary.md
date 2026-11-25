# HidroSense YOLOv11n (`whitefly` & `aphids`) Evaluation Summary

- **Promotion Gate Status**: `PASSED`
- **Calibrated Production Confidence Threshold**: `0.45`
- **Mobile TFLite Embedding `mAP@50` Drop (`rect=False, batch=1`)**: `0.0000`

## 1. Object Detection Metrics (Held-Out Test Split)

| Model & Inference Geometry | `mAP@50` | `mAP@75` | `mAP@50-95` | `Precision` | `Recall` | `F1-Score` |
|---|---:|---:|---:|---:|---:|---:|
| Stage 1 Baseline (Kaggle T4 GPU, `rect=True`) | `0.9217` | `0.7256` | `0.6700` | `0.9107` | `0.8701` | `0.8900` |
| Stage 2 Production (Kaggle T4 GPU, `rect=True`) | **`0.9512`** | **`0.8510`** | **`0.6793`** | **`0.8874`** | **`0.9341`** | **`0.9101`** |
| Stage 1 Baseline (`640x640` `rect=False`, PyTorch) | `0.9193` | `0.7659` | `0.6770` | `0.8765` | `0.8756` | `0.8761` |
| Stage 2 Production (`640x640` `rect=False`, PyTorch) | **`0.9423`** | **`0.4847`** | **`0.4973`** | **`0.8830`** | **`0.9114`** | **`0.8970`** |
| Embedded Mobile TFLite (`640x640` `ai_edge_litert`) | **`0.9423`** | **`0.4853`** | **`0.4977`** | **`0.8832`** | **`0.9134`** | **`0.8981`** |

- **Direct Tensor Parity (PyTorch vs FP16 TFLite)**: `max_abs_diff = 0.000742`, `mean_abs_diff = 3.6e-05`, `cls_score_max_abs_diff = 6e-06`

## 2. Classification, Specificity & Anti-Hallucination (OOD) Metrics

- **Matched-Box Pest Classification Accuracy (`whitefly` vs `aphids`)**: `1.0000`
- **Image-Level Presence/Absence Accuracy**: `0.9341` (`Balanced Accuracy = 0.9277`)
- **Specificity / True Negative Rate (All Negatives)**: `0.9062`
- **Real-Life OOD False Positive Rate (`people`, `bottles`, `healthy_food`, `random_objects`)**: `0.0417` (`1` / `24`)
- **Matthews Correlation Coefficient (MCC)**: `0.8554`

| Negative / OOD Group | Images | True Negatives | False Positives | Specificity (TNR) | FPR |
|---|---:|---:|---:|---:|---:|
| `leaf_empty` | `7` | `5` | `2` | `0.7143` | `0.2857` |
| `molted_skin_only` | `1` | `1` | `0` | `1.0000` | `0.0000` |
| `ood_drink_bottles_cups` | `3` | `2` | `1` | `0.6667` | `0.3333` |
| `ood_healthy_food` | `2` | `2` | `0` | `1.0000` | `0.0000` |
| `ood_people` | `10` | `10` | `0` | `1.0000` | `0.0000` |
| `ood_random_objects` | `9` | `9` | `0` | `1.0000` | `0.0000` |

## 3. Training & Validation Loss Convergence

- **Best Epoch / Total Trained**: `100` / `100`
- **Train Losses (`box` / `cls` / `dfl`)**: `1.02884` / `1.24136` / `1.26314`
- **Val Losses (`box` / `cls` / `dfl`)**: `1.09603` / `1.63956` / `1.24391`
