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
| S2 Major | 7 | 6 | 1 |
| S3 Minor | 22 | 19 | 3 |
| S4 Cosmetic | 3 | 3 | 0 |
| **Total** | **32** | **28** | **4** |

Rincian: **FIXED** = BUG-01,02,03,06,07,08,09,10,11,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32 (28).
**NEEDS-HUMAN-REVIEW** = BUG-04 (S2, dependensi), BUG-05 (S3, token plaintext),
BUG-12/13 (S3, harness ML & doc API usang).
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

## BUG-29 [S3] Form "Pindah ke meja": jumlah besar susah diisi; meja penuh bisa jadi bawaan
- Area/PB: Tanam → Semaian → Pindah ke meja (5.17) · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026)
- Langkah reproduksi: 1) buka form pindah dengan jumlah besar (mis. 200); 2) coba ubah jumlah; 3) perhatikan pilihan meja bawaan saat meja pertama penuh/perawatan.
- Ekspektasi: jumlah besar bisa dicapai tanpa menekan plus satu-satu (tahan tombol atau ketik angka); bawaan memilih meja yang tersedia, bukan meja penuh.
- Aktual: hanya bisa satu langkah per ketukan; meja penuh bisa terpilih sebagai bawaan.
- Bukti: `flutter test test/v2_pindah_meja_jumlah_test.dart` — 3 kasus (tahan plus, ketik angka, bawaan meja); ketiganya gagal pada simulasi kode lama, lulus setelah perbaikan.
- Penyebab (akar): `V2Stepper`/`V2QtyField` hanya punya `onTap` satu langkah dan pil angka tidak bisa diketik; `_mejaIndex` awal tidak menyaring meja `tersedia`.
- Status: **FIXED** — tombol minus/plus bisa ditahan untuk berulang; angka bisa diketuk lalu diketik (dialog); meja tersedia pertama dipilih otomatis bila pilihan awal penuh/perawatan. **Urutan daftar meja tidak diubah** (menunggu PM). File: `v2_stepper.dart`, `v2_pindah_meja_page.dart`.
- Regression test: `apps/mobile/test/v2_pindah_meja_jumlah_test.dart`.
- Pertanyaan terbuka: apakah urutan daftar meja perlu diubah (mis. meja paling kosong di atas)? Menunggu PM.
- Catatan bukti: perbaikan dibuktikan lewat tes widget; **verifikasi ulang di HP asli menunggu dev FE**.

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

## BUG-31 [S3] Font 200%: label bulan grafik penjualan membungkus dua baris
- Area/PB: Penjualan → Ringkasan penjualan (grafik) · Ditemukan lewat: uji manual dev FE (HP asli, 24 Nov 2026), tercatat ulang dari BUG-24
- Langkah reproduksi: 1) set ukuran font sistem ke 200%; 2) buka Ringkasan penjualan; 3) lihat label bulan di bawah batang.
- Ekspektasi: tiap label bulan satu baris dan titik pusatnya sebaris dengan batangnya.
- Aktual: label "Sep"/"Okt"/"Nov" membungkus dua baris ("Se"/"p") dan tidak sejajar batang.
- Bukti: `flutter test test/v2_penjualan_chart_align_test.dart` — 4 kasus (lebar 320/360/411, skala 1.0 & 2.0); 2 gagal pada kode lama (tinggi label 80), lulus setelah perbaikan.
- Penyebab (akar): label bulan bebas membungkus; di skala 2.0 tinggi label melebihi slot sehingga turun baris.
- Status: **FIXED** — label dibungkus `FittedBox(fit: scaleDown)` dengan `maxLines: 1`/`softWrap: false`. File: `v2_penjualan_chart_card.dart`.
- Regression test: `apps/mobile/test/v2_penjualan_chart_align_test.dart`.
- Catatan bukti: perbaikan dibuktikan lewat tes widget; **verifikasi ulang di HP asli menunggu dev FE**.

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
