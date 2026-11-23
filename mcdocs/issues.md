# mcdocs/issues.md — Bug & temuan

Format sesuai PROMPT §8. Severity: S1 Critical / S2 Major / S3 Minor / S4 Cosmetic.
Status: `OPEN` | `FIXED` | `WONTFIX` | `NEEDS-HUMAN-REVIEW`.

Batas perbaikan (permintaan client sesi ini): **hanya** bug di `apps/mobile/` yang
diperbaiki. Bug backend/DB/ML/keamanan **didokumentasikan** dengan saran perbaikan.

## Statistik

| Severity | Ditemukan | Diperbaiki | Terbuka / review |
|---|---|---|---|
| S1 Critical | 0 | 0 | 0 |
| S2 Major | 1 | 0 | 1 |
| S3 Minor | 6 | 3 | 3 |
| S4 Cosmetic | 1 | 0 | 1 |
| **Total** | **8** | **3** | **5** |

Gap fitur (bukan bug kode) dicatat di `rtm.md` §Gap.

---

## BUG-01 [S3] formatAngka menghasilkan titik gantung ("1.")
- Area/PB: PB-08/PB-09/PB-10 (tampilan angka) · Ditemukan lewat: review kode + `TC-FE-01`
- Langkah reproduksi: 1) panggil `formatAngka(1.001)` di `apps/mobile`.
- Ekspektasi: `"1"` (nilai di bawah 0,01 dibulatkan, tanpa pemisah desimal menggantung).
- Aktual: `"1."` — `toStringAsFixed(2)` menghasilkan `"1.00"`, lalu `RegExp(r'0+$')`
  memangkas nol tanpa ikut membuang titik.
- Bukti: `flutter test test/core_formatting_test.dart` gagal sebelum perbaikan
  (`Expected: not a string containing '.'; Actual: '1.'`).
- Penyebab (akar): regex pemangkas nol di `apps/mobile/lib/core/formatting.dart:31`
  tidak opsional terhadap titik desimal.
- Status: **FIXED** — `replaceFirst(RegExp(r'0+$'), '')` → `replaceFirst(RegExp(r'\.?0+$'), '')`.
- Regression test: `apps/mobile/test/core_formatting_test.dart`.

## BUG-02 [S3] formatAngkaDesimal/formatKg menghasilkan koma gantung ("1, kg")
- Area/PB: PB-08/PB-09 (label berat/juta) · Ditemukan lewat: review kode + `TC-FE-02`
- Langkah reproduksi: 1) `formatAngkaDesimal(1.001)`; 2) `formatKg(1.001)`.
- Ekspektasi: `"1"` dan `"1 kg"`.
- Aktual: `"1,"` dan `"1, kg"` (`formatJutaAkurat` juga bisa menghasilkan `"Rp 1, jt"`).
- Bukti: `flutter test test/v2_format_desimal_test.dart` gagal sebelum perbaikan
  (`Expected: not a string ending with ','; Actual: '1,'`).
- Penyebab (akar): pola yang sama seperti BUG-01 di
  `apps/mobile/lib/views/v2/components/v2_penjualan_data.dart:309`.
- Status: **FIXED** — regex diperbaiki menjadi `\.?0+$` sebelum `replaceAll('.', ',')`.
- Regression test: `apps/mobile/test/v2_format_desimal_test.dart`.

## BUG-03 [S3] Lencana "Menipis" tidak konsisten dengan aturan kanonik di batas minimum
- Area/PB: PB-02 (indikator stok minimum) · Ditemukan lewat: `TC-FE-03`
- Langkah reproduksi: 1) buat barang dengan `saldo == stok_minimum` (mis. saldo 3, min 3);
  2) buka daftar Stok v2 vs kartu "Stok menipis" di Beranda.
- Ekspektasi: bukan menipis. Backend `di_bawah_minimum = saldo < minimum`
  (`apps/backend/src/features/inventory/store.ts:85`), `InventoryRecord.isLow`
  memakai `<` dan bahkan divalidasi ulang di `fromApi`, sedangkan label stok lama
  menampilkan "Stok mencukupi" saat `saldo == minimum`
  (`test/inventory_stock_label_test.dart`).
