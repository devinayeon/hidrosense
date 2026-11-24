# qa/testing.md — Matriks Uji & Bukti (HidroSense)

Dokumen ini memuat **semua test case** beserta status nyata dan cara menjalankannya ulang.
Status yang dipakai: `PASS`, `FAIL` (temuan), `BLOCKED` (dengan alasan), `N/A` (dengan
alasan), `MANUAL-PENDING` (uji perangkat fisik, lihat `qa/manual_checklist.md`).

- Tanggal pengujian: **24 November 2026** (re-QA setelah backend + AI/`ml` menyusul).
- Lingkungan: Linux x86_64; Node v22.23.1; npm 10.9.8; Flutter 3.47.7 (stable);
  Python 3.14.3.
- DB uji: `/tmp/opencode/hsqa/qa.db` (SQLite), server `http://127.0.0.1:3100`.
- **Tidak** menyentuh data produksi; **tidak** memakai kredensial produksi
  (Cloudinary memakai kredensial palsu khusus uji).
- Perangkat Android: **tidak ada** (`adb devices` kosong) → uji on-device `MANUAL-PENDING`.

> Catatan sesi: pada sesi ini backend (`apps/backend`), AI (`ml`) dan fitur mobile
> deteksi/rotasi sudah dibangun. Status lamanya (`N/A`/`BLOCKED` karena "belum ada")
> **digantikan** oleh hasil pengujian nyata pada fitur yang kini ada.

---

## 0. Cara menjalankan ulang semua tes

```bash
# 1) Backend — unit/integration (432 tes)
cd apps/backend && npm test

# 2) Backend — siapkan DB uji terisolasi + migrasi + seed
bash qa/reset-backend-qa.sh        # -> /tmp/opencode/hsqa/qa.db

# 3) Backend — server uji (terminal terpisah). Kredensial Cloudinary palsu (uji).
cd apps/backend
DATABASE_URL=file:/tmp/opencode/hsqa/qa.db PORT=3100 \
  CLOUDINARY_CLOUD_NAME=hsqa CLOUDINARY_API_KEY=123456789012 \
  CLOUDINARY_API_SECRET=hsqa_secret_123 node --import tsx src/server.ts

# 4) Backend — suite adversarial (butuh server di atas).
#    Bersihkan rate limit login dulu agar tidak 429 antar-run:
sqlite3 /tmp/opencode/hsqa/qa.db "DELETE FROM auth_rate_limits;"
BASE_URL=http://127.0.0.1:3100/api/v1 bash qa/backend-api-smoke.sh       # 73 tes
BASE_URL=http://127.0.0.1:3100/api/v1 bash qa/backend-boundaries.sh      # 11 tes batas
BASE_URL=http://127.0.0.1:3100/api/v1 bash qa/backend-e2e.sh             # 28 tes E2E
BASE_URL=http://127.0.0.1:3100/api/v1 bash qa/backend-concurrency.sh     # 22 tes balapan
BASE_URL=http://127.0.0.1:3100/api/v1 CLOUDINARY_API_SECRET=hsqa_secret_123 \
  bash qa/backend-pest-rotation.sh                                       # 109 tes pest/rotasi
BASE_URL=http://127.0.0.1:3100/api/v1 REPS=12 bash qa/perf.sh            # latensi

# 5) Backend — fuzz invarian (§5.8; tanpa jaringan, DB in-memory).
cd apps/backend && node --import tsx qa/fuzz-invariants.mjs               # 638 pemeriksaan

# 6) Mobile
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test                                           # 584 tes

# 7) AI / ML
cd /home/eiser/coolyeah/PPL/hidrosense && python3 -m pytest ml/tests -q   # 165 lulus, 3 gagal-harness

# 8) Audit integritas data (kueri ulang).
sqlite3 -header /tmp/opencode/hsqa/qa.db < qa/audit_queries.sql
```

---

## 1. Baseline & hasil akhir

| Suite | Baseline (sebelum sesi ini) | Hasil akhir | Catatan |
|---|---|---|---|
| `npm test` (backend) | 432/432 PASS | **432/432 PASS** | Tidak ada tes backend yang diubah. |
| `flutter test` (mobile) | 584 PASS | **584 PASS** (exit 0) | Termasuk 61 tes fitur pest baru. |
| `flutter analyze` | 2 warning aset | **2 warning aset** | `assets/illustrations/inventory/` & `.../features/` (dir hilang); bukan dari QA. |
| `python3 -m pytest ml/tests` | tak jalan (dep hilang) | **165 PASS / 3 FAIL / 0 SKIP** | 3 FAIL = bug harness ML, bukan model (lihat §4.8). |
| `qa/backend-pest-rotation.sh` | — (baru) | **109/109 PASS** | Fitur baru backend. |
| fuzz §5.8 | 638 lulus | **638 lulus ×3 run** | Perbaikan kueri AQ-10 (bug harness, §4.7). |

---

## 2. Ringkasan per Area (PROMPT §4 & §5)

| Area | Total TC | PASS | FAIL | BLOCKED | N/A | MANUAL-PENDING |
|---|---|---|---|---|---|---|
| PB-01 Autentikasi & hak akses | 35 | 34 | 0 | 0 | 0 | 1 |
| PB-02 Inventaris & stok | 16 | 16 | 0 | 0 | 0 | 0 |
| PB-03 Penyemaian bibit | 14 | 12 | 0 | 0 | 0 | 2 |
| PB-04 Pertumbuhan & meja | 18 | 18 | 0 | 0 | 0 | 0 |
| PB-05 Deteksi hama (YOLO TFLite) | 10 | 9 | 0 | 0 | 0 | 1 |
| PB-06 Rekomendasi & perawatan | 9 | 7 | 0 | 1 | 1 | 0 |
| PB-07 Penyimpanan lokal & sinkronisasi | 19 | 14 | 0 | 0 | 0 | 5 |
| PB-08 Pencatatan panen | 11 | 11 | 0 | 0 | 0 | 0 |
| PB-09 Pencatatan penjualan | 12 | 12 | 0 | 0 | 0 | 0 |
| PB-10 Rekomendasi cuaca (BMKG) | 14 | 12 | 0 | 2 | 0 | 0 |
| PB-11 Pengelolaan akun | 13 | 13 | 0 | 0 | 0 | 0 |
| §5 lintas-area | 33 | 25 | 2 | 0 | 0 | 6 |
| **Total** | **204** | **183** | **2** | **3** | **1** | **15** |

