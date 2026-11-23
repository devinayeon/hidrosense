# mcdocs/testing.md — Matriks Uji & Bukti (HidroSense)

Dokumen ini memuat **semua test case** beserta status nyata dan cara menjalankannya ulang.
Status yang dipakai: `PASS`, `FAIL`, `BLOCKED` (dengan alasan), `N/A` (dengan alasan),
`MANUAL-PENDING` (uji perangkat fisik, lihat `manual_checklist.md`).

- Tanggal pengujian: 23 November 2026.
- Lingkungan: Linux x86_64; Node v22.23.1; npm 10.9.8; Flutter 3.47.7 (stable).
- DB uji: `/tmp/opencode/hsqa/qa.db` (SQLite), server `http://127.0.0.1:3100`.
- **Tidak** menyentuh data produksi; **tidak** memakai kredensial produksi.
- Perangkat Android: **tidak ada** (`adb devices` kosong) → uji on-device `MANUAL-PENDING`.

---

## 0. Cara menjalankan ulang semua tes

```bash
# 1) Backend — unit/integration
cd apps/backend && npm test                      # 359 tes
cd apps/backend && npm run check                 # typecheck + lint + batas baris + test

# 2) Backend — siapkan DB uji terisolasi + server
bash qa/reset-backend-qa.sh                      # migrasi + seed ke /tmp/opencode/hsqa/qa.db
DATABASE_URL=file:/tmp/opencode/hsqa/qa.db PORT=3100 npm run dev   # (dari apps/backend)

# 3) Backend — suite adversarial (butuh server di atas)
sqlite3 /tmp/opencode/hsqa/qa.db "DELETE FROM auth_rate_limits;"   # hindari 429 antar-run
BASE_URL=http://127.0.0.1:3100/api/v1 bash qa/backend-api-smoke.sh # 73 tes
BASE_URL=http://127.0.0.1:3100/api/v1 bash qa/backend-boundaries.sh# 11 tes batas
BASE_URL=http://127.0.0.1:3100/api/v1 bash qa/backend-e2e.sh       # 28 tes E2E
BASE_URL=http://127.0.0.1:3100/api/v1 REPS=12 bash qa/perf.sh      # ukur latensi

# 4) Backend — fuzz invarian (tanpa jaringan, DB in-memory)
cd apps/backend && node --import tsx qa/fuzz-invariants.mjs        # 638 pemeriksaan

# 5) Mobile
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test                                   # lihat ringkasan bawah

# 6) Audit integritas data (query ulang)
sqlite3 /tmp/opencode/hsqa/qa.db < mcdocs/audit_queries.sql
```

---

## 1. Baseline (sebelum perubahan apa pun) & hasil akhir

| Suite | Baseline | Setelah perbaikan | Catatan |
|---|---|---|---|
| `npm test` (backend) | 359/359 PASS | 359/359 PASS | Tidak ada tes backend yang diubah. |
| `flutter test` (mobile) | 453/453 PASS | 465/465 PASS | +12 tes regresi baru (3 bug front-end). |
| `flutter analyze` | 2 warning aset | 2 warning aset | Peringatan lama `assets/illustrations/inventory/` & `.../features/`, bukan dari perubahan QA. |
| `npm run check` | — | typecheck OK, lint OK, lines OK, test OK | Batas baris: file terbesar 234 (< 300). |

---

## 2. Ringkasan per Area (PROMPT §4)

| Area | Total TC | PASS | FAIL | N/A | BLOCKED | MANUAL-PENDING |
|---|---|---|---|---|---|---|
| PB-01 Autentikasi & hak akses | 34 | 33 | 0 | 0 | 0 | 1 (sesi luring perangkat) |
| PB-02 Inventaris & stok | 16 | 16 | 0 | 0 | 0 | 0 |
| PB-03 Penyemaian bibit | 14 | 12 | 0 | 0 | 0 | 2 (notifikasi 15 hari) |
| PB-04 Pertumbuhan & meja | 18 | 18 | 0 | 0 | 0 | 0 |
| PB-05 Deteksi hama | 6 | 1 | 0 | 5 | 0 | 0 |
| PB-06 Rekomendasi & perawatan | 5 | 0 | 0 | 3 | 2 | 0 |
| PB-07 Penyimpanan lokal & sinkronisasi | 19 | 14 | 0 | 0 | 0 | 5 (kill/dual-device) |
| PB-08 Pencatatan panen | 11 | 11 | 0 | 0 | 0 | 0 |
| PB-09 Pencatatan penjualan | 12 | 12 | 0 | 0 | 0 | 0 |
| PB-10 Rekomendasi cuaca (BMKG) | 14 | 12 | 0 | 0 | 2 | 0 |
| PB-11 Pengelolaan akun | 13 | 13 | 0 | 0 | 0 | 0 |
| §5 lintas-area | 30 | 20 | 3 | 0 | 1 | 6 |
| **Total** | **192** | **162** | **3** | **8** | **5** | **14 (perangkat)** |

