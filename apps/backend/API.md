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
- `PATCH` atau nonaktifkan yang tidak mengubah apa pun tidak menaikkan `version` dan tidak muncul di `/sync/changes`.

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
| `POST /auth/login` | `username`, `password` | Membalas token dan `user`. Gagal: `401 INVALID_CREDENTIALS`. Akun nonaktif dengan password benar: `403 ACCOUNT_DEACTIVATED`; dengan password salah tetap `401`, jadi status akun tidak bocor ke penebak |
| `POST /auth/refresh` | `refresh_token` | Membalas token baru. Refresh token sekali pakai |
| `GET /auth/me` | | Pengguna aktif |
| `POST /auth/logout` | | `204` |

Access token berlaku 15 menit. Sesi berakhir 7 hari setelah refresh terakhir, dan paling lambat 30 hari setelah login.

## Akun

Endpoint ini tidak memakai `Idempotency-Key`. Pengiriman ulang `POST /employees` yang berhasil dibalas `409 USERNAME_TAKEN`.

**Aturan username.** Username disimpan dan dikembalikan dalam bentuk baku: Unicode NFC dan huruf kecil. `Budi`, `budi`, dan `BUDI` satu akun, dan login menerima ejaan apa pun. Username 1–50 karakter, tanpa karakter kontrol, karakter tak terlihat (lebar nol, pembalik arah), spasi selain spasi biasa, spasi ganda, atau spasi di ujung. Selain itu `400 VALIDATION_ERROR`; username yang hanya beda huruf besar kecil atau susunan Unicode dari akun lain dibalas `409 USERNAME_TAKEN`.

**Aturan lain.** `password` 12–128 karakter dan memuat minimal satu karakter yang terlihat. `no_telepon` memuat minimal satu angka.

**Email.** Disimpan dan dikembalikan dalam huruf kecil. Harus unik di semua akun, tanpa membedakan huruf besar kecil; akun nonaktif tetap memegang emailnya. Bentrok dibalas `409 EMAIL_TAKEN` pada `POST /employees`, `PATCH /employees/:id`, dan `PATCH /profile`. Akun tanpa email boleh banyak.

**Mengosongkan kolom.** `email`, `no_telepon`, dan `alamat` boleh `null`, string kosong, atau hanya spasi; ketiganya mengosongkan kolom dan disimpan sebagai `null`. `nama` tidak boleh kosong.

**Teks.** `nama` satu baris tanpa karakter kontrol, tak terlihat, pembalik arah, atau spasi selain spasi biasa. `alamat` boleh beberapa baris (baris baru dan tab sah) dengan aturan yang sama untuk karakter lain. Pelanggaran dibalas `400 VALIDATION_ERROR`.

**Daftar dan pencarian.** `GET /employees` memakai `page` dan `limit` seperti daftar lain dan membalas `meta`. Query `q` mencari teks apa adanya di `nama` dan `username`: `%` dan `_` bukan wildcard, huruf besar kecil tidak dibedakan (juga untuk é), dan é yang disusun satu atau dua kodepoin dianggap sama. Id yang bukan pegawai atau tidak ada dibalas `404 ACCOUNT_NOT_FOUND`.

| Endpoint | Izin | Body atau query |
|---|---|---|
| `GET /employees` | `pegawai:manage` | Query: `status_aktif`, `q` |
| `GET /employees/:id` | `pegawai:manage` | |
| `POST /employees` | `pegawai:manage` | `nama`, `username`, `password` (12–128 karakter), `email?`, `no_telepon?`, `alamat?` |
| `PATCH /employees/:id` | `pegawai:manage` | Field yang sama, semuanya opsional. Akun nonaktif: `409 ACCOUNT_DEACTIVATED` |
| `POST /employees/:id/deactivate` | `pegawai:manage` | Tanpa body (body kosong atau `{}` juga diterima). `204`, dan sesi akun itu dicabut |
| `POST /employees/:id/activate` | `pegawai:manage` | Tanpa body (body kosong atau `{}` juga diterima). `204` |
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

`estimasi_panen` adalah tanggal pemindahan ditambah 45 hari.

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

## Pindaian hama

Izin: `deteksi:read`, `deteksi:write` (hanya petani). Satu baris per **foto**; hitungan per kelas ada di `deteksi`. Foto harus berada di folder pindai milik akun itu sendiri: `https://res.cloudinary.com/<cloud_name>/image/upload/v<versi>/hidrosense/pindai/<id_user>/<berkas>`, dan `cloudinary_public_id` (bila dikirim) berawalan `hidrosense/pindai/<id_user>/`. Tanpa konfigurasi Cloudinary dibalas `503 UPLOAD_NOT_CONFIGURED`.

