

|  TUGAS MATA KULIAH PENGEMBANGAN PERANGKAT LUNAK  ![logo unej.jpg][image1] HidroSense: Sistem Manajemen Budidaya Selada Hidroponik NFT dengan Deteksi Hama dan Rekomendasi Perawatan berdasarkan Cuaca Menggunakan YOLO berbasis Mobile Oleh : A \[ 9 \] ADITYA DWI FERDIANSYAH – 242410103030 SITI RAUDATUL JANNAH – 242410103048 FAKHRIAN IQBAL ZULKARNAIN – 242410103060 MOHAMMAD WILDAN ALQORI’IN – 2424101063 ACHMAD NUHAN T – 242410103011 PROGRAM STUDI INFORMATIKA FAKULTAS ILMU KOMPUTER UNIVERSITAS JEMBER 2026 |  |  |
| :---: | ----- | ----- |

**Daftar Isi**

**System Request**.......................................................................................................................................2

Note:  
Untuk gambar yg kecil atau buram/ tidak jelas tambahkan barcode atau link(bukan berupa chip link).

| System Request – HidroSense: Sistem Manajemen Budidaya Selada Hidroponik NFT dengan Deteksi Hama dan Rekomendasi Perawatan berdasarkan Cuaca Menggunakan YOLO berbasis Mobile |  |
| ----- | :---- |
| **Project Sponsor:** | Bapak Agus. Hidro Selada. Krajan, Sabrang, Kecamatan Ambulu, Kabupaten Jember, Jawa Timur, 68172\. |
| **Business Need:** | **Mempermudah pencatatan dan pengelolaan inventaris** Membantu petani mencatat pembelian dan ketersediaan benih, media tanam, pupuk, obat, serta kebutuhan budidaya lainnya. Penggunaan bahan untuk proses budidaya dapat mengurangi stok secara otomatis sehingga jumlah persediaan dapat dipantau dengan lebih teratur. **Mempermudah pengelolaan proses budidaya selada** Membantu petani mengelola proses mulai dari penyemaian selama ±15 hari, pemindahan bibit ke meja tanam, pemantauan pertumbuhan, pencatatan tanaman rusak/reject, hingga panen sekitar usia ±45 hari. **Membantu pengelolaan kapasitas meja tanam** Membantu petani menentukan penempatan bibit pada meja tanam berdasarkan ketersediaan lubang dan usia tanaman sehingga kapasitas 250 lubang pada setiap meja dapat dimanfaatkan secara lebih optimal. **Membantu deteksi dan penanganan hama** Membantu petani mengidentifikasi hama melalui gambar tanaman menggunakan AI serta memberikan rekomendasi penanganan dan rotasi obat berdasarkan riwayat penggunaan obat. **Membantu menentukan perawatan berdasarkan kondisi cuaca** Mengintegrasikan data cuaca dari API BMKG dan memanfaatkan AI untuk memberikan rekomendasi tindakan perawatan berdasarkan kondisi atau prakiraan cuaca yang berpotensi memengaruhi tanaman. |
| **Business Requirements:** |  |
| Petani Fitur Akun Menambahkan data akun pegawai Melihat data akun pegawai Mengubah data akun pegawai Menonaktifkan data akun pegawai Fitur Manajemen Pencatatan Inventaris Melihat data inventaris Fitur Manajemen Penyemaian Bibit Melihat data penyemaian bibit Melihat notifikasi penyemaian mencapai 15 hari. Fitur Manajemen Pertumbuhan dan Meja Tanam Melihat data meja tanam. Melihat data pertumbuhan. Melihat umur tanaman berdasarkan HSS. Melihat data tanaman yang rusak. Fitur Manajemen Pencatatan Panen Melihat estimasi waktu panen. Melihat data panen. Fitur Pencatatan Penjualan Menambahkan data penjualan. Melihat data penjualan. Mengubah data penjualan. Fitur Perawatan Menambahkan data gambar untuk deteksi. Melihat hasil deteksi hama. Melihat hasil rekomendasi obat. Melakukan konfirmasi data perawatan. Melihat data perawatan. Fitur Rekomendasi Perawatan Berdasarkan Cuaca Melihat rekomendasi perawatan berdasarkan kondisi cuaca. Pegawai Fitur Manajemen Pencatatan Inventaris Menambahkan data inventaris Melihat data inventaris Mengubah data inventaris Menonaktifkan data inventaris yang tidak tersedia Fitur Manajemen Penyemaian Bibit Menambahkan data penyemaian bibit Melihat data penyemaian bibit Mengubah data penyemaian Melihat notifikasi penyemaian mencapai 15 hari. Fitur Manajemen Pertumbuhan dan Meja Tanam Menambahkan data meja tanam. Melihat data meja tanam. Mengubah data meja tanam. Mengubah status meja tanam. Menambahkan data pertumbuhan. Melihat data pertumbuhan. Mengubah data pertumbuhan. Melihat umur tanaman berdasarkan HSS. Menambahkan data tanaman yang rusak. Melihat data tanaman yang rusak. Mengubah data tanaman yang rusak. Fitur Manajemen Pencatatan Panen Melihat estimasi waktu panen. Menambahkan data panen. Melihat data panen. Mengubah data panen. API BMKG Penyediaan Data Cuaca Menyediakan data kondisi cuaca. Menyediakan data prakiraan cuaca. |  |
| **Business Value:** |  |
| Keuntungan Intangible : Mempermudah pengelolaan inventaris budidaya karena data stok benih dan kebutuhan budidaya dapat dicatat dan dipantau secara terpusat. Mempermudah pengelolaan siklus budidaya selada karena proses penyemaian, pertumbuhan, tanaman rusak, hingga panen dapat dicatat dan dipantau secara terstruktur. Meningkatkan keteraturan penggunaan meja tanam karena ketersediaan lubang dan usia tanaman pada setiap meja dapat dipantau sehingga penempatan bibit menjadi lebih teratur. Membantu pengambilan keputusan dalam penanganan hama melalui hasil deteksi dan rekomendasi AI berdasarkan kondisi tanaman serta riwayat penggunaan obat. Membantu petani dalam menentukan tindakan perawatan berdasarkan kondisi cuaca melalui informasi cuaca BMKG dan rekomendasi AI. Keuntungan Tangible : Efisiensi Pengelolaan Inventaris Sebelum: Pencatatan inventaris dilakukan secara manual dan membutuhkan sekitar 60 menit per sesi dan dilakukan 2 kali sebulan, maka total waktu yang digunakan mencapai 120 menit (2 jam) per bulan. Karena pencatatan dilakukan secara manual, data stok juga perlu direkap kembali untuk mengetahui jumlah persediaan yang tersedia. Sesudah: Pencatatan inventaris dilakukan melalui sistem dan stok dapat diperbarui berdasarkan penggunaan. Waktu pencatatan ditargetkan menjadi sekitar 30 menit per sesi. Jika dilakukan 2 kali sebulan, total waktu menjadi 60 menit (1 jam) per bulan. Dengan demikian, petani dapat menghemat sekitar 60 menit (1 jam) per bulan (120 − 60 \= 60 menit) atau terjadi efisiensi waktu sebesar 50% ((120 − 60\) ÷ 120 × 100% \= 50%). Efisiensi Monitoring Siklus Budidaya Sebelum: Monitoring proses budidaya mulai dari penyemaian, pemindahan bibit, pertumbuhan, hingga panen dilakukan secara manual. Satu siklus membutuhkan 15 hari penyemaian \+ 45 hari pertumbuhan \= 60 hari sampai panen. Dengan asumsi pencatatan dan pengecekan usia tanaman pada 12 meja membutuhkan sekitar 90 menit sampai dengan 120 menit per sesi, maka setiap proses monitoring diperkirakan membutuhkan waktu paling lama 2 jam karena tanaman memiliki usia yang berbeda akibat penyemaian berikutnya dilakukan setiap 10 hari. Sesudah: Sistem mencatat tanggal penyemaian, umur bibit, pemindahan ke meja, umur tanaman, tanaman rusak, dan estimasi panen secara otomatis. Waktu monitoring ditargetkan menjadi sekitar 45 menit per sesi. Dengan demikian, waktu monitoring dapat dikurangi sebesar 75 menit per sesi (120 − 45 \= 75 menit) atau terjadi efisiensi sebesar 62,5% ((120 − 45\) ÷ 120 × 100% \= 62,5%). Sistem juga dapat membantu memantau seluruh kapasitas 3.000 lubang tanam yang terdiri dari 12 meja × 250 lubang. Optimalisasi Pemanfaatan Meja Tanam Sebelum: Pengecekan kondisi meja dan jumlah tanaman yang rusak atau gagal tumbuh dilakukan secara manual. Setiap meja memiliki 250 lubang, dengan total 12 meja \= 3.000 lubang tanam (12 × 250). Dengan asumsi pengecekan seluruh meja membutuhkan sekitar 90 menit per sesi, maka petani membutuhkan sekitar 1,5 jam untuk melakukan pengecekan kapasitas dan kondisi tanaman pada seluruh meja. Sesudah: Sistem dapat menampilkan data tanaman berdasarkan meja serta mencatat tanaman yang rusak, busuk, atau gagal tumbuh. Waktu pengecekan dikurangi menjadi sekitar 30 menit per sesi, sehingga petani dapat menghemat sekitar 60 menit per sesi (90 − 30 \= 60 menit) atau terjadi efisiensi waktu sebesar 66,67% ((90 − 30\) ÷ 90 × 100% \= 66,67%). Efisiensi Monitoring Hama Sebelum: Dokumentasi hama dilakukan dengan mengambil foto tanaman kemudian menyimpan dan mencari kembali foto tersebut secara manual di HP. Dengan asumsi proses dokumentasi, pencarian riwayat, dan pencatatan penanganan membutuhkan sekitar 60 menit per kejadian, maka waktu yang diperlukan adalah sekitar 1 jam untuk setiap kejadian hama. Sesudah: Petani dapat mengunggah foto tanaman langsung melalui sistem untuk mendapatkan hasil deteksi hama serta rekomendasi penanganan. Waktu monitoring ditargetkan menjadi sekitar 20 menit per kejadian, sehingga waktu yang dapat dihemat mencapai 40 menit per kejadian (60 − 20 \= 40 menit) atau terjadi efisiensi sebesar 66,67% ((60 − 20\) ÷ 60 × 100% \= 66,67%). Monitoring dan Evaluasi Hasil Panen Sebelum: Data tanggal panen, tonase, harga, dan hasil dari setiap meja dicatat secara manual di buku. Dengan asumsi proses pencatatan dan rekapitulasi membutuhkan sekitar 60 menit setiap panen, sedangkan panen dilakukan 2 kali dalam satu bulan, maka waktu yang digunakan mencapai 120 menit atau 2 jam per bulan (60 × 2). Hasil produksi rata-rata mencapai 350 kg per panen, sehingga total produksi sekitar 700 kg per bulan (350 × 2). Sesudah: Data panen dan penjualan dicatat langsung melalui sistem sehingga proses pencatatan dan rekapitulasi ditargetkan menjadi sekitar 30 menit setiap panen. Dengan frekuensi 2 kali panen per bulan, total waktu menjadi 60 menit atau 1 jam per bulan (30 × 2). Dengan demikian, petani dapat menghemat sekitar 60 menit atau 1 jam per bulan (120 − 60\) atau terjadi efisiensi waktu sebesar 50% ((120 − 60\) ÷ 120 × 100%). Sistem juga dapat membantu memantau produksi sekitar 700 kg per bulan serta keuntungan kotor sekitar Rp14.000.000–Rp17.500.000 per bulan (Rp7.000.000 × 2 sampai Rp8.750.000 × 2). |  |
| **Special Issues Or Constraints** |  |
| Special Issues : Kualitas dataset AI memengaruhi hasil deteksi hama. Kualitas foto tanaman dapat memengaruhi hasil deteksi. Riwayat penggunaan obat memengaruhi hasil rekomendasi rotasi obat dapat diberikan dengan tepat. Rekomendasi AI bersifat sebagai pendukung keputusan petani, bukan pengganti keputusan dalam penanganan tanaman. Constraints : Sistem dikembangkan dalam bentuk mobile application. Sistem membutuhkan koneksi internet untuk sinkronisasi data dan integrasi API BMKG. Sistem difokuskan pada budidaya selada hidroponik NFT. Status meja tanam diperbarui secara manual oleh petani, sehingga sistem tidak mendeteksi kondisi fisik meja secara otomatis. Data cuaca bergantung pada ketersediaan API BMKG. |  |

# **Software Requirements Specification**

# **for**

# **HidroSense: Sistem Manajemen Budidaya Selada Hidroponik NFT dengan Deteksi Hama dan Rekomendasi Perawatan berdasarkan Cuaca Menggunakan YOLO berbasis Mobile**

**Version 1.0 approved**

**Prepared by Kelompok A9 PPL Agro Universitas Jember**

**\<organization\>**

**\<date created\>**

**Table of Contents**

