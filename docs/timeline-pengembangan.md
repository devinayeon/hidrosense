# Acuan Pengembangan HidroSense

Sumber utama: [A9_PPL IF_WEEK5.docx.md](./A9_PPL%20IF_WEEK5.docx.md), khususnya Product Backlog (baris 668–721), Project Charter (723–815), dan WBS (825–976). Tanggal sprint dan target berasal dari dokumen. Rincian urutan kerja di bawah adalah penjabaran untuk pelaksanaan, bukan kutipan jadwal harian resmi. Gantt Chart di sumber masih berupa placeholder.

## Konteks produk

HidroSense adalah aplikasi Android berbasis Flutter untuk mitra Hidro Selada di Ambulu, Jember. Aplikasi membantu pengelolaan selada hidroponik NFT dari inventaris, penyemaian, meja tanam, pemindahan, kerusakan, deteksi hama, perawatan, panen, hingga penjualan. Aktor manusia: petani dan pegawai; akses pegawai dibatasi pada inventaris, penyemaian, dan pertumbuhan/meja tanam. Deteksi awal mencakup thrips, whitefly, dan aphids memakai YOLO yang dikonversi ke TensorFlow Lite untuk inferensi lokal. Rekomendasi penanganan memakai hasil deteksi dan riwayat obat; rekomendasi cuaca memakai data BMKG dan aturan yang divalidasi. Data operasional disimpan di SQLite lalu disinkronkan melalui backend ke Turso. Gambar disimpan di Cloudinary saat koneksi tersedia. Status fisik meja diubah manual.

Di luar cakupan produk awal: iOS, sensor otomatis, kendali perangkat hidroponik, dan pelaksanaan perawatan otomatis. Rekomendasi adalah pendukung keputusan petani.

## Timeline resmi dan hasil tiap tahap

| Tahap | Tanggal | Backlog / pekerjaan | Hasil yang diperiksa pada akhir tahap |
| --- | --- | --- | --- |
| Tahap awal | 19–30 Agustus 2026 | Wawancara dan observasi, kebutuhan, ruang lingkup, System Request/SRS awal, backlog, charter, WBS, jadwal, rancangan proses/ERD, sumber dataset dan perangkat uji | Kebutuhan awal dan rancangan disepakati; ketergantungan eksternal teridentifikasi |
| Sprint 1: fondasi dan pencatatan awal | 31 Agustus–22 September 2026 | PB-01 autentikasi dan hak akses; PB-02 inventaris dan stok; PB-03 penyemaian; awal PB-07 SQLite dan sinkronisasi; kelayakan AI | Login dan pembatasan akses; transaksi stok dan penyemaian tervalidasi; data luring bertahan; sinkronisasi awal diuji; dataset/pedoman anotasi dan uji TFLite awal; review, retrospektif, laporan uji |
| Sprint 2: budidaya dan deteksi hama | 23 September–15 Oktober 2026 | PB-04 meja tanam, pemindahan, kerusakan; PB-05 deteksi hama; pelatihan dan konversi model | Kapasitas meja dan tanaman aktif konsisten; hasil deteksi lokal dari kamera/galeri tersimpan per batch; kasus gambar gagal/tanpa deteksi ditangani; mutu model dan waktu inferensi diukur; review, retrospektif, laporan uji |
| Sprint 3: perawatan dan siklus usaha | 16 Oktober–7 November 2026 | PB-06 rekomendasi dan tindakan aktual; PB-08 panen; PB-09 penjualan; PB-10 cuaca BMKG; PB-11 profil; penyelesaian PB-07 sinkronisasi dan gambar | Riwayat obat dan pemakaian stok konsisten; panen dan penjualan terhubung ke batch; cuaca menampilkan kondisi gagal; perubahan profil sesuai kewenangan; alur penyemaian sampai penjualan diuji; review, retrospektif, laporan uji |
| Sprint 4: penyempurnaan dan penyerahan | 8–28 November 2026 | Perbaikan fungsi/UI, konflik dan pengiriman ulang sinkronisasi, optimasi, pengujian akhir/lapangan, dokumentasi, paket produk | Black box/API/regresi/usability lulus; hak akses dan pemulihan koneksi diverifikasi; model diuji pada data terpisah; aplikasi Android, backend, model, laporan, dan panduan pengguna diserahkan paling lambat 28 November |

