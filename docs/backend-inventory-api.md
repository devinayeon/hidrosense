# API inventaris B005

Semua path di bawah diawali `/api/v1`. Semua request memerlukan `Authorization: Bearer <access_token>`. Petani dapat membaca; pegawai dapat membaca dan menulis. Body JSON memakai `Content-Type: application/json`. Nama field tambahan ditolak pada body create/PATCH dan query daftar.

## Endpoint dan hasil

| Resource | Path | ID domain | Create | Daftar/detail | Ubah | Nonaktifkan |
| --- | --- | --- | --- | --- | --- | --- |
| Jenis | `/jenis-inventaris` | `id_jenis_inventaris` | POST | GET / GET `/:id` | PATCH `/:id` | POST `/:id/deactivate` |
| Obat | `/obat` | `id_obat` | POST | GET / GET `/:id` | PATCH `/:id` | POST `/:id/deactivate` |
| Inventaris | `/inventaris` | `id_inventaris` | POST | GET / GET `/:id` | PATCH `/:id` | POST `/:id/deactivate` |

Create baru menghasilkan 201 dan header `Location` menuju detail. Replay create menghasilkan 200. Detail, daftar, PATCH, dan deactivate menghasilkan 200. Deactivate mengubah `status_aktif` menjadi 0, mempertahankan record serta relasi histori. Tidak tersedia hard delete maupun reaktivasi.

`:id` dan ID referensi adalah string integer positif, maksimum `9223372036854775807`, tanpa nol di depan. `public_id` adalah UUID stabil; `version` adalah string integer. Client tidak boleh mengirim `public_id`, `version`, ID domain, atau `status_aktif` dalam body create/PATCH.

## Schema body

Semua string teks di-trim. String kosong setelah trim ditolak. Field bertanda nullable menerima `null`; field opsional yang tidak diberikan saat create disimpan sebagai `null`.

| Resource | Field | Create | Aturan |
| --- | --- | --- | --- |
| Jenis | `nama_jenis` | Wajib | String 1–50 karakter; unik |
| Obat | `nama_obat` | Wajib | String 1–100 karakter |
| Obat | `jenis_obat` | Opsional, nullable | String 1–50 karakter |
| Obat | `dosis` | Opsional, nullable | String 1–100 karakter |
| Obat | `aturan_penggunaan` | Opsional, nullable | String tidak kosong |
| Obat | `deskripsi` | Opsional, nullable | String tidak kosong |
| Inventaris | `id_jenis_inventaris` | Wajib | ID string; jenis harus aktif |
| Inventaris | `id_obat` | Opsional, nullable | ID string; obat harus aktif jika diberikan |
| Inventaris | `nama_barang` | Wajib | String 1–100 karakter |
| Inventaris | `satuan` | Wajib | String 1–30 karakter |
| Inventaris | `stok_minimum` | Opsional, nullable | String desimal positif; 1–10 digit sebelum titik, 1–2 digit setelah titik |

Contoh `stok_minimum`: `"10"`, `"10.5"`, `"0.25"`. Angka JSON, `"0"`, nilai negatif, notasi eksponen, dan lebih dari dua digit pecahan ditolak. Nilai dinormalisasi: `"0010.50"` menjadi `"10.5"`. Ini ambang master, bukan saldo stok B006.

PATCH obat/inventaris memerlukan minimal satu field yang dikenal. Field tidak dikirim mempertahankan nilai lama; `null` menghapus nilai hanya pada field nullable. PATCH jenis memerlukan `nama_jenis`. Referensi aktif hanya diperiksa jika field referensi dikirim. Menonaktifkan jenis/obat tidak menghapus inventaris yang sudah merujuknya; referensi tersebut tetap terbaca. PATCH teks pada record nonaktif diizinkan, tetapi tidak mengaktifkan kembali record.

Deactivate tidak memerlukan body. Identitas operasi deactivate ditentukan path; jangan mengirim field perubahan melalui endpoint ini.

## Daftar

Query opsional: `page` default `1` (integer positif, maksimum 6 digit), `limit` default `20` (1–100), `status_aktif=0|1`. Tanpa filter status, daftar mencakup aktif dan nonaktif. Urutan naik berdasarkan ID domain. Halaman tanpa record menghasilkan array kosong.

```json
{
  "data": [],
  "meta": { "page": 1, "limit": 20, "total": 0, "total_pages": 0 }
}
```

## Schema response resource

Detail mengembalikan `{ "data": <resource> }`; daftar mengembalikan array resource dan `meta`. Semua resource menyertakan `public_id` UUID, `version` string, serta `status_aktif` angka `0|1`.

| Resource | Field tambahan dalam `data` |
| --- | --- |
| Jenis | `id_jenis_inventaris`, `nama_jenis` |
| Obat | `id_obat`, `nama_obat`, `jenis_obat`, `dosis`, `aturan_penggunaan`, `deskripsi` |
| Inventaris | `id_inventaris`, `id_jenis_inventaris`, `id_obat`, `nama_barang`, `satuan`, `stok_minimum`, `nama_jenis`, `nama_obat` |

Field nullable pada request juga nullable pada response. `nama_obat` inventaris bernilai `null` bila tidak terhubung dengan obat. Semua ID domain/referensi dan desimal tetap string.

