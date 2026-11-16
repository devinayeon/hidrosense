# Integrasi Cabang, Review Penjualan, B17, dan B18 Lokal

> Pembaruan: fitur AI tidak dimulai dulu atas keputusan pemilik, jadi B11 **dikeluarkan** sebelum push. Kodenya tetap ada di branch lokal `simpan/b11-deteksi` (`a4bff83`). Migrasi perubahan kini `0015_sync_changes`. Bagian yang menyebut `/deteksi` hanya berlaku untuk branch itu. Lihat bagian 10.

Tanggal: 2026-11-04
Dasar kerja: keputusan pemilik: B12–B14 bukan fokus sekarang, tidak ada pengujian di Turso, pengembangan memakai database lokal.
Branch: `integrasi/backend-rework` di worktree `.worktrees/integrasi-backend`
Status: selesai dan teruji di lokal. **Belum digabung ke `main` dan belum di-push.**

## 1. Hasil

| Pemeriksaan | Hasil |
|---|---|
| `npm run check` (typecheck, batas baris, test backend) | **331/331 lulus** |
| `flutter test --concurrency=1` | **364/364 lulus** |
| `flutter analyze` | bersih |
| `npm run build`, real run `dist/serverless.js` dan alur HTTP lokal | sesuai (bagian 6) |
| Salinan database dev ditingkatkan dari 11 ke 16 migrasi | data domain tidak berubah, 0 pelanggaran FK, stok konsisten |
| Turso | **tidak dijalankan**, sesuai keputusan |

## 2. Commit di branch

| Commit | Isi |
|---|---|
| `4578a83` | Rework hasil review, sesi, dan serverless |
| `c12a474` | Penggabungan `origin/main` |
| `692c8b2` | Perbaikan penjualan dan peningkatan database lama |
| `c036e94` | Hasil deteksi dan pengambilan perubahan |
| commit terakhir | Panduan API, perbaikan test Flutter, dokumen ini |

## 3. Penggabungan cabang

- **Bentrok migrasi:** `0012_operation_key_lower` dinomori ulang jadi `0014`; `0012` dan `0013` milik origin tetap. Tanpa ini backend gagal start: `Duplicate migration version: 0012`.
- **Database lama:** database yang sudah mencatat `0012_operation_key_lower` tetap bisa ditingkatkan dengan `npm run db:migrate`. Runner menghapus catatan itu beserta indeksnya, lalu menjalankan migrasi sesuai urutan baru. Hanya indeks yang tersentuh.
- **Konflik teks:** 4 file diselesaikan. Fitur origin (status meja otomatis) dan rework (perbaikan meja rusak, helper tanggal) dipertahankan keduanya.
- **`src/db/sales-amounts.js`** pindah ke `src/common/money.ts`, karena `allowJs` sudah dihapus.

Commit origin `a6c9bf3` menghapus dokumen di `docs/`, termasuk kontrak API dan `rencana-backend.md`. Isinya tetap ada di riwayat git, misalnya `git show fd9a125:docs/rencana-backend.md`.

## 4. Review `features/sales`

| # | Temuan | Bukti | Tindakan |
|---|---|---|---|
| S1 | `sales/write.ts` membuat kunci sendiri bila header kosong, sehingga retry bisa menggandakan penjualan | Tripwire test gagal: `sales/write.ts must require the header` | Diperbaiki; tanpa header kini `400` |
| S2 | N+1 di daftar penjualan | `expected at most 3 queries, ran 62` | Diperbaiki; 3 query |
| S3 | `id_panen` yang tidak ada di body dibalas `404` | `404 !== 422` | Diperbaiki; `422` sesuai aturan status |
| S4 | Salinan helper tanggal WIB | Pembacaan kode | Memakai `jakartaDate` |
| S5 | Satu baris penjualan lama yang rusak membuat seluruh daftar gagal | Pembacaan kode; belum dibuktikan | **Tidak diubah.** Penjualan lama tidak pernah dibuat lewat API, jadi kecil kemungkinannya terjadi |

Yang bertahan: cek stok panen, pembulatan total, izin pegawai, konflik versi, dan replay. Semua sudah dipin test origin.

## 5. Fitur baru

Kontrak lengkap ada di `docs/panduan-menjalankan-backend.md` bagian 7 dan 8.

### B11: hasil deteksi (`/api/v1/deteksi`)
- Inferensi tetap di perangkat; server hanya mencatat hasil per batch.
- Satu deteksi adalah satu gambar, bisa berisi beberapa hama, tanpa hama, atau gagal. Respons tidak pernah menyatakan tanaman bebas hama, sesuai PB-05.
- Retry dengan kunci yang sama tidak menyimpan dua kali.
- Hanya petani yang bisa mengakses. Hasil model tidak bisa diubah, gambar bisa disusulkan satu kali.
- Migrasi `0015` membangun ulang `hasil_deteksi`, dengan ID tetap agar `rekomendasi_perawatan` untuk B12 tidak putus. Rollback menghapus deteksi tanpa hama, karena bentuk lama tidak bisa menampungnya.

### B17: pengambilan perubahan (`GET /api/v1/sync/changes`)
- Perangkat menanyakan perubahan sejak kursor terakhir, lalu membaca ulang tiap catatan lewat endpoint biasa, sehingga izin tetap diperiksa di sana.
- Pencatatan memakai trigger database, sehingga semua jalur yang menaikkan versi ikut tercatat.
- Nilai turunan ikut diumumkan (saldo, tanaman aktif, kapasitas) tanpa menaikkan versi, supaya tidak ada konflik palsu.
- Pegawai tidak melihat `penjualan` dan `deteksi`. Tipe yang tidak dikenal disembunyikan dari semua pengguna.
- Kursor yang lebih maju dari server (misalnya database lokal direset) dibalas `409 SYNC_CURSOR_RESET`.

