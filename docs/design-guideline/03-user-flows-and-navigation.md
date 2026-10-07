# Modul 03: Arsitektur Navigasi & Diagram Alur Pengguna (User Flows & Navigation)

Dokumen ini memetakan arsitektur navigasi antarmuka dan alur pengguna (*User Flows*) untuk seluruh fitur inti aplikasi **HidroSense Mobile** (B000 hingga B009) mengacu pada standar **Apple Human Interface Guidelines (HIG)**.

---

## 1. Arsitektur Informasi & Hirarki Navigasi

Sistem navigasi HidroSense dibagi menjadi 3 pola utama sesuai standar Apple HIG:

```
[Level 0: Root Gate] ---> Belum Login: [Login Page]
                     ---> Sudah Login: [Main Page / Tab Bar]
                                       |-- Tab 1: [Beranda / Dashboard]
                                       |-- Tab 2: [Inventaris & Stok]
                                       |-- Tab 3: [Semaian / Nursery]
```

### 3 Pola Navigasi HIG:
1. **Persistent Tab Bar (Layar Utama):**
   - Menampung 3 tujuan utama: *Beranda*, *Inventaris*, dan *Semaian*.
   - Tab Bar tetap terlihat di layar root dan memberikan orientasi instan kepada pengguna di mana mereka berada.
2. **Hierarchical Push Navigation (Layar Detail):**
   - Menggunakan `Navigator.push()` dengan tombol kembali (*Back Button*) di kiri atas yang jelas.
   - Contoh: Ketuk Meja NFT `M-01` di dashboard $\rightarrow$ Masuk ke `DetailTanamanMejaPage`.
3. **Modal Presentation / Bottom Sheets (Layar Form & Input Cepat):**
   - Menggunakan bottom sheet atau full-screen modal dengan tombol "Batal" di kiri dan "Simpan" di kanan.
   - Contoh: Form Tambah Barang, Form Catat Semai, Form Pindah Bibit.

---

## 2. Alur Pengguna Inti (Core User Flows)

### Flow 1: Autentikasi & Pembagian Peran (B002)

Pengguna masuk menggunakan kredensial baku dan aplikasi menyesuaikan hak akses berdasarkan peran (`petani` vs `pegawai`).

```mermaid
graph TD
    A[Buka Aplikasi] --> B{Sesi Aktif Tersimpan?}
    B -->|Ya| C[Ambil Sesi Memori / Offline Cache]
    B -->|Tidak| D[Tampilkan Layar Login]
    D --> E[Input Username & Password]
    E --> F[Tekan Tombol 'Masuk']
    F --> G{Validasi Kredensial di API}
    G -->|Gagal / 401| H[Tampilkan Inline Error: Username/Password Salah]
    G -->|Offline / Timeout| I[Tampilkan Banner: Periksa Koneksi & Tombol Coba Lagi]
    G -->|Sukses / 200| J[Simpan Token & User Identity]
    J --> K{Cek Peran Pengguna}
    K -->|Petani / Owner| L[Dashboard Mode Petani: Full Akses & Ringkasan Laporan]
    K -->|Pegawai / Staf| M[Dashboard Mode Pegawai: Fokus Tindakan Operasional Kebun]
```

---

### Flow 2: Manajemen Inventaris & Buku Besar Stok (B005 & B006)

Pengguna memeriksa ketersediaan benih/nutrisi dan mencatat penambahan stok baru ke dalam buku besar stok yang tersimpan aman (*sealed*).

```mermaid
graph TD
    A[Pilih Tab 'Inventaris'] --> B[Tampilkan Daftar Kategori: Benih, Nutrisi, Obat, Perlengkapan]
    B --> C[Lihat Kartu Barang & Saldo Stok Terkini]
    C --> D{Apakah Stok < Stok Minimum?}
    D -->|Ya| E[Tampilkan Badge Oranye 'Stok Menipis']
    D -->|Tidak| F[Tampilkan Badge Hijau 'Stok Cukup']
    C --> G[Ketuk Tombol '+ Barang' atau 'Input Stok Masuk']
    G --> H[Buka Modal Form Stok]
    H --> I[Pilih Barang & Masukkan Kuantitas Angka]
    I --> J[Tinjau Keterangan Sumber Barang]
    J --> K[Tekan 'Simpan Transaksi Stok']
    K --> L[Kunci Header Transaksi Sealed = 1]
    L --> M[Update Saldo Otomatis di Layar & Tampilkan Haptic Sukses]
```

---

