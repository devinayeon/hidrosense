# Kontrak API B009: Pemindahan Bibit ke Meja Tanam (Transfers)

Prefix rute: `/api/v1/pemindahan`

## 1. POST /api/v1/pemindahan
Mencatat pemindahan bibit semai ke meja tanam NFT.

- **Izin**: `budidaya:write` (Pegawai)
- **Header**:
  - `Authorization: Bearer <access_token>`
  - `Idempotency-Key: <UUID>` (Opsional; server membuat kunci jika tidak dikirim. Wajib dikirim klien untuk replay aman setelah respons hilang.)
  - `X-Client-Id: <UUID>` (Opsional untuk reservasi offline public UUID)
- **Body**:
```json
{
  "id_penyemaian": "1",
  "id_meja": "2",
  "tanggal_pemindahan": "2026-09-16",
  "jumlah_tanaman": 150,
  "keterangan": "Batch A pindah meja M-02"
}
```
- **Respons Sukses (201 Created)**:
```json
{
  "data": {
    "id_pemindahan": "1",
    "public_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
    "version": "1",
    "id_penyemaian": "1",
    "id_meja": "2",
    "kode_meja": "M-02",
    "tanggal_semai": "2026-09-01",
    "tanggal_pemindahan": "2026-09-16",
    "jumlah_tanaman": 150,
    "keterangan": "Batch A pindah meja M-02",
    "umur_semai_hari": 15,
    "estimasi_panen": "2026-10-16",
    "hss": 15,
    "hst": 0,
    "sisa_hari_panen": 30,
    "tanaman_aktif": 150
  }
}
```
- **Error**:
  - `400 VALIDATION_ERROR`: Field tidak lengkap, format tanggal salah, atau umur semai < 15 hari.
  - `401 UNAUTHENTICATED`: Token tidak sah atau kedaluwarsa.
  - `403 FORBIDDEN`: Akun tidak memiliki hak `budidaya:write`.
  - `404 PENYEMAIAN_NOT_FOUND`: Data penyemaian tidak ditemukan.
  - `404 TABLE_NOT_FOUND`: Meja tanam tidak ditemukan.
  - `409 SEEDLING_INSUFFICIENT`: Bibit semai yang tersedia tidak mencukupi jumlah pemindahan.
  - `409 TABLE_CAPACITY_EXCEEDED`: Kapasitas lubang meja tanam tidak mencukupi.
  - `409 TABLE_NOT_AVAILABLE`: Status meja tanam tidak tersedia (misal: 'rusak'/'perbaikan').
  - `409 OPERATION_CONFLICT`: Idempotency key sama dengan payload berbeda.

## 2. GET /api/v1/pemindahan
Mengambil daftar riwayat pemindahan / batch tanaman di meja.

- **Izin**: `budidaya:read` (Petani & Pegawai)
- **Query Parameter**:
  - `page`: nomor halaman (default: 1)
  - `limit`: batas per halaman (default: 20, max: 100)
  - `id_meja`: filter berdasarkan id meja tertentu
  - `id_penyemaian`: filter berdasarkan id penyemaian tertentu
- **Respons Sukses (200 OK)**:
```json
{
  "data": [ ... ],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 1,
    "total_pages": 1
  }
}
```

## 3. GET /api/v1/pemindahan/:id
Mengambil detail satu batch pemindahan.

- **Izin**: `budidaya:read` (Petani & Pegawai)
- **Respons Sukses (200 OK)**: Objek data detail transfer.

## 4. PATCH /api/v1/pemindahan/:id
Memperbarui keterangan batch pemindahan.

- **Izin**: `budidaya:write` (Pegawai)
- **Body**:
```json
{
  "keterangan": "Keterangan pembaruan"
}
```
- **Respons Sukses (200 OK)**: Objek data transfer terbaru dengan versi dinaikkan (`version: "2"`).
