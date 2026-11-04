# Review Backend HidroSense

Tanggal review: 2026-11-04
Lokasi kode: `apps/backend`
Cakupan: arsitektur, stack, keamanan auth, konsistensi data, kualitas kode, dan pengujian.
> Koreksi: review ini hanya mencakup `main` lokal. `origin/main` berisi 24 commit lain, termasuk `features/sales`. Lihat [scope vs kode](review-and-rework/scope-vs-kode-2026-11-04.md).

Metode: membaca kode sumber inti (`app.ts`, `config.ts`, `common/*`, `db/client.js`, `features/auth/*`, `features/transfers/*`, `features/stock/store.ts`, migrasi 0002) dan menjalankan `npm run check`.

Hasil `npm run check` (typecheck, check:lines, test): **lulus. 246 test, 246 pass, 0 gagal.**

Catatan batasan: saya tidak membaca setiap file. Fitur `harvest`, `damage`, `nursery`, `inventory`, `accounts`, dan skrip `scripts/*` hanya saya lihat strukturnya. Temuan di bawah hanya berlaku untuk file yang saya baca.

---

## 1. Ringkasan singkat

Backend ini adalah API untuk aplikasi mobile Flutter HidroSense (budidaya selada hidroponik NFT). Kualitasnya jauh di atas rata-rata proyek eksperimen:

- Tulisan dibungkus transaksi yang mengecek sesi dan izin di dalam transaksi yang sama.
- Semua endpoint tulis wajib punya kunci anti-duplikat (idempotency key), dan ada test yang menjaga aturan itu.
- Token disimpan sebagai hash, password memakai scrypt, dan error tidak membocorkan detail internal.
- Ada 12 migrasi dengan file `down`, serta 246 test.

Kelemahan terbesarnya bukan pada bug, tetapi pada tiga hal: bagian database masih JavaScript yang tidak dicek tipenya, ada dua sistem validasi yang berjalan bersamaan, dan beberapa keputusan yang akan sulit bila beban bertambah (rate limit yang menulis ke DB di setiap request, tidak ada pembersihan sesi berkala).

---

## 2. Stack dan fungsinya

| Komponen | Versi | Fungsi di proyek ini |
|---|---|---|
| Node.js | ≥ 22.13 | Runtime. Memakai fitur bawaan: `--env-file`, `node:test`, `node:crypto` |
| TypeScript | 7.0.2 | Bahasa utama, mode `strict` |
| Fastify | 5.12.5 | Framework HTTP, routing, hook, logging (pino) |
| `@fastify/helmet` | 13.1.1 | Header keamanan HTTP |
| `@fastify/cors` | 11.3.0 | Aturan CORS |
| `@libsql/client` | 0.18.0 | Driver SQLite/libSQL, bisa lokal (`file:`) atau remote (Turso) |
| Zod | 4.6.5 | Validasi input dan konfigurasi |
| `tsx` | 4.23.15 | Menjalankan `.ts` langsung saat development dan test |

Semua dependensi dipasang dengan versi pasti (tanpa `^`). Ini praktik yang baik untuk build yang bisa diulang.

Tidak dipakai: ORM, framework test (Jest/Vitest), ESLint, Prettier. Semua query ditulis sebagai SQL mentah dengan parameter.

### Struktur

```
src/
  server.ts          titik masuk: baca config, buka DB, cek migrasi, jalankan app
  app.ts             rakit Fastify: hook, CORS, health check, daftar fitur
  config.ts          validasi environment dengan Zod
  common/            kode bersama: sessions, passwords, permissions, rate-limit,
                     sync (idempotency), validation, errors, authenticated-write
  db/                client, migrate, seed (campuran .js dan .ts)
  features/<domain>/ accounts, auth, damage, harvest, inventory, nursery,
                     stock, sync, tables, transfers
                     (pola: contracts -> service -> store -> write -> index)
migrations/          0001 sampai 0012, masing-masing ada .up.sql dan .down.sql
test/                37 file test
```

