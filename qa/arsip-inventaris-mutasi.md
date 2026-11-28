# QA: Blokir mutasi barang arsip + label status akun pegawai

Tanggal: 28 Nov 2026. Branch: `wild-fe`.
Rencana: `mcdocs/arsip-inventaris-mutasi-plan.md`.
Task: `mcdocs/arsip-inventaris-mutasi-tasks.md`.
Lingkungan: Node v22.23.1 (backend), Flutter 3.47.7 stable, Dart 3.13.5.

Permintaan client saat uji manual:

1. **Backend, barang arsip**: barang yang sudah diarsipkan masih menerima
   request manipulasi. Hanya boleh dilihat dan diaktifkan kembali. Tujuannya
   mencegah dua pegawai berlomba, satu mengarsipkan dan satu mengubah, lalu
   data tetap berubah setelah arsip.
2. **Mobile, detail akun pegawai**: kapsul status akun masih "Aman" (aktif) dan
   "-"/"Kosong" (nonaktif). Seharusnya "Aktif" dan "Nonaktif".

## Ringkasan hasil

| Aturan | Sebelum | Sesudah | Bukti |
|---|---|---|---|
| `PATCH /inventaris/:id` barang arsip | Diterima `200`, data berubah | Ditutup `409 INVENTARIS_ARCHIVED`, data tidak berubah | `test/inventaris-archive-guard.test.js` |
| `POST /inventaris/:id/deactivate` pada barang arsip | Diterima `200` (no-op) | Ditutup `409 INVENTARIS_ARCHIVED` | `test/inventaris-archive-guard.test.js` |
| `POST /inventaris/:id/activate` barang arsip | Boleh | Tetap boleh `200` | `test/inventaris-archive-guard.test.js` |
| Lihat barang arsip (`GET` detail, daftar, saldo) | Boleh | Tetap boleh `200` | `test/inventaris-archive-guard.test.js` |
| Mutasi stok baru barang arsip | Sudah ditolak `422 INVENTARIS_NOT_AVAILABLE` | Tidak diubah | `test/stock.test.js` (test lama) |
| Pembalik transaksi stok barang arsip | Boleh (koreksi catatan lama) | Sengaja tetap boleh | `test/stock.test.js` ("whole reversal...") |
| Panggilan ulang dengan kunci idempotensi sama | Replay `200` | Tetap replay `200` | `test/inventaris-archive-guard.test.js` (test retry) |
| Aktifkan kembali lalu ubah lagi | Boleh | Boleh `200` | `test/inventaris-archive-guard.test.js` |
| Kapsul detail pegawai aktif | "Aman" | "Aktif" | `test/v2_employee_status_badge_test.dart` |
| Kapsul detail pegawai nonaktif | "Kosong" + ikon minus | "Nonaktif" | `test/v2_employee_status_badge_test.dart` |
| Kapsul profil sendiri | "Aman"/"Kosong" | "Aktif"/"Nonaktif" | `test/v2_employee_status_badge_test.dart` |

## Perubahan kode

Backend:

- `apps/backend/src/features/inventory/store.ts`
  - Tambah `inventarisArchived()` (melempar `409 INVENTARIS_ARCHIVED` dengan
    pesan "Barang sudah diarsipkan. Aktifkan kembali dulu untuk mengubahnya.")
    dan `assertInventarisActive(current)`.
- `apps/backend/src/features/inventory/inventaris.ts`
  - `PATCH /inventaris/:id`: panggil `assertInventarisActive(current)` sebelum
    menulis. `UPDATE` juga memakai syarat `status_aktif=1` dan memeriksa
    `rowsAffected` supaya balapan baca-lalu-tulis tertutup: bila pegawai lain
    mengarsipkan di antara baca dan tulis, permintaan ditolak, bukan menimpa.
  - `POST /inventaris/:id/deactivate`: panggil `assertInventarisActive(current)`
    sebelum menulis, jadi arsip ulang ditolak.
  - `POST /inventaris/:id/activate` tidak diubah (tetap boleh).
- `apps/backend/API.md`: mencatat aturan barang arsip dan pengecualian
  pembalik stok.

Mobile:

