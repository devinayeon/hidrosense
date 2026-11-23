# HidroSense YOLOv11n Lettuce Pest Detection — R2 Audit Report

**Date:** 2026-11-22 (R2 Audit + M2–M4 Resolution Update)  
**Branch:** `feature/ml-production-pipeline` (reconciled `ml/` from `feature/ml-local-work` `96713dd` onto `main` `05849e0`)  
**Audited Kernel:** `adityadwiferdiansyah/hidrosense-yolov11n-lettuce-pests-training` (`id_no: 145430380`, `currentVersionNumber: 4`)  
**Audited Artifact:** `ml/artifacts/yolo11n_lettuce_pests.tflite` (`sha256: a65a43cf450097e4417e5c59ab0e4e71c17906e0fbd580bb2639175ed368d963`)  
**Resolved Production Run:** `adityadwiferdiansyah/hidrosense-yolov11n-lettuce-pests-training` (Kaggle GPU `Tesla T4` x2, `torch 2.11.0+cu130`, dataset `adityadwiferdiansyah/hidrosense-lettuce-pests-real`)  
**Production Artifact:** `ml/artifacts/yolo11n_lettuce_pests.tflite` (`5.159` MB, NHWC FP16, `sha256: cd388bdab9c24490d6d01dd336ef4f2b191f1b66032e23adcf6cf831592b2ab3`)

---

## 1. Executive Summary

**Audit Verdict:**
1. The previously committed model (`ml/artifacts/yolo11n_lettuce_pests.tflite`, `10.121` MB, reported `mAP@50 = 0.9820`) was **NOT trained on real Roboflow data**. When `ROBOFLOW_API_KEY` was absent from both environment variables and Kaggle Secrets, the kernel script silently fell back to generating **108 synthetic PIL-drawn geometric images** (`72` train / `18` val / `18` test).
2. The model was **NOT trained on GPU**. Kaggle kernel `v4` executed with `enable_gpu: false` on a **CPU** (`torch-2.11.0+cpu`, `Intel Xeon CPU @ 2.20GHz`, `GPU_mem 0G`) at reduced resolution (`imgsz=320`, `epochs=8`, `batch=8`).
3. **No real-data baseline existed at R2 audit time (`96713dd`), but this has since been resolved in M2–M4.** Every prior metric in `96713dd` `ml/reports/evaluation_report.json` (`baseline mAP@50 = 0.08`, `finetuned mAP@50 = 0.9820`) was measured on 18 synthetic images and had zero real-world validity. In M2–M4, a verified leak-free `1,576`-image real Roboflow dataset (`153`-image held-out real test split, `0` synthetic, `0` leakage) and Kaggle `Tesla T4` x2 GPU training run established the true real-data baseline (`mAP@50 = 0.8539`, `recall = 0.8078`, `thrips` `mAP@50 = 0.6152` / `recall = 0.5312`) and improved production model (`mAP@50 = 0.8913`, `recall = 0.8566`, `thrips` `mAP@50 = 0.7216` / `recall = 0.6562`, NHWC FP16 TFLite `5.159 MB`, `ai_edge_litert` direct interpreter `mAP@50 = 0.8893`).
4. Additionally, `ml/artifacts/model_metadata.json` contradicts the exported `.tflite` flatbuffer on **input shape, tensor layout, output anchor count, and quantization** (`[1, 640, 640, 3]` NHWC / `[1, 7, 8400]` / `yolo11n-fp16-...` claimed vs. empirical `[1, 3, 320, 320]` NCHW `float32` / `[1, 7, 2100]` / FP32 `quantize: null` `10.121 MB` verified via `ai_edge_litert.interpreter.Interpreter`).

---

## 2. Audit Scope & Verification Sources

This audit verified all claims directly against repository commits, local artifacts, and Kaggle API metadata/logs:
- **Git commits & branches:**
  - `main` (`05849e0c6cd514fd512bd7809370cd7eb92e8c94`): empty placeholders (`ml/train.py`, `ml/evaluate.py`, `ml/export_tflite.py`) and 2-line `ml/requirements.txt`.
  - `feature/ml-local-work` (`96713dd9018b22b7404247a7c849a228294eeb1a`): 13 tracked files under `ml/`, including pipeline scripts, unit tests, `ml/reports/evaluation_report.json`, `ml/artifacts/model_metadata.json`, `ml/artifacts/labels.txt`, and Git LFS pointer for `ml/artifacts/yolo11n_lettuce_pests.tflite`.
