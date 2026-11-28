# Hasil — Migrasi 0026 gagal 502 di Turso (sesi 11)

Tanggal: 28 November 2026 · Branch: `wild-fe`
Catatan investigasi lengkap: `mcdocs/migrasi-0026-turso-502.md`

## Ringkasan

| # | Gejala | Hasil |
|---|---|---|
| 1 | `db:migrate` menambah `0026_ai_stok_rotasi` → `SERVER_ERROR: Server returned HTTP status 502` | Tidak lagi 502; 26/26 migrasi `applied` di Turso. |
| 2 | Setelah gagal, `db:status` menampilkan **semua** migrasi `pending` | Normal: `migrate()` memakai satu transaksi untuk semua migrasi, jadi satu gagal = semua rollback (efek samping, bukan penyebab). |

## Akar masalah

`0026_ai_stok_rotasi.up.sql` memuat `INSERT INTO merek_bahan ... VALUES (...)` dengan **~100 baris
sekaligus** (banyak subquery skalar `(SELECT id_katalog FROM obat_katalog WHERE bahan_aktif = '...')`).
Satu pernyataan seberat itu membuat instance upstream Turso mati/tak terhubung. Badan respons mentah Turso
(via wrap `fetch`): `{"error":"upstream forward failed"}` lalu `{"error":"connect to upstream failed"}` —
gateway balas 502. Ini batas/instabilitas sisi server, bukan error SQL: lokal 26 migrasi sukses ~41 ms.

Penting: **fix `chunkSql` per 32 KiB (commit `4988be3`) tidak cukup.** Diuji langsung ke Turso, chunk ke-10
(~28 KB, memuat `INSERT merek_bahan`) tetap 502. Jadi memecah *request* bukan solusinya; yang harus dipecah
adalah *jumlah baris per INSERT*.

## Perubahan berkas

- `apps/backend/migrations/0026_ai_stok_rotasi.up.sql`
  - Setiap `INSERT INTO merek_obat` / `merek_bahan` dipecah menjadi pernyataan maksimal **50 baris**.
  - Data tuple **identik dan urutan sama**: 2769 `merek_obat`, 3427 `merek_bahan`.
- `docs/data/registri/susun_merek.py`
  - `ROWS_PER_STATEMENT = 50` (dulu 100) agar regenerasi tidak mengulang masalah.

## Bukti uji

| Perintah | Hasil |
|---|---|
| `npm run check` (lokal) | **518 lulus / 518**, lint bersih |
| `npm run db:migrate` (Turso) | 26/26 `applied` |
| `ALLOW_PROD_SEED=1 npm run db:seed` (Turso) | sukses, akun uji + data domain siap |
| Verifikasi isi DB | 26 migrasi, 2769 merek_obat, 3427 merek_bahan, 29 obat_katalog, 2 users, 4 meja_tanam, `foreign_key_check` = 0 pelanggaran |

Bukti pemecahan (sebelum fix, satu transaksi lalu rollback di Turso):

| Varian | Hasil |
|---|---|
| 0026 asli | ❌ 502 di statement 42/77 |
| Pecah 2 (~50 baris/stmt) | ✅ |
| Pecah 3 (~34) | ✅ |
| Pecah 4 (~25) | ✅ |
| Pecah 10 | ✅ |

## Catatan

- Perubahan menyentuh migrasi yang sudah ada. Aman karena 0026 belum pernah ter-apply sukses di DB mana pun
  (remote saat itu semua `pending`). DB lokal yang sudah ter-apply 0026 perlu di-refresh karena checksum berubah.
- Kedua lapisan tetap dipakai: `chunkSql` per request (`4988be3`) + INSERT kecil (`01692bb`).
