# qa/issues.md — Bug & temuan (HidroSense)

Format sesuai PROMPT §8. Severity: S1 Critical / S2 Major / S3 Minor / S4 Cosmetic.
Status: `OPEN` | `FIXED` | `WONTFIX` | `NEEDS-HUMAN-REVIEW`.

Batas perbaikan (permintaan client): **hanya** bug di `apps/mobile/` yang diperbaiki.
Bug backend/DB/ML/keamanan **didokumentasikan** dengan saran perbaikan. Skrip QA
(harness/kueri audit) boleh diperbaiki bila terbukti salah memodelkan produk;
perubahan itu tidak mengubah perilaku produk.

## Statistik

| Severity | Ditemukan | Diperbaiki | Terbuka / review |
|---|---|---|---|
| S1 Critical | 0 | 0 | 0 |
| S2 Major | 1 | 0 | 1 |
| S3 Minor | 11 | 8 | 3 |
| S4 Cosmetic | 2 | 1 | 1 |
| **Total** | **14** | **9** | **5** |

Rincian: **FIXED** = BUG-01,02,03,06,07,08,09,10,11 (9). **NEEDS-HUMAN-REVIEW** =
BUG-04 (S2, dependensi), BUG-05 (S3, token plaintext), BUG-12/13 (S3, harness ML &
doc API usang), BUG-14 (S4, komentar usang).
Gap fitur (bukan bug kode) dicatat di `qa/rtm.md` §Gap. Tidak ada temuan **S1**.
Semua temuan di luar perbaikan (backend/DB/ML/keamanan/dokumentasi) berstatus
`NEEDS-HUMAN-REVIEW` dengan alasan.

---

## BUG-01 [S3] formatAngka menghasilkan titik gantung ("1.")
- Area/PB: PB-08/09/10 (tampilan angka) · Ditemukan lewat: review kode + `TC-FE-01`
- Langkah reproduksi: 1) panggil `formatAngka(1.001)` di `apps/mobile`.
- Ekspektasi: `"1"`.
- Aktual: `"1."` — `toStringAsFixed(2)` → `"1.00"`, lalu pemangkas nol membuang nol tapi bukan titik.
- Bukti: `flutter test test/core_formatting_test.dart` gagal sebelum perbaikan.
- Penyebab (akar): regex pemangkas nol di `apps/mobile/lib/core/formatting.dart:31` tidak opsional terhadap titik.
- Status: **FIXED** — `replaceFirst(RegExp(r'\.?0+$'), '')`.
- Regression test: `apps/mobile/test/core_formatting_test.dart`.

## BUG-02 [S3] formatAngkaDesimal/formatKg menghasilkan koma gantung ("1, kg")
- Area/PB: PB-08/PB-09 (label berat/juta) · Ditemukan lewat: `TC-FE-02`
- Langkah reproduksi: 1) `formatAngkaDesimal(1.001)`; 2) `formatKg(1.001)`.
- Ekspektasi: `"1"` dan `"1 kg"`.
- Aktual: `"1,"` dan `"1, kg"`.
- Bukti: `flutter test test/v2_format_desimal_test.dart` gagal sebelum perbaikan.
- Penyebab (akar): pola sama seperti BUG-01 di `v2_penjualan_data.dart:309`.
- Status: **FIXED** — regex `\.?0+$` sebelum `replaceAll('.', ',')`.
- Regression test: `apps/mobile/test/v2_format_desimal_test.dart`.

## BUG-03 [S3] Lencana "Menipis" tidak konsisten dengan aturan kanonik di batas minimum
- Area/PB: PB-02 · Ditemukan lewat: `TC-FE-03`
- Langkah reproduksi: 1) barang `saldo == stok_minimum` (mis. 3 dan 3); 2) bandingkan daftar Stok v2 vs kartu Beranda.
- Ekspektasi: bukan menipis (backend `di_bawah_minimum = saldo < minimum`).
- Aktual: `statusStok()` memakai `<=`, jadi diberi lencana "Menipis".
- Bukti: `flutter test test/v2_inventaris_status_test.dart` gagal sebelum perbaikan.
- Penyebab (akar): ambang inklusif di `v2_inventaris_data.dart:38`.
- Status: **FIXED** — `jumlah <= minimum` → `jumlah < minimum`.
- Regression test: `apps/mobile/test/v2_inventaris_status_test.dart`.

