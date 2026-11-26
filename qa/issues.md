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
| S2 Major | 16 | 14 | 2 |
| S3 Minor | 41 | 38 | 3 |
| S4 Cosmetic | 3 | 3 | 0 |
| **Total** | **60** | **55** | **5** |

Rincian: **FIXED** = BUG-01,02,03,06,07,08,09,10,11,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,57,58,59,68 (55).
**NEEDS-HUMAN-REVIEW** = BUG-04 (S2, dependensi), BUG-05 (S3, token plaintext),
BUG-12/13 (S3, harness ML & doc API usang), BUG-56 (S2, password server min 12 — butuh backend).
Catatan: BUG-31 tetap dihitung FIXED walau sempat dibuka ulang (OPEN) di sesi 4, karena
sudah diperbaiki ulang dan lulus tes; hitungan menemukan/memperbaiki tidak berubah dua kali.
Gap fitur (bukan bug kode) dicatat di `qa/rtm.md` §Gap. Tidak ada temuan **S1**.
Semua temuan di luar perbaikan (backend/DB/ML/keamanan/dokumentasi) berstatus
`NEEDS-HUMAN-REVIEW` dengan alasan.

> Diperbarui 24 Nov 2026: BUG-15..BUG-21 ditambahkan dari hasil uji manual dev FE
> di HP asli (24 Nov 2026). BUG-14 dinaikkan dari review menjadi FIXED.
> Sesi 2 (24 Nov 2026): BUG-22..BUG-25 ditambahkan dari laporan manual dev FE yang
> sama dan sudah diperbaiki di `apps/mobile`. BUG-24 melanjutkan BUG-20 (lihat D-21).
> BUG-16 naik dari `NEEDS-HUMAN-REVIEW` ke **FIXED** setelah tim backend mengisi
> kredensial Cloudinary dan dev FE berhasil menyimpan pindaian di HP (24 Nov 2026).
> Sesi 3 (24 Nov 2026): BUG-26..BUG-32 ditambahkan dari laporan manual dev FE yang
> sama dan sudah diperbaiki di `apps/mobile` (D-23/D-24). Status **FIXED di kode**,
> tetapi **verifikasi visual ulang di HP asli belum dilakukan** dan menunggu dev FE.
> Sesi 4 (24 Nov 2026): hasil uji manual dev FE masuk — BUG-26,27,29,30,32 **PASS**;
> BUG-28 tombol PASS tetapi data basi → **BUG-34**; BUG-31 **dibuka ulang** (OPEN) dan
> diperbaiki ulang jadi daftar per bulan. Ditambah BUG-33..BUG-38 dari temuan yang sama
> (audit pintu masuk + invalidasi provider), semuanya sudah **FIXED di kode** + regression
> test, plus 3 fitur tambahan sesuai keputusan PM (Fitur-1..3, D-27/D-28/D-29).
> Status BUG-33..38 = **FIXED di kode, belum diuji ulang di HP** (menunggu dev FE).
> Sesi 5 (25 Nov 2026): audit pintu masuk Detail meja & alur panen menghasilkan
> BUG-39..BUG-43, lalu BUG-44..BUG-47 dari uji manual dev FE. Semuanya **FIXED di kode**
> + regression test (701 tes lulus). **Verifikasi ulang di HP asli belum dilakukan**;
> hasil manual dev FE dicatat sebagai "diuji manual dev FE", bukan PASS QA.
> Sesi 6 (25 Nov 2026): triase 30 temuan pelapor (K-01..K-30, D-33) → BUG-48..BUG-55
> **FIXED di kode** + regression test (**816 PASS**, `flutter analyze` 0).
> Lanjutan Sesi 6 (26 Nov 2026): keputusan PM D-34/D-35/D-36/D-39 → BUG-57..BUG-59
> **FIXED di kode** + regression test (**841 PASS**); **BUG-56** (password server min 12)
> dicatat **butuh backend/PM** (`NEEDS-HUMAN-REVIEW`). Semua verifikasi ulang di HP asli
> masih menunggu dev FE (bukan klaim PASS).

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
- Status: **FIXED** — komentar diperbarui (24 Nov 2026) agar menyebut `PestScanPage`
  (deteksi di perangkat + unggah foto). Hanya komentar; perilaku tidak berubah.
- Regression test: tidak ada (perubahan dokumentasi-kode saja).

## BUG-15 [S3] Kontrol "tingkat serangan" di Deteksi hama berantakan (kapsul/chip)
- Area/PB: PB-05 (deteksi hama) · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026)
- Langkah reproduksi: 1) buka Menu "Deteksi hama"; 2) ambil foto sampai hasil muncul; 3) lihat pemilih "Tingkat serangan".
- Ekspektasi: tiga pilihan Ringan/Sedang/Berat tersusun rapi dalam satu kapsul.
- Aktual: `SegmentedButton` bawaan Material (membawa ikon centang, lebar mengikuti isi) melampaui lebar kartu → layout rusak/meluber, terutama di layar sempit dan saat skala teks besar.
- Bukti: `flutter test test/pest_scan_page_test.dart` ("kapsul tingkat serangan tidak meluber di layar sempit") — gagal sebelum perbaikan, lulus sesudahnya.
- Penyebab (akar): kontrol bukan kapsul desain v2 dan tidak dibatasi lebar induk.
- Status: **FIXED** — diganti `V2Segmented` (kapsul desain v2: tiap segmen `Expanded`, teks elipsis) di `pest_scan_page.dart`.
- Regression test: `apps/mobile/test/pest_scan_page_test.dart`.

## BUG-16 [S2] Simpan deteksi gagal: "Layanan unggah foto belum dikonfigurasi."
- Area/PB: PB-05 / unggahan foto · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026)
- Langkah reproduksi: 1) Deteksi hama → hasil → tekan "Simpan dan minta saran obat".
- Ekspektasi: foto tersimpan dan kartu saran muncul.
- Aktual: gagal dengan pesan server `503 UPLOAD_NOT_CONFIGURED`.
- Bukti: `apps/backend/src/common/cloudinary.ts:13` — `requireCloudinary()` melempar bila `config.cloudinary` kosong (env `CLOUDINARY_CLOUD_NAME/API_KEY/API_SECRET` belum diisi di server). Mobile meneruskan pesan server apa adanya via `pestErrorMessage`.
- Penyebab (akar): **konfigurasi backend/server** (kredensial Cloudinary belum diisi), bukan bug kode mobile.
- Status: **FIXED** — tim backend mengisi env `CLOUDINARY_*` di server; simpan pindaian berhasil di HP (uji manual dev FE, 24 Nov 2026). Sisi mobile tetap mencatat perbaikan pesannya: `UPLOAD_NOT_CONFIGURED`/`UPLOAD_FAILED` diterjemahkan menjadi kalimat yang bisa ditindaklanjuti petani.
- Regression test: `apps/mobile/test/pest_error_message_test.dart` (pemetaan pesan, 3 kasus). Blocker unggah sudah hilang; MC-PERF-07 (deteksi 50×) berpindah dari `BLOCKED` ke `MANUAL-PENDING`.

## BUG-17 [S3] Lokasi Cuaca hanya menampilkan Malang/Batu/Pasuruan
- Area/PB: PB-10 (cuaca BMKG) · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026)
- Langkah reproduksi: 1) Menu Cuaca; 2) buka sheet "pilih lokasi".
- Ekspektasi: lokasi mitra (Ambulu, Jember) ada dan terpilih secara default.
- Aktual: daftar cadangan menampilkan Malang, Batu, Pasuruan.
- Bukti: `flutter test test/v2_cuaca_lokasi_test.dart` ("lokasi cadangan memakai Ambulu, bukan Malang").
- Penyebab (akar): `designCuacaLokasi` di `v2_cuaca_data.dart` masih memakai data contoh lama.
- Status: **FIXED** — daftar cadangan diganti Sabrang/Ambulu/Jember dengan Ambulu paling depan. Kode BMKG default `BMKG_ADM4=35.09.12.2002` (Desa Sabrang, Kec. Ambulu) memang sudah benar.
- Regression test: `apps/mobile/test/v2_cuaca_lokasi_test.dart`.

## BUG-18 [S3] Kartu "Lubang terisi" di Beranda tidak bisa ditekan
- Area/PB: Beranda (frame 2.1) · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026)
- Langkah reproduksi: 1) Beranda; 2) tekan kartu "Lubang terisi".
- Ekspektasi: terbuka menu Tanam → segmen Meja.
- Aktual: kartu tidak bereaksi (`onFilledHoles` tidak dipasang).
- Bukti: `flutter test test/v2_beranda_filled_holes_test.dart` ("kartu 'Lubang terisi' membuka Tanam → Meja").
- Penyebab (akar): `V2BerandaPage` hanya menyalurkan `onLowStock` ke `V2BerandaStats`, tidak `onFilledHoles`.
- Status: **FIXED** — `onFilledHoles` disalurkan; kartu membuka Tanam ke segmen Meja lewat `tanamTabBuilder`.
- Regression test: `apps/mobile/test/v2_beranda_filled_holes_test.dart`.

## BUG-19 [S2] Setelah sesi dipulihkan (app dibuka ulang) mendarat di tampilan v1
- Area/PB: Navigasi/akun · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026)
- Langkah reproduksi: 1) login; 2) tutup app dari latar belakang; 3) buka lagi.
- Ekspektasi: langsung ke beranda v2 (sesi masih ada).
- Aktual: masuk ke beranda v1 (`MainPage`) karena mode v2 tidak dipulihkan.
- Bukti: `flutter test test/app_gate_v2_restore_test.dart` ("sesi dipulihkan membuka beranda v2, bukan v1").
- Penyebab (akar): `AppGate` memilih v2 hanya bila `v2UiModeProvider` true, dan nilai itu tidak tersimpan/dipulihkan.
- Status: **FIXED** — begitu ada sesi, `AppGate` selalu membuka `V2BerandaConnectedPage`; jalur masuk v1 diputus. File/kode v1 **tidak dihapus** (keputusan D-15).
- Regression test: `apps/mobile/test/app_gate_v2_restore_test.dart`, `connected_flow_test.dart`.

## BUG-20 [S3] Skala teks sistem 200% membuat beberapa layar meluber (overflow)
- Area/PB: §5.4 (aksesibilitas/tampilan) · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026)
- Langkah reproduksi: 1) set ukuran font sistem ke 200%; 2) buka Beranda, Deteksi hama, Cuaca, Sinkron.
- Ekspektasi: teks membungkus, tidak ada garis kuning-hitam overflow.
- Aktual: overflow vertikal/horizontal pada kartu hero Beranda, petak statistik, tab bar bawah, kartu lokasi/info Cuaca.
- Bukti: `flutter test test/v2_text_scale_test.dart` dan `pest_scan_page_test.dart` (skala 2.0) — gagal sebelum perbaikan, lulus sesudahnya.
- Penyebab (akar): banyak tinggi tetap (`height: 160`, `height: size`, `SizedBox(height: 56/48)`) sementara teks ikut membesar.
- Status: **FIXED** — tinggi tetap diganti tinggi minimum; teks boleh membungkus; petak statistik disamakan tinggi dengan `IntrinsicHeight`. Layar: `v2_beranda_hero.dart`, `v2_bento_tile.dart`+`v2_beranda_stats.dart`, `v2_tab_bar.dart`, `v2_cuaca_cards.dart`.
- Catatan sesi 2: uji manual 24 Nov 2026 menunjukkan **layar lain** (Siklus berjalan, Siap pindah, daftar Tanaman, Detail pegawai, Ringkasan penjualan, Detail meja) masih meluber pada font 200%. Itu dicatat terpisah sebagai **BUG-24** (D-21); status FIXED di sini hanya berlaku untuk daftar layar di atas.
- Regression test: `apps/mobile/test/v2_text_scale_test.dart`, `pest_scan_page_test.dart`.