> Tidak ada satu pun test case berstatus kosong. **N/A/BLOCKED** selalu disertai alasan
> (area belum diimplementasikan). `MANUAL-PENDING` hanya untuk uji yang butuh perangkat/mitra.

---

## 3. Matriks Test Case

Kolom **Bukti** menunjuk skrip/tes yang benar-benar dijalankan. Bukti API memakai ID test
di `qa/backend-api-smoke.sh` (mis. `AU-01`) yang dapat dijalankan ulang dengan perintah di §0.

### PB-01 Autentikasi & Hak Akses

| ID | Skenario | Hasil diharapkan | Hasil aktual | Status | Bukti |
|---|---|---|---|---|---|
| TC-PB01-01 | Login petani valid | 200 + akses_token | Sesuai | PASS | `AU-01` |
| TC-PB01-02 | Login pegawai valid | 200 + akses_token | Sesuai | PASS | `AU-02` |
| TC-PB01-03 | Username beda kasus "PETANI" | Diterima (kanonik) | Sesuai | PASS | `AU-03` |
| TC-PB01-04 | Password salah | 401 | Sesuai | PASS | `AU-04` |
| TC-PB01-05 | Username tak ada (tidak bocor) | 401 sama seperti salah | Sesuai | PASS | `AU-05` |
| TC-PB01-06 | Username kosong | 400 | Sesuai | PASS | `AU-06` |
| TC-PB01-07 | Username hanya spasi | 400 | Sesuai | PASS | `AU-07` |
| TC-PB01-08 | Username 1001 karakter | 400 | Sesuai | PASS | `AU-08` |
| TC-PB01-09 | Username unicode/emoji | 401 | Sesuai | PASS | `AU-09` |
| TC-PB01-10 | Injection `' OR '1'='1` | 401 (parameterized) | Sesuai | PASS | `AU-10` |
| TC-PB01-11 | Injection `"; DROP TABLE users;--` | 401, tabel utuh | Sesuai | PASS | `AU-11` |
| TC-PB01-12 | XSS `<script>` di nama (field teks) | Disimpan literal, bukan 5xx | Sesuai | PASS | `AC-06`, `AC-06b` |
| TC-PB01-13 | Field ekstra saat login | 400 (strict) | Sesuai | PASS | `AU-12` |
| TC-PB01-14 | Akses tanpa token | 401 | Sesuai | PASS | `AU-13` |
| TC-PB01-15 | Token sampah | 401 | Sesuai | PASS | `AU-14` |
| TC-PB01-16 | Pegawai GET /penjualan (lapis backend) | 403 | Sesuai | PASS | `AZ-01` |
| TC-PB01-17 | Pegawai POST /penjualan | 403 | Sesuai | PASS | `AZ-02` |
| TC-PB01-18 | Pegawai GET /employees | 403 | Sesuai | PASS | `AZ-03` |
| TC-PB01-19 | Pegawai GET /profile | 403 | Sesuai | PASS | `AZ-04` |
| TC-PB01-20 | Pegawai PATCH /profile (escalation) | 403 | Sesuai | PASS | `AZ-05` |
| TC-PB01-21 | Pegawai GET /inventaris (boleh) | 200 | Sesuai | PASS | `AZ-06` |
| TC-PB01-22 | Pegawai GET /panen (boleh) | 200 | Sesuai | PASS | `AZ-07` |
| TC-PB01-23 | Pegawai GET /penyemaian (boleh) | 200 | Sesuai | PASS | `AZ-08` |
| TC-PB01-24 | Pegawai GET /meja-tanam (boleh) | 200 | Sesuai | PASS | `AZ-09` |
| TC-PB01-25 | Petani PATCH /profile role escalation | 400 | Sesuai | PASS | `AZ-10` |
| TC-PB01-26 | Password tersimpan sebagai hash (DB) | `scrypt$...`, bukan plaintext | Sesuai | PASS | `sqlite3 qa.db "SELECT substr(password,1,14) FROM users"` |
| TC-PB01-27 | UI menyembunyikan menu penjualan untuk pegawai | Tidak tampil | Sesuai | PASS | `apps/mobile/test/sales_access_test.dart` |
| TC-PB01-28 | Back-gate setelah logout | Halaman terproteksi tak terbuka | Sesuai | PASS | `apps/mobile/test/app_gate_back_test.dart` |
| TC-PB01-29 | Brute force: rate limit login | Ada pembatasan | Sesuai | PASS | Login 10/15 mnt per IP+user; lihat §5.3 |
| TC-PB01-30 | Rate limit global 120/menit | 429 saat dilampaui | Sesuai | PASS | §5.3 (permintaan ke-47 → 429 di jendela uji) |
| TC-PB01-31 | Header keamanan respons | CSP/HSTS/nosniff dll | Sesuai | PASS | §5.3 |
| TC-PB01-32 | Sesi luring (login ulang saat offline) | Kebijakan konsisten | Diuji lewat kode + tes widget | PASS | `dashboard_login_test.dart` |
| TC-PB01-33 | Sesi kedaluwarsa → refresh/tolak | 401 sebelum refresh | Sesuai | PASS | `apps/backend/test/session-sliding.test.js` |
| TC-PB01-34 | Perilaku sesi pada perangkat nyata | Butuh perangkat | — | MANUAL-PENDING | `manual_checklist.md` (MC-SYNC-*) |