## BUG-04 [S2] Dependensi backend memiliki 3 advisory keamanan
- Area/PB: §5.3 Keamanan · Ditemukan lewat: `npm audit --omit=dev`
- Langkah reproduksi: `cd apps/backend && npm audit --omit=dev`.
- Ekspektasi: tidak ada advisory pada dependensi runtime.
- Aktual: `3 vulnerabilities (1 low, 1 moderate, 1 high)`:
  - `zod <4.6.6` — **high** — kehabisan memori saat validasi koleksi besar (GHSA-mrhx-c7xc-m3w5).
  - `fastify 5.12.2–5.12.5` — header validation bypass (GHSA-389g-gv7q-r4x8).
  - `fast-uri` (via ajv) — scheme injection.
- Bukti: keluaran `npm audit` (nyata, 24 Nov 2026).
- Penyebab (akar): versi terkunci lebih lama dari patch.
- Status: **NEEDS-HUMAN-REVIEW** — menyentuh dependensi backend (di luar batas perbaikan fe).
  Saran: naikkan `zod` ≥4.6.7, `fastify` ≥5.12.8, lalu `npm test` (432 tes) untuk regresi.
- Regression test: tidak ada (belum diperbaiki).

## BUG-05 [S3] Token sesi disimpan plaintext di SQLite lokal (`session.db`)
- Area/PB: PB-01 / §5.3 · Ditemukan lewat: review kode
- Langkah reproduksi: 1) login di app; 2) periksa `session.db` di sandbox aplikasi.
- Ekspektasi: token di penyimpanan terenkripsi (Android Keystore / `flutter_secure_storage`).
- Aktual: `session_store.dart` menyimpan access/refresh token sebagai teks di tabel SQLite `sessions`.
  Password tidak disimpan (server: hash scrypt), tetapi token = kredensial bearer.
- Bukti: pembacaan `session_store.dart`; tidak ada dep `flutter_secure_storage` di `pubspec.yaml`.
- Penyebab (akar): desain penyimpanan lokal memakai sqflite biasa.
- Status: **NEEDS-HUMAN-REVIEW** — menyentuh desain penyimpanan + migrasi, bukan perbaikan lokal.
- Regression test: tidak ada.

## BUG-06 [S3] Angka kartu "Stok menipis" ≠ isi daftar tersaring
- Area/PB: PB-02 · Ditemukan lewat: `TC-PB02-09`
- Langkah reproduksi: 1) buat barang menipis dari kategori selain Benih; 2) bandingkan angka kartu Beranda dengan daftar yang dibukanya.
- Ekspektasi: angka kartu = jumlah baris daftar yang dibuka.
- Aktual (dulu): kartu menghitung semua jenis; daftar difilter Benih + Menipis → angka bisa lebih besar.
- Bukti: `flutter test test/v2_low_stock_parity_test.dart` (lulus) — cakupan kini sama: semua jenis di bawah minimum/habis.
- Penyebab (akar): perbedaan cakupan agregasi vs filter tujuan.
- Status: **FIXED** — cakupan disamakan (`berandaLowStockCount` == baris `status != aman`).
- Regression test: `apps/mobile/test/v2_low_stock_parity_test.dart`, `v2_beranda_low_stock_test.dart`.

## BUG-07 [S4] Sync replayer menandai "gagal" bila penghapusan baris antrean error
- Area/PB: PB-07 · Ditemukan lewat: review kode
- Langkah reproduksi: 1) baris diterima server; 2) `queue.remove()` melempar (I/O SQLite sesaat).
- Ekspektasi: baris yang sudah diterima tidak ditandai gagal.
- Aktual (dulu): `send()` + `remove()` dalam satu `try`; kegagalan `remove` menandai baris `gagal`.
- Bukti: `flutter test test/v2_sync_replayer_test.dart` ("kegagalan melepas baris tidak menandai baris gagal (BUG-07)").
- Penyebab (akar): penggabungan dua langkah berbeda-nasib dalam satu `try`.
- Status: **FIXED** — `send` dipisah dari `remove`.
- Regression test: `apps/mobile/test/v2_sync_replayer_test.dart`.

## BUG-08 [S3] `confidence` hasil deteksi tidak dibatasi 0–1 di level DB
- Area/PB: §5.2 · Ditemukan lewat: `TC-5.2-04`
- Langkah reproduksi: `sqlite3 /tmp/opencode/hsqa/qa.db ".schema deteksi_hama"`.
- Ekspektasi: constraint rentang di DB.
- Aktual (dulu): `hasil_deteksi.confidence DECIMAL(5,4)` tanpa CHECK.
- Bukti: skema live kini memuat
  `confidence_maks REAL CHECK (confidence_maks IS NULL OR BETWEEN 0 AND 1)`
  pada `deteksi_hama` (migrasi `0019_pest_rotation.up.sql`). Kontrol negatif AQ-17 mendeteksi nilai di luar rentang.