## BUG-21 [S2] "Sinkron sekarang" melaporkan sukses padahal gagal/tanpa koneksi
- Area/PB: PB-07 (sinkron) · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026)
- Langkah reproduksi: 1) matikan internet; 2) Menu Lainnya → Sinkron → "Sinkron sekarang".
- Ekspektasi: pesan gagal yang jelas; "terakhir sinkron" tidak berubah.
- Aktual: muncul sukses "Sinkron selesai" walau tak ada data terkirim (antrean kosong / jaringan putus).
- Bukti: `flutter test test/v2_sinkron_feedback_test.dart` ("antrean kosong tidak mengaku 'Sinkron selesai'", "jaringan putus menampilkan gagal, bukan sukses").
- Penyebab (akar): sukses ditentukan hanya oleh `run.remaining == 0`; pada antrean kosong `total == 0` sehingga `remaining == 0` juga.
- Status: **FIXED** — sukses hanya bila ada data terkirim dan `remaining == 0`; antrean kosong → "Tidak ada data untuk disinkronkan."; `sent == 0` → keadaan gagal/offline dan `_doneAt` (jam terakhir sinkron) tidak diubah. Meski aplikasi online-only, umpan balik yang salah tetap bug.
- Regression test: `apps/mobile/test/v2_sinkron_feedback_test.dart`.

## BUG-22 [S2] Riwayat pindaian hama tidak muncul di menu Rawat
- Area/PB: PB-06 (deteksi & rekomendasi) / layar Rawat 9.1 · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026)
- Langkah reproduksi: 1) Rawat → Deteksi hama; 2) foto daun, simpan; 3) keluar dari halaman pindai; 4) buka lagi tab Rawat.
- Ekspektasi: hasil pindai terbaru terlihat di Rawat; riwayat rotasi obat ikut diperbarui setelah simpan.
- Aktual: Rawat hanya menampilkan kartu "tambah pindai"; riwayat rotasi hanya bisa dibuka dari dalam halaman pindai dan tampak basi setelah simpan.
- Bukti: `flutter test test/v2_rawat_pindaian_test.dart` (8 kasus) — 8 lulus setelah perbaikan.
- Penyebab (akar): tab Rawat tidak pernah membaca daftar pindaian; `PestRepository` belum punya `listScans`, dan setelah simpan tidak ada invalidasi data.
- Status: **FIXED** — model `ScanDetection`/`PestScanRecord`/`ScanPage`, `PestRepository.listScans()`, provider `pestScansProvider` (status rekomendasi digabung lewat `scanId`), bagian "Pindaian terbaru" + tombol "Riwayat rotasi" di daftar Rawat, halaman detail pindai baru, dan invalidasi `pestScansProvider`/`pestHistoryProvider` saat kembali dari pindai/rotasi. File: `scan_upload_models.dart`, `pest_repository.dart`, `pest_providers.dart`, `v2_rawat_data.dart`, `v2_pindai_badge.dart`, `v2_rawat_list_page.dart`, `v2_pindai_detail_page.dart`, `v2_rawat_connected.dart`.
- Regression test: `apps/mobile/test/v2_rawat_pindaian_test.dart`.

## BUG-23 [S2] Stok di layar tidak berkurang setelah "Setujui" dengan potong stok
- Area/PB: PB-06 (rekomendasi perawatan) → PB-02 (stok) · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026)
- Langkah reproduksi: 1) buka rekomendasi hama untuk benih "test" (saldo 100); 2) "Setujui" dan pakai potong stok 10; 3) kembali ke Stok.
- Ekspektasi: saldo benih menjadi 90.
- Aktual: saldo tetap 100 sampai aplikasi di-restart; riwayat menampilkan "pakai 10" dan server sudah memotong stok.
- Bukti: `flutter test test/v2_stock_refresh_after_accept_test.dart` (2 kasus) — lulus setelah perbaikan; sebelum perbaikan stok tetap nilai lama.
- Penyebab (akar): kartu rekomendasi tidak menyegarkan `connectedInventoryProvider` setelah penerimaan yang memotong stok, jadi cache inventory di mobile basi (opsi a: mobile tidak me-refresh — D-20).
- Status: **FIXED** — `DecidableRecommendationCard` menjadi `ConsumerWidget`; setelah penerimaan berhasil dengan `material != null` dipanggil `ref.invalidate(connectedInventoryProvider)`. Backend tidak diubah.
- Regression test: `apps/mobile/test/v2_stock_refresh_after_accept_test.dart`.
- Pertanyaan terbuka (D-20): apakah potong stok rekomendasi boleh mengenai jenis selain `obat` (mis. `benih`)? Menunggu PM; belum ada perubahan aturan.

## BUG-24 [S3] Font 200% masih membuat beberapa kartu menimpa/memotong teks (lanjutan BUG-20)
- Area/PB: §5.4 (aksesibilitas/tampilan) · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026)
- Langkah reproduksi: 1) set ukuran font sistem ke 200%; 2) buka Beranda ("Siklus berjalan", kartu "Siap pindah" + kapsul), Tanaman (daftar + kapsul), Akun pegawai → Detail pegawai, Penjualan → Ringkasan penjualan, Tanaman → Meja → Detail meja.
- Ekspektasi: teks membungkus/menyusut di dalam kartu, tidak ada tulisan terpotong atau garis kuning-hitam.
- Aktual: keterangan tahap ke-4 "Siklus berjalan" tak terbaca; kapsul "Siap pindah" terpotong; kapsul status daftar Tanaman meluber; kartu utama Detail pegawai memotong kapsul; label bulan grafik penjualan tidak sejajar dengan batang; label indikator lubang Detail meja bertumpuk.
- Bukti: `flutter test test/v2_text_scale_bug24_test.dart` — 15 kasus merender layar pada `textScaler 2.0`; gagal sebelum perbaikan, lulus sesudahnya. Audit cepat seluruh halaman v2 lain (cuaca, daftar/form pegawai, panen, penjualan, rawat, sinkron, onboarding, detail tanaman) juga bersih.
- Penyebab (akar): pola sama seperti BUG-20 — tinggi tetap (`SizedBox(height: 56/80/88/120/136/164)`, `height: 28`) dan `Row` tanpa `Flexible`/`Wrap` pada teks yang ikut membesar.
- Status: **FIXED** — tinggi tetap diganti tinggi minimum; `Row` teks → `Wrap`/`Flexible`; teks dalam cincin → `FittedBox`; grafik penjualan memisahkan baris label dari batang; grid lubang meja tidak lagi dipaku 294×164; onboarding mengukur tinggi teks dengan `TextPainter`. File: `v2_timeline_step.dart`, `v2_cycle_ring.dart`, `v2_cycle_legend.dart`, `v2_semaian_row.dart`, `v2_semaian_detail_page.dart`, `v2_inventaris_row.dart`, `v2_meja_row.dart`, `v2_meja_detail_cards.dart`, `v2_stock_item.dart`, `v2_badge.dart`, `v2_summary_card.dart`, `v2_akun_profil_card.dart`, `v2_penjualan_chart_card.dart`, `v2_penjualan_info_card.dart`, `v2_rawat_foto_card.dart`, `v2_rawat_konfirmasi_page.dart`, `v2_rawat_obat_page.dart`, `v2_panen_form_page.dart`, `v2_detail_tanaman_page.dart`, `v2_stepper.dart`, `v2_text_field.dart`, `v2_onboarding_page.dart`.
- Regression test: `apps/mobile/test/v2_text_scale_bug24_test.dart`.
- Catatan bukti: perbaikan dibuktikan lewat tes widget; **verifikasi visual ulang di HP asli belum dilakukan** dan menunggu dev FE.

## BUG-25 [S4] Tab Tanam selalu membuka sub-tab "Meja" setelah kartu "Lubang terisi"
- Area/PB: navigasi tab bawah / Beranda → Tanam · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026)
- Langkah reproduksi: 1) di Beranda tekan kartu "Lubang terisi" (membuka Tanam → Meja); 2) pindah ke tab lain; 3) ketuk tab Tanam lagi.
- Ekspektasi: tab Tanam dibuka di sub-tab default "Semaian"; kartu "Lubang terisi" hanya berpengaruh sekali.
- Aktual: sub-tab "Meja" terus dipakai setiap kali tab Tanam dibuka.
- Bukti: `flutter test test/v2_beranda_tanam_segment_reset_test.dart` — gagal pada kode lama ("segmen:0" tidak ditemukan), lulus setelah perbaikan.
- Penyebab (akar): `_tanamSegmen` di `v2_beranda_page.dart` di-set 1 oleh kartu dan tidak pernah dikembalikan ke 0.
- Status: **FIXED** — setiap ketukan langsung ke tab Tanam mereset `_tanamSegmen = 0` (pola sama dengan reset saringan tab Stok, BUG-06); pergantian peran juga mereset (D-22).
- Regression test: `apps/mobile/test/v2_beranda_tanam_segment_reset_test.dart`.

## BUG-26 [S3] Kartu cuaca Beranda membuka halaman contoh, bukan cuaca nyata
- Area/PB: Beranda → kartu Cuaca · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026)
- Langkah reproduksi: 1) buka Beranda saat tersambung; 2) tekan kartu cuaca (atau hero/detail siklus → pintu cuaca).
- Ekspektasi: semua pintu masuk membuka halaman Cuaca nyata (`V2CuacaConnectedPage`) dengan prakiraan BMKG terbaru dan lokasi sama.
- Aktual: kartu cuaca di Beranda membuka halaman contoh desain (`V2CuacaPage`), sehingga tanggal prakiraan tertinggal (16/17/18 Nov) dan lokasinya beda dari pintu lain.
- Bukti: `flutter test test/v2_cuaca_entry_consistency_test.dart` — 3 kasus; 2 gagal pada kode lama, lulus setelah perbaikan.
- Penyebab (akar): `v2_beranda_page.dart` kartu cuaca memakai `onTap` tetap ke `V2CuacaPage.route()` dan mengabaikan `widget.onOpenWeather`.
- Status: **FIXED** — kartu cuaca memakai `widget.onOpenWeather ?? V2CuacaPage.route()` seperti hero/detail siklus. File: `v2_beranda_page.dart`; `weather_viewmodel.dart` (jam pembaruan lewat `weatherClockProvider`).
- Regression test: `apps/mobile/test/v2_cuaca_entry_consistency_test.dart`.
- Catatan bukti: perbaikan dibuktikan lewat tes widget; **verifikasi ulang di HP asli menunggu dev FE**.

