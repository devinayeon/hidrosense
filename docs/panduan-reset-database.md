# Panduan Reset Database (Lokal & Turso Baru)

Panduan ini untuk 2 keadaan yang paling sering terjadi:

- **A.** Ingin database lokal SQLite yang baru dan fresh, lalu jalan lokal.
- **B.** Database di web Turso sudah dihapus dan dibuat baru, ingin dipakai.

Semua perintah dijalankan dari `apps/backend`:

```powershell
cd apps/backend
```

## Konsep 30 detik (wajib paham)

Yang menentukan database mana yang dipakai adalah **isi file `.env` yang aktif**.
Kita menyimpan 3 file di `apps/backend` (semuanya di-ignore git, aman dari commit):

| File | Isi | Kapan dipakai |
| --- | --- | --- |
| `.env.local` | SQLite lokal `file:./data/hidrosense.db` | Kerja harian |
| `.env.turso` | Turso remote + token full-access | Verifikasi remote |
| `.env` | **Yang aktif saat ini** — salinan dari salah satu di atas | — |

Ganti target = salin file yang mau dipakai menjadi `.env`. Tidak ada yang perlu
diketik manual.

## A. Reset lokal SQLite sampai fresh (kerja harian)

Gunakan ini kalau kamu ingin coding jalan lokal. Data lama di
`data/hidrosense.db` akan hilang — itu memang tujuannya (isinya cuma data uji).

```powershell
cd apps/backend

# 1. Matikan dulu `npm run dev` kalau sedang jalan (Ctrl+C).
#    File SQLite tidak bisa dihapus selagi dibuka server.

# 2. Pastikan targetnya lokal:
Copy-Item .env.local .env -Force

# 3. Hapus database lokal yang lama:
Remove-Item ./data/hidrosense.db -ErrorAction SilentlyContinue
Remove-Item ./data/hidrosense.db-wal,./data/hidrosense.db-shm,./data/hidrosense.db-journal -ErrorAction SilentlyContinue

# 4. Buat ulang dari nol (migrasi) lalu isi data uji (seed):
npm run db:status
npm run db:migrate
npm run db:status
npm run db:seed
```

Hasil yang benar:

- `db:status` pertama: semua `pending` (database kosong, wajar).
- `db:migrate`: `up: 0001_initial_schema, ..., 0010_damage_index`.
- `db:status` kedua: semua `applied`.
- `db:seed`: `✅ Database berhasil diseed` + tercetak akun `petani` dan `pegawai`.

Lalu jalankan API:

```powershell
npm run dev
```

Di terminal PowerShell **lain**:

```powershell
Invoke-RestMethod http://127.0.0.1:3000/health/live
Invoke-RestMethod http://127.0.0.1:3000/health/ready
```

Keduanya harus menjawab OK. Login pakai akun yang dicetak seeder.

> Kenapa hapus file, bukan `db:rollback`? Karena `rollback` hanya mundur
> **satu** migrasi per perintah, dan migrasi `0006` sengaja menolak rollback
> kalau tabel stok sudah ada isinya. Hapus file = 5 detik, bersih total.

## B. Pakai database Turso yang baru dibuat

Keadaanmu sekarang: database di web Turso sudah baru, URL + token baru sudah
ditempel di `.env.turso`, dan `.env` sudah berisi token baru. Bagian ini untuk
memverifikasi sambungannya dan mengisi skema + data uji ke DB baru itu.

```powershell
cd apps/backend

# 1. Pakai target Turso:
Copy-Item .env.turso .env -Force

# 2. Cek target. WAJIB semua `pending` karena DB-nya baru kosong:
npm run db:status
```

- Kalau semua `pending` → lanjut langkah 3. ✅
- Kalau muncul `applied` → kamu masih menunjuk ke DB **lama**. STOP.
  Buka web Turso, salin ulang URL DB barunya
  (`turso db show <nama-db-baru> --url`) ke `.env.turso`, salin lagi ke
  `.env`, ulangi `db:status`.

```powershell
# 3. Isi DB baru:
npm run db:migrate
npm run db:status
npm run db:seed
```

Catatan Turso:

- Token harus **full-access** (`turso db tokens create <nama-db>` tanpa flag
  read-only). Token read-only bisa `db:status` tapi gagal saat
  `db:migrate`/`db:seed`.
- `npm run db:backup` hanya untuk lokal dan akan error di Turso — itu normal.
  Backup remote lewat dashboard Turso.
- Jangan `db:rollback` berulang di Turso yang sudah di-seed: migrasi `0006`
  memblokirnya. Kalau remote sudah kotor, cara bersihnya adalah hapus + buat
  DB baru lagi di web Turso, bukan rollback.

## C. Pindah-pindah target (contoh alur kamu sekarang)

```powershell
cd apps/backend

Copy-Item .env.turso .env -Force
npm run db:status     # verifikasi remote baru → migrate → seed (bagian B)

Copy-Item .env.local .env -Force
npm run db:status     # kembali kerja lokal (bagian A)
```

## D. Kalau error

| Gejala | Artinya | Perbaikan |
| --- | --- | --- |
| `Seeder gagal: Migrasi database belum lengkap` | Ada migrasi `pending` | Jalankan `npm run db:migrate` dulu, baru `db:seed` |
| `Migration history differs / checksum mismatch` | Isi `_schema_migrations` tidak cocok dengan file `migrations/` | Jangan edit/hapus `_schema_migrations` manual. Untuk lokal: hapus file DB (bagian A). Untuk Turso: buat DB baru |
| `Rollback ... allowDataLoss` atau gagal di `0006` | Rollback menabrak guard stok / flag kurang | Memang begitu by design. Jangan rollback berulang — reset fresh saja |
| `DATABASE_AUTH_TOKEN is required` | `.env` menunjuk Turso tapi token kosong | Isi token full-access di `.env.turso`, salin ke `.env` |
| `Tidak bisa hapus hidrosense.db` | Server masih jalan / file terkunci | Ctrl+C `npm run dev` dulu, ulangi hapus |
| Health `ready` gagal | DB belum migrate / URL salah | `npm run db:status` — pastikan semua `applied` dan URL sesuai target |

Lihat juga [panduan menjalankan backend](panduan-menjalankan-backend.md) untuk
urutan lengkap dari database kosong sampai pengujian fitur.