### Flow 3: Siklus Penyemaian Benih (B007)

Staf kebun mencatat semaian baru, memantau usia semai harian (HSS), dan menerima alert visual saat semaian siap pindah tanam.

```mermaid
graph TD
    A[Pilih Tab 'Semaian'] --> B[Tampilkan Batch Aktif]
    B --> C[Hitung Usia Semai Otomatis: Hari Setelah Semai / HSS]
    C --> D{Usia Semai >= 15 Hari?}
    D -->|Ya| E[Status: 'Siap Pindah Tanam' - Badge Oranye Terang]
    D -->|Tidak| F[Status: 'Fase Semai Aktif' - Usia < 15 Hari]
    E --> G[Munculkan Tombol Aksi Cepat: 'Pindah ke Meja']
    B --> H[Tekan '+ Semai' untuk Batch Baru]
    H --> I[Isi Form: Tanggal Semai, Jenis Benih, Jumlah Benih]
    I --> J[Validasi Jumlah Benih > 0]
    J --> K[Simpan Batch Semai Baru]
```

---

### Flow 4: Pemantauan Meja Tanam NFT (B008)

Pemantauan ketersediaan lubang tanam pada meja hidroponik sebelum bibit dipindahkan.

```mermaid
graph TD
    A[Buka Modul 'Meja NFT' dari Dashboard] --> B[Daftar Seluruh Meja Tanam: M-01, M-02, M-03, dst]
    B --> C[Tampilkan Indikator Meter Okupansi Lubang]
    C --> D{Status Meja?}
    D -->|Tersedia| E[Warna Hijau Mint: Kapasitas Tersedia untuk Bibit Baru]
    D -->|Penuh| F[Warna Biru: Semua Lubang Terisi Tanaman]
    D -->|Perbaikan| G[Warna Abu/Merah: Meja Dinonaktifkan Sementara]
    E --> H[Ketuk Kartu Meja]
    H --> I[Tampilkan Detail Tanaman, Tanggal Tanam, dan Riwayat Perawatan]
```

---

### Flow 5: Pemindahan Bibit ke Meja Tanam & Estimasi Panen (B009)

Alur kritis pemindahan bibit dari baki semai ke meja NFT dengan verifikasi standar umur 15 hari dan baseline panen 45 hari.

```mermaid
graph TD
    A[Pilih Batch Semai Siap Pindah / Tombol 'Pindah ke Meja'] --> B[Buka Form Pemindahan Bibit]
    B --> C{Verifikasi Umur Semai >= 15 Hari?}
    C -->|Tidak / Umur < 15 Hari| D[Blokir Input & Beri Alert: Bibit Belum Cukup Umur]
    C -->|Ya / Umur >= 15 Hari| E[Pilih Meja Tanam Tujuan yang Berstatus 'Tersedia']
    E --> F[Masukkan Jumlah Tanaman yang Dipindahkan]
    F --> G{Jumlah Bibit <= Sisa Lubang Meja Tersedia?}
    G -->|Tidak / Melebihi Kapasitas| H[Munculkan Peringatan Kapasitas Meja Tidak Cukup]
    G -->|Ya / Valid| I[Sistem Otomatis Menghitung Estimasi Tanggal Panen]
    I --> J[Kalkulasi: Tanggal Semai + Baseline 45 Hari Standar HidroSense]
    J --> K[Tampilkan Preview Ringkasan Pemindahan & Estimasi Panen]
    K --> L[Konfirmasi 'Simpan Pemindahan']
    L --> M[Kurangi Sisa Bibit Semai & Isi Okupansi Meja Tanam]
```

---

### Flow 6: Rekomendasi Cuaca BMKG & Tindakan Nutrisi

Sistem sinkronisasi prakiraan cuaca lokal untuk memandu tindakan staf lapangan.

```mermaid
graph TD
    A[Dashboard Mendeteksi Data Cuaca BMKG Terkini] --> B{Kondisi Cuaca?}
    B -->|Panas Terik / Suhu > 32°C| C[Rekomendasi: Tambah Debit Aliran & Pantau Suhu Air Nutrisi]
    B -->|Hujan Lebat / Lembap Tinggi| D[Rekomendasi: Waspada Jamur Daun, Sesuaikan PPM Nutrisi]
    C --> E[Tampilkan Card Rekomendasi Cuaca di Dashboard]
    D --> E
    E --> F[Staf Membuka Detail Rekomendasi Cuaca]
    F --> G[Catat Tindakan Penanganan Cuaca Lapangan]
```