## BUG-27 [S2] Tanggal bawaan form bisa tertinggal (satu akar tanggal)
- Area/PB: §5.4 (tanggal catat) · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026)
- Langkah reproduksi: 1) buka form "Catat rusak" dari alur Tanam; 2) buka form "Catat penjualan" baru dari daftar; 3) perhatikan tanggal bawaan.
- Ekspektasi: tanggal bawaan = hari ini menurut zona WIB (`jakartaToday()`), termasuk sekitar tengah malam.
- Aktual: sebagian pintu form memakai tanggal tetap sehingga catatan bisa tersimpan dengan tanggal yang salah.
- Bukti: `flutter test test/v2_catat_rusak_date_test.dart` — 6 kasus (termasuk batas tengah malam WIB); 3 gagal pada kode lama, lulus setelah perbaikan.
- Penyebab (akar): tanggal form di-hardcode alih-alih diturunkan dari jam yang bisa disuntik. Audit: pemanggil nyata (`v2_semaian_connected.dart`, `v2_panen_connected.dart`) sudah memakai `jakartaToday()`; sisa `DateTime(2026,11,15)` di `v2_pindah_meja_page.dart:97` dan `v2_panen_form_page.dart:159` adalah galeri/contoh (`v2PanenHariIni`), bukan alur nyata.
- Status: **FIXED** — `v2_tanaman_rusak_page.dart` memakai clock yang bisa disuntik (`initial ?? jakartaToday(clock())`); `v2_penjualan_form_page.dart` menerima `initialDate` dan `v2_penjualan_list_page.dart` mengirim `jakartaToday()` hanya saat membuat penjualan baru.
- Regression test: `apps/mobile/test/v2_catat_rusak_date_test.dart`.
- Catatan bukti: perbaikan dibuktikan lewat tes widget; **verifikasi ulang di HP asli menunggu dev FE**.

## BUG-28 [S3] Tombol halaman sukses "Pindah ke meja" tidak bisa ditekan
- Area/PB: Tanam → Semaian → Pindah ke meja (5.18/5.22) · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026)
- Langkah reproduksi: 1) pindahkan semaian ke meja lewat alur nyata; 2) di halaman sukses tekan "Lihat meja" / "Ke daftar semaian" / "Pindahkan sisa".
- Ekspektasi: tiap tombol menutup halaman sukses dan menjalankan aksinya (buka detail meja tujuan, kembali ke daftar semaian, atau lanjut memindah sisa).
- Aktual: tombol tampak normal tetapi ditekan tidak terjadi apa-apa.
- Bukti: `flutter test test/v2_pindah_meja_success_test.dart` — 3 kasus; ketiganya gagal pada kode lama (tombol mati), lulus setelah perbaikan.
- Penyebab (akar): `v2_pindah_meja_page.dart` `_pindahkan` membuka `V2PindahMejaResultPage` tanpa `onPrimary`/`onSecondary`, sehingga `V2Button` dibuat nonaktif.
- Status: **FIXED** — halaman sukses mengembalikan `V2PindahMejaAksi` (selesai/lihatMeja/keDaftarSemaian/pindahkanSisa); `v2_semaian_connected.dart` menindaklanjuti (buka detail meja lewat `V2MejaConnectedDetailPage`, kembali ke daftar, atau buka lagi form untuk sisa). File: `v2_pindah_meja_page.dart`, `v2_semaian_data.dart`, `v2_semaian_connected.dart`.
- Regression test: `apps/mobile/test/v2_pindah_meja_success_test.dart`.
- Catatan bukti: perbaikan dibuktikan lewat tes widget; **verifikasi ulang di HP asli menunggu dev FE**.
- Update 24 Nov 2026 (uji manual dev FE): tombol **sudah hidup** (PASS untuk tombolnya), **tetapi** data yang ditampilkan setelahnya basi — dicatat terpisah sebagai **BUG-34** (bukan membuka ulang BUG-28).

## BUG-29 [S3] Form "Pindah ke meja": jumlah besar susah diisi; meja penuh bisa jadi bawaan
- Area/PB: Tanam → Semaian → Pindah ke meja (5.17) · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026)
- Langkah reproduksi: 1) buka form pindah dengan jumlah besar (mis. 200); 2) coba ubah jumlah; 3) perhatikan pilihan meja bawaan saat meja pertama penuh/perawatan.
- Ekspektasi: jumlah besar bisa dicapai tanpa menekan plus satu-satu (tahan tombol atau ketik angka); bawaan memilih meja yang tersedia, bukan meja penuh.
- Aktual: hanya bisa satu langkah per ketukan; meja penuh bisa terpilih sebagai bawaan.
- Bukti: `flutter test test/v2_pindah_meja_jumlah_test.dart` — 3 kasus (tahan plus, ketik angka, bawaan meja); ketiganya gagal pada simulasi kode lama, lulus setelah perbaikan.
- Penyebab (akar): `V2Stepper`/`V2QtyField` hanya punya `onTap` satu langkah dan pil angka tidak bisa diketik; `_mejaIndex` awal tidak menyaring meja `tersedia`.
- Status: **FIXED** — tombol minus/plus bisa ditahan untuk berulang; angka bisa diketuk lalu diketik (dialog); meja tersedia pertama dipilih otomatis bila pilihan awal penuh/perawatan. **Urutan daftar meja tidak diubah** (menunggu PM). File: `v2_stepper.dart`, `v2_pindah_meja_page.dart`.
- Regression test: `apps/mobile/test/v2_pindah_meja_jumlah_test.dart`.
- Pertanyaan terbuka: apakah urutan daftar meja perlu diubah (mis. meja paling kosong di atas)? **PM menjawab BOLEH (24 Nov 2026)** → dikerjakan sebagai fitur tambahan (Fitur-2, D-27).
- Catatan bukti: perbaikan dibuktikan lewat tes widget; **verifikasi ulang di HP asli menunggu dev FE**.
- Update 24 Nov 2026 (uji manual dev FE): **PASS** — tahan plus/minus, ketik angka, dan bawaan meja berfungsi.

## BUG-30 [S3] Notifikasi tidak bisa ditekan dan tanpa status dibaca
- Area/PB: Beranda → bel Notifikasi (2.4) · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026)
- Langkah reproduksi: 1) buka Beranda; 2) tekan bel; 3) coba ketuk satu baris notifikasi, lalu tombol "Tandai semua dibaca".
- Ekspektasi: baris bisa ditekan → menandai sudah dibaca dan membuka tujuan relevan (Semaian/Stok); ada penanda "belum dibaca" yang bukan sekadar warna; "Tandai semua dibaca" nonaktif saat tidak ada yang belum dibaca.
- Aktual: baris tidak bereaksi, tidak ada status dibaca, dan tombol tandai-semuanya selalu aktif.
- Bukti: `flutter test test/v2_notifikasi_bug30_test.dart` — 7 kasus (ketuk baris, penanda, tandai semua, Beranda pindah tab, id stabil, simpanan per pengguna); 5 gagal pada simulasi kode lama, lulus setelah perbaikan.
- Penyebab (akar): `V2Notification` tidak punya `id`/`target`/`read`; `V2ListItem` diberi `onTap` null sehingga tidak ada jalur masuk.
- Status: **FIXED** (D-23) — `V2Notification` punya id stabil + tujuan; baris ditekan → tandai dibaca + tutup halaman dengan tujuan; Beranda membuka tab yang relevan; penanda "belum dibaca" berupa titik (bentuk, bukan warna) + label semantik; "Tandai semua dibaca" nonaktif bila bersih; status disimpan lokal per pengguna (`notification_read.db`). File: `v2_notifications_page.dart`, `v2_beranda_page.dart`, `v2_beranda_connected_page.dart`, `v2_beranda_notifikasi.dart`, `data/services/notification_read_store.dart`, `viewmodels/v2_notification_read.dart`.
- Regression test: `apps/mobile/test/v2_notifikasi_bug30_test.dart`.
- Catatan bukti: perbaikan dibuktikan lewat tes widget; **verifikasi ulang di HP asli menunggu dev FE**.

## BUG-31 [S3] Ringkasan penjualan: label bulan tidak sejajar dengan grafik
- Area/PB: Penjualan → Ringkasan penjualan (grafik) · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026), tercatat ulang dari BUG-24
- Langkah reproduksi: 1) buka Ringkasan penjualan; 2) lihat label bulan di bawah batang (skala 1.0 dan 2.0).
- Ekspektasi: label bulan sejajar dengan batangnya, atau tidak dipaksa sejajar.
- Aktual: setelah perbaikan sesi 3 (FittedBox), label tetap **tidak sejajar** dengan grafik menurut dev FE.
- Bukti: `flutter test test/v2_penjualan_chart_align_test.dart` (sesi 3) — menyejajarkan label; **tidak cukup** menurut uji manual dev FE. Diperbaiki ulang sesi 4 (commit `eedbb43`) dan **PASS di HP** (diuji manual dev FE, 25 Nov 2026).
- Penyebab (akar): menyejajarkan label di bawah batang rapuh pada lebar/skala berbeda.
- Status: **FIXED** — keputusan dev FE: tidak lagi menyejajarkan label; teks ringkasan per bulan jadi **daftar ke bawah** (nama bulan kiri, nilai kanan rata) dan label bulan yang tidak sejajar dihapus. File: `v2_penjualan_page.dart` / komponen ringkasan penjualan (D-25).
- Regression test: `apps/mobile/test/v2_penjualan_chart_align_test.dart` (dibuka ulang untuk daftar per bulan).

## BUG-32 [S3] Filter riwayat rotasi rapat dan daftar terlalu panjang
- Area/PB: Rawat/Tanaman → Riwayat rotasi (pest) · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026)
- Langkah reproduksi: 1) buka Riwayat rotasi; 2) perhatikan baris filter; 3) set font 200% dan buka daftar panjang.
- Ekspektasi: filter punya jarak yang lega dan tidak meluber; entri panjang bisa dilipat supaya daftar tidak terlalu panjang; kontrol tetap ≥ 48dp di skala besar.
- Aktual: filter terlalu rapat/meluber pada skala 2.0 dan daftar terasa sangat panjang.
- Bukti: `flutter test test/v2_rotation_history_bug32_test.dart` — 2 kasus (termasuk skala 2.0); gagal pada kode lama saat `collapsible` dihapus, lulus setelah perbaikan.
- Penyebab (akar): baris filter memakai `Row` tanpa pembungkusan; entri tidak punya mode ringkas; chip punya tinggi tetap sehingga kena overflow.
- Status: **FIXED** — filter dibungkus `Wrap` dengan jarak token; entri riwayat bisa dilipat (ringkasan ↔ rincian, tombol ≥ 48 dengan label teks+ikon); chip diberi `minHeight` 48 dan label `Flexible`. File: `rotation_history_page.dart`, `recommendation_card.dart`, `decision_sheets.dart`, `v2_chip.dart`.
- Regression test: `apps/mobile/test/v2_rotation_history_bug32_test.dart`, `apps/mobile/test/pest_widgets_test.dart`.
- Catatan bukti: perbaikan dibuktikan lewat tes widget; **verifikasi ulang di HP asli menunggu dev FE**.