**[HidroSense: Sistem Manajemen Budidaya Selada Hidroponik NFT dengan Deteksi Hama dan Rekomendasi Perawatan berdasarkan Cuaca Menggunakan YOLO berbasis Mobile	1](#hidrosense:-sistem-manajemen-budidaya-selada-hidroponik-nft-dengan-deteksi-hama-dan-rekomendasi-perawatan-berdasarkan-cuaca-menggunakan-yolo-berbasis-mobile)**

[**1\. Introduction	1**](#introduction)

[1.1. Purpose	1](#purpose)

[1.2. Scope	2](#scope)

[1.2.1. Metodologi Pengembangan	2](#metodologi-pengembangan)

[1.3. Product Perspective	3](#product-perspective)

[1.3.1. System Interfaces	3](#system-interfaces)

[1.3.2. User Interfaces	3](#user-interfaces)

[1.3.3. Hardware Interfaces	3](#hardware-interfaces)

[1.3.4. Software Interfaces	3](#software-interfaces)

[1.3.5. Communication Interfaces	4](#communication-interfaces)

[1.3.6. Memory Constraints	4](#memory-constraints)

[1.3.7. Operations	4](#operations)

[3.1.1. Site Adaption Requirements	4](#site-adaption-requirements)

[3.1.2. Interfaces with Services	4](#interfaces-with-services)

[1.4. Product Functions	5](#product-functions)

[1.5. User Characteristic	5](#user-characteristic)

[1.6. Limitations	5](#limitations)

[1.7. Assumption and Dependencies	6](#assumption-and-dependencies)

[1.8. Definitions	6](#definitions)

[1.9. Acronyms and Abbreviations	6](#acronyms-and-abbreviations)

[**2\. Requirement	6**](#requirement)

[2.1. External Interfaces	7](#external-interfaces)

[2.2. Functions	7](#functions)

[2.2.1. Input	7](#input)

[2.2.2. Proses	9](#proses)

[2.2.3. Output	10](#output)

[2.3. Usability Requirement	11](#usability-requirement)

[2.4. Performance Requirement	12](#performance-requirement)

[2.4.1. Persyaratan Numerik Statis	12](#persyaratan-numerik-statis)

[2.5. Logical Database Requirement	13](#logical-database-requirement)

[2.6. Design Constraints	13](#design-constraints)

[2.7. Design Constraints	14](#design-constraints-1)

[2.7.1. Reliability	14](#reliability)

[2.7.2. Availability	14](#availability)

[2.7.3. Security	14](#security)

[2.7.4. Maintainability	14](#maintainability)

[2.7.5. Portability	14](#portability)

[2.8. Software System  Attributes	15](#software-system-attributes)

[**3\. Verification	15**](#verification)

[**4\. Requirement	17**](#requirement-1)

[4.1. PRODUCT BACKLOG	18](#product-backlog)

[4.2. PROJECT CHARTER	25](#project-charter)

[4.3. GANTT CHART	29](#gantt-chart)

[4.4. WORK BREAKDOWN STRUCTURE (WBS)	29](#work-breakdown-structure-\(wbs\))

[4.5. WORK BREAKDOWN STRUCTURE	35](#work-breakdown-structure)

[4.6. CLASS DIAGRAM	39](#class-diagram)

[4.7. FLOWCHART AI	39](#flowchart-ai)

[**4\. Overall Description	39**](#overall-description)

[1\. Product Perspective	39](#product-perspective-1)

[2\. Product Functions	39](#product-functions-1)

[3\. User Classes and Characteristics	39](#user-classes-and-characteristics)

[4\. Operating Environment	40](#operating-environment)

[5\. Design and Implementation Constraints	40](#design-and-implementation-constraints)

[6\. User Documentation	40](#user-documentation)

[7\. Assumptions and Dependencies	40](#assumptions-and-dependencies)

[**5\. External Interface Requirements	40**](#external-interface-requirements)

[1\. User Interfaces	40](#user-interfaces-1)

[2\. Hardware Interfaces	40](#hardware-interfaces-1)

[3\. Software Interfaces	41](#software-interfaces-1)

[4\. Communications Interfaces	41](#communications-interfaces)

[**6\. System Features	41**](#system-features)

[1\. System Feature 1	41](#system-feature-1)

[2\. System Feature 2 (and so on)	42](#system-feature-2-\(and-so-on\))

[**7\. Other Nonfunctional Requirements	42**](#other-nonfunctional-requirements)

[1\. Performance Requirements	42](#performance-requirements)

[2\. Safety Requirements	42](#safety-requirements)

[3\. Security Requirements	42](#security-requirements)

[4\. Software Quality Attributes	42](#software-quality-attributes)

[5\. Business Rules	42](#business-rules)

[**8\. Other Requirements	42**](#other-requirements)

**Revision History**

| Name | Date | Reason For Changes | Version |
| :---- | :---- | :---- | :---- |
|  |  |  |  |
|  |  |  |  |

1. # **Introduction** {#introduction}

HidroSense adalah platform berbasis mobile yang membantu petani mengelola proses budidaya selada hidroponik dengan sistem NFT (Nutrient Film Technique) secara terstruktur. Platform ini menyediakan fitur untuk mengelola berbagai tahapan budidaya, yaitu pencatatan inventaris, penyemaian, pemantauan pertumbuhan, panen, penjualan, dan penanganan hama. HidroSense menggunakan algoritma YOLO untuk mendeteksi hama pada tanaman selada berdasarkan gambar yang diunggah oleh petani. Selain itu, sistem ini menggunakan data cuaca dari API BMKG untuk memberikan rekomendasi tindakan perawatan berdasarkan kondisi lingkungan.

HidroSense bertujuan membantu petani, khususnya mitra Hidro Selada milik Bapak Agus di Ambulu, Kabupaten Jember, dalam mengidentifikasi hama pada tanaman selada secara dini. Sistem mengidentifikasi hama berdasarkan ciri-ciri visual yang terdapat pada daun selada. Hasil identifikasi tersebut menjadi dasar dalam menentukan tindakan penanganan hama. HidroSense juga memberikan rekomendasi penanganan dan rotasi obat berdasarkan riwayat penggunaan obat sebelumnya. Dengan mekanisme tersebut, petani dapat mengurangi penggunaan jenis obat yang sama secara berulang sehingga risiko hama beradaptasi terhadap satu jenis obat dapat ditekan.

Penerapan HidroSense diharapkan dapat meningkatkan efisiensi pengelolaan budidaya selada hidroponik. Sistem ini juga membantu petani menekan risiko kerugian akibat serangan hama dan mengoptimalkan pemanfaatan kapasitas meja tanam. Selain itu, HidroSense dapat menjadi langkah awal dalam digitalisasi usaha budidaya selada hidroponik skala kecil dan menengah untuk mendukung pengelolaan pertanian yang lebih modern.

1. ## **Purpose** {#purpose}

Tujuan sistem aplikasi ini adalah:

* Sistem mempermudah pencatatan dan pengelolaan inventaris budidaya, seperti benih, media tanam, pupuk, dan obat. Sistem juga mencatat pengurangan stok secara otomatis ketika bahan digunakan.  
* Sistem mempermudah pengelolaan siklus budidaya selada, mulai dari penyemaian, pemindahan tanaman ke meja tanam, pemantauan pertumbuhan, hingga panen.  
* Sistem membantu petani mengoptimalkan pemanfaatan kapasitas meja tanam berdasarkan ketersediaan lubang tanam dan usia tanaman.  
* Sistem memberikan hasil deteksi hama secara cepat berdasarkan gambar tanaman yang diunggah. Sistem juga memberikan rekomendasi penanganan dan rotasi obat yang sesuai.  
* Sistem memberikan rekomendasi tindakan perawatan tanaman berdasarkan kondisi dan prakiraan cuaca dari API BMKG.  
* Sistem mendukung peningkatan produktivitas budidaya dengan mengurangi kerugian akibat keterlambatan penanganan hama dan kondisi cuaca yang tidak terpantau.

  2. ## **Scope** {#scope}

Ruang lingkup sistem meliputi:

* Sistem beroperasi sebagai aplikasi mobile.  
* Aktor membutuhkan koneksi internet untuk melakukan sinkronisasi data dan mengakses API BMKG.  
* Sistem berfokus pada budidaya selada dengan metode hidroponik NFT.  
* Sistem memiliki tiga jenis aktor, yaitu petani, pegawai, dan API BMKG sebagai aktor eksternal.  
* Pengguna harus melakukan login untuk mengakses fitur utama sistem.  
  * Petani dan pegawai melakukan login menggunakan username dan password.  
* Sistem pada tahap awal mendeteksi tiga jenis hama, yaitu thrips, whitefly (kutu kebul), dan aphids (kutu daun). Jenis hama tersebut dapat dikembangkan lebih lanjut sesuai dengan kebutuhan mitra.  
* Petani memperbarui status fisik meja tanam secara manual karena sistem tidak melakukan deteksi otomatis terhadap kondisi fisik meja.

  1. ## **Metodologi Pengembangan** {#metodologi-pengembangan}

Tim menggunakan model pengembangan SDLC Agile Scrum untuk mengembangkan sistem ini. Model tersebut digunakan karena dapat beradaptasi terhadap perubahan kebutuhan dan sesuai untuk tim kerja kecil dengan waktu pengerjaan yang terbatas, seperti tenggat mata kuliah Pengembangan Perangkat Lunak. Tim melakukan pengujian pada setiap sprint agar dapat menyelesaikan kendala secara bertahap tanpa menunggu seluruh sistem selesai dibangun.

Tim kerja terdiri atas tiga peran, yaitu Scrum Master, Product Owner, dan Development Team (DT).

1. Scrum Master mengarahkan dan membimbing Product Owner serta Development Team agar proses pengembangan sistem berjalan sesuai dengan prosedur yang telah disepakati.  
2. Product Owner mewakili kebutuhan pengguna, khususnya mitra Hidro Selada, dan menyampaikan visi produk kepada tim.  
3. Development Team melakukan perancangan, pengembangan, dan pengujian sistem.

**STRUKTUR TIM**

| Nama | NIM | Posisi | Kontak |
| :---- | :---- | :---- | :---- |
| Aditya Dwi Ferdiansyah | 242410103030 | Scrum Master & DT (Backend Developer) | \+62 822-4443-1416 |
| Siti Raudatul Jannah  | 242410103048 | Product Owner (Analyst) | \+62 852-3392-9574 |
| Fakhrian Iqbal Zulkarnain  | 242410103060 | DT (UI/UX Designer) | \+62 831-2204-2536 |
| Mochammad Wildan Alqori'in  | 242410103063 | DT (Frontend Developer) | \+62 851-1314-9394 |
| Achmad Nuhan T. | 242410103011 | DT (Tester) | \+62 851-0308-0404 |

Tahapan pengembangan sistem meliputi:

1. Analisis, yaitu tahap ketika tim menganalisis kebutuhan pengguna dan mengumpulkan informasi mengenai proses budidaya untuk menyusun kebutuhan sistem. Tim juga menggunakan dokumen System Request yang telah disusun bersama mitra sebagai salah satu sumber informasi.  
2. Perancangan, yaitu tahap ketika tim merancang arsitektur sistem berbasis mobile, skema basis data, dan alur integrasi model AI.  
3. Implementasi, yaitu tahap ketika tim mengembangkan sistem berdasarkan hasil perancangan.  
4. Pengujian dan Evaluasi, yaitu tahap ketika tim menguji sistem yang telah diimplementasikan untuk menemukan kekurangan sistem. Tim kemudian melakukan evaluasi berdasarkan hasil pengujian tersebut.

   3. ## **Product Perspective** {#product-perspective}

Produk yang dikembangkan diharapkan dapat meningkatkan proses bisnis budidaya selada hidroponik milik mitra. Sistem tersebut berfokus pada deteksi hama melalui analisis visual pada daun selada dan pengelolaan operasional budidaya secara terpusat dalam satu aplikasi. 

1. ## **System Interfaces** {#system-interfaces}

Sistem dirancang untuk berjalan sebagai aplikasi mobile pada perangkat Android. Tim dapat mengembangkan sistem ke platform iOS pada tahap berikutnya untuk memperluas jangkauan pengguna. 

2. ## **User Interfaces** {#user-interfaces}

HidroSense menerapkan antarmuka pengguna yang sederhana dan intuitif. Konsep tersebut diterapkan karena pengguna utama sistem, yaitu petani, tidak selalu memiliki latar belakang teknis di bidang teknologi. Antarmuka tersebut bertujuan memberikan pengalaman penggunaan yang lancar, terutama ketika pengguna mengunggah foto tanaman dan mencatat data budidaya di lapangan.

3. ## **Hardware Interfaces** {#hardware-interfaces}

Perangkat keras yang digunakan dalam sistem meliputi:

* Smartphone Android dengan kamera untuk mengambil gambar tanaman.  
* Koneksi internet melalui Wi-Fi atau data seluler.

  4. ## **Software Interfaces** {#software-interfaces}

Pembangunan sistem membutuhkan perangkat lunak pendukung sebagai berikut:

* Framework aplikasi mobile: Flutter (Dart).  
* Model deteksi hama: YOLO yang dijalankan secara lokal pada perangkat melalui TensorFlow Lite.  
* Basis data lokal pada perangkat: SQLite.  
* Basis data pusat untuk sinkronisasi: Turso (libSQL).  
* Backend untuk integrasi API BMKG dan proses bisnis lainnya: Node.js atau FastAPI.  
* Penyimpanan gambar: Cloudinary.  
* Sistem operasi pengembangan: Windows 11\.  
* Browser pendukung proses pengembangan: Google Chrome.

  5. ## **Communication Interfaces** {#communication-interfaces}

### **USE CASE HIDROSENSE**

[![][image2]](https://drive.google.com/file/d/1aiVYCr3068yJVfejv4Lk-TRNcMs-wGbe/view?usp=sharing)

6. ## **Memory Constraints** {#memory-constraints}

Perangkat smartphone yang digunakan petani disarankan memiliki RAM minimum 3 GB agar proses deteksi hama berbasis AI secara lokal dapat berjalan dengan lancar. Sistem tidak menetapkan batas maksimum spesifikasi perangkat sehingga sistem tetap dapat berjalan pada perangkat dengan spesifikasi yang lebih tinggi. 

7. ## **Operations** {#operations}

1. Petani dan pegawai wajib melakukan login sebelum mengakses fitur dalam sistem.  
2. Sistem melakukan sinkronisasi data ke server pusat secara otomatis ketika perangkat terhubung ke internet.  
3. Sistem memperbarui data cuaca dari API BMKG secara berkala sesuai dengan ketersediaan API.

   1. ## **Site Adaption Requirements** {#site-adaption-requirements}

HidroSense berjalan sebagai aplikasi native pada sistem operasi Android. Oleh karena itu, sistem memerlukan penyesuaian terhadap versi sistem operasi target, seperti Android versi 8.0 atau lebih baru. Versi minimum tersebut perlu divalidasi kembali sesuai dengan kebutuhan pengujian tim.

2. ## **Interfaces with Services** {#interfaces-with-services}

1. GUI menggunakan Flutter.  
2. Sistem menggunakan SQLite sebagai basis data lokal dan Turso (libSQL) sebagai basis data sinkronisasi.  
3. Sistem menggunakan Node.js atau FastAPI sebagai backend.  
4. Sistem menggunakan API BMKG dan Cloudinary sebagai layanan eksternal.

   4. ## **Product Functions** {#product-functions}

Sistem ini memberikan manfaat sebagai berikut:

1. Sistem mengurangi kerugian akibat serangan hama pada budidaya selada dengan memberikan deteksi dini dan rekomendasi penanganan secara cepat.  
2. Sistem mempermudah petani mencatat dan memantau inventaris, siklus budidaya, panen, dan penjualan secara terpusat dalam satu aplikasi.  
3. Sistem membantu petani mengoptimalkan pemanfaatan kapasitas 3.000 lubang tanam pada 12 meja tanam milik mitra.  
4. Sistem membantu petani menentukan rotasi obat berdasarkan riwayat penggunaan sehingga risiko resistensi hama terhadap jenis obat yang sama dapat dikurangi.  
5. Sistem membantu petani menentukan tindakan perawatan tanaman berdasarkan kondisi dan prakiraan cuaca.

   5. ## **User Characteristic** {#user-characteristic}

| Pengguna | Kebutuhan |
| ----- | ----- |
| Petani | 1\. Melakukan login. 2\. Mengelola data inventaris. 3\. Mengelola data penyemaian bibit. 4\. Mengelola data pertumbuhan dan meja tanam. 5\. Mengelola data panen dan penjualan. 6\. Mengunggah gambar tanaman untuk melakukan deteksi hama. 7\. Melihat hasil deteksi dan rekomendasi obat. 8\. Melihat rekomendasi perawatan berdasarkan kondisi cuaca. 9\. Mengelola data akun.  |
| Pegawai | 1\. Melakukan login. 2\. Mengelola data inventaris. 3\. Mengelola data penyemaian bibit. 4\. Mengelola data pertumbuhan dan meja tanam.  |
| API BMKG | 1\. Menyediakan data kondisi cuaca. 2\. Menyediakan data prakiraan cuaca.  |

   6. ## **Limitations** {#limitations}

* Sistem dirancang sebagai aplikasi mobile.  
* Sistem hanya dapat diakses oleh pengguna yang telah terverifikasi menggunakan username dan password.  
* Sistem berfokus pada budidaya selada hidroponik dengan metode NFT.  
* Sistem pada tahap awal hanya mendeteksi tiga jenis hama, yaitu *thrips*, *whitefly*, dan *aphids*.  
* Kualitas foto tanaman yang diunggah dapat memengaruhi keakuratan hasil deteksi.  
* Rekomendasi AI berfungsi sebagai pendukung keputusan petani dan bukan sebagai pengganti keputusan dalam penanganan tanaman.  
* Petani memperbarui status fisik meja tanam secara manual karena sistem tidak mendeteksi kondisi fisik meja secara otomatis.  
* Sistem membutuhkan koneksi internet untuk melakukan sinkronisasi data dan mengakses API BMKG.  
* Data cuaca yang ditampilkan bergantung pada ketersediaan API BMKG.

  7. ## **Assumption and Dependencies** {#assumption-and-dependencies}

Pengguna HidroSense diasumsikan memiliki smartphone dengan sistem operasi Android dan akses internet yang memadai untuk melakukan sinkronisasi data serta mengakses fitur berbasis AI. Sistem juga bergantung pada ketersediaan dan stabilitas API BMKG untuk menyediakan fitur rekomendasi perawatan berdasarkan kondisi cuaca.

8. ## **Definitions** {#definitions}

* **System Request (SR)** adalah dokumen yang menjelaskan alasan bisnis pembangunan sistem dan harapan terhadap sistem tersebut.  
* **Software Requirements Specification (SRS)** adalah dokumen yang menjelaskan kebutuhan dan cara pengembangan sebuah perangkat lunak.  
* **Unified Modelling Language (UML)** adalah metode pemodelan visual yang digunakan sebagai sarana perancangan sistem berorientasi objek.  
* **Application Programming Interface (API)** adalah sekumpulan aturan dan definisi yang memungkinkan suatu aplikasi berinteraksi dengan perangkat lunak lain.  
* **Nutrient Film Technique (NFT)** adalah sistem hidroponik yang menggunakan aliran tipis larutan nutrisi yang bersirkulasi secara terus-menerus melewati akar tanaman.  
* **YOLO (You Only Look Once)** adalah arsitektur model deteksi objek berbasis deep learning yang digunakan untuk mendeteksi hama pada gambar tanaman.

  9. ## **Acronyms and Abbreviations** {#acronyms-and-abbreviations}

* **SRS**: Software Requirements Specification.  
* **SR**: System Request.  
* **UML**: Unified Modelling Language.  
* **GUI**: Graphical User Interface.  
* **UI**: User Interface.  
* **UX**: User Experience.  
* **API**: Application Programming Interface.  
* **SDLC**: Software Development Life Cycle.  
* **DT**: Development Team.  
* **RAM**: Random Access Memory.  
* **NFT**: Nutrient Film Technique.  
* **BMKG**: Badan Meteorologi, Klimatologi, dan Geofisika.  
* **HSS**: Hari Setelah Semai.

2. # **Requirement** {#requirement}

   1. ## **External Interfaces** {#external-interfaces}

External interface mencakup antarmuka pengguna yang mengatur interaksi antara sistem dan pengguna. Selain itu, external interface mencakup tata letak layar, tombol, fungsi pada setiap layar, antarmuka perangkat keras, dan kebutuhan antarmuka lainnya. 

| Aktor/Entitas | Atribut yang Dibutuhkan |
| ----- | ----- |
| Users (Petani/Pegawai)  | Nama, Username, Password, Email, No. Telepon, Alamat, Role, Status Akun  |
| Inventaris | Nama barang, Jenis inventaris, Satuan, Stok minimum, Status aktif  |
| Transaksi Stok | Jenis transaksi (masuk/keluar), Tanggal, Jumlah, Barang terkait  |
| Penyemaian | Tanggal semai, Jumlah benih, Status penyemaian  |
| Meja Tanam | Kode meja, Jumlah lubang, Status meja  |
| Pemindahan | Tanggal pemindahan, Jumlah tanaman, Asal penyemaian, Meja tujuan  |
| Kerusakan Tanaman | Tanggal kejadian, Jenis kerusakan, Jumlah tanaman terdampak  |
| Panen | Tanggal panen, Jumlah tanaman, Berat hasil panen  |
| Penjualan | Tanggal jual, Jumlah kilogram terjual, Harga per kilogram  |
| Deteksi Hama | Gambar tanaman (referensi penyimpanan gambar), Nama hama terdeteksi, Tingkat keyakinan (confidence)  |
| Rekomendasi Perawatan | Obat yang direkomendasikan, Status rekomendasi (diterima/ditolak), Alasan penolakan  |
| Perawatan | Tindakan yang dilakukan, Catatan petani  |
| Kondisi Cuaca | Rentang suhu, Kelembapan, Curah hujan, dan rekomendasi terkait  |

2. ## **Functions** {#functions}

Functions merupakan tindakan mendasar yang harus dilakukan perangkat lunak untuk menerima dan merespons input, mengelola data, serta menghasilkan output.

1. ## **Input** {#input}

1. **Input proses login**  
* Field username digunakan untuk memasukkan username pengguna.  
* Field password digunakan untuk memasukkan password pengguna.  
* Tombol masuk digunakan untuk melakukan proses login ke dalam sistem.

2. **Input manajemen inventaris**  
* Field nama barang digunakan untuk memasukkan nama barang.  
* Field jenis inventaris digunakan untuk menentukan jenis inventaris.  
* Field satuan digunakan untuk memasukkan satuan barang.  
* Field stok minimum digunakan untuk memasukkan batas minimum stok.  
* Tombol simpan, ubah, dan nonaktifkan digunakan untuk mengelola data inventaris.

3. **Input transaksi stok**  
* Field jenis transaksi digunakan untuk menentukan jenis transaksi, yaitu transaksi masuk atau keluar.  
* Field jumlah digunakan untuk memasukkan jumlah barang yang ditransaksikan.  
* Field barang terkait digunakan untuk menentukan barang yang terlibat dalam transaksi.  
* Tombol simpan digunakan untuk menyimpan data transaksi stok.

4. **Input manajemen penyemaian bibit**  
* Field tanggal semai digunakan untuk memasukkan tanggal penyemaian.  
* Field jumlah benih digunakan untuk memasukkan jumlah benih yang disemai.  
* Tombol simpan dan ubah digunakan untuk mengelola data penyemaian.

5. **Input manajemen meja tanam**  
* Field kode meja digunakan untuk memasukkan kode meja tanam.  
* Field jumlah lubang digunakan untuk memasukkan jumlah lubang tanam.  
* Field status meja digunakan untuk menentukan status meja tanam.  
* Tombol simpan dan ubah digunakan untuk mengelola data meja tanam.

6. **Input pemindahan tanaman**  
* Field asal penyemaian digunakan untuk menentukan data penyemaian asal tanaman.  
* Field meja tujuan digunakan untuk menentukan meja tanam tujuan.  
* Field jumlah tanaman digunakan untuk memasukkan jumlah tanaman yang dipindahkan.  
* Tombol simpan digunakan untuk menyimpan data pemindahan tanaman.

7. **Input kerusakan tanaman**  
* Field data pemindahan terkait digunakan untuk menentukan data pemindahan tanaman yang mengalami kerusakan.  
* Field jenis kerusakan digunakan untuk menentukan jenis kerusakan tanaman.  
* Field jumlah tanaman terdampak digunakan untuk memasukkan jumlah tanaman yang mengalami kerusakan.  
* Tombol simpan digunakan untuk menyimpan data kerusakan tanaman.

8. **Input manajemen panen**  
* Field data pemindahan terkait digunakan untuk menentukan batch tanaman yang dipanen.  
* Field jumlah tanaman digunakan untuk memasukkan jumlah tanaman yang dipanen.  
* Field berat hasil panen digunakan untuk memasukkan berat hasil panen.  
* Tombol simpan dan ubah digunakan untuk mengelola data panen.

9. **Input manajemen penjualan**  
* Field data panen terkait digunakan untuk menentukan data panen yang dijual.   
* Field jumlah kilogram terjual digunakan untuk memasukkan jumlah hasil panen yang terjual.   
* Field harga per kilogram digunakan untuk memasukkan harga jual setiap kilogram.  
* Tombol simpan dan ubah digunakan untuk mengelola data penjualan. 

10. **Input deteksi hama**  
* Field camera scan digunakan untuk mengambil gambar tanaman secara langsung melalui kamera.   
* Field upload gambar digunakan untuk memilih gambar tanaman dari galeri.   
* Tombol Deteksi digunakan untuk memproses gambar agar dapat dianalisis oleh sistem. 

11. **Input keputusan rekomendasi perawatan**  
* Tombol terima atau tolak rekomendasi digunakan untuk menentukan keputusan terhadap rekomendasi perawatan.   
* Field alasan penolakan digunakan untuk mencatat alasan ketika petani menolak rekomendasi. 

12. **Input data perawatan**  
* Field tindakan yang dilakukan digunakan untuk mencatat tindakan perawatan yang dilakukan petani.   
* Field catatan tambahan digunakan untuk mencatat informasi tambahan mengenai tindakan perawatan.   
* Tombol simpan digunakan untuk menyimpan data perawatan. 

  2. ## **Proses** {#proses}

Sistem HidroSense menampilkan halaman utama setelah pengguna berhasil melakukan login. Tampilan halaman utama menyesuaikan peran pengguna, yaitu petani atau pegawai. Selain itu, sistem mencatat setiap perubahan stok inventaris sebagai transaksi tersendiri. Dengan demikian, sistem menghitung jumlah stok berdasarkan akumulasi seluruh transaksi masuk dan keluar, bukan berdasarkan angka statis yang diubah secara manual.

Pada proses budidaya, sistem menghubungkan data penyemaian dan data meja tanam melalui proses pemindahan tanaman. Data pemindahan menjadi acuan utama untuk melacak tahapan budidaya berikutnya, termasuk pencatatan kerusakan tanaman, hasil panen, dan hasil deteksi hama. Dengan mekanisme tersebut, sistem dapat menelusuri riwayat setiap batch tanaman dari tahap penyemaian hingga panen.

Pada fitur deteksi hama, pengguna dapat mengambil gambar tanaman secara langsung melalui kamera atau mengunggah gambar dari galeri. Setelah itu, pengguna menekan tombol Deteksi untuk memulai proses analisis. Sistem memproses gambar secara lokal pada perangkat menggunakan model YOLO yang telah dikonversi ke format TensorFlow Lite. Sistem kemudian menghasilkan deteksi hama berupa thrips, whitefly, atau aphids tanpa harus mengirimkan gambar ke server terlebih dahulu. Sistem menyimpan hasil deteksi dan menghubungkannya dengan data pemindahan tanaman yang bersangkutan.

Setelah sistem mengidentifikasi hama, sistem memeriksa riwayat penggunaan obat pada batch tanaman terkait. Sistem kemudian menentukan rekomendasi obat berikutnya berdasarkan aturan rotasi golongan bahan aktif. Aturan tersebut bertujuan mengurangi risiko hama beradaptasi terhadap satu jenis obat yang sama. Sistem menyimpan rekomendasi dengan status awal menunggu keputusan petani. Petani dapat menerima atau menolak rekomendasi tersebut. Jika petani menolak rekomendasi, petani dapat mencantumkan alasan penolakan. Setelah petani menentukan keputusan, sistem mencatat tindakan perawatan yang benar-benar dilakukan sebagai data perawatan, termasuk catatan tambahan jika diperlukan. Dengan mekanisme tersebut, rekomendasi AI berfungsi sebagai pendukung keputusan dan tidak menjalankan tindakan perawatan secara otomatis tanpa persetujuan petani.

Selain menggunakan fitur deteksi hama, petani dapat mencatat kejadian kerusakan tanaman, seperti tanaman busuk atau gagal tumbuh. Sistem menghubungkan data kerusakan tersebut dengan data pemindahan tanaman yang terkait.

Pada fitur rekomendasi cuaca, sistem mengambil data kondisi dan prakiraan cuaca dari API BMKG secara berkala. Sistem kemudian mencocokkan data tersebut dengan aturan rentang kondisi cuaca yang telah ditetapkan, meliputi suhu, kelembapan, dan curah hujan. Berdasarkan hasil pencocokan tersebut, sistem menampilkan rekomendasi tindakan perawatan yang sesuai. Sistem melakukan pencocokan setiap kali mengambil data cuaca dari API dan tidak menyimpan data cuaca sebagai riwayat historis.

Sistem menyimpan seluruh data yang dicatat pengguna, seperti inventaris, stok, penyemaian, meja tanam, pemindahan, kerusakan tanaman, panen, dan penjualan, terlebih dahulu pada basis data lokal di perangkat. Sistem kemudian menyinkronkan data tersebut secara otomatis ke basis data pusat ketika perangkat terhubung ke internet.

3. ## **Output** {#output}

1. **Output proses login**  
* Sistem mengautentikasi pengguna yang memasukkan kredensial login yang valid.  
* Sistem memberikan akses ke dashboard sesuai dengan role pengguna, yaitu petani atau pegawai.

2. **Output manajemen inventaris dan stok**  
* Sistem menyimpan data inventaris dan transaksi stok.  
* Sistem menghitung jumlah stok terkini secara otomatis berdasarkan akumulasi transaksi.

3. **Output manajemen penyemaian bibit**  
* Sistem menyimpan data penyemaian.  
* Sistem menampilkan status penyemaian sehingga pengguna dapat memantau proses penyemaian.

4. **Output manajemen meja tanam**  
* Sistem menyimpan data meja tanam.  
* Sistem menampilkan status meja tanam.

5. **Output pemindahan tanaman**  
* Sistem menyimpan data pemindahan sebagai penghubung antara data penyemaian dan meja tanam.  
* Sistem menggunakan data pemindahan untuk menelusuri riwayat batch tanaman.

6. **Output kerusakan tanaman**  
* Sistem menyimpan data kerusakan tanaman dan menghubungkannya dengan data pemindahan terkait.

7. **Output manajemen panen dan penjualan**  
* Sistem menyimpan data panen yang meliputi jumlah tanaman dan berat hasil panen secara terpisah dari data harga jual.  
* Sistem menyimpan data penjualan yang meliputi jumlah kilogram terjual dan harga per kilogram serta menghubungkannya dengan data panen terkait.

8. **Output deteksi hama**  
* Sistem memproses gambar secara lokal pada perangkat.  
* Sistem menampilkan hasil deteksi berupa jenis hama dan tingkat keyakinan (confidence score) serta menghubungkannya dengan data pemindahan terkait.  
* Sistem menyimpan rekomendasi obat dengan status menunggu keputusan petani.

9. **Output keputusan rekomendasi perawatan**  
* Sistem menyimpan status rekomendasi, yaitu diterima atau ditolak.  
* Sistem menyimpan alasan penolakan apabila petani menolak rekomendasi.  
* Sistem menyimpan data tindakan perawatan yang benar-benar dilakukan petani.

10. **Output rekomendasi cuaca**  
* Sistem menampilkan data kondisi dan prakiraan cuaca.  
* Sistem menampilkan rekomendasi tindakan perawatan berdasarkan hasil pencocokan kondisi cuaca.

  3. ## **Usability Requirement** {#usability-requirement}

Usability requirement menjelaskan harapan dan spesifikasi yang dirancang untuk memastikan sistem mudah digunakan oleh pengguna. Pengguna utama HidroSense adalah petani yang tidak selalu memiliki latar belakang teknis. Oleh karena itu, sistem menggunakan antarmuka yang sederhana dan alur penggunaan yang jelas, terutama pada fitur pengambilan gambar untuk deteksi hama, pencatatan data budidaya sehari-hari, dan proses persetujuan rekomendasi obat.

Usability requirement mencakup efektivitas penggunaan, efisiensi waktu pencatatan, dan kepuasan pengguna ketika menjalankan aktivitas budidaya melalui aplikasi.

4. ## **Performance Requirement** {#performance-requirement}

Performance requirement menjelaskan persyaratan kinerja yang diharapkan dari sistem. Nilai yang ditetapkan pada bagian ini merupakan target awal dan dapat disesuaikan berdasarkan hasil pengujian tim. 

1. ## **Persyaratan Numerik Statis** {#persyaratan-numerik-statis}

Sistem memiliki performance requirement sebagai berikut:

* Sistem harus memuat halaman utama aplikasi dalam waktu kurang dari 3 detik setelah aplikasi dijalankan.  
* Sistem ditargetkan menyelesaikan proses deteksi hama secara lokal dalam waktu kurang dari 5 detik per gambar, tergantung pada spesifikasi perangkat yang digunakan.  
* Sistem melakukan sinkronisasi data ke basis data pusat secara otomatis dalam waktu kurang dari 1 menit setelah perangkat terhubung ke internet.  
* Sistem ditargetkan menyelesaikan pencocokan data cuaca terhadap aturan rekomendasi dalam waktu kurang dari 2 detik setiap kali data cuaca diperbarui.

  5. ## **Logical Database Requirement** {#logical-database-requirement}

![][image3]

6. ## **Design Constraints** {#design-constraints}

Design constraint merupakan kendala yang dikenakan pada solusi desain. Kendala tersebut merupakan kondisi yang perlu dipenuhi agar sistem dapat berjalan sesuai dengan kebutuhan yang telah ditetapkan.

* Sistem tidak memiliki batasan maksimal terhadap spesifikasi perangkat pengguna.  
* Sistem harus menjalankan proses deteksi hama secara lokal pada perangkat tanpa memerlukan koneksi internet.  
* Sistem harus memungkinkan pengguna mengisi data inventaris, stok, penyemaian, meja tanam, pemindahan, kerusakan tanaman, panen, dan penjualan ketika perangkat tidak terhubung ke internet.  
* Sistem harus menyinkronkan data secara otomatis ketika koneksi internet tersedia.  
* Sistem membutuhkan koneksi internet aktif untuk menjalankan fitur rekomendasi cuaca karena fitur tersebut bergantung pada data dari API BMKG.  
* Sistem mencocokkan data cuaca dari API BMKG secara langsung dengan aturan rentang kondisi yang telah ditetapkan tanpa menyimpan data tersebut sebagai riwayat historis.

  7. ## **Design Constraints** {#design-constraints-1}

Standards compliance merupakan konsistensi yang diperlukan dalam tampilan dan perilaku sistem. 

1. ## **Reliability** {#reliability}

Sistem dapat diakses ketika pengguna memiliki koneksi internet untuk fitur yang membutuhkan koneksi tersebut. Sistem menangani kegagalan sinkronisasi melalui mekanisme pengulangan otomatis ketika koneksi internet kembali tersedia. 

2. ## **Availability** {#availability}

Sistem menyediakan fitur pencatatan data dasar selama 24 jam tanpa bergantung pada koneksi internet karena sistem menyimpan data terlebih dahulu secara lokal pada perangkat. Sistem juga menyediakan fitur deteksi hama selama 24 jam karena proses deteksi dilakukan secara lokal. Sementara itu, fitur rekomendasi cuaca hanya dapat digunakan ketika koneksi internet dan API BMKG tersedia. 

3. ## **Security** {#security}

Petani dan pegawai wajib melakukan login menggunakan username dan password sebelum mengakses fitur dalam sistem sesuai dengan role masing-masing. Sistem menyimpan password pengguna dalam bentuk terenkripsi untuk menjaga keamanan data pengguna. 

4. ## **Maintainability** {#maintainability}

Tim melakukan pembaruan sistem secara berkala sesuai dengan kebutuhan pengembangan. Pembaruan tersebut mencakup model deteksi hama apabila terdapat data baru yang dapat meningkatkan akurasi. Selain itu, tim dapat memperbarui aturan rotasi obat dan aturan rekomendasi cuaca sesuai dengan kebutuhan mitra. 

5. ## **Portability** {#portability}

Kemampuan adaptasi perangkat lunak meliputi:

* Sistem dibangun menggunakan Flutter (Dart) sehingga berpotensi dikembangkan untuk platform Android dan iOS (lanjutan).   
* Tim menyusun kode dengan struktur yang rapi, komentar yang memadai, dan konvensi penamaan yang konsisten.   
* Tim membangun model deteksi hama menggunakan YOLO dan mengkonversinya ke TensorFlow Lite agar model dapat berjalan secara lokal pada perangkat mobile. 

  8. ## **Software System 	Attributes** {#software-system-attributes}

| Requirement | Keterangan |
| ----- | ----- |
| Availability  | Sistem menyediakan fitur pencatatan data dan deteksi hama selama 24 jam. Fitur cuaca bergantung pada ketersediaan API BMKG.  |
| Reliability  | Sistem menoleransi kegagalan sinkronisasi sekitar 10 sampai 15 persen dan menggunakan mekanisme pengulangan otomatis.  |
| Ergonomy  | Sistem harus mudah digunakan (user friendly), khususnya bagi petani yang tidak memiliki latar belakang teknis.  |
| Portability  | Aplikasi berjalan pada perangkat Android dan berpotensi dikembangkan ke platform iOS.  |
| Response Time  | Sistem memuat halaman dalam waktu kurang dari 3 detik dan menyelesaikan proses deteksi hama dalam waktu kurang dari 5 detik.  |
| Security  | Sistem mewajibkan login berdasarkan role dan melakukan validasi data pengguna untuk menjaga keamanan sistem.  |

3. # **Verification** {#verification}

Metode verifikasi dan validasi yang digunakan untuk menguji HidroSense meliputi usability testing, API testing, black box testing, dan model evaluation testing. Setiap metode digunakan untuk memeriksa aspek sistem yang berbeda, mulai dari kemudahan penggunaan, komunikasi dengan layanan eksternal, fungsionalitas sistem, hingga performa model deteksi hama. 

1. Usability Testing

Usability testing dilakukan untuk memeriksa kemudahan penggunaan sistem oleh pengguna sebenarnya, yaitu petani dan pegawai di Hidro Selada. Pengujian dilakukan dengan mengajak Bapak Agus dan pegawainya menggunakan aplikasi secara langsung di lokasi kebun. Pengujian terutama dilakukan pada fitur pengambilan gambar untuk deteksi hama dan pencatatan data budidaya harian.

Selama pengujian, tim mencatat setiap kesulitan atau masalah yang dialami pengguna ketika menggunakan aplikasi. Pengujian dilakukan secara langsung di lapangan karena kondisi pencahayaan, koneksi internet, dan cara pengguna memegang perangkat di kebun hidroponik dapat berbeda dari kondisi penggunaan aplikasi pada umumnya. Hasil pengujian kemudian dievaluasi untuk memastikan bahwa desain antarmuka memenuhi kebutuhan usability yang telah ditetapkan, khususnya bagi pengguna yang tidak memiliki latar belakang teknis di bidang teknologi.

2. API Testing

API testing dilakukan untuk memastikan bahwa Application Programming Interface (API) yang digunakan sistem dapat bekerja sesuai dengan kebutuhan. Pengujian mencakup integrasi dengan API BMKG serta komunikasi antara aplikasi mobile dan backend.

Tim melakukan pengujian dengan mengirimkan request ke endpoint API menggunakan alat bantu seperti Postman. Selanjutnya, tim memeriksa respons yang diterima dari server. Pengujian mencakup skenario respons normal, kondisi ketika API BMKG tidak tersedia atau mengalami keterlambatan, serta kondisi ketika sistem menerima data yang tidak valid.

Hasil pengujian digunakan untuk menentukan apakah API memberikan respons yang tepat, akurat, dan sesuai dengan kebutuhan sistem. Dengan demikian, pengujian ini membantu memastikan bahwa sistem dapat berkomunikasi dengan server dan layanan eksternal, yaitu API BMKG, Cloudinary, dan Turso, dengan baik. Hasil tersebut juga digunakan untuk mengevaluasi keandalan dan kinerja komunikasi sistem.

3. Black Box Testing

Black box testing merupakan proses pengujian fungsionalitas eksternal sistem dari sudut pandang pengguna akhir. Pengujian ini tidak memerlukan pengetahuan mengenai struktur internal atau implementasi sistem. Fokus pengujian terletak pada perilaku sistem yang dapat dilihat dan dialami oleh pengguna.

Tim menguji hasil pencatatan inventaris, hasil deteksi hama, rekomendasi perawatan, dan keluaran lain yang dapat dilihat oleh pengguna. Pengujian dilakukan pada setiap fitur utama yang tercantum dalam Business Requirements, yaitu manajemen akun, inventaris, penyemaian, pertumbuhan dan meja tanam, panen, penjualan, deteksi hama, serta rekomendasi cuaca.

Setiap fitur diuji menggunakan skenario input yang valid dan tidak valid. Hasil pengujian kemudian digunakan untuk memastikan bahwa sistem memberikan respons sesuai dengan kebutuhan pengguna dan memenuhi kebutuhan fungsional yang telah ditentukan.

4. Model Evaluation Testing

Model evaluation testing dilakukan untuk mengukur performa model YOLO dalam mendeteksi tiga jenis hama awal, yaitu thrips, whitefly, dan aphids. Pengujian ini diperlukan karena kemampuan model dalam mendeteksi hama merupakan salah satu fungsi utama HidroSense. Pengujian dilakukan sebelum model digunakan dalam aplikasi produksi. 

Pengujian model mencakup beberapa tahapan sebagai berikut:

* Tim membagi dataset menjadi data latih (training) dan data uji (testing) yang terpisah. Pembagian tersebut dilakukan untuk memastikan bahwa model dapat diuji menggunakan data yang tidak digunakan selama proses pelatihan.  
* Tim mengukur metrik deteksi objek, yaitu precision, recall, F1-score, dan mAP (mean Average Precision). Metrik tersebut digunakan untuk mengukur kemampuan model dalam mengenali dan melokalisasi hama pada gambar.  
* Tim membandingkan performa model dengan baseline berupa YOLO11n polos yang belum melalui proses fine-tuning. Perbandingan tersebut digunakan untuk mengetahui peningkatan performa yang dihasilkan setelah proses fine-tuning.  
* Tim menguji model menggunakan gambar dari kondisi nyata di lapangan. Pengujian tersebut digunakan untuk mengetahui kemampuan model dalam menghadapi kondisi pencahayaan dan sudut pengambilan gambar yang digunakan oleh mitra.  
* Tim mengukur kecepatan inferensi model ketika model berjalan secara lokal pada perangkat mobile. Pengukuran tersebut digunakan untuk mengetahui apakah model dapat memenuhi target response time yang ditetapkan pada bagian 2.4, yaitu kurang dari 5 detik per gambar pada perangkat dengan spesifikasi standar.

4. # **Requirement** {#requirement-1}

Supporting Information memuat dokumen dan rancangan pendukung pengembangan HidroSense. Bagian ini memperjelas prioritas kebutuhan, ruang lingkup, jadwal, dan pembagian pekerjaan. Tim menggunakan informasi tersebut untuk menyelaraskan pelaksanaan pengembangan dengan bagian Introduction, Requirement, dan Verification.

HidroSense mendukung pengelolaan budidaya selada hidroponik NFT pada usaha Hidro Selada milik Bapak Agus di Ambulu, Kabupaten Jember. Aplikasi ini mengintegrasikan pencatatan budidaya, deteksi hama secara lokal, dan rekomendasi perawatan. Hasil deteksi serta rekomendasi menjadi informasi pendukung bagi petani dalam menentukan tindakan.

Dokumen dan rancangan yang mendukung pengembangan HidroSense meliputi:

1. System Request.  
2. Product Backlog dan user story.  
3. Project Charter.	  
4. Gantt Chart.  
5. Work Breakdown Structure.  
6. Analisis kebutuhan sistem.  
7. Rancangan proses bisnis.  
8. Use Case Diagram.  
9. Entity Relationship Diagram dan struktur tabel.  
10. Activity Diagram.  
11. Sequence Diagram.  
12. Class Diagram.  
13. Rancangan antarmuka.  
14. Software Testing Plan.  
15. Software Testing Report.  
16. Flowchart AI.

Bagian berikut merinci Product Backlog, Project Charter, jadwal, dan WBS. Gantt Chart, Class Diagram, dan Flowchart AI disediakan sebagai placeholder untuk dilengkapi dengan gambar.

1. ## **PRODUCT BACKLOG** {#product-backlog}

| Informasi | Keterangan |
| ----- | ----- |
| **Project Name** | HidroSense: Sistem Manajemen Budidaya Selada Hidroponik NFT dengan Deteksi Hama Menggunakan YOLO dan Rekomendasi Perawatan Berbasis Mobile  |
| **Team** | Kelompok A9  |
| **Project Work Period** | 19 Agustus–28 November 2026  |
| **Prepared by** | Aditya Dwi Ferdiansyah |
| **Product Goal** | Membantu mitra mencatat kegiatan budidaya, mendeteksi hama, dan menentukan tindakan perawatan melalui satu aplikasi.  |

Product Backlog memuat kebutuhan produk yang diurutkan berdasarkan manfaat, ketergantungan, dan risiko. Product Owner mengelola prioritas, sedangkan Development Team memperkirakan pekerjaan sesuai kapasitas. Tim menguraikan kelompok fitur menjadi pekerjaan yang dapat diselesaikan pada setiap sprint.

1. ### **Priority**

Prioritas berikut menunjukkan urutan perhatian dalam pengembangan. Seluruh fitur tetap menjadi bagian dari target penyelesaian pada 28 November 2026\.

1. #### **Prioritas Tinggi**

| ID | Fitur | Fungsi | Tujuan |
| :---- | :---- | :---- | :---- |
| PB-01 | Autentikasi dan hak akses | Memvalidasi kredensial serta membatasi akses petani dan pegawai.  | Menjaga akses sesuai kewenangan pengguna.  |
| PB-02  | Inventaris dan transaksi stok  | Mengelola barang, transaksi masuk dan keluar, serta saldo stok.  | Memudahkan pemantauan ketersediaan dan penggunaan bahan.  |
| PB-03  | Penyemaian bibit  | Mencatat tanggal semai, jumlah benih, dan status penyemaian.  | Menyediakan data awal siklus budidaya.  |
| PB-04  | Pertumbuhan dan meja tanam  | Mengelola meja, pemindahan, kapasitas, dan kerusakan tanaman.  | Mendukung pemanfaatan 3.000 lubang pada 12 meja tanam.  |
| PB-05  | Deteksi hama  | Mendeteksi thrips, whitefly, dan aphids dari gambar secara lokal.  | Membantu petani mengenali hama pada selada.  |
| PB-06  | Rekomendasi dan pencatatan perawatan  | Menyusun rekomendasi, mencatat keputusan petani, dan menyimpan tindakan aktual.  | Mendukung penanganan hama dan penelusuran riwayat perawatan.  |
| PB-07  | Penyimpanan lokal dan sinkronisasi  | Menyimpan data pada perangkat dan menyinkronkannya ketika koneksi tersedia.  | Mendukung pencatatan saat perangkat tidak terhubung ke internet.  |

2. #### **Prioritas Sedang**

| ID | Fitur | Fungsi | Tujuan |
| :---- | :---- | :---- | :---- |
| PB-08  | Pencatatan panen  | Mencatat jumlah tanaman dan berat panen berdasarkan batch.  | Menyediakan informasi hasil produksi.  |
| PB-09  | Pencatatan penjualan  | Mencatat berat terjual dan harga per kilogram.  | Memudahkan pemantauan penjualan hasil panen.  |
| PB-10  | Rekomendasi perawatan berdasarkan cuaca  | Mencocokkan data BMKG dengan aturan perawatan.  | Membantu petani mempertimbangkan cuaca dalam perawatan tanaman.  |
| PB-11  | Pengelolaan data akun  | Menampilkan dan memperbarui data akun sesuai kewenangan.  | Menjaga ketepatan data pengguna.  |

   2. ### **Backlog Fitur**

| Fitur | User Story | Requirement dan Kriteria Penerimaan |
| ----- | ----- | ----- |
| PB-01: Autentikasi dan Hak Akses  | Title: Mengakses aplikasi sesuai peran. Actor: Petani dan pegawai.  Scenario: Pengguna memasukkan username dan password. Sistem memvalidasi kredensial. Sistem menampilkan halaman utama sesuai peran. Pengguna mengakses fitur yang menjadi kewenangannya. | Sistem memberikan akses apabila kredensial valid. Sistem menampilkan pesan kesalahan untuk isian kosong atau kredensial tidak valid. Sistem membatasi akses pegawai pada inventaris, penyemaian, serta pertumbuhan dan meja tanam. Sistem menerapkan pembatasan pada antarmuka dan pemrosesan data. Tim menetapkan dan menguji aturan sesi luring pada sprint pertama. |
| PB-02: Inventaris dan Transaksi Stok  | Title: Mengelola barang dan pergerakan stok. Actor: Petani dan pegawai.  Scenario: Pengguna membuka menu Inventaris. Sistem menampilkan data barang dan saldo stok. Pengguna menambah, mengubah, atau menonaktifkan barang. Pengguna mencatat penerimaan atau penggunaan bahan. Sistem menyimpan transaksi dan memperbarui saldo. | Sistem menyimpan nama barang, jenis, satuan, stok minimum, dan status aktif. Sistem menghitung saldo dari transaksi masuk dan keluar. Sistem mencatat penggunaan bahan tanpa menghasilkan transaksi ganda. Sistem menolak jumlah tidak valid dan penggunaan yang melebihi stok tersedia. Sistem mempertahankan riwayat transaksi ketika barang dinonaktifkan. |
| PB-03: Penyemaian Bibit | Title: Mencatat dan memantau penyemaian.  Actor: Petani dan pegawai.  Scenario: Pengguna memasukkan tanggal semai dan jumlah benih. Sistem menyimpan data penyemaian. Pengguna melihat usia bibit dan memperbarui status. Pengguna memilih data penyemaian sebagai asal pemindahan tanaman. | Sistem menyimpan tanggal semai, jumlah benih, dan status penyemaian. Sistem menerima jumlah benih berupa bilangan positif. Sistem menghitung usia bibit berdasarkan tanggal semai. Sistem menjaga konsistensi jumlah bibit yang telah dipindahkan ketika data berubah. |
| PB-04: Pertumbuhan dan Meja Tanam  | Title: Mengelola pemindahan dan perkembangan tanaman.  Actor: Petani dan pegawai.  Scenario: Pengguna memilih penyemaian asal dan meja tujuan. Pengguna memasukkan tanggal serta jumlah pemindahan. Sistem memeriksa ketersediaan bibit dan kapasitas meja. Sistem menyimpan pemindahan sebagai acuan batch tanaman. Pengguna mencatat kerusakan tanaman dan memperbarui status meja. | Sistem menghubungkan pemindahan dengan penyemaian dan meja tujuan. Sistem menolak pemindahan yang melebihi bibit tersedia atau kapasitas meja. Sistem menghubungkan kerusakan dengan batch yang terdampak. Sistem menolak jumlah kerusakan yang melebihi tanaman aktif. Sistem memperbarui jumlah tanaman dan kapasitas berdasarkan pemindahan, pengurangan tanaman, serta panen. Pengguna memperbarui status fisik meja secara manual. |
| PB-05: Deteksi Hama  | Title: Mendeteksi hama dari gambar tanaman. Actor: Petani.  Scenario: Petani memilih batch tanaman. Petani mengambil gambar melalui kamera atau memilih gambar dari galeri. Petani menjalankan deteksi. Sistem memproses gambar menggunakan YOLO berformat TensorFlow Lite. Sistem menampilkan dan menyimpan hasil deteksi. | Sistem menjalankan inferensi secara lokal tanpa koneksi internet. Model mendukung thrips, whitefly, dan aphids. Sistem menampilkan kelas hama dan tingkat keyakinan serta menghubungkannya dengan batch. Sistem menangani gambar tidak valid, kegagalan pemrosesan, dan hasil tanpa deteksi yang memenuhi ambang. Sistem tidak menyatakan tanaman bebas hama hanya karena model tidak menemukan objek. Tim menguji target inferensi kurang dari 5 detik per gambar pada perangkat sasaran. Tim mengevaluasi model menggunakan precision, recall, F1-score, dan mAP pada data uji terpisah. |
| PB-06: Rekomendasi dan Pencatatan Perawatan  | Title: Meninjau rekomendasi dan mencatat tindakan perawatan. Actor: Petani.  Scenario: Sistem membaca hasil deteksi dan riwayat penggunaan obat pada batch. Sistem menerapkan aturan rekomendasi dan rotasi golongan bahan aktif. Sistem menampilkan rekomendasi dengan status menunggu keputusan. Petani menerima atau menolak rekomendasi. Petani mencatat tindakan yang dilakukan. | Sistem menghubungkan rekomendasi dengan hasil deteksi dan aturan yang digunakan. Sistem menyimpan keputusan petani serta alasan penolakan apabila diisi. Sistem membedakan penerimaan rekomendasi dari pelaksanaan perawatan. Sistem membentuk riwayat penggunaan obat dari tindakan aktual. Sistem mengurangi stok berdasarkan jumlah bahan yang digunakan. Sistem menampilkan keterangan apabila rekomendasi yang sesuai belum tersedia. |
| PB-07: Penyimpanan Lokal dan Sinkronisasi  | Title: Mencatat data secara luring dan menyinkronkannya. Actor: Petani dan pegawai sesuai hak akses. Scenario: Pengguna mencatat kegiatan budidaya. Sistem menyimpan data pada SQLite. Sistem menandai perubahan yang belum tersinkronisasi. Sistem mengirim perubahan melalui backend ketika koneksi tersedia. Sistem memperbarui status atau mengulangi pengiriman apabila gagal. | Data tersimpan tetap tersedia setelah aplikasi dibuka kembali. Pengiriman ulang tidak menghasilkan transaksi ganda. Kegagalan sinkronisasi tidak menghapus data lokal. Sistem menangani perubahan dari beberapa perangkat berdasarkan aturan konflik yang terdokumentasi. Tim menguji target sinkronisasi kurang dari 1 menit dengan kondisi koneksi dan volume data yang ditetapkan. |
| PB-08: Pencatatan Panen  | Title: Mencatat hasil panen berdasarkan batch. Actor: Petani. Scenario: Petani memilih batch yang dipanen. Petani memasukkan tanggal, jumlah tanaman, dan berat hasil. Sistem memvalidasi dan menyimpan data. Sistem memperbarui jumlah tanaman aktif serta kapasitas meja. | Sistem menghubungkan panen dengan data pemindahan. Sistem menolak jumlah panen yang melebihi tanaman aktif. Sistem menyimpan berat panen secara terpisah dari harga jual. Sistem menjaga konsistensi tanaman dan penjualan terkait ketika data panen berubah. |
| PB-09: Pencatatan Penjualan  | Title: Mencatat penjualan hasil panen.  Actor: Petani. Scenario: Petani memilih data panen. Petani memasukkan tanggal penjualan, berat terjual, dan harga per kilogram. Sistem memvalidasi serta menyimpan transaksi. Sistem menampilkan nilai penjualan. | Sistem menghubungkan penjualan dengan hasil panen. Sistem menolak berat terjual yang melebihi hasil panen tersedia. Sistem menghitung nilai penjualan dari berat terjual dikalikan harga per kilogram. Sistem menolak nilai berat atau harga yang tidak valid. |
| PB-10: Rekomendasi Perawatan Berdasarkan Cuaca  | Title: Melihat cuaca dan rekomendasi perawatan.   Actor: Petani. Layanan Eksternal: API BMKG Scenario: Petani membuka menu Cuaca. Sistem mengambil data untuk lokasi mitra. Sistem memvalidasi data dan mencocokkannya dengan aturan perawatan. Sistem menampilkan informasi cuaca serta rekomendasi. Sistem menampilkan status ketidaktersediaan apabila pengambilan data gagal. | Sistem menampilkan lokasi dan waktu prakiraan. Sistem menggunakan parameter yang tersedia pada respons API. Tim memastikan ketersediaan curah hujan numerik sebelum menggunakannya dalam aturan. Sistem tidak menyimpan data cuaca sebagai riwayat historis. Kegagalan layanan cuaca tidak menghambat pencatatan atau deteksi lokal. Sistem ditargetkan menyelesaikan pencocokan aturan kurang dari 2 detik setelah menerima data valid. |
| PB-11: Pengelolaan Data Akun  | Title: Melihat dan memperbarui data akun. Actor: Petani. Scenario: Petani membuka halaman akun. Sistem menampilkan data yang dapat diakses. Petani mengubah data yang diizinkan. Sistem memvalidasi dan menyimpan perubahan. | Sistem membatasi akses data akun sesuai kewenangan. Sistem menolak isian tidak valid. Sistem mencegah peningkatan hak akses melalui perubahan profil. Tim menetapkan rincian kewenangan pengelolaan akun pada sprint pertama. |

      3. ### **Kriteria Penyelesaian Backlog**

Tim menyatakan item backlog selesai apabila seluruh kriteria berikut terpenuhi: 

1. Implementasi memenuhi kebutuhan dan kriteria penerimaan.  
2. Kode telah ditinjau dan diintegrasikan.  
3. Pengujian yang relevan telah lulus.  
4. Tidak terdapat cacat terbuka yang menghambat alur utama, melanggar hak akses, atau menyebabkan kehilangan data.  
5. Dokumentasi dan bukti pengujian telah diperbarui.

Kriteria tersebut menjadi Definition of Done yang digunakan bersama. Tim merencanakan kembali item yang belum memenuhinya melalui Product Backlog.

2. ## **PROJECT CHARTER** {#project-charter}

   1. ### **General Project Charter**

| Komponen | Keterangan |
| ----- | ----- |
| **Judul proyek**  | HidroSense: Sistem Manajemen Budidaya Selada Hidroponik NFT dengan Deteksi Hama Menggunakan YOLO dan Rekomendasi Perawatan Berbasis Mobile  |
| **Tim pelaksana**  | Kelompok A9  |
| **Mitra**  | Hidro Selada milik Bapak Agus  |
| **Lokasi**  | Ambulu, Kabupaten Jember  |
| **Tanggal mulai**  | 19 Agustus 2026  |
| **Tahap awal, termasuk wawancara**  | 19–30 Agustus 2026  |
| **Pelaksanaan sprint** | 31 Agustus–28 November 2026  |
| **Target penyelesaian produk**  | 28 November 2026  |
| **Metode pengembangan**  | Pendekatan Agile dengan kerangka kerja Scrum  |
| **Jumlah sprint**  | Empat sprint  |
| **Platform utama**  | Android menggunakan Flutter  |
| **Hasil utama** | Aplikasi, backend, basis data, model deteksi, dokumentasi, dan laporan pengujian  |

      2. ### **Project Team**

| Nama | NIM | Posisi | Tanggung Jawab |
| ----- | ----- | ----- | ----- |
| Aditya Dwi Ferdiansyah  | 242410103030  | Scrum Master dan DT, Backend Developer  | Memfasilitasi Scrum, membantu penyelesaian hambatan, serta mengembangkan backend dan integrasi data.  |
| Siti Raudatul Jannah  | 242410103048  | Product Owner, Analyst  | Menggali kebutuhan mitra, mengelola prioritas, dan meninjau kesesuaian hasil dengan kebutuhan produk.  |
| Fakhrian Iqbal Zulkarnain  | 242410103060  | DT, UI/UX Designer  | Merancang alur interaksi, antarmuka, dan prototipe.  |
| Mochammad Wildan Alqori'in  | 242410103063  | DT, Frontend Developer  | Mengembangkan aplikasi Flutter dan mengintegrasikan data serta inferensi lokal.  |
| Achmad Nuhan T.  | 242410103011  | DT, Tester  | Menyusun pengujian, mendokumentasikan temuan, dan memverifikasi perbaikan.  |

Development Team mengerjakan pengembangan model AI secara bersama. Tim menetapkan penanggung jawab teknis pada awal sprint pertama. Pembagian peran tetap memungkinkan anggota saling membantu untuk menyelesaikan tujuan sprint.

3. ### **Project Scope Statement**

| Komponen | Uraian |
| ----- | ----- |
| **Tujuan** | Mempermudah pencatatan budidaya, menelusuri riwayat batch, membantu identifikasi hama, dan menyediakan rekomendasi perawatan.  |
| **Cakupan operasional** | Inventaris, stok, penyemaian, meja tanam, pemindahan, kerusakan, panen, dan penjualan.  |
| **Cakupan deteksi** | Deteksi thrips, whitefly, dan aphids melalui kamera atau galeri menggunakan YOLO secara lokal.  |
| **Cakupan rekomendasi** | Rekomendasi obat berdasarkan hasil deteksi dan riwayat penggunaan serta rekomendasi cuaca berbasis aturan.  |
| **Cakupan data** | Penyimpanan lokal SQLite, sinkronisasi ke Turso melalui backend, dan penyimpanan gambar melalui Cloudinary.  |
| **Batasan**  | Produk awal berjalan pada Android dan berfokus pada selada hidroponik NFT. Pengguna memperbarui status fisik meja secara manual.  |
| **Di luar cakupan**  | Aplikasi iOS, sensor otomatis, pengendalian perangkat hidroponik, dan pelaksanaan perawatan otomatis.  |
| **Ketergantungan**  | Dataset berlabel, perangkat uji, akses mitra, aturan perawatan yang tervalidasi, dan layanan eksternal.  |
| **Pendekatan**  | Wawancara, observasi, pengembangan bertahap, pengujian setiap sprint, dan evaluasi bersama mitra.  |

Tim memilih Node.js atau FastAPI sebagai backend pada sprint pertama. Pemilihan mempertimbangkan kebutuhan integrasi dan kemampuan tim. Proses unggah gambar berlangsung ketika koneksi tersedia sehingga tidak menghambat inferensi lokal.

4. ### **Rencana Waktu dan Target Sprint**

Tahap awal berlangsung pada 19–30 Agustus 2026 dan mencakup wawancara. Tim kemudian melaksanakan empat sprint sampai 28 November 2026\. Setiap sprint mencakup analisis, perancangan, implementasi, dan pengujian sesuai fitur yang dikerjakan.

| Tahap | Periode | Target hasil |
| ----- | ----- | ----- |
| Tahap awal | 19–30 Agustus 2026  | Hasil wawancara, kebutuhan awal, ruang lingkup, dan rencana pengembangan.  |
| Sprint 1: Fondasi dan pencatatan awal  | 31 Agustus–22 September 2026  | Autentikasi, inventaris, stok, penyemaian, penyimpanan lokal, sinkronisasi awal, dan pemeriksaan kelayakan AI.  |
| Sprint 2: Budidaya dan deteksi hama  | 23 September–15 Oktober 2026  | Meja tanam, pemindahan, kerusakan tanaman, dan deteksi hama yang terhubung dengan batch.  |
| Sprint 3: Perawatan dan penyelesaian siklus usaha  | 16 Oktober–7 November 2026  | Rekomendasi, perawatan, panen, penjualan, cuaca, dan profil yang terintegrasi.  |
| Sprint 4: Penyempurnaan dan penyerahan  | 8–28 November 2026  | Penyempurnaan, evaluasi akhir, uji lapangan, dokumentasi, dan penyerahan produk.  |

Tim memulai pengumpulan data dan pemeriksaan model sejak sprint pertama. Langkah ini membantu tim mengetahui kendala AI sebelum integrasi fitur deteksi. Pengujian dilakukan selama pengembangan, sedangkan sprint terakhir berfokus pada penyempurnaan dan kesiapan penyerahan.

5. ### **Kriteria Keberhasilan Proyek**

Proyek memenuhi target apabila:

1. Fitur dalam ruang lingkup memenuhi kriteria penerimaan.  
2. Sistem menerapkan hak akses secara konsisten.  
3. Pencatatan luring dan deteksi lokal berjalan pada perangkat sasaran.  
4. Sinkronisasi lulus pengujian gangguan koneksi, pengiriman ulang, dan konflik data.  
5. Tim memverifikasi target kinerja sesuai tabel berikut.  
6. Model memenuhi ambang evaluasi yang disepakati sebelum pengujian akhir.  
7. Tim menyelesaikan usability testing dan memperbaiki temuan yang menghambat penggunaan.  
8. Tim menyerahkan produk serta dokumentasi paling lambat 28 November 2026\.

| Aspek | Target Awal |
| ----- | ----- |
| **Pemuatan halaman utama**  | Kurang dari 3 detik  |
| **Inferensi lokal**  | Kurang dari 5 detik per gambar  |
| **Sinkronisasi**  | Kurang dari 1 menit setelah koneksi tersedia pada kondisi uji yang ditetapkan  |
| **Pencocokan aturan cuaca**  | Kurang dari 2 detik setelah data valid diterima  |

Tim mencatat perangkat, volume data, dan kondisi koneksi dalam laporan pengujian. Jika hasil evaluasi mengharuskan perubahan target, tim mendokumentasikan penyesuaiannya bersama Product Owner.

6. ### **Risiko dan Penanganan**

| Risiko | Dampak | Penanganan |
| ----- | ----- | ----- |
| Dataset terbatas atau tidak seimbang  | Kualitas deteksi rendah pada kelas tertentu.  | Tim mengumpulkan data sejak awal, memeriksa anotasi, dan mengevaluasi setiap kelas.  |
| Inferensi lambat  | Target waktu deteksi tidak tercapai.  | Tim menguji model pada perangkat sasaran sejak awal.  |
| Koneksi tidak stabil  | Sinkronisasi dan akses cuaca tertunda.  | Sistem menggunakan penyimpanan lokal dan pengulangan pengiriman.  |
| Perubahan dari beberapa perangkat  | Data stok atau tanaman tidak konsisten.  | Tim menerapkan identitas transaksi unik dan aturan konflik.  |
| Aturan perawatan belum tervalidasi  | Rekomendasi kurang sesuai.  | Tim meninjau aturan bersama mitra dan sumber agronomi yang dapat dipertanggungjawabkan.  |
| Pekerjaan melebihi kapasitas  | Penyelesaian terlambat.  | Tim memperinci pekerjaan dan menilai perubahan cakupan bersama Product Owner.  |

   3. ## **GANTT CHART** {#gantt-chart}

Ntar disini ye

4. ## **WORK BREAKDOWN STRUCTURE (WBS)** {#work-breakdown-structure-(wbs)}

WBS menguraikan pekerjaan HidroSense menjadi bagian yang dapat dikelola dan diperiksa. WBS by Activity menunjukkan aktivitas tim, sedangkan WBS by Product menunjukkan hasil pengembangan. Kedua bentuk tersebut menggambarkan ruang lingkup yang sama dari sudut pandang berbeda.

1. ### **WBS BY ACTIVITY**

| HidroSense: Sistem Manajemen Budidaya Selada Hidroponik NFT dengan Deteksi Hama dan Rekomendasi Perawatan berdasarkan Cuaca Menggunakan YOLO berbasis Mobile |  |
| :---: | :---- |
| Periode: 19–30 Agustus 2026  |  |
| 1\. | **Identifikasi dan Perancangan Sistem** |
| 1.1 | Tim melakukan wawancara dan observasi kegiatan budidaya.  |
| 1.2 | Analyst mengidentifikasi masalah, kebutuhan pengguna, dan proses bisnis.  |
| 1.3 | Tim menetapkan tujuan, ruang lingkup, serta batasan produk.  |
| 1.4 | Tim menetapkan pendekatan pengembangan dan pembagian tanggung jawab.  |
| 1.5 | Analyst menyusun System Request dan draf SRS.  |
| 1.6 | Product Owner menyusun Product Backlog awal bersama tim.  |
| 1.7 | Tim menyusun Project Charter, WBS, dan jadwal.  |
| 1.8 | Tim menyusun rancangan awal proses bisnis dan Use Case Diagram.  |
| 1.9 | Tim menyusun rancangan awal ERD dan struktur tabel.  |
| 1.10 | Tim mengidentifikasi sumber dataset, perangkat uji, dan layanan eksternal.  |
| Periode:31 Agustus–22 September 2026 |  |
| **2\.** | **SPRINT 1: Fondasi Sistem dan Pencatatan Awal**  |
| **2.1** | **Analyst** |
| 2.1.1 | Analyst memperinci kebutuhan autentikasi, inventaris, stok, dan penyemaian.  |
| 2.1.2 | Analyst menyusun user story serta kriteria penerimaan.  |
| 2.1.3 | Analyst menetapkan matriks hak akses bersama Product Owner.  |
| 2.1.4 | Analyst memperinci aturan sesi luring dan sinkronisasi bersama Programmer.  |
| **2.2** | **Designer** |
| 2.2.1 | Designer menyusun Activity Diagram fitur sprint pertama.  |
| 2.2.2 | Designer menyusun Sequence Diagram bersama Programmer.  |
| 2.2.3 | Designer menyusun Class Diagram awal bersama tim.  |
| 2.2.4 | Designer merancang antarmuka login, inventaris, stok, dan penyemaian.  |
| **2.3** | **Programmer** |
| 2.3.1 | Programmer menyiapkan Flutter, backend, dan pengelolaan versi kode.  |
| 2.3.2 | Programmer mengimplementasikan autentikasi serta hak akses.  |
| 2.3.3 | Programmer mengimplementasikan inventaris, stok, dan penyemaian.  |
| 2.3.4 | Programmer mengimplementasikan SQLite dan sinkronisasi awal.  |
| 2.3.5 | Programmer menyiapkan dataset serta pedoman anotasi.  |
| 2.3.6 | Programmer memeriksa kelayakan inferensi TensorFlow Lite pada Android.  |
| 2.3.7 | Programmer melakukan code review dan memperbaiki implementasi.  |
| **2.4** | **Tester** |
| 2.4.1 | Tester menyusun Software Testing Plan.  |
| 2.4.2 | Tester menguji autentikasi, hak akses, inventaris, dan penyemaian.  |
| 2.4.3 | Tester menguji penyimpanan luring serta sinkronisasi awal.  |
| 2.4.4 | Tester mencatat hasil pemeriksaan model pada perangkat.  |
| 2.4.5 | Tester menguji ulang perbaikan dan menyusun Software Testing Report.  |
| **2.5** | **End** |
| 2.5.1 | Tim melaksanakan Sprint Review.  |
| 2.5.2 | Tim melaksanakan Sprint Retrospective.  |
| 2.5.3 | Product Owner memperbarui Product Backlog bersama tim.  |
| **Periode: 23 September–15 Oktober 2026** |  |
| **3\.** | **SPRINT 2: Pengelolaan Budidaya dan Deteksi Hama**  |
| **3.1** | **Analyst** |
| 3.1.1 | Analyst memperinci kebutuhan meja, pemindahan, dan kerusakan tanaman.  |
| 3.1.2 | Analyst menyusun user story serta kriteria penerimaan.  |
| 3.1.3 | Analyst memperinci aturan kapasitas meja dan jumlah tanaman aktif.  |
| 3.1.4 | Analyst menetapkan hubungan batch dengan hasil deteksi.  |
| 3.1.5 | Analyst memperinci respons untuk gambar tidak valid dan hasil tanpa deteksi.  |
| **3.2** | **Designer** |
| 3.2.1 | Designer menyusun Activity Diagram budidaya dan deteksi.  |
| 3.2.2 | Designer menyusun Sequence Diagram bersama Programmer.  |
| 3.2.3 | Designer memperbarui Class Diagram bersama tim.  |
| 3.2.4 | Designer merancang antarmuka meja, pemindahan, kerusakan, dan deteksi.  |
| 3.2.5 | Designer menyusun Flowchart AI bersama Programmer.  |
| **3.3** | **Programmer** |
| 3.3.1 | Programmer mengimplementasikan meja tanam dan pemindahan.  |
| 3.3.2 | Programmer mengimplementasikan kerusakan serta perhitungan tanaman aktif.  |
| 3.3.3 | Programmer menyelesaikan anotasi dan pembagian dataset.  |
| 3.3.4 | Programmer melatih model serta melakukan penyetelan menggunakan data validasi.  |
| 3.3.5 | Programmer mengonversi model ke TensorFlow Lite.  |
| 3.3.6 | Programmer mengintegrasikan kamera, galeri, dan inferensi lokal.  |
| 3.3.7 | Programmer menghubungkan hasil deteksi dengan batch dan penyimpanan data.  |
| 3.3.8 | Programmer melakukan code review dan memperbaiki implementasi.  |
| **3.4** | **Tester** |
| 3.4.1 | Tester menyusun Software Testing Plan untuk fitur sprint kedua.  |
| 3.4.2 | Tester menguji kapasitas meja dan konsistensi jumlah tanaman.  |
| 3.4.3 | Tester menguji input gambar, inferensi luring, dan kondisi gagal.  |
| 3.4.4 | Tester memeriksa kualitas deteksi sebelum dan sesudah konversi model.  |
| 3.4.5 | Tester mengukur waktu inferensi pada perangkat sasaran.  |
| 3.4.6 | Tester menguji ulang perbaikan dan menyusun Software Testing Report.  |
| **3.5** | **End** |
| 3.5.1 | Tim melaksanakan Sprint Review.  |
| 3.5.2 | Tim melaksanakan Sprint Retrospective.  |
| 3.5.3 | Product Owner memperbarui Product Backlog bersama tim.  |
| **Periode: 16 Oktober–7 November 2026** |  |
| **4\.** | **SPRINT 3: Perawatan, Panen, Penjualan, dan Cuaca** |
| **4.1** | **Analyst**  |
| 4.1.1 | Analyst memperinci aturan rekomendasi dan rotasi obat.  |
| 4.1.2 | Analyst memperinci keputusan petani serta pencatatan tindakan aktual.  |
| 4.1.3 | Analyst memperinci kebutuhan panen, penjualan, dan profil.  |
| 4.1.4 | Analyst memvalidasi kebutuhan parameter cuaca bersama Programmer.  |
| 4.1.5 | Analyst menyusun user story serta kriteria penerimaan.  |
| **4.2** | **Designer** |
| 4.2.1 | Designer menyusun Activity Diagram fitur sprint ketiga.  |
| 4.2.2 | Designer menyusun Sequence Diagram integrasi bersama Programmer.  |
| 4.2.3 | Designer memperbarui Class Diagram bersama tim.  |
| 4.2.4 | Designer merancang antarmuka perawatan, panen, penjualan, cuaca, dan profil.  |
| 4.2.5 | Designer melengkapi Flowchart AI dengan alur rekomendasi berbasis aturan.  |
| **4.3** | **Programmer** |
| 4.3.1 | Programmer mengimplementasikan rekomendasi dan keputusan petani.  |
| 4.3.2 | Programmer mengimplementasikan perawatan serta riwayat penggunaan obat.  |
| 4.3.3 | Programmer menghubungkan pemakaian bahan dengan stok.  |
| 4.3.4 | Programmer mengimplementasikan panen dan penjualan.  |
| 4.3.5 | Programmer mengintegrasikan BMKG serta aturan perawatan cuaca.  |
| 4.3.6 | Programmer mengimplementasikan perubahan profil.  |
| 4.3.7 | Programmer melengkapi sinkronisasi dan penyimpanan gambar.  |
| 4.3.8 | Programmer menyempurnakan model berdasarkan data validasi.  |
| 4.3.9 | Programmer melakukan code review dan memperbaiki implementasi.  |
| **4.4** | **Tester** |
| 4.4.1 | Tester menyusun Software Testing Plan untuk fitur sprint ketiga. |
| 4.4.2 | Tester menguji rekomendasi, keputusan petani, dan perawatan aktual.  |
| 4.4.3 | Tester menguji konsistensi stok, tanaman, panen, dan penjualan.  |
| 4.4.4 | Tester menguji API pada kondisi normal dan gagal.  |
| 4.4.5 | Tester menguji perubahan profil sesuai kewenangan.  |
| 4.4.6 | Tester menguji alur penyemaian sampai penjualan.  |
| 4.4.7 | Tester menguji ulang perbaikan dan menyusun Software Testing Report.  |
| **4.5** | **End** |
| 4.5.1 | Tim melaksanakan Sprint Review.  |
| 4.5.2 | Tim melaksanakan Sprint Retrospective.  |
| 4.5.3 | Product Owner memperbarui Product Backlog bersama tim.  |
| 4.5.4 | Tim menetapkan prioritas penyempurnaan dan validasi lapangan.  |
| **Periode: 8–28 November 2026** |  |
| **5\.** | **SPRINT 4: Penyempurnaan dan Penyerahan Produk**  |
| **5.1** | **Analyst**  |
| 5.1.1 | Analyst meninjau kesesuaian implementasi dengan kebutuhan.  |
| 5.1.2 | Analyst memeriksa keterlacakan kebutuhan terhadap hasil pengujian.  |
| 5.1.3 | Analyst menyiapkan skenario validasi bersama mitra dan Tester.  |
| 5.1.4 | Analyst memperbarui SRS berdasarkan hasil yang disepakati.  |
| **5.2** | **Designer** |
| 5.2.1 | Designer meninjau konsistensi antarmuka.  |
| 5.2.2 | Designer memperbaiki rancangan berdasarkan hasil usability testing.  |
| 5.2.3 | Designer menyelaraskan diagram dengan implementasi akhir bersama tim.  |
| 5.2.4 | Designer menyiapkan materi visual panduan pengguna.  |
| **5.3** | **Programmer** |
| 5.3.1 | Programmer memperbaiki temuan fungsional dan integrasi.  |
| 5.3.2 | Programmer menyempurnakan pengiriman ulang serta penanganan konflik data.  |
| 5.3.3 | Programmer mengoptimalkan aplikasi dan model.  |
| 5.3.4 | Programmer menerapkan perbaikan antarmuka.  |
| 5.3.5 | Programmer melakukan code review akhir.  |
| 5.3.6 | Programmer menyiapkan paket aplikasi, backend, dan model.  |
| 5.3.7 | Programmer melengkapi dokumentasi teknis.  |
| **5.4** | **Tester** |
| 5.4.1 | Tester memperbarui Software Testing Plan untuk pengujian akhir.  |
| 5.4.2 | Tester melaksanakan black box testing dan API testing.  |
| 5.4.3 | Tester menguji hak akses, penggunaan luring, dan pemulihan koneksi.  |
| 5.4.4 | Tester menguji duplikasi serta konflik sinkronisasi.  |
| 5.4.5 | Tester mengukur kinerja aplikasi pada kondisi yang terdokumentasi.  |
| 5.4.6 | Tester mengevaluasi model akhir menggunakan data uji terpisah.  |
| 5.4.7 | Tester melaksanakan usability testing bersama mitra.  |
| 5.4.8 | Tester melakukan pengujian regresi setelah perbaikan.  |
| 5.4.9 | Tester memfinalisasi Software Testing Report.  |
| **5.5** | **End** |
| 5.5.1 | Tim melaksanakan Sprint Review akhir.  |
| 5.5.2 | Tim melaksanakan Sprint Retrospective.  |
| 5.5.3 | Tim memeriksa kriteria keberhasilan proyek.  |
| 5.5.4 | Tim memfinalisasi laporan dan panduan pengguna.  |
| 5.5.5 | Tim menyerahkan produk pada 28 November 2026\.  |
| 5.5.6 | Tim mencatat hasil penyerahan dan kebutuhan pengembangan lanjutan.  |

   5. ## **WORK BREAKDOWN STRUCTURE** {#work-breakdown-structure}

      1. ### **WBS BY PRODUCT**

| HidroSense: Sistem Manajemen Budidaya Selada Hidroponik NFT dengan Deteksi Hama dan Rekomendasi Perawatan berdasarkan Cuaca Menggunakan YOLO berbasis Mobile |  |
| :---: | :---- |
| **1\.** | **Petani** |
| **1.1** | **Akun**  |
| 1.1.1 | Login menggunakan username dan password.  |
| 1.1.2 | Akses fitur sesuai peran petani.  |
| 1.1.3 | Tampilan data akun.  |
| 1.1.4 | Perubahan data akun sesuai kewenangan.  |
| **1.2** | **Inventaris dan Stok** |
| 1.2.1 | Daftar inventaris dan saldo stok.  |
| 1.2.2 | Penambahan serta perubahan data barang.  |
| 1.2.3 | Penonaktifan barang.  |
| 1.2.4 | Transaksi stok masuk dan keluar.  |
| 1.2.5 | Riwayat penggunaan bahan.  |
| **1.3** | **Penyemaian** |
| 1.3.1 | Pencatatan tanggal semai dan jumlah benih.  |
| 1.3.2 | Tampilan usia bibit serta status penyemaian.  |
| 1.3.3 | Perubahan data penyemaian.  |
| **1.4** | **Pertumbuhan dan Meja Tanam** |
| 1.4.1 | Data meja dan kapasitas lubang tanam.  |
| 1.4.2 | Perubahan status fisik meja.  |
| 1.4.3 | Pencatatan pemindahan dari penyemaian ke meja.  |
| 1.4.4 | Identitas batch tanaman.  |
| 1.4.5 | Pencatatan kerusakan tanaman.  |
| 1.4.6 | Informasi tanaman aktif dan kapasitas tersedia.  |
| **1.5** | **Deteksi Hama** |
| 1.5.1 | Pemilihan batch yang diperiksa.  |
| 1.5.2 | Pengambilan gambar melalui kamera.  |
| 1.5.3 | Pemilihan gambar dari galeri.  |
| 1.5.4 | Hasil deteksi dan tingkat keyakinan.  |
| 1.5.5 | Penyimpanan hasil yang terhubung dengan batch.  |
| 1.5.6 | Pesan kegagalan dan hasil tanpa deteksi.  |
| **1.6** | **Rekomendasi dan Perawatan** |
| 1.6.1 | Rekomendasi berdasarkan hasil deteksi dan riwayat obat.  |
| 1.6.2 | Status menunggu, diterima, atau ditolak.  |
| 1.6.3 | Alasan penolakan apabila diisi.  |
| 1.6.4 | Pencatatan tindakan aktual serta penggunaan bahan.  |
| 1.6.5 | Riwayat perawatan per batch.  |
| **1.7** | **Panen** |
| 1.7.1 | Pencatatan tanggal dan jumlah tanaman yang dipanen.  |
| 1.7.2 | Pencatatan berat hasil panen.  |
| 1.7.3 | Hubungan panen dengan batch.  |
| 1.7.4 | Pembaruan tanaman aktif dan kapasitas meja.  |
| **1.8** | **Penjualan** |
| 1.8.1 | Pemilihan hasil panen yang dijual.  |
| 1.8.2 | Pencatatan tanggal, berat terjual, dan harga per kilogram.  |
| 1.8.3 | Perhitungan nilai penjualan.  |
| 1.8.4 | Informasi sisa hasil panen.  |
| **1.9** | **Cuaca** |
| 1.9.1 | Informasi cuaca berdasarkan lokasi mitra.  |
| 1.9.2 | Waktu prakiraan.  |
| 1.9.3 | Rekomendasi perawatan berdasarkan aturan cuaca.  |
| 1.9.4 | Status ketidaktersediaan data.  |
| **2\.** | **Pegawai** |
| **2.1** | **Akun dan Akses** |
| 2.1.1 | Login menggunakan username dan password.  |
| 2.1.2 | Akses fitur sesuai peran pegawai.  |
| **2.2** | **Inventaris dan Stok** |
| 2.2.1 | Akses modul inventaris pada bagian 1.2 sesuai kewenangan pegawai.  |
| **2.3** | **Penyemaian** |
| 2.3.1 | Akses modul penyemaian pada bagian 1.3 sesuai kewenangan pegawai.  |
| **2.4** | **Pertumbuhan dan Meja Tanam**  |
| 2.4.1 | Akses modul pertumbuhan dan meja tanam pada bagian 1.4 sesuai kewenangan pegawai.  |
| **3\.** | **Komponen Sistem Bersama** |
| **3.1** | **Penyimpanan dan Sinkronisasi** |
| 3.1.1 | Basis data lokal SQLite.  |
| 3.1.2 | Basis data pusat Turso.  |
| 3.1.3 | Backend untuk proses bisnis dan komunikasi data.  |
| 3.1.4 | Antrean serta status sinkronisasi.  |
| 3.1.5 | Pengiriman ulang tanpa duplikasi.  |
| 3.1.6 | Penanganan konflik perubahan data.  |
| 3.1.7 | Integrasi penyimpanan gambar Cloudinary.  |
| **3.2** | **Model Deteksi Hama** |
| 3.2.1 | Dataset dan anotasi thrips, whitefly, serta aphids.  |
| 3.2.2 | Pembagian data latih, validasi, dan uji.  |
| 3.2.3 | Konfigurasi pelatihan serta catatan eksperimen.  |
| 3.2.4 | Model YOLO hasil pelatihan.  |
| 3.2.5 | Model TensorFlow Lite.  |
| 3.2.6 | Komponen prapemrosesan, inferensi, dan pengolahan hasil.  |
| **3.3** | **Aturan Rekomendasi** |
| 3.3.1 | Aturan penanganan berdasarkan jenis hama.  |
| 3.3.2 | Aturan rotasi golongan bahan aktif.  |
| 3.3.3 | Aturan perawatan berdasarkan parameter cuaca.  |
| 3.3.4 | Pemetaan data API BMKG ke aturan cuaca.  |
| **4\.** | **Dokumentasi dan Paket Penyerahan** |
| **4.1** | **Dokumentasi Perencanaan dan Rancangan** |
| 4.1.1 | System Request dan SRS.  |
| 4.1.2 | Product Backlog dan Project Charter.  |
| 4.1.3 | Gantt Chart dan WBS.  |
| 4.1.4 | Rancangan basis data serta diagram sistem.  |
| 4.1.5 | Rancangan antarmuka.  |
| **4.2** | **Dokumentasi Pengujian** |
| 4.2.1 | Software Testing Plan.  |
| 4.2.2 | Software Testing Report.  |
| 4.2.3 | Hasil usability testing.  |
| 4.2.4 | Hasil evaluasi model dan kinerja perangkat.  |
| **4.3** | **Paket Produk** |
| 4.3.1 | Paket instalasi Android.  |
| 4.3.1 | Kode sumber aplikasi dan backend.  |
| 4.3.1 | Model deteksi beserta konfigurasi.  |
| 4.3.1 | Panduan pengguna dan dokumentasi teknis.  |
| 4.3.1 | Catatan versi serta penyerahan produk.  |

   6. ## **CLASS DIAGRAM** {#class-diagram}

   7. ## **FLOWCHART AI** {#flowchart-ai}

4. # **Overall Description** {#overall-description}

   1. ## **Product Perspective** {#product-perspective-1}

*\<Describe the context and origin of the product being specified in this SRS. For example, state whether this product is a follow-on member of a product family, a replacement for certain existing systems, or a new, self-contained product. If the SRS defines a component of a larger system, relate the requirements of the larger system to the functionality of this software and identify interfaces between the two. A simple diagram that shows the major components of the overall system, subsystem interconnections, and external interfaces can be helpful.\>*

2. ## **Product Functions** {#product-functions-1}

*\<Summarize the major functions the product must perform or must let the user perform. Details will be provided in Section 3, so only a high level summary (such as a bullet list) is needed here. Organize the functions to make them understandable to any reader of the SRS. A picture of the major groups of related requirements and how they relate, such as a top level data flow diagram or object class diagram, is often effective.\>*

3. ## **User Classes and Characteristics** {#user-classes-and-characteristics}

*\<Identify the various user classes that you anticipate will use this product. User classes may be differentiated based on frequency of use, subset of product functions used, technical expertise, security or privilege levels, educational level, or experience. Describe the pertinent characteristics of each user class. Certain requirements may pertain only to certain user classes. Distinguish the most important user classes for this product from those who are less important to satisfy.\>*

4. ## **Operating Environment** {#operating-environment}

*\<Describe the environment in which the software will operate, including the hardware platform, operating system and versions, and any other software components or applications with which it must peacefully coexist.\>*

5. ## **Design and Implementation Constraints** {#design-and-implementation-constraints}

*\<Describe any items or issues that will limit the options available to the developers. These might include: corporate or regulatory policies; hardware limitations (timing requirements, memory requirements); interfaces to other applications; specific technologies, tools, and databases to be used; parallel operations; language requirements; communications protocols; security considerations; design conventions or programming standards (for example, if the customer’s organization will be responsible for maintaining the delivered software).\>*

6. ## **User Documentation** {#user-documentation}

*\<List the user documentation components (such as user manuals, on-line help, and tutorials) that will be delivered along with the software. Identify any known user documentation delivery formats or standards.\>*

7. ## **Assumptions and Dependencies** {#assumptions-and-dependencies}

*\<List any assumed factors (as opposed to known facts) that could affect the requirements stated in the SRS. These could include third-party or commercial components that you plan to use, issues around the development or operating environment, or constraints. The project could be affected if these assumptions are incorrect, are not shared, or change. Also identify any dependencies the project has on external factors, such as software components that you intend to reuse from another project, unless they are already documented elsewhere (for example, in the vision and scope document or the project plan).\>*

5. # **External Interface Requirements** {#external-interface-requirements}

   1. ## **User Interfaces** {#user-interfaces-1}

*\<Describe the logical characteristics of each interface between the software product and the users. This may include sample screen images, any GUI standards or product family style guides that are to be followed, screen layout constraints, standard buttons and functions (e.g., help) that will appear on every screen, keyboard shortcuts, error message display standards, and so on. Define the software components for which a user interface is needed. Details of the user interface design should be documented in a separate user interface specification.\>*

2. ## **Hardware Interfaces** {#hardware-interfaces-1}

*\<Describe the logical and physical characteristics of each interface between the software product and the hardware components of the system. This may include the supported device types, the nature of the data and control interactions between the software and the hardware, and communication protocols to be used.\>*

3. ## **Software Interfaces** {#software-interfaces-1}

*\<Describe the connections between this product and other specific software components (name and version), including databases, operating systems, tools, libraries, and integrated commercial components. Identify the data items or messages coming into the system and going out and describe the purpose of each. Describe the services needed and the nature of communications. Refer to documents that describe detailed application programming interface protocols. Identify data that will be shared across software components. If the data sharing mechanism must be implemented in a specific way (for example, use of a global data area in a multitasking operating system), specify this as an implementation constraint.\>*

4. ## **Communications Interfaces** {#communications-interfaces}

*\<Describe the requirements associated with any communications functions required by this product, including e-mail, web browser, network server communications protocols, electronic forms, and so on. Define any pertinent message formatting. Identify any communication standards that will be used, such as FTP or HTTP. Specify any communication security or encryption issues, data transfer rates, and synchronization mechanisms.\>*

6. # **System Features** {#system-features}

*\<This template illustrates organizing the functional requirements for the product by system features, the major services provided by the product. You may prefer to organize this section by use case, mode of operation, user class, object class, functional hierarchy, or combinations of these, whatever makes the most logical sense for your product.\>*

1. ## **System Feature 1** {#system-feature-1}

*\<Don’t really say “System Feature 1.” State the feature name in just a few words.\>*

4.1.1	Description and Priority

*\<Provide a short description of the feature and indicate whether it is of High, Medium, or Low priority. You could also include specific priority component ratings, such as benefit, penalty, cost, and risk (each rated on a relative scale from a low of 1 to a high of 9).\>*

4.1.2	Stimulus/Response Sequences

*\<List the sequences of user actions and system responses that stimulate the behavior defined for this feature. These will correspond to the dialog elements associated with use cases.\>*

4.1.3	Functional Requirements

*\<Itemize the detailed functional requirements associated with this feature. These are the software capabilities that must be present in order for the user to carry out the services provided by the feature, or to execute the use case. Include how the product should respond to anticipated error conditions or invalid inputs. Requirements should be concise, complete, unambiguous, verifiable, and necessary. Use “TBD” as a placeholder to indicate when necessary information is not yet available.\>*

*\<Each requirement should be uniquely identified with a sequence number or a meaningful tag of some kind.\>*

REQ-1:	  
REQ-2:	

2. ## **System Feature 2 (and so on)** {#system-feature-2-(and-so-on)}

7. # **Other Nonfunctional Requirements** {#other-nonfunctional-requirements}

   1. ## **Performance Requirements** {#performance-requirements}

*\<If there are performance requirements for the product under various circumstances, state them here and explain their rationale, to help the developers understand the intent and make suitable design choices. Specify the timing relationships for real time systems. Make such requirements as specific as possible. You may need to state performance requirements for individual functional requirements or features.\>*

2. ## **Safety Requirements** {#safety-requirements}

*\<Specify those requirements that are concerned with possible loss, damage, or harm that could result from the use of the product. Define any safeguards or actions that must be taken, as well as actions that must be prevented. Refer to any external policies or regulations that state safety issues that affect the product’s design or use. Define any safety certifications that must be satisfied.\>*

3. ## **Security Requirements** {#security-requirements}

*\<Specify any requirements regarding security or privacy issues surrounding use of the product or protection of the data used or created by the product. Define any user identity authentication requirements. Refer to any external policies or regulations containing security issues that affect the product. Define any security or privacy certifications that must be satisfied.\>*

4. ## **Software Quality Attributes** {#software-quality-attributes}

*\<Specify any additional quality characteristics for the product that will be important to either the customers or the developers. Some to consider are: adaptability, availability, correctness, flexibility, interoperability, maintainability, portability, reliability, reusability, robustness, testability, and usability. Write these to be specific, quantitative, and verifiable when possible. At the least, clarify the relative preferences for various attributes, such as ease of use over ease of learning.\>*

5. ## **Business Rules** {#business-rules}

*\<List any operating principles about the product, such as which individuals or roles can perform which functions under specific circumstances. These are not functional requirements in themselves, but they may imply certain functional requirements to enforce the rules.\>*

8. # **Other Requirements** {#other-requirements}

*\<Define any other requirements not covered elsewhere in the SRS. This might include database requirements, internationalization requirements, legal requirements, reuse objectives for the project, and so on. Add any new sections that are pertinent to the project.\>*

**Appendix A: Glossary**

*\<Define all the terms necessary to properly interpret the SRS, including acronyms and abbreviations. You may wish to build a separate glossary that spans multiple projects or the entire organization, and just include terms specific to a single project in each SRS.\>*

**Appendix B: Analysis Models**

*\<Optionally, include any pertinent analysis models, such as data flow diagrams, class diagrams, state-transition diagrams, or entity-relationship diagrams*.\>

**Appendix C: To Be Determined List**

*\<Collect a numbered list of the TBD (to be determined) references that remain in the SRS so they can be tracked to closure.\>*

u

[image1]: <data:image/png;base64,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>

[image2]: <data:image/png;base64,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>

[image3]: <data:image/png;base64,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IYSIAZI2IYQQQogYIGkTQgghhIgBkjYhhBBCiBggaRNCCCGEiAGSNiGEEEKIGCBpE0IIIYSIAZI2IYQQQogYIGkTQgghhIgBkjYhhBBCiBggaRNCCCGEiAGSNiGEEEKIGCBpE0IIIYSIAZI2IYQQQogYIGkTQgghhIgBkjYhhBBCiBggaRNCCCGEiAGSNiGEEEKIGCBpE0IIIYSIAZI2IYQQQogYIGkTQgghhIgBkjYhhBBCiBggaRNCCCGEiAGSNiGEEEKIGCBpE0IIIYSIAZI2IYQQQogYIGkTQgghhIgBkjYhhBBCiBggaRNCCCGEiAGSNiGEEEKIGCBpE0IIIYSIAZI2IYQQQogYIGkTQgghhIgBkjYhhBBCiBggaRNCCCGEiAGSNiGEEEKIGCBpE0IIIYSIAZI2IYQQQogYIGkTQgghhIgBkjYhhBBCiBggaRNCCCGEiAGSNiGEEEKIGCBpE0IIIYSIAZI2IYQQQogYIGkTQgghhIgBkjYhhBBCiBggaRNCCCGEiAGSNiGEEEKIGCBpE0IIIYSIAZI2IYQQQogYIGkTQgghhIgBkjYhhBBCiBggaRNCCCGEiAGSNiGEEEKIGCBpE0IIIYSIAZI2IYQQQogYIGkTQgghhIgBkjYhhBBCiBggaRNCCCGEiAGSNiGEEEKIGCBpE0IIIYSIAZI2IYQQQogY8P8BfNYFIijHwf0AAAAASUVORK5CYII=>