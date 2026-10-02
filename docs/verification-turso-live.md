# Verifikasi Turso live — B000–B005

Status historis sebelum migrasi. Pembaruan 3 Oktober 2026: migrasi `0002–0005` sudah diterapkan dan readiness kini 200. Lihat [laporan deployment](deployment-turso-migrations.md); bukti di dokumen ini tetap merekam kondisi awal.

Tanggal: 2 Oktober 2026, 23:55 WIB. Target menggunakan `DATABASE_URL` dan `DATABASE_AUTH_TOKEN` dari `apps/backend/.env`; kredensial dan alamat database tidak dicatat.

## Kesimpulan

Koneksi dan primitive database remote kompatibel dengan driver backend yang terpasang (`@libsql/client`). **Deployment belum siap untuk B002–B005:** hanya `0001_initial_schema` yang terpasang. Migrasi `0002_auth_sessions`, `0003_sync_foundation`, `0004_inventory_master`, dan `0005_sync_resource_links` masih pending. Tidak ada migrasi deployment yang diterapkan dalam verifikasi ini.

`/health/live` menghasilkan 200 dan `/health/ready` menghasilkan 503 dengan kode `NOT_READY`. Ini sesuai kondisi database remote, bukan kegagalan koneksi. Pengujian menggunakan Fastify injection dengan koneksi database live, bukan trafik melalui server deployment atau reverse proxy.

## Hasil pengujian

| Area | Hasil | Bukti / batas |
| --- | --- | --- |
| B000 koneksi | Lulus | SQLite remote 3.47.0; foreign keys aktif melalui factory backend |
| History migrasi | Lulus | Checksum `0001` cocok dengan berkas lokal; `0002–0005` pending |
| Schema deployment | Belum lengkap | 43 objek remote dibanding 54 objek referensi lokal; 12 definisi hilang/berbeda, termasuk `jenis_inventaris` yang belum memiliki perubahan B005 |
| Integritas FK | Lulus | `PRAGMA foreign_key_check` tidak menemukan pelanggaran |
| Parameter binding / ID 64-bit | Lulus | Nilai `9223372036854775807` dibaca tepat melalui `CAST(... AS TEXT)` |
| B001 health/readiness | Lulus | 200 / 503 `NOT_READY` |
| B002 proyeksi sesi | Terblokir | `auth_sessions` belum tersedia |
| B003 proyeksi akun | Lulus terbatas | Query kolom akun dan join role dengan `LIMIT 0`; tidak membaca data pribadi atau membuktikan CRUD end-to-end |
| B004 proyeksi sync | Terblokir | Schema sync belum tersedia |
| B005 proyeksi inventaris | Terblokir | Schema sync dan perubahan master belum tersedia |
| DDL/DML rollback | Lulus | Tabel dan baris yang dibatalkan tidak terlihat dari client independen |
| Commit atomik dan persistensi | Lulus | Dua tabel probe berelasi dikomit; ID 64-bit, marker, dan desimal `0.125` terbaca dari client independen |
| UPSERT RETURNING | Lulus | Increment versi mengembalikan string `2` |
| FK dan rollback mutasi sebelumnya | Lulus | Insert referensi invalid ditolak; rollback mengembalikan versi ke `1` |
| Cleanup | Lulus | Kedua tabel probe tidak ditemukan lagi setelah DROP atomik |

Semua query fitur diperiksa dahulu pada schema lokal in-memory lengkap, kemudian dijalankan read-only pada Turso. Perbandingan schema memakai teks SQL dengan normalisasi whitespace; bukan pembuktian kesetaraan struktural. Daftar perbedaan didukung history migrasi yang pending.

## Latensi

Eksekusi final: 16:55:44–16:55:56 UTC. Pembukaan koneksi beserta pengaktifan/verifikasi FK membutuhkan 2265 ms. Dua belas query berurutan menghasilkan minimum 101 ms, median 108,5 ms, maksimum 418 ms. Durasi 2145 ms mencakup transaksi commit multi-tabel dan pembacaan verifikasi dari client kedua.

Tiga eksekusi terbatas dilakukan saat menyusun dan memvalidasi probe. Median query berkisar 108–111,5 ms; maksimum per eksekusi 114–722 ms. Sampel kecil ini bukan load test, SLA, atau estimasi p95 produksi.

## Keamanan dan cakupan

Penulisan remote hanya dilakukan pada dua tabel berawalan `_hidro_verify_` dengan suffix acak per eksekusi. Tidak ada akun, sesi, receipt, ledger, sequence domain, atau record bisnis yang diubah. Cleanup setiap eksekusi terverifikasi. Token tidak ditampilkan; error probe hanya menyimpan nama class dan kode.

Review independen menyetujui pembatasan penulisan dan bukti cleanup. Perubahan inventaris yang sudah ada di workspace dipertahankan. Mobile dan BMKG tidak diubah.

Verifikasi lokal setelah penambahan probe: `npm run check` lulus (85 tes, typecheck, batas baris); `npm run build` dan `git diff --check` lulus. File kode terbesar tetap `test/inventory.test.js`, 288/400 baris. Graphify diperbarui secara AST; ekstraksi SQL masih terbatas karena `tree_sitter_sql` belum tersedia. Migrasi SQL diperiksa langsung untuk verifikasi ini.

Persistensi yang dibuktikan terbatas pada pembacaan setelah commit melalui client independen. Konkurensi writer, failover, restart database, backup/PITR, reverse proxy nyata, klien eksternal, load, dan timing side channel belum diuji. Flow autentikasi, pencabutan sesi, receipt/replay, dan CRUD penuh perlu diuji setelah schema deployment lengkap pada database staging yang sesuai.

## Skill dan reproduksi

Perintah `npx skills use "https://github.com/tursodatabase/agent-skills" --skill "turso-cloud"` telah dijalankan. Output lengkap serta referensi JavaScript dan autentikasi dibaca. Verifikasi menggunakan driver produksi proyek; tidak mengganti SDK atau merotasi token.

Dari direktori `apps/backend`, dengan target remote yang memang diizinkan untuk probe:

```powershell
$env:TURSO_LIVE_VERIFY='1'
node --env-file=.env --import tsx scripts/verify-turso-live.mjs
```

Exit code `1` pada eksekusi ini disengaja karena pemeriksaan kelengkapan schema gagal. Probe membersihkan tabel scratch dalam `finally`. Bukti JSON eksekusi final: `verification-turso-live-evidence.json`.

Tindak lanjut deployment: siapkan backup/PITR Turso, terapkan migrasi `0002–0005` melalui proses deployment, verifikasi readiness, kemudian jalankan pengujian fitur di staging. Langkah deployment tersebut tidak termasuk perubahan yang dilakukan dalam review ini.
