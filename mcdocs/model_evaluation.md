# mcdocs/model_evaluation.md — Evaluasi Model AI (PROMPT §5.5)

**Status: `BLOCKED`** — pekerjaan tidak dapat dijalankan karena **artefak model dan
dataset tidak ada di repo**. Tidak ada angka yang dikarang.

## Bukti ketiadaan artefak (nyata)

```
$ find . -type f \( -name '*.tflite' -o -name '*.onnx' -o -name '*.pt' -o -name '*.h5' -o -name '*.keras' \) \
    -not -path '*/node_modules/*'
(selesai — tidak ada berkas)

$ ls -la ml/
-rw-r--r--. 1 eiser eiser   0 evaluate.py        <- 0 byte
-rw-r--r--. 1 eiser eiser   0 export_tflite.py   <- 0 byte
-rw-r--r--. 1 eiser eiser  22 requirements.txt
-rw-r--r--. 1 eiser eiser   0 train.py           <- 0 byte

$ find . -type d \( -iname 'dataset*' -o -iname '*training*' \) -not -path '*/node_modules/*'
(tidak ada)

$ grep -iE 'camera|image_picker|tflite|tensorflow|opencv' apps/mobile/pubspec.yaml
(tidak ada)
$ grep -i camera apps/mobile/android/app/src/main/AndroidManifest.xml
(tidak ada)
```

Kesimpulan dari bukti:
1. Tidak ada model terlatih (`.tflite`) maupun model sumber (`.pt`/`.onnx`).
2. Skrip `ml/train.py`, `ml/evaluate.py`, `ml/export_tflite.py` **kosong (0 byte)** —
   tidak ada definisi pelatihan/ekspor untuk dijalankan.
3. Tidak ada dataset (citra hama thrips/whitefly/aphids) di repo.
4. Aplikasi Flutter **tidak** memuat plugin kamera/TensorFlow Lite dan **tidak** meminta
   izin `CAMERA`, jadi inferensi on-device belum ada implementasinya.

## Dampak ke area terkait

| Butir §5.5 | Status | Alasan |
|---|---|---|
| Pemisahan train/val/test tanpa kebocoran | `BLOCKED` | Tidak ada dataset. |
| Precision/recall/F1/mAP per kelas | `BLOCKED` | Tidak ada model & set uji. |
| Perbandingan vs baseline YOLO11n | `BLOCKED` | Tidak ada kedua model. |
| Sebelum vs sesudah konversi TFLite | `BLOCKED` | Tidak ada konversi/model. |
| Robustness gambar lapangan | `BLOCKED` | Tidak ada inferensi. |
| Pra-pemrosesan app == pelatihan | `BLOCKED` | Tidak ada pipeline pra-pemrosesan di app. |
| Ambang confidence & dampaknya | `BLOCKED` | Ambang hanya ada di data mock UI. |

## Yang BISA diverifikasi (dan sudah dilakukan)

- **PB-05 UI** di `apps/mobile`: layar deteksi memakai **data mockup desain**, bukan
  inferensi nyata; tidak ada kamera/galeri, tidak ada izin kamera. Ini dicatat sebagai
  `N/A`/gap di `rtm.md`, bukan sebagai hasil model.
- **Ketentuan perilaku** "hasil kosong tidak boleh dinyatakan 'tanaman bebas hama'"
  belum dapat diuji pada inferensi nyata; teks layar mock sudah diperiksa (lihat
  `testing.md` TC-PB05-*), tetapi tidak mewakili model.

## Rekomendasi (agar bisa dievaluasi tim sebelum ujian)

1. Letakkan model terlatih + skrip ekspor yang tidak kosong di `ml/` beserta hash dataset.
2. Tambahkan `dataset/` dengan pembagian split eksplisit dan hash per-gambar (deteksi duplikat).
3. Setelah model ada, jalankan `ml/evaluate.py` untuk mAP@0.5 & mAP@0.5:0.95 per kelas,
   bandingkan dengan YOLO11n baseline.
4. Baru kemudian lakukan uji inferensi on-device (PB-05) pada perangkat nyata.