> Jumlah pada kolom = 183 + 2 + 3 + 1 + 15 = **204**. Tidak ada test case berstatus kosong.
> Dua **FAIL** berada di §5.3 (keamanan): `TC-5.3-10` = token plaintext (BUG-05) dan
> `TC-5.3-11` = dependensi rentan (BUG-04) — keduanya temuan **keamanan**, bukan cacat
> alur bisnis, dan berada di luar batas perbaikan sesi (`apps/mobile/` saja) sehingga
> `NEEDS-HUMAN-REVIEW`. `BLOCKED`/`N/A` selalu disertai alasan; `MANUAL-PENDING` hanya
> untuk uji perangkat/mitra. Tiga kegagalan ML pada §4.8 adalah cacat harness uji ML,
> bukan produk — dicatat di `qa/issues.md` sebagai **BUG-12** (QA-tooling).

---

## 3. Matriks Test Case

Kolom **Bukti** menunjuk skrip/tes yang benar-benar dijalankan. Bukti API memakai ID test
di `qa/backend-*.sh` (mis. `AU-01`) yang dapat dijalankan ulang dengan perintah di §0.

### PB-01 Autentikasi & Hak Akses

| ID | Skenario | Hasil diharapkan | Hasil aktual | Status | Bukti |
|---|---|---|---|---|---|
| TC-PB01-01 | Login petani valid | 200 + akses_token | Sesuai | PASS | `AU-01` |
| TC-PB01-02 | Login pegawai valid | 200 + akses_token | Sesuai | PASS | `AU-02` |
| TC-PB01-03 | Username beda kasus "PETANI" | Diterima (kanonik) | Sesuai | PASS | `AU-03` |
| TC-PB01-04 | Password salah | 401 | Sesuai | PASS | `AU-04` |
| TC-PB01-05 | Username tak ada (tak bocorkan) | 401 sama seperti salah | Sesuai | PASS | `AU-05` |
| TC-PB01-06 | Username kosong | 400 | Sesuai | PASS | `AU-06` |
| TC-PB01-07 | Username hanya spasi | 400 | Sesuai | PASS | `AU-07` |
| TC-PB01-08 | Username 1001 karakter | 400 | Sesuai | PASS | `AU-08` |
| TC-PB01-09 | Username unicode/emoji | 401 | Sesuai | PASS | `AU-09` |
| TC-PB01-10 | Injection `' OR '1'='1` | 401 (parameterized) | Sesuai | PASS | `AU-10` |
| TC-PB01-11 | Injection `"; DROP TABLE users;--` | 401, tabel utuh | Sesuai | PASS | `AU-11` |
| TC-PB01-12 | XSS `<script>` di nama (field teks) | Disimpan literal, bukan 5xx | Sesuai | PASS | `AC-06` |
| TC-PB01-13 | Field ekstra saat login | 400 (strict) | Sesuai | PASS | `AU-12` |
| TC-PB01-14 | Akses tanpa token | 401 | Sesuai | PASS | `AU-13` |
| TC-PB01-15 | Token sampah | 401 | Sesuai | PASS | `AU-14` |
| TC-PB01-16 | Pegawai GET /penjualan | 403 | Sesuai | PASS | `AZ-01` |
| TC-PB01-17 | Pegawai POST /penjualan | 403 | Sesuai | PASS | `AZ-02` |
| TC-PB01-18 | Pegawai GET /employees | 403 | Sesuai | PASS | `AZ-03` |
| TC-PB01-19 | Pegawai GET /profile | 403 | Sesuai | PASS | `AZ-04` |
| TC-PB01-20 | Pegawai PATCH /profile (escalation) | 403 | Sesuai | PASS | `AZ-05` |
| TC-PB01-21 | Pegawai GET /inventaris (boleh) | 200 | Sesuai | PASS | `AZ-06` |
| TC-PB01-22 | Pegawai GET /panen (boleh) | 200 | Sesuai | PASS | `AZ-07` |
| TC-PB01-23 | Pegawai GET /penyemaian (boleh) | 200 | Sesuai | PASS | `AZ-08` |
| TC-PB01-24 | Pegawai GET /meja-tanam (boleh) | 200 | Sesuai | PASS | `AZ-09` |
| TC-PB01-25 | Pegawai GET /pindaian, /rekomendasi (ditolak) | 403 | Sesuai | PASS | `SC-*/RC-*` (pest suite) |
| TC-PB01-26 | Pegawai POST /pindaian, terima rekomendasi | 403 | Sesuai | PASS | pest suite (role pegawai) |
| TC-PB01-27 | Petani PATCH /profile role escalation | 400 | Sesuai | PASS | `AZ-10` |
| TC-PB01-28 | Password tersimpan hash (DB) | `scrypt$...`, bukan plaintext | Sesuai | PASS | `sqlite3 qa.db "SELECT substr(password,1,14) FROM users"` |
| TC-PB01-29 | UI sembunyikan penjualan utk pegawai | Tidak tampil | Sesuai | PASS | `apps/mobile/test/sales_access_test.dart` |
| TC-PB01-30 | UI deteksi: pegawai tanpa izin → pesan | Pesan khusus, tanpa kamera | Sesuai | PASS | `pest_scan_page_test.dart` ("akun tanpa izin deteksi") |
| TC-PB01-31 | Back-gate setelah logout | Halaman terproteksi tak terbuka | Sesuai | PASS | `apps/mobile/test/app_gate_back_test.dart` |
| TC-PB01-32 | Brute force: rate limit login | Ada pembatasan | Sesuai | PASS | 10/15 mnt per IP+user; §4.6 |
| TC-PB01-33 | Rate limit global | 429 saat lampaui | Sesuai | PASS | §4.6 |
| TC-PB01-34 | Sesi kedaluwarsa → refresh | 401 sebelum refresh | Sesuai | PASS | `apps/backend/test/session-sliding.test.js` |
| TC-PB01-35 | Perilaku sesi pada perangkat nyata | Butuh perangkat | — | MANUAL-PENDING | `qa/manual_checklist.md` |

