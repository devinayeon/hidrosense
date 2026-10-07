# Panduan Menjalankan Backend HidroSense

Panduan ini mencakup migrasi database, seeder data uji, menjalankan API, dan
memverifikasi fitur backend.

## Prasyarat

- Node.js `>=22.13`
- npm
- PowerShell

Semua perintah pada panduan ini dijalankan dari direktori `apps/backend`.

```powershell
cd apps/backend
npm ci
```

## 1. Menyiapkan konfigurasi database

Salin konfigurasi contoh hanya jika file `.env` belum tersedia:

```powershell
Copy-Item .env.example .env
```

Konfigurasi default menggunakan SQLite lokal pada
`apps/backend/data/hidrosense.db`:

```dotenv
DATABASE_URL=file:./data/hidrosense.db
```

Path `file:` selalu relatif terhadap `apps/backend`, bukan terhadap direktori
tempat perintah dipanggil. Untuk Turso/libSQL, isi `DATABASE_URL` dan
`DATABASE_AUTH_TOKEN` dengan kredensial database yang sesuai. Jangan commit
file `.env` atau token ke repository.

## 2. Menjalankan migrasi

Periksa target dan status migrasi terlebih dahulu:

```powershell
npm run db:status
```

Terapkan semua migrasi yang masih `pending`:

```powershell
npm run db:migrate
npm run db:status
```

Migrasi dicatat di tabel `_schema_migrations` dan aman untuk dijalankan ulang;
migrasi yang sudah `applied` tidak dijalankan lagi. Server tidak menjalankan
migrasi otomatis dan akan menolak startup jika masih ada migrasi tertunda.

Sebelum perubahan skema yang berisiko, buat backup ke file baru:

```powershell
npm run db:backup -- ./backups/before-change.db
```

Rollback hanya mengembalikan satu migrasi terakhir dan wajib memakai flag
eksplisit karena dapat menghapus data:

```powershell
npm run db:rollback -- --allow-data-loss
```

Jangan mengubah file migrasi yang sudah diterapkan. Untuk pemulihan, gunakan
file database hasil backup dengan nama baru dan ubah `DATABASE_URL`; jangan
menimpa database yang sedang dibuka.

## 3. Mengisi data uji dengan seeder

Seeder hanya dapat berjalan setelah seluruh migrasi diterapkan:

```powershell
npm run db:seed
```

Seeder mengisi akun dan data domain untuk pengujian B000-B009. Output perintah
menampilkan kredensial akun uji `petani` dan `pegawai`; gunakan nilai tersebut
untuk login selama pengujian. Seeder dirancang idempoten sehingga dapat
dijalankan ulang tanpa membuat duplikasi data uji.

Seeder diblokir pada `NODE_ENV=production` kecuali `ALLOW_PROD_SEED=1`.
Jangan menggunakan akun atau data seeder di production.

## 4. Menjalankan backend

### Mode development

Mode ini menjalankan TypeScript langsung dan melakukan restart saat source
berubah:

```powershell
npm run dev
```

### Mode build dan production-like

```powershell
npm run build
npm start
```

Default API tersedia di `http://127.0.0.1:3000`. Jika `HOST` atau `PORT`
diubah di `.env`, gunakan nilai tersebut pada URL pengujian.

### Memeriksa kesehatan API

Di terminal PowerShell lain:

```powershell
Invoke-RestMethod http://127.0.0.1:3000/health/live
Invoke-RestMethod http://127.0.0.1:3000/health/ready
```

`/health/live` memeriksa proses API. `/health/ready` memeriksa koneksi database
dan kesiapan skema. Jika startup gagal, pastikan `.env` valid, database dapat
dibuka, dan `npm run db:status` tidak lagi menampilkan migrasi `pending`.

## 5. Menguji fitur

### Pemeriksaan lengkap

Perintah berikut menjalankan typecheck, pemeriksaan batas ukuran file, dan
seluruh test suite:

```powershell
npm run check
```

Atau jalankan test saja:

```powershell
npm test
```

Test menggunakan database SQLite/libSQL lokal sementara dan tidak menggantikan
verifikasi koneksi remote Turso.

### Test berdasarkan area fitur

Jalankan satu area untuk iterasi cepat:

```powershell
npm test -- test/http.test.js
npm test -- test/auth.test.js
npm test -- test/profile.test.js
npm test -- test/inventory.test.js
npm test -- test/stock.test.js
npm test -- test/nursery.test.js
npm test -- test/transfers.test.js
npm test -- test/seed.test.js
npm test -- test/migrations.test.js
```

Test migrasi dan seeder berguna setelah perubahan SQL atau data awal. Test
`http`, `auth`, dan `profile` memverifikasi fondasi API dan autentikasi.
Test `inventory`, `stock`, `nursery`, dan `transfers` memverifikasi alur fitur
domain.

### Verifikasi manual alur fitur

1. Jalankan migrasi dan seeder.
2. Jalankan API dengan `npm run dev`.
3. Pastikan kedua endpoint health berstatus siap.
4. Login menggunakan kredensial yang dicetak oleh seeder melalui endpoint
   autentikasi sesuai [kontrak API](backend-api.md).
5. Jalankan request fitur yang sedang dikerjakan menggunakan akun dan data
   hasil seeder.
6. Setelah perubahan, ulangi test area terkait lalu `npm run check`.

Untuk operasi penulisan stok, sertakan `Idempotency-Key` sesuai kontrak stock
ledger. Jangan menguji operasi destruktif pada database yang berisi data
penting; gunakan database lokal atau salinan backup.

## Urutan cepat dari database kosong

```powershell
cd apps/backend
npm ci
Copy-Item .env.example .env
npm run db:status
npm run db:migrate
npm run db:seed
npm run check
npm run dev
```

Biarkan `npm run dev` berjalan, lalu jalankan pemeriksaan health atau test
fitur dari terminal lain.
