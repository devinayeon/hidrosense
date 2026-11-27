# QA — Perbaikan modul Inventaris (sesi 10)

Tanggal: **27 November 2026**. Branch kerja: `wild-fe`.
Permintaan client (uji manual di HP): perbaikan alur **Tambah**, **Ubah**, dan
**Arsipkan** barang. Rencana: `mcdocs/inventaris-perbaikan-plan.md`; task:
`mcdocs/inventaris-perbaikan-tasks.md`.

Status yang dipakai: `PASS`, `FAIL`, `BLOCKED`, `MANUAL-PENDING`.
Tidak menyentuh data atau kredensial produksi.

## Lingkungan

- Linux x86_64; Node v22.23.1; npm 10.9.8; Flutter 3.47.7 (stable).
- Backend diuji dengan `npm test` (SQLite sementara per-suite).
- Mobile diuji dengan `flutter analyze` + `flutter test --concurrency=1`.
- Perangkat Android: **tidak ada** di lingkungan ini, jadi verifikasi visual di HP
  tetap `MANUAL-PENDING` (lihat `qa/manual_checklist.md` §Sesi 10).

## Ringkasan hasil

| Permintaan | Perubahan | Status |
|---|---|---|
| Nama barang unik (Tambah) | Cek keunikan semua status, tanpa beda huruf besar/kecil → `409 INVENTARIS_NAME_TAKEN`; form memetakan ke kolom nama | `PASS` |
| Batas stok awal & stok minimum (Tambah) | Stok awal wajib, ≥ 0, maks 10 digit + 2 desimal; stok minimum > 0 dan ≤ stok awal; pesan inline, form tetap terbuka | `PASS` |
| Jenis Obat: sembunyikan "Nama barang", sumber dropdown `obat_katalog` | Kolom nama diganti pemilih obat; optional dan wajib saat jenis Obat; `id_katalog` + `nama_katalog` dari tabel katalog | `PASS` |
| Galat stok minimum di form (Ubah) | Validasi stok minimum dijalankan di form sesuai penyebab, tidak lagi muncul terlambat di detail | `PASS` |
| Aktifkan kembali barang arsip | Endpoint `POST /inventaris/:id/activate` + tombol "Aktifkan kembali" dengan konfirmasi dan toast di daftar | `PASS` |

## Bukti backend (`apps/backend`)

| Perintah | Hasil |
|---|---|
| `npm run typecheck` | bersih (tanpa galat) |
| `npm run lint` | 183 berkas, tanpa temuan |
| `npm run check:lines` | berkas terbesar `src/features/weather/service.ts` (246/300 baris) |
| `npm test` | **470/470 lulus, 0 gagal** |

Test inventaris yang ditambah/diperbarui (`test/inventory.test.js`,
`test/inventory-id-boundaries.test.js`):

- Nama barang unik ditolak (aktif vs aktif, aktif vs arsip, beda huruf besar/kecil).
- Nama diturunkan dari `obat_katalog.bahan_aktif` saat `id_katalog` diisi.
- `id_obat` dan `id_katalog` tidak boleh terisi bersamaan (`400 VALIDATION_ERROR`).
- `id_katalog` tak dikenal ditolak (`422 KATALOG_NOT_FOUND`).
- Aktivasi aman dipanggil berulang; barang arsip kembali aktif.
- Katalog hanya bisa dibaca pengguna berizin `inventaris:read`.

Catatan regresi: `test/inventory-id-boundaries.test.js` sempat membuat dua barang
bernama `'Large references'` sehingga bentrok dengan aturan nama unik; diubah jadi
`Large references ${id}`. Sejak itu seluruh suite hijau.

## Bukti mobile (`apps/mobile`)

| Perintah | Hasil |
|---|---|
| `flutter analyze` | `No issues found!` |
| `flutter test --concurrency=1` | **892 lulus, 0 gagal** |
| Test fokus inventaris + mapper + repo | 49/49 lulus |

Test widget baru (`test/v2_inventaris_form_fixes_test.dart`):

- Jenis Obat menyembunyikan kolom "Nama barang" dan mewajibkan pemilihan obat.
- Stok minimum tidak boleh melebihi stok awal saat menambah.
- Stok awal menolak bentuk angka tidak sah (`1.234`).
- Ubah barang: galat stok minimum tampil di form (nilai `0`, dan bentuk angka salah).
- Nama barang duplikat dari server (`INVENTARIS_NAME_TAKEN`) tampil di kolom nama,
  form tetap terbuka.
- Detail barang arsip punya tombol "Aktifkan kembali".
- Repository mengirim `id_katalog` (tanpa `id_obat`) dan memanggil
  `inventaris/:id/activate`.

Test prasyarat (`test/v2_inventaris_tambah_prasyarat_test.dart`) disesuaikan agar
memeriksa pemuatan `GET /api/v1/obat-katalog` (dulu `GET /api/v1/obat`) sebelum
tombol Tambah ditekan.

## Rincian implementasi

### Backend

- Migrasi `0024_inventaris_katalog`: kolom `inventaris.id_katalog` (FK ke
  `obat_katalog`) + indeks `idx_inventaris_katalog`; rollback tersedia dan lulus
  `full-flow.test.js` (migrasi up/down/up).
- `GET /api/v1/obat-katalog` (izin `inventaris:read`, paginasi) mengembalikan
  `id_katalog`, `nama` (= `bahan_aktif`), `jenis`.
- `createInventarisSchema` menerima `id_katalog` (opsional) dan `nama_barang`
  menjadi opsional; `id_obat`/`id_katalog` saling meniadakan; server menurunkan
  nama dari katalog.
- `assertNamaBarangAvailable` menolak nama duplikat (`409 INVENTARIS_NAME_TAKEN`).
- `POST /api/v1/inventaris/:id/activate` mengembalikan data barang dan aman
  dipanggil berulang.
- Respons daftar/detail menambah `id_katalog` + `nama_katalog`; `API.md` diperbarui.

### Mobile

- `ObatKatalogRecord` + `fetchObatKatalog` + provider `obatKatalogProvider`.
- `InventoryRecord`: `katalogId`, `katalogName`; `v2InventarisItemFromRecord`
  menandai sumber (`medicineKatalog`) sesuai `id_katalog`.
- `InventoryDraft`: `medicineId` (master `obat`) dan `katalogId` (katalog);
  hanya satu yang terisi. `InventoryRepository` mengirim `id_katalog`/`id_obat`
  sesuai sumber, plus `activateItem`. Antrean sinkronisasi (`v2_inventory_sender`)
  ikut menyertakan kedua kunci.
- Form: kolom "Nama barang" hanya untuk non-Obat; obat wajib dipilih saat jenis
  Obat; validasi stok awal/minimum inline; galat `INVENTARIS_NAME_TAKEN`
  dipetakan ke kolom yang benar.
- Detail: footer "Aktifkan kembali" untuk barang arsip (frame 4.29 tidak diubah
  saat galeri); daftar memberi toast setelah pemulihan.

## Sisa / catatan

- **Verifikasi visual di HP tetap wajib** oleh dev FE (`MANUAL-PENDING`).
  Langkah uji perbaikan ada di `qa/manual_checklist.md` §Sesi 10 (MC-FIX-70a..e).
- `apps/mobile/android/app/src/main/res/xml/network_security_config.xml` dan
  `apps/mobile/pubspec.lock` sengaja **tidak** ikut di-commit (perubahan lokal
  lingkungan uji).