Pola per fitur: `contracts.ts` (bentuk data), `service.ts` (aturan bisnis), `store.ts` (SQL), `write.ts` (pembungkus tulis), `index.ts` (route). Pemisahan ini konsisten dan mudah diikuti.

---

## 3. Kenapa TypeScript, bukan JavaScript

Ini alasan yang bisa dipakai untuk menjelaskan pilihan tersebut, lengkap dengan bukti dari kode.

### 3.1 Perbedaan dasar

| | JavaScript | TypeScript |
|---|---|---|
| Pengecekan tipe | Saat program berjalan | Saat compile, sebelum program berjalan |
| Eksekusi | Langsung | Dikompilasi ke JS (`tsc`) atau dijalankan lewat `tsx` |
| Dukungan editor | Dasar | Autocomplete, navigasi, dan refactor yang jauh lebih kuat |
| Biaya | Tidak ada | Konfigurasi dan langkah build |

TypeScript tidak mengubah cara Node berjalan. Hasil akhirnya tetap JavaScript. Tipe hanya ada saat pengembangan dan hilang setelah kompilasi.

### 3.2 Alasan yang berlaku untuk HidroSense

1. **Data yang dikelola bernilai tinggi.** Backend mengurus stok, panen, pemindahan bibit, dan akun. Salah satu tipe saja (misalnya ID yang tertukar antara angka dan teks) bisa merusak saldo stok.
2. **Kontrak data yang eksplisit.** Setiap fitur punya `contracts.ts`. Compiler memaksa `service`, `store`, dan `write` memakai bentuk data yang sama.
3. **Refactor aman.** Proyek ini sudah melewati banyak putaran audit dan perbaikan (lihat riwayat commit). Tanpa tipe, setiap perubahan kontrak harus dicari manual di seluruh kode.
4. **ID 64-bit.** Kode memakai `CAST(id_user AS TEXT)` dan tipe `string` untuk menjaga ID SQLite 64-bit agar tidak terpotong oleh `number` JavaScript. Tipe membantu memastikan ID tidak pernah dipakai sebagai `number` secara tidak sengaja.
5. **Ekosistem sudah bertipe.** Fastify, Zod, dan libSQL membawa definisi tipe sendiri, jadi tidak ada biaya tambahan.
6. **TypeScript dan Zod saling melengkapi.** TypeScript menjaga kode di dalam program. Zod memeriksa data nyata dari luar (request dan environment) saat runtime. Tipe saja tidak melindungi dari input yang salah.

### 3.3 Kelemahan yang jujur
- Ada langkah build dan konfigurasi tambahan.
- Tipe tidak menggantikan test. Tipe hanya menjamin bentuk data, bukan kebenaran logika.
- Di proyek ini manfaat tipe belum penuh karena sebagian kode masih `.js` (lihat temuan T-01).

---

## 4. Yang sudah dikerjakan dengan baik

| Area | Bukti di kode |
|---|---|
| Transaksi dan otorisasi | `common/authenticated-write.ts`: sesi dan izin dicek ulang di transaksi yang sama dengan penulisan, rollback saat gagal, dan kegagalan rollback tidak menutupi error utama |
| Idempotency | `common/sync.ts`: payload di-hash dalam bentuk kanonik, retry mengembalikan resi lama, kunci yang sama dengan isi berbeda menghasilkan `409 OPERATION_CONFLICT` |
| Test penjaga | `write-wrapper-contract.test.js` memastikan setiap pembungkus tulis meminta kunci idempotency |
| Token | Token acak 32 byte, hanya hash SHA-256 yang disimpan, access token 15 menit, refresh token 7 hari, refresh bersifat sekali pakai lewat satu `UPDATE` bersyarat |
| Password | scrypt (N=32768, r=8, p=3), `timingSafeEqual`, dan pengguna yang tidak ada tetap membayar biaya derivasi (anti user enumeration lewat waktu respons) |
| Sesi terikat kredensial | `credential_hash` dibandingkan dengan `users.password`, jadi ganti password otomatis mematikan sesi lama |
| Rate limit login | Kunci per IP dan username, sehingga penyerang tidak bisa mengunci akun korban dari IP lain. Batas ini sudah didokumentasikan di komentar |
| Konfigurasi | Divalidasi Zod, CORS harus origin persis dan HTTPS di production, `TRUSTED_PROXIES` divalidasi sebagai IP/CIDR |
| Error | Pesan generik ke klien, log tidak memuat error mentah, ada `request_id` untuk pelacakan |
| Hardening HTTP | `bodyLimit` 16 KB, timeout 15 detik, helmet, `cache-control: no-store`, redaksi header `authorization` di log |
| Database | `PRAGMA foreign_keys = ON` diperiksa ulang, WAL untuk lokal, izin file 0600 di non-Windows, backup memakai `VACUUM INTO` |
| Stok | Saldo diperbarui dengan `UPDATE ... WHERE saldo + delta BETWEEN 0 AND batas`, jadi saldo negatif ditolak di level SQL, bukan hanya di kode |
| Struktur dan disiplin | Ada `check:lines` untuk membatasi ukuran file, pola fitur konsisten |