### B18: verifikasi lokal
`test/full-flow.test.js` menjalankan seluruh siklus lewat handler serverless di soket nyata, dengan database file:
stok, semai, retry, pindah, rusak, deteksi, panen, jual, dua perangkat berebut satu catatan, instance kedua, rekonsiliasi stok, lalu backup dan restore.

Angka yang dihitung manual di test:
- 100 dipindah, 5 rusak, 20 dipanen: 75 aktif, dan dari 150 lubang tersisa 75.
- Saldo benih: 1000 + 50 − 10,5 = 1039,5 gram.
- Panen 9,00 kg, reject 1,00 kg: layak 8,00 kg. Terjual 5,00 kg × 20.000 = 100.000, sisa 3,00 kg; jual 3,01 kg ditolak.

Semua migrasi juga diuji naik, turun sampai habis, lalu naik lagi.

### Handler serverless
`dist/serverless.js` kini menerima database lokal selama `NODE_ENV` bukan `production`, supaya bisa dicoba tanpa Turso. Di production database lokal tetap ditolak.

## 6. Real run

Hasil build di port asli, database file sementara yang sudah dihapus:

| Skenario | Hasil |
|---|---|
| `/health/ready` | `200` |
| Deteksi dengan hama / tanpa hama | `201` / `201` |
| Gambar `file:///sdcard/a.jpg` | `400` |
| Pegawai membaca deteksi | `403` |
| Feed petani | `200`, 21 catatan |
| Feed pegawai memuat deteksi | tidak |
| Kursor `99999` | `SYNC_CURSOR_RESET` |
| `POST /penjualan` tanpa kunci | `400` |

**Salinan `apps/backend/data/hidrosense.db`:** migrasi 11 ke 16 berhasil. Yang berubah hanya `_schema_migrations`, `deteksi` (baru, 0 baris), dan `sync_changes` (baru, 29 baris). Pelanggaran FK 0 dan stok konsisten 8/8. File aslinya tidak disentuh, dan salinannya sudah dihapus. **Database dev aslimu perlu `npm run db:migrate` setelah pindah ke kode ini.**

## 7. Bom waktu di test Flutter

3 test `penjualan_test.dart` gagal. Tanggal datanya dihitung mundur dari hari ini, jadi pada awal bulan penjualan jatuh ke bulan lalu dan total bulan ini tidak cocok. Bukan bug produk. Tanggal test kini dihitung dari tanggal 1 bulan berjalan.

## 8. Belum dikerjakan

| Item | Alasan |
|---|---|
| B12–B14 | Keputusan pemilik |
| **Flutter:** deteksi, penyimpanan token aman, antrean offline, `expected_version`, memakai `/sync/changes`, `saldo_valid` | Sisi mobile. Backend sudah siap untuk semuanya kecuali unggah gambar |
| Unggah Cloudinary | Butuh kredensial. Server hanya memvalidasi identitas gambar; tanda tangan unggah belum ada |
| Kontrak API lengkap untuk tim mobile (bagian B18) | Dokumen lama dihapus origin. Panduan kini hanya memuat endpoint baru dan aturan umum |
| T-07, T-08, T-09, F8, refactor `write.ts` | Lihat rework pertama |

## 9. Belum diuji

- **Turso, termasuk `0015` dan `0016`:** `PRAGMA defer_foreign_keys` dan trigger hanya terbukti di SQLite lokal. Jalankan di salinan Turso sebelum produksi.
- **Platform serverless nyata**, cold start, dan target kinerja SRS.
- Dua proses menulis serentak lewat `/sync/changes`: urutan kursor mengandalkan SQLite yang hanya punya satu penulis.
- Perangkat Android nyata dan alur offline.
- Pertumbuhan tabel `sync_changes`: belum ada pembersihan. Tiap perubahan menambah satu sampai beberapa baris.

## 10. Sebelum push ke `main`

Keputusan pemilik: fitur AI belum dimulai, database tidak disentuh, sisanya diselesaikan dari sisi backend.

| Pekerjaan | Hasil |
|---|---|
| B11 dikeluarkan | Rute, migrasi, test, dan panduan dihapus; disimpan di `simpan/b11-deteksi` |
| Kontrak API | `apps/backend/API.md`, menggantikan dokumen yang dihapus origin |
| Linter (T-09) | Biome di `npm run check`. `noFloatingPromises` terbukti aktif pada file probe; kode nyata 0 temuan. Satu import tak terpakai dihapus |

Sengaja tidak dikerjakan:

| Item | Alasan |
|---|---|
| T-07 rehash saat login | Mengubah `users.password` akan mencabut sesi lain karena sesi terikat `credential_hash`. Belum ada rencana menaikkan parameter |
| F8 replay akun | Sistem resi menyimpan hash isi permintaan, yang di sini memuat password. Perlu desain sendiri |
| T-08 test ke TypeScript | Besar, tidak mengubah perilaku |
| Refactor `write.ts`, baris padat harvest, kait `0011` | Kosmetik atau baru berguna saat migrasi data berikutnya |
| B19 BMKG di backend | Sudah berjalan di mobile. Memindahkannya perlu keputusan dan perubahan mobile |

**Database:** tidak ada koneksi ke database dev maupun Turso pada tahap ini. Semua test memakai `:memory:` atau file sementara.

Hasil akhir yang di-push: `npm run check` **319/319** (angka 331 di bagian 1 masih memuat test B11), `flutter test` **364/364**, `npm run build` lulus.