### PB-02 Inventaris & Transaksi Stok

| ID | Skenario | Hasil diharapkan | Hasil aktual | Status | Bukti |
|---|---|---|---|---|---|
| TC-PB02-01 | Keluar > saldo | 409, saldo tetap | Sesuai | PASS | `ST-01/02` |
| TC-PB02-02 | Jumlah 0 | 400 | Sesuai | PASS | `ST-03` |
| TC-PB02-03 | Jumlah negatif | 400 | Sesuai | PASS | `ST-04` |
| TC-PB02-04 | Jumlah non-angka | 400 | Sesuai | PASS | `ST-05` |
| TC-PB02-05 | Jumlah NaN | 400 | Sesuai | PASS | `ST-06` |
| TC-PB02-06 | Satuan tak cocok barang | 422 | Sesuai | PASS | `ST-07` |
| TC-PB02-07 | Tanpa Idempotency-Key | 400 | Sesuai | PASS | `ST-08` |
| TC-PB02-08 | Inventaris tak ada | 422 | Sesuai | PASS | `ST-09` |
| TC-PB02-09 | Saldo = akumulasi masuk/keluar | Cocok buku besar | Sesuai | PASS | Fuzz `AQ-02` (§5.8) |
| TC-PB02-10 | Stok tak pernah negatif | >= 0 selalu | Sesuai | PASS | Fuzz `AQ-01`; DB CHECK rentang |
| TC-PB02-11 | Double-tap simpan = 1 transaksi | Tidak ganda | Sesuai | PASS | Idempotensi (`ID-01..04`) |
| TC-PB02-12 | Indikator stok menipis (batas) | `saldo < minimum` | Sesuai (setelah BUG-03) | PASS | `v2_inventaris_status_test.dart` |
| TC-PB02-13 | Nama barang duplikat | Ditolak/ditangani | Sesuai | PASS | `inventory.test.js` |
| TC-PB02-14 | Daftar besar & pagination | Lancar, limit <= 100 | Sesuai | PASS | `QS-01..03` |
| TC-PB02-15 | Barang nonaktif tak bisa transaksi | Ditolak | Sesuai | PASS | `ST-09`, `inventory.test.js` |
| TC-PB02-16 | Riwayat barang diarsip tetap ada | Riwayat utuh | Sesuai | PASS | `inventory_archive_test.dart` |

### PB-03 Penyemaian Bibit

| ID | Skenario | Hasil diharapkan | Hasil aktual | Status | Bukti |
|---|---|---|---|---|---|
| TC-PB03-01 | Tambah semai jumlah bulat positif | 201 | Sesuai | PASS | `nursery.test.js`; E2E `E2E-06` |
| TC-PB03-02 | Jumlah 0/negatif/pecahan | Ditolak | Sesuai | PASS | `nursery.test.js` |
| TC-PB03-03 | Sisa benih = benih - dipindah | Tepat | Sesuai | PASS | E2E `E2E-08/12` |
| TC-PB03-04 | Pindah tepat sebanyak benih | 201 | Sesuai | PASS | `BND-03` |
| TC-PB03-05 | Pindah 1 melebihi benih | 409 | Sesuai | PASS | `BND-04` |
| TC-PB03-06 | Ubah benih < sudah dipindah | Ditolak | Sesuai | PASS | `nursery-remediation.test.js` |
| TC-PB03-07 | Status penyemaian mengikuti alur | Berubah benar | Sesuai | PASS | `nursery_remediation_test.dart` |
| TC-PB03-08 | HSS dari tanggal semai (WIB) | Benar (0/14/15/16) | Sesuai | PASS | `growth-policy.test.js` |
| TC-PB03-09 | Pindah usia < 15 hari ditolak | 400 | Sesuai | PASS | `BND-01` |
| TC-PB03-10 | Pindah tepat 15 hari diterima | 201 | Sesuai | PASS | `BND-02` |
| TC-PB03-11 | Notifikasi tepat hari ke-15 | Muncul sekali | Butuh perangkat | MANUAL-PENDING | `manual_checklist.md` MC-NOTIF-* |
| TC-PB03-12 | Tanggal semai masa depan | Ditolak | Sesuai | PASS | `dateSchema` refine |
| TC-PB03-13 | Tanggal batas bulan/tahun | Ditolak bila invalid | Sesuai | PASS | `dateSchema` refine |
| TC-PB03-14 | Notifikasi setelah reboot/app reopen | Tetap benar | Butuh perangkat | MANUAL-PENDING | `manual_checklist.md` MC-NOTIF-* |

### PB-04 Pertumbuhan & Meja Tanam

| ID | Skenario | Hasil diharapkan | Hasil aktual | Status | Bukti |
|---|---|---|---|---|---|
| TC-PB04-01 | Kode meja duplikat | 409 | Sesuai | PASS | `TB-01` |
| TC-PB04-02 | jumlah_lubang 0 | 400 | Sesuai | PASS | `TB-02` |
| TC-PB04-03 | Status dari klien ditolak (server-derived) | 400 | Sesuai | PASS | `TB-03` |
| TC-PB04-04 | Pindah bibit terlalu muda | 400 | Sesuai | PASS | `TB-04`, `BND-01` |
| TC-PB04-05 | Pindah melebihi sisa bibit | 409 | Sesuai | PASS | `TB-05`, `BND-04` |
| TC-PB04-06 | Pindah melebihi kapasitas meja | 409 | Sesuai | PASS | `TB-06`, `BND-06` |
| TC-PB04-07 | Pindah tepat kapasitas | 201 | Sesuai | PASS | `BND-05` |
| TC-PB04-08 | Status meja "penuh" otomatis di 10/10 | Status tepat | Sesuai | PASS | `BND-07` |
| TC-PB04-09 | Meja perbaikan tak bisa dipakai | 409 | Sesuai | PASS | `TB-07` |
| TC-PB04-10 | tanaman_aktif >= 0 | Selalu >= 0 | Sesuai | PASS | Fuzz `AQ-04/08` |
| TC-PB04-11 | Estimasi panen = pindah + 45 hari | Tepat | Sesuai | PASS | E2E `E2E-11` |
| TC-PB04-12 | Umur berdasarkan HSS benar | Benar | Sesuai | PASS | `growth-policy.test.js` |
| TC-PB04-13 | Kapasitas meja diperbarui tiap langkah | Tepat | Sesuai | PASS | E2E `E2E-13/14/16/20/26` |
| TC-PB04-14 | Rusak > tanaman aktif ditolak | 409 | Sesuai | PASS | `damage.test.js`; Fuzz `AQ-08` |
| TC-PB04-15 | Urutan rusak→panen→rusak tak negatif | Tak negatif | Sesuai | PASS | Fuzz rantai |
| TC-PB04-16 | Ubah/hapus pemindahan ber-relasi | Ditolak / tanpa orphan | Sesuai | PASS | `damage-restoration.test.js` |
| TC-PB04-17 | Kapasitas total <= 3.000 | Terjaga | Terjaga | PASS | Fuzz `AQ-04` |
| TC-PB04-18 | Batch sebagai acuan turunan | Konsisten | Sesuai | PASS | `damage_flow_test.dart` |