---

## 5. Temuan

Tingkat: **Tinggi** = sebaiknya dikerjakan sebelum rilis. **Sedang** = dikerjakan pada iterasi berikut. **Rendah** = perbaikan kualitas.

### T-01 (Sedang) Lapisan database tidak dicek tipenya
- **Bukti:** `tsconfig.json` memakai `allowJs: true` dan `checkJs: false`. `src/db/client.js`, `migrate.js`, `cli.js`, dan `harvest-weights.js` adalah JavaScript.
- **Dampak:** `openDatabase()` dipakai di `server.ts` dengan tipe yang disimpulkan seadanya (`Awaited<ReturnType<typeof openDatabase>>`). Bagian paling sensitif (koneksi, PRAGMA, migrasi, backup) justru tanpa jaring pengaman tipe.
- **Saran:** ubah `src/db/*.js` menjadi `.ts`, lalu matikan `allowJs`. Pekerjaan kecil karena file-nya hanya sekitar 60 sampai 90 baris.

### T-02 (Sedang) Dua sistem validasi berjalan bersamaan
- **Bukti:** `auth/login.ts` dan `auth/refresh.ts` memakai JSON Schema Fastify (Ajv) dan mendeklarasikan tipe `Body` terpisah. Fitur lain memakai Zod lewat `parseInput`.
- **Dampak:** tipe `{ username: string; password: string }` ditulis tangan di samping schema, sehingga keduanya bisa tidak sinkron tanpa ketahuan compiler. Pesan error juga dibentuk dari dua jalur berbeda.
- **Saran:** pilih satu. Zod dengan `fastify-type-provider-zod` memberi tipe otomatis dari schema. Kalau tidak mau menambah dependensi, pindahkan login dan refresh ke Zod + `parseInput`.

### T-03 (Sedang) Rate limit menulis ke database pada setiap request
- **Bukti:** `app.ts` memanggil `consumeLimit(db, 'ip:...', 120, 60000, ...)` di hook `onRequest` untuk semua `/api/`. Itu satu `INSERT ... ON CONFLICT DO UPDATE` per request.
- **Dampak:** setiap request, bahkan GET ringan, melakukan satu penulisan. Klien dibuka dengan `concurrency: 1`, jadi semua query antre di satu koneksi. Dengan Turso remote, setiap penulisan juga satu round trip jaringan. Ini menjadi bottleneck pertama saat pengguna bertambah.
- **Catatan:** untuk skala satu kebun dan beberapa pegawai, ini aman. Risikonya muncul bila trafik naik.
- **Saran:** simpan rate limit umum per IP di memori (Map dengan jendela waktu, atau `@fastify/rate-limit`), dan pertahankan versi DB hanya untuk login yang butuh bertahan antar restart.