- Penyebab (akar): constraint belum ada saat tabel pertama dibuat; ditambahkan saat fitur dibangun.
- Status: **FIXED** (oleh migrasi 0019, sesi backend).
- Regression test: `qa/audit_queries.sql` AQ-17.

## BUG-09 [S3] Baris konflik **panen** buntu di layar Sinkron
- Area/PB: PB-07 · Ditemukan lewat: `qa/backend-concurrency.sh` + review kode
- Langkah reproduksi: 1) sebabkan konflik versi pada panen; 2) buka layar Sinkron, ketuk baris panen.
- Ekspektasi: dialog resolusi konflik terbuka.
- Aktual (dulu): `V2PanenSender` tidak punya resolver → baris buntu.
- Bukti: `flutter test test/v2_panen_conflict_test.dart` (lulus).
- Penyebab (akar): resolver konflik belum dipasang untuk pengirim panen.
- Status: **FIXED** — `V2PanenSender` memakai `V2SyncConflictResolver` + provider resolver.
- Regression test: `apps/mobile/test/v2_panen_conflict_test.dart`.

## BUG-10 [S3] Baris "Rusak" gagal (bukan konflik) membuka dialog konflik
- Area/PB: PB-07 · Ditemukan lewat: review kode
- Langkah reproduksi: 1) buat baris Rusak gagal non-konflik; 2) ketuk barisnya.
- Ekspektasi: tidak membuka dialog konflik.
- Aktual (dulu): `_actionFor` membuka dialog konflik untuk kegagalan biasa.
- Bukti: `flutter test test/v2_sinkron_rusak_action_test.dart` ("baris Rusak gagal yang bukan konflik tidak membuka dialog").
- Penyebab (akar): `_actionFor` tidak memakai penjaga `item.konflik`.
- Status: **FIXED**.
- Regression test: `apps/mobile/test/v2_sinkron_rusak_action_test.dart`.

## BUG-11 [S3] Kueri audit AQ-09/AQ-10 salah memodelkan skema berat panen (QA-tooling)
- Area/PB: §5.2/§5.8 (kueri audit) · Ditemukan lewat: run fuzz §5.8 → assertion AQ-10
- Langkah reproduksi: 1) panen dengan `berat_reject > 0`; 2) jual tepat berat layak;
  3) jalankan kueri AQ-10 lama.
- Ekspektasi: 0 baris (produk benar).
- Aktual: AQ-10 lama melaporkan "terjual > layak" **palsu**, karena
  `SUM(berat_minor - berat_reject_minor)` mengurangi reject dua kali. Kolom
  `detail_panen.berat_minor` **sudah** menyimpan berat layak (total − reject)
  (`harvest/service.ts:27-28`); reject ada di `berat_reject_minor` sendiri. AQ-09
  lama juga membandingkan `reject > berat_minor` yang bukan invarian "reject <= total".
- Bukti (repro `/tmp/opencode/hsqa/repro-aq10.mjs`):
  ```
  RAW detail_panen: berat=2.5, berat_minor=250, reject_minor=50
  jual 2,50 -> 201 ; jual 2,51 -> 409 SALE_EXCEEDS_HARVEST_STOCK
  AQ-10 WRONG: [{"id_panen":1}]   AQ-10 FIXED: []
  ```
- Penyebab (akar): kueri audit (dan skrip fuzz lama) memakai `berat_minor` sebagai
  berat total, padahal itu berat layak.
- Status: **FIXED** (QA tooling) — `qa/audit_queries.sql` (AQ-09/AQ-10) dan
  `apps/backend/qa/fuzz-invariants.mjs` diperbaiki. **Produk tidak diubah.**
  Fuzz kini 638 pemeriksaan lulus (3 run).
- Regression test: `qa/audit_queries.sql` + kontrol negatif; `repro-aq10.mjs`.