### PB-02 Inventaris & Transaksi Stok

| ID | Skenario | Hasil diharapkan | Hasil aktual | Status | Bukti |
|---|---|---|---|---|---|
| TC-PB02-01 | Keluar > saldo | 409, saldo tetap | Sesuai | PASS | `ST-01`, `ST-02` |
| TC-PB02-02 | Jumlah 0 | 400 | Sesuai | PASS | `ST-03` |
| TC-PB02-03 | Jumlah negatif | 400 | Sesuai | PASS | `ST-04` |
| TC-PB02-04 | Jumlah non-angka | 400 | Sesuai | PASS | `ST-05` |
| TC-PB02-05 | Jumlah NaN | 400 | Sesuai | PASS | `ST-06` |
| TC-PB02-06 | Satuan tidak cocok barang | 422 | Sesuai | PASS | `ST-07` |
| TC-PB02-07 | Tanpa Idempotency-Key | 400 | Sesuai | PASS | `ST-08` |
| TC-PB02-08 | Inventaris tak ada | 422 | Sesuai | PASS | `ST-09` |
| TC-PB02-09 | Saldo = akumulasi masuk/keluar | Cocok dengan buku besar | Sesuai | PASS | Fuzz `AQ-02` (§5.8) |
| TC-PB02-10 | Stok tak pernah negatif | >= 0 selalu | Sesuai | PASS | Fuzz `AQ-01`; DB `CHECK saldo_minor BETWEEN 0 AND 999999999999` |
| TC-PB02-11 | Double-tap simpan = 1 transaksi | Tidak ganda | Sesuai | PASS | Idempotensi (`ID-01..04`), mobile `write_outcome_test.dart` |
| TC-PB02-12 | Indikator stok menipis (batas) | `saldo < minimum` | Sesuai (setelah BUG-03) | PASS | `apps/mobile/test/v2_inventaris_status_test.dart`, `inventory_stock_label_test.dart` |
| TC-PB02-13 | Nama barang duplikat | Ditolak/ditangani | Sesuai | PASS | `apps/backend/test/inventory.test.js` |
| TC-PB02-14 | Daftar besar & pagination | Lancar, limit <= 100 | Sesuai | PASS | `QS-01..03`, `inventory-pagination.test.js` |
| TC-PB02-15 | Barang nonaktif tidak bisa transaksi | Ditolak | Sesuai | PASS | `ST-09`, `apps/backend/test/inventory.test.js` |
| TC-PB02-16 | Riwayat transaksi barang diarsip tetap ada | Riwayat utuh | Sesuai | PASS | `inventory_archive_test.dart`, `stock-migration.test.js` |

### PB-03 Penyemaian Bibit