| Endpoint | Body atau query |
|---|---|
| `POST /pindaian` | `id_pemindahan`, `gambar`, `cloudinary_public_id?`, `versi_model`, `deteksi` (paling banyak 3: `hama`, `jumlah`, `confidence_maks?`; daftar kosong = tidak ada hama) |
| `GET /pindaian`, `GET /pindaian/:id` | Query daftar: `id_pemindahan`, `page`, `limit` |

Kesalahan: `422 TRANSFER_NOT_FOUND`, `404 DETECTION_NOT_FOUND`.

## Rekomendasi rotasi obat

Izin: `rekomendasi:read` (baca), `deteksi:write` (membuat), `rekomendasi:decide` (terima/tolak; menerima juga butuh `perawatan:write`). Hanya petani. Penulisan memakai `Idempotency-Key`.

Rekomendasi dibuat per **meja** dan hama. Yang dirotasi adalah kelompok mode of action (MoA, skema IRAC), bukan nama produk: dua produk dengan MoA sama dianggap pilihan yang sama. Aturan mesin (forward chaining):

- `ringan`: cara paling ringan dulu (mekanis, hayati, nabati).
- `sedang`: agen hayati atau nabati dulu; bila tidak ada, kimia dengan MoA berbeda.
- `berat`: kimia dengan MoA yang tidak dipakai pada 2 `perawatan` ber-MoA terakhir di meja itu. Semua hama dihitung, karena satu semprotan mengenai semuanya. Cara tanpa MoA (perangkap, buang daun) tidak menggeser jendela itu.
- Obat yang ditolak dengan alasan `tidak_tersedia` atau `harga` dalam 30 hari terakhir, di meja mana pun, tidak disarankan lagi.
- Tidak ada pilihan yang lolos: opsi lain yang aman (`ROT-FALLBACK`), tanpa mengulang MoA terblokir.

| Endpoint | Body atau query |
|---|---|
| `POST /rekomendasi-obat` | `id_meja`, `hama` (`thrips`, `whitefly`, `aphids`), `tingkat` (`ringan`, `sedang`, `berat`), `id_hasil_deteksi?` (harus dari meja yang sama). `201` baru. `200` bila sudah ada saran menunggu untuk meja dan hama itu: dengan `tingkat` dan foto yang sama saran dikembalikan apa adanya (`replayed: true`); bila berbeda saran itu dihitung ulang (`replayed: false`) |
| `GET /rekomendasi-obat`, `GET /rekomendasi-obat/:id` | Query daftar: `status` (`menunggu`, `diterima`, `ditolak`), `id_meja`, `hama`, `page`, `limit` |
| `POST /rekomendasi-obat/:id/terima` | `tanggal_aplikasi?` (bawaan hari ini, tidak boleh di masa depan), `catatan?`, `bahan?` (1 sampai 5 baris unik `id_inventaris`, `jumlah`, `satuan`; butuh `inventaris:write`). Membuat `perawatan` (tindakan nyata) yang menjadi riwayat rotasi, dan memotong stok bahan dalam transaksi yang sama. Stok kurang (`409 INSUFFICIENT_STOCK`) atau satuan salah (`422 UNIT_MISMATCH`) membatalkan seluruh penerimaan. Respons memuat `bahan_terpakai` |
| `POST /rekomendasi-obat/:id/tolak` | `alasan` (`tidak_tersedia`, `harga`, `sudah_ditangani`, `tidak_yakin_hama`, `lainnya`), `catatan?` (wajib bila `lainnya`, paling panjang 500). Penolakan bukan tindakan dan tidak memblokir MoA |

Status berubah satu arah dan dijaga trigger database: yang sudah `diterima` atau `ditolak` tidak bisa diubah atau dihapus. Mengulang keputusan yang sama (termasuk catatan dan tanggal yang dikirim) dibalas `200` dengan `replayed: true`; keputusan atau isi berbeda dibalas `409 RECOMMENDATION_ALREADY_DECIDED`.

Setiap rekomendasi memuat `obat.sumber`, `obat.terverifikasi`, `obat.phi_hari` dan `obat.phi_sumber`. Katalog berasal dari riset web dan belum diverifikasi pakar. `phi_hari` diisi dari label/panduan Amerika Serikat untuk selada (`phi_sumber` menyebut asalnya, wajib terisi bila `phi_hari` terisi); kosong berarti tidak ada data dan masa tunggu panen harus dicek pada label produk. Status pendaftaran untuk selada di Indonesia tidak terkonfirmasi.