## Urutan pelaksanaan yang disarankan

Urutan ini menurunkan dependensi dari backlog dan WBS; tanggal antarpekerjaan dapat disesuaikan pada sprint planning.

1. **Sprint 1:** tetapkan matriks hak akses, aturan sesi luring dan konflik, pilihan backend (Node.js atau FastAPI), serta skema identitas transaksi. Bangun autentikasi → model barang/transaksi stok → penyemaian → SQLite dan sinkronisasi awal. Secara paralel siapkan dataset tiga hama, pedoman anotasi, dan uji inferensi TFLite pada perangkat sasaran.
2. **Sprint 2:** bangun meja dan kapasitas → pemindahan dari penyemaian menjadi batch → kerusakan dan jumlah tanaman aktif. Selesaikan anotasi dan pemisahan data latih/validasi/uji → latih dan evaluasi YOLO → konversi TFLite → integrasikan kamera/galeri dan simpan hasil per batch. Uji hasil tanpa deteksi tanpa menyimpulkan tanaman bebas hama.
3. **Sprint 3:** setelah deteksi dan riwayat batch siap, validasi aturan obat bersama mitra → implementasikan rekomendasi, keputusan petani, tindakan aktual, serta pengurangan stok. Setelah jumlah tanaman aktif siap, implementasikan panen → penjualan. Integrasikan BMKG dan aturan cuaca setelah parameter respons tervalidasi. Lengkapi profil, sinkronisasi, dan penyimpanan gambar.
4. **Sprint 4:** tutup temuan uji, khususnya kehilangan/duplikasi data dan hak akses; uji konflik antardevice, luring lalu daring, dan regresi alur penuh. Jalankan uji perangkat dan usability bersama mitra, finalkan diagram/SRS, laporan, panduan, paket Android, backend, dan model.

## Aturan dan gerbang kualitas yang perlu diingat

- Penyemaian sekitar 15 hari; umur bibit dihitung dari tanggal semai. Pemindahan tidak boleh melebihi bibit tersedia atau kapasitas meja. Dokumen menyebut 12 meja dengan total 3.000 lubang.
- Transaksi keluar tidak boleh melebihi stok. Pemakaian bahan dari perawatan hanya dicatat sekali. Kerusakan dan panen tidak boleh melebihi tanaman aktif; penjualan tidak boleh melebihi berat panen tersedia.
- Keputusan menerima rekomendasi berbeda dari tindakan perawatan yang benar-benar dilakukan. Riwayat rotasi obat berasal dari tindakan aktual.
- Perubahan luring harus bertahan setelah aplikasi dibuka kembali; pengiriman ulang tidak membuat duplikasi; konflik antardevice perlu aturan terdokumentasi. Cuaca/gambar dapat menunggu koneksi, sedangkan deteksi lokal tetap berjalan.
- Target awal yang harus diuji pada kondisi terdokumentasi: halaman utama <3 detik; inferensi lokal <5 detik/gambar; sinkronisasi <1 menit setelah koneksi tersedia; pencocokan aturan cuaca <2 detik setelah data valid diterima. Evaluasi model memakai precision, recall, F1-score, dan mAP; ambang mutu model masih perlu disepakati.
- Definition of Done tiap backlog: kriteria penerimaan terpenuhi, kode ditinjau dan terintegrasi, tes relevan lulus, tidak ada cacat penghambat alur utama/hak akses/kehilangan data, dokumentasi dan bukti uji diperbarui.

## Kondisi repo saat acuan ini dibuat (30 September 2026)

Repo sudah mempunyai kerangka Flutter di `apps/mobile`, `apps/backend/package.json` yang masih minimal, dan skrip ML di `ml`. Ini hanya inventaris singkat, bukan klaim bahwa target Sprint 1 sudah selesai. Pada tanggal acuan, jadwal resmi sedang berada di Sprint 2; status penyelesaian fitur perlu diverifikasi per kriteria penerimaan sebelum pekerjaan berikutnya diprioritaskan.