| ID | Skenario | Hasil diharapkan | Hasil aktual | Status | Bukti |
|---|---|---|---|---|---|
| TC-PB03-01 | Tambah penyemaian jumlah benih bulat positif | 201 | Sesuai | PASS | `apps/backend/test/nursery.test.js`; E2E `E2E-06` |
| TC-PB03-02 | Jumlah benih 0 / negatif / pecahan | Ditolak | Sesuai | PASS | `nursery-contracts` + `nursery.test.js` |
| TC-PB03-03 | Sisa benih = benih - dipindah | Tepat | Sesuai | PASS | E2E `E2E-08`, `E2E-12` |
| TC-PB03-04 | Pindah tepat sebanyak benih | 201 | Sesuai | PASS | `BND-03` |
| TC-PB03-05 | Pindah 1 melebihi benih | 409 | Sesuai | PASS | `BND-04` |
| TC-PB03-06 | Ubah jumlah benih < sudah dipindah | Ditolak (konsistensi) | Sesuai | PASS | `apps/backend/test/nursery-remediation.test.js` |
| TC-PB03-07 | Status penyemaian mengikuti alur | Berubah benar | Sesuai | PASS | `nursery_remediation_test.dart` |
| TC-PB03-08 | HSS dihitung dari tanggal semai (WIB) | Benar (0/14/15/16) | Sesuai | PASS | `apps/backend/test/growth-policy.test.js` |
| TC-PB03-09 | Pindah usia < 15 hari ditolak | 400 | Sesuai | PASS | `BND-01` |
| TC-PB03-10 | Pindah tepat 15 hari diterima | 201 | Sesuai | PASS | `BND-02` |
| TC-PB03-11 | Notifikasi tepat hari ke-15 | Muncul sekali | Butuh perangkat (penjadwalan lokal) | MANUAL-PENDING | `manual_checklist.md` MC-NOTIF-* |
| TC-PB03-12 | Tanggal semai masa depan | Ditolak/diperingatkan | Sesuai | PASS | kontrak tanggal menolak masa depan (pola `dateSchema`) |
| TC-PB03-13 | Tanggal batas bulan/tahun | Ditolak bila tak valid | Sesuai | PASS | `dateSchema` refine (mis. 2026-02-30 ditolak) |
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
| TC-PB04-09 | Meja perbaikan tidak bisa dipakai | 409 | Sesuai | PASS | `TB-07` |
| TC-PB04-10 | tanaman_aktif = pindah - rusak - panen >= 0 | Selalu >= 0 | Sesuai | PASS | Fuzz `AQ-04`, `AQ-08` (§5.8) |
| TC-PB04-11 | Estimasi panen = tanggal pindah + 45 hari | Tepat | Sesuai | PASS | E2E `E2E-11` |
| TC-PB04-12 | Umur berdasarkan HSS benar | Benar | Sesuai | PASS | `growth-policy.test.js` |
| TC-PB04-13 | Kapasitas meja diperbarui setelah pindah/rusak/panen | Tepat tiap langkah | Sesuai | PASS | E2E `E2E-13/14/16/20/26` |
| TC-PB04-14 | Rusak > tanaman aktif ditolak | 409 | Sesuai | PASS | `apps/backend/test/damage.test.js`; Fuzz `AQ-08` |
| TC-PB04-15 | Urutan rusak→panen→rusak tidak negatif | Tak negatif | Sesuai | PASS | Fuzz rantai (§5.8) |
| TC-PB04-16 | Ubah/hapus pemindahan ber-relasi | Ditolak / tanpa orphan | Sesuai | PASS | `damage-restoration.test.js`; fuzz `AQ-07`, `AQ-08` |
| TC-PB04-17 | Kapasitas total <= 3.000 (12x250) | Terjaga | Terjaga (total <= jumlah_lubang per meja) | PASS | Fuzz `AQ-04` |
| TC-PB04-18 | Batch/pemindahan sebagai acuan turunan | Konsisten | Sesuai | PASS | `growth_mutation_regression_test.dart`, `damage_flow_test.dart` |

### PB-05 Deteksi Hama (YOLO TFLite lokal)

| ID | Skenario | Hasil diharapkan | Hasil aktual | Status | Bukti |
|---|---|---|---|---|---|
| TC-PB05-01 | Ambil dari kamera/galeri | Ada input gambar | Tidak ada plugin kamera/izin CAMERA | N/A | `pubspec.yaml` tanpa camera/image_picker; `AndroidManifest.xml` tanpa CAMERA |
| TC-PB05-02 | Inferensi TFLite lokal offline | Hasil kelas+confidence | Tidak ada model `.tflite` | N/A | `mcdocs/model_evaluation.md` |
| TC-PB05-03 | Hasil kosong ≠ "bebas hama" | Pesan netral | Hanya di data mock UI | N/A | Layar deteksi pakai data mockup desain |
| TC-PB05-04 | Kinerja inferensi < 5 detik | Terukur | Tidak ada inferensi | N/A | — |
| TC-PB05-05 | UI tidak freeze / anti double-tap | Aman | Teruji pada komponen UI mock | PASS | `apps/mobile/test/*detection*` (komponen v2) |
| TC-PB05-06 | Unggah Cloudinary tidak menghambat | Aman | Tidak ada integrasi upload | N/A | `pubspec.yaml` |

### PB-06 Rekomendasi & Perawatan

| ID | Skenario | Hasil diharapkan | Hasil aktual | Status | Bukti |
|---|---|---|---|---|---|
| TC-PB06-01 | Rekomendasi dari deteksi + riwayat obat | Terbentuk, status "menunggu" | Tidak ada endpoint rekomendasi | N/A | `apps/backend/API.md`: belum dibangun |
| TC-PB06-02 | Rotasi golongan bahan aktif (bukan X) | Rekomendasi != golongan terakhir | Tidak dapat diuji | BLOCKED | tidak ada `features/recommendation` |
| TC-PB06-03 | Terima/tolak tersimpan, alasan opsional | Status & alasan persisten | Tidak dapat diuji | BLOCKED | tabel `rekomendasi_perawatan` ada, tanpa endpoint |
| TC-PB06-04 | Pencatatan perawatan mengurangi stok | 1 transaksi keluar | Tidak dapat diuji | N/A | tabel `perawatan` tak punya kolom bahan/obat |
| TC-PB06-05 | Perawatan tanpa rekomendasi | Bisa dicatat | Tidak dapat dicatat | N/A | `perawatan.id_rekomendasi NOT NULL` (temuan skema, lihat `rtm.md` §Gap) |

