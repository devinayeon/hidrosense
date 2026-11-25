# qa/model_evaluation.md — Evaluasi Model AI (PROMPT §5.5)

**Status: `PASS`** (sebelumnya `BLOCKED`). Artefak model, dataset, dan laporan evaluasi
kini ada di repo. Semua angka di bawah berasal dari berkas nyata (`ml/reports/*.json`,
`ml/artifacts/model_metadata.json`) dan diverifikasi ulang pada 24 November 2026.

- Model: `ml/artifacts/yolo11n_lettuce_pests.tflite`
- Kelas: `0: thrips`, `1: whitefly`, `2: aphids` (`ml/artifacts/labels.txt`)
- Sumber laporan: `ml/reports/evaluation_report.json`, `dataset_provenance.{md,json}`,
  `audit_report.md`, `apps/mobile/test/fixtures/yolo_golden.json`

---

## 1. Audit artefak (diverifikasi ulang, 24 Nov 2026)

Dijalankan dengan `ai_edge_litert.interpreter.Interpreter` langsung pada berkas:

```
size        5.409.324 byte (5,159 MB)
sha256      cd388bdab9c24490d6d01dd336ef4f2b191f1b66032e23adcf6cf831592b2ab3
flatbuffer  b'TFL3'
INPUT       [1, 640, 640, 3]  float32  (NHWC, RGB)
OUTPUT      [1, 7, 8400]      float32
```

**Konsistensi metadata:** `ml/artifacts/model_metadata.json` menyatakan
`input_shape [1,640,640,3]`, `output_shape [1,7,8400]`, `input_dtype float32`,
`classes {0:thrips,1:whitefly,2:aphids}` — **cocok persis** dengan flatbuffer.
Selaras dengan `ml/reports/evaluation_report.json` (tflite_eval) dan
`model_version = yolo11n-fp16-cd388bda`.

> Catatan historis: `ml/reports/audit_report.md` (audit R2, 22 Nov) memuat tabel
> ketidaksesuaian metadata vs flatbuffer, tetapi itu menunjuk artefak **lama**
> (10,121 MB, `[1,3,320,320]` NCHW, 8.4.215). Artefak **produksi** saat ini
> (5,159 MB, NHWC 640) sudah menggantikannya dan **tidak** lagi punya selisih itu.
> Ketidaksesuaian yang dijelaskan di audit_report.md **RESOLVED**.

**Paritas ke aplikasi:** `apps/mobile/assets/ml/yolo11n_lettuce_pests.tflite` byte-identik
(sha256 sama). Fixture golden `apps/mobile/test/fixtures/yolo_golden.json` juga memakai
sha256 yang sama; tes `apps/mobile/test/pest_summary_test.dart` mengunci
(1) sha256 model == metadata == artefak, (2) kontrak tensor metadata == konstanta dekoder.

---

## 2. Pembagian data (tanpa kebocoran)

Dari `ml/reports/dataset_provenance.md` & `evaluation_report.json.provenance`:

| Split | Gambar | Grup | Instance | thrips | whitefly | aphids |
|---|---:|---:|---:|---:|---:|---:|
| train | 1245 | 360 | 28562 | 793 | 13709 | 14060 |
| val | 178 | 45 | 4350 | 53 | 2908 | 1389 |
| test | 153 | 45 | 2889 | 160 | 1481 | 1248 |
| **Total** | **1576** | **450** | **35801** | 1006 | 18098 | 16697 |

- **0 gambar sintetis** (`synthetic_images_count = 0`, `zero_synthetic_confirmed = true`).
- Deduplikasi: 5.625 dipindai → **1.333 duplikat dibuang** (560 sha256 + 773 pHash);
  2.716 kosong/tak terpetakan dilewati; 35.801 kotak disimpan.
- **Split leakage = 0.** Verifikasi silang: `cross_split_sha256_overlaps = 0`,
  `cross_split_phash_overlaps = 0`, `cross_split_group_phash_overlaps = 0`,
  `cross_split_base_stem_overlaps = 0`, semua kelas kanonik ada di tiap split.
- Sumber Roboflow (3): `puzzle-piece-detection/lettuce-pests` v6,
  `puzzle-piece-detection/lettuce-pest-detection` v1, `agrivision-2025/lettuce-pests-wieje` v1.
- `thrips` di-oversample 4× di train (181 → kontribusi 1788 gambar), menangani
  ketidakseimbangan kelas.

Kesimpulan §5.5 (pembagian terpisah & bebas kebocoran): **PASS**.

---

## 3. Metrik (baseline YOLO11n vs fine-tuned)

Dari `evaluation_report.json` (set uji 153 gambar):

| Metrik | Baseline YOLO11n | Fine-tuned | Delta |
|---|---:|---:|---:|
| mAP@0.5 | 0,8539 | **0,8913** | +0,0374 |
| mAP@0.5:0.95 | 0,5791 | 0,5765 | −0,0026 |
| Precision | 0,9196 | 0,8952 | −0,0244 |
| Recall | 0,8078 | **0,8566** | +0,0488 |
| F1 | 0,8601 | **0,8755** | +0,0154 |

