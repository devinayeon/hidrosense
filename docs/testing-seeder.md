# Panduan Database Seeder & Kredensial Pengujian (B000–B009)

Dokumen ini memuat panduan lengkap penggunaan database seeder dan kredensial akun uji untuk pengujian autentikasi serta integrasi aplikasi mobile Flutter **HidroSense**.

---

## 1. Ringkasan & Ruang Lingkup

Seeder otomatis ini (`npm run db:seed`) menyiapkan lingkungan pengujian lokal yang realistis dengan mencakup seluruh modul inti dari **B000 hingga B009**:
- **B000 & B001**: Struktur database relasional LibSQL/SQLite & HTTP standard JSON envelopes.
- **B002**: Autentikasi sesi token ganda (Access + Refresh token) dengan hashing aman `scrypt`.
- **B003 & B004**: Sinkronisasi data offline-first, pelacakan versi sumber daya, dan pemetaan ID publik UUIDv4.
- **B005**: Master data inventaris (Jenis Inventaris, Obat/Pestisida, Barang Inventaris).
- **B006**: Buku besar stok masuk (Stock Ledger) tersimpan permanen (*sealed*) dan saldo stok aktif.
- **B007**: Batch penyemaian bibit aktif dengan kalkulasi umur semai.
- **B008**: Data meja tanam hidroponik NFT dengan status ketersediaan lubang tanam.
- **B009**: Pemindahan bibit ke meja tanam (umur semai 15 hari) dan baseline estimasi panen 45 hari.

---

## 2. Akun Pengujian & Kredensial Baku

Sistem backend HidroSense memiliki 2 peran aktif (`petani` dan `pegawai`). Kredensial berikut telah distandarisasi untuk digunakan oleh tim mobile Flutter:

| Aktor | Role | Username | Password | Email | No. Telepon | Hak Akses Utama |
|---|---|---|---|---|---|---|
| **Petani** | `petani` | `petani` | `Petani123456!` | `petani@hidrosense.id` | `081234567890` | Pemilik kebun, manajemen akun pegawai, seluruh fitur operasional |
| **Pegawai** | `pegawai` | `pegawai` | `Pegawai123456!` | `pegawai@hidrosense.id` | `081298765432` | Staf operasional, input stok, semai bibit, pindah meja, catat rawat |

### Catatan Keamanan Password
- Password dienkripsi menggunakan algoritma `scrypt` dengan parameter aman Node.js crypto (`scrypt$32768$8$3$<salt>$<hash>`).
- Format password memenuhi aturan validasi B002: minimal 12 karakter, mengandung huruf besar, huruf kecil, angka, dan simbol.

---

## 3. Data Awal Domain (Fixtures B005–B009)

Setelah proses seeding dijalankan, aplikasi Flutter dapat langsung mengonsumsi data realistis berikut:

### A. Master Inventaris & Obat (B005)
1. **Jenis Inventaris**:
   - `id_jenis: 1` -> Benih
   - `id_jenis: 2` -> Nutrisi
   - `id_jenis: 3` -> Obat & Pestisida
   - `id_jenis: 4` -> Perlengkapan
2. **Obat & Pestisida**:
   - `id_obat: 1`: Abamectin 18 EC (Insektisida, 0.5 ml/L)
   - `id_obat: 2`: Imidakloprid 200 SL (Insektisida, 0.75 ml/L)
   - `id_obat: 3`: Mancozeb 80 WP (Fungisida, 1.5 g/L)
3. **Barang Inventaris**:
   - `id_inventaris: 1`: Benih Selada Romaine (`satuan: gram`, `stok_minimum: 100`)
   - `id_inventaris: 2`: Benih Selada Butterhead (`satuan: gram`, `stok_minimum: 100`)
   - `id_inventaris: 3`: Nutrisi AB Mix Sayuran Daun (`satuan: liter`, `stok_minimum: 20`)
   - `id_inventaris: 4`: Insektisida Abamectin (`satuan: botol`, `stok_minimum: 5`)
   - `id_inventaris: 5`: Rockwool Semai Standar (`satuan: lembar`, `stok_minimum: 10`)