Kesalahan: `422 TABLE_NOT_FOUND`, `422 DETECTION_NOT_FOUND`, `422 DETECTION_TABLE_MISMATCH`, `404 RECOMMENDATION_NOT_FOUND`, `409 NO_RECOMMENDATION`, `409 RECOMMENDATION_ALREADY_DECIDED`.

## Unggahan foto

Izin: `deteksi:write`. Aplikasi mengunggah langsung ke Cloudinary; backend hanya menandatangani.

| Endpoint | Catatan |
|---|---|
| `POST /unggahan/tanda-tangan` | Tanpa body. Mengembalikan `cloud_name`, `api_key`, `timestamp`, `folder`, `signature`, `upload_url`. Kirim ke Cloudinary persis `folder`, `timestamp`, `api_key`, `signature`. Folder dikunci server per pengguna. `503 UPLOAD_NOT_CONFIGURED` bila belum dikonfigurasi |

Konfigurasi lewat `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`. Ketiganya diisi bersama (production gagal start bila setengah terisi). `api_secret` hanya ada di environment server.

## Sinkronisasi

| Endpoint | Catatan |
|---|---|
| `GET /sync/changes` | Query: `cursor`, `limit` (paling besar 200). Lihat `docs/panduan-menjalankan-backend.md` bagian 7 |
| `POST /sync/operations` | Mencadangkan `public_id` untuk `client_id` sebelum catatannya dibuat |
| `GET /sync/status` | Query wajib: `device_id` (UUID dari aplikasi). Mengembalikan `data.last_synced_at` (ISO 8601) atau `null` bila perangkat itu belum pernah sinkron. Dipakai layar Sinkron supaya jam "Terakhir sinkron" tidak kembali ke awal |
| `POST /sync/status` | Body: `{ "device_id": "<uuid>" }`. Mencatat sinkron yang baru selesai memakai jam server, tidak pernah mundur. Aman diulang. Dicatat per pengguna dan per perangkat |

## Cuaca

Izin: `cuaca:read` (petani). Aplikasi memilih desa/kelurahan lalu meminta prakiraan BMKG untuk kode `adm4`-nya. Daftar wilayah berasal dari wilayah.id (kode Kemendagri bertitik, sama dengan `adm4` BMKG), posisi GPS diterjemahkan lewat OpenStreetMap Nominatim, prakiraan dari API publik BMKG. Semuanya disimpan sementara di server.

| Endpoint | Catatan |
|---|---|
| `GET /weather/regions` | Query: `level` = `province`/`regency`/`district`/`village`; `parent` = kode induk (`35`, `35.09`, `35.09.12`), tanpa `parent` hanya untuk `province`. Mengembalikan `data: [{ id, name }]`; desa juga punya `adm4`. Disimpan 24 jam |
| `GET /weather/locate` | Query: `lat`, `lon`. Mengembalikan `adm4`, `province`, `regency`, `district`, `village`, `approximate`. Nominatim sering tanpa kecamatan dan mengeja desa sedikit beda dari daftar resmi, jadi desa dicari dari nama di seluruh kabupaten (ejaan persis lebih dulu, lalu mirip) dan desa kembar dipilih yang terdekat. `approximate: true` berarti desa persisnya tidak dikenali dan yang dipakai desa terdekat di kecamatan yang sama. `404 LOCATION_NOT_FOUND` di luar Indonesia atau bila nama tidak cocok |
| `GET /weather/forecast` | Query: `adm4`. `data` adalah jawaban BMKG apa adanya; `meta.stale` true bila BMKG gangguan dan yang disajikan prakiraan terakhir (paling lama 6 jam). Disimpan 10 menit. `502 WEATHER_UPSTREAM_UNAVAILABLE` bila tidak ada cadangan |

Saat mengirim antrean, kirim induk lebih dulu, misalnya penyemaian sebelum pemindahan, karena anak merujuk ID server milik induk. Kalau respons hilang, kirim ulang dengan kunci yang sama untuk mendapatkan ID itu.

## Belum tersedia

Endpoint `perawatan` mandiri (daftar tindakan) dan pemotongan stok otomatis saat rekomendasi diterima belum dibangun. Cuaca BMKG berjalan di aplikasi mobile, bukan di backend.