### T-04 (Sedang) Pembersihan sesi hanya terjadi saat server menyala
- **Bukti:** `DELETE FROM auth_sessions WHERE refresh_expires_at<=?` dan penghapusan `auth_rate_limits` hanya ada di `server.ts` (saat boot). Tidak ada `setInterval` atau job berkala.
- **Dampak:** proses yang berjalan berminggu-minggu menumpuk baris kedaluwarsa. Tidak berbahaya untuk keamanan (query autentikasi sudah memfilter waktu), tetapi tabel terus membesar.
- **Saran:** jalankan pembersihan berkala (misalnya tiap jam) dengan `setInterval(...).unref()`, atau lakukan secara oportunistik saat login.

### T-05 (Sedang) Refresh tidak memperpanjang masa sesi, dan tidak ada deteksi pemakaian ulang
- **Bukti:** `auth/refresh.ts` memperbarui `access_expires_at` tetapi tidak `refresh_expires_at` (nilainya dibatasi `MIN(?, refresh_expires_at)`). Refresh token lama yang dipakai lagi hanya menghasilkan 401.
- **Dampak:**
  1. Pengguna dipaksa login ulang tepat 7 hari setelah login pertama, walaupun aktif setiap hari. Untuk petani yang memakai aplikasi di lapangan, ini bisa mengganggu.
  2. Jika refresh token dicuri dan dipakai lebih dulu, pengguna asli hanya mendapat 401 tanpa tanda adanya pencurian.
- **Saran:** putuskan kebijakannya secara sadar. Pilihan umum adalah sliding window (perpanjang saat refresh, dengan batas mutlak, misalnya 30 hari) dan mencabut seluruh sesi saat refresh token lama dipakai ulang.

### T-06 (Sedang) Verifikasi password memakai threadpool bersama
- **Bukti:** `passwords.ts` memakai `crypto.scrypt` asinkron dengan N=32768, p=3, dan `maxmem` 64 MB.
- **Dampak:** scrypt berjalan di threadpool libuv (bawaan 4 thread) yang dipakai juga oleh operasi file dan DNS. Pembatasan login adalah 10 percobaan per IP+username dan 120 request per menit per IP. Beberapa IP berbeda yang mengirim login bersamaan dapat menahan threadpool dan menunda request lain. Komentar di `login.ts` sudah mengakui bahwa batas per akun lintas IP sengaja tidak ada.
- **Saran:** ukur waktu satu hash di server target. Jika di atas sekitar 150 ms, turunkan `p` atau naikkan `UV_THREADPOOL_SIZE`. Pertimbangkan batas konkurensi untuk verifikasi password.

### T-07 (Rendah) Tidak ada jalur peningkatan parameter hash password
- **Bukti:** `verifyPassword` memakai regex yang menetapkan `scrypt$32768$8$3$` secara literal. Hash dengan parameter lain dianggap tidak valid.
- **Dampak:** jika suatu saat parameter dinaikkan, semua password lama gagal diverifikasi, dan tidak ada mekanisme rehash saat login berhasil.
- **Saran:** baca N, r, p dari string hash, lalu rehash otomatis saat login bila parameternya tertinggal.

### T-08 (Rendah) Test tidak dicek tipenya
- **Bukti:** 37 file test semuanya `.js`. `tsconfig.json` hanya menyertakan `src/**`.
- **Dampak:** test bisa memanggil fungsi dengan argumen yang salah tanpa peringatan compiler. Saat kontrak berubah, test rusak diam-diam atau lulus karena alasan yang salah.
- **Saran:** pindahkan test ke `.ts` secara bertahap, mulai dari test yang paling sering berubah.

### T-09 (Rendah) Tidak ada linter dan formatter
- **Bukti:** `package.json` tidak memuat ESLint, Prettier, atau Biome.
- **Dampak:** gaya kode dijaga manual. Pola seperti `catch {}` kosong, variabel tak terpakai (`_sessionId` di `createSession`), dan impor yang tidak terpakai tidak terdeteksi otomatis.
- **Saran:** tambahkan Biome atau ESLint dengan aturan `@typescript-eslint/no-floating-promises` (sangat berguna di kode async seperti ini) dan jalankan di `npm run check`.

