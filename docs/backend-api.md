# Kontrak API Backend HidroSense

Versi B001–B005. Base URL lokal: `http://127.0.0.1:3000`. Prefix bisnis: `/api/v1`. Production menggunakan HTTPS melalui reverse proxy dengan IP/CIDR tepercaya pada `TRUSTED_PROXIES`. HTTP API production ditolak dengan 426; health checks tetap dapat diakses dari jaringan internal.

## Endpoint yang tersedia

| Method | Path | Autentikasi | Respons utama |
| --- | --- | --- | --- |
| GET | `/health/live` | Publik | 200 ketika proses hidup |
| GET | `/health/ready` | Publik | 200 ketika database/migrasi siap, 503 jika tidak |
| POST | `/api/v1/auth/login` | Username/password | 200 token dan identitas; 400/401/429 |
| POST | `/api/v1/auth/refresh` | Refresh token | 200 pasangan token baru; 400/401/429 |
| GET | `/api/v1/auth/me` | Bearer access token | 200 identitas dan izin saat ini; 401 |
| POST | `/api/v1/auth/logout` | Bearer access token | 204 tanpa body; 401 |

Bootstrap tersedia melalui CLI `npm run auth:bootstrap`, bukan endpoint publik. Tujuh endpoint akun pegawai/profil tersedia pada [kontrak B003](./backend-accounts-api.md). B004 menambah POST `/api/v1/sync/operations` khusus `sync.reserve-id`. B005 menambah daftar/detail/tambah/ubah/nonaktifkan untuk `jenis-inventaris`, `obat`, dan `inventaris`. Penulisan menerima `Idempotency-Key` UUID; replay sama memberi 200 dan key sama dengan isi berbeda memberi 409 `OPERATION_CONFLICT`. `stok_minimum` memakai string desimal.

## Request dan respons

Body menggunakan `Content-Type: application/json`, maksimum 16 KiB pada tahap autentikasi. Field di luar schema ditolak; tipe angka tidak otomatis diubah menjadi string. Username bersifat case-sensitive sesuai unique constraint database. Login menerima username 1–50 karakter nonkosong dan password 1–128 karakter; bootstrap mewajibkan password 12–128 karakter.

Login:

```json
{ "username": "nama-akun", "password": "password-pengguna" }
```

Respons login (`access_token` dan `refresh_token` pada contoh adalah placeholder):

```json
{
  "data": {
    "token_type": "Bearer",
    "access_token": "<token-acak>",
    "refresh_token": "<token-refresh-acak>",
    "expires_in": 900,
    "access_expires_at": "2026-09-30T10:15:00.000Z",
    "refresh_expires_at": "2026-10-07T10:00:00.000Z",
    "user": {
      "id_user": "1",
      "nama": "Nama Pengguna",
      "username": "nama-akun",
      "role": "pegawai",
      "permissions": ["inventaris:read", "penyemaian:read", "budidaya:read", "panen:read", "inventaris:write", "penyemaian:write", "budidaya:write", "panen:write"]
    }
  }
}
```

`GET /auth/me` memakai `Authorization: Bearer <access_token>` dan mengembalikan `{ "data": { ...identitas... } }`, tanpa token maupun hash password. `POST /auth/logout` menggunakan header yang sama. Access token yang sudah kedaluwarsa perlu direfresh dahulu untuk logout server, atau pasangan token dibuang pada perangkat setelah sesi berakhir.

Refresh:

```json
{ "refresh_token": "<token-refresh-aktif>" }
```

Respons refresh berisi field token yang sama seperti login, tanpa `user`. Access token berlaku maksimal 15 menit dan tidak melewati masa refresh. Refresh berlaku maksimal tujuh hari sejak login, tidak diperpanjang secara bergulir. Setiap refresh sukses mengganti kedua token; token lama tidak berlaku lagi. Dua refresh bersamaan menghasilkan satu keberhasilan dan satu 401. Klien harus mengurutkan refresh. Jika respons refresh hilang, token lama tidak bisa dipakai ulang; login ulang diperlukan.

Semua respons menyertakan `X-Request-Id` yang dibuat server dan `Cache-Control: no-store`. Respons gagal:

```json
{
  "error": {
    "code": "FORBIDDEN",
    "message": "Akses tidak diizinkan untuk akun ini.",
    "request_id": "<id-request>"
  }
}
```

| Status | Kode | Arti |
| --- | --- | --- |
| 400 | `VALIDATION_ERROR` / `BAD_REQUEST` | Isi request atau JSON tidak valid |
| 401 | `INVALID_CREDENTIALS` | Username/password tidak sah, akun nonaktif, atau role tidak didukung |
| 401 | `UNAUTHENTICATED` | Sesi/token hilang, invalid, kedaluwarsa, dicabut, atau kredensial berubah |
| 403 | `FORBIDDEN` | Akun aktif tidak mempunyai izin operasi |
| 404 | `NOT_FOUND` | Route tidak tersedia |
| 413 | `PAYLOAD_TOO_LARGE` | Body melebihi batas |
| 415 | `UNSUPPORTED_MEDIA_TYPE` | Content-Type tidak didukung |
| 426 | `HTTPS_REQUIRED` | API production diakses tanpa HTTPS yang terverifikasi |
| 429 | `RATE_LIMITED` | Tunggu jumlah detik pada header `Retry-After` |
| 500 | `INTERNAL_ERROR` | Kesalahan internal; detail SQL/stack tidak dikirim |
| 503 | `NOT_READY` | Pemeriksaan readiness gagal |