### PB-05 Deteksi Hama (YOLO TFLite lokal) — **kini dibangun**

Model & aset: `ml/artifacts/yolo11n_lettuce_pests.tflite` (sha256 `cd388bda…b2ab3`,
5.409.324 byte) disalin ke `apps/mobile/assets/ml/` (byte-identik, diverifikasi tes).

| ID | Skenario | Hasil diharapkan | Hasil aktual | Status | Bukti |
|---|---|---|---|---|---|
| TC-PB05-01 | Ambil gambar kamera/galeri | Ada input gambar | `image_picker ^1.2.4`; izin ditolak → pesan jelas | PASS | `pest_scan_page_test.dart` ("akses kamera ditolak") |
| TC-PB05-02 | Inferensi TFLite lokal offline | Kelas+confidence, tanpa jaringan | `Interpreter.fromAsset('assets/ml/…')`, tidak ada request jaringan | PASS | `pest_detector.dart`; `pest_viewmodels_test.dart` ("tanpa menyentuh jaringan") |
| TC-PB05-03 | Hasil kosong ≠ "bebas hama" | Pesan netral | "Tidak ada hama terdeteksi / Ini bukan jaminan tanaman sehat…" | PASS | `pest_scan_page.dart:159`; `pest_scan_page_test.dart` ("nol deteksi") |
| TC-PB05-04 | Kinerja inferensi < 5 dtk (perangkat) | Terukur | Butuh perangkat; host 129,65 ms/gambar (bukan perangkat) | MANUAL-PENDING | `manual_checklist.md` MC-PERF-06 |
| TC-PB05-05 | UI tidak freeze / anti double-tap | Aman | Letterbox di `compute` (isolate); simpan-ganda diabaikan | PASS | `yolo_decoder.dart`; `pest_viewmodels_test.dart` |
| TC-PB05-06 | Unggah Cloudinary tak menghambat / gagal tak hilangkan hasil | Hasil lokal tetap | `uploadPhoto` setelah inferensi; gagal → `UPLOAD_FAILED`, hasil tetap | PASS | `pest_repository_test.dart` (Cloudinary gagal) |
| TC-PB05-07 | Pra-pemrosesan app == pelatihan | 640×640, RGB 0-1, pad 114, NMS 0.35/0.45 | Konstanta dekoder = `model_metadata.json`; golden paritas | PASS | `pest_decoder_test.dart`; `pest_summary_test.dart:79` |
| TC-PB05-08 | Banyak objek satu gambar | Ditangani (NMS) | Decoder mengembalikan banyak kotak + NMS | PASS | `pest_decoder_test.dart` |
| TC-PB05-09 | Gambar invalid/rusak | Tidak crash | "foto rusak: gagal saat analisis, tanpa tombol simpan ulang" | PASS | `pest_viewmodels_test.dart` |
| TC-PB05-10 | Deteksi tanpa memilih batch | Ditangani | "meja tanpa tanaman aktif: tidak ada yang dikirim, boleh ganti meja" | PASS | `pest_viewmodels_test.dart` |

> Catatan: model lokal **bukan jaminan**; hasil kosong sengaja tidak menyatakan
> "tanaman bebas hama" sesuai kriteria penerimaan PB-05.

### PB-06 Rekomendasi & Pencatatan Perawatan — **kini dibangun**

| ID | Skenario | Hasil diharapkan | Hasil aktual | Status | Bukti |
|---|---|---|---|---|---|
| TC-PB06-01 | Rekomendasi dari deteksi + riwayat, status "menunggu" | Terbentuk | `pindaian` + `rekomendasi_perawatan`; unik per (meja,hama) menunggu | PASS | `qa/backend-pest-rotation.sh` (SC/RC) |
| TC-PB06-02 | Rotasi golongan bahan aktif | Saran != MoA terblokir (jendela 2) | `ROT-PHT`/`ROT-MOA`/`ROT-FALLBACK`; 2 MoA terakhir diblokir | PASS | `rotation-engine.test.js`; pest suite `§C` |
| TC-PB06-03 | Terima/tolak tersimpan; alasan opsional; tak bisa ganda | Persisten, 409 bila dobel | Replay→`200 replayed:true`; konten beda→`409 RECOMMENDATION_ALREADY_DECIDED` | PASS | pest suite `§D`; `rotation.test.js` |
| TC-PB06-04 | Menerima != melakukan perawatan (SRS) | Terpisah | **Implementasi menyatukan**: `acceptRecommendation` membuat baris `perawatan` + potong stok | BLOCKED (deviasi desain) | `rotation/service.ts:125,131`; lihat `rtm.md` G-12 |
| TC-PB06-05 | Perawatan tanpa rekomendasi bisa dicatat | Bisa | `perawatan.id_rekomendasi NOT NULL`; hanya dibuat lewat terima | N/A (gap skema) | `0019` skema; `rtm.md` G-02 |
| TC-PB06-06 | Perawatan kurangi stok; tolak bila kurang; satu transaksi | 1 keluar | `recordMovement`; kurang→`409 INSUFFICIENT_STOCK`; satuan salah→`422 UNIT_MISMATCH` | PASS | pest suite `§D`/`§E` |
| TC-PB06-07 | Bila tak ada rekomendasi yang lolos | Pesan jelas | `409 NO_RECOMMENDATION` | PASS | pest suite `§E` |
| TC-PB06-08 | Rekomendasi tak auto-jalan | Tidak otomatis | Hanya berubah bila pengguna menekan aksi | PASS | `recommendation_decider.dart`; tes viewmodel |
| TC-PB06-09 | Riwayat perawatan dari tindakan aktual | Ada daftar | Halaman `rotation_history_page.dart` | PASS | pest history tests |