- **Kaggle Kernel API & Output Inspection:**
  - Inspected `adityadwiferdiansyah/hidrosense-yolov11n-lettuce-pests-training` (`id_no: 145430380`), status `COMPLETE`, `currentVersionNumber: 4`, `lastRunTime: 2026-11-18T13:37:34.882Z`.
- **Empirical Artifact & Runtime Verification (`ml/venv`):**
  - Materialized `ml/artifacts/yolo11n_lettuce_pests.tflite` from local Git LFS object cache (`a65a43cf450097e4417e5c59ab0e4e71c17906e0fbd580bb2639175ed368d963`) and executed `ai_edge_litert.interpreter.Interpreter` (`ai-edge-litert 2.4.0`) + `ultralytics 8.4.215` LiteRT backend inspection.

### Kaggle API v1–v3 `404 Not Found` Caveat
Kaggle API requests (`ApiGetKernelRequest`, `ApiGetKernelSessionStatusRequest`, and `ApiListKernelSessionOutputRequest`) for `version_label` `'1'`, `'2'`, `'3'` (as well as `'5'`) return `404 Client Error: Not Found`. Only `currentVersionNumber: 4` is exposed and retrievable via the Kaggle API. Consequently, prior kernel versions `v1`–`v3` cannot be inspected through Kaggle API endpoints; all remote execution findings below are established from `v4` and cross-checked byte-for-byte against the committed `feature/ml-local-work` (`96713dd`) artifacts.

---

## 3. Kaggle Kernel `v4` Execution & Data Provenance Evidence

### 3.1 Compute / Hardware Configuration
Kaggle kernel metadata and `v4` execution stdout prove CPU-only execution:
- **Kernel Metadata:** `enable_gpu: false`, `enable_tpu: false`, `machine_shape: "None"`, `dataset_sources: []`.
- **Execution Environment (stdout):** `Ultralytics 8.4.215 Python-3.13.18 torch-2.11.0+cpu CPU (Intel Xeon CPU @ 2.20GHz)`.
- **Training Run Parameters:** `imgsz=320`, `epochs=8`, `batch=8`, `GPU_mem 0G` across all 8 epochs, total training duration `79.39s`.

### 3.2 Synthetic Fallback Data Provenance
- During `v4` execution, `try_download_roboflow()` checked environment variables and Kaggle Secrets for `ROBOFLOW_API_KEY`, found neither, and silently returned `[]`.
- This triggered the synthetic generator `generate_hydroponic_lettuce_pest_dataset()` (`[13.29s stdout] Generating calibrated NFT hydroponic lettuce pest dataset (thrips, whitefly, aphids)...`), creating **108 PIL-drawn geometric synthetic images**:
  - `72` train images
  - `18` validation images
  - `18` test images
- The `v4` kernel output inventory contains `269` files with **zero `raw_roboflow` directories or files**.

### 3.3 Metrics & Byte-for-Byte Artifact Identity
Metrics recorded in `ml/reports/evaluation_report.json` (`96713dd`) match Kaggle `v4` evaluation on the **18 synthetic test images** (`55` instances):
- **Untuned `yolo11n.pt` on 18 synthetic test images:** `mAP@50 = 0.08`, `mAP@50-95 = 0.0497`, `precision = 0.1193`, `recall = 0.3024`.
- **Finetuned `v4` on 18 synthetic test images:** `mAP@50 = 0.982`, `mAP@50-95 = 0.704`, `precision = 0.8708`, `recall = 0.9944`, `f1 = 0.9285` (per-class breakdown for `thrips`, `whitefly`, `aphids` omitted because `evaluate_ultralytics_model()` calls `model.val(..., verbose=False)` and exports only aggregate box metrics).
- **Artifact Cryptographic Identity:** Kaggle `v4` output `best.tflite` (`10,612,707` bytes = `10.121` MB, `sha256: a65a43cf450097e4417e5c59ab0e4e71c17906e0fbd580bb2639175ed368d963`) matches `feature/ml-local-work` (`96713dd`) `ml/artifacts/yolo11n_lettuce_pests.tflite` byte-for-byte.

---

## 4. Artifact & Metadata Discrepancy Audit

