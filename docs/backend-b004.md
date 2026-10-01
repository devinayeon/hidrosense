# B004 — Fondasi sinkronisasi server

Tanggal: 1 Oktober 2026. Cakupan B004 adalah fondasi integritas sinkronisasi; antrean perangkat, push/pull lintas seluruh fitur, dan UI konflik tetap B017/mobile.

## Review B000–B003

B000 menyediakan migrasi ber-checksum, rollback, backup, foreign key, dan database SQLite/libSQL. B001 menetapkan error boundary, HTTPS production, rate limit, dan kontrak ID string. B002 menyediakan sesi serta otorisasi yang dibaca ulang dari database. B003 membuktikan transaksi tulis dapat mengautentikasi ulang actor di dalam transaksi dan mencabut sesi secara atomik. B004 memakai batas-batas tersebut tanpa mengubah mobile atau BMKG.

## Implementasi

- Migrasi `0003_sync_foundation` menambah receipt operasi per pengguna, peta UUID klien ke UUID publik, dan tabel versi resource untuk dipakai slice tulis berikutnya.
- `POST /api/v1/sync/operations` memerlukan Bearer token dan hanya menerima `sync.reserve-id`. Operasi domain tidak dapat dideklarasikan selesai melalui endpoint ini; handler domain menjalankan perubahan dan receipt dalam transaksi sama.
- Pengiriman ulang isi sama mengembalikan receipt sama dengan 200. Key sama dan isi berbeda memberi `409 OPERATION_CONFLICT`. Operasi baru memberi 201 dan revision global sebagai cursor perubahan.
- Pasangan `resource_type` dan `client_id` menghasilkan `public_id` stabil. Seluruh pembacaan, mapping, receipt, dan respons berada dalam satu transaksi write setelah autentikasi ulang.

BFRI: fit 4, testability 5, kompleksitas 2, risiko data 2, risiko operasional 2; skor 3. Karena tetap menyentuh identitas dan transaksi, pengujian integrasi dan regresi migrasi dijalankan.

## Bukti

`test/sync.test.js` menguji replay, konflik, isolasi actor, mapping ID, penolakan tipe operasi domain, input salah, dan akses anonim. Pengujian B005 membuktikan receipt dan perubahan bisnis commit bersama. `test/migrations.test.js` menguji migrasi/backup/restore. Jalankan `npm run check` dan `npm run build` dari `apps/backend`.

## Koreksi audit dan batas arsitektur 2 Oktober 2026

Audit lintas B001–B005 menemukan bahwa atomisitas receipt B005 belum disertai pengikatan identitas publik dan kenaikan versi resource. Kesimpulan awal tanpa temuan tidak mencakup kewajiban lintas slice tersebut dan telah dikoreksi.

Interface sync sekarang menjadi pemilik hashing/canonical payload, replay/conflict, reservasi UUID publik, pengikatan resource domain, versi, dan receipt. Handler bisnis menjalankan mutasi melalui interface tersebut di dalam transaksi write yang sama. Autentikasi serta permission diperiksa ulang di transaksi sebelum efek bisnis; kegagalan membatalkan seluruh perubahan.

Endpoint `sync.reserve-id` tetap hanya mereservasi mapping UUID klien ke UUID publik, tidak menjalankan mutasi domain dan tidak menaikkan versi resource. Create B005 dapat memakai reservasi tersebut melalui `X-Client-Id`; UUID klien yang sudah terikat pada record tidak boleh membuat record kedua. Receipt mutasi B005 menyertakan `public_id` dan `version`, sedangkan `revision` tetap cursor receipt global. Replay mempertahankan respons dan versi yang disimpan pada operasi pertama.
