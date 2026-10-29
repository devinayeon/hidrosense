# Panduan Menjalankan Backend HidroSense

Panduan ini mencakup konfigurasi database, migrasi, seeder data uji, dan startup API.

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

Seeder diblokir pada `NODE_ENV=production` **dan** pada `DATABASE_URL` remote
(`libsql://`/`https://`) kecuali `ALLOW_PROD_SEED=1`. Menjalankan ulang seeder
tidak mengubah password maupun status aktif akun yang sudah ada.
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

Untuk menyiapkan akun petani pertama tanpa data seeder, ikuti [setup akun backend](../apps/backend/README.md#akun-petani-pertama).

## 5. Header wajib untuk endpoint tulis

Setiap `POST`/`PATCH` yang menulis data domain mewajibkan header
`Idempotency-Key` berisi UUID v4 unik per operasi. Tanpa header itu server
membalas `400 VALIDATION_ERROR` dengan pesan `Header sinkronisasi tidak valid.`
Tujuannya: percobaan ulang setelah timeout mengembalikan hasil tersimpan
(`200`, `replayed: true`), bukan membuat catatan kedua.

`X-Client-Id` opsional dan hanya dipakai pada operasi yang membuat catatan baru
(`create`, termasuk `POST /stok/:id/reverse` yang membuat gerakan pembalik).
Operasi yang mengubah catatan lama mengabaikannya.

```powershell
$key = [guid]::NewGuid().ToString()
$token = (Invoke-RestMethod http://127.0.0.1:3000/api/v1/auth/login -Method Post `
  -ContentType 'application/json' -Body '{"username":"petani","password":"..."}').data.access_token

Invoke-RestMethod http://127.0.0.1:3000/api/v1/meja-tanam -Method Post `
  -Headers @{ Authorization = "Bearer $token"; 'Idempotency-Key' = $key } `
  -ContentType 'application/json' -Body '{"kode_meja":"M-05","jumlah_lubang":250}'
```

Kirim ulang dengan `$key` yang sama dan isi yang sama untuk menguji replay.
Endpoint `employees` dan `profile` belum memakai mekanisme receipt ini.
