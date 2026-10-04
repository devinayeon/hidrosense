# Kontrak API Penyemaian B007

Tanggal: 4 Oktober 2026, Asia/Jakarta. Kontrak berlaku sesudah migrasi `0007_nursery`.
Penyemaian mengelola pencatatan benih, perhitungan usia bibit, kesiapan pindah (usia ≥ 15 hari), dan konsumsi atomik stok bahan melalui ledger B006 (`stok.id_penyemaian`).

Semua endpoint memakai Bearer access token.
- `petani`: `penyemaian:read`
- `pegawai`: `penyemaian:read`, `penyemaian:write`, `inventaris:write`

Write dan replay memeriksa sesi/izin terkini di dalam transaksi. Envelope error mengikuti [kontrak HTTP bersama](backend-api.md).

---

## Endpoint

| Method | Path | Izin | Respons | Keterangan |
| --- | --- | --- | --- | --- |
| POST | `/api/v1/penyemaian` | `penyemaian:write` | 201 baru; 200 replay; `Location: /api/v1/penyemaian/:id` | Buat semai + konsumsi bahan benih atomik |
| GET | `/api/v1/penyemaian` | `penyemaian:read` | 200 `{data: Sowing[], meta}` | List semai (filter status / siap pindah) |
| GET | `/api/v1/penyemaian/:id` | `penyemaian:read` | 200 `{data: SowingDetail}`; 404 jika tidak ditemukan | Detail semai + usia + stok konsumsi |
| PATCH | `/api/v1/penyemaian/:id` | `penyemaian:write` | 200 `{data: Sowing, operation}` | Update terbatas (jumlah, status, keterangan) |

---

## POST `/api/v1/penyemaian` (Create Sowing)

### Headers
- `Authorization: Bearer <token>`
- `Idempotency-Key: <UUID>` (wajib)
- `X-Client-Id: <UUID>` (opsional)

### Request Body
```json
{
  "tanggal_semai": "2026-10-04",
  "jumlah_benih": 100,
  "keterangan": "Penyemaian batch 1",
  "materials": [
    {
      "id_inventaris": "1",
      "jumlah": "5",
      "satuan": "gram"
    }
  ]
}
```

- `tanggal_semai`: String tanggal kalender valid format `YYYY-MM-DD`.
- `jumlah_benih`: Integer positif `1..1000000`.
- `keterangan`: String trim opsional/null maks 1000 karakter.
- `materials`: Array `1..50` item konsumsi inventaris. Setiap `id_inventaris` harus unik. Satuan harus sesuai master inventaris. Saldo inventaris harus mencukupi dan barang berstatus aktif (`status_aktif = 1`). Konsumsi benih direkam ke tabel `stok` dengan `jenis_stok: keluar`, `id_penyemaian`, dan `sealed = 1` dalam satu transaksi atomik.

### Response `201 Created`
```json
{
  "data": {
    "id_penyemaian": "1",
    "public_id": "893c5d7a-1234-4567-89ab-cdef01234567",
    "version": "1",
    "id_user": "2",
    "tanggal_semai": "2026-10-04",
    "jumlah_benih": 100,
    "status_penyemaian": "aktif",
    "keterangan": "Penyemaian batch 1",
    "usia_hari": 0,
    "siap_pindah": false
  },
  "operation": {
    "operation_key": "...",
    "revision": "...",
    "public_id": "...",
    "version": "1"
  },
  "replayed": false
}
```

---

## GET `/api/v1/penyemaian` (List Sowings)

### Query Parameters
- `page`: integer positif (default `1`)
- `limit`: integer `1..100` (default `20`)
- `status_penyemaian`: enum `'aktif'` | `'selesai'` (opsional)
- `siap_pindah`: `'1'` (opsional, hanya menampilkan bibit dengan `usia_hari >= 15`)

Urutan default: `tanggal_semai DESC, id_penyemaian DESC`.

### Response `200 OK`
```json
{
  "data": [
    {
      "id_penyemaian": "1",
      "public_id": "...",
      "version": "1",
      "id_user": "2",
      "tanggal_semai": "2026-09-19",
      "jumlah_benih": 100,
      "status_penyemaian": "aktif",
      "keterangan": null,
      "usia_hari": 15,
      "siap_pindah": true
    }
  ],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 1,
    "total_pages": 1
  }
}
```

---

## GET `/api/v1/penyemaian/:id` (Detail Sowing)

Mengembalikan data semai lengkap termasuk riwayat bahan konsumsi stok (`stok_konsumsi`).

### Response `200 OK`
```json
{
  "data": {
    "id_penyemaian": "1",
    "public_id": "...",
    "version": "1",
    "id_user": "2",
    "tanggal_semai": "2026-09-19",
    "jumlah_benih": 100,
    "status_penyemaian": "aktif",
    "keterangan": null,
    "usia_hari": 15,
    "siap_pindah": true,
    "stok_konsumsi": [
      {
        "id_stok": "10",
        "id_detail_stok": "15",
        "id_inventaris": "1",
        "jumlah": "5",
        "satuan": "gram"
      }
    ]
  }
}
```

---

## PATCH `/api/v1/penyemaian/:id` (Update Sowing)

Mendukung pembaruan parsial terhadap:
- `jumlah_benih`: integer positif (tidak boleh lebih kecil dari jumlah tanaman yang telah dipindahkan di tabel `pemindahan`).
- `status_penyemaian`: enum `'aktif'` | `'selesai'`.
- `keterangan`: string trim opsional/null maks 1000 karakter.

Pembaruan yang berhasil menaikkan `version` (misal dari `'1'` ke `'2'`).

### Request Body
```json
{
  "status_penyemaian": "selesai",
  "keterangan": "Semua bibit berhasil dipindahkan ke meja tanam."
}
```

---

## Error Bisnis

| Status | Code | Makna |
| --- | --- | --- |
| 400 | `VALIDATION_ERROR` | Format body, tanggal, atau query tidak valid |
| 401 | `UNAUTHENTICATED` | Token sesi absen atau tidak valid |
| 403 | `FORBIDDEN` | Pengguna tidak memiliki permission yang dibutuhkan |
| 404 | `PENYEMAIAN_NOT_FOUND` | Record semai tidak ditemukan |
| 409 | `SOWING_UNDERCAPACITY` | `jumlah_benih` baru lebih kecil dari jumlah yang sudah dipindahkan |
| 409 | `OPERATION_CONFLICT` | `Idempotency-Key` sama dikirim dengan payload berbeda |
| 409 | `INSUFFICIENT_STOCK` | Saldo bahan/benih di inventaris tidak mencukupi untuk konsumsi |
| 422 | `INVENTARIS_NOT_AVAILABLE` | Bahan benih tidak ditemukan atau tidak aktif (`status_aktif = 0`) |
| 422 | `UNIT_MISMATCH` | Satuan yang dimasukkan berbeda dengan satuan master inventaris |

## Klarifikasi review waktu

`usia_hari` dan `siap_pindah` dihitung dari tanggal bisnis Asia/Jakarta berdasarkan clock aplikasi pada saat request. Filter `siap_pindah=1` memakai tanggal yang sama, sehingga batas 15 hari berlaku mulai pukul 00:00 Asia/Jakarta. PATCH parsial mempertahankan `keterangan` bila field tidak hadir; `keterangan: null` menghapusnya.
