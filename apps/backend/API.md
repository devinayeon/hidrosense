# Kontrak API Backend HidroSense

Untuk tim mobile dan tester. Semua path berawalan `/api/v1`, kecuali health check.

## Aturan umum

### Autentikasi
Kirim `Authorization: Bearer <access_token>`. Tanpa token yang sah, server membalas `401 UNAUTHENTICATED`. Tanpa izin, server membalas `403 FORBIDDEN`.

### Format respons
```json
{ "data": {}, "meta": { "page": 1, "limit": 20, "total": 1, "total_pages": 1 } }
{ "error": { "code": "VALIDATION_ERROR", "message": "...", "request_id": "..." } }
```
`meta` hanya ada pada daftar. Pakai `code` untuk logika klien, dan `message` untuk ditampilkan.

### Format nilai
| Jenis | Format |
|---|---|
| ID | String angka, misalnya `"12"` |
| Tanggal | `YYYY-MM-DD`, dibandingkan dengan tanggal WIB |
| Jumlah stok, berat, harga | String desimal, paling banyak 2 angka di belakang titik, misalnya `"1.50"` |
| Jumlah tanaman, benih, lubang | Angka bulat positif |

### Daftar
`page` dan `limit` lewat query. `limit` bawaan 20, paling besar 100. Parameter yang tidak dikenal dibalas `400`.

### Header endpoint tulis
Berlaku untuk semua `POST` dan `PATCH` pada bagian Inventaris sampai Penjualan.

| Header | Aturan |
|---|---|
| `Idempotency-Key` | Wajib. UUID baru per operasi. Pakai lagi nilai yang sama saat mengirim ulang |
| `X-Client-Id` | Opsional. UUID, hanya untuk operasi yang membuat catatan baru. Pada operasi lain dibalas `400` |

Pengiriman ulang dengan kunci dan isi sama dibalas `200` dengan `"replayed": true`, tanpa menulis lagi. Kunci sama dengan isi berbeda dibalas `409 OPERATION_CONFLICT`.

Respons tulis berbentuk `{ "data": {}, "operation": { "operation_key", "revision", "public_id", "version" }, "replayed": false }`.

### Konflik antar perangkat
Setiap catatan membawa `version`. Kirim `expected_version` berisi versi terakhir yang dibaca:
- Opsional pada meja tanam, penyemaian, pemindahan, kerusakan, inventaris, obat, dan jenis inventaris. Konflik dibalas `409 VERSION_CONFLICT`. Tanpa field ini, penulisan terakhir yang menang.
- Wajib pada panen (`409 HARVEST_VERSION_CONFLICT`) dan penjualan (`409 SALE_VERSION_CONFLICT`).

### Kode status
| Status | Arti |
|---|---|
| `400` | Input tidak valid, termasuk tanggal di masa depan |
| `404` | Catatan di URL tidak ada |
| `409` | Bentrok dengan keadaan data, misalnya stok tidak cukup |
| `422` | Catatan yang dirujuk di body tidak ada atau tidak aktif |
| `426` | Production menerima HTTPS saja |
| `429` | Terlalu banyak permintaan. Baca header `Retry-After` |
| `503` | Layanan belum siap. Aman dicoba ulang |

Batas permintaan: 120 per menit per IP, dan 10 percobaan login per 15 menit per IP dan username.

## Hak akses

| Izin | Petani | Pegawai |
|---|---|---|
| `inventaris:*`, `penyemaian:*`, `budidaya:*`, `panen:*` | Ya | Ya |
| `penjualan:*`, `pegawai:manage`, `profil:*` | Ya | Tidak |

## Health check

| Endpoint | Arti |
|---|---|
| `GET /health/live` | Proses hidup |
| `GET /health/ready` | Database terhubung dan semua migrasi sudah diterapkan; bila belum, `503 NOT_READY` |

## Autentikasi

| Endpoint | Body | Catatan |
|---|---|---|
| `POST /auth/login` | `username`, `password` | Membalas token dan `user`. Gagal: `401 INVALID_CREDENTIALS` |
| `POST /auth/refresh` | `refresh_token` | Membalas token baru. Refresh token sekali pakai |
| `GET /auth/me` | | Pengguna aktif |
| `POST /auth/logout` | | `204` |

Access token berlaku 15 menit. Sesi berakhir 7 hari setelah refresh terakhir, dan paling lambat 30 hari setelah login.

## Akun