- `apps/mobile/lib/views/v2/pages/v2_employee_detail_page.dart`
  - Kapsul status: `Aktif` (success) / `Nonaktif` (neutral).
- `apps/mobile/lib/views/v2/pages/v2_profile_detail_page.dart`
  - Label kapsul sama (cacat sekelas yang sama).
- `apps/mobile/lib/views/v2/components/v2_akun_profil_card.dart`
  - Komentar contoh badge ikut diperbarui ke `Aktif`.

Test:

- Baru: `apps/backend/test/inventaris-archive-guard.test.js` (6 kasus).
- Baru: `apps/mobile/test/v2_employee_status_badge_test.dart` (3 kasus).
- Diperbarui: `apps/backend/test/audit-fixes.test.js` (deactivate kedua kini
  `409`, versi dan jumlah perubahan tetap).
- Diperbarui: `apps/backend/test/stock.test.js` (barang diaktifkan kembali
  sebelum PATCH satuan supaya jalur `UNIT_LOCKED` tetap diuji).
- Diperbarui: `apps/mobile/test/v2_text_scale_bug24_test.dart`
  (`'Aman'` -> `'Aktif'`).

## Daftar risiko (chatter) & hasil

Diurutkan sesuai dampak (data dulu, lalu alur, lalu teks):

1. Dua pegawai: satu mengarsipkan, satu menyimpan ubahan dari layar lama.
   **Ditutup**: `PATCH` barang arsip `409`, data tidak berubah (test balapan).
2. Arsip ulang lewat API langsung. **Ditutup**: `deactivate` kedua `409`.
3. Balapan baca-lalu-tulis di level transaksi. **Ditutup**: `UPDATE` mensyaratkan
   `status_aktif=1` dan memeriksa `rowsAffected`.
4. Retry jaringan setelah arsip sukses dianggap gagal. **Ditutup**: replay
   dengan kunci idempotensi yang sama tetap `200`.
5. Mutasi stok barang arsip lolos. **Sudah tertutup** sebelumnya
   (`422 INVENTARIS_NOT_AVAILABLE`), dikunci test lama.
6. Pembalik transaksi stok barang arsip. **Tetap** dibolehkan sebagai koreksi
   catatan lama; ada test yang menguncinya dan dicatat di `API.md`.
7. Barang arsip tidak bisa diubah meski salah input sejak awal. **Ditutup**:
   aktifkan kembali dulu, lalu ubah.
8. `obat`/`jenis-inventaris` arsip masih bisa diubah. **Tetap**: di luar
   permintaan "barang"; keduanya tidak punya endpoint aktifkan kembali sehingga
   memblokir akan mengunci permanen.
9. Kapsul pegawai nonaktif masih menampilkan ikon minus. **Sebagian tetap**:
   ikon minus adalah gaya status netral; teksnya kini "Nonaktif" sesuai maksud.
10. Kapsul profil sendiri ikut salah. **Ditutup** (cacat sekelas).
11. Label "Aktif" bertabrakan dengan tombol "Aktifkan"/"Nonaktifkan".
    **Aman**: pencocokan teks persis; test membedakan "Aktif" dari "Aktifkan".
12. Skala teks besar membuat kapsul meluber. **Aman**: test bug24 di skala 2.0
    tetap lulus dengan label baru.
13. Galeri komponen masih memakai "Aman"/"Kosong". **Tetap**: contoh komponen,
    bukan status akun nyata.
14. Data lama yang sudah terlanjur berubah setelah arsip. **Tidak diperiksa**:
    tidak ada akses data live dan tidak ada penanda andal kapan arsip terjadi
    dibanding kapan ubahan terjadi.

## Bukti yang dijalankan (hasil nyata)

```
$ cd apps/backend && npm test
i tests 480
i pass 480
i fail 0

$ npm run typecheck   # tsc --noEmit, tanpa output galat
$ npm run lint        # Checked 187 files, No fixes applied
$ npm run check:lines # Largest code file 246 lines (maksimum 300)

$ cd apps/mobile && flutter analyze
No issues found! (ran in 2.2s)

$ flutter test --concurrency=1
... +965: All tests passed!
```