## Idempotensi dan sinkronisasi

Write menerima header opsional `Idempotency-Key: <UUID>`. Simpan dan gunakan key sama ketika mengulang operasi setelah koneksi terputus. Bila tidak diberikan, server membuat key baru sehingga request ulang tidak otomatis deduplikasi. Key diisolasi per actor dan mengikat tipe operasi, payload tervalidasi, serta ID target untuk PATCH/deactivate.

Create juga menerima header opsional `X-Client-Id: <UUID>`, dipetakan ke `public_id` stabil untuk resource tersebut. Gunakan UUID yang telah direservasi melalui B004 bila ada. UUID klien berbeda dari ID integer domain. Create dengan key baru tetapi UUID klien yang sudah terikat pada record menghasilkan `409 RESOURCE_ALREADY_EXISTS`; tidak membuat duplikat.

Replay key dan payload sama mengembalikan `data` dan `operation` asli dengan `replayed: true`, walaupun resource telah berubah sejak operasi pertama. Key sama dengan tipe/payload berbeda menghasilkan `409 OPERATION_CONFLICT`. Kegagalan bisnis tidak menyimpan receipt sukses. Mutasi domain, mapping identitas, versi, dan receipt commit dalam transaksi yang sama; actor dan izin diperiksa ulang di transaksi tersebut.

`operation.revision` adalah cursor receipt global, bukan versi resource. `operation.version` dan `data.version` sama untuk mutasi tersebut. Versi berubah hanya ketika mutasi baru berhasil, bukan saat replay atau reservasi ID. Update/deactivate yang diterima dengan key baru merupakan mutasi baru, termasuk ketika nilai yang dikirim sama dengan nilai tersimpan.

Contoh create:

```http
POST /api/v1/inventaris
Authorization: Bearer <access_token>
Content-Type: application/json
Idempotency-Key: 5f9c14e6-76bc-4f68-a3cf-8e4fd877d744
X-Client-Id: d95fe5e9-8ca7-4bc6-b0d7-3f1c70ab7c2e

{"id_jenis_inventaris":"1","nama_barang":"Pupuk cair","satuan":"liter","stok_minimum":"10.50"}
```

```json
{
  "data": {
    "id_inventaris": "1",
    "id_jenis_inventaris": "1",
    "id_obat": null,
    "nama_barang": "Pupuk cair",
    "satuan": "liter",
    "stok_minimum": "10.5",
    "status_aktif": 1,
    "nama_jenis": "Pupuk",
    "nama_obat": null,
    "public_id": "cc06496f-22ba-4ad9-b795-147bff7871f3",
    "version": "1"
  },
  "operation": {
    "operation_key": "5f9c14e6-76bc-4f68-a3cf-8e4fd877d744",
    "revision": "12",
    "public_id": "cc06496f-22ba-4ad9-b795-147bff7871f3",
    "version": "1"
  },
  "replayed": false
}
```

Contoh PATCH: `PATCH /api/v1/inventaris/1` dengan `{"stok_minimum":null}` menghapus ambang minimum tanpa mengubah nama, satuan, atau referensi. Response memakai envelope write yang sama seperti create dengan versi mutasi terbaru.

## Error per endpoint

Semua error memakai envelope:

```json
{"error":{"code":"VALIDATION_ERROR","message":"Input tidak sesuai kontrak API.","request_id":"req-1"}}
```

| Endpoint/kondisi | HTTP | Code |
| --- | --- | --- |
| Semua: token tidak sah/kedaluwarsa | 401 | `UNAUTHENTICATED` |
| Write: actor tanpa izin inventaris tulis | 403 | `FORBIDDEN` |
| Semua: body/query/ID/header UUID tidak sesuai kontrak | 400 | `VALIDATION_ERROR` |
| Semua write: key sama, operasi/payload berbeda | 409 | `OPERATION_CONFLICT` |
| Semua create: UUID klien sudah terikat pada record | 409 | `RESOURCE_ALREADY_EXISTS` |
| Jenis create/PATCH: nama sudah digunakan | 409 | `JENIS_NAME_TAKEN` |
| Jenis detail/PATCH/deactivate: target tidak ada | 404 | `JENIS_NOT_FOUND` |
| Obat detail/PATCH/deactivate: target tidak ada | 404 | `OBAT_NOT_FOUND` |
| Inventaris detail/PATCH/deactivate: target tidak ada | 404 | `INVENTARIS_NOT_FOUND` |
| Inventaris create/PATCH: referensi jenis tidak ada/nonaktif | 422 | `JENIS_NOT_FOUND` |
| Inventaris create/PATCH: referensi obat tidak ada/nonaktif | 422 | `OBAT_NOT_FOUND` |
| Semua: body melebihi batas server | 413 | `PAYLOAD_TOO_LARGE` |
| Semua: media type tidak didukung | 415 | `UNSUPPORTED_MEDIA_TYPE` |
| Semua: gangguan internal | 500 | `INTERNAL_ERROR` |

Daftar dan detail tidak mengubah versi maupun membuat receipt. Limit request mengikuti konfigurasi B001; respons rate limit menggunakan kontrak server B001.
