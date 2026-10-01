# Review dan perbaikan B003

Tanggal: 1 Oktober 2026. Cakupan: autentikasi yang dipakai B003, endpoint akun/profil, transaksi sesi, dan tes regresi. Mobile, BMKG, serta Turso remote di luar cakupan.

## Temuan yang telah diperbaiki

| Severity | Temuan | Perbaikan | Bukti regresi |
| --- | --- | --- | --- |
| P2 | Login lama dapat membuat sesi setelah username target diganti | `createSession` kini memeriksa ID, username, password, status, dan role dalam satu `INSERT ... SELECT` | `auth.test.js`: login berhenti setelah lookup, rename berhasil, login lama mendapat 401 dan tidak ada sesi baru |
| P2 | ID `9007199254740992` dapat dibuat tetapi login menghasilkan 500 | Semua query autentikasi yang mengembalikan `id_user` memakai `CAST(... AS TEXT)` | `auth.test.js`: create, login, dan `/auth/me` akun ID 64-bit berhasil dengan ID string tepat |

## Penerapan guideline

`backend-dev-guidelines` dipakai untuk menilai risiko dan menetapkan perbaikan. BFRI perbaikan: architectural fit 4, testability 5, complexity 2, data risk 3, operational risk 4; skor 0. Karena menyentuh autentikasi dan sesi, perubahan diisolasi pada slice auth, menggunakan parameter SQL terikat, tidak mengubah skema, dan memiliki tes integrasi deterministik.

Proyek memakai Fastify dan pola vertical-slice yang sudah ditetapkan pada rencana backend. Panduan route/controller/service/repository untuk Express/Prisma tidak dipaksakan menjadi refactor lintas arsitektur. Validasi input, error boundary terpusat, logging terstruktur, dan konfigurasi yang sudah ada tetap digunakan.

## Validasi

Jalankan dari `apps/backend`:

```powershell
npm run check
npm run build
```

Hasil harus mencakup tes autentikasi stale-username dan ID 64-bit bersama seluruh regresi B001-B003. Pengujian lokal tidak menggantikan staging Turso atau verifikasi reverse proxy produksi.
