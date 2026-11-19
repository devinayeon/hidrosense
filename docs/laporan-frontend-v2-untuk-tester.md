# Laporan Front-end v2 untuk Tester

Tanggal: 19 November 2026
Cakupan: hasil perbaikan empat temuan dari pengujian langsung alur v2
akun `petani`, plus skenario uji ulang dan batas yang diketahui.

## Persiapan

1. Jalankan backend di host:

   ```bash
   cd apps/backend
   npm run dev
   ```

2. Untuk emulator/perangkat Android dengan backend di `127.0.0.1:3000`,
   pasang reverse port sebelum membuka aplikasi:

   ```bash
   adb reverse tcp:3000 tcp:3000
   ```

   Tanpa langkah ini aplikasi akan gagal menghubungi layanan dan menampilkan
   pesan koneksi, bukan data.

3. Jalankan aplikasi v2 dan masuk dengan akun seed:
   - Petani: `petani` / `Petani123456!`
   - Pegawai: `pegawai` / `Pegawai123456!`

4. Perintah pemeriksaan otomatis:

   ```bash
   cd apps/mobile
   flutter analyze
   flutter test
   ```

## Skenario uji ulang

### 1. Lainnya > Penjualan

**Langkah**

1. Masuk sebagai `petani`.
2. Buka tab **Lainnya** > **Penjualan**.
3. Tunggu hingga daftar tampil.
4. Ulangi saat perangkat dalam mode pesawat, lalu nyalakan jaringan dan tekan
   **Coba lagi**.

**Hasil yang diharapkan**

- Daftar penjualan tampil, atau keadaan kosong yang jelas bila belum ada
  penjualan.
- Tidak pernah berhenti di skeleton tanpa akhir.
- Saat offline/gagal, muncul **Gagal memuat** dengan tombol **Coba lagi**.
- Setelah jaringan kembali, **Coba lagi** memuat ulang daftar.

**Catatan**

- Pemicu pasti keluhan awal tidak berhasil direproduksi dengan data seed
  (endpoint penjualan dan panen balas 200). Perbaikan bersifat defensif:
  semua jenis galat sekarang menutup skeleton. Mohon dicoba lagi dengan data
  dan perangkat yang sama seperti laporan awal.

### 2. Beranda > Stok menipis

**Langkah**

1. Di Beranda, catat angka pada kartu **Stok menipis**.
2. Ketuk kartu tersebut.
3. Bandingkan daftar yang muncul dengan tab **Stok** > chip jenis **Benih** >
   chip keadaan **Menipis**.
4. Coba pindah tab lewat bottom nav, lalu kembali ke Beranda.

**Hasil yang diharapkan**

- Kartu membuka tab **Stok** dengan saringan **Benih + Menipis**.
- Bottom nav berfungsi; tidak perlu memakai tombol back perangkat untuk
  keluar.
- Daftar memakai data tersambung yang sama dengan tab Stok, bukan data contoh
  desain.
- Mengetuk tab **Stok** secara langsung menampilkan semua barang lagi
  (saringan Benih + Menipis direset).

**Batas yang diketahui**

- Angka kartu dihitung dari semua jenis barang yang menipis, sedangkan daftar
  tujuan disaring ke Benih. Pada data seed saat ini angkanya cocok. Bila ada
  nutrisi/perlengkapan yang juga menipis, angka kartu bisa lebih besar dari
  jumlah baris Benih + Menipis. Ini sedang menunggu keputusan produk; catat
  sebagai temuan terpisah bila terlihat.

### 3. Tanam > Tambah semaian > HSS

**Langkah**

1. Buka tab **Tanam** > **Tambah semaian**.
2. Pilih tanggal semai **12 November 2026**.
3. Simpan, lalu lihat HSS pada kartu semaian (hari ini 19 November 2026).

**Hasil yang diharapkan**

- HSS menunjukkan **7**, bukan 3.
- Semaian berumur 15 hari atau lebih berstatus **Siap pindah**.
- HSS di daftar dan detail konsisten.

**Catatan**

- HSS sekarang diambil dari `usia_hari` yang dihitung server (basis
  Asia/Jakarta). Perubahan jam perangkat tidak boleh mengubah HSS selama
  server mengirim `usia_hari`.
- Data contoh galeri tetap memakai tanggal acuan desain; itu bukan data
  pengguna.

### 4. Tanam > Meja > Tambah meja

**Langkah**

1. Buka tab **Tanam** > **Meja** > **Tambah meja**.
2. Isi kode `test`, jumlah lubang `1231`, keterangan `tset`, lalu **Simpan**.
3. Ulangi dengan jumlah lubang `1000`.
4. Ulangi dengan kode lebih dari 30 karakter.
5. Ulangi dengan keterangan lebih dari 1000 karakter.
6. Ulangi dengan kode yang sudah dipakai meja lain.

**Hasil yang diharapkan**

- Kasus `1231`: pesan **Maksimal 1.000 lubang** muncul tepat di bawah field
  jumlah lubang; data tidak dikirim ke server.
- Kasus `1000`: meja berhasil disimpan.
- Kode lebih dari 30 karakter: pesan **Maksimal 30 karakter** di bawah field
  kode.
- Keterangan lebih dari 1000 karakter: pesan **Maksimal 1.000 karakter** di
  bawah field keterangan.
- Kode duplikat: pesan **Kode meja sudah digunakan.** (dari server, sudah
  ramah pengguna).
- Tidak ada lagi pesan **Input tidak sesuai kontrak API.** untuk kasus ini.
- Bila ada galat validasi lain yang belum tercakup, pesan yang tampil adalah
  **Ada isian yang belum sesuai. Periksa kembali data yang Anda masukkan.**

## Regresi yang perlu dicek

- Tab **Stok** tanpa lewat kartu Beranda tetap menampilkan semua barang.
- Filter jenis/keadaan di tab Stok masih bisa diubah manual.
- Alur **Semaian** lain (ubah, selesai, pindah ke meja) tidak berubah.
- Alur **Meja** lain (ubah meja, tambah tanaman, status) tidak berubah.
- Galeri desain v2 (jika dipakai untuk review frame) tetap memakai data contoh.

## Tes otomatis yang ditambahkan

- `test/v2_penjualan_load_failure_test.dart` — galat tak terduga menutup
  skeleton dan menampilkan **Coba lagi**.
- `test/v2_beranda_low_stock_test.dart` — kartu Beranda membuka tab Stok
  tersaring Benih + Menipis.
- `test/v2_connected_mappers_test.dart` — HSS memakai `usia_hari` server.
- `test/v2_meja_form_test.dart` — batas 1000 lubang, 30 karakter kode, dan
  1000 karakter keterangan.
- `test/v2_error_message_test.dart` — terjemahan pesan validasi teknis.

## Hasil verifikasi

- `flutter analyze`: hanya 2 peringatan aset lama yang sudah ada sebelumnya.
- `flutter test`: **453 tes lulus** (sebelumnya 443).

## Saran langkah berikutnya untuk tester

1. Ulangi keempat skenario dengan perangkat dan data yang sama seperti laporan
   awal, termasuk mode pesawat dan jaringan lambat.
2. Uji batas angka: 1, 999, 1000, 1001 lubang; kode 1, 30, dan 31 karakter.
3. Uji dua peran: `petani` (penjualan, semaian, meja) dan `pegawai` (tanpa
   penjualan) untuk memastikan pesan izin tetap jelas.
4. Bila menemukan angka kartu "stok menipis" tidak sama dengan daftar,
   catat jenis barang yang menipis agar keputusan produk bisa diambil.