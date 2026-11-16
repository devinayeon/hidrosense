# Setup Backend HidroSense

Prasyarat: Node.js `>=22.13`, npm, dan PowerShell.

Untuk konfigurasi database lokal atau Turso/libSQL, migrasi, seeder, dan pemeriksaan kesehatan API, ikuti [panduan menjalankan backend](../../docs/panduan-menjalankan-backend.md).

## Menjalankan lokal

Dari root repository:

```powershell
cd apps/backend
npm ci
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
npm run db:migrate
npm run db:seed
npm run dev
```

Seeder mencetak kredensial akun uji. Gunakan data seeder hanya untuk pengembangan dan pengujian.

Default API: `http://127.0.0.1:3000`. Server menolak startup jika masih ada migrasi tertunda.

## Akun petani pertama

Untuk database tanpa data seeder, jalankan setelah migrasi dan build dari direktori `apps/backend`:

```powershell
npm run build
$env:BOOTSTRAP_USERNAME = 'username-petani'
$env:BOOTSTRAP_NAME = 'Nama Petani'
try {
  $env:BOOTSTRAP_PASSWORD = [System.Net.NetworkCredential]::new('', (Read-Host 'Password (12-128 karakter)' -AsSecureString)).Password
  npm run auth:bootstrap
} finally {
  Remove-Item Env:BOOTSTRAP_PASSWORD -ErrorAction SilentlyContinue
  Remove-Item Env:BOOTSTRAP_USERNAME -ErrorAction SilentlyContinue
  Remove-Item Env:BOOTSTRAP_NAME -ErrorAction SilentlyContinue
}
```

Bootstrap menolak jika akun petani sudah ada, termasuk akun nonaktif. Tidak ada password bawaan atau endpoint registrasi publik.

## Menjalankan hasil build

```powershell
npm run build
npm start
```

Konfigurasi API tersedia di `.env.example`: `NODE_ENV`, `HOST`, `PORT`, `LOG_LEVEL`, `CORS_ORIGINS`, dan `TRUSTED_PROXIES`. Production memerlukan HTTPS melalui proxy tepercaya. Simpan kredensial database di backend dan jangan commit `.env`.
