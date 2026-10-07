# Spesifikasi Teknis Database Seeder HidroSense

> **Tanggal**: 7 Oktober 2026  
> **Tujuan**: Menyediakan data awal & akun uji kredensial baku untuk pengujian autentikasi dan integrasi Flutter Mobile pada seluruh modul B000–B009.

---

## 1. Akun Pengguna Uji & Hak Akses

Dua akun uji terstandarisasi dengan algoritma hashing `scrypt` (B002):

| Role | Username | Password Baku | Nama Lengkap | Email | Deskripsi & Hak Akses |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **petani** | `petani` | `Petani123456!` | Budi Petani Hidroponik | `petani@hidrosense.id` | Pemilik kebun (Super/Admin). Akses: Kelola Pegawai, Profil, Keuangan/Penjualan, Monitoring Baca Budidaya & Stok. |
| **pegawai** | `pegawai` | `Pegawai123456!` | Siti Pegawai Kebun | `pegawai@hidrosense.id` | Staf operasional kebun. Akses: Tulis & Baca Stok/Inventaris, Penyemaian, Meja Tanam, Pemindahan Bibit, Panen. Dilarang akses Penjualan. |

---

## 2. Rincian Data Awal Domain (B000 – B009)

1. **B005 — Master Inventaris & Obat**:
   - Jenis: `Benih`, `Nutrisi`, `Obat & Pestisida`, `Perlengkapan`.
   - Obat: `Abamectin 18 EC`, `Imidakloprid 200 SL`, `Fungisida Mancozeb 80 WP`.
   - Barang: `Benih Selada Romaine`, `Nutrisi AB Mix`, `Insektisida Abamectin`, `Rockwool Semai`.
2. **B006 — Buku Stok (Ledger Saldo)**:
   - Saldo masuk tersegel (`sealed = 1`) untuk semua barang master sehingga saldo tersedia nyata di gudang.
3. **B007 — Penyemaian**:
   - Batch Semai 1: Umur $\ge 15$ hari (status `aktif`, `siap_pindah: true`).
   - Batch Semai 2: Umur 5 hari (status `aktif`, `siap_pindah: false`).
4. **B008 — Meja Tanam**:
   - Meja `M-01` (250 lubang, aktif sebagian).
   - Meja `M-02` (250 lubang, kosong/tersedia).
   - Meja `M-03` (200 lubang, status `perbaikan`).
5. **B009 — Pemindahan Bibit**:
   - 1 Batch Pemindahan bibit dari Batch Semai 1 ke Meja `M-01` (200 tanaman).
   - Estimasi panen otomatis dihitung dengan standar baseline 45 hari.
6. **B004 — Sinkronisasi & UUID**:
   - Seluruh baris domain ditautkan ke `sync_resource_links` dan `sync_resource_versions`.

---

## 3. Keamanan & Idempotensi

- **Idempotensi**: Menggunakan pembersihan data uji terarah atau `ON CONFLICT` sehingga dapat dijalankan berulang kali tanpa `UNIQUE constraint failed`.
- **Perlindungan Lingkungan**: Mencegah overwrite di production kecuali terdapat environment variable konfirmasi (`ALLOW_PROD_SEED=1`).
- **Perintah CLI**: `npm run db:seed`.