Endpoint ini tidak memakai `Idempotency-Key`. Pengiriman ulang `POST /employees` yang berhasil dibalas `409 USERNAME_TAKEN`.

| Endpoint | Izin | Body atau query |
|---|---|---|
| `GET /employees` | `pegawai:manage` | Query: `status_aktif`, `q` |
| `GET /employees/:id` | `pegawai:manage` | |
| `POST /employees` | `pegawai:manage` | `nama`, `username`, `password` (12–128 karakter), `email?`, `no_telepon?`, `alamat?` |
| `PATCH /employees/:id` | `pegawai:manage` | Field yang sama, semuanya opsional. Akun nonaktif: `409 ACCOUNT_DEACTIVATED` |
| `POST /employees/:id/deactivate` | `pegawai:manage` | Tanpa body. `204`, dan sesi akun itu dicabut |
| `POST /employees/:id/activate` | `pegawai:manage` | Tanpa body. `204` |
| `GET /profile` | `profil:read` | |
| `PATCH /profile` | `profil:write` | Field akun. Mengubah `username` atau `password` wajib menyertakan `current_password`, dan mencabut semua sesi |

## Inventaris

Izin: `inventaris:read` untuk `GET`, `inventaris:write` untuk lainnya. Daftar mendukung query `status_aktif`.

| Endpoint | Body |
|---|---|
| `GET`, `POST /jenis-inventaris`; `GET`, `PATCH /jenis-inventaris/:id` | `nama_jenis` |
| `POST /jenis-inventaris/:id/deactivate` | |
| `GET`, `POST /obat`; `GET`, `PATCH /obat/:id` | `nama_obat`, `jenis_obat?`, `dosis?`, `aturan_penggunaan?`, `deskripsi?` |
| `POST /obat/:id/deactivate` | |
| `GET`, `POST /inventaris`; `GET`, `PATCH /inventaris/:id` | `id_jenis_inventaris`, `id_obat?`, `nama_barang`, `satuan`, `stok_minimum?` |
| `POST /inventaris/:id/deactivate` | |

Satuan yang sudah punya riwayat stok tidak bisa diubah: `409 UNIT_LOCKED`.

## Stok

Izin: `inventaris:read`, `inventaris:write`.

| Endpoint | Body atau query |
|---|---|
| `POST /stok` | `jenis_stok` (`masuk`, `keluar`), `details[]`: `id_inventaris`, `jumlah`, `satuan`; `keterangan?` |
| `POST /stok/:id/reverse` | `keterangan` (wajib). Membuat gerakan pembalik; boleh membawa `X-Client-Id` |
| `GET /stok`, `GET /stok/:id` | Query daftar: `id_inventaris`, `jenis_stok` |
| `GET /inventaris/:id/saldo` | Membalas `saldo`, `stok_minimum`, `di_bawah_minimum` |

Kesalahan: `409 INSUFFICIENT_STOCK`, `409 STOK_ALREADY_REVERSED`, `409 REVERSAL_NOT_ALLOWED`, `422 INVENTARIS_NOT_AVAILABLE`, `422 UNIT_MISMATCH`.

## Penyemaian

Izin: `penyemaian:read`, `penyemaian:write`.

| Endpoint | Body atau query |
|---|---|
| `POST /penyemaian` | `tanggal_semai`, `jumlah_benih`, `materials[]` (minimal satu): `id_inventaris`, `jumlah`, `satuan`; `keterangan?`. Mengurangi stok |
| `GET /penyemaian` | Query: `status_penyemaian`, `siap_pindah=1` (usia minimal 15 hari) |
| `GET /penyemaian/:id` | Termasuk `usia_hari`, `siap_pindah`, `sisa_benih`, `stok_konsumsi` |
| `PATCH /penyemaian/:id` | `jumlah_benih?`, `status_penyemaian?`, `keterangan?`, `expected_version?` |

Penyemaian `selesai` tidak bisa diubah: `409 SOWING_COMPLETED`.

## Meja tanam

Izin: `budidaya:read`, `budidaya:write`.

| Endpoint | Body atau query |
|---|---|
| `POST /meja-tanam` | `kode_meja`, `jumlah_lubang`, `status_meja?`, `keterangan?` |
| `GET /meja-tanam` | Query: `status_meja` |
| `GET /meja-tanam/:id` | Termasuk `tanaman_aktif`, `kapasitas_tersedia`, `saldo_valid` |
| `PATCH /meja-tanam/:id` | Field yang sama, semuanya opsional, plus `expected_version?` |