Rate limit: maksimum 120 request `/api/` per IP per 60 detik dan 10 percobaan login per username per 15 menit, termasuk login sukses. Counter disimpan dalam database bersama. Header `X-Forwarded-For` dari sumber yang tidak tercantum dalam `TRUSTED_PROXIES` tidak mengubah IP pemanggil. Gangguan penyimpanan throttle menghasilkan kegagalan request, bukan bypass throttle.

## Matriks hak akses

Keputusan pengguna: ikuti System Request, termasuk hak pegawai atas panen dan penolakan akses penjualan. Matrix ini adalah kontrak guard untuk fitur berikutnya. `read` mencakup daftar/detail; `write` mencakup tambah/ubah serta nonaktifkan jika use case mengizinkannya, bukan hak menghapus histori. Scope `budidaya` mencakup meja, pemindahan/pertumbuhan, HSS, estimasi panen, dan kerusakan.

| Modul | Petani | Pegawai |
| --- | --- | --- |
| Inventaris/stok | Baca | Baca dan tulis |
| Penyemaian/pengingat 15 hari | Baca | Baca dan tulis |
| Meja/pertumbuhan/kerusakan | Baca | Baca dan tulis |
| Panen | Baca | Baca dan tulis |
| Penjualan | Baca dan tulis | Tidak diizinkan |
| Deteksi hama | Baca dan catat hasil | Tidak diizinkan |
| Rekomendasi/perawatan hama | Baca, putuskan, catat tindakan | Tidak diizinkan |
| Pengelolaan pegawai | Kelola | Tidak diizinkan |
| Profil | Baca dan ubah sesuai field yang diizinkan | Identitas sesi melalui `/auth/me` saja |
| Cuaca | Baca (fitur ditunda B19) | Tidak diizinkan |

Guard membaca role dan status pengguna dari database pada setiap request. Permissions yang dikirim klien diabaikan/tidak diterima sebagai sumber hak akses. Keberadaan permission tidak berarti endpoint fiturnya sudah dibuat. Perubahan matrix berikutnya harus disepakati dan diuji.

## Kontrak data untuk slice berikutnya

- **ID**: string angka positif dalam JSON untuk ID integer domain, misalnya `"12"`. Tolak tanda minus, pecahan, format eksponen, serta nilai melebihi rentang aman driver sebelum query. DB masih menyimpan PK integer. ID sesi internal tidak dikirim sebagai ID domain.
- **Tanggal kegiatan**: `YYYY-MM-DD` sebagai tanggal kalender Asia/Jakarta, divalidasi kalender sebenarnya. Jangan mengubah tanggal semai menjadi timestamp UTC untuk menghitung HSS. Estimasi usia berdasarkan selisih tanggal kalender.
- **Waktu kejadian**: RFC 3339 UTC dengan akhiran `Z` pada JSON. Waktu sesi disimpan sebagai epoch milidetik pada tabel autentikasi. Timestamp domain lama dikonversi secara eksplisit ketika endpoint domain dibuat.
- **Desimal**: gunakan string desimal pada kontrak input/output kuantitas/harga, maksimum dua digit pecahan sesuai field sumber; confidence maksimum empat. Perhitungan uang memakai integer berskala/aritmetika desimal, pembulatan half-up ke dua desimal pada total. Jangan memakai floating point JavaScript sebagai dasar validasi saldo. Implementasi penyimpanan/perhitungan eksak dan batas `DECIMAL(p,s)` harus dituntaskan dengan migrasi bila diperlukan sebelum B06; auth tidak memiliki field uang.
- **Pagination**: endpoint daftar berikutnya menggunakan `page` (default 1) dan `limit` (default 20, maksimum 100), keduanya integer positif; urutan stabil dengan ID sebagai pembeda. Respons daftar `{ data: [...], meta: { page, limit, total } }`. Endpoint daftar belum ada pada B001/B002.
- **Penulisan**: parameter SQL selalu dibind. Kontrak identitas operasi dan retry transaksi bisnis dikerjakan B04 sebelum fitur pencatatan. Refresh sesi menggunakan rotasi single-use, bukan kontrak idempotency bisnis.

## Penggunaan dan integrasi

Jalankan langkah instalasi pada [README backend](../apps/backend/README.md). Header otorisasi, password, dan token tidak boleh dimasukkan ke URL, log, atau commit. Penerapan HTTPS, CORS allowlist, dan proxy tepercaya harus sesuai deployment. CORS berlaku untuk browser; otorisasi tetap dilakukan server untuk semua klien.

Kontrak sesi luring serta breakdown tersedia pada [B001/B002](./backend-b001-b002.md). Server tidak memvalidasi permintaan saat koneksi terputus; saat tersambung kembali, refresh/login dan pemeriksaan hak akses tetap berlaku.

Referensi implementasi: [Fastify validation](https://fastify.dev/docs/latest/Reference/Validation-and-Serialization/), [Fastify server configuration](https://fastify.dev/docs/latest/Reference/Server/), [Node.js scrypt](https://nodejs.org/api/crypto.html#cryptoscryptpassword-salt-keylen-options-callback). Versi dependency yang benar-benar dipakai terkunci di `package-lock.json`.
