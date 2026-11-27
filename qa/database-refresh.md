# Hasil — Refresh database backend + seeder sesuai aturan baru

Tanggal: 27 November 2026 · Branch: `wild-fe`
Rencana: `mcdocs/database-refresh-plan.md` · Tasks: `mcdocs/database-refresh-tasks.md`

## Ringkasan

| # | Permintaan | Hasil |
|---|---|---|
| 1 | Perintah `npm run` untuk refresh database | **Belum ada** sebelumnya. Ditambahkan `npm run db:refresh -- --allow-data-loss`. |
| 2 | Refresh mulai dari tabel + seed | Drop semua tabel (anak→induk), migrasi ulang, lalu seed. Dua kali berturut-turut berhasil. |
| 3 | Seeder menyesuaikan aturan baru | Benih penyemaian seed 600 → **250**, 400 → **150** (batas baru 250). |
| 4 | `jumlah_lubang` maksimal 250 | Backend 1000 → **250**. |
| 5 | `jumlah_benih` maksimal 250 | Backend 1.000.000 → **250**. |

## Perubahan berkas

- `apps/backend/src/db/refresh.ts` (baru)
  - `dropAllTables`: baca tabel + `PRAGMA foreign_key_list`, hitung urutan hapus
    anak→induk, hapus dalam satu transaksi.
  - `refreshDatabase`: hapus tabel lalu jalankan seluruh migrasi.
- `apps/backend/src/db/refresh-cli.ts` (baru)
  - Wajib `--allow-data-loss`; tolak remote/production tanpa `ALLOW_PROD_SEED=1`.
  - Cetak `DATABASE_URL` tujuan sebelum menghapus, lalu seed ulang.
- `apps/backend/package.json`: script `db:refresh`.
- `apps/backend/src/features/tables/contracts.ts`: `jumlah_lubang` maks 250.
- `apps/backend/src/features/nursery/contracts.ts`: `jumlah_benih` maks 250
  (create dan update).
- `apps/backend/src/db/seed.ts`: benih 250 dan 150.
- Uji: `apps/backend/test/refresh.test.js` (baru), `tables.test.js`,
  `validation-details.test.js`, `nursery.test.js`, `damage-restoration.test.js`.
- Dokumen: `apps/backend/API.md`, `apps/backend/README.md`,
  `docs/panduan-menjalankan-backend.md`.

## Bukti uji

| Perintah | Hasil |
|---|---|
| `npm run typecheck` | bersih |
| `npm run lint` | bersih (186 berkas) |
| `npm run check:lines` | bersih (berkas terbesar 246 baris) |
| Uji fokus (7 berkas) | **40 lulus / 40** |
| `npm test` (seluruh suite) | **474 lulus / 474**, tanpa gagal |

Kasus baru `test/refresh.test.js`:

1. Data lama (meja 999 lubang, semaian 9.999 benih, akun lama) hilang setelah
   refresh; migrasi dijalankan ulang dari nol; seed baru patuh aturan; kolom
   `id_katalog` ada.
2. CLI menolak jalan tanpa `--allow-data-loss`.
3. CLI menolak database remote tanpa `ALLOW_PROD_SEED=1`.

Kasus batas baru `test/nursery.test.js` (N-14): `jumlah_benih` 250 diterima,
251 ditolak, baik saat create maupun update.

## Uji end-to-end CLI (file sementara)

```
DATABASE_URL=file:/tmp/opencode/refresh-e2e.db npm run db:refresh -- --allow-data-loss
```

| Run | Hasil |
|---|---|
| 1 (database kosong) | 0 tabel dihapus, 24 migrasi, seed sukses |
| 2 (database terisi) | 35 tabel dihapus, 24 migrasi, seed sukses |

Verifikasi akhir: 35 tabel, 2 akun, 4 meja, benih maksimum 250, kolom
`id_katalog` ada.

## Refresh database remote (sudah dijalankan)

Target: `libsql://hidrosense-riverin.aws-ap-southeast-1.turso.io` (dari `.env`).

Sebelum refresh (dibaca hanya-baca):

- Migrasi **23 dari 24** (`0024_inventaris_katalog` belum masuk), sehingga
  `inventaris.id_katalog` tidak ada.
- Meja `M1` = 600 lubang, `M-06` = 999 lubang.
- Penyemaian 600, 400, 200.000, dan 1.000.000 benih.
- 6 akun, termasuk `tesgawai`, `rauda`, `rawl`, `wild`.

Perintah yang dijalankan (dengan izin client):

```
npm run db:refresh -- --allow-data-loss
```

Hasil dari perintah: **35 tabel lama dihapus, 24 migrasi diterapkan ulang**,
seed B000-B009 sukses.

Verifikasi setelah refresh (hanya-baca):

| Pemeriksaan | Hasil |
|---|---|
| Tabel | 35 |
| Migrasi | 24 |
| Akun | 2 (`petani`, `pegawai`); akun uji lama hilang |
| Meja | 4; tidak ada yang > 250 lubang (`M-01..M-03` 250, `M-04` 200) |
| Penyemaian | 2; benih maksimum 250 |
| `inventaris.id_katalog` | ada |
| Stok / pemindahan | 1 transaksi stok masuk / 1 pemindahan batch |
| Login API `petani` dan `pegawai` | `200`, token terbit (server lokal + DATABASE_URL remote) |

## Cara menjalankan refresh

```powershell
# lokal
npm run db:refresh -- --allow-data-loss

# remote Turso (butuh ALLOW_PROD_SEED=1 di .env)
npm run db:refresh -- --allow-data-loss
```

Untuk database lokal yang datanya masih dibutuhkan, backup dulu:
`npm run db:backup -- <nama-file>`.