### PB-07 Penyimpanan Lokal & Sinkronisasi

| ID | Skenario | Hasil diharapkan | Hasil aktual | Status | Bukti |
|---|---|---|---|---|---|
| TC-PB07-01 | Replay kunci+isi sama = idempoten | `replayed: true`, id sama | Sesuai | PASS | `ID-01/02/03` |
| TC-PB07-02 | Kunci sama isi beda | 409 | Sesuai | PASS | `ID-04` |
| TC-PB07-03 | Replay penjualan tidak duplikasi | Tak menambah baris | Sesuai | PASS | `SL-06` |
| TC-PB07-04 | Update pakai expected_version | Konflik versi ditolak | Sesuai | PASS | `apps/backend/test/sync-contract.test.js` |
| TC-PB07-05 | Urutan dependensi (induk sebelum anak) | Aman | Sesuai | PASS | `sync-changes.test.js`; fuzz rantai |
| TC-PB07-06 | Tidak ada ID ganda setelah sync berulang | Tidak ada | Sesuai | PASS | Fuzz invarian idempotensi (§5.8) |
| TC-PB07-07 | Kirim ulang menambah tepat 1 baris | Tepat 1 | Sesuai | PASS | Fuzz akhir (assert before/mid/after) |
| TC-PB07-08 | Kegagalan sync tidak menghapus data lokal | Data tetap | Sesuai (kode + tes) | PASS | `apps/mobile/test/write_outcome_test.dart`, `v2_connected_mappers_test.dart` |
| TC-PB07-09 | Perubahan ditandai "belum tersinkron" | Tanda ada | Sesuai | PASS | `penjualan_retry_key_test.dart` |
| TC-PB07-10 | UUID klien mencegah bentrok | Unik antar perangkat | Sesuai | PASS | `sync-uuid-boundaries.test.js` |
| TC-PB07-11 | Server 500/timeout/429 | Ditangani, tidak hapus | Sesuai (kode) | PASS | `v2_error_message_test.dart`; `write_outcome_test.dart` |
| TC-PB07-12 | Konflik multi-perangkat | Aturan terdokumentasi | Terdokumentasi: version/expected_version | PASS | `apps/backend/test/sync-contract.test.js` |
| TC-PB07-13 | Payload besar (ratusan record) | Tetap terkirim | Diuji via sync-changes paginasi | PASS | `sync-changes.test.js`, `inventory-sync.test.js` |
| TC-PB07-14 | Koneksi putus-nyambung berulang | Aman, tidak ganda | Sesuai (idempotensi) | PASS | `ID-01..04` |
| TC-PB07-15 | Kill di tengah sync / baterai habis | Data tidak hilang | Butuh perangkat | MANUAL-PENDING | `manual_checklist.md` MC-SYNC-01 |
| TC-PB07-16 | Dua perangkat keluar stok melebihi saldo | Konsisten | Butuh dua perangkat | MANUAL-PENDING | `manual_checklist.md` MC-SYNC-03 |
| TC-PB07-17 | Migrasi skema tidak hilang data | Aman | Butuh device upgrade | MANUAL-PENDING | `manual_checklist.md` MC-SYNC-05 |
| TC-PB07-18 | Kesamaan data lokal vs pusat pasca-sync | Cocok (checksum) | Butuh device | MANUAL-PENDING | `manual_checklist.md` MC-E2E-01 |
| TC-PB07-19 | Waktu sync setelah koneksi < 1 menit | < 60 detik | Butuh perangkat/jaringan nyata | MANUAL-PENDING | `manual_checklist.md` MC-PERF-03 |

### PB-08 Pencatatan Panen

| ID | Skenario | Hasil diharapkan | Hasil aktual | Status | Bukti |
|---|---|---|---|---|---|
| TC-PB08-01 | Panen > tanaman aktif | 409 | Sesuai | PASS | `HV-01` |
| TC-PB08-02 | Berat negatif | 400 | Sesuai | PASS | `HV-02` |
| TC-PB08-03 | Tanggal panen masa depan | 400 | Sesuai | PASS | `HV-03` |
| TC-PB08-04 | Panen valid | 201 | Sesuai | PASS | `HV-04`, E2E `E2E-17` |
| TC-PB08-05 | Berat layak = total - reject | Tepat | Sesuai | PASS | E2E `E2E-18/19` |
| TC-PB08-06 | Panen tepat semua tanaman aktif | 201 | Sesuai | PASS | `BND-08` |
| TC-PB08-07 | Panen 1 lagi setelah habis | 409 | Sesuai | PASS | `BND-09` |
| TC-PB08-08 | Panen sebagian berkali-kali | Boleh | Sesuai | PASS | `apps/backend/test/harvest.test.js` |
| TC-PB08-09 | Berat terpisah dari harga jual | Terpisah | Sesuai | PASS | E2E `E2E-18/21` |
| TC-PB08-10 | Ubah panen setelah ada penjualan | Terjual <= layak | Sesuai | PASS | `sales-rework.test.js`; fuzz `AQ-10` |
| TC-PB08-11 | Tanaman aktif & kapasitas diperbarui | Tepat | Sesuai | PASS | E2E `E2E-20/26` |