Inspecting the exported `.tflite` flatbuffer header (`bytes[4:8] == b'TFL3'`), its embedded Ultralytics `metadata.json` (`"imgsz": [320, 320]`, `"args": {"quantize": null}`, `"version": "8.4.215"`), Ultralytics `8.4.215`'s exporter (`format="tflite"` redirects to `format="litert"` via `litert_torch`, exporting FP32 NCHW tensors), and running `ai_edge_litert.interpreter.Interpreter` directly on `ml/artifacts/yolo11n_lettuce_pests.tflite` exposes severe discrepancies against `ml/artifacts/model_metadata.json`:

| Field / Property | Claimed in `ml/artifacts/model_metadata.json` | Actual `yolo11n_lettuce_pests.tflite` (Empirical) | Impact / Defect |
|---|---|---|---|
| `input_shape` & layout | `[1, 640, 640, 3]` (NHWC, 640px) | `[1, 3, 320, 320]` (NCHW/BCHW, 320px) | Mobile/client preprocessing expecting NHWC 640x640 fails with shape/rank mismatch |
| `output_shape` | `[1, 7, 8400]` (8400 anchors for 640px) | `[1, 7, 2100]` (2100 anchors for 320px) | Downstream decoder expecting 8400 anchors reads out-of-bounds or mis-parses predictions |
| `model_version` / precision | `yolo11n-fp16-a65a43cf` | FP32 (`quantize: null`, quantization `[0.0, 0]`) | Misleading FP16 label on an unquantized FP32 export |
| Artifact size | Not gated in `model_metadata.json` | `10,612,707` bytes (`10.121` MB) | Exceeds `ml/evaluate.py` `PROMOTION_GATES["model_size_mb"] <= 6.0` |
| `metrics` provenance | `map50: 0.982` | Measured on 18 synthetic PIL test images | Invalid as a real-world hydroponic lettuce pest metric |

### Verbatim Empirical `ai_edge_litert.interpreter.Interpreter` Verification Output
Executed in `ml/venv` (`Python 3.12.10`, `ai-edge-litert==2.4.0`, `numpy==2.5.5`) against `ml/artifacts/yolo11n_lettuce_pests.tflite`:

```json
{
  "size_bytes": 10612707,
  "size_mb": 10.121,
  "sha256": "a65a43cf450097e4417e5c59ab0e4e71c17906e0fbd580bb2639175ed368d963",
  "input_shape": [
    1,
    3,
    320,
    320
  ],
  "input_dtype": "float32",
  "input_quantization": [
    0.0,
    0
  ],
  "output_shape": [
    1,
    7,
    2100
  ],
  "output_dtype": "float32",
  "output_quantization": [
    0.0,
    0
  ],
  "smoke_invoke_output_shape": [
    1,
    7,
    2100
  ]
}
```

---

## 5. Real-Data Baseline & Roboflow Dataset Resolution (M2–M3)

- **Roboflow Dataset Provenance (`ml/reports/dataset_provenance.md`, `ml/reports/dataset_provenance.json`):**
  - All three Roboflow Universe sources probed **HTTP 200 (`accessible: true`)** using runtime credentials stored strictly outside tracked files:
    1. `puzzle-piece-detection/lettuce-pests` v6 (`yolov11`, `required: true`, raw: `1,584` train / `155` valid / `77` test; `0: aphid`, `1: whitefly`).
    2. `puzzle-piece-detection/lettuce-pest-detection` v1 (`yolov11`, `required: true`, raw: `1,396` train / `397` valid / `200` test; `0: thrips`).
    3. `agrivision-2025/lettuce-pests-wieje` v1 (`yolov11`, `required: false`, raw: `1,584` train / `155` valid / `77` test; `0: aphid`, `1: whitefly`).
  - Deduplication (`5,625` raw images scanned; `1,333` duplicates removed: `560` exact SHA-256 + `773` 8-dihedral pHash Hamming <= 2; `2,716` empty/unmapped skipped; `35,801` boxes kept) and group-aware stratified splitting (`450` connected-component groups at Hamming <= 4, `677` Roboflow base stems grouped) produced **`1,576` real images** (`1,245` train / `178` val / `153` test), **`0` synthetic images (`zero_synthetic_confirmed: true`)**, and **`0` cross-split leakage** (`status: "passed"`), with all three canonical classes (`0: thrips`, `1: whitefly`, `2: aphids`) present in all splits.
  - Uploaded as private Kaggle Dataset `adityadwiferdiansyah/hidrosense-lettuce-pests-real` so Roboflow credentials are never embedded in Kaggle kernel code or outputs.