## BUG-33 [S3] Pemilih tanaman "Catat panen" tidak bisa dipakai saat batch berulang
- Area/PB: Tanam → Panen → Catat panen · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026) + audit pintu masuk
- Langkah reproduksi: 1) buka Catat panen; 2) pilih tanaman yang punya dua batch/semaian dengan nama sama; 3) coba pilih yang kedua.
- Ekspektasi: semua batch bisa dipilih (termasuk nama yang sama), pilihan jelas mana batch mana.
- Aktual: pilihan digabung/dedup berdasarkan nama sehingga batch kedua tidak bisa dipilih.
- Bukti: `flutter test test/v2_panen_picker_bug33_test.dart` — 6 kasus; gagal pada kode lama (API pemilih belum ada), lulus setelah perbaikan.
- Penyebab (akar): pemilih memakai nama tanaman sebagai kunci sehingga batch bernama sama saling menimpa; ringkasan pilihan tidak cukup membedakan batch.
- Status: **FIXED** — `V2PanenEstimasi` diberi kunci stabil + label rincian (batch/meja/tanggal); `v2DaftarEstimasiPanen()` menyusun pilihan ganda tanpa dedup nama; sheet pemilih baru `v2_panen_tanaman_sheet.dart` (bisa cari & pilih banyak), `V2BottomSheet.flexible` agar sheet tinggi ikut konten. File: `v2_panen_data.dart`, `v2_panen_connected.dart`, `v2_panen_form_page.dart`, `v2_panen_tanaman_sheet.dart`, `v2_bottom_sheet.dart`.
- Regression test: `apps/mobile/test/v2_panen_picker_bug33_test.dart`.
- Catatan bukti: perbaikan dibuktikan lewat tes widget; **verifikasi ulang di HP asli menunggu dev FE**.

## BUG-34 [S3] Data meja basi setelah "Pindah ke meja"
- Area/PB: Tanam → Semaian → Pindah ke meja · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026), lanjutan BUG-28
- Langkah reproduksi: 1) pindahkan semaian ke meja lewat alur nyata; 2) kembali ke daftar meja/detail meja; 3) bandingkan jumlah lubang terisi & isi meja dengan hasil pindah.
- Ekspektasi: daftar/detail meja menampilkan angka terbaru setelah pindah.
- Aktual: meja tujuan masih menampilkan angka lama (butuh muat ulang manual).
- Bukti: `flutter test test/v2_pindah_stale_bug34_test.dart` — 2 kasus; gagal pada kode lama (helper invalidasi belum ada), lulus setelah perbaikan.
- Penyebab (akar): setelah tulis pindah, provider meja tidak di-invalidate; satu jalur (`_bukaMeja`) juga tidak menyegarkan.
- Status: **FIXED** — helper `v2SegarkanSetelahTulis(ref, {tableIds})` di `v2_meja_connected.dart` meng-invalidate provider daftar/detail meja tujuan; dipakai di `_kirimPindah`/`_pindah`/`_bukaMeja` (`v2_semaian_connected.dart`). File: `v2_meja_connected.dart`, `v2_semaian_connected.dart`, `v2_pindah_meja_page.dart`.
- Regression test: `apps/mobile/test/v2_pindah_stale_bug34_test.dart`.
- Catatan bukti: perbaikan dibuktikan lewat tes widget; **verifikasi ulang di HP asli menunggu dev FE**.

## BUG-35 [S3] "Tambah tanaman" di detail meja tidak membuka alur yang benar
- Area/PB: Tanam → Meja → detail meja → "Tambah tanaman" · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026)
- Langkah reproduksi: 1) buka detail meja; 2) tekan "Tambah tanaman"; 3) perhatikan alur & data yang tersimpan.
- Ekspektasi: menambah tanaman memakai alur "Pindah ke meja" (meja ini terpilih), jumlah wajar, tersimpan konsisten.
- Aktual: alur lama mengisi data langsung tanpa lewat form pindah, sehingga meja/ jumlah/validasi tidak konsisten.
- Bukti: `flutter test test/v2_tambah_tanaman_bug35_test.dart` — 2 kasus; gagal pada kode lama (`showResultPage` belum ada), lulus setelah perbaikan.
- Penyebab (akar): `_tambahTanaman` memakai jalur isi-langsung, bukan membuka form pindah.
- Status: **FIXED** (D-25) — `_tambahTanaman` memilih semaian lalu membuka `V2PindahMejaFormPage` dengan default (meja terpilih = meja itu, semaian terpilih, jumlah = min(sisa bibit, sisa kapasitas meja)); `showResultPage:false` + `onPindahkan` supaya tetap di detail meja. File: `v2_meja_connected.dart`, `v2_pindah_meja_page.dart`.
- Regression test: `apps/mobile/test/v2_tambah_tanaman_bug35_test.dart`, `apps/mobile/test/v2_pindah_meja_success_test.dart`.
- Catatan bukti: perbaikan dibuktikan lewat tes widget; **verifikasi ulang di HP asli menunggu dev FE**.

## BUG-36 [S3] Data tanaman tersambung memaku tanggal contoh (perkiraan panen salah)
- Area/PB: Tanam → Meja → detail tanaman tersambung · Ditemukan lewat: audit pintu masuk (review kode)
- Langkah reproduksi: 1) buka tanaman yang tersambung ke data nyata; 2) lihat HST & perkiraan panen.
- Ekspektasi: HST dihitung dari tanggal tanam nyata; perkiraan panen ikut tanggal pindah nyata.
- Aktual: sebagian perhitungan memakai acuan galeri 15 Nov 2026, sehingga HST/perkiraan panen tidak sesuai data nyata.
- Bukti: `flutter test test/v2_tanaman_hari_ini_bug36_test.dart` — 3 kasus; gagal pada kode lama (API `hariIni` belum ada), lulus setelah perbaikan.
- Penyebab (akar): item tanaman tidak punya acuan "hari ini" yang bisa disuntik; halaman sukses pindah menampilkan tanggal contoh ("30 Des").
- Status: **FIXED** — `V2TanamanItem.hariIni` (null = acuan galeri 15 Nov 2026) untuk `hst`/`hariMenujuPanen`; `v2MejaItemFromRecord(hariIni:, ...)` bawaan `jakartaToday()`; perkiraan panen halaman sukses pindah pakai tanggal pindah nyata. File: `v2_meja_data.dart`, `v2_meja_connected.dart`, `v2_pindah_meja_page.dart`.
- Regression test: `apps/mobile/test/v2_tanaman_hari_ini_bug36_test.dart`.
- Catatan bukti: perbaikan dibuktikan lewat tes widget; **verifikasi ulang di HP asli menunggu dev FE**.

## BUG-37 [S3] Jumlah besar tidak bisa diketik di semua pemakai `V2QtyField`
- Area/PB: PB-08/09/10 (semua form yang memakai pengatur jumlah) · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026), perluasan BUG-29
- Langkah reproduksi: 1) buka Catat stok / Tambah semaian / Catat rusak / Konfirmasi rawat / Catat panen; 2) coba ketik angka besar langsung ke pil angka.
- Ekspektasi: angka bisa diketuk lalu diketik di semua form; nilai di bawah minimum tidak diterima.
- Aktual (dulu): hanya sebagian form yang bisa diketik; sisanya maju satu-satu.
- Bukti: `flutter test test/v2_qty_ketik_bug37_test.dart` — 6 kasus (termasuk skala teks 2.0); gagal pada kode lama (belum ada `onChanged`), lulus setelah perbaikan.
- Penyebab (akar): BUG-29 hanya memperbaiki sebagian pemakai `V2QtyField`; sisanya tidak mengirim `onChanged` sehingga edit ketik tidak tersimpan.
- Status: **FIXED** — `onChanged` ditambahkan di catat stok, semaian, rusak, rawat konfirmasi, dan panen (pindah meja sudah); setter tetap menjaga batas minimum. File: `v2_panen_form_page.dart`, `v2_semaian_form_page.dart`, `v2_tanaman_rusak_page.dart`, `v2_stepper.dart` (komponen bersama).
- Regression test: `apps/mobile/test/v2_qty_ketik_bug37_test.dart`.
- Catatan bukti: perbaikan dibuktikan lewat tes widget; **verifikasi ulang di HP asli menunggu dev FE**.

## BUG-38 [S3] "Tambah bahan" di form semaian hanya mengganti baris, tidak menambah
- Area/PB: Tanam → Semaian → Tambah semaian (bahan) · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026) + audit kontrak server
- Langkah reproduksi: 1) buka form Tambah semaian; 2) isi satu bahan; 3) tekan "Tambah bahan".
- Ekspektasi: muncul baris bahan kedua (dan seterusnya) yang ikut tersimpan.
- Aktual: tombol mengganti bahan yang sudah ada, tidak pernah ada baris kedua.
- Bukti: `flutter test test/v2_semaian_bahan_bug38_test.dart` — 2 kasus; gagal pada kode lama (model `V2SemaianBahanPakai`/`SowingMaterialDraft` belum ada), lulus setelah perbaikan.
- Penyebab (akar): model form hanya punya satu slot bahan; penyimpanan hanya mengirim satu bahan.
- Status: **FIXED** (D-26) — audit kontrak server selesai: `POST /penyemaian` menerima `materials[]` (minimal satu, tiap baris `id_inventaris` unik), **backend tidak diubah**. Form kini multi-baris (`V2SemaianBahanPakai`, `V2SemaianItem.bahanList`): pilih/hapus baris, bahan terpakai tidak ditawarkan lagi, galat stok per baris; simpan mengirim semua `materials[]` (`SowingDraft.materials` + `SowingMaterialDraft`). File: `v2_semaian_data.dart`, `v2_semaian_form_page.dart`, `sowing_draft.dart`.
- Regression test: `apps/mobile/test/v2_semaian_bahan_bug38_test.dart`.
- Catatan bukti: perbaikan dibuktikan lewat tes widget; **verifikasi ulang di HP asli menunggu dev FE**.

## BUG-39 [S2] Detail meja dari halaman sukses "Pindah ke meja" bisa kosong/basi
- Area/PB: 06 Meja Tanam — Detail meja · Ditemukan lewat: uji manual dev FE (HP asli, 25 Nov 2026) + audit pintu masuk
- Langkah reproduksi: 1) pindahkan semaian ke meja dari alur semaian; 2) di halaman sukses tekan "Lihat meja"; 3) bandingkan kapasitas/tanaman dengan daftar Meja.
- Ekspektasi: Detail meja menampilkan data terbaru dari server.
- Aktual: halaman memegang salinan objek dari halaman sebelumnya, jadi kapasitas/tanaman bisa kosong atau basi.
- Bukti: `flutter test test/v2_meja_pintu_bersama_bug39_test.dart` — gagal di kode lama (parameter `tableId` belum ada; halaman tidak pernah membaca ulang provider).
- Penyebab (akar): dua jalur pembuka (daftar Meja dan halaman sukses pindah) mengirim snapshot berbeda; Detail meja hanya menyegarkan saat menulis.
- Status: **FIXED di kode, belum diuji ulang di HP** — satu pintu masuk `bukaDetailMeja(navigator, tableId, item?)`; `V2MejaConnectedDetailPage` menerima `tableId` dan selalu menghitung ulang dari provider (kapasitas, tanaman, kerusakan); `item` hanya gambar awal. File: `v2_meja_connected.dart`, `v2_semaian_connected.dart`.
- Regression test: `apps/mobile/test/v2_meja_pintu_bersama_bug39_test.dart`.