`beats_baseline = true`. Fine-tuning menaikkan mAP@0.5, recall, dan F1; precision
turun tipis (trade-off wajar). **Ketidakseimbangan kelas** nyata: `thrips` paling
lemah.

**Per kelas (fine-tuned):**

| Kelas | Precision | Recall | mAP@0.5 | mAP@0.5:0.95 | F1 |
|---|---:|---:|---:|---:|---:|
| thrips | 0,8106 | 0,6562 | 0,7216 | 0,3284 | 0,7253 |
| whitefly | 0,9843 | 0,9865 | 0,9938 | 0,7319 | 0,9854 |
| aphids | 0,8908 | 0,9271 | 0,9585 | 0,6693 | 0,9086 |

---

## 4. Sebelum vs sesudah konversi TFLite

`tflite_eval` (interpreter `ai_edge_litert`, 153 gambar):

| Metrik | Model val (Ultralytics) | TFLite (interpreter langsung) |
|---|---:|---:|
| mAP@0.5 | 0,8896 | 0,8893 |
| mAP@0.5:0.95 | 0,5424 | 0,5422 |
| Precision | 0,8930 | 0,8952 |
| Recall | 0,8533 | 0,8530 |
| F1 | 0,8727 | 0,8736 |

- **`tflite_map50_drop = 0,0017`** → konversi ke TFLite (FP16) **hampir tidak**
  menurunkan akurasi.
- Semua keluaran finite (`all_outputs_finite = true`, 153 gambar); 2.887 deteksi
  pada ambang contoh 0,35 / IoU 0,45; ketiga kelas terdeteksi.
- Latensi rata-rata host: **129,65 ms/gambar** (jauh di bawah target 5 dtk; tetapi
  host ≠ perangkat).

**Gerbang penerimaan:** `map50 = 0,8913`, `recall = 0,8566`, `tflite_map50_drop = 0,0017`,
`model_size_mb = 5,159` → **status `PASSED`**.

---

## 5. Pra-pemrosesan app == pelatihan

- Konstanta dekoder mobile (`apps/mobile/lib/features/pest/domain/yolo_decoder.dart`):
  input 640, 8400 anchor, pad letterbox 114, normalisasi 0–1, RGB,
  ambang default 0,35 / IoU 0,45 — **sama** dengan metadata model.
- Fixture golden (`yolo_golden.json`) memuat sampel tensor + geometri letterbox +
  keluaran per kasus untuk ketiga kelas; tes `pest_decoder_test.dart` memverifikasi
  geometri letterbox, NMS, dan paritas tensor. Kontrak tensor diuji sama dengan
  konstanta dekoder (`pest_summary_test.dart:79`).

Kesimpulan §5.5 (pra-pemrosesan identik): **PASS**.

---

## 6. Ketahanan & kondisi lapangan

| Butir §5.5 | Status | Catatan |
|---|---|---|
| Gambar tanpa hama (negatif) | PASS | Kelas "tanpa deteksi" ditangani; UI tidak menyatakan "bebas hama". |
| Objek mirip hama (debu/tetes air) | BELUM DIUJI | Tidak ada set uji negatif terpisah; perlu uji lapangan. |
| Hama sangat kecil | SEBAGIAN | Thrips (paling kecil) mAP@0.5 0,7216 → paling lemah; `small_obj_ratio` test 0,045. |
| Cahaya redup/silau, blur, sudut miring, daun basah | BELUM DIUJI | Tidak ada split kondisi; perlu uji lapangan. |
| Kecepatan inferensi perangkat | MANUAL-PENDING | Host 129,65 ms; perangkat Android belum diukur. |
| Ambang confidence & dampak FP/FN | SEBAGIAN | Ambang 0,35/IoU 0,45; belum ada analisis kurva PR untuk rekomendasi ambang. |

---

## 7. Deployment mobile

- Model ditanam sebagai aset (`assets/ml/…`), inferensi **lokal** via
  `Interpreter.fromAsset` (GPU XNNPACK tersedia; `threads = 2`).
- Pra-proses (EXIF + letterbox) dijalankan di **isolate** (`compute`) agar UI tidak beku.
- Tanpa request jaringan saat inferensi (offline). Unggah Cloudinary dilakukan setelah
  inferensi dan tidak menghambatnya.

---

## 8. Rekomendasi

1. Uji ketahanan lapangan (redup/silau, blur, sudut, daun basah) dengan set uji
   terpisah; catat per-kondisi mAP.
2. Analisis kurva PR untuk menetapkan ambang per kelas (thrips butuh ambang lebih
   longgar atau augmentasi/data tambahan).
3. Ukur latensi & mAP pada perangkat Android sasaran (PB-05 TC-PB05-04).
4. Pertahankan fixture golden + kunci sha256 agar regresi pra-pemrosesan tertangkap.