- Status `penuh` dihitung server dan tidak bisa dikirim klien: `400 TABLE_STATUS_DERIVED`.
- Meja dengan data tidak konsisten tetap muncul di daftar dengan `saldo_valid: false` dan `kapasitas_tersedia: 0`. Detailnya dibalas `409 TABLE_BALANCE_INVALID`.
- `PATCH` boleh memperbaiki meja seperti itu, asalkan hasilnya valid.

## Pemindahan

Izin: `budidaya:read`, `budidaya:write`.

| Endpoint | Body atau query |
|---|---|
| `POST /pemindahan` | `id_penyemaian`, `id_meja`, `tanggal_pemindahan`, `jumlah_tanaman`, `keterangan?` |
| `GET /pemindahan` | Query: `id_meja`, `id_penyemaian` |
| `GET /pemindahan/:id` | Termasuk `umur_semai_hari`, `estimasi_panen`, `hss`, `hst`, `sisa_hari_panen`, `tanaman_aktif` |
| `PATCH /pemindahan/:id` | `keterangan?`, `expected_version?` |

Kesalahan: `400 SEEDLING_NOT_READY`, `409 SEEDLING_INSUFFICIENT`, `409 SOWING_INACTIVE`, `409 TABLE_NOT_AVAILABLE`, `409 TABLE_CAPACITY_EXCEEDED`.

## Kerusakan

Izin: `budidaya:read`, `budidaya:write`.

| Endpoint | Body atau query |
|---|---|
| `POST /kerusakan` | `id_pemindahan`, `tanggal_kejadian`, `jumlah_tanaman`, `jenis_kerusakan`, `keterangan?` |
| `GET /kerusakan`, `GET /kerusakan/:id` | Query daftar: `id_pemindahan` |
| `PATCH /kerusakan/:id` | `tanggal_kejadian?`, `jumlah_tanaman?`, `jenis_kerusakan?`, `keterangan?`, `expected_version?` |

Kesalahan: `409 DAMAGE_EXCEEDS_ACTIVE`, `409 DAMAGE_RESTORE_EXCEEDS_TABLE_CAPACITY`.

## Panen

Izin: `panen:read`, `panen:write`.

| Endpoint | Body |
|---|---|
| `POST /panen` | `tanggal_panen`, `keterangan?`, `details[]`: `id_pemindahan`, `jumlah_tanaman`, `berat_total`, `berat_reject` |
| `GET /panen`, `GET /panen/:id` | |
| `PATCH /panen/:id` | `expected_version` (wajib), `keterangan?`, `details[]?`: `id_detail_panen`, `berat_total`, `berat_reject` |

`berat_layak` dihitung dari `berat_total − berat_reject`. Kesalahan: `409 HARVEST_EXCEEDS_ACTIVE_PLANTS`, `409 HARVEST_WEIGHT_BELOW_SOLD`.

## Penjualan

Izin: `penjualan:read`, `penjualan:write`. Hanya petani.

| Endpoint | Body |
|---|---|
| `POST /penjualan` | `tanggal_penjualan`, `pembeli`, `status_pembayaran` (`lunas`, `belum_lunas`), `keterangan?`, `id_panen`, `jumlah_kg`, `harga_per_kg` |
| `GET /penjualan`, `GET /penjualan/:id` | |
| `PATCH /penjualan/:id` | `expected_version` (wajib), plus field yang sama. `id_panen`, `jumlah_kg`, dan `harga_per_kg` harus dikirim bersama |

`total_harga` = berat × harga. Kesalahan: `409 SALE_EXCEEDS_HARVEST_STOCK`, `409 HARVEST_NOT_SELLABLE`, `400 INVALID_SALE_DATE`.

## Sinkronisasi

| Endpoint | Catatan |
|---|---|
| `GET /sync/changes` | Query: `cursor`, `limit` (paling besar 200). Lihat `docs/panduan-menjalankan-backend.md` bagian 7 |
| `POST /sync/operations` | Mencadangkan `public_id` untuk `client_id` sebelum catatannya dibuat |

Saat mengirim antrean, kirim induk lebih dulu, misalnya penyemaian sebelum pemindahan, karena anak merujuk ID server milik induk. Kalau respons hilang, kirim ulang dengan kunci yang sama untuk mendapatkan ID itu.

## Belum tersedia

Deteksi hama, rekomendasi, dan perawatan belum dibangun. Cuaca BMKG berjalan di aplikasi mobile, bukan di backend.