- Aktual: `statusStok()` memakai `<=`, jadi barang dengan `saldo == minimum` diberi
  lencana "Menipis" dan ikut tersaring di "Menipis", padahal kartu Beranda tidak
  menghitungnya (`isLow`). Kartu dan daftar bisa berbeda tanpa sebab kategori.
- Bukti: `flutter test test/v2_inventaris_status_test.dart` gagal sebelum perbaikan
  (`statusStok(3,3)` → menipis, diharapkan aman).
- Penyebab (akar): ambang inklusif di
  `apps/mobile/lib/views/v2/components/v2_inventaris_data.dart:38`.
- Status: **FIXED** — `jumlah <= minimum` → `jumlah < minimum`; dokumentasi fungsi
  diperbarui agar menyebut aturan kanonik.
- Regression test: `apps/mobile/test/v2_inventaris_status_test.dart`.

## BUG-04 [S2] Dependensi backend memiliki 3 advisory keamanan
- Area/PB: §5.3 Keamanan · Ditemukan lewat: `npm audit --omit=dev`
- Langkah reproduksi: `cd apps/backend && npm audit --omit=dev`.
- Ekspektasi: tidak ada advisory pada dependensi runtime.
- Aktual: `3 vulnerabilities (1 low, 1 moderate, 1 high)`:
  - `zod <4.6.6` — **high** — kehabisan memori saat memvalidasi koleksi besar
    (GHSA-mrhx-c7xc-m3w5). Dipakai di semua validasi request.
  - `fastify 5.12.2–5.12.5` — header validation bypass (GHSA-389g-gv7q-r4x8).
  - `fast-uri` (via ajv) — scheme injection (GHSA-333x-w4r6-6crp).
- Bukti: keluaran `npm audit` di atas (nyata).
- Penyebab (akar): versi terkunci di `package.json`/lockfile lebih lama dari patch.
- Status: **NEEDS-HUMAN-REVIEW** — perbaikan menyentuh dependensi backend, di luar
  batas perbaikan front-end sesi ini. Saran: naikkan `zod` ke >=4.6.7, `fastify` ke
  >=5.12.8 lalu jalankan `npm test` penuh (359 tes) untuk regresi.
- Regression test: tidak ada (perbaikan belum dilakukan).

## BUG-05 [S3] Token sesi disimpan plaintext di SQLite lokal (`session.db`)
- Area/PB: PB-01 / §5.3 (penyimpanan lokal) · Ditemukan lewat: review kode
- Langkah reproduksi: 1) login di app; 2) periksa `session.db` pada sandbox aplikasi.
- Ekspektasi: token (kredensial) disimpan di penyimpanan terenkripsi
  (Android Keystore / `flutter_secure_storage`).
- Aktual: `apps/mobile/lib/data/services/session_store.dart` menyimpan access/refresh
  token sebagai teks di tabel SQLite `sessions`. Password sendiri **tidak** disimpan
  (dan di server berupa hash scrypt), tetapi token = kredensial bearer.
- Bukti: pembacaan `session_store.dart`; tidak ada dependensi `flutter_secure_storage`
  di `apps/mobile/pubspec.yaml`.
- Penyebab (akar): desain penyimpanan lokal memakai sqflite biasa.
- Status: **NEEDS-HUMAN-REVIEW** — perubahan menyentuh desain penyimpanan + migrasi;
  bukan perbaikan lokal berisiko rendah.
- Regression test: tidak ada.

## BUG-06 [S3] Angka kartu "Stok menipis" ≠ isi daftar tersaring (keputusan produk)
- Area/PB: PB-02 · Ditemukan lewat: `TC-PB02-09`
- Langkah reproduksi: 1) buat barang menipis dari kategori selain Benih; 2) bandingkan
  angka kartu Beranda dengan daftar "Benih + Menipis" yang dibukanya.
- Ekspektasi: angka kartu sama dengan jumlah baris daftar yang dibuka.
- Aktual: kartu menghitung **semua jenis** yang menipis, daftar difilter **Benih +
  Menipis**. Bila nutrisi/perlengkapan juga menipis, angka kartu lebih besar.
