# Implementasi Backend B007: Penyemaian, Usia Bibit, Kesiapan 15 Hari, dan Pemakaian Bahan

Tanggal: 4 Oktober 2026, Asia/Jakarta.
Baseline commit: `8d415af`.
Scope: Implementasi fitur penyemaian lokal (B007).

---

## 1. Ringkasan Eksekutif

Fitur penyemaian (B007) telah selesai diimplementasikan secara vertikal dan lulus seluruh pengujian otomatis:
- Total tes backend: **164/164 lulus** (153 tes B000–B006 + 11 tes baru B007).
- Typecheck (`tsc --noEmit`) dan build (`tsc`) **bersih (0 error)**.
- Line limit check (`check:lines`) **lolos** (tidak ada file runtime melebihi 400 baris).

---

## 2. Komponen yang Dibangun

### Migrasi Basis Data:
- `migrations/0007_nursery.up.sql`: Menambahkan index `idx_penyemaian_user_date` dan trigger SQLite `trg_penyemaian_status_insert` & `trg_penyemaian_status_update` untuk memastikan `status_penyemaian IN ('aktif', 'selesai')`.
- `migrations/0007_nursery.down.sql`: Rollback trigger dan index secara aman dan kompatibel tanpa data loss.
- Integrasi sync identity: Menggunakan tabel `sync_resource_links` dan `sync_resource_versions` (mirror pola B005 & B006).

### Feature Slice (`src/features/nursery/`):
- `contracts.ts`: Skema validasi Zod untuk `createSowingSchema`, `updateSowingSchema`, `listSowingQuerySchema`.
- `store.ts`: Query SQL untuk list, detail, agregasi pemindahan (`countMoved`), serta kalkulasi usia hari (`usia_hari`) dan kesiapan pindah (`siap_pindah`) dengan zona waktu UTC+7 (Asia/Jakarta).
- `service.ts`: Logika bisnis pembuatan semai dengan konsumsi bahan stok atomik melalui `recordMovement` (origin: `{ id_penyemaian }`), serta validasi batas kapasitas pemindahan saat update.
- `write.ts`: Wrapper idempotent domain mutation menggunakan `executeDomainMutation` (menangani reservation `public_id`, versioning, dan replay).
- `index.ts`: Registrasi rute Fastify:
  - `POST /api/v1/penyemaian` (`penyemaian:write`)
  - `GET /api/v1/penyemaian` (`penyemaian:read`)
  - `GET /api/v1/penyemaian/:id` (`penyemaian:read`)
  - `PATCH /api/v1/penyemaian/:id` (`penyemaian:write`)

### Pengujian (`test/`):
- `test-support/nursery-fixture.js`: Fixture terisolasi untuk login aktor, setup inventaris, dan stok benih awal.
- `test/nursery.test.js`: 11 skenario pengujian komprehensif (N-01 hingga N-11):
  - N-01: Pembuatan semai + konsumsi stok keluar atomik + receipt domain.
  - N-02 & N-03: Idempotency replay (200) vs conflict key (409).
  - N-04: Filter list berdasarkan `status_penyemaian` dan `siap_pindah=1` (usia ≥ 15 hari).
  - N-05: Detail semai menampilkan usia, kesiapan, dan rincian stok konsumsi.
  - N-06: Validasi `jumlah_benih >= jumlah tanaman yang sudah dipindahkan`.
  - N-07: Update status ke 'selesai' + verifikasi kenaikan versi dan database trigger.
  - N-08: Penolakan konsumsi barang inventaris nonaktif.
  - N-09: Rollback atomik saat saldo stok tidak mencukupi (saldo tidak negatif).
  - N-10: Matriks hak akses: pegawai (read/write), petani (read only), anonim (401).
  - N-11: Preservasi format string untuk seluruh ID (signed64 safe).
- `test/nursery-migration.test.js`: Uji migrasi maju, mundur, dan re-apply dengan preservasi data.

---

## 3. Dokumentasi & Kontrak API

Kontrak API lengkap didokumentasikan di [`docs/backend-nursery-api.md`](backend-nursery-api.md).

## Hasil review 4 Oktober 2026

[Review B007–B008](reviews/b007-b008-2026-10-04.md) membuktikan dua koreksi B007: PATCH parsial menjaga `keterangan`, dan usia/kesiapan memakai clock aplikasi pada tanggal bisnis Jakarta. Migrasi forward `0008_nursery_list_index` mengoreksi indeks daftar lintas pengguna; `0007` tetap tidak diubah. Gate akhir: 177/177 tes backend, typecheck, batas baris, dan build lulus. Bukti ini lokal, belum deployment remote.