## BUG-40 [S2] Semaian siap pindah tidak muncul di pemilih "Tambah tanaman"
- Area/PB: 06 Meja Tanam — Tambah tanaman · Ditemukan lewat: uji manual dev FE (25 Nov 2026)
- Langkah reproduksi: 1) buat semaian HSS ≥ 15 yang belum ditandai `siap_pindah` oleh server; 2) buka Detail meja → Tambah tanaman.
- Ekspektasi: semaian HSS 15+ ditawarkan (sama seperti daftar Semaian).
- Aktual: pemilih kosong karena memakai `SowingRecord.canTransfer` yang menuntut `siap_pindah` dari server.
- Bukti: `flutter test test/v2_meja_pemilih_semaian_bug40_41_test.dart` — kasus BUG-40 gagal di kode lama (pemilih kosong).
- Penyebab (akar): dua aturan kesiapan berbeda antara daftar Semaian (`V2SemaianItem.siapPindah`, HSS ≥ 15) dan pemilih meja (`canTransfer`).
- Status: **FIXED di kode, belum diuji ulang di HP** — pemilih memakai `v2SemaianItemFromRecord(...).siapPindah`, satu aturan dengan daftar Semaian. File: `v2_meja_connected.dart`.
- Regression test: `apps/mobile/test/v2_meja_pemilih_semaian_bug40_41_test.dart`.

## BUG-41 [S3] "Lihat semaian" di pemilih justru kembali ke Detail meja
- Area/PB: 06 Meja Tanam — Pilih semaian · Ditemukan lewat: uji manual dev FE (25 Nov 2026)
- Langkah reproduksi: 1) buka Tambah tanaman saat belum ada semaian siap; 2) tekan "Lihat semaian".
- Ekspektasi: daftar Semaian terbuka.
- Aktual: pemilih tertutup dan kembali ke Detail meja.
- Bukti: `flutter test test/v2_meja_pemilih_semaian_bug40_41_test.dart` — kasus BUG-41 gagal di kode lama (daftar semaian tidak terbuka).
- Penyebab (akar): `V2PilihSemaianPage` memakai `Navigator.pop` bawaan karena pemanggil tidak mengirim `onLihatSemaian`.
- Status: **FIXED di kode, belum diuji ulang di HP** — pemanggil mengirim callback: tutup pemilih lalu buka `V2SemaianConnectedListPage.route()`. File: `v2_meja_connected.dart`, `v2_semaian_connected.dart`.
- Regression test: `apps/mobile/test/v2_meja_pemilih_semaian_bug40_41_test.dart`.

## BUG-42 [S2] "Catat penjualan" dari Detail panen memakai tanggal contoh dan tidak menyimpan
- Area/PB: 07 Panen — Detail panen · Ditemukan lewat: uji manual dev FE (25 Nov 2026)
- Langkah reproduksi: 1) buka Detail panen tersambung; 2) tekan "Catat penjualan"; 3) isi lalu Simpan.
- Ekspektasi: tanggal awal hari ini (WIB) dan penjualan tersimpan ke server.
- Aktual: tanggal awal 15 Nov (data contoh) dan form berjalan mode pratinjau, jadi Simpan hanya menutup form.
- Bukti: `flutter test test/v2_panen_jual_bug42_43_test.dart` — kasus BUG-42 gagal di kode lama (tanggal 15 Nov, `drafts` kosong).
- Penyebab (akar): `V2PanenConnectedDetailPage` hanya mengirim `onUbah`; tombol "Catat penjualan" memakai jalur contoh tanpa `store`/`initialDate`.
- Status: **FIXED di kode, belum diuji ulang di HP** — `V2PanenDetailPage` menerima `onCatatPenjualan`; halaman tersambung mengirim `store: v2PenjualanStoreProvider` dan `initialDate: jakartaToday()`. File: `v2_panen_detail_page.dart`, `v2_panen_connected.dart`.
- Regression test: `apps/mobile/test/v2_panen_jual_bug42_43_test.dart`.

## BUG-43 [S2] Status dan sisa panen tidak berubah setelah penjualan dicatat
- Area/PB: 07 Panen — Detail panen · Ditemukan lewat: uji manual dev FE (25 Nov 2026)
- Langkah reproduksi: 1) catat penjualan untuk satu panen; 2) buka kembali Detail panen.
- Ekspektasi: angka "Terjual" bertambah dan "Sisa" berkurang.
- Aktual: selalu "Terjual 0 kg" karena `terjual` tidak pernah diisi.
- Bukti: `flutter test test/v2_panen_jual_bug42_43_test.dart` — kasus BUG-43 gagal di kode lama (menampilkan "Terjual 0 kg. Sisa 100 kg.").
- Penyebab (akar): endpoint panen tidak mengembalikan angka terjual dan mapper tidak menghitungnya dari batch penjualan.
- Status: **FIXED di kode, belum diuji ulang di HP** — `terjual` dihitung dari `BatchPanen.stokTersedia` (`berat layak − stok tersedia`) oleh `v2TerjualDariBatch`, reaktif ke `penjualanViewModelProvider`. Backend tidak diubah. File: `v2_panen_connected.dart`.
- Regression test: `apps/mobile/test/v2_panen_jual_bug42_43_test.dart`.

## BUG-44 [S3] "Stok terpakai" di Detail semaian hanya menyebut satu bahan
- Area/PB: 05 Semaian — Detail semaian · Ditemukan lewat: uji manual dev FE (25 Nov 2026)
- Langkah reproduksi: 1) buat semaian dengan dua bahan (BUG-38); 2) buka Detail semaian.
- Ekspektasi: semua bahan tampil, mis. "Benih Romaine 2 pak, Nutrisi AB Mix 1 liter".
- Aktual: hanya bahan pertama yang tampil.
- Bukti: `flutter test test/v2_semaian_stok_bug44_test.dart` — gagal di kode lama (`bahanList` selalu null).
- Penyebab (akar): `v2SemaianItemFromRecord` hanya membaca `materials.first`.
- Status: **FIXED di kode, belum diuji ulang di HP** — semua `record.materials` dipetakan ke `bahanList` (nama dari inventaris). File: `v2_semaian_connected.dart`.
- Regression test: `apps/mobile/test/v2_semaian_stok_bug44_test.dart`.

## BUG-45 [S3] Tombol simpan tidak punya keadaan loading yang seragam
- Area/PB: semua layar dengan simpan/aksi tulis · Ditemukan lewat: audit UI (25 Nov 2026)
- Langkah reproduksi: 1) jalankan simpan yang butuh jaringan; 2) perhatikan tombol.
- Ekspektasi: tombol menampilkan spinner dan tidak bisa ditekan ulang selama proses.
- Aktual: sebagian layar menulis ternary `V2ButtonState.loading` sendiri, sebagian lagi tidak menampilkan proses.
- Bukti: `flutter test test/v2_button_loading_bug45_test.dart` — gagal di kode lama (parameter `loading` belum ada).
- Penyebab (akar): `V2Button` hanya punya enum `state`; tidak ada properti ringkas untuk keadaan menyimpan.
- Status: **FIXED di kode, belum diuji ulang di HP** — `V2Button(loading: true)` menampilkan spinner dan memblokir ketukan; layar login, karyawan (form/detail), penjualan (form/detail) memakai properti itu. File: `v2_button.dart` + 5 layar.
- Regression test: `apps/mobile/test/v2_button_loading_bug45_test.dart`.

## BUG-46 [S3] Stok obat tidak muncul di lembar terima rekomendasi (Fitur-3)
- Area/PB: 08 Rawat — Riwayat rotasi / lembar terima (PB-06) · Ditemukan lewat: uji manual dev FE (25 Nov 2026)
- Langkah reproduksi: 1) terima rekomendasi hama; 2) buka pilihan bahan.
- Ekspektasi: barang obat (mis. Abamectin) dan nutrisi bisa dipilih.
- Aktual: obat tidak muncul; hanya jenis yang namanya persis "nutrisi"/"obat".
- Bukti: `flutter test test/v2_potong_stok_obat_bug46_test.dart` — gagal di kode lama (jenis "Obat & Pestisida" tidak cocok).
- Penyebab (akar): data nyata memakai nama jenis "Obat & Pestisida" (seed backend), sedangkan pencocokan lama memakai nama persis.
- Status: **FIXED di kode, belum diuji ulang di HP** (D-31) — barang dengan `id_obat` dikenali lewat pengenal stabil; nama jenis dicocokkan per kata kunci (nutrisi/obat/pestisida). Backend tidak diubah. File: `decision_sheets.dart`.
- Regression test: `apps/mobile/test/v2_potong_stok_obat_bug46_test.dart`.

## BUG-47 [S3] Catatan tanaman bisa diubah tetapi tidak pernah tampil di Detail tanaman
- Area/PB: 06 Meja Tanam — Detail tanaman (6.21/6.22) · Ditemukan lewat: uji manual dev FE (25 Nov 2026)
- Langkah reproduksi: 1) buka Detail tanaman; 2) tekan "Ubah" dan isi catatan; 3) simpan.
- Ekspektasi: catatan tampil di kartu info dan tersimpan ke batch pemindahan.
- Aktual: simpan berhasil, tetapi catatan tidak terlihat di halaman.
- Bukti: `flutter test test/v2_detail_tanaman_catatan_bug47_test.dart` — gagal di kode lama (teks "Catatan" tidak ditemukan).
- Penyebab (akar): kartu info hanya menampilkan "Tanaman aktif" dan "Pindah". Server sudah punya kolom `keterangan` di `pemindahan`, jadi backend tidak perlu diubah.
- Status: **FIXED di kode, belum diuji ulang di HP** — kartu info menampilkan baris "Catatan" bila terisi; data sudah dipetakan dari `TransferRecord.note`. File: `v2_detail_tanaman_page.dart`.
- Regression test: `apps/mobile/test/v2_detail_tanaman_catatan_bug47_test.dart`.

---