## BUG-12 [S3] 3 tes harness ML gagal karena asumsi branch/platform (QA-tooling)
- Area/PB: §5.5 / CI ML · Ditemukan lewat: `python3 -m pytest ml/tests`
- Langkah reproduksi: `cd /home/eiser/coolyeah/PPL/hidrosense && python3 -m pytest ml/tests -q`.
- Ekspektasi: semua lulus.
- Aktual: `3 failed, 165 passed`:
  1. `test_f5_t1_committed_branch_diff_strictly_inside_ml` — mengasumsikan
     `git diff main..HEAD` hanya menyentuh `ml/`. Pada branch `wild-fe`, diff memuat
     922 path non-`ml/`. (Asumsi branch ML terpisah.)
  2. `test_f5_t1_commit_history_main_to_head_clean_of_secrets_and_non_ml_paths`
     — asumsi sama lewat `git log main..HEAD --name-only`.
  3. `test_f2_t2_push_kaggle_kernel_propagates_missing_cli_and_failure` —
     `PermissionError: [Errno 13]` pada `os.posix_spawn('…/fake_kaggle.cmd')` di Linux
     (file `.cmd` tak dieksekusi di Linux; asumsi Windows).
- Bukti: `/tmp/opencode/hsqa/ml-pytest.log` (akhir: `3 failed, 165 passed`).
- Penyebab (akar): tes mengasumsikan (a) branch ML terpisah, (b) host Windows.
- Status: **NEEDS-HUMAN-REVIEW** — memperbaiki tes ML (menyeleksi path `ml/` saja;
  menghormati `PATHEXT`/membuat skrip POSIX) di luar batas perbaikan produk sesi ini.
- Regression test: tidak ada (belum diperbaiki). Model sendiri lulus (§`model_evaluation.md`).

## BUG-13 [S3] `apps/backend/API.md` menyatakan fitur perawatan/potong-stok "belum dibangun"
- Area/PB: §5.9 (regresi dokumen vs implementasi) · Ditemukan lewat: review doc + `qa/backend-pest-rotation.sh`
- Langkah reproduksi: `grep -n "Belum tersedia" -A4 apps/backend/API.md` (baris 273–275).
- Ekspektasi: dokumen API cocok dengan implementasi.
- Aktual: paragraf menulis "pemotongan stok otomatis saat rekomendasi diterima belum
  dibangun", padahal **sudah** jalan (suite membuktikan saldo 10→8 saat terima).
- Bukti: `apps/backend/API.md:273-275`; `qa/backend-pest-rotation.sh` §D (potong stok).
- Penyebab (akar): doc API tak diperbarui setelah endpoint rekomendasi/perawatan dibangun.
- Status: **NEEDS-HUMAN-REVIEW** — perbaikan dokumen tim (bukan kode), di luar sesi QA.
  Saran: hapus/ubah paragraf "Belum tersedia" agar cocok dengan endpoint nyata.
- Regression test: tidak ada.

## BUG-14 [S4] Doc-comment usang di tab Rawat connected
- Area/PB: PB-05/PB-06 (kerapian kode) · Ditemukan lewat: review kode
- Langkah reproduksi: baca `apps/mobile/lib/views/v2/connected/v2_rawat_connected.dart:39-40`.
- Ekspektasi: komentar cocok dengan perilaku.
- Aktual: komentar berbunyi "Alur foto/AI belum punya endpoint sehingga tombol
  'Foto tanaman' hanya menjelaskan hal itu", padahal tombol kini membuka
  `PestScanPage.route()` (fitur sudah ada).
- Bukti: `v2_rawat_connected.dart:39-40` vs `:70` (`onFotoTanaman: () => Navigator…PestScanPage.route()`).
- Penyebab (akar): komentar tak diperbarui saat alur foto/AI dipasang.
- Status: **NEEDS-HUMAN-REVIEW** — hanya komentar; tidak mengubah perilaku. Di luar
  batas perbaikan sesi (dokumentasi-only).
- Regression test: tidak ada.

---

## Catatan (bukan bug)

- **XSS di field teks:** server menyimpan `<script>…` apa adanya dan mengembalikannya di
  JSON. Klien Flutter merender sebagai teks (tanpa WebView/HTML) → tidak dieksekusi.
  Bila kelak ada klien web, sanitasi wajib.
- **Constraint DB mencegah stok negatif:** menyisipkan `saldo_minor=-5` ditolak `CHECK`.
  Pertahanan berlapis, bukan bug.
- **Kontrak `acceptRecommendation`:** lihat deviasi desain TC-PB06-04 (G-12 di `rtm.md`),
  dicatat sebagai gap, bukan bug fatal.
- **Fuzz >15 menit (jam simulasi) → 401:** token akses tak diperbarui di dalam loop stok;
  batasan harness (default 400/40 aman), bukan produk.
