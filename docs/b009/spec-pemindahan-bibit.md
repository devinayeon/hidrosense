# Spesifikasi Teknis B009: Pemindahan Bibit ke Meja Tanam

> **Fitur**: B009 — Pemindahan Bibit ke Meja (*Seedling Transfer to Growing Table*)
> **Tanggal**: 7 Oktober 2026
> **Status**: Draf Disetujui (Baseline Standar Panen 45 Hari)
> **Modul Terkait**: B007 (Penyemaian), B008 (Meja Tanam), B004 (Sinkronisasi & Idempotensi)

---

## 1. Latar Belakang & Keputusan Bisnis

1. **Fungsi Utama**:
   - Mencatat pemindahan bibit semai yang telah berusia minimal 15 hari ke lubang tanam meja hidroponik NFT.
   - Menghitung secara otomatis Hari Setelah Semai (HSS), Hari Setelah Tanam (HST), estimasi tanggal panen, dan sisa hari menuju panen.
2. **Standar Durasi Panen (Keputusan Final)**:
   - Ketidakpastian durasi panen (45 vs 60 hari) telah **diputuskan secara eksplisit**: menggunakan **standar panen 45 hari** (45 Hari Setelah Semai / HSS).
   - Rincian siklus:
     - Tahap Semai (Nursery): 15 hari.
     - Tahap Pembesaran di Meja Tanam: 30 hari.
     - Total Siklus: 45 hari.
   - Rumus Estimasi Panen:
     $$\text{Estimasi Tanggal Panen} = \text{Tanggal Semai} + 45\text{ hari kalender}$$
     $$\text{Sisa Hari Panen} = \max(0, \text{Estimasi Tanggal Panen} - \text{Tanggal Hari Ini})$$

---

## 2. Aturan Invarian & Validasi

1. **Invarian Usia Bibit**:
   - Tanggal pemindahan harus $\ge \text{Tanggal Semai} + 15\text{ hari}$ ($\text{Umur Semai} \ge 15\text{ hari}$).
   - Tanggal pemindahan tidak boleh lebih awal dari tanggal semai.
2. **Invarian Ketersediaan Bibit Semai (B007)**:
   - Data penyemaian harus ada dan berstatus `aktif`.
   - Total bibit yang dipindahkan kumulatif ($\sum \text{jumlah\_tanaman}$) tidak boleh melebihi `jumlah_benih` pada penyemaian.
   - Jika $\text{jumlah\_tanaman} > \text{sisa\_bibit}$, sistem melempar error `409 SEEDLING_INSUFFICIENT`.
3. **Invarian Kapasitas Meja Tanam (B008)**:
   - Meja tanam tujuan harus ada dan tidak berstatus `rusak` atau `perbaikan`.
   - $\text{Tanaman Aktif di Meja} + \text{jumlah\_tanaman} \le \text{jumlah\_lubang}$.
   - Jika melebihi kapasitas lubang yang tersedia, sistem melempar error `409 TABLE_CAPACITY_EXCEEDED`.
4. **Invarian Transaksi & Konkurensi**:
   - Seluruh pemeriksaan kapasitas semai, kapasitas meja, penulisan tabel `pemindahan`, pembaruan versi, dan bukti mutasi sinkronisasi dieksekusi dalam satu transaksi atomik database (`Transaction`).

---

## 3. Skema Data & Kontrak API

### Endpoint HTTP
- `POST /api/v1/pemindahan` — Catat pemindahan bibit baru (memerlukan hak `budidaya:write`).
- `GET /api/v1/pemindahan` — Ambil daftar pemindahan/batch aktif (memerlukan hak `budidaya:read`).
- `GET /api/v1/pemindahan/:id` — Ambil detail satu batch pemindahan.
- `PATCH /api/v1/pemindahan/:id` — Perbarui catatan keterangan batch pemindahan.

### Skema Validasi Zod (Input Create)
```typescript
{
  id_penyemaian: integerIdSchema,
  id_meja: integerIdSchema,
  tanggal_pemindahan: dateSchema, // YYYY-MM-DD
  jumlah_tanaman: z.number().int().positive().max(1_000_000),
  keterangan: z.string().trim().max(1000).nullable().optional()
}
```

### Format Respons Data (DTO)
```json
{
  "data": {
    "id_pemindahan": "1",
    "public_id": "c1f729f2-0853-4e4b-9762-b91a7895e542",
    "version": "1",
    "id_penyemaian": "1",
    "id_meja": "1",
    "kode_meja": "M-01",
    "tanggal_semai": "2026-09-01",
    "tanggal_pemindahan": "2026-09-16",
    "jumlah_tanaman": 100,
    "keterangan": "Blok A Meja 1",
    "umur_semai_hari": 15,
    "estimasi_panen": "2026-10-16",
    "hss": 15,
    "hst": 0,
    "sisa_hari_panen": 30,
    "tanaman_aktif": 100
  }
}
```