### B. Stok Masuk Awal & Saldo (B006)
- **Header Stok Masuk**: `id_stok: 1` (`jenis_stok: masuk`, status: `sealed = 1`).
- **Saldo Stok Tersedia (`stok_saldo`)**:
  - Benih Romaine: 1.000 gram (`100.000 minor`)
  - Benih Butterhead: 800 gram (`80.000 minor`)
  - Nutrisi AB Mix: 100 liter (`10.000 minor`)
  - Insektisida Abamectin: 20 botol (`2.000 minor`)
  - Rockwool Semai: 50 lembar (`5.000 minor`)

### C. Penyemaian Bibit (B007)
- **Batch 1**: `id_penyemaian: 1`, Benih Romaine, disemai 20 hari yang lalu (siap pindah tanam $\ge 15$ hari), jumlah: 600 benih, status: `aktif`.
- **Batch 2**: `id_penyemaian: 2`, Benih Butterhead, disemai 5 hari yang lalu (masih fase semai muda), jumlah: 400 benih, status: `aktif`.

### D. Meja Tanam NFT (B008)
- `M-01`: Kapasitas 250 lubang, status: `tersedia` (terisi 200 tanaman dari Batch 1).
- `M-02`: Kapasitas 250 lubang, status: `tersedia`.
- `M-03`: Kapasitas 250 lubang, status: `tersedia`.
- `M-04`: Kapasitas 200 lubang, status: `perbaikan`.

### E. Pemindahan Bibit (B009)
- `id_pemindahan: 1`: Dipindahkan dari Penyemaian Batch 1 ke Meja `M-01`.
- Tanggal pindah: 5 hari lalu (tepat pada hari ke-15 semai).
- Jumlah tanaman: 200 bibit.
- Standar panen: Baseline 45 hari dari tanggal semai.

---

## 4. Cara Menjalankan Seeder

### Prasyarat
Pastikan dependensi backend telah terpasang dan migrasi database sudah dieksekusi:
```bash
cd apps/backend
npm run db:migrate
```

### Eksekusi Seeder
Jalankan perintah berikut:
```bash
npm run db:seed
```

### Karakteristik Idempotensi & Keamanan
- **Idempotent**: Perintah dapat dijalankan berulang kali tanpa error duplikasi (*conflict handling* `ON CONFLICT` otomatis memperbarui akun dan entitas).
- **Production Guard**: Menolak eksekusi pada environment `NODE_ENV=production` kecuali flag eksplisit `ALLOW_PROD_SEED=1` disertakan.

---

## 5. Panduan Pengujian Integrasi di Flutter

### Alur Autentikasi (B002)

1. **Login Request**:
   - **Method**: `POST`
   - **URL**: `http://<BACKEND_HOST>:3000/api/v1/auth/login`
   - **Headers**: `Content-Type: application/json`
   - **Body JSON**:
     ```json
     {
       "username": "petani",
       "password": "Petani123456!"
     }
     ```
   - **Response Berhasil (200 OK)**:
     ```json
     {
       "data": {
         "token_type": "Bearer",
         "access_token": "<jwt_access_token>",
         "expires_in": 900,
         "refresh_token": "<jwt_refresh_token>",
         "refresh_expires_in": 2592000,
         "user": {
           "id_user": 1,
           "nama": "Budi Petani Hidroponik",
           "username": "petani",
           "role": "petani",
           "email": "petani@hidrosense.id"
         }
       }
     }
     ```

2. **Akses Endpoint Berproteksi**:
   - Sertakan header `Authorization: Bearer <access_token>` pada setiap permintaan ke endpoint modul B003–B009 (misal: `/api/v1/penyemaian`, `/api/v1/meja-tanam`, `/api/v1/pemindahan`).

3. **Pengujian Pergantian Peran (Role Switch)**:
   - Login sebagai `pegawai` (`pegawai` / `Pegawai123456!`) untuk menguji pembatasan hak akses yang hanya dapat diakses oleh peran tertentu.
