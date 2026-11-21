# HidroSense YOLOv11n Lettuce Pest Detection — R2 Audit Report

**Date:** 2026-11-21  
**Branch:** `feature/ml-production-pipeline` (reconciled `ml/` from `feature/ml-local-work` `96713dd` onto `main` `05849e0`)  
**Audited Kernel:** `adityadwiferdiansyah/hidrosense-yolov11n-lettuce-pests-training` (`id_no: 145430380`, `currentVersionNumber: 4`)  
**Audited Artifact:** `ml/artifacts/yolo11n_lettuce_pests.tflite` (`sha256: a65a43cf450097e4417e5c59ab0e4e71c17906e0fbd580bb2639175ed368d963`)

---

## 1. Executive Summary

**Audit Verdict:**
1. The previously committed model (`ml/artifacts/yolo11n_lettuce_pests.tflite`, `10.121` MB, reported `mAP@50 = 0.9820`) was **NOT trained on real Roboflow data**. When `ROBOFLOW_API_KEY` was absent from both environment variables and Kaggle Secrets, the kernel script silently fell back to generating **108 synthetic PIL-drawn geometric images** (`72` train / `18` val / `18` test).
2. The model was **NOT trained on GPU**. Kaggle kernel `v4` executed with `enable_gpu: false` on a **CPU** (`torch-2.11.0+cpu`, `Intel Xeon CPU @ 2.20GHz`, `GPU_mem 0G`) at reduced resolution (`imgsz=320`, `epochs=8`, `batch=8`).
3. **No real-data baseline exists yet.** Because every prior metric in `ml/reports/evaluation_report.json` (`baseline mAP@50 = 0.08`, `finetuned mAP@50 = 0.9820`) was measured on 18 synthetic images, those numbers have zero real-world validity. Establishing a true real-data baseline on held-out real Roboflow test images is mandatory in M2–M3 before evaluating any fine-tuned production model.
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

## 5. Real-Data Baseline Status & Roboflow Dataset Readiness

- **Real-Data Baseline Status:** **Does not exist yet.** No pretrained or fine-tuned evaluation has been run on a held-out real Roboflow test split. In M3, pretrained `yolo11n.pt` must first be evaluated on the held-out real test split (`split="test"`, `imgsz=640`) to establish the true real-data baseline before measuring improvements from Kaggle GPU fine-tuning.
- **Target Roboflow Universe Datasets (R3 + Follow-Up):**
  1. `puzzle-piece-detection/lettuce-pests` — confirmed version **`6`** (`yolov11` export format).
  2. `puzzle-piece-detection/lettuce-pest-detection` — confirmed version **`1`** (`yolov11` export format).
  3. `agrivision-2025/lettuce-pests-wieje` — accessibility to be probed in M2 using `ROBOFLOW_API_KEY` (stored strictly outside tracked files, e.g. gitignored `ml/.env`); if `404`/unavailable, document the probe outcome in provenance logs and proceed with the two confirmed datasets.
- **Kaggle Training Strategy:** Download, canonicalize (`0: thrips`, `1: whitefly`, `2: aphids`), pHash-deduplicate, and stratified-split (`80/10/10`) locally in M2, then upload the merged dataset as a private Kaggle Dataset (`adityadwiferdiansyah/hidrosense-lettuce-pests-real`) mounted into the Kaggle GPU kernel so `ROBOFLOW_API_KEY` is never exposed inside Kaggle kernel scripts or outputs.

---

## 6. Itemized Pipeline Gaps to Resolve (M1–M4 Roadmap)

