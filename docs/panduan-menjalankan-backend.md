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
hanya mengisi baris yang belum ada; akun dan data domain yang sudah ada tidak
berubah, termasuk tanggal semai. Untuk data uji dengan tanggal baru, hapus dulu
file database lokal lalu jalankan migrasi dan seeder lagi.
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
Operasi yang mengubah catatan lama menolaknya dengan `400 VALIDATION_ERROR`.

`PATCH` domain menerima field `expected_version` di body, berisi `version` terakhir
yang dibaca klien. Jika data sudah berubah, server membalas `409 VERSION_CONFLICT`
dan tidak menulis apa pun. Tanpa field itu penulisan terakhir yang menang. `PATCH /panen/:id`
tetap mewajibkan field ini dan membalas `409 HARVEST_VERSION_CONFLICT`.

Kode status kesalahan: resource di URL tidak ada `404`; referensi di dalam body tidak ada
`422`; tanggal di masa depan `400`.

## 6. Sesi login

Access token berlaku 15 menit. Sesi berakhir 7 hari setelah refresh terakhir dan paling
lambat 30 hari setelah login. Refresh token sekali pakai; token lama dibalas `401` tanpa
mencabut sesi yang sedang berjalan.

## 7. Mengambil perubahan untuk perangkat lain

```http
GET /api/v1/sync/changes?cursor=0&limit=100
```

```json
{
  "data": [
    {
      "cursor": "42",
      "resource_type": "meja-tanam",
      "domain_id": "1",
      "public_id": "...",
      "version": "3",
      "changed_at": "2026-09-30T00:00:00.000Z"
    }
  ],
  "meta": { "next_cursor": "42", "has_more": false }
}
```

Cara memakainya:

1. Simpan `next_cursor` setelah data halaman itu berhasil disimpan di perangkat.
2. Baca ulang tiap catatan lewat endpoint biasa, misalnya `GET /api/v1/meja-tanam/1`.
3. Ulangi selama `has_more` bernilai `true`.
4. Bila server membalas `409 SYNC_CURSOR_RESET`, mulai lagi dari `cursor=0`.

Satu catatan muncul sekali per halaman pada perubahan terbarunya. `limit` paling besar 200.
Daftar ini tersaring menurut izin, jadi pegawai tidak melihat `penjualan`.

`resource_type`: `jenis-inventaris`, `obat`, `inventaris`, `stok`, `penyemaian`, `meja-tanam`,
`pemindahan`, `kerusakan_tanaman`, `panen`, `penjualan`.

Perubahan nilai turunan ikut diumumkan tanpa menaikkan `version`, misalnya saldo `inventaris`,
serta tanaman aktif dan kapasitas pada `pemindahan` dan `meja-tanam`. Karena `inventaris`
menampilkan nama jenis dan obat, baca ulang daftarnya bila `jenis-inventaris` atau `obat` berubah.
Akun pegawai dan profil tidak termasuk daftar ini.

## 8. Pengembangan lokal

Pengembangan memakai database file lokal. `dist/serverless.js` juga menerima database lokal selama
`NODE_ENV` bukan `production`.

API menolak start selama ada migrasi yang belum diterapkan, termasuk pada database yang pernah memakai
`0012_operation_key_lower`. Jalankan `npm run db:migrate` saat database siap ditingkatkan.

## 9. Deploy serverless

Entry point: `dist/serverless.js`, yang mengekspor handler Node `(req, res)`. File ini tidak
memanggil `listen`.

Sebelum deploy:

1. Jalankan `npm run db:migrate` dari pipeline deploy dengan `DATABASE_URL` Turso. Function
   tidak menjalankan migrasi. Migrasi `0015_sync_changes` belum pernah dijalankan di Turso.
2. Sertakan folder `migrations/` di paket function; `/health/ready` membacanya. Jika dibundel,
   jalur folder ini bisa berubah dan endpoint itu akan membalas `503`.

Environment function:

| Variabel | Nilai |
|---|---|
| `DATABASE_URL` | `libsql://...` atau `https://...`. Database file ditolak karena disk function tidak menetap. |
| `DATABASE_AUTH_TOKEN` | Token Turso |
| `NODE_ENV` | `production` |
| `TRUST_PROXY_HOPS` | Jumlah proxy di depan function, biasanya `1` |
| `CORS_ORIGINS` | Kosongkan kecuali ada klien browser |

Periksa `TRUST_PROXY_HOPS` di platform yang dipakai: nilai yang terlalu kecil membuat semua
pengguna berbagi satu kuota, dan nilai yang terlalu besar membuat kuota bisa dihindari dengan
memalsukan `X-Forwarded-For`.

Kuota request tersimpan di database supaya berlaku lintas instance. Sesi dan kuota kedaluwarsa
dibersihkan saat login dan refresh, jadi tidak perlu cron.

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