### T-10 (Rendah) Health check membaca file migrasi pada setiap panggilan
- **Bukti:** `/health/ready` memanggil `loadMigrations()` (membaca direktori) lalu `migrationStatus` (query DB) setiap kali.
- **Dampak:** load balancer atau Docker yang memeriksa tiap beberapa detik menimbulkan I/O disk dan query berulang. Biaya kecil, tetapi tidak perlu.
- **Saran:** simpan daftar migrasi yang dimuat sekali saat start, lalu cukup cek status di DB.

### T-11 (Rendah) Zona waktu WIB ditulis langsung di service
- **Bukti:** `transfers/service.ts` menghitung `today` dengan `now + 7 * 60 * 60 * 1000`.
- **Dampak:** aturan "tanggal pemindahan tidak boleh di masa depan" bergantung pada UTC+7 yang ditanam di kode. Aman selama kebun ada di WIB. Berubah menjadi bug bila ada kebun di WITA/WIT.
- **Saran:** jadikan offset zona waktu sebagai konfigurasi, atau pakai `Intl.DateTimeFormat` dengan `Asia/Jakarta`. Satu helper bersama akan dipakai ulang di fitur lain.

### T-12 (Rendah) Metadata `package.json` belum benar
- **Bukti:** `"description": "HidroSense backend database setup and SQLite/libSQL migrations"` (sudah jauh lebih luas dari itu), `"author": ""`, `"license": "ISC"`, `"keywords": []`.
- **Saran:** perbarui deskripsi. Pastikan lisensi sesuai kebutuhan, karena `private: true` sudah dipakai.

### T-13 (Info) Versi TypeScript 7.0.2
- Typecheck dan seluruh test lulus pada versi ini, jadi tidak ada masalah saat ini. TypeScript 7 adalah generasi baru dengan kompiler yang ditulis ulang. Jika menambah tooling (linter, type provider), pastikan kompatibel dengan versi ini sebelum memutuskan.

---

## 6. Hal yang belum diperiksa

Agar tidak ada kesan bahwa semuanya sudah aman, ini bagian yang belum saya telaah:

- Endpoint baca (GET): bagaimana otentikasi dan izin diterapkan di `index.ts` tiap fitur. Hanya jalur tulis yang saya baca.
- Fitur `harvest`, `damage`, `nursery`, `inventory`, `accounts` secara mendalam.
- Skrip operasional `scripts/*` (deploy migrasi Turso, rekonsiliasi stok) dan keamanan penanganan token Turso.
- Isi migrasi 0003 sampai 0012 dan apakah semua file `down` benar-benar bisa dijalankan tanpa kehilangan data.
- Perilaku di bawah beban nyata. Tidak ada uji beban, sehingga catatan T-03 dan T-06 berupa analisis kode, belum pengukuran.
- Integrasi dengan aplikasi mobile (kontrak sinkronisasi offline dari sisi Flutter).

---

## 7. Rekomendasi urutan kerja

| Prioritas | Pekerjaan | Temuan | Perkiraan usaha |
|---|---|---|---|
| 1 | Putuskan kebijakan sesi: perpanjangan refresh dan deteksi pemakaian ulang | T-05 | Sedang |
| 2 | Konversi `src/db/*.js` ke TypeScript, matikan `allowJs` | T-01 | Kecil |
| 3 | Satukan validasi ke Zod | T-02 | Kecil |
| 4 | Pembersihan sesi berkala | T-04 | Kecil |
| 5 | Pindahkan rate limit umum ke memori, simpan versi DB untuk login | T-03 | Sedang |
| 6 | Ukur waktu scrypt, tetapkan ukuran threadpool | T-06 | Kecil |
| 7 | Tambah linter dengan `no-floating-promises` | T-09 | Kecil |
| 8 | Konversi test ke TypeScript bertahap | T-08 | Besar |
| 9 | Sisanya (T-07, T-10, T-11, T-12) | | Kecil |

Setelah itu, lanjutkan review ke bagian yang belum diperiksa pada bagian 6, dimulai dari jalur baca (GET) dan skrip operasional.
