# B004 — Fondasi sinkronisasi server

Tanggal: 1 Oktober 2026. Cakupan B004 adalah fondasi integritas sinkronisasi; antrean perangkat, push/pull lintas seluruh fitur, dan UI konflik tetap B017/mobile.

## Review B000–B003

B000 menyediakan migrasi ber-checksum, rollback, backup, foreign key, dan database SQLite/libSQL. B001 menetapkan error boundary, HTTPS production, rate limit, dan kontrak ID string. B002 menyediakan sesi serta otorisasi yang dibaca ulang dari database. B003 membuktikan transaksi tulis dapat mengautentikasi ulang actor di dalam transaksi dan mencabut sesi secara atomik. B004 memakai batas-batas tersebut tanpa mengubah mobile atau BMKG.

## Implementasi

- Migrasi `0003_sync_foundation` menambah receipt operasi per pengguna, peta UUID klien ke UUID publik, dan tabel versi resource untuk dipakai slice tulis berikutnya.
- `POST /api/v1/sync/operations` memerlukan Bearer token dan hanya menerima `sync.reserve-id`. Operasi domain tidak dapat dideklarasikan selesai melalui endpoint ini; handler domain menjalankan perubahan dan receipt dalam transaksi sama.
- Pengiriman ulang isi sama mengembalikan receipt sama dengan 200. Key sama dan isi berbeda memberi `409 OPERATION_CONFLICT`. Operasi baru memberi 201 dan revision global sebagai cursor perubahan.
- Pasangan `resource_type` dan `client_id` menghasilkan `public_id` stabil. Seluruh pembacaan, mapping, receipt, dan respons berada dalam satu transaksi write setelah autentikasi ulang.

BFRI: fit 4, testability 5, kompleksitas 2, risiko data 2, risiko operasional 2; skor 3. Karena tetap menyentuh identitas dan transaksi, pengujian integrasi dan regresi migrasi dijalankan.

## Bukti

`test/sync.test.js` menguji replay, konflik, isolasi actor, mapping ID, penolakan tipe operasi domain, input salah, dan akses anonim. Pengujian B005 membuktikan receipt dan perubahan bisnis commit bersama. `test/migrations.test.js` menguji migrasi/backup/restore. Jalankan `npm run check` dan `npm run build` dari `apps/backend`.

## Koreksi audit dan batas arsitektur 2 Oktober 2026

Audit lintas B001–B005 menemukan bahwa atomisitas receipt B005 belum disertai pengikatan identitas publik dan kenaikan versi resource. Kesimpulan awal tanpa temuan tidak mencakup kewajiban lintas slice tersebut dan telah dikoreksi.

Interface sync sekarang menjadi pemilik hashing/canonical payload, replay/conflict, reservasi UUID publik, pengikatan resource domain, versi, dan receipt. Handler bisnis menjalankan mutasi melalui interface tersebut di dalam transaksi write yang sama. Autentikasi serta permission diperiksa ulang di transaksi sebelum efek bisnis; kegagalan membatalkan seluruh perubahan.

Endpoint `sync.reserve-id` tetap hanya mereservasi mapping UUID klien ke UUID publik, tidak menjalankan mutasi domain dan tidak menaikkan versi resource. Create B005 dapat memakai reservasi tersebut melalui `X-Client-Id`; UUID klien yang sudah terikat pada record tidak boleh membuat record kedua. Receipt mutasi B005 menyertakan `public_id` dan `version`, sedangkan `revision` tetap cursor receipt global. Replay mempertahankan respons dan versi yang disimpan pada operasi pertama.

## Kontrak HTTP reservasi

`POST /api/v1/sync/operations` membutuhkan `Authorization: Bearer <access_token>` dan `Content-Type: application/json`. Semua actor aktif dengan role petani atau pegawai dapat melakukan reservasi. Reservasi tidak memberi izin melakukan mutasi domain; endpoint domain tetap memeriksa izin modul.

Body harus object dengan tepat lima field berikut. Semua field wajib, field tambahan ditolak, dan tidak ada coercion tipe.

| Field | Tipe dan validasi |
| --- | --- |
| `operation_key` | String UUID; identitas operasi per actor |
| `operation_type` | String literal `sync.reserve-id`; tipe operasi lain ditolak |
| `payload` | Object kosong `{}`; null, array, atau field tambahan ditolak |
| `resource_type` | String 1–80 karakter, pola `^[a-z][a-z0-9_.-]*$`; gunakan `jenis-inventaris`, `obat`, atau `inventaris` untuk B005 |
| `client_id` | String UUID klien; casing hexadecimal diterima lalu dinormalisasi lowercase |