> Deviasi TC-PB06-04 (BLOCKED): aplikasi memperlakukan **"Terima" = sekaligus
> mencatat perawatan** (opsional membawa `bahan`, memotong stok). SRS memisahkan
> "keputusan" dan "tindakan aktual". Ini keputusan desain yang perlu disepakati tim
> (lihat `rtm.md` G-12), bukan bug fatal — perilaku konsisten & teruji.

### PB-07 Penyimpanan Lokal & Sinkronisasi

| ID | Skenario | Hasil diharapkan | Hasil aktual | Status | Bukti |
|---|---|---|---|---|---|
| TC-PB07-01 | Replay kunci+isi sama = idempoten | `replayed:true`, id sama | Sesuai | PASS | `ID-01/02/03` |
| TC-PB07-02 | Kunci sama isi beda | 409 | Sesuai | PASS | `ID-04` |
| TC-PB07-03 | Replay penjualan tak duplikasi | Tak menambah baris | Sesuai | PASS | `SL-06` |
| TC-PB07-04 | Update pakai expected_version | Konflik versi ditolak | Sesuai | PASS | `sync-contract.test.js` |
| TC-PB07-05 | Urutan dependensi (induk dulu) | Aman | Sesuai | PASS | `sync-changes.test.js`; fuzz rantai |
| TC-PB07-06 | Tak ada ID ganda setelah sync berulang | Tidak ada | Sesuai | PASS | Fuzz idempotensi |
| TC-PB07-07 | Kirim ulang menambah tepat 1 baris | Tepat 1 | Sesuai | PASS | Fuzz akhir |
| TC-PB07-08 | Gagal sync tak hapus data lokal | Data tetap | Sesuai | PASS | `write_outcome_test.dart` |
| TC-PB07-09 | Ditandai "belum tersinkron" | Tanda ada | Sesuai | PASS | `penjualan_retry_key_test.dart` |
| TC-PB07-10 | UUID klien mencegah bentrok | Unik | Sesuai | PASS | `sync-uuid-boundaries.test.js` |
| TC-PB07-11 | Server 500/timeout/429 | Ditangani, tak hapus | Sesuai | PASS | `v2_error_message_test.dart` |
| TC-PB07-12 | Konflik multi-perangkat | Aturan terdokumentasi | Version/expected_version (LWW) | PASS | `sync-contract.test.js`; lihat G-13 |
| TC-PB07-13 | Payload besar | Terkirim | Paginasi sync-changes | PASS | `sync-changes.test.js` |
| TC-PB07-14 | Koneksi putus-nyambung | Aman, tak ganda | Sesuai | PASS | `ID-01..04` |
| TC-PB07-15 | Kill di tengah sync / baterai habis | Data tak hilang | Butuh perangkat | MANUAL-PENDING | `manual_checklist.md` MC-SYNC-01 |
| TC-PB07-16 | Dua perangkat keluar stok melebihi saldo | Konsisten | Backend aman (lihat pest/concurrency); dua device | MANUAL-PENDING | `manual_checklist.md` MC-SYNC-03 |
| TC-PB07-17 | Migrasi skema tak hilang data | Aman | Butuh device upgrade | MANUAL-PENDING | `manual_checklist.md` MC-SYNC-05 |
| TC-PB07-18 | Kesamaan data lokal vs pusat | Cocok (checksum) | Butuh device | MANUAL-PENDING | `manual_checklist.md` MC-E2E-01 |
| TC-PB07-19 | Waktu sync < 1 menit | < 60 dtk | Butuh perangkat/jaringan | MANUAL-PENDING | `manual_checklist.md` MC-PERF-03 |

### PB-08 Pencatatan Panen

| ID | Skenario | Hasil diharapkan | Hasil aktual | Status | Bukti |
|---|---|---|---|---|---|
| TC-PB08-01 | Panen > tanaman aktif | 409 | Sesuai | PASS | `HV-01` |
| TC-PB08-02 | Berat negatif | 400 | Sesuai | PASS | `HV-02` |
| TC-PB08-03 | Tanggal panen masa depan | 400 | Sesuai | PASS | `HV-03` |
| TC-PB08-04 | Panen valid | 201 | Sesuai | PASS | `HV-04`, E2E `E2E-17` |
| TC-PB08-05 | Berat layak = total - reject | Tepat | Sesuai: `berat_minor` menyimpan **layak** | PASS | `harvest/service.ts:27-28`; repro AQ-10 §4.7 |
| TC-PB08-06 | Panen tepat semua tanaman aktif | 201 | Sesuai | PASS | `BND-08` |
| TC-PB08-07 | Panen 1 lagi setelah habis | 409 | Sesuai | PASS | `BND-09` |
| TC-PB08-08 | Panen sebagian berkali-kali | Boleh | Sesuai | PASS | `harvest.test.js` |
| TC-PB08-09 | Berat terpisah dari harga jual | Terpisah | Sesuai | PASS | E2E `E2E-18/21` |
| TC-PB08-10 | Ubah panen setelah ada penjualan | Terjual <= layak | Sesuai | PASS | `sales-rework.test.js`; fuzz `AQ-10` |
| TC-PB08-11 | Tanaman aktif & kapasitas diperbarui | Tepat | Sesuai | PASS | E2E `E2E-20/26` |

### PB-09 Pencatatan Penjualan