- **Verified Kaggle GPU Execution Evidence (`adityadwiferdiansyah/hidrosense-yolov11n-lettuce-pests-training`):**
  - `enable_gpu: true`, `gpu_count: 2`, `device: "Tesla T4"`, `gpu_vram_gb: 14.56`, `torch_version: "2.11.0+cu130"`, `cuda_version: "13.0"`, `python_version: "3.13.16"`, `ultralytics_version: "8.4.216"`, `imgsz: 640`, `epochs: 45` (Stage 1 baseline, `700.39s`) / `80` (Stage 2 improved, `1312.96s`).
- **Held-Out Real Test Split Evaluation (`153` images, `2,889` instances: `160` thrips, `1,481` whitefly, `1,248` aphids):**

| Model / Stage | Scope | `mAP@50` | `mAP@50-95` | `Precision` | `Recall` | `F1` | Notes |
|---|---|---:|---:|---:|---:|---:|---|
| Pretrained COCO `yolo11n.pt` (zero-shot) | Overall | `0.0016` | `0.0005` | `0.0050` | `0.0396` | `0.0090` | `thrips` `mAP@50=0.0048` / `R=0.1187`; `whitefly`/`aphids` `0.0000` (`m3_summary.json`) |
| **Stage 1 Real-Data Baseline** (unweighted `1,245` train imgs, 45 ep, `700.39s`) | **Overall** | **`0.8539`** | **`0.5791`** | **`0.9196`** | **`0.8078`** | **`0.8601`** | True real-data baseline (`evaluation_report.json`, `m3_summary.json`) |
| Stage 1 Real-Data Baseline | `thrips` | `0.6152` | `0.3086` | `0.8671` | `0.5312` | `0.6588` | Minority-class recall bottleneck prior to balancing |
| Stage 1 Real-Data Baseline | `whitefly` | `0.9947` | `0.7502` | `0.9890` | `0.9865` | `0.9878` | Strong majority-class detection |
| Stage 1 Real-Data Baseline | `aphids` | `0.9517` | `0.6786` | `0.9026` | `0.9057` | `0.9042` | Strong majority-class detection |
| **Stage 2 Improved Model** (`4x` train-only `thrips` oversampling -> `1,788` imgs, 80 ep, `1312.96s`) | **Overall** | **`0.8913`** (`+0.0374`) | **`0.5765`** (`-0.0026`) | **`0.8952`** (`-0.0244`) | **`0.8566`** (`+0.0488`) | **`0.8755`** (`+0.0154`) | `beats_baseline: true`; all promotion gates `PASSED` |
| Stage 2 Improved Model | `thrips` | `0.7216` (`+0.1064`) | `0.3284` | `0.8106` | `0.6562` (`+0.1250`) | `0.7253` | Major minority-class recovery on held-out real test split |
| Stage 2 Improved Model | `whitefly` | `0.9938` (`-0.0009`) | `0.7319` | `0.9843` | `0.9865` | `0.9854` | Maintained parity with baseline |
| Stage 2 Improved Model | `aphids` | `0.9585` (`+0.0068`) | `0.6693` | `0.8908` | `0.9271` | `0.9086` | Improved `mAP@50` and recall |
| **M4 Production NHWC FP16 TFLite** (`ml/artifacts/yolo11n_lettuce_pests.tflite`) | **Ultralytics / `ai_edge_litert`** | **`0.8896` / `0.8893`** | `0.5424` / `0.5422` | `0.8930` / `0.8952` | `0.8533` / `0.8530` | `0.8727` / `0.8736` | `5.159 MB` (`5,409,324` B), `[1,640,640,3]`->`[1,7,8400]`, `drop=0.0017 <= 0.015`, `latency=129.65 ms`, `2,887` detections (`evaluation_report.json`, `model_metadata.json`) |

---

## 6. Pipeline Gaps Resolution Status (M1–M4)