- Bukti: `docs/laporan-frontend-v2-untuk-tester.md` §2 dan
  `docs/laporan-frontend-v2-untuk-backend.md` §2 sudah mencatatnya sebagai keputusan
  produk yang menunggu; perilaku kode sesuai catatan itu.
- Penyebab (akar): perbedaan cakupan agregasi vs filter tujuan.
- Status: **NEEDS-HUMAN-REVIEW** (keputusan produk: samakan cakupan atau ubah filter).
  Catatan: BUG-03 sudah memperbaiki ketidakcocokan **batas minimum**; sisa perbedaan
  ini murni soal cakupan kategori.
- Regression test: `apps/mobile/test/v2_beranda_low_stock_test.dart` (mengunci filter).

## BUG-07 [S4] Sync replayer menandai "gagal" bila penghapusan baris antrean error
- Area/PB: PB-07 · Ditemukan lewat: review kode
- Langkah reproduksi: 1) kirim satu baris antrean sampai server menerima; 2) buat
  `SyncQueueStore.remove()` melempar (mis. I/O SQLite sesaat).
- Ekspektasi: baris yang sudah diterima server tidak ditandai gagal.
- Aktual: `apps/mobile/lib/viewmodels/v2_sync_replayer.dart` memanggil
  `sender.send()` lalu `queue.remove()` di dalam satu `try`; kegagalan `remove`
  masuk `catch` dan menandai baris `gagal`.
- Bukti: pembacaan kode (baris `sender.send`/`queue.remove`).
- Penyebab (akar): penggabungan dua langkah berbeda nasib dalam satu blok `try`.
- Status: **NEEDS-HUMAN-REVIEW / WONTFIX-sementara** — tidak menghilangkan data
  (kunci idempoten membuat kirim ulang aman dan baris lepas saat retry). Dampak
  hanya label "gagal" sementara.
- Regression test: tidak ada.

## BUG-08 [S3] `hasil_deteksi.confidence` tidak dibatasi rentang 0–1 di level DB
- Area/PB: §5.2 Integritas data · Ditemukan lewat: `TC-5.2-04`
- Langkah reproduksi: 1) periksa skema `hasil_deteksi`:
  `sqlite3 /tmp/opencode/hsqa/qa.db ".schema hasil_deteksi"`.
- Ekspektasi: kolom confidence dibatasi `CHECK(confidence BETWEEN 0 AND 1)` di DB
  (PROMPT §5.2 meminta constraint level DB, bukan hanya UI).
- Aktual: `confidence DECIMAL(5,4)` **tanpa** `CHECK`; nilai di luar 0–1 dapat tersimpan
  bila diisi lewat jalur apa pun.
- Bukti: `.schema hasil_deteksi` (tidak ada klausa CHECK pada confidence); 25 tabel
  lain memang punya CHECK.
- Penyebab (akar): constraint rentang tidak ditambahkan pada migrasi tabel tersebut.
- Status: **NEEDS-HUMAN-REVIEW** — tabel `hasil_deteksi` belum dipakai (fitur PB-05 belum
  dibangun); perbaikan menyentuh migrasi skema DB (di luar batas front-end). Saran: tambah
  `CHECK(confidence BETWEEN 0 AND 1)` saat fitur deteksi dibangun (lihat `rtm.md` G-07).
- Regression test: tidak ada (perbaikan belum dilakukan).

## Catatan (bukan bug)

- **XSS di field teks:** server menyimpan `<script>...` apa adanya dan mengembalikannya
  di JSON (dibuktikan `TC-PB01-12`). Klien Flutter merender teks sebagai teks, tidak
  ada WebView/HTML, jadi tidak ada eksekusi. Bila kelak ada klien web, sanitasi wajib
  ditambahkan.
- **Constraint DB mencegah stok negatif:** percobaan menyisipkan `saldo_minor=-5`
  ditolak oleh `CHECK` SQLite (bukti: negative control audit). Ini pertahanan
  berlapis yang baik, bukan bug.