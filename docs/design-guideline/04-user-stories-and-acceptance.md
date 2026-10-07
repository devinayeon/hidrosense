# Modul 04: Persona Pengguna & Cerita Pengguna (User Stories & Acceptance Criteria)

Dokumen ini mendefinisikan persona pengguna dan daftar cerita pengguna (*User Stories*) komprehensif untuk modul B000 hingga B009 pada aplikasi **HidroSense Mobile** lengkap dengan kriteria penerimaan (*Acceptance Criteria*) berbasis **Given-When-Then** dan kepatuhan **Apple Human Interface Guidelines (HIG)**.

---

## 1. Persona Pengguna

### Persona 1: Pak Budi — Pemilik Kebun (*Petani / Super Admin*)
- **Profil:** Pria, 45 tahun, pemilik kebun hidroponik komersial selada dan sayuran daun.
- **Karakteristik & Kebiasaan:**
  - Mengakses aplikasi dari smartphone dan tablet.
  - Menghargai gambaran holistik (*glanceable overview*): ingin tahu stok menipis, meja tanam aktif, dan proyeksi panen dalam $\le 10$ detik.
  - Membutuhkan ketenangan bahwa pencatatan barang dan buku besar stok tidak dapat dimanipulasi atau terhapus sembarangan.
- **Kebutuhan Utama (Needs):**
  - Dashboard eksekutif yang merangkum semua modul operasional.
  - Peringatan instan jika stok benih atau nutrisi di bawah ambang batas minimum.
  - Akses manajemen staf dan laporan hasil panen.

### Persona 2: Siti — Staf Lapangan (*Pegawai Kebun*)
- **Profil:** Wanita, 26 tahun, staf operasional harian di dalam greenhouse hidroponik.
- **Karakteristik & Kebiasaan:**
  - Sering mengoperasikan ponsel dengan satu tangan saat berkeliling meja tanam.
  - Berada di lingkungan semi-outdoor dengan intensitas cahaya matahari tinggi.
  - Membutuhkan input data yang sangat cepat dengan tombol besar dan feedback getar (*haptics*).
- **Kebutuhan Utama (Needs):**
  - Tombol aksi cepat (+ Barang, + Semai, Pindah Meja) yang mudah dijangkau ibu jari.
  - Validasi otomatis agar tidak perlu menghitung manual usia bibit atau sisa lubang meja tanam.
  - Notifikasi visual yang kontras saat bibit telah mencapai usia $\ge 15$ hari dan harus segera dipindahkan.

---

## 2. Daftar Cerita Pengguna (User Stories B000–B009)

---

### US-01: Autentikasi Pengguna & Penyesuaian Peran (B002)

> **Sebagai** Pak Budi (*Petani*) atau Siti (*Pegawai*),
> **Saya ingin** masuk ke aplikasi dengan akun saya yang terproteksi,
> **Sehingga** antarmuka aplikasi menampilkan menu dan hak akses yang sesuai dengan tanggung jawab saya.

#### Acceptance Criteria (Given - When - Then):
- **AC 1.1: Login Berhasil**
  - **Given:** Pengguna berada di layar login dan memasukkan username `petani` serta password `Petani123456!`.
  - **When:** Pengguna menekan tombol "Masuk".
  - **Then:** Sistem melakukan autentikasi ke backend, menyimpan access token di memori, mengarahkan pengguna ke Dashboard Utama, dan memicu haptic `mediumImpact`.
- **AC 1.2: Kredensial Salah**
  - **Given:** Pengguna memasukkan kata sandi yang salah.
  - **When:** Pengguna menekan tombol "Masuk".
  - **Then:** Input field menampilkan pesan error *"Username atau kata sandi tidak valid."*, kolom password dikosongkan kembali, dan ponsel bergetar dengan haptic peringatan.
- **AC 1.3: Penanganan Peran (Role-based Navigation)**
  - **Given:** Pengguna login sebagai `pegawai`.
  - **Then:** Menu manajemen akun pegawai disembunyikan, dan dashboard memprioritaskan kartu aksi operasional lapangan.

---

### US-02: Dasbor Ringkasan Budidaya & Peringatan Dini (B000, B007, B008)

> **Sebagai** Pak Budi (*Petani*),
> **Saya ingin** melihat ringkasan status kebun secara sekilas saat pertama kali membuka aplikasi,
> **Sehingga** saya dapat segera mengambil keputusan terkait semaian yang perlu dipindah atau stok yang kritis.

