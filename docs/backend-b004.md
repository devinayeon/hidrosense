# B004 — Fondasi sinkronisasi server

Tanggal: 1 Oktober 2026. Cakupan B004 adalah fondasi integritas sinkronisasi; antrean perangkat, push/pull lintas seluruh fitur, dan UI konflik tetap B017/mobile.

## Review B000–B003

B000 menyediakan migrasi ber-checksum, rollback, backup, foreign key, dan database SQLite/libSQL. B001 menetapkan error boundary, HTTPS production, rate limit, dan kontrak ID string. B002 menyediakan sesi serta otorisasi yang dibaca ulang dari database. B003 membuktikan transaksi tulis dapat mengautentikasi ulang actor di dalam transaksi dan mencabut sesi secara atomik. B004 memakai batas-batas tersebut tanpa mengubah mobile atau BMKG.

## Implementasi

- Migrasi `0003_sync_foundation` menambah receipt operasi per pengguna, peta UUID klien ke UUID publik, dan tabel versi resource untuk dipakai slice tulis berikutnya.
- `POST /api/v1/sync/operations` memerlukan Bearer token. `operation_key` UUID terikat ke pengguna; hash payload kanonik membuat urutan properti JSON tidak mengubah identitas operasi.
- Pengiriman ulang isi sama mengembalikan receipt sama dengan 200. Key sama dan isi berbeda memberi `409 OPERATION_CONFLICT`. Operasi baru memberi 201 dan revision global sebagai cursor perubahan.
- Pasangan `resource_type` dan `client_id` menghasilkan `public_id` stabil. Seluruh pembacaan, mapping, receipt, dan respons berada dalam satu transaksi write setelah autentikasi ulang.

BFRI: fit 4, testability 5, kompleksitas 2, risiko data 2, risiko operasional 2; skor 3. Karena tetap menyentuh identitas dan transaksi, pengujian integrasi dan regresi migrasi dijalankan.

## Bukti

`test/sync.test.js` menguji replay, konflik, isolasi actor, canonical JSON, mapping ID, input salah, dan akses anonim. `test/migrations.test.js` menguji migrasi/backup/restore. Jalankan `npm run check` dan `npm run build` dari `apps/backend`.