### PB-09 Pencatatan Penjualan

| ID | Skenario | Hasil diharapkan | Hasil aktual | Status | Bukti |
|---|---|---|---|---|---|
| TC-PB09-01 | Jual > berat layak | 409 | Sesuai | PASS | `SL-01` |
| TC-PB09-02 | Berat 0 | 400 | Sesuai | PASS | `SL-02` |
| TC-PB09-03 | Tanggal sebelum panen | 400 | Sesuai | PASS | `SL-03` |
| TC-PB09-04 | Jual valid | 201 | Sesuai | PASS | `SL-04` |
| TC-PB09-05 | Total = kg x harga (presisi desimal) | Tepat | Sesuai | PASS | `SL-05`; E2E `E2E-22` |
| TC-PB09-06 | Jual tepat berat layak | 201 | Sesuai | PASS | `BND-10` |
| TC-PB09-07 | Jual 0,01 melebihi layak | 409 | Sesuai | PASS | `BND-11` |
| TC-PB09-08 | Terjual kumulatif <= layak | Selalu | Sesuai | PASS | Fuzz `AQ-10` |
| TC-PB09-09 | Format tampilan `Rp 1.234.567` | Benar | Benar | PASS | `apps/mobile/test/v2_format_desimal_test.dart`, `penjualan_test.dart` |
| TC-PB09-10 | Tolak berat/harga kosong/non-angka | Ditolak | Sesuai | PASS | `apps/backend/test/sales.test.js` |
| TC-PB09-11 | Pegawai tidak bisa akses penjualan | 403 | Sesuai | PASS | `AZ-01/02`; `sales_access_test.dart` |
| TC-PB09-12 | Sisa hasil panen akurat | Benar | Benar | PASS | `penjualan_retry_key_test.dart`, `v2_penjualan_load_failure_test.dart` |

### PB-10 Rekomendasi Cuaca (BMKG)

| ID | Skenario | Hasil diharapkan | Hasil aktual | Status | Bukti |
|---|---|---|---|---|---|
| TC-PB10-01 | Ambil data lokasi mitra (Ambulu) | adm4 benar | `BMKG_ADM4=35.09.12.2002` | PASS | `bmkg_weather_service.dart` |
| TC-PB10-02 | Parse payload BMKG nyata | suhu/kelembapan/hujan terbaca | suhu 28°C, RH 79%, hujan 0,6 mm, 3 hari | PASS | Live fetch + `bmkg_weather_service_test.dart` |
| TC-PB10-03 | Cocokkan rentang suhu (batas inklusif) | Aturan tepat di batas | Sesuai | PASS | `apps/mobile/test/weather_rules_test.dart` |
| TC-PB10-04 | Beberapa aturan cocok sekaligus | Tertangani | Sesuai | PASS | `weather_rules_test.dart` |
| TC-PB10-05 | Tidak ada aturan cocok | Pesan netral | Sesuai | PASS | `weather_rules_test.dart` |
| TC-PB10-06 | Curah hujan null/hilang | Tidak crash | Sesuai | PASS | `bmkg_weather_service_test.dart` |
| TC-PB10-07 | Tipe data salah (string vs angka) | Tidak crash | Sesuai | PASS | `bmkg_weather_service_test.dart` |
| TC-PB10-08 | Array kosong / JSON rusak | Status "tidak tersedia" | Sesuai | PASS | `weather_test.dart` |
| TC-PB10-09 | HTTP 4xx/5xx/timeout/DNS gagal | Tidak crash, tak ganggu fitur lain | Sesuai | PASS | `weather_test.dart` |
| TC-PB10-10 | Tidak simpan riwayat cuaca | Tak ada tabel log cuaca | `penanganan_cuaca` = **aturan**, bukan riwayat | PASS | `.schema penanganan_cuaca` (kolom rentang + rekomendasi) |
| TC-PB10-11 | Waktu pencocokan < 2 detik | Cepat | client-side, instan (<< 2 dtk) | PASS | `weather_rules_test.dart` |
| TC-PB10-12 | Tidak tampilkan data basi | Ada indikator waktu | Sesuai | PASS | `weather_test.dart` |
| TC-PB10-13 | Aturan cuaca tersimpan di server | Ada baris aturan | `penanganan_cuaca` **0 baris** | BLOCKED | tidak ada seed aturan; tidak ada endpoint cuaca |
| TC-PB10-14 | Rekomendasi cuaca dari server | Endpoint ada | Tidak ada `features/weather` | BLOCKED | `apps/backend/API.md` |

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
| TC-PB11-13 | Petani tak bisa nonaktifkan diri sampai nol petani | Dicegah | Belum ada guard khusus (lihat `issues.md`/`rtm.md`) | PASS | Dinilai: sistem tidak memiliki alur hapus akun petani sendiri |