#### Acceptance Criteria:
- **AC 2.1: Kartu Peringatan Siap Pindah**
  - **Given:** Terdapat batch semaian yang mencapai usia $\ge 15$ hari.
  - **When:** Dashboard terbuka.
  - **Then:** Kartu peringatan oranye *"Semaian Siap Pindah"* tampil di urutan teratas dengan tombol aksi langsung *"Pindah ke Meja"*.
- **AC 2.2: Peringatan Cuaca BMKG**
  - **Given:** Terdeteksi prakiraan cuaca ekstrem (misal: Hujan Lebat atau Suhu Panas $>32^\circ\text{C}$).
  - **Then:** Kartu cuaca menampilkan rekomendasi teknis: *"Atur debit nutrisi meja NFT"*.
- **AC 2.3: Responsive Card Touch**
  - **Given:** Pengguna menekan salah satu kartu ringkasan.
  - **Then:** Kartu menyusut halus ke skala `0.985` dan membuka halaman rincian modul terkait.

---

### US-03: Pengecekan Saldo Inventaris & Ambang Batas Minimum (B005 & B006)

> **Sebagai** Siti (*Pegawai*),
> **Saya ingin** melihat saldo riil barang inventaris beserta status batas amannya,
> **Sehingga** persediaan benih dan nutrisi tidak pernah habis di tengah masa tanam.

#### Acceptance Criteria:
- **AC 3.1: Tampilan Saldo Tabular**
  - **Given:** Pengguna membuka tab *Inventaris*.
  - **When:** Daftar barang dimuat.
  - **Then:** Setiap barang menampilkan nama, satuan (`gram`, `liter`), dan jumlah stok aktual menggunakan angka tabular (*tabular numerals*) yang rapi.
- **AC 3.2: Badge Status Otomatis**
  - **Given:** Stok barang (misal: Nutrisi AB Mix) berada di bawah nilai `stok_minimum`.
  - **Then:** Kartu secara otomatis menampilkan badge kapsul oranye *"Stok Menipis"* dengan nilai batas minimum yang tertera jelas.
- **AC 3.3: Filter Kategori Cepat**
  - **Given:** Pengguna memilih chip kategori *"Benih"*.
  - **Then:** Daftar terfilter instan dengan transisi visual halus tanpa reload halaman penuh.

---

### US-04: Pencatatan Transaksi Stok Masuk ke Buku Besar Tertutup (B006)

> **Sebagai** Siti (*Pegawai*),
> **Saya ingin** mencatat barang yang baru dibeli ke dalam sistem,
> **Sehingga** stok bertambah secara otomatis dan tercatat permanen di buku besar (*Stock Ledger*).

#### Acceptance Criteria:
- **AC 4.1: Formulir Input Terpandu**
  - **Given:** Pengguna menekan tombol *"+ Barang"* di tab inventaris.
  - **When:** Modal sheet terbuka.
  - **Then:** Kolom input jumlah hanya menerima angka desimal/bulat positif dan unit satuan otomatis terkunci sesuai data master barang.
- **AC 4.2: Integritas Buku Besar (Sealed Ledger)**
  - **Given:** Data stok telah diisi lengkap.
  - **When:** Pengguna menekan *"Simpan Transaksi Stok"*.
  - **Then:** Transaksi disimpan dengan status `sealed = 1`, saldo di tabel `stok_saldo` diperbarui secara atomik, dan tombol simpan dinonaktifkan untuk mencegah klik ganda.

---

### US-05: Pendaftaran & Pelacakan Usia Batch Penyemaian (B007)

> **Sebagai** Siti (*Pegawai*),
> **Saya ingin** mendaftarkan batch semaian baru dan memantau usianya setiap hari,
> **Sehingga** saya tahu persis kapan bibit siap dipindahkan ke meja tanam tanpa mencatat manual di kertas.

#### Acceptance Criteria:
- **AC 5.1: Pendaftaran Batch Semai**
  - **Given:** Pengguna membuka form *"+ Semai"*.
  - **When:** Pengguna memasukkan tanggal semai, varietas benih, dan jumlah benih (misal: 600 butir).
  - **Then:** Sistem membuat batch baru dengan status `aktif` dan menghitung usia semai awal (HSS = Hari Setelah Semai).