## BUG-48 [S2] Nonaktifkan akun gagal di layar padahal server sudah menyimpan (204 tanpa body)
- Area/PB: 03 Akun — pegawai (3.16/3.17) · Ditemukan lewat: QA manual Sesi 6 (25 Nov 2026, K-04)
- Langkah reproduksi: 1) login sebagai petani; 2) Akun pegawai → pilih pegawai → Nonaktifkan; 3) lihat pesan dan daftar.
- Ekspektasi: akun nonaktif, daftar ikut berubah, tanpa pesan galat.
- Aktual: pesan "Format data tidak sesuai"; akun tetap tampak aktif di daftar, padahal `GET /employees/:id` menunjukkan `status_aktif: 0`.
- Bukti: backend lokal menjawab `POST /api/v1/employees/2/deactivate` → **204 No Content tanpa body**; `ApiClient._request` melempar `FormatException('Respons layanan tidak valid.')` untuk body kosong. Tes baru di `test/api_client_test.dart` gagal di kode lama dengan galat yang sama.
- Penyebab (akar): respons 2xx tanpa body dianggap format salah; `deactivate`, `activate`, dan `logout` memang 204.
- Status: **FIXED di kode, belum diuji ulang di HP** — `_request` mengembalikan map kosong untuk 204/body kosong pada status sukses. File: `lib/data/services/api_client.dart`.
- Regression test: `apps/mobile/test/api_client_test.dart` (`empty 204 response is accepted`).

## BUG-49 [S3] Tombol "Tambah barang" menunggu jaringan sebelum membuka form
- Area/PB: 04 Inventaris — Stok · Ditemukan lewat: QA manual Sesi 6 (25 Nov 2026, K-07)
- Langkah reproduksi: 1) buka tab Stok; 2) tekan "Tambah barang".
- Ekspektasi: form 4.10 langsung terbuka.
- Aktual: terasa jeda karena `_tambah` menunggu `inventoryMedicinesProvider` (permintaan jaringan) lebih dulu; kategori baru dimuat setelah form ditutup.
- Bukti: `test/v2_inventaris_tambah_prasyarat_test.dart` — di kode lama tidak ada permintaan `/jenis-inventaris` atau `/obat` sebelum tombol ditekan.
- Penyebab (akar): daftar pendukung dimuat saat dibutuhkan, bukan saat tab dibuka.
- Status: **FIXED di kode, belum diuji ulang di HP** — kategori & obat dihangatkan sejak tab dibuka (`ref.watch`), lalu dibaca dari cache tanpa menunggu jaringan. File: `v2_inventaris_connected.dart`.
- Regression test: `apps/mobile/test/v2_inventaris_tambah_prasyarat_test.dart`.

## BUG-50 [S2] "Kategori barang belum tersedia" baru muncul setelah form stok diisi penuh
- Area/PB: 04 Inventaris — Stok (4.10/4.11) · Ditemukan lewat: QA manual Sesi 6 (25 Nov 2026, K-08)
- Langkah reproduksi: 1) Tambah barang → isi form → Simpan; 2) amati pesan.
- Ekspektasi: bila server memang tak punya kategori aktif, beri tahu sebelum form dibuka; bila gagal jaringan, bedakan pesannya.
- Aktual: pesan generik baru muncul setelah isian penuh dan form ditutup; kategori kosong dan gangguan jaringan memakai pesan yang sama.
- Bukti: backend lokal + seed mengembalikan **4 kategori aktif** (`Benih`, `Nutrisi`, `Obat & Pestisida`, `Perlengkapan`) dan `POST /inventaris` **201**; jadi pesan di sesi QA menandakan jalur prasyarat/jaringan, bukan kontrak yang tak didukung.
- Penyebab (akar): kategori diperiksa setelah form selesai; tidak ada pembeda "daftar kosong" vs "gagal memuat".
- Status: **FIXED di kode, belum diuji ulang di HP** — kategori diperiksa sebelum form dibuka; pesan kosong (`v2KategoriKosongPesan`) dan gagal-muat dibedakan. File: `v2_inventaris_connected.dart`.
- Regression test: `apps/mobile/test/v2_inventaris_tambah_prasyarat_test.dart`.

## BUG-51 [S3] Kode meja duplikat baru ditolak server setelah form ditutup, isian hilang
- Area/PB: 06 Meja Tanam — Tambah meja (6.6/6.7) · Ditemukan lewat: QA manual Sesi 6 (25 Nov 2026, K-14)
- Langkah reproduksi: 1) Tambah meja; 2) isi kode yang sudah ada + jumlah + keterangan; 3) Simpan.
- Ekspektasi: pesan "Kode meja sudah dipakai" tampil di field kode dan isian lain tidak hilang.
- Aktual: form ditutup, server menolak, pengguna harus membuka form lagi dan mengisi ulang semuanya.
- Bukti: `test/v2_meja_form_test.dart` (`kode meja yang sudah dipakai ditolak tanpa menutup form`) — di kode lama form langsung `pop` karena kode duplikat tidak diperiksa di klien.
- Penyebab (akar): validasi duplikat hanya di server; daftar meja yang sudah dimuat tidak dipakai untuk pencegahan awal.
- Status: **FIXED di kode, belum diuji ulang di HP** — `V2MejaFormPage` menerima `takenCodes`; duplikat ditolak sebelum `pop` (server tetap penentu akhir). File: `v2_meja_form_page.dart`, `v2_meja_connected.dart`.
- Catatan: auto-increment kode **bukan** lingkup desain 6.6 (input manual "Contoh: A2") → NOT-A-BUG.
- Regression test: `apps/mobile/test/v2_meja_form_test.dart`.

## BUG-52 [S3] Pesan galat form meja tidak hilang setelah nilai diperbaiki
- Area/PB: 06 Meja Tanam — Tambah/Ubah meja (6.7/6.19) · Ditemukan lewat: QA manual Sesi 6 (25 Nov 2026, K-15)
- Langkah reproduksi: 1) isi jumlah lubang 0 → Simpan; 2) perbaiki menjadi 240 tanpa menekan Simpan lagi.
- Ekspektasi: pesan "Isi angka lebih dari 0" hilang begitu nilai valid.
- Aktual: pesan bertahan sampai Simpan ditekan ulang.
- Bukti: `test/v2_meja_form_test.dart` (`pesan galat hilang begitu isian diperbaiki`) — gagal di kode lama (`findsNothing` tidak terpenuhi).
- Penyebab (akar): galat hanya disetel di `_simpan`; tak ada listener yang membersihkannya saat isian berubah.
- Status: **FIXED di kode, belum diuji ulang di HP** — listener `_clearKodeError/_clearLubangError/_clearKeteranganError`. File: `v2_meja_form_page.dart`.
- Regression test: `apps/mobile/test/v2_meja_form_test.dart`.

## BUG-53 [S3] Daftar meja tampak diam sesaat setelah Simpan (baris baru menunggu jaringan)
- Area/PB: 06 Meja Tanam — daftar (6.1) · Ditemukan lewat: QA manual Sesi 6 (25 Nov 2026, K-17)
- Langkah reproduksi: 1) Tambah meja → Simpan; 2) amati daftar sebelum/sesudah jawaban server.
- Ekspektasi: pengguna tahu penyimpanan sedang berjalan.
- Aktual: form tertutup dan daftar lama tampil tanpa tanda proses; baris baru muncul setelah jawaban server. Id meja ditentukan server, jadi baris tidak bisa ditampilkan lebih awal tanpa data sementara.
- Bukti: alur `_tambah` → `createTable` → `_merge` (menaruh di depan) → `refresh()`; tidak ada umpan balik sebelum `await` selesai.
- Penyebab (akar): jeda jaringan + tidak ada indikator proses di daftar.
- Status: **sebagian, FIXED di kode** — pesan "Menyimpan meja…" muncul segera lalu diganti "Meja ditambahkan.". Akar (jeda/ID dari server) tetap; perbaikan penuh butuh pola form menyimpan sendiri (dicatat sebagai rekomendasi, belum dikerjakan).
- Regression test: tidak ada (perilaku waktu; diverifikasi lewat alur kode).

## BUG-54 [S2] Form "Catat penjualan" alur nyata terisi contoh dan panen pertama otomatis
- Area/PB: 08 Penjualan — Catat penjualan (8.7) · Ditemukan lewat: QA manual Sesi 6 (25 Nov 2026, K-26)
- Langkah reproduksi: 1) Penjualan → Catat penjualan (alur tersambung, bukan galeri); 2) langsung tekan Simpan.
- Ekspektasi: isian kosong, panen wajib dipilih; tidak ada penjualan contoh tersimpan.
- Aktual: pembeli "Warung Sari", 60 kg, Rp40.000, dan panen pertama sudah terpilih; Simpan tanpa mengubah ikut menulis data contoh itu.
- Bukti: `test/v2_penjualan_form_default_test.dart` — di kode lama field berisi nilai contoh dan Simpan lolos validasi; sekarang Simpan menolak dengan "Isi nama pembeli"/"Pilih panen"/"Isi jumlah"/"Isi harga".
- Penyebab (akar): nilai contoh galeri dipakai juga untuk alur nyata; `empty` hanya menandai pratinjau validasi, bukan "bukan galeri".
- Status: **FIXED di kode, belum diuji ulang di HP** — `_prefill` hanya untuk galeri/pratinjau atau mode ubah; alur nyata mulai kosong dan `_panen` null. File: `v2_penjualan_form_page.dart`. Tes BUG-42 disesuaikan (isi form dulu, lalu Simpan).
- Regression test: `apps/mobile/test/v2_penjualan_form_default_test.dart`.

## BUG-55 [S3] Pemilih "Meja tanam" di layar deteksi tampak mati tanpa penjelasan
- Area/PB: 09 Perawatan — Foto tanaman/deteksi (9.5–9.8) · Ditemukan lewat: QA manual Sesi 6 (25 Nov 2026, K-28)
- Langkah reproduksi: 1) buka Foto tanaman; 2) buka daftar "Meja tanam" saat belum ada meja berisi tanaman.
- Ekspektasi: dijelaskan bahwa meja harus punya tanaman aktif lebih dulu.
- Aktual: dropdown kosong, tombol simpan nonaktif dengan "Pilih meja tanam dulu", tanpa menyebut prasyaratnya.
- Bukti: `test/pest_scan_page_test.dart` (`tanpa meja berisi tanaman: daftar meja dijelaskan`) — di kode lama teks prasyarat tidak ada. Backend menghitung `tanaman_aktif` (`apps/backend/src/features/tables/store.ts:12,69`), jadi bukan kekurangan data server.
- Penyebab (akar): filter `activePlants > 0` menyembunyikan semua meja tanpa menjelaskan sebabnya.
- Status: **FIXED di kode, belum diuji ulang di HP** — pesan "Belum ada meja dengan tanaman aktif…" tampil saat daftar kosong. File: `pest_scan_page.dart`.
- Regression test: `apps/mobile/test/pest_scan_page_test.dart`.

## BUG-56 [S2] Password 6–11 karakter ditolak server walau klien mengizinkan (butuh backend)
- Area/PB: 03 Akun — Tambah/Ubah pegawai (3.7/3.12) · Ditemukan lewat: keputusan PM D-34 (26 Nov 2026, K-02)
- Langkah reproduksi: 1) Petani → Akun pegawai → Tambah/ubah pegawai; 2) isi password 6–11 karakter; 3) Simpan.
- Ekspektasi (D-34): password minimal 6 karakter diterima.
- Aktual: klien menerima (validasi 6–12), tetapi server menolak dengan `VALIDATION_ERROR` karena
  `apps/backend/src/common/validation.ts:42` memakai `newPasswordSchema = z.string().min(12).max(128)`.