| Gap ID | File / Component | Defect Observed in `96713dd` | Target Milestone & Required Fix |
|---|---|---|---|
| **G1** | `ml/prepare_dataset.py` (lines 44–60, 340–356) | Silent fallback to local dirs / `[]` when `ROBOFLOW_API_KEY` is missing; `ROBOFLOW_SOURCES` hardcodes `"version": "1"` for all 3 datasets; no CLI `main()` entrypoint. | **M2**: Fail fast if `ROBOFLOW_API_KEY` is missing or confirmed sources fail; support configured versions (`6`, `1`) and graceful probe/log for `lettuce-pests-wieje`; add CLI `main()`. |
| **G2** | `ml/prepare_dataset.py` (lines 95–102, 176–180) | `_iter_source_image_label_pairs()` uses `list(img_path.parts).index("images")` (grabs *first* `"images"` segment instead of *last*, failing if an ancestor dir is named `images`); `canonicalize_label_name()` uses naive substring scan `if token in cleaned:`. | **M2**: Replace `.index("images")` with last `"images"` segment lookup + unit test; harden synonym matching in `canonicalize_label_name()` to prevent false-positive substring matches. |
| **G3** | `ml/prepare_dataset.py` (lines 279–337) | `dataset_report.json` omits Roboflow source versions, access/probe status, split integrity hashes, and leak checks across train/val/test. | **M2**: Add complete source provenance manifest, split overlap/leakage verification, and checksums; upload verified dataset to Kaggle Datasets. |
| **G4** | `ml/train.py` (lines 73–108) | `write_kaggle_kernel_bundle()` references missing `kaggle_train_entry.py` and wrong slug `hidrosense-yolo11n-lettuce-pests`; writes JSON string booleans (`"true"`, `"false"`) instead of booleans; lacks automated push/poll/log/output retrieval. | **M3**: Implement `ml/kaggle_train_entry.py`, fix slug to `hidrosense-yolov11n-lettuce-pests-training`, fix boolean metadata fields, attach `dataset_sources`, enforce `enable_gpu: true` (`imgsz=640`), run real-data baseline + fine-tuned GPU training, and verify GPU logs. |
| **G5** | `ml/evaluate.py` (lines 8–13, 47–99) | `evaluate_ultralytics_model()` uses `verbose=False` and omits per-class metrics (`thrips`, `whitefly`, `aphids`), `tflite_eval` block, and `provenance` block; `PROMOTION_GATES["model_size_mb"] <= 6.0` fails on `10.121 MB` FP32 LiteRT exports. | **M4**: Compute overall + per-class held-out test metrics, execute direct `ai_edge_litert.interpreter.Interpreter` evaluation on real test images (verifying `tflite_map50_drop`), populate `evaluation_report.json` per contract, and resolve size gate / quantization (`int8`/`w8a16`/`w8a32` or aligned gate). |
| **G6** | `ml/export_tflite.py` (lines 89–146) | `build_model_metadata()` hardcodes NHWC `[1, img_size, img_size, 3]` and `8400` anchors instead of reading actual `Interpreter` tensors; `export_model_to_flutter_assets()` hardcodes `yolo11n-fp16-...` regardless of precision and omits `metrics`; Ultralytics `8.4.215` `format="tflite"` exports NCHW via `litert_torch`. | **M4**: Query actual `Interpreter` input/output shapes, dtypes, and quantization params; explicitly reconcile NCHW (`litert_torch`) vs. NHWC (`onnx2tf`) contract; fix `model_version` tag; include `metrics` & SHA-256 in `model_metadata.json`. |
| **G7** | `ml/requirements.txt` | Pinned `tensorflow>=2.17.0,<2.20.0`, `onnx>=1.16.0,<1.19.0`, and `onnx2tf>=1.22.0` conflict with `ml/venv` (`Python 3.12.10`, `numpy 2.5.5`, `protobuf 7.36.2`, `opencv-python 5.0.0.93`) and omit `ai-edge-litert>=2.1.4`. | **Resolved in M1**: Replaced with `ai-edge-litert>=2.1.4` and `roboflow>=1.1.48` (installed cleanly with `pip check` passing and zero downgrades), documenting Kaggle export-container deps separately. |