| Gap ID | File / Component | Defect Observed in `96713dd` | Resolution Status & Implemented Fix |
|---|---|---|---|
| **G1** | `ml/prepare_dataset.py` (lines 44–60, 340–356) | Silent fallback to local dirs / `[]` when `ROBOFLOW_API_KEY` is missing; `ROBOFLOW_SOURCES` hardcodes `"version": "1"` for all 3 datasets; no CLI `main()` entrypoint. | **Resolved in M2 (`56c91fc`)**: Fail-fast when `ROBOFLOW_API_KEY` is missing or confirmed sources fail (zero synthetic fallback), configured source versions (`6`, `1`) with `agrivision-2025/lettuce-pests-wieje` HTTP 200 probe logging, and CLI `main()`. |
| **G2** | `ml/prepare_dataset.py` (lines 95–102, 176–180) | `_iter_source_image_label_pairs()` uses `list(img_path.parts).index("images")` (grabs *first* `"images"` segment instead of *last*, failing if an ancestor dir is named `images`); `canonicalize_label_name()` uses naive substring scan `if token in cleaned:`. | **Resolved in M2 (`56c91fc`, `c83c12a`)**: Replaced `.index("images")` with last `"images"` segment lookup and hardened `canonicalize_label_name()` synonym matching with unit tests. |
| **G3** | `ml/prepare_dataset.py` (lines 279–337) | `dataset_report.json` omits Roboflow source versions, access/probe status, split integrity hashes, and leak checks across train/val/test. | **Resolved in M2 (`56c91fc`, `c83c12a`)**: Emits full `dataset_provenance.{md,json}`, 8-dihedral pHash + Roboflow base-stem leak-free 80/10/10 splits (`0` overlaps), split manifest SHA-256 checksums, and uploaded `adityadwiferdiansyah/hidrosense-lettuce-pests-real`. |
| **G4** | `ml/train.py` (lines 73–108) | `write_kaggle_kernel_bundle()` references missing `kaggle_train_entry.py` and wrong slug `hidrosense-yolo11n-lettuce-pests`; writes JSON string booleans (`"true"`, `"false"`) instead of booleans; lacks automated push/poll/log/output retrieval. | **Resolved in M3 (`fd2719b`)**: Implemented `ml/kaggle_train_entry.py`, fixed slug to `hidrosense-yolov11n-lettuce-pests-training`, wrote strict JSON booleans (`enable_gpu: true`), attached dataset source, and executed Kaggle GPU `Tesla T4` x2 baseline + balanced training (`m3_summary.json`). |
| **G5** | `ml/evaluate.py` (lines 8–13, 47–99) | `evaluate_ultralytics_model()` uses `verbose=False` and omits per-class metrics (`thrips`, `whitefly`, `aphids`), `tflite_eval` block, and `provenance` block; `PROMOTION_GATES["model_size_mb"] <= 6.0` fails on `10.121 MB` FP32 LiteRT exports. | **Resolved in M4 (`a8ef80c`)**: Computed overall + per-class held-out test metrics, executed `ai_edge_litert.interpreter.Interpreter` over all `153` real test images (`tflite_map50_drop = 0.0017`, `5.159 MB <= 6.0`), and populated full `evaluation_report.json` (`status: "PASSED"`). |
| **G6** | `ml/export_tflite.py` (lines 89–146) | `build_model_metadata()` hardcodes NHWC `[1, img_size, img_size, 3]` and `8400` anchors instead of reading actual `Interpreter` tensors; `export_model_to_flutter_assets()` hardcodes `yolo11n-fp16-...` regardless of precision and omits `metrics`; Ultralytics `8.4.215` `format="tflite"` exports NCHW via `litert_torch`. | **Resolved in M4 (`a8ef80c`)**: Queries live `Interpreter` input/output shapes/dtypes, exports verified NHWC FP16 `5.159 MB` (`[1, 640, 640, 3]` -> `[1, 7, 8400]`) artifact, writes `yolo11n-fp16-cd388bda`, `sha256`, and `metrics` to `ml/artifacts/model_metadata.json`. |
| **G7** | `ml/requirements.txt` | Pinned `tensorflow>=2.17.0,<2.20.0`, `onnx>=1.16.0,<1.19.0`, and `onnx2tf>=1.22.0` conflict with `ml/venv` (`Python 3.12.10`, `numpy 2.5.5`, `protobuf 7.36.2`, `opencv-python 5.0.0.93`) and omit `ai-edge-litert>=2.1.4`. | **Resolved in M1**: Replaced with `ai-edge-litert>=2.1.4` and `roboflow>=1.1.48` (installed cleanly with `pip check` passing and zero downgrades), documenting Kaggle export-container deps separately. |