- Bukti: `apps/mobile/test/v2_employee_d34_test.dart` (batas klien 6–12 dipaku); baris server
  `apps/backend/src/common/validation.ts:42`.
- Penyebab (akar): kontrak server belum disesuaikan dengan D-34. **Di luar batas FE** (backend READ-ONLY).
- Status: **BUTUH BACKEND/PM** — validasi klien sudah 6–12; agar konsisten, server perlu
  `min(6).max(12)`. Telepon **tidak** bermasalah: kontrak server
  (`apps/backend/src/features/accounts/contracts.ts:12`) lebih longgar daripada 10–13 digit.
- Mitigasi klien: batas 6–12 tetap ditampilkan agar pengguna mengisi nilai yang diterima kedua sisi;
  pesan galat server tetap ditampilkan apa adanya.

## BUG-57 [S3] Tidak ada konfirmasi sebelum menyimpan perubahan akun/meja
- Area/PB: 03 Akun — Ubah pegawai (3.12); 06 Meja — Ubah meja (6.18) · Ditemukan lewat: QA manual Sesi 6 (K-03/K-18)
- Langkah reproduksi: 1) buka Ubah pegawai/meja; 2) ubah satu isian; 3) tekan Simpan.
- Ekspektasi (D-35): muncul pop-up konfirmasi sebelum menyimpan.
- Aktual (sebelum perbaikan): Simpan langsung mengirim/menutup form tanpa konfirmasi.
- Bukti: `apps/mobile/test/v2_meja_d35_test.dart` — di kode lama hasil pop tidak null sebelum dialog.
- Penyebab (akar): aksi Simpan tidak meminta konfirmasi ulang untuk perubahan data yang sudah ada.
- Status: **FIXED di kode, belum diuji ulang di HP** — dialog `showV2Dialog` pada mode ubah
  (`v2_employee_form_page.dart` "Simpan perubahan akun?"; `v2_meja_form_page.dart`
  "Simpan perubahan meja?"). Form tambah tetap tanpa konfirmasi.
- Regression test: `apps/mobile/test/v2_meja_d35_test.dart`, `apps/mobile/test/v2_employee_d34_test.dart`.

## BUG-58 [S2] Tidak ada jalan mengaktifkan kembali pegawai nonaktif
- Area/PB: 03 Akun — Detail pegawai nonaktif (3.17) · Ditemukan lewat: QA manual Sesi 6 (K-05)
- Langkah reproduksi: 1) Petani → Akun pegawai; 2) buka pegawai nonaktif; 3) cari cara mengaktifkan kembali.
- Ekspektasi (D-36): tersedia aksi "Aktifkan" untuk petani.
- Aktual (sebelum perbaikan): hanya tombol "Ubah"; server sudah punya `POST /employees/:id/activate` (204).
- Bukti: `apps/mobile/test/v2_employee_d36_test.dart` — di kode lama tombol "Aktifkan" tidak ada.
- Penyebab (akar): `V2EmployeeStore` belum punya operasi `activate`; UI detail belum menampilkannya.
- Status: **FIXED di kode, belum diuji ulang di HP** — `V2EmployeeStore.activate` +
  `V2EmployeeApiStore.activate` (`POST /employees/:id/activate`), `V2EmployeeActivated`, tombol
  "Aktifkan" (menggantikan "Nonaktifkan" saat nonaktif), toast "<nama> diaktifkan kembali".
  File: `v2_akun_employee_store.dart`, `v2_employee_store.dart`, `v2_akun_employee.dart`,
  `v2_employee_detail_page.dart`, `v2_employee_list_page.dart`.
- Regression test: `apps/mobile/test/v2_employee_d36_test.dart`.

## BUG-59 [S3] Keterangan penjualan tidak ada di form/detail (fitur D-39)
- Area/PB: 08 Penjualan — Catat/Ubah penjualan (8.7/8.21), Detail (8.15) · Ditemukan lewat: QA manual Sesi 6 (K-25)
- Langkah reproduksi: 1) Penjualan → Catat penjualan; 2) cari isian catatan bebas; 3) simpan.
- Ekspektasi (D-39): tersedia "Keterangan (opsional)" yang tersimpan & tampil kembali.
- Aktual (sebelum perbaikan): model/form tidak mengenal kolom keterangan walau server mendukung
  (`sales/contracts.ts:27,36,44`).
- Bukti: `apps/mobile/test/v2_penjualan_d39_test.dart` — di kode lama field ke-4 tidak ada dan
  draft tanpa `keterangan`.
- Penyebab (akar): fitur belum diimplementasikan (di luar desain FigCraft) sampai diputuskan PM.
- Status: **FIXED di kode, belum diuji ulang di HP** — field `keterangan` pada
  `V2Penjualan`/`V2PenjualanDraft`, isian form, kartu info di detail, dan pemetaan antrean
  (`v2_penjualan_mappers.dart`); dikirim sebagai `note` pada create/update/markPaid.
- Regression test: `apps/mobile/test/v2_penjualan_d39_test.dart`.

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
- **Aplikasi online-only (D-14):** tidak bisa mencatat/mengakses menu saat offline adalah
  perilaku yang **diharapkan** (keputusan PM), bukan bug. Catatan informasi: inferensi
  TFLite tetap **lokal** (tanpa server), tetapi layar Deteksi hama memuat data meja/batch
  dari server sehingga membukanya tetap butuh internet — **bukan bug**.
- **Mode gelap (D-16):** aplikasi hanya punya satu tema terang; mengganti tema sistem tidak
  berpengaruh. Gap/keputusan, **bukan bug**; tidak menambah dark mode tanpa persetujuan.
- **Izin notifikasi (D-17):** `POST_NOTIFICATIONS` dideklarasikan tetapi tak ada alur
  permintaan izin; notifikasi native juga belum ada (D-06). Gap, **bukan bug**.
- **Kegagalan simpan foto (BUG-16):** akar masalah = kredensial `CLOUDINARY_*` belum diisi
  di server. Tim backend sudah mengisi env-nya dan simpan pindaian berhasil di HP
  (dev FE, 24 Nov 2026) → BUG-16 **FIXED**. Sisi mobile tetap punya pesan galat yang
  bisa ditindaklanjuti bila layanan unggah bermasalah lagi.

### Sesi 6 (25 Nov 2026) — temuan pelapor yang **bukan bug kode**

Rincian bukti ada di `mcdocs/qa-sesi6-tasks.md` (tabel triase); ringkasannya:

- **K-01 profil petani tidak ada:** desain FigCraft 3.1 "Lainnya (Petani)" tidak punya rute
  profil petani mandiri; lihat G-20 (gap dokumen), bukan bug.
- **K-09 dropdown "Obat" vs isian "Nama barang":** FigCraft 4.11 memang memuat keduanya.
- **K-10 form stok kurang tanggal/keterangan:** ERD `inventaris` memang tanpa keduanya;
  tanggal/keterangan milik catatan `stok`.
- **K-16 "maksimum 250 lubang per meja":** NFR-5 "12 meja × 250 = 3.000" adalah **kapasitas
  total kebun**, bukan batas per meja (kontrak per meja maks 1000, lihat G-19).
- **K-22 tombol Simpan naik di atas keyboard:** FigCraft 8.10 memang menggambar tombol tepat
  di atas keyboard saat isian aktif; implementasi cocok.
- **K-23 status "lunas"/"belum lunas":** ada di desain 8.7 **dan** kontrak server
  (`lunas|belum_lunas`).
- **K-24 menyimpan nama pembeli:** `pembeli` wajib di kontrak server dan ada di 8.7.
- **K-25 keterangan penjualan kurang:** server mendukung opsional, tetapi FigCraft 8.7/8.21
  tidak punya isiannya → fitur di luar desain, dicatat sebagai rekomendasi (D-39), tidak
  diimplementasikan.
- **K-30 pegawai "sama seperti petani":** matriks izin sudah diterapkan; pegawai 4 tab
  (Beranda/Tanam/Stok/Profil) tanpa Rawat/Lainnya; tab Profil read-only (G-18 tetap terbuka).

### Sesi 6 (25 Nov 2026) — temuan yang menunggu prasyarat atau penjelasan

- **K-11/K-13/K-20/K-21/K-27 ("tidak bisa dicoba"):** jalur uji terblokir prasyarat data
  (tambah barang → semai → pindah → panen → jual). Bukan bug; perlu uji ulang berurutan
  setelah BUG-49/BUG-50.
- **K-06/K-19/K-29 ("ngebug"/"modelnya lucu"):** tanpa langkah/pesan yang jelas. Pertanyaan
  sudah disampaikan ke pelapor (`qa/decisions.md` §7).
- **K-02/K-03/K-05/K-18:** memerlukan keputusan produk (D-34..D-36); lihat `qa/decisions.md`.
- **K-17/K-08/K-28 (bagian data):** akar data/jaringan, bukan cacat tombol; mitigasi klien
  sudah ditambahkan (BUG-50/53/55).

---

# Sesi 7 (26 Nov 2026) — fix bug FE sesuai keputusan SA

Rencana & status: `mcdocs/qa-sesi7-plan.md`, `mcdocs/qa-sesi7-tasks.md`.
Butir yang butuh backend: `docs/backend-change-requests.md`.
Semua status di bawah = **FIXED di kode, belum diuji ulang di HP**.

## BUG-60 [S2] Barang arsip tidak pernah muncul di chip "Arsip"
- Area/PB: 04 Stok — daftar & arsip (4.28/4.29) · Ditemukan lewat: testing FE Sesi 7
- Langkah: 1) arsipkan satu barang; 2) buka chip "Arsip".
- Ekspektasi: barang arsip tampil di chip "Arsip" dan hilang dari "Semua".
- Aktual: daftar selalu memuat barang aktif saja, jadi arsip tidak pernah termuat.
- Bukti: `inventory_repository.refresh()` mengirim `status_aktif=1`; sekarang dihapus
  supaya server mengirim aktif **dan** arsip. `test/inventory_backend_flow_test.dart`
  disesuaikan (101 baris arsip ikut termuat, 6 halaman).
- Status: **FIXED di kode** — filter "Semua" tetap menyembunyikan arsip
  (`v2_inventaris_list_page.dart`: `item.arsip != (_status == 2)`).
- Regression test: `test/inventory_backend_flow_test.dart`.

## BUG-61 [S2] Ubah barang: jenis baru tidak terkirim, kategori lama dipakai
- Area/PB: 04 Stok — Ubah barang (4.24)
- Langkah: 1) ubah barang dari Benih ke Nutrisi; 2) Simpan.
- Ekspektasi: jenis/kategori ikut berubah.
- Aktual (sebelum): payload memakai `record?.categoryId` sehingga jenis baru diabaikan.
- Status: **FIXED di kode** — `v2_inventaris_connected.dart` menurunkan kategori dari
  `updated.jenis` (`_kategoriCocok`), dengan `record?.categoryId` hanya sebagai cadangan.
- Regression test: `test/inventory_backend_flow_test.dart` (alur ubah).

