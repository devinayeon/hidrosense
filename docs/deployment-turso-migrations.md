# Deployment migrasi Turso 0002–0005

Tanggal pelaksanaan: 3 Oktober 2026, sekitar 00:18–00:22 WIB. Target adalah database remote dari `apps/backend/.env`. URL dan token tidak dicatat.

## Hasil

Migrasi `0002_auth_sessions`, `0003_sync_foundation`, `0004_inventory_master`, dan `0005_sync_resource_links` diterapkan melalui runner migrasi proyek dalam transaksi write. Semua checksum history kini valid dan seluruh migrasi `0001–0005` berstatus applied. Eksekusi ulang migrasi menghasilkan daftar kosong: tidak ada perubahan tambahan.

Review sebelumnya yang menyatakan deployment terblokir migrasi pending telah terselesaikan. `/health/live` dan `/health/ready` kini menghasilkan 200 melalui Fastify injection yang menggunakan database remote. Ini membuktikan readiness database/backend terpasang pada kode workspace; tidak membuktikan proses backend deployment atau reverse proxy eksternal sudah berjalan.

## Backup dan preservasi

Sebelum migrasi, dibuat snapshot logis konsisten melalui transaksi read remote. Snapshot direstorasi ke berkas SQLite lokal yang mencakup schema, indeks, data, history migrasi, dan `sqlite_sequence`. Driver bigint hanya digunakan oleh alat snapshot agar integer 64-bit tidak kehilangan presisi; driver runtime tidak diubah.

Backup diverifikasi melalui fingerprint setiap tabel, `PRAGMA integrity_check`, `PRAGMA foreign_key_check`, lalu ditutup dan dibuka ulang untuk memeriksa persistensi. Total snapshot: 21 tabel termasuk metadata. Setelah migrasi, fingerprint seluruh kolom domain yang sudah ada tetap sama. Kolom baru `jenis_inventaris.status_aktif` dan metadata UUID/versi merupakan perluasan schema yang diharapkan.

Backup lokal, di-ignore Git:

`apps/backend/backups/turso-before-0002-0005-d3c176b6-0735-47bc-9f41-434195546654.sqlite`

Backup memuat data database; jangan dipublikasikan. Snapshot lokal ini bukan verifikasi PITR atau backup platform Turso. Fingerprint preservasi berlaku pada interval pengujian; penulis eksternal tidak dihentikan oleh script.

Rollback down tidak dijalankan di live karena menghapus sesi, receipt, dan metadata identitas/versi. Backup menyimpan kondisi sebelum migrasi untuk restorasi melalui proses pemulihan terkontrol. Suite lokal menguji pasangan up/down migrasi; deployment ini hanya melakukan arah up.

## Pengujian setelah migrasi

| Pemeriksaan | Hasil |
| --- | --- |
| Schema remote vs referensi lokal | 54 objek cocok; tidak ada objek tambahan atau definisi berbeda |
| History/checksum dan rerun | Lulus; seluruh migrasi applied; rerun no-op |
| FK dan bound query | Lulus; tidak ada pelanggaran FK |
| Integer signed 64-bit ke TEXT | Lulus, `9223372036854775807` terbaca tepat |
| Readiness/live | 200 / 200 |
| Proyeksi sesi, akun, sync, inventaris | Seluruh query lulus |
| DDL/DML rollback | Tabel/baris batal tidak terlihat melalui client kedua |
| Commit multi-tabel/persistensi | Lulus melalui pembacaan client independen |
| UPSERT RETURNING/FK/rollback | Lulus; mutasi versi batal setelah kegagalan FK |
| B002 fungsi sesi/authenticate | Pembuatan sesi dan principal petani lulus |
| B003 fungsi akun | Pembacaan dan rename lulus; sesi lama tercabut |
| B004 fungsi reservasi | Replay, canonical UUID casing, dan konflik payload lulus |
| B005 fungsi mutasi domain | Obat create/replay/deactivate, UUID, versi, referensi inventaris, desimal, penolakan referensi nonaktif, dan histori lulus |
| Cleanup | Tabel scratch dihapus; probe fungsi domain di-rollback dan tidak menyisakan akun/barang probe |
| Suite lokal | 85/85 tes, typecheck, build, batas 400 baris lulus |

Uji fungsi domain memakai implementasi produksi di dalam transaksi remote yang dibatalkan. Ini menguji SQL dan fungsi terhadap Turso; pengujian semua endpoint HTTP tetap berada pada suite lokal. Probe tidak melakukan bootstrap produksi, memodifikasi akun pengguna, atau meninggalkan record domain uji.

Sampel 12 query remote berurutan: minimum 98 ms, median 104 ms, maksimum 110 ms. Pembukaan koneksi dan verifikasi FK 955 ms. Commit multi-tabel dan baca ulang membutuhkan 887 ms. Sampel ini bukan SLA atau load test.

## Skill yang digunakan

`find-skills` dijalankan dan output lengkap dibaca. Leaderboard serta pencarian `turso` dan `database migration` ditinjau. Kandidat komunitas Turso dengan jumlah instalasi rendah tidak dipilih. Pilihan pasti: `turso-cloud` dari [repository resmi Turso](https://github.com/tursodatabase/agent-skills), ditambah skill lokal `migration` untuk preservasi/rollback dan `verify-and-stop` untuk verifikasi terukur. Repository resmi memiliki 28 stars pada pemeriksaan; reputasi sumber dan pembacaan instruksi menjadi dasar pemilihan, bukan popularitas saja.

`turso-cloud` dieksekusi; output dan referensi JavaScript/autentikasi lengkap dibaca. SDK produksi proyek tetap dipakai. `caveman-review` diterapkan pada komunikasi review; implementasi dan testing mengikuti permintaan eksplisit pengguna.

## Bukti dan perintah

- `deployment-turso-migrations-evidence.json`: backup, history before/after, migrasi, preservasi, rerun.
- `deployment-turso-verification-evidence.json`: schema, health, query, latency, transaksi, cleanup.
- `deployment-turso-features-evidence.json`: enam pemeriksaan fungsi dan rollback remote.

Perintah berikut berasal dari direktori `apps/backend`. Perintah pertama memodifikasi schema remote dan membuat backup baru; hanya jalankan dalam deployment yang diotorisasi.

```powershell
$env:TURSO_MIGRATION_DEPLOY='1'
node --env-file=.env scripts/deploy-turso-migrations.mjs
$env:TURSO_LIVE_VERIFY='1'
node --env-file=.env --import tsx scripts/verify-turso-live.mjs
node --env-file=.env --import tsx scripts/verify-turso-features.mjs
npm run check
npm run build
```

Mobile/BMKG tidak diubah; perubahan inventaris sebelumnya dipertahankan. Belum diuji: reverse proxy nyata, seluruh flow HTTP terhadap remote melalui klien eksternal, konkurensi writer/failover/restart, load, dan timing side channel.
