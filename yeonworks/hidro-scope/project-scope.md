Tujuan:

1. Sistem mempermudah pencatatan dan pengelolaan inventaris budidaya, seperti benih, media tanam, pupuk, dan obat. Sistem juga mencatat pengurangan stok secara otomatis ketika bahan digunakan.
2. Sistem mempermudah pengelolaan siklus budidaya selada, mulai dari penyemaian, pemindahan tanaman ke meja tanam, pemantauan pertumbuhan, hingga panen.
3. Sistem membantu petani mengoptimalkan pemanfaatan kapasitas meja tanam berdasarkan ketersediaan lubang tanam dan usia tanaman.
4. Sistem memberikan hasil deteksi hama secara cepat berdasarkan gambar tanaman yang diunggah. Sistem juga memberikan rekomendasi penanganan dan rotasi obat yang sesuai.
5. Sistem memberikan rekomendasi tindakan perawatan tanaman berdasarkan kondisi dan prakiraan cuaca dari API BMKG.
6. Sistem mendukung peningkatan produktivitas budidaya dengan mengurangi kerugian akibat keterlambatan penanganan hama dan kondisi cuaca yang tidak terpantau.





Project Scope:

1. Sistem beroperasi sebagai aplikasi mobile.
2. Aktor membutuhkan koneksi internet hanya untuk melakukan sinkronisasi data dan mengakses API BMKG.
3. Sistem berfokus pada budidaya selada dengan metode hidroponik NFT.
4. Sistem memiliki tiga jenis aktor, yaitu petani, pegawai, dan API BMKG sebagai aktor eksternal.
5. Pengguna harus melakukan login untuk mengakses fitur utama sistem.
6. Petani dan pegawai melakukan login menggunakan username dan password.
7. Sistem pada tahap awal mendeteksi tiga jenis hama, yaitu thrips, whitefly (kutu kebul), dan aphids (kutu daun). Jenis hama tersebut dapat dikembangkan lebih lanjut sesuai dengan kebutuhan mitra.
8. Petani memperbarui status fisik meja tanam secara manual karena sistem tidak melakukan deteksi otomatis terhadap kondisi fisik meja.



Special Issues:

1. Kualitas dataset AI memengaruhi hasil deteksi hama.
2. Kualitas foto tanaman dapat memengaruhi hasil deteksi.
3. Riwayat penggunaan obat memengaruhi hasil rekomendasi rotasi obat dapat diberikan dengan tepat.
4. Rekomendasi AI bersifat sebagai pendukung keputusan petani, bukan pengganti keputusan dalam penanganan tanaman.



Constraints :

1. Sistem dikembangkan dalam bentuk mobile application.
2. Sistem membutuhkan koneksi internet untuk sinkronisasi data dan integrasi API BMKG.
3. Sistem difokuskan pada budidaya selada hidroponik NFT.
4. Status meja tanam diperbarui secara manual oleh petani, sehingga sistem tidak mendeteksi kondisi fisik meja secara otomatis.
5. Data cuaca bergantung pada ketersediaan API BMKG.



Additional:

1. Satu siklus membutuhkan 15 hari penyemaian + 45 hari pertumbuhan = 60 hari sampai panen.



Tangible:

1. Mempermudah pengelolaan inventaris budidaya karena data stok benih dan kebutuhan budidaya dapat dicatat dan dipantau secara terpusat.
2. Mempermudah pengelolaan siklus budidaya selada karena proses penyemaian, pertumbuhan, tanaman rusak, hingga panen dapat dicatat dan dipantau secara terstruktur.
3. Meningkatkan keteraturan penggunaan meja tanam karena ketersediaan lubang dan usia tanaman pada setiap meja dapat dipantau sehingga penempatan bibit menjadi lebih teratur.
4. Membantu pengambilan keputusan dalam penanganan hama melalui hasil deteksi dan rekomendasi AI berdasarkan kondisi tanaman serta riwayat penggunaan obat.
5. Membantu petani dalam menentukan tindakan perawatan berdasarkan kondisi cuaca melalui informasi cuaca BMKG dan rekomendasi AI.



A. Petani



Fitur Akun

* Menambahkan data akun pegawai
* Melihat data akun pegawai
* Mengubah data akun pegawai
* Menonaktifkan data akun pegawai



Fitur Manajemen Pencatatan Inventaris

* Menambahkan data inventaris
* Melihat data inventaris
* Mengubah data inventaris
* Mengarsip data inventaris yang tidak tersedia



Fitur Manajemen Penyemaian Bibit

* Menambahkan data penyemaian bibit
* Melihat data penyemaian bibit
* Mengubah data penyemaian
* Melihat notifikasi penyemaian ketika mencapai 15 hari.



Fitur Meja Tanam dan Manajemen Pertumbuhan

* Menambahkan data meja tanam.
* Melihat data meja tanam.
* Mengubah data meja tanam.
* Menambahkan data pertumbuhan.
* Melihat data pertumbuhan.
* Mengubah data pertumbuhan.
* Melihat umur tanaman berdasarkan HSS.
* Menambahkan data tanaman yang rusak.
* Melihat data tanaman yang rusak.
* Mengubah data tanaman yang rusak.



Fitur Manajemen Pencatatan Panen

* Melihat estimasi waktu panen.
* Menambahkan data panen.
* Melihat data panen.
* Mengubah data panen.



Fitur Pencatatan Penjualan

* Menambahkan data penjualan.
* Melihat data penjualan.
* Mengubah data penjualan.



Fitur Perawatan

* Mengunggah data gambar untuk deteksi.
* Melihat hasil deteksi hama.
* Melihat hasil rekomendasi obat.
* Melakukan konfirmasi data perawatan.
* Melihat data perawatan.



Fitur Rekomendasi Perawatan Berdasarkan Cuaca

Melihat rekomendasi perawatan berdasarkan kondisi cuaca.



B. Pegawai



Fitur Manajemen Pencatatan Inventaris

* Menambahkan data inventaris
* Melihat data inventaris
* Mengubah data inventaris
* Menonaktifkan data inventaris yang tidak tersedia



Fitur Manajemen Penyemaian Bibit

* Menambahkan data penyemaian bibit
* Melihat data penyemaian bibit
* Mengubah data penyemaian
* Melihat notifikasi penyemaian mencapai 15 hari.



Fitur Manajemen Pertumbuhan dan Meja Tanam

* Menambahkan data meja tanam.
* Melihat data meja tanam.
* Mengubah data meja tanam.
* Mengubah status meja tanam.
* Menambahkan data pertumbuhan.
* Melihat data pertumbuhan.
* Mengubah data pertumbuhan.
* Melihat umur tanaman berdasarkan HSS.
* Menambahkan data tanaman yang rusak.
* Melihat data tanaman yang rusak.
* Mengubah data tanaman yang rusak.



Fitur Manajemen Pencatatan Panen

* Melihat estimasi waktu panen.
* Menambahkan data panen.
* Melihat data panen.
* Mengubah data panen.



API BMKG

* Penyediaan Data Cuaca
* Menyediakan data kondisi cuaca.
* Menyediakan data prakiraan cuaca.