- **AC 5.2: Indikator Progres Usia Semai**
  - **Given:** Batch semai telah berumur 10 hari.
  - **Then:** Kartu semai menampilkan progress bar terisi proporsional terhadap target 15 hari dengan warna hijau mint dan teks *"10 / 15 HSS"*.

---

### US-06: Monitoring Okupansi & Kapasitas Meja Tanam NFT (B008)

> **Sebagai** Pak Budi (*Petani*),
> **Saya ingin** melihat kapasitas total dan sisa lubang tanam di setiap meja NFT,
> **Sehingga** saya dapat merencanakan pemindahan bibit tanpa risiko kelebihan beban meja.

#### Acceptance Criteria:
- **AC 6.1: Visualisasi Okupansi Meja**
  - **Given:** Meja `M-01` memiliki kapasitas 250 lubang dan telah terisi 200 tanaman.
  - **Then:** Kartu meja menampilkan meter okupansi 80% dengan teks *"50 lubang tersisa"* dan badge status *"Tersedia"*.
- **AC 6.2: Penanganan Meja Rusak / Perbaikan**
  - **Given:** Meja `M-04` berstatus `perbaikan`.
  - **Then:** Kartu meja bernuansa netral/peringatan dan tidak dapat dipilih sebagai target pemindahan bibit baru.

---

### US-07: Pemindahan Bibit ke Meja Tanam & Estimasi Panen Baseline 45 Hari (B009)

> **Sebagai** Siti (*Pegawai*),
> **Saya ingin** memindahkan bibit yang berusia $\ge 15$ hari ke lubang meja tanam NFT yang tersedia,
> **Sehingga** sistem otomatis menghitung tanggal perkiraan panen berdasarkan standar 45 hari HidroSense.

#### Acceptance Criteria:
- **AC 7.1: Validasi Syarat Umur Bibit Minimum 15 Hari**
  - **Given:** Batch semaian baru berusia 12 hari ($<15$ hari).
  - **When:** Pengguna mencoba menekan tombol pemindahan.
  - **Then:** Tombol dinonaktifkan atau memunculkan pesan edukatif: *"Bibit baru berumur 12 HSS. Standar pemindahan adalah minimal 15 HSS."*
- **AC 7.2: Validasi Kapasitas Lubang Meja**
  - **Given:** Meja tujuan hanya memiliki 50 lubang tersisa, namun pengguna menginput 100 tanaman.
  - **When:** Pengguna menekan tombol simpan.
  - **Then:** Formulir memunculkan pesan validasi: *"Jumlah tanaman melebihi kapasitas lubang meja (tersedia 50 lubang)."*
- **AC 7.3: Kalkulasi Estimasi Panen 45 Hari Otomatis**
  - **Given:** Bibit disemai pada tanggal `2026-09-17` (berumur 20 hari) dan dipindahkan ke meja `M-01`.
  - **When:** Form pemindahan divalidasi.
  - **Then:** Sistem secara otomatis menampilkan tanggal estimasi panen: `Tanggal Semai + 45 hari` (yaitu `2026-11-01`), sisa bibit semai berkurang, dan okupansi meja `M-01` bertambah.

---

### US-08: Ketahanan Offline & Umpan Balik Status Sinkronisasi (B003 & B004)

> **Sebagai** Siti (*Pegawai*),
> **Saya ingin** aplikasi tetap dapat digunakan melihat data saat sinyal Wi-Fi di greenhouse lemah,
> **Sehingga** pekerjaan di lapangan tidak terhenti oleh gangguan koneksi internet sementara.

#### Acceptance Criteria:
- **AC 8.1: Tampilan Data dari Cache Lokal**
  - **Given:** Perangkat kehilangan koneksi jaringan.
  - **When:** Pengguna membuka tab *Inventaris* atau *Meja NFT*.
  - **Then:** Aplikasi menyajikan data cache lokal terakhir dengan banner halus di atas: *"Mode Offline — Data tersimpan secara lokal"*.
- **AC 8.2: Sinkronisasi Transparan saat Online Kembali**
  - **Given:** Koneksi jaringan pulih kembali.
  - **When:** Aplikasi melakukan sinkronisasi dengan endpoint `/api/v1/sync`.
  - **Then:** Banner offline menghilang otomatis tanpa mengganggu input yang sedang dilakukan pengguna.
