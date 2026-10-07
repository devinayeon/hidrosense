# Laporan Peninjauan Status Fitur HidroSense (B000 – B017+)

> **Tanggal Peninjauan**: 7 Oktober 2026  
> **Target Audiens**: Pemangku Kepentingan (*Stakeholders*), Tim Produk, dan Pembaca Non-Teknis  
> **Status Dokumen**: Laporan Evaluasi Berkala Progres Pengembangan

---

## 1. Ringkasan Eksekutif

Laporan ini menyajikan status pencapaian fitur sistem **HidroSense** dari alur **B000 sampai dengan B017 (dan keseluruhan tahap terencana)**. Penjelasan disusun menggunakan bahasa bisnis/operasional kebun yang mudah dipahami tanpa istilah teknis yang rumit.

- **Total Fitur Terencana**: 20 Tahap kerja (B000 s.d. B019).
- **Progres Saat Ini**: **10 Fitur Selesai Penuh (B000 – B009)** di sisi sistem server (*backend*) dan telah lulus 184 uji coba otomatis tanpa kesalahan.
- **Kondisi Aplikasi HP (Mobile)**: Fitur masuk (login), melihat daftar stok barang/obat di gudang, penyemaian, dan meja tanam sudah mulai tersambung ke server. Fitur lainnya sedang disiapkan secara bertahap.
- **Fokus Kerja Selanjutnya**: Memulai tahap **B010** (Pencatatan tanaman rusak/mati di meja tanam).

---

## 2. Tabel Evaluasi Status Fitur