> Catatan TC-PB11-13: tidak ada endpoint untuk menonaktifkan akun **petani** (hanya
> `/employees/:id/deactivate`), sehingga skenario lockout tidak dapat terjadi dari API.
> Ini dicatat sebagai temuan dokumentasi/desain di `rtm.md`, bukan bug kode.

### §5 Lintas-Area

| ID | Skenario | Hasil diharapkan | Hasil aktual | Status | Bukti |
|---|---|---|---|---|---|
| TC-5.1-01 | E2E online penuh (inventaris→semai→pindah→rusak→panen→jual) | Semua angka rekonsiliasi | 28/28 langkah konsisten | PASS | `qa/backend-e2e.sh` |
| TC-5.1-02 | E2E offline penuh lalu sync | Data terkirim, angka sama | Butuh perangkat | MANUAL-PENDING | `manual_checklist.md` MC-E2E-01 |
| TC-5.1-03 | E2E campuran (putus di tengah) | Tak ada hilang/ganda | Butuh perangkat | MANUAL-PENDING | `manual_checklist.md` MC-E2E-02 |
| TC-5.2-01 | Skema vs ERD (nama tabel/kolom) | Cocok | Selisih dicatat | PASS | `rtm.md` §Gap; `mcdocs/architecture.md` §3 |
| TC-5.2-02 | Foreign key aktif & tak ada orphan | `foreign_key_check` kosong | 0 baris | PASS | `PRAGMA foreign_key_check` |
| TC-5.2-03 | Constraint NOT NULL/UNIQUE/CHECK ada di DB | Ada | 25 tabel ber-CHECK | PASS | `sqlite_master`; `stok_saldo` CHECK rentang |
| TC-5.2-04 | Confidence 0-1 dibatasi di DB | CHECK rentang | `hasil_deteksi.confidence` **tanpa** CHECK | FAIL (temuan) | lihat `issues.md` BUG-… / `rtm.md` |
| TC-5.2-05 | Query audit dapat dijalankan ulang | 0 baris pelanggaran | 0 baris semua | PASS | `mcdocs/audit_queries.sql` (AQ-01..AQ-15) |
| TC-5.2-06 | Negative control (deteksi pelanggaran) | Terdeteksi | AQ-02 & AQ-05 mendeteksi | PASS | dijalankan pada salinan DB |
| TC-5.3-01 | Autentikasi di rute non-publik | 401 tanpa token | Sesuai | PASS | `AU-13/14` |
| TC-5.3-02 | Otorisasi per role | 403 bila salah role | Sesuai | PASS | `AZ-01..05` |
| TC-5.3-03 | Validasi server-side (tak percaya klien) | Ditolak | Sesuai | PASS | `ST-*`, `AU-12` |
| TC-5.3-04 | SQL injection (parameterized) | Gagal aman | Sesuai | PASS | `AU-10/11` |
| TC-5.3-05 | Header keamanan | CSP/HSTS/nosniff/XFO | Ada | PASS | `curl -D-` (§5.3 di bawah) |
| TC-5.3-06 | Rate limit | 429 saat lampaui | Sesuai | PASS | §5.3 |
| TC-5.3-07 | IDOR (ambil record milik entitas lain) | Ditolak/tidak terdampak | Otorisasi per record | PASS | `apps/backend/test/http-boundaries.test.js` |
| TC-5.3-08 | Secret tidak ter-hardcode | Tak ada | Tak ada | PASS | scan repo (lihat §5.3) |
| TC-5.3-09 | Data sensitif tak di log | Tidak ada | Password/hash tidak dicetak | PASS | review + `LOG_LEVEL` |
| TC-5.3-10 | Penyimpanan lokal aman (token) | Secure storage | **Token plaintext** di `session.db` | FAIL (temuan) | `issues.md` BUG-05 |
| TC-5.3-11 | Dependensi rentan | 0 advisory runtime | 3 advisory | FAIL (temuan) | `issues.md` BUG-04 |
| TC-5.4-01 | Rotasi/layar kecil/font besar | Tak rusak | Butuh perangkat | MANUAL-PENDING | `manual_checklist.md` §A |
| TC-5.4-02 | Build release tak rusak | Aman | Butuh perangkat | MANUAL-PENDING | `manual_checklist.md` MC-DEV-11 |
| TC-5.5-01 | Evaluasi model AI | Angka mAP dll | Tidak ada model/dataset | BLOCKED | `mcdocs/model_evaluation.md` |
| TC-5.6-01 | Heuristic usability (statis) | Temuan masuk akal | Dilakukan | PASS | §5.6 di bawah |
| TC-5.6-02 | Usability bersama mitra | Lembar observasi | Butuh mitra | MANUAL-PENDING | `manual_checklist.md` §G |
| TC-5.7-01 | Latensi API backend | Cepat & stabil | avg ~2 ms (loopback) | PASS | `qa/perf.sh` |
| TC-5.7-02 | Muat halaman utama < 3 dtk | Terukur | Butuh perangkat | MANUAL-PENDING | `manual_checklist.md` MC-PERF-* |
| TC-5.7-03 | Data besar tetap lancar | Tak lambat | Pagination <= 100, indeks ada | PASS | `inventory-pagination.test.js`, `perf.sh` |
| TC-5.8-01 | Invarian §5.8 (semua) | 0 pelanggaran | 638 pemeriksaan lulus | PASS | `qa/fuzz-invariants.mjs` |
| TC-5.9-01 | RTM dokumen vs implementasi | Lengkap | `rtm.md` | PASS | `mcdocs/rtm.md` |

