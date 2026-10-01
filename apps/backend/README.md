# Database backend HidroSense

API B001–B003 sudah tersedia: fondasi HTTP, autentikasi, sesi, guard hak akses, pengelolaan pegawai, dan profil petani. Lihat [kontrak API](../../docs/backend-api.md), [kontrak akun/profil](../../docs/backend-accounts-api.md), dan [breakdown B003](../../docs/backend-b003.md). Pegawai memiliki akses panen dan tidak memiliki akses penjualan sesuai System Request.

## Menjalankan API dan autentikasi

Jalankan dari `apps/backend`:

```powershell
npm ci
npm run db:migrate
npm run check
npm run build
npm start
```

Default: `http://127.0.0.1:3000`. `npm run dev` menjalankan source TypeScript dengan watch. Migrasi tidak dijalankan otomatis saat startup; server menolak mulai jika ada migrasi tertunda. `GET /health/live` memeriksa proses, `GET /health/ready` memeriksa koneksi dan kesiapan skema. `npm run check` menjalankan typecheck, batas 400 baris kode/file, dan tes. File yang ditulis ditargetkan di bawah 300 baris.

Bootstrap akun petani pertama dilakukan dari terminal terpisah setelah migrasi dan build. Pilih username/nama lalu masukkan password melalui prompt tersembunyi:

