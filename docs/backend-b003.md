# B003 — Akun pegawai dan profil

Tanggal: 1 Oktober 2026. B003 adalah alias B03 pada [rencana backend](./rencana-backend.md).

## Keputusan dan batas pekerjaan

- Pengelolaan pegawai hanya untuk petani (`pegawai:manage`). Profil sendiri hanya untuk petani (`profil:read/write`) sesuai PB-11. Pegawai tetap dapat melihat identitas sesi melalui `/auth/me`.
- Sistem saat ini melayani satu kebun sesuai skema tim; tidak ada model tenant atau kepemilikan pegawai per petani. Semua petani yang sah mengelola daftar pegawai yang sama.
- Endpoint pegawai selalu membatasi target ke role `pegawai`. Endpoint profil mengambil ID dari sesi, bukan body atau parameter klien.
- Penonaktifan mengubah `status_aktif` menjadi 0 dan menghapus seluruh sesi akun dalam satu transaksi. Catatan pengguna dan transaksi budidaya tetap tersimpan. Pengulangan penonaktifan menghasilkan 204.
- Perubahan username atau password mencabut seluruh sesi target, termasuk sesi petani yang sedang mengubah profil. Perubahan kontak/nama mempertahankan sesi.
- Petani dapat mereset password pegawai. Perubahan username/password profil sendiri memerlukan `current_password` yang benar. Tidak tersedia registrasi publik, penghapusan akun, perubahan role, atau aktivasi kembali.
- B003 menggunakan tabel `users`, `roles`, dan `auth_sessions` yang sudah ada. Tidak membutuhkan migrasi baru, dependency runtime baru, atau perubahan mobile.

## Breakdown implementasi

| ID | Hasil | Bukti penerimaan |
| --- | --- | --- |
| B003.1 | Kontrak input, respons akun aman, ID, dan pagination | Field asing/role/status ditolak; password tidak masuk respons; parameter SQL dibind |
| B003.2 | `create-employee` | 201; role dipilih server; password di-hash; username global duplikat menghasilkan 409 |
| B003.3 | `list-employees` dan `get-employee` | Pagination default 20/maksimum 100; filter aktif; urutan ID stabil; akun petani tidak muncul |
| B003.4 | `update-employee` | PATCH parsial; kontak nullable; reset kredensial mencabut sesi; konflik tidak menyimpan perubahan sebagian |
| B003.5 | `deactivate-employee` | Status dan pencabutan sesi atomik; histori tetap; login/refresh ditolak sesudah nonaktif |
| B003.6 | `get-profile` dan `update-profile` | Identitas dari sesi; verifikasi password untuk kredensial; eskalasi role/status ditolak |
| B003.7 | Pengujian dan dokumentasi | Tes endpoint, izin, konflik bersamaan, rollback paksa, regresi B001/B002, typecheck, build, batas baris |

## Pola implementasi

Folder `apps/backend/src/features/accounts` mempertahankan vertical slice. Setiap handler memiliki satu use case. `contracts.ts` menjadi sumber validasi dan inferred types Zod; `store.ts` membagi pemetaan respons dan operasi database yang benar-benar digunakan beberapa slice.

Validasi menerima `unknown`, menolak field di luar daftar, dan mengubah kegagalan menjadi envelope `VALIDATION_ERROR`. Username tetap case-sensitive. Hashing password dilakukan sebelum membuka transaksi write agar lock database tidak ditahan selama scrypt. Otorisasi diulang di dalam transaksi untuk menolak sesi yang sudah dicabut/kedaluwarsa atau role yang berubah selama hashing. Pemeriksaan username unik dan penulisan terjadi dalam transaksi yang sama; unique constraint database tetap berlaku.

Nama kolom UPDATE hanya berasal dari whitelist kode. Respons dipetakan eksplisit, sehingga hash, ID sesi, dan token tidak ikut keluar. Read batch menggunakan snapshot yang sama untuk jumlah total dan halaman hasil. Seluruh request tetap melewati rate limit database bersama, error handler, HTTPS production, dan logging B001.

Patch kontak serentak mengikuti urutan commit; perubahan field berbeda tidak menimpa kolom yang tidak dikirim. Versi sumber daya dan idempotency key bisnis tetap menjadi B04. Retry create dengan username sama menghasilkan 409; klien dapat memeriksa daftar sebelum mencoba lagi. Penonaktifan dapat diulang dengan aman.

## Pengujian

Jalankan dari `apps/backend`:

```powershell
npm run check
npm run build
```

- `test/accounts.test.js`: alur CRUD terbatas, role, validasi, ID, pagination, duplicate create bersamaan, reset password, serta preservasi histori saat nonaktif.
- `test/profile.test.js`: profil sendiri, kontak nullable, penolakan role/status/ID klien, verifikasi password, konflik username, serta pencabutan semua sesi.
- `test/accounts-transactions.test.js`: trigger SQLite memaksa kegagalan DELETE sesi untuk membuktikan rollback perubahan akun; penolakan actor yang dicabut/diturunkan/kedaluwarsa; refresh bersamaan dengan deactivation; SQL-like input sebagai data.
- Tes B001/B002 dan migrasi tetap dijalankan. Seluruh fixture memakai database uji; tidak membuat akun atau mengubah data produksi/lokal pengguna.

Pengujian lokal tidak membuktikan deployment Turso remote, reverse proxy produksi, atau integrasi perangkat mobile. Pengujian staging Turso tetap dijadwalkan pada B18.

Hasil 1 Oktober 2026: `npm run check` lulus dengan 47 tes (29 regresi dan 18 tes akun/profil), typecheck lulus, serta `npm run build` lulus. File kode terbesar tetap `migrations/0001_initial_schema.up.sql` sebanyak 234 baris, di bawah batas 400 baris.

## Perbaikan review B003

Review setelah implementasi menemukan dan memperbaiki dua celah pada autentikasi akun B003.

- Login kini menyertakan username yang telah diverifikasi dalam `INSERT ... SELECT` pembuat sesi. Jika username berubah setelah pembacaan kredensial, penulisan sesi bersyarat gagal dengan 401; sesi baru tidak dapat melewati pencabutan saat rename.
- Query autentikasi memproyeksikan `users.id_user` sebagai TEXT. ID SQLite 64-bit di atas batas integer aman JavaScript kini tetap berupa string pada login, pembuatan sesi, dan `/auth/me`.

Tes regresi mensimulasikan login yang berhenti setelah pembacaan kredensial lalu username berubah, serta akun baru dengan ID `9007199254740992`. Perbaikan tidak membutuhkan migrasi dan tidak mengubah mobile.

## Review B001/B002

Lihat [laporan review](./review-backend-b001-b002.md). Kontrak lengkap B003 tersedia pada [API akun/profil](./backend-accounts-api.md). Tahap berikutnya B004/B04; BMKG tetap B19.