| Kode | Nama Fitur | Fungsi Nyata bagi Pengguna | Status | Keterangan Evaluator |
| :--- | :--- | :--- | :---: | :--- |
| **B000** | **Fondasi Wadah Data** | Tempat penyimpanan utama seluruh data kebun selada (19 kelompok data domain). | 🟢 **Selesai** | Wadah data sudah terpasang rapi, aman, dan siap menampung data operasional. |
| **B001** | **Pintu Komunikasi Server** | Jalur komunikasi aman agar aplikasi di HP bisa berkirim pesan dengan komputer server. | 🟢 **Selesai** | Jalur komunikasi aktif, stabil, dan siap melayani permintaan dari HP. |
| **B002** | **Keamanan Akun & Hak Akses** | Mengatur proses login pengguna dan membedakan peran: **Petani (Pemilik)** vs **Pegawai (Staf Kebun)**. | 🟢 **Selesai** | Akun terkunci dengan standar enkripsi aman; akses menu dibatasi sesuai peran kerja. |
| **B003** | **Pengelolaan Pegawai & Profil** | Petani dapat menambah staf baru, menonaktifkan akun staf yang berhenti, serta mengubah biodata profil. | 🟢 **Selesai** | Hak akses berjalan tertib; pegawai tidak memiliki akses untuk mengubah perannya sendiri. |
| **B004** | **Pengaman Anti-Data Dobel** | Sistem pencegah catatan ganda ketika sinyal internet di kebun sering putus-nyambung. | 🟢 **Selesai** | Server otomatis mengenali data yang sama sehingga tidak akan ada catatan kembar/siluman. |
| **B005** | **Katalog Barang & Obat** | Buku daftar inventaris kebun: jenis benih selada, obat hama, nutrisi ab-mix, dan pupuk. | 🟢 **Selesai** | Data master barang dan jenis obat sudah terdaftar dan siap digunakan untuk transaksi. |
| **B006** | **Buku Stok Masuk & Keluar** | Menghitung sisa fisik barang di gudang otomatis setiap ada barang masuk/keluar serta mencegah stok minus. | 🟢 **Selesai** | Pencatatan stok presisi hingga satuan pecahan desimal (misal: 0.25 kg). |
| **B007** | **Pencatatan Semai Bibit** | Mencatat tanggal sebar benih dan menghitung usia bibit hingga mencapai usia siap pindah (15 hari). | 🟢 **Selesai** | Pengambilan benih semai otomatis memotong stok barang di gudang. |
| **B008** | **Pengaturan Meja Tanam NFT** | Mencatat 12 meja tanam hidroponik, total lubang tanam (kapasitas), dan status meja (tersedia/penuh). | 🟢 **Selesai** | Kapasitas meja terjaga agar tidak kelebihan beban tanaman di lapangan. |
| **B009** | **Pemindahan Bibit ke Meja** | Memindahkan bibit umur 15 hari ke lubang meja tanam dan menghitung estimasi tanggal panen (standar 45 hari). | 🟢 **Selesai** | Alur pemindahan tuntas, kapasitas meja & ketersediaan bibit tervalidasi atomik. |
| **B010** | **Catatan Tanaman Rusak** | Mencatat tanaman yang layu atau mati di meja tanam agar perkiraan hasil panen tetap akurat. | 🟡 **Antrean Berikutnya** | Mengantre segera setelah fitur pemindahan bibit selesai. |
| **B011** | **Penerimaan Foto Hama** | Server menerima foto kiriman kamera HP yang mendeteksi hama daun (thrips, kutu daun, dll). | ⚪ **Belum Dimulai** | Menunggu penyelarasan dengan model kecerdasan buatan (*AI*) di HP. |
| **B012** | **Saran Obat Pembasmi Hama** | Sistem otomatis menyarankan obat yang tepat dan merotasi jenis obat agar hama kebal obat tidak muncul. | ⚪ **Belum Dimulai** | Aturan pemilihan obat mengacu pada riwayat riil penyemprotan sebelumnya. |
| **B013** | **Persetujuan Petani atas Obat** | Petani dapat menyetujui atau menolak saran obat sebelum disemprotkan oleh staf kebun. | ⚪ **Belum Dimulai** | Memberikan kendali penuh keputusan pengeluaran obat kepada pemilik kebun. |
| **B014** | **Catatan Semprot Nyata** | Staf mencatat tindakan penyemprotan obat yang benar-benar dilakukan, otomatis memotong stok obat di gudang. | ⚪ **Belum Dimulai** | Mengantre setelah alur rekomendasi obat disepakati. |
| **B015** | **Pencatatan Hasil Panen** | Mencatat jumlah lubang yang dipanen beserta berat timbangan kotor/bersih (dalam kilogram). | ⚪ **Belum Dimulai** | Otomatis mengosongkan kapasitas meja tanam yang telah selesai dipanen. |
| **B016** | **Pencatatan Penjualan Selada** | Mencatat penjualan sayur ke pelanggan, harga jual per kg, dan total uang pendapatan kebun. | ⚪ **Belum Dimulai** | Khusus untuk Petani; Pegawai kebun dibatasi agar tidak bisa melihat data keuangan ini. |
| **B017** | **Penyelarasan Penuh Luar Jaringan** | Kemampuan HP dipakai seharian penuh di kebun tanpa internet, lalu semua data terkirim rapi saat online. | ⚪ **Belum Dimulai** | Menggabungkan seluruh alur transaksi dari semai hingga penjualan. |
| **B018** | **Uji Coba Lapangan Menyeluruh** | Simulasi pengujian satu siklus panen penuh dari awal sampai akhir untuk persiapan peluncuran. | ⚪ **Belum Dimulai** | Tahap akhir pemeriksaan mutu aplikasi sebelum dipakai resmi oleh mitra. |
| **B019** | **Prakiraan Cuaca BMKG** | Menampilkan informasi cuaca lokal dari BMKG serta tips antisipasi cuaca ekstrem. | ⏸️ **Ditangguhkan** | Dikerjakan paling akhir sesuai kesepakatan agar tidak menghambat fitur inti kebun. |

---

## 3. Catatan Penting & Rekomendasi Reviewer

1. **Kualitas Sistem Dasar Sangat Kuat**:
   - Seluruh fondasi dasar (B000 – B008) yang mencakup keamanan, akun, stok gudang, semai, dan meja tanam sudah beres dan teruji 100% di server.
2. **Kebutuhan Diskusi Sebelum B009**:
   - Sebelum melangkah ke **B009 (Pemindahan Bibit)**, tim produk dan mitra perkebunan disarankan menyepakati patokan perkiraan usia panen: apakah dihitung **45 hari setelah semai** atau **15 hari semai + 45 hari pembesaran di meja** (total 60 hari).
3. **Integritas Data Operasional**:
   - Aturan sistem dibuat ketat demi kenyamanan pengguna: stok tidak bisa minus tiba-tiba, catatan pemakaian barang tidak bisa terduplikasi, dan riwayat kerja pegawai tercatat jelas.