`operation_key` wajib berada di body. Header `Idempotency-Key` B005 tidak menggantikannya. Key operasi diperlakukan sebagai teks exact: simpan dan kirim kembali ejaan key yang sama, termasuk kapitalisasi. Sebaliknya `client_id` adalah identitas UUID; casing berbeda tidak menciptakan identitas baru. Mapping diisolasi berdasarkan actor, resource type, dan UUID klien. Dua actor dapat menggunakan UUID klien yang sama tanpa berbagi mapping.

Contoh request:

```http
POST /api/v1/sync/operations
Authorization: Bearer <access_token>
Content-Type: application/json

{"operation_key":"5f9c14e6-76bc-4f68-a3cf-8e4fd877d744","operation_type":"sync.reserve-id","payload":{},"resource_type":"obat","client_id":"d95fe5e9-8ca7-4bc6-b0d7-3f1c70ab7c2e"}
```

Operasi baru memberi 201, replay key dan isi sama memberi 200 dengan `replayed: true`. Response sukses:

```json
{
  "data": { "public_id": "cc06496f-22ba-4ad9-b795-147bff7871f3" },
  "operation": {
    "operation_key": "5f9c14e6-76bc-4f68-a3cf-8e4fd877d744",
    "revision": "12",
    "public_id": "cc06496f-22ba-4ad9-b795-147bff7871f3"
  },
  "replayed": false
}
```

`public_id` adalah UUID server dan sama pada `data`/`operation`. `revision` adalah string integer cursor receipt global. Reservasi tidak membuat record bisnis, tidak menambah versi resource, dan tidak mengembalikan field `version`. Key baru untuk mapping yang sudah ada menghasilkan receipt/revision baru dengan public UUID yang sama. Replay tidak menambah receipt/revision dan mempertahankan envelope tersimpan; receipt lama tidak ditulis ulang.

Gunakan `client_id` yang sama pada header `X-Client-Id` create B005, bukan `public_id`. Setelah public UUID terikat pada record domain, create kedua dengan UUID klien yang sama ditolak oleh endpoint domain.

Response error mengikuti envelope B001:

```json
{"error":{"code":"VALIDATION_ERROR","message":"Input tidak sesuai kontrak API.","request_id":"<id-request>"}}
```

| HTTP | Code dan kondisi |
| --- | --- |
| 400 | `VALIDATION_ERROR`: schema/body/UUID/resource type tidak valid; `BAD_REQUEST`: JSON atau request malformed |
| 401 | `UNAUTHENTICATED`: token hilang, tidak valid, expired, actor nonaktif, atau sesi dicabut |
| 409 | `OPERATION_CONFLICT`: key yang sama dipakai untuk tipe/payload/resource/UUID klien berbeda |
| 409 | `CLIENT_ID_CONFLICT`: mapping lama beda casing menunjuk lebih dari satu public UUID |
| 413 | `PAYLOAD_TOO_LARGE`: body melewati batas B001 |
| 415 | `UNSUPPORTED_MEDIA_TYPE`: media type tidak didukung |
| 426 | `HTTPS_REQUIRED`: request API production tanpa HTTPS terverifikasi |
| 429 | `RATE_LIMITED`: batas request B001 terlampaui; ikuti `Retry-After` |
| 500 | `INTERNAL_ERROR`: gangguan internal, tanpa detail SQL/stack |

Semua respons menyertakan `X-Request-Id` dan `Cache-Control: no-store` sesuai B001. Request ID pada envelope error sama dengan header. Autentikasi diperiksa kembali dalam transaksi sebelum lookup/replay atau reservasi.

### Kompatibilitas mapping lama

Pembacaan mapping membandingkan UUID klien tanpa membedakan casing, tetapi tidak mengubah row lama atau receipt tersimpan. Hash receipt yang dibuat dengan casing lama masih dikenali melalui mapping yang sesuai. Mapping baru memakai lowercase. Bila versi lama pernah membuat mapping casing berbeda ke public UUID berbeda, request ditolak 409 `CLIENT_ID_CONFLICT` sebelum perubahan domain/receipt. Penyelesaian collision membutuhkan keputusan data tersendiri; server tidak menggabungkan histori secara otomatis.