| ID | Skenario | Hasil diharapkan | Hasil aktual | Status | Bukti |
|---|---|---|---|---|---|
| TC-PB09-01 | Jual > berat layak | 409 | Sesuai | PASS | `SL-01`; repro: jual 2,51 saat layak 2,50 → 409 |
| TC-PB09-02 | Berat 0 | 400 | Sesuai | PASS | `SL-02` |
| TC-PB09-03 | Tanggal sebelum panen | 400 | Sesuai | PASS | `SL-03` |
| TC-PB09-04 | Jual valid | 201 | Sesuai | PASS | `SL-04` |
| TC-PB09-05 | Total = kg × harga (presisi) | Tepat | Sesuai | PASS | `SL-05`; E2E `E2E-22` |
| TC-PB09-06 | Jual tepat berat layak | 201 | Sesuai | PASS | `BND-10`; repro jual 2,50 → 201 |
| TC-PB09-07 | Jual 0,01 melebihi layak | 409 | Sesuai | PASS | `BND-11` |
| TC-PB09-08 | Terjual kumulatif <= layak | Selalu | Sesuai | PASS | Fuzz `AQ-10` (kueri diperbaiki, §4.7) |
| TC-PB09-09 | Format `Rp 1.234.567` | Benar | Benar | PASS | `v2_format_desimal_test.dart` |
| TC-PB09-10 | Tolak berat/harga kosong/non-angka | Ditolak | Sesuai | PASS | `sales.test.js` |
| TC-PB09-11 | Pegawai tak bisa akses penjualan | 403 | Sesuai | PASS | `AZ-01/02` |
| TC-PB09-12 | Sisa hasil panen akurat | Benar | Benar | PASS | `v2_penjualan_load_failure_test.dart` |

### PB-10 Rekomendasi Cuaca (BMKG)

| ID | Skenario | Hasil diharapkan | Hasil aktual | Status | Bukti |
|---|---|---|---|---|---|
| TC-PB10-01 | Ambil data lokasi mitra (Ambulu) | adm4 benar | `BMKG_ADM4=35.09.12.2002` | PASS | `bmkg_weather_service.dart` |
| TC-PB10-02 | Parse payload BMKG nyata | suhu/RH/hujan terbaca | Terbaca | PASS | Live fetch + tes service |
| TC-PB10-03 | Cocokkan rentang suhu (batas) | Aturan tepat di batas | Sesuai | PASS | `weather_rules_test.dart` |
| TC-PB10-04 | Beberapa aturan cocok sekaligus | Tertangani | Sesuai | PASS | `weather_rules_test.dart` |
| TC-PB10-05 | Tidak ada aturan cocok | Pesan netral | Sesuai | PASS | `weather_rules_test.dart` |
| TC-PB10-06 | Curah hujan null/hilang | Tidak crash | Sesuai | PASS | `bmkg_weather_service_test.dart` |
| TC-PB10-07 | Tipe data salah | Tidak crash | Sesuai | PASS | `bmkg_weather_service_test.dart` |
| TC-PB10-08 | Array kosong / JSON rusak | "tidak tersedia" | Sesuai | PASS | `weather_test.dart` |
| TC-PB10-09 | HTTP 4xx/5xx/timeout/DNS | Tidak crash, tak ganggu | Sesuai | PASS | `weather_test.dart` |
| TC-PB10-10 | Tidak simpan riwayat cuaca | Tak ada tabel log | `penanganan_cuaca` = aturan (bukan riwayat) | PASS | `.schema penanganan_cuaca` |
| TC-PB10-11 | Waktu pencocokan < 2 dtk | Cepat | client-side, instan | PASS | `weather_rules_test.dart` |
| TC-PB10-12 | Tidak tampilkan data basi | Ada indikator waktu | Sesuai | PASS | `weather_test.dart` |
| TC-PB10-13 | Aturan cuaca tersimpan di server | Ada baris aturan | `penanganan_cuaca` **0 baris** | BLOCKED | tak ada seed aturan |
| TC-PB10-14 | Rekomendasi cuaca dari server | Endpoint ada | Tak ada `features/weather` | BLOCKED | `apps/backend/API.md` |

### PB-11 Pengelolaan Data Akun

| ID | Skenario | Hasil diharapkan | Hasil aktual | Status | Bukti |
|---|---|---|---|---|---|
| TC-PB11-01 | Petani buat akun pegawai | 201 | Sesuai | PASS | `AC-01` |
| TC-PB11-02 | Username duplikat beda kasus | 409 | Sesuai | PASS | `AC-02` |
| TC-PB11-03 | Password < 12 karakter | 400 | Sesuai | PASS | `AC-03` |
| TC-PB11-04 | Format email salah | 400 | Sesuai | PASS | `AC-04` |
| TC-PB11-05 | Nomor telepon tanpa angka | 400 | Sesuai | PASS | `AC-05` |
| TC-PB11-06 | Pegawai baru bisa login | 200 | Sesuai | PASS | `AC-07` |
| TC-PB11-07 | Nonaktifkan akun | 204 | Sesuai | PASS | `AC-08` |
| TC-PB11-08 | Akun nonaktif login (password benar) | 403 | Sesuai | PASS | `AC-09` |
| TC-PB11-09 | Akun nonaktif login (password salah) | 401 | Sesuai | PASS | `AC-10` |
| TC-PB11-10 | Sesi lama akun nonaktif ditolak | 401 | Sesuai | PASS | `AC-11` |
| TC-PB11-11 | Data akun nonaktif tetap ada | 200 | Sesuai | PASS | `AC-12` |
| TC-PB11-12 | Pegawai tak bisa kelola pegawai/naikkan role | 403 | Sesuai | PASS | `AZ-03/05` |
| TC-PB11-13 | Petani tak bisa nonaktifkan diri → nol petani | Dicegah | Tak ada endpoint nonaktifkan petani → skenario tak mungkin | PASS | dinilai; lihat `rtm.md` G-08 |

### §5 Lintas-Area