Bukti aturan gagal pada kode lama (O-07):

```
$ git stash push -- apps/backend/src/features/inventory/store.ts \
    apps/backend/src/features/inventory/inventaris.ts
$ node --import tsx --test test/inventaris-archive-guard.test.js
Gagal dengan alasan benar, contoh:
  PATCH on archived ...        actual 200, expected 409
  archiving wins over a later edit ...  200 !== 409
  (respons PATCH lama berisi "nama_barang":"Dari B", "stok_minimum":"3")
$ git stash pop

$ git stash push -- apps/mobile/lib/views/v2/pages/v2_employee_detail_page.dart \
    apps/mobile/lib/views/v2/pages/v2_profile_detail_page.dart
$ flutter test test/v2_employee_status_badge_test.dart
Failing (3/3):
  detail pegawai aktif memakai kapsul "Aktif"
  detail pegawai nonaktif memakai kapsul "Nonaktif"
  detail profil sendiri memakai kapsul "Aktif"
$ git stash pop
```

## Real run

- Backend dijalankan lewat `app.inject` pada aplikasi Fastify nyata dengan
  database SQLite di memori (fixture), termasuk login pegawai sungguhan,
  pembuatan jenis dan barang, arsip, lalu PATCH/activate. Ini alur HTTP nyata,
  bukan unit palsu.
- Mobile dijalankan lewat widget test pada halaman `V2EmployeeDetailPage` dan
  `V2ProfileDetailPage` nyata (render penuh, bukan potongan komponen).
- Aplikasi Android di perangkat/emulator tidak dijalankan (tidak ada perangkat
  di lingkungan ini).

## Delivery Gate (outofthebox, DURING)

Block 1 - Hard Gate:
- [x] Tidak ada check yang menulis ke data dev/produksi (O-01/O-02). PASS: fixture SQLite memori.
- [x] Tidak ada PASS berdasarkan tebakan (O-03). PASS: setiap hasil dikutip dari perintah/test.
- [x] Tidak ada check yang dilonggarkan agar hijau (O-05). PASS: test lama diperbarui ke aturan baru, bukan dihapus.
- [x] Tidak ada sisa sementara (O-06). PASS: `git stash pop` mengembalikan file, tidak ada file sementara baru.

Block 2 - Must Probe:
- [x] Setiap check baru gagal pada kode lama dengan alasan benar (O-07). PASS: kutipan di atas (backend + mobile).
- [x] Setiap sumbu atlas ditelusuri atau disebut dilewati (O-08). PASS: 14 kasus di daftar risiko.
- [x] Data lama diperiksa dampaknya (O-09). PASS (terbatas): tidak ada akses data live; lihat butir 14 dan "Yang tidak diuji".
- [x] Suite penuh dijalankan dengan angka (O-10). PASS: backend 480/480, mobile 965/965.
- [x] Produk nyata dijalankan minimal sekali (O-11). PASS (parsial): inject HTTP nyata + widget page nyata; perangkat tidak tersedia.
- [x] Lingkungan kirim diuji (O-12). PASS: mesin dan versi yang sama dengan build.
- [x] Putaran terakhir tidak menemukan kasus baru. PASS: 14 kasus, tidak ada tambahan.

Block 3 - Quality Locks:
- [x] Dampak diurutkan (O-13), check deterministik (O-14), assertion pada nilai penting (O-15), daftar tak-teruji disebut (O-16).

## Yang tidak diuji

- Aplikasi Android di perangkat/emulator (tidak ada perangkat); status HP tetap `MANUAL-PENDING`.
- Balapan jaringan sungguhan antara dua klien pada database produksi (libsql
  remote). Yang diuji adalah urutan arsip lalu ubah dan penjagaan
  `rowsAffected`; isolasi transaksi remote tidak dapat direproduksi di fixture
  memori.
- Perbaikan data lama yang terlanjur berubah setelah arsip: tidak ada akses data
  live dan tidak ada penanda waktu arsip yang andal.
- Perilaku `obat`/`jenis-inventaris` arsip: sengaja tidak diubah (di luar
  cakupan "barang"), jadi masih bisa diubah lewat `PATCH` selama aktif/arsip.