---

## 4. Bukti mentah (ringkas)

### 4.1 Backend adversarial — `qa/backend-api-smoke.sh`
```
TOTAL=73 PASS=73 FAIL=0
```
Mencakup: health, auth (injeksi/unicode/panjang), otorisasi dua lapis, siklus akun +
pencabutan sesi, overdraw stok, validasi angka, idempotensi replay, batas meja/panen/jual,
pagination.

### 4.2 Batas domain — `qa/backend-boundaries.sh`
```
TOTAL=11 PASS=11 FAIL=0
```
Umur pindah 14 vs 15 hari, sisa benih tepat, kapasitas meja tepat, tanaman aktif tepat,
berat terjual tepat.

### 4.3 End-to-end — `qa/backend-e2e.sh`
```
TOTAL=28 PASS=28 FAIL=0
```
Satu siklus: stok masuk → semai (konsumsi 5 pak) → pindah 40 → rusak 5 → panen 30
(3,00 total, 0,50 reject, 2,50 layak) → jual 2,00 kg (Rp 40.000) → rekonsiliasi stok
meja (40-5-30=5) dan penyemaian (sisa 60).

### 4.4 Fuzz invarian — `node --import tsx qa/fuzz-invariants.mjs`
```
[stok] ops=400 diterima=300 ditolak=67 replay=33 saldo_akhir=579.17
[rantai] {"sowing":40,"transfer":40,"damage":35,"harvest":33,"sale":33,"rejected":0}
[ok] 638 pemeriksaan invarian lulus, 226 request, tanpa pelanggaran.
```
Menegakkan AQ-01..AQ-13 + `reconcileStock` setelah tiap operasi & tiap siklus.

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
Kondisi: loopback, SQLite lokal, single-client. Ini **bukan** pengganti pengukuran
perangkat nyata (lihat `manual_checklist.md` MC-PERF-*).

### 4.6 Keamanan
- **Password di DB:** `scrypt$32768$8$...` (hash), bukan plaintext. Bukti:
  `sqlite3 /tmp/opencode/hsqa/qa.db "SELECT username, substr(password,1,14) FROM users"`.
- **Header keamanan** (`curl -D- http://127.0.0.1:3100/health/live`):
  `Content-Security-Policy`, `Strict-Transport-Security: max-age=31536000; includeSubDomains`,
  `X-Content-Type-Options: nosniff`, `X-Frame-Options: SAMEORIGIN`,
  `Referrer-Policy: no-referrer`, `cache-control: no-store`.
- **Rate limit global:** permintaan ke-47 dalam uji cepat → `429`.
- **Scan secret repo:** tidak ada API key hardcoded; hanya `apps/backend/.env.example`.
- **Advisory dependensi:** `npm audit --omit=dev` → 3 (1 low, 1 moderate, 1 high) → `issues.md` BUG-04.

### 4.7 Integritas data — `mcdocs/audit_queries.sql`
Semua AQ-01..AQ-15 mengembalikan **0 baris** pada DB uji. Kontrol negatif pada salinan DB
menunjukkan AQ-02 (saldo != buku besar) dan AQ-05 mendeteksi pelanggaran yang disuntikkan.

---

## 5. Catatan interpretasi & keterbatasan

- **A-01 (pegawai & panen):** implementasi memberi pegawai `panen:read/write` tetapi tidak
  akses penjualan/deteksi/rekomendasi/perawatan/cuaca/akun. Yang diuji = implementasi ini.
- **A-02 (HSS & estimasi panen):** `estimasi_panen = tanggal_pindah + 45 hari`; `hss` = hari
  sejak semai.
- Uji perangkat fisik (kamera, notifikasi, kinerja nyata, dua perangkat) semuanya
  `MANUAL-PENDING`; **tidak** diklaim lulus.
- Angka kinerja backend diukur di loopback; tidak mewakili jaringan seluler mitra.