| ID | Skenario | Hasil diharapkan | Hasil aktual | Status | Bukti |
|---|---|---|---|---|---|
| TC-5.1-01 | E2E online penuh (inventaris→semai→pindah→rusak→panen→jual) | Angka rekonsiliasi | 28/28 langkah konsisten | PASS | `qa/backend-e2e.sh` |
| TC-5.1-02 | E2E offline penuh lalu sync | Terkirim, angka sama | Butuh perangkat | MANUAL-PENDING | MC-E2E-01 |
| TC-5.1-03 | E2E campuran (putus di tengah) | Tak hilang/ganda | Butuh perangkat | MANUAL-PENDING | MC-E2E-02 |
| TC-5.1-04 | E2E pest: unggah→pindai→rekomendasi→terima→stok turun | Rekonsiliasi | §A-E pest suite konsisten (saldo 10→8) | PASS | `qa/backend-pest-rotation.sh` |
| TC-5.2-01 | Skema vs ERD (nama tabel/kolom) | Cocok | Selisih dicatat | PASS | `rtm.md` §Gap |
| TC-5.2-02 | Foreign key aktif & tak ada orphan | `foreign_key_check` kosong | 0 baris | PASS | `PRAGMA foreign_key_check` |
| TC-5.2-03 | Constraint NOT NULL/UNIQUE/CHECK ada di DB | Ada | Semua tabel ber-CHECK | PASS | `sqlite_master` |
| TC-5.2-04 | Confidence 0-1 dibatasi DB | CHECK rentang | `deteksi_hama.confidence_maks BETWEEN 0 AND 1` (migrasi 0019) | PASS | `.schema deteksi_hama` |
| TC-5.2-05 | Query audit dijalankan ulang | 0 baris | AQ-01..AQ-28 = 0 baris | PASS | `qa/audit_queries.sql` |
| TC-5.2-06 | Negative control (deteksi pelanggaran) | Terdeteksi | Semua AQ mendeteksi saat disuntik | PASS | §4.7 |
| TC-5.3-01 | Autentikasi di rute non-publik | 401 tanpa token | Sesuai | PASS | `AU-13/14` |
| TC-5.3-02 | Otorisasi per role | 403 bila salah role | Sesuai | PASS | `AZ-01..05`, pest suite |
| TC-5.3-03 | Validasi server-side | Ditolak | Sesuai | PASS | `ST-*`, `AU-12` |
| TC-5.3-04 | SQL injection (parameterized) | Gagal aman | Sesuai | PASS | `AU-10/11` |
| TC-5.3-05 | Header keamanan | CSP/HSTS/nosniff/XFO | Ada | PASS | §4.6 |
| TC-5.3-06 | Rate limit | 429 saat lampaui | Sesuai | PASS | §4.6 |
| TC-5.3-07 | IDOR | Ditolak | Otorisasi per record | PASS | `http-boundaries.test.js` |
| TC-5.3-08 | Secret tak ter-hardcode | Tak ada | Tak ada | PASS | scan repo (§4.6) |
| TC-5.3-09 | Data sensitif tak di log | Tidak ada | Password/hash tak dicetak | PASS | review + `LOG_LEVEL` |
| TC-5.3-10 | Penyimpanan lokal token | Secure storage | **Token plaintext** di `session.db` | FAIL (temuan) | `issues.md` BUG-05 |
| TC-5.3-11 | Dependensi rentan | 0 advisory runtime | 3 advisory (1 low/1 mod/1 high) | FAIL (temuan) | `issues.md` BUG-04 |
| TC-5.4-01 | Rotasi/layar kecil/font besar | Tak rusak | Butuh perangkat | MANUAL-PENDING | `manual_checklist.md` §A |
| TC-5.4-02 | Build release tak rusak | Aman | Butuh perangkat | MANUAL-PENDING | MC-DEV-11 |
| TC-5.5-01 | Evaluasi model AI | mAP per kelas dll | mAP50 0,8913; TFLite drop 0,0017; leakage 0 | PASS | `qa/model_evaluation.md` |
| TC-5.5-02 | Pra-pemrosesan app == pelatihan | Identik | Golden paritas dekoder | PASS | `pest_decoder_test.dart` |
| TC-5.6-01 | Heuristic usability statis | Temuan masuk akal | Dilakukan | PASS | §5.6 (di bawah) |
| TC-5.6-02 | Usability bersama mitra | Lembar observasi | Butuh mitra | MANUAL-PENDING | `manual_checklist.md` §G |
| TC-5.7-01 | Latensi API backend | Cepat & stabil | avg ~2 ms; p95 ~2,5 ms (loopback) | PASS | `qa/perf.sh` |
| TC-5.7-02 | Muat halaman utama < 3 dtk | Terukur | Butuh perangkat | MANUAL-PENDING | MC-PERF-* |
| TC-5.7-03 | Data besar tetap lancar | Tak lambat | Paginasi ≤ 100, indeks ada | PASS | `inventory-pagination.test.js`, `perf.sh` |
| TC-5.8-01 | Invarian §5.8 (semua) | 0 pelanggaran | 638 pemeriksaan × 3 run lulus | PASS | `apps/backend/qa/fuzz-invariants.mjs` |
| TC-5.8-02 | Uji balapan stok (2 request bersamaan) | Salah satu/keduanya aman, tak negatif | 22/22 | PASS | `qa/backend-concurrency.sh` |
| TC-5.9-01 | RTM dokumen vs implementasi | Lengkap | `qa/rtm.md` | PASS | `qa/rtm.md` |

---

## 4. Bukti mentah (ringkas)

### 4.1 Baseline `npm test` (backend) — 432 tes
```
i tests 432
i pass 432
i fail 0
backend npm test exit=0
```

### 4.2 `flutter test` (mobile) — 584 tes
```
01:20 +584: All tests passed!
flutter test exit=0
```
`flutter analyze`: 2 warning aset (`assets/illustrations/inventory/`,
`assets/illustrations/features/` tidak ada).

### 4.3 Backend adversarial
```
qa/backend-api-smoke.sh    TOTAL=73  PASS=73  FAIL=0
qa/backend-boundaries.sh   TOTAL=11  PASS=11  FAIL=0
qa/backend-e2e.sh          TOTAL=28  PASS=28  FAIL=0
qa/backend-concurrency.sh  TOTAL=22  PASS=22  FAIL=0
qa/backend-pest-rotation.sh TOTAL=109 PASS=109 FAIL=0 SKIP=0
```
`qa/backend-pest-rotation.sh` menutup: (A) unggahan tanda tangan `UP-*`;
(B) pindaian foto `SC-*`; (C) mesin rotasi `RC-*`/`ROT-*`/`MO-*`;
(D) terima/tolak + potong stok `DC-*`; (E) tepi & balapan `E-*`/`PQ-*`.