```powershell
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

Bootstrap menolak jika petani sudah ada, termasuk akun nonaktif. Tidak ada password bawaan atau endpoint registrasi publik. Petani mengelola pegawai melalui `/api/v1/employees` dan profil sendiri melalui `/api/v1/profile`; perubahan kredensial mencabut seluruh sesi akun target. B003 tidak memerlukan migrasi baru. Migrasi `0002_auth_sessions` menambah tabel sesi dan counter throttle; rollback versi ini mencabut semua sesi tetapi mempertahankan tabel/data domain.

Konfigurasi API tersedia di `.env.example`: `NODE_ENV`, `HOST`, `PORT`, `LOG_LEVEL`, `CORS_ORIGINS`, dan `TRUSTED_PROXIES`. Production memerlukan HTTPS melalui proxy tepercaya. Semua instance harus memakai database bersama agar sesi dan rate limit konsisten. Startup membersihkan sesi/counter kedaluwarsa; pada deployment yang berjalan lama, jadwalkan penghapusan data infrastruktur kedaluwarsa secara berkala. SQL penghapusan memakai batas `refresh_expires_at`/`resets_at` dalam epoch milidetik dan tidak menyentuh data domain.

Acuan pekerjaan fitur berikutnya: [urutan pengerjaan backend](../../docs/rencana-backend.md). Backend mengikuti pola vertical slice; seluruh fitur terkait BMKG ditempatkan terakhir sambil menunggu revisi rancangan.

Setup Node.js (ES modules) untuk migrasi SQLite lokal dan Turso **libSQL**, menggunakan `@libsql/client`. Node.js mengikuti fondasi `package.json` yang sudah ada. Target SQLite/Turso telah dikonfirmasi; header PostgreSQL pada [DBML asli tim](../../docs/database/hidrosense.dbml) dipertahankan sebagai arsip sumber.

## Menjalankan lokal

Prasyarat: Node.js >=22.13 dan npm. Jalankan dari root repo:

```powershell
cd apps/backend
npm ci
Copy-Item .env.example .env
npm run db:status
npm run db:migrate
npm run db:status
npm test
```

Salin `.env.example` hanya saat belum memiliki `.env`. Tanpa `.env`, target default adalah `file:./data/hidrosense.db`. Semua path `file:` relatif ditafsirkan terhadap `apps/backend`, sehingga tidak bergantung pada direktori pemanggil. File database, backup, dan kredensial diabaikan Git. Data awal/akun tidak ditambahkan otomatis.

`db:migrate` membuat 19 tabel domain, 23 foreign key, 23 indeks kolom foreign key, dan tabel internal `_schema_migrations`. Pengulangan perintah tidak mengulang migrasi yang sudah tercatat. `db:status` menampilkan status `pending` atau `applied`.

## Target Turso/libSQL

Isi `.env` lokal menggunakan URL dan token database milik proyek:

```dotenv
DATABASE_URL=libsql://your-database-your-org.turso.io
DATABASE_AUTH_TOKEN=your-token
```

Jalankan `npm run db:status` untuk memeriksa target, lalu `npm run db:migrate`. Kredensial tetap di backend. Setup ini memakai protokol libSQL; database Turso dengan engine/API baru harus dikonfirmasi kompatibilitasnya sebelum digunakan. Pengujian yang disertakan memakai SQLite/libSQL lokal; koneksi remote membutuhkan kredensial dan pengujian tersendiri.

## Pemetaan DBML ke SQLite

Nama dan urutan 19 tabel, kolom, nullability, default, unique, dan 23 relasi mengikuti DBML tim. Tidak ada cascade delete yang ditambahkan. Semua relasi memakai `NO ACTION`; histori yang masih direferensikan tidak dapat dihapus begitu saja.

| DBML | SQLite | Catatan |
| --- | --- | --- |
| `int [pk, increment]` | `INTEGER PRIMARY KEY AUTOINCREMENT` | ID dibuat oleh database pusat; bukan identitas global lintas perangkat |
| `int` | `INTEGER` | SQLite memakai affinity; validasi bilangan bulat dan rentang dilakukan juga pada layer aplikasi |
| `varchar(n)` | `TEXT CHECK(length(kolom) <= n)` | Batas panjang asli dipertahankan; null tetap diizinkan bila sumber mengizinkannya |
| `text` | `TEXT` | Tidak diberi batas tambahan |
| `boolean` | `INTEGER CHECK(kolom IN (0,1))` | Default `true` menjadi `1` |
| `date` | `TEXT` | Kontrak aplikasi: `YYYY-MM-DD`; kalender perlu divalidasi sebelum disimpan |
| `timestamp` | `TEXT` | `CURRENT_TIMESTAMP` dipertahankan; default UTC `YYYY-MM-DD HH:MM:SS` |
| `decimal(p,s)` | deklarasi `DECIMAL(p,s)` dengan affinity NUMERIC | SQLite tidak menegakkan precision/scale PostgreSQL dan dapat menyimpan REAL biner. Jangan menganggapnya fixed decimal yang eksak |

Validasi angka, pembulatan, dan perhitungan uang harus ditetapkan saat implementasi service. Bila diperlukan penyimpanan uang yang eksak, buat migrasi lanjutan dengan satuan integer terkecil atau representasi desimal yang disepakati tim; migrasi awal ini mempertahankan nama dan deklarasi desimal tim.

Referensi: [tipe data SQLite](https://www.sqlite.org/datatype3.html), [foreign key SQLite](https://www.sqlite.org/foreignkeys.html), dan [SDK Turso/libSQL](https://docs.turso.tech/sdk/ts/reference).

## Disiplin migrasi

- File migrasi berpasangan: `migrations/0001_initial_schema.up.sql` dan `.down.sql`. Versi berikutnya memakai nomor yang lebih besar, misalnya `0002_add_sync_identity`.
- Jangan mengubah migrasi yang telah diterapkan. SHA-256 dari kedua file disimpan dalam `_schema_migrations`; perubahan isi atau histori yang hilang/tidak berurutan ditolak. CRLF/LF dinormalisasi sebelum hashing.
- Semua migrasi tertunda dan pencatatan versinya dijalankan dalam satu transaksi write. Kesalahan menyebabkan rollback transaksi. Pemeriksaan `foreign_key_check` dilakukan sebelum commit.
- File SQL tidak boleh memuat `BEGIN`, `COMMIT`, `ROLLBACK`, atau menonaktifkan foreign key; transaksi dikelola runner. File ini adalah kode tepercaya yang ditinjau tim, bukan input pengguna.
- Database lama dengan tabel bernama sama dan tanpa histori migrasi tidak diadopsi otomatis. Inventarisasi serta backup data dahulu, kemudian siapkan migrasi/baseline khusus untuk kondisi tersebut.
- Penambahan fitur berikutnya perlu kompatibel dengan versi aplikasi yang masih aktif: tambah struktur dahulu, migrasikan data, verifikasi, baru hapus struktur lama melalui pekerjaan terpisah. Migrasi awal ini hanya membentuk skema baru.

## Backup dan pemulihan

Untuk database lokal:

```powershell
npm run db:backup -- ./backups/before-change.db
```

Perintah memakai `VACUUM INTO` untuk snapshot konsisten, termasuk data yang telah commit di WAL. Target backup harus baru dan tidak boleh menimpa file yang ada. Untuk remote gunakan fasilitas backup/restore Turso dan verifikasi hasilnya sebelum perubahan destruktif.

Rollback mengembalikan **satu versi terakhir**:

```powershell
npm run db:rollback -- --allow-data-loss
```

**Rollback `0001` menghapus seluruh tabel dan data domain HidroSense.** Perintah tanpa flag ditolak. SQL down adalah pembatalan skema, bukan pemulihan data; data dipulihkan dari backup.

Untuk pemulihan lokal, hentikan seluruh proses yang memakai database, pertahankan file lama beserta `-wal`/`-shm`, lalu salin backup ke **nama file baru** (contoh `data/restored.db`). Ubah `DATABASE_URL=file:./data/restored.db`, jalankan `db:status`, dan periksa data sebelum mengaktifkan aplikasi. Jangan menimpa file database yang masih terbuka. Tes melakukan pembukaan ulang backup dan `PRAGMA integrity_check` untuk membuktikan snapshot bisa dibaca.

Koneksi lokal mengaktifkan foreign key, WAL untuk database berbasis file, dan busy timeout 5 detik. Jangan mengubah jumlah koneksi tanpa memastikan PRAGMA berlaku pada setiap koneksi. Di Unix, direktori baru menggunakan mode 700 dan file database/backup mode 600; di Windows akses mengikuti ACL direktori pengguna. Simpan backup pada lokasi dengan akses terbatas. Untuk pemeliharaan database yang bertumbuh, jalankan `PRAGMA optimize` pada waktu idle; rencanakan `VACUUM` hanya saat dibutuhkan dengan backup dan ruang disk yang memadai.

## Bukti pengujian dan batas pekerjaan

`npm test` membandingkan skema aktual terhadap DBML asli dan menguji relasi/indeks, NOT NULL/unique/default, boolean/panjang teks, input dengan karakter SQL melalui parameter, rantai data budidaya, pengulangan tanpa kehilangan data, rollback/reapply, transaksi gagal, perubahan checksum, database lama, dan backup lokal yang dapat dibaca ulang. Query plan juga diperiksa agar pencarian berdasarkan foreign key memakai indeks.

Fondasi HTTP dan autentikasi B001/B002 sudah diimplementasikan; endpoint bisnis dan sinkronisasi mobile mengikuti tahap berikutnya. Kolom `password` menyimpan hash scrypt, sedangkan hash token disimpan dalam `auth_sessions`. DBML belum menyediakan identitas transaksi global/idempotency, versi perubahan untuk konflik sinkronisasi, golongan bahan aktif untuk rotasi obat, atau representasi terpisah hasil tanpa deteksi/banyak objek. Hal tersebut dicatat untuk migrasi berikutnya saat kontrak fitur ditetapkan. Validasi kapasitas meja, saldo stok, jumlah panen, dan batas penjualan membutuhkan transaksi pada handler fitur terkait.