## BUG-62 [S2] Pindah meja: bisa dobel submit, sisa bibit tak divalidasi, estimasi dari tanggal semai
- Area/PB: 05 Semaian — Pindah ke meja (5.17/5.21)
- Ekspektasi: satu ketukan = satu permintaan; jumlah tidak melebihi sisa bibit; estimasi
  panen dihitung dari tanggal pindah (HST 0 sejak pindah).
- Aktual (sebelum): tombol bisa ditekan berkali-kali, jumlah melebihi sisa bibit baru
  ditolak setelahnya, dan estimasi memakai umur tetap dari semai.
- Status: **FIXED di kode** — `_submitting`, `_sisaBibit`, `_pesanJumlah`,
  `_pickTanggal` dijaga, input disable, tombol `loading`, helper "Sisa bibit di semaian N",
  `v2PerkiraanPanen(_tanggal)`.
- Regression test: `test/v2_pindah_meja_jumlah_test.dart`,
  `test/v2_pindah_meja_success_test.dart`, `test/v2_validators_sesi7_test.dart`.

## BUG-63 [S2] "Lihat semaian" menumpuk route dan tidak kembali ke tab Semaian
- Area/PB: 06 Meja — Detail meja (6.10)
- Ekspektasi: kembali ke dashboard lalu membuka tab Tanam/Semaian.
- Aktual (sebelum): push halaman daftar semaian baru di atas detail meja.
- Status: **FIXED di kode** — `onOpenSemaian` diteruskan Beranda → Tanam → Meja;
  aksi `popUntil(isFirst)` + ganti tab.
- Regression test: `test/v2_meja_pemilih_semaian_bug40_41_test.dart`.

## BUG-64 [S3] Keterangan tidak tampil di detail semaian, meja, dan panen
- Area/PB: 05 Semaian, 06 Meja, 07 Panen — detail
- Ekspektasi (keputusan SA): keterangan yang diisi ikut terbaca di detail.
- Aktual (sebelum): data keterangan dibawa mapper tetapi tidak dirender.
- Status: **FIXED di kode** — kartu info "Keterangan" muncul bila tidak kosong di
  `v2_semaian_detail_page.dart`, `v2_meja_detail_page.dart`, `v2_panen_detail_page.dart`.
- Regression test: tidak ada (widget detail tidak punya tes khusus keterangan); alur
  pemetaan ditutup `test/v2_connected_mappers_test.dart`.

## BUG-65 [S3] Grafik berat panen memakai data contoh, bukan riwayat nyata
- Area/PB: 07 Panen — Riwayat (7.6)
- Ekspektasi (keputusan SA): grafik dari data asli, maks 3 tanggal terakhir, satu panen
  = satu tanggal (beberapa panen di hari sama dijumlahkan).
- Aktual (sebelum): `designGrafikPanen` hardcoded (12 Okt/29 Okt/6 Nov).
- Status: **FIXED di kode** — `v2GrafikPanenDari` + `v2GrafikPanenKeterangan`.
- Regression test: `test/v2_validators_sesi7_test.dart`.

## BUG-66 [S3] Pegawai bisa membuka Cuaca lewat detail siklus (berakhir 403)
- Area/PB: 02 Beranda — detail siklus (2.7) · Ditemukan lewat: audit role Sesi 7
- Langkah: 1) masuk sebagai pegawai; 2) buka kartu siklus; 3) ketuk baris cuaca.
- Ekspektasi (keputusan SA): route terlarang disembunyikan.
- Aktual (sebelum): `onOpenWeather` selalu diteruskan; pegawai tanpa `cuaca:read`.
- Status: **FIXED di kode** — `_openCycle` hanya meneruskan cuaca saat `_petani` dan
  beranda tidak menyediakan cuaca BMKG.
- Regression test: `test/v2_role_gating_sesi7_test.dart`.

## BUG-67 [S3] Kode meja tidak otomatis bertambah
- Area/PB: 06 Meja — Tambah meja (6.7)
- Ekspektasi (keputusan SA Sesi 7, merevisi triase K-16): kode berikutnya terisi otomatis
  dari daftar meja yang ada; pengguna tetap bisa menimpanya.
- Status: **FIXED di kode** — `v2KodeMejaBerikutnya` (pola huruf+angka, mis. A1→A2,
  M-01→M-02); tidak menebak bila belum ada meja berpola.
- Regression test: `test/v2_validators_sesi7_test.dart`.

## Catatan Sesi 7 — butir yang sengaja tidak diubah
- **Penjualan hapus "belum lunas"/pembeli:** `pembeli` wajib di kontrak server; tanpa
  perubahan backend klien hanya bisa mengirim nilai palsu. Diblokir, lihat
  `docs/backend-change-requests.md` #2.
- **Stok nama barang dropdown dari katalog AI:** `obat_katalog` tidak diekspos API dan
  berbeda dari `/obat`. Diblokir, lihat #3.
- **Riwayat perawatan:** tidak ada endpoint daftar `perawatan`; tab Rawat masih menampilkan
  laporan kerusakan. Diblokir, lihat #4.
- **Profil pegawai:** tanpa `profil:read`, telepon/alamat tampil "-". Diblokir, lihat #5.

## Sesi 8 (27 Nov 2026) — daftar terurut "perubahan terakhir"

Permintaan client: setiap daftar menu umum (Stok, Semaian, Meja, Panen, Penjualan,
Akun/pegawai) menaruh baris yang **paling baru diubah** di paling atas, bukan yang
paling baru **dibuat** atau tanggal transaksinya.

## BUG-68 [S3] Daftar fitur tidak terurut berdasarkan perubahan terakhir
- Area/PB: 04 Stok, 05 Semaian, 06 Meja, 07 Panen, 08 Penjualan, 09 Akun/pegawai.
- Langkah: 1) catat/ubah satu baris lama (mis. koreksi panen atau ubah barang);
  2) buka kembali daftar fitur itu.
- Ekspektasi (keputusan SA Sesi 8, D-51): baris yang **paling baru diubah** tampil
  paling atas. Perubahan turunan (saldo stok, tanaman aktif meja, pindah/kerusakan/
  panen) ikut dihitung sebagai perubahan barang/meja.
- Aktual (sebelum): daftar memakai tanggal bisnis (`tanggal_panen`, `tanggal_semai`,
  `tanggal_penjualan`) atau `id` menaik, sehingga koreksi pada baris lama tidak
  memindahkannya ke atas; akun diurut `id_user` menaik.
- Status: **FIXED di kode (backend + FE), belum diuji ulang di HP.**
  - Backend: kolom `updated_at` = `MAX(sync_changes.changed_at)` per record
    (`lastChangedAt()` di `common/sync.ts`); daftar `ORDER BY COALESCE(updated_at,0)
    DESC, <id> DESC`. Akun memakai `users.updated_at` (diisi jalur tulis akun).
  - FE: order backend tidak ditimpa. Stok/Semaian/Meja/Akun sudah memetakan daftar
    apa adanya (tanpa sort), jadi cukup mengikuti backend. Panen/Penjualan punya sort
    sendiri di klien, jadi `HarvestRecord`/`SaleRecord` (dan `PenjualanItem`) membaca
    `updated_at` (nullable) dan `panen_viewmodel._merge` + `comparePenjualanItems`
    memakai `updated_at` lebih dulu.
  - Migrasi: `apps/backend/migrations/0023_list_last_changed.{up,down}.sql`.
- Regression test: FE `test/list_last_changed_test.dart`; backend
  `test/accounts.test.js`, `test/tables.test.js`, `test/inventory-read-model.test.js`.
- Catatan: server sesi ini **boleh** berubah (berbeda dari batas Sesi 7) karena
  urutan "perubahan terakhir" hanya benar bila waktu ubah berasal dari server.

## Sesi 9 (27 Nov 2026) — pop-up konfirmasi ulang + loading pada tombol proses

Permintaan client: setiap tombol yang menjalankan proses tulis membuka **pop-up konfirmasi
ulang** dengan **spinner di tombol konfirmasinya**, dan layar baru kembali ke menu setelah
proses selesai. Tombol navigasi murni (mis. "Lihat meja") hanya butuh loading. **FE saja**
(tidak ada perubahan backend).

## BUG-69 [S3] Tombol proses kembali ke layar sebelumnya sebelum proses selesai
- Area/PB: lintas fitur — Semaian, Meja, Panen, Penjualan, Stok, Akun/pegawai, Rusak,
  Rekomendasi obat.
- Langkah: 1) jalankan proses tulis dari layar mana pun (tambah/ubah/catat/arsip/terima/
  tolak/aktif-nonaktif) saat jaringan lambat; 2) amati layar sebelum server menjawab.
- Ekspektasi (permintaan client Sesi 9, D-52): muncul pop-up konfirmasi ulang; saat
  ditekan, tombol konfirmasi berputar sampai proses selesai; layar baru berpindah setelah
  itu. Kalau server menolak, pop-up menutup dan galat tampil sebagai pesan sementara form
  tetap terbuka (isian tidak hilang).
- Aktual (sebelum): sebagian form menutup/menavigasi lebih dulu lalu menulis di belakang
  (mis. "Tambah meja", "Catat panen", "Catat stok", "Arsipkan", "Catat penjualan"),
  sebagian lagi hanya punya spinner tanpa konfirmasi ulang ("Simpan" penjualan, "Tandai
  lunas"), dan beberapa proses (rekomendasi obat, aktif/nonaktif pegawai) berjalan tanpa
  pop-up sama sekali. Tidak ada satu pola.
- Status: **FIXED di kode (FE), belum diuji ulang di HP.**
  - Primitif: `showV2ActionDialog` di `lib/views/v2/widgets/v2_dialog.dart`
    (`V2Dialog.primaryLoading`, `barrierDismissible:false`, `PopScope(canPop:!running)`,
    galat dilempar ke pemanggil).
  - Pola: form/halaman menerima callback `onSubmit`/`onXxx` dan menjalankan tulisnya **di
    dalam** pop-up; baru setelah `done` layar berpindah. Jalur pratinjau/galeri (callback
    null) tidak berubah.
  - Cakupan: tambah/ubah semaian; pindah semaian ke meja; tambah/ubah meja & ubah status
    meja; tambah tanaman ke meja; catat/ubah rusak; ubah catatan tanaman; catat/ubah panen;
    catat/ubah/kirim ulang penjualan & tandai lunas; tambah/ubah barang, catat stok,
    arsipkan; terima/tolak rekomendasi obat; tambah/ubah/nonaktifkan/aktifkan pegawai.
    Halaman hasil pindah meja ("Lihat meja"/"Pindahkan sisa") = loading tanpa pop-up.
- Regression test: `test/v2_confirm_loading_sesi9_test.dart` (primitif + tambah pegawai +
  form meja); tes alur lama disesuaikan agar melewati pop-up:
  `test/v2_employee_d36_test.dart`, `test/v2_stock_refresh_after_accept_test.dart`,
  `test/v2_pindah_stale_bug34_test.dart`, `test/v2_tambah_tanaman_bug35_test.dart`,
  `test/v2_panen_jual_bug42_43_test.dart`, `test/v2_penjualan_d39_test.dart`.