### 4.4 Fuzz invarian §5.8
```
[stok] ops=400 diterima=310 ditolak=59 replay=31 saldo_akhir=564
[rantai] {"sowing":40,"transfer":40,"damage":39,"harvest":39,"sale":39,"rejected":0}
[ok] 638 pemeriksaan invarian lulus, 242 request, tanpa pelanggaran.
```
(3 run berturut-turut hijau. Lihat §4.7 untuk perbaikan kueri AQ-10.)

### 4.5 Kinerja API — `REPS=12 bash qa/perf.sh`
```
endpoint             avg_ms   p50_ms   p95_ms   max_ms   http
meja.list               2.0      2.0      2.2      2.4    200
inventaris.list         2.1      1.9      2.5      3.1    200
penyemaian.list         1.8      1.8      2.0      2.1    200
panen.list              2.0      1.9      2.1      2.4    200
penjualan.list          1.9      1.9      2.0      2.7    200
sync.changes            2.4      2.3      2.9      3.4    200
```
Kondisi: loopback, SQLite lokal, single-client → **bukan** pengganti pengukuran perangkat.

### 4.6 Keamanan
- **Password di DB:** `scrypt$...` (hash), bukan plaintext.
- **Header keamanan:** CSP, HSTS, nosniff, X-Frame-Options, Referrer-Policy, `no-store`.
- **Rate limit global:** permintaan ke-47 dalam uji cepat → `429`.
- **Scan secret repo:** tidak ada API key hardcoded (hanya `.env.example`).
- **Advisory dependensi:** `npm audit --omit=dev` → 3 (1 low, 1 mod, 1 high) → BUG-04.

### 4.7 Integritas data — `qa/audit_queries.sql`
Semua **AQ-01..AQ-28** mengembalikan 0 baris pada DB uji. Kontrol negatif: AQ-01/02/05
dan AQ-16..AQ-28 mendeteksi pelanggaran yang disuntikkan (SQLite terpisah dengan
skema tanpa CHECK/FK).

**Temuan QA-tooling (BUG-11, sudah diperbaiki):** kueri asli **AQ-10**
(`SUM(berat_minor - berat_reject_minor)`) salah memodelkan skema. Kolom
`detail_panen.berat_minor` **sudah** menyimpan **berat layak** (total − reject);
reject tersimpan terpisah di `berat_reject_minor` (`harvest/service.ts:27-28`).
Menurangi reject lagi membuat "layak" jadi terlalu kecil → laporan palsu
"terjual > layak". Bukti repro (`/tmp/opencode/hsqa/repro-aq10.mjs`):
```
RAW detail_panen: berat=2.5, berat_minor=250, reject_minor=50
jual 2,50 -> 201 ; jual 2,51 -> 409 SALE_EXCEEDS_HARVEST_STOCK
AQ-10 WRONG (berat_minor-reject): [{"id_panen":1}]   <- laporan palsu
AQ-10 FIXED (berat_minor as layak): []               <- benar
```
Kueri AQ-10 (dan AQ-09) diperbaiki di `qa/audit_queries.sql` **dan**
`apps/backend/qa/fuzz-invariants.mjs`. Produk **tidak** berubah.

### 4.8 AI / ML — `python3 -m pytest ml/tests -q`
```
3 failed, 165 passed in 34.38s
```
3 kegagalan = **cacat harness uji ML**, bukan model (detail di `qa/issues.md` BUG-12):
1. `test_f5_t1_committed_branch_diff_strictly_inside_ml` — mengasumsikan diff
   `main..HEAD` hanya menyentuh `ml/`; pada branch `wild-fe` diff memuat seluruh
   produk (922 path non-`ml/`). Asumsi branch ML terpisah.
2. `test_f5_t1_commit_history_main_to_head_clean_of_secrets_and_non_ml_paths` — asumsi sama.
3. `test_f2_t2_push_kaggle_kernel_propagates_missing_cli_and_failure` —
   `PermissionError: [Errno 13]` saat `os.posix_spawn` menjalankan `fake_kaggle.cmd`
   di Linux (file `.cmd` tidak executable). Asumsi platform Windows.

Evaluasi model nyata (bukan pytest) ada di `qa/model_evaluation.md`.

---

## 5. Catatan interpretasi & keterbatasan

- **A-01 (pegawai & panen):** implementasi memberi pegawai `panen:read/write` tetapi
  **tidak** penjualan/deteksi/rekomendasi/perawatan/cuaca/akun (diverifikasi 403).
- **A-02 (HSS):** `estimasi_panen = tanggal_pindah + 45 hari`; `hss` = hari sejak semai.
- **A-03 (berat panen):** `detail_panen.berat_minor` = **berat layak**; `berat` juga layak.
  Kueri audit harus memakai `berat_minor` langsung (lihat §4.7).
- **A-04 (terima = perawatan):** `acceptRecommendation` menyatukan keputusan & tindakan
  (membuat `perawatan` + potong stok). Deviasi SRS → G-12.
- Uji perangkat fisik (kamera, notifikasi, kinerja nyata, dua perangkat) semuanya
  `MANUAL-PENDING`; **tidak** diklaim lulus.
- Angka kinerja backend diukur di loopback; tidak mewakili jaringan seluler mitra.
- Fuzz default `FUZZ_STOCK_OPS=400 FUZZ_CYCLES=40` divalidasi. Run lebih besar
  (>15 menit jam simulasi) **gagal 401** karena token akses tak diperbarui di dalam
  loop stok — batasan harness, bukan produk (perbaikan: panggil `renew()` berkala).

### 5.6 Heuristic usability (statis) — temuan
- Target sentuh & kontras: komponen v2 memakai token `V2Space`/warna kontras tinggi;
  verifikasi nyata di perangkat `MANUAL-PENDING`.
- Pesan kosong deteksi bersifat netral & menindaklanjuti ("foto ulang"),
  sesuai PB-05.
- Istilah HSS/batch/meja konsisten di layar petani.
- Konfirmasi aksi destruktif (nonaktifkan) ada.
- Usability test bersama mitra: `MANUAL-PENDING` (lembar di `manual_checklist.md` §G).
