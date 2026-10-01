# Urutan Pengerjaan Backend HidroSense

Status: acuan urutan kerja aktif berdasarkan arahan pengguna pada 30 September 2026. Dokumen ini menetapkan pekerjaan berikutnya; daftar fitur di bawah belum berarti sudah diimplementasikan.

Pembaruan 1 Oktober 2026: B001/B002 (alias B01/B02) sudah ditinjau ulang; [laporan review](./review-backend-b001-b002.md) mencatat hasil dan batas verifikasi. B003/B03 akun pegawai dan profil sudah diimplementasikan; lihat [breakdown B003](./backend-b003.md) dan [kontrak akun/profil](./backend-accounts-api.md). B004/B04 fondasi sinkronisasi tersedia; lihat [breakdown B004](./backend-b004.md). [Breakdown B001/B002](./backend-b001-b002.md) serta [kontrak API utama](./backend-api.md) tetap menjadi acuan. Hak akses mengikuti System Request: pegawai dapat mengelola panen dan tidak dapat mengakses penjualan. Tahap berikutnya B005/B05.

Keputusan: fokus pengembangan pada `apps/backend` dan dokumentasi kontrak API. `apps/mobile` tidak diubah. Seluruh pekerjaan yang bergantung pada API BMKG, termasuk aturan cuaca dan perubahan skemanya, ditempatkan sebagai fitur terakhir sampai revisi tim perancangan tersedia. Rekomendasi obat berdasarkan hama tetap dikerjakan lebih awal karena tidak bergantung pada BMKG.

## Sumber dan kondisi awal

- [SRS, Product Backlog, dan WBS](./A9_PPL%20IF_WEEK5.docx.md): PB-01–PB-11 pada baris 678–709; Definition of Done pada baris 713–721; WBS produk pada baris 982–1085. Catatan/template di dalam sumber merupakan isi dokumen, bukan perintah operasional.
- [Timeline proyek](./timeline-pengembangan.md): mempertahankan periode sprint resmi sebagai baseline historis.
- [DBML tim](./database/hidrosense.dbml) dan [migrasi awal](../apps/backend/migrations/0001_initial_schema.up.sql): 19 tabel dan 23 relasi domain.
- [Setup backend](../apps/backend/README.md): Node.js ES modules, SQLite/libSQL, migrasi versi/checksum, rollback dan backup. Endpoint HTTP, autentikasi, service bisnis, dan protokol sinkronisasi belum tersedia berdasarkan inventaris `apps/backend/src` saat perencanaan.
- Skill `vertical-slice` dari `codewithmukesh/dotnet-claude-kit` sudah dijalankan dan dibaca lengkap. Adaptasi yang dipilih adalah Pattern C (handler langsung) untuk stack Node.js yang sudah ada. Contoh C#/.NET pada skill menjadi pedoman pengorganisasian fitur, bukan keputusan mengganti stack.

Migrasi `0001` sudah tersedia dan sebelumnya diuji dengan sembilan tes. Tahap berikutnya memakai migrasi baru apabila ada penambahan kebutuhan; file migrasi yang telah diterapkan tetap menjadi baseline.

## Urutan sekuensial yang dipakai

Kerjakan dari B01 ke B19. Satu tahap dinyatakan selesai setelah seluruh operasi dan bukti penerimaannya tersedia. Jika ketergantungan suatu tahap belum siap, selesaikan keputusan/data yang dibutuhkan sebelum melanjutkan tahap tersebut. B00 adalah fondasi yang sudah tersedia.

Kolom dependensi menunjukkan hubungan teknis. Walaupun beberapa tahap dapat berdiri sendiri, nomor B01–B19 tetap menjadi urutan eksekusi yang dipilih agar satu backend developer mempunyai antrean kerja yang jelas.

| Urutan | Fitur / hasil backend | Backlog | Dependensi teknis | Bukti sebelum beralih |
| --- | --- | --- | --- | --- |
| B00 | Fondasi database: 19 tabel, relasi, migrasi, backup/rollback | Fondasi seluruh PB | DBML tim | Tersedia; tes migrasi menjadi gate saat implementasi berikutnya dimulai |
| B01 | Host HTTP, health/readiness, konfigurasi, format error, validasi, kontrak API dan matriks akses | Fondasi seluruh PB | B00 | API dapat diuji tanpa Flutter; kontrak tanggal, desimal, ID, pagination, dan error terdokumentasi |
| B02 | Autentikasi dan otorisasi | PB-01 | B01 | Login sah/gagal, sesi kedaluwarsa/dicabut, pengguna nonaktif, serta akses petani/pegawai diuji |
| B03 | Akun pegawai dan profil | PB-11; akun pada System Request | B02 | Petani dapat membuat/melihat/mengubah/menonaktifkan pegawai dan memperbarui profil sesuai kewenangan; perubahan profil tidak dapat menaikkan role |
| B04 | Fondasi sinkronisasi server: identitas operasi, replay, versi perubahan, dan kontrak konflik | PB-07 bagian awal | B02–B03 | Kontrak dan migrasi pendukung tersedia; dua pengiriman operasi sama tidak menghasilkan dua perubahan; payload berbeda dengan key sama ditolak |
| B05 | Master jenis inventaris, data dasar obat, dan barang inventaris | PB-02; prasyarat PB-06 | B04 | Tambah, daftar/detail, ubah, nonaktifkan; referensi obat/jenis valid dan histori tetap dapat dibaca |
| B06 | Stok masuk/keluar, saldo, dan histori bahan | PB-02 | B05 | Header/detail dan saldo konsisten; stok tidak negatif; pengiriman ulang dan dua pemakaian bersamaan tidak menggandakan/menghabiskan saldo yang sama |
| B07 | Penyemaian, umur bibit, kesiapan 15 hari, dan pemakaian bahan | PB-03 | B06 | Tambah/lihat/ubah; jumlah positif; pemakaian bahan tercatat sekali; perubahan tidak membuat jumlah bibit lebih kecil dari yang sudah dipindahkan |
| B08 | Meja tanam dan status fisik | PB-04 bagian meja | B02, B04 | Tambah/lihat/ubah meja dan status; kode unik; kapasitas positif; kapasitas tidak boleh diturunkan di bawah tanaman aktif |
| B09 | Pemindahan, batch, pertumbuhan, HSS, dan estimasi panen | PB-04 bagian batch | B07–B08 | Pemindahan terhubung ke asal dan meja; bibit/kapasitas tidak terlampaui termasuk saat transaksi bersamaan; umur dihitung dari tanggal semai |
| B10 | Kerusakan tanaman | PB-04 bagian kerusakan | B09 | Tambah/lihat/ubah kerusakan per batch; tanaman aktif serta kapasitas dihitung konsisten; jumlah rusak tidak melebihi sisa tanaman |
| B11 | Penerimaan/riwayat hasil deteksi serta penyimpanan gambar | PB-05 bagian backend; PB-07 gambar | B09–B10, B04 | Metadata hasil inferensi terhubung ke batch; kelas/confidence valid; hasil tanpa deteksi dan gagal dapat direpresentasikan; unggah ulang tidak menggandakan catatan |
| B12 | Aturan hama, golongan bahan aktif, rotasi obat, dan pembuatan rekomendasi | PB-06 bagian rekomendasi | B05, B11 | Aturan tervalidasi dan versinya terlacak; pemilihan obat memakai riwayat tindakan aktual; kondisi tanpa aturan/riwayat ditangani eksplisit |
| B13 | Keputusan terhadap rekomendasi | PB-06 bagian keputusan | B12 | Status menunggu → diterima/ditolak, alasan opsional; transisi/replay terkendali; menerima rekomendasi belum mengurangi stok |
| B14 | Pelaksanaan perawatan, bahan yang dipakai, dan riwayat obat | PB-06 bagian tindakan | B06, B09, B13 | Tindakan aktual dan stok keluar commit bersama; retry tidak menggandakan konsumsi; rekomendasi berikutnya membaca riwayat aktual ini |
| B15 | Pencatatan panen | PB-08 | B09–B10, B06 untuk pola transaksi | Header/detail, tanggal, jumlah, berat, daftar/detail dan perubahan panen tersedia; jumlah aktif/kapasitas benar; perubahan panen menjaga transaksi penjualan terkait |
| B16 | Pencatatan penjualan | PB-09 | B15 | Header/detail, tambah/lihat/ubah, harga/kg, nilai penjualan dan sisa panen benar; berat terjual tidak melebihi tersedia termasuk pada transaksi bersamaan |
| B17 | Penyelesaian sinkronisasi server untuk seluruh fitur noncuaca | PB-07 bagian lengkap | B04–B16 | Push/pull atau replay operasi memakai aturan bisnis yang sama; dependensi antar-ID, retry, konflik, otorisasi, dan pagination/cursor diuji dengan simulator dua perangkat |
| B18 | Verifikasi dan paket backend noncuaca | Lintas PB noncuaca | B01–B17 | Alur operasional penuh, regresi, restore backup, migrasi upgrade, dokumentasi API, serta uji staging Turso selesai; backend noncuaca siap diintegrasikan |
| B19 — terakhir | Revisi rancangan cuaca → implementasi BMKG → rekomendasi cuaca → regresi dan paket akhir backend | PB-10 | B18 dan revisi resmi tim perancangan | Kontrak baru sudah jelas, integrasi cuaca lulus kasus normal/gagal, dan kegagalan cuaca tidak menghambat fitur lain |

## Rincian operasi dan batas tiap tahap

### B01–B04: akses dan kontrak pencatatan

B01 menyiapkan komposisi aplikasi dan pengujian HTTP, bukan seluruh platform abstrak terlebih dahulu. Kontrak API memakai versi yang terdokumentasi, ID yang konsisten, daftar dengan pagination, kode kesalahan terstruktur, serta tanggal/waktu yang tidak mengubah HSS karena zona waktu. Tetapkan representasi dan pembulatan kuantitas/harga sebelum B06; `DECIMAL` SQLite pada migrasi awal tidak menjamin fixed decimal yang eksak.

B02 menyediakan bootstrap akun petani secara terkendali, role petani/pegawai, login, informasi sesi/pengguna aktif, mekanisme kedaluwarsa/pembaruan sesuai kontrak, dan logout/pencabutan. Password hanya disimpan sebagai hash. Setiap endpoint memeriksa role dan status akun pada server. Penonaktifan akun tidak menghapus transaksi historis. Aturan sesi ketika klien luring harus terdokumentasi; simulasi backend tidak membuktikan implementasi sesi Flutter.

B03 mengerjakan pengelolaan akun pegawai dan profil lebih awal daripada rencana Sprint 3 karena diperlukan untuk menguji seluruh hak akses. Operasi yang direncanakan: `create-employee`, `list-employees`, `get-employee`, `update-employee`, `deactivate-employee`, `get-profile`, dan `update-profile`. Perubahan profil tidak menerima role/status administratif bebas dari pemanggil.

B04 menetapkan identitas operasi global dari klien, pemetaan ID sementara/ID pusat atau ID publik, dan kontrol versi. Kunci unik minimal terikat pada identitas pemanggil dan operasi; replay mengembalikan hasil yang sama, sedangkan key sama dengan isi berbeda menjadi konflik. Catatan deduplikasi dan perubahan bisnis berada dalam transaksi yang sama. Ini menjadi komponen bersama yang dipakai setiap penulisan operasional sejak B05, lalu dibuktikan pada transaksi stok di B06. Detail transport sinkronisasi dapat diselesaikan pada B17, tetapi aturan integritas tidak ditunda sampai B17.

### B05–B10: inventaris sampai tanaman aktif

B05 mencakup `jenis_inventaris`, `obat`, dan `inventaris`. Data dasar obat disiapkan agar relasi inventaris tidak kosong tanpa alasan; aturan rotasi dan rekomendasi baru dikerjakan B12. Hak pengelolaan obat ditetapkan bersama matriks akses. Barang nonaktif tetap muncul pada histori tetapi tidak dipakai untuk transaksi baru. Stok minimum menjadi data acuan daftar stok; kanal notifikasi stok tambahan tidak diasumsikan sebagai fitur baru.

B06 menyimpan stok pada `stok` dan `detail_stok`; saldo dihitung dari ledger masuk/keluar. Pengambilan saldo, pemeriksaan, dan penulisan dilakukan atomik. Jenis, satuan, jumlah positif, dan referensi barang divalidasi. Koreksi transaksi yang sudah memengaruhi saldo harus memiliki kebijakan pembalikan/penyesuaian yang terdokumentasi; tidak mengedit saldo akhir secara bebas.

B07 mencatat penyemaian dan bahan yang benar-benar digunakan; hubungan `stok.id_penyemaian` mencegah konsumsi tercatat dua kali. Sediakan data usia dan daftar bibit siap pindah pada usia 15 hari untuk memenuhi kebutuhan pengingat. Backend menyiapkan data/kontrak pengingat; tampilan dan penjadwalan notifikasi lokal adalah serahan kepada tim mobile.

B08 mempertahankan kapasitas sebagai konfigurasi data meja. Angka 12 meja × 250 lubang adalah konteks mitra, bukan batas keras yang harus ditanam di semua handler.

B09 memperlakukan `pemindahan` sebagai identitas batch sesuai DDL. Urutan operasi: daftar bibit tersedia dan meja tersedia → catat pemindahan → detail/daftar batch → koreksi yang tervalidasi → informasi HSS dan estimasi panen. Estimasi sekitar 45 HSS adalah perkiraan dari dokumen, bukan janji tanggal panen. Parameter usia harus dapat disepakati dengan mitra.

B10 menambah/menampilkan/memperbaiki data kerusakan. Perhitungan yang dipakai bersama: tanaman aktif = jumlah dipindahkan − kerusakan − tanaman dipanen; kapasitas tersedia = kapasitas meja − jumlah tanaman aktif pada meja. Saat B15 diterapkan, uji ulang perhitungan yang sama dengan panen parsial. Pengubahan asal/jumlah batch atau kerusakan harus tetap menjaga seluruh transaksi turunannya.

### B11–B14: hasil deteksi, rekomendasi, dan tindakan aktual

B11 mengerjakan kontrak penerimaan hasil YOLO dari klien, validasi hasil, daftar/detail per batch, serta unggah/tautkan gambar melalui Cloudinary. Endpoint menerima identitas aset yang bisa diverifikasi; server tidak memperlakukan path lokal perangkat sebagai gambar yang sudah tersedia di cloud. Kontrak memungkinkan metadata dan unggah gambar datang terpisah dengan status yang jelas. Uji memakai fixture hasil deteksi dan adapter penyimpanan gambar; uji integrasi Cloudinary memerlukan kredensial khusus environment.

Pelatihan YOLO, dataset, kamera/galeri, konversi TFLite, dan inferensi perangkat tetap milik jalur ML/mobile. Backend tidak menunggu UI untuk diuji dan tidak memindahkan inferensi lokal menjadi inferensi server. Target inferensi <5 detik dan mutu model harus dibuktikan tim ML/mobile, terpisah dari bukti endpoint.

B12 membutuhkan migrasi tambahan untuk menyimpan golongan bahan aktif, pemetaan hama ke aturan/obat, serta identitas/versi aturan yang melahirkan rekomendasi. Riwayat kosong memiliki perilaku awal yang eksplisit; hasil tanpa hama yang memenuhi ambang tidak menghasilkan klaim tanaman bebas hama atau obat otomatis. Dataset aturan berasal dari validasi tim/mitra. Susun fixture untuk riwayat tindakan sebelum handler pencatatan tindakan selesai; B14 kemudian membuktikan alur aktualnya.

B13 memisahkan `decide-recommendation` dari `record-care`. Keputusan menolak dapat menyimpan alasan, sedangkan keputusan menerima tidak menciptakan konsumsi obat. Kebijakan mengubah keputusan dan pencatatan tindakan terhadap rekomendasi yang ditolak harus ditetapkan sebelum implementasi transisi status.

B14 menyimpan tindakan, petugas, waktu, catatan, dan pemakaian bahan per batch melalui relasi yang sudah ada. Pembaruan `perawatan`, `stok`, dan `detail_stok` harus berada dalam satu transaksi. Cek ulang rekomendasi berikutnya setelah tindakan berhasil; pergantian golongan obat memakai tindakan nyata, bukan sekadar riwayat saran.

### B15–B18: hasil usaha dan kesiapan integrasi

B15 memakai header `panen` dan detail `detail_panen`, sehingga satu pencatatan panen dapat memuat beberapa batch sesuai struktur tim. Panen parsial mengurangi tanaman aktif dan mengembalikan kapasitas yang terpakai. Koreksi berat/jumlah tetap harus konsisten dengan penjualan yang sudah tercatat.

B16 mengikuti `detail_penjualan.id_panen` yang menunjuk header panen. Ketersediaan dihitung dari total berat detail panen dikurangi total yang sudah dijual, bukan dari satu detail batch arbitrer. Nilai transaksi dihitung dari jumlah kg × harga/kg dengan aturan desimal B01. Bila tim memerlukan penelusuran penjualan per detail batch, perubahan referensi tersebut harus menjadi keputusan skema tersendiri.

B17 menguji siklus server dari catatan belum terkirim, pengiriman ulang setelah respons hilang, penerimaan hasil, sampai pengambilan perubahan untuk klien lain. Perubahan bersamaan pada stok, kapasitas, tanaman, dan penjualan tidak boleh memakai aturan "yang terakhir menulis selalu menang" tanpa validasi. Konflik terdeteksi menghasilkan respons yang bisa ditangani klien. Catatan induk harus dapat dipetakan sebelum anak; misalnya penyemaian → pemindahan → hasil deteksi → rekomendasi/perawatan. Endpoint sinkronisasi tidak boleh menjadi jalur tulis tabel bebas yang melewati otorisasi dan aturan bisnis.

B18 menyiapkan kontrak OpenAPI atau dokumentasi HTTP setara, contoh request/response, fixture, dan bukti tes untuk tim mobile. Verifikasi alur stok → semai → pindah → rusak/deteksi → rekomendasi → keputusan → perawatan → panen → penjualan, termasuk retry dan konflik. Uji staging Turso memakai database uji dan kredensial yang sesuai. Target sinkronisasi <1 menit hanya dapat dinilai pada volume data/koneksi yang ditetapkan; pengujian backend dengan simulator belum berarti sinkronisasi aplikasi mobile sudah selesai.

### B19: semua pekerjaan terkait BMKG paling akhir

Status awal: **menunggu revisi tim perancangan**. Termasuk yang ditahan: adapter BMKG, pengambilan/prakiraan berkala, pemetaan lokasi/parameter, aturan perawatan cuaca, endpoint cuaca, dan migrasi khusus cuaca. Tabel `penanganan_cuaca` yang sudah ada adalah baseline, bukan bukti rancangan baru sudah final.

Setelah B18 selesai, urutannya adalah:

1. Baca revisi resmi dan tetapkan perubahan field, sumber data, lokasi, jadwal pembaruan, aturan rekomendasi, serta kriteria penerimaan PB-10.
2. Cocokkan revisi dengan `penanganan_cuaca`; buat migrasi kompatibel hanya jika diperlukan.
3. Implementasikan adapter BMKG beserta validasi respons, timeout dan penanganan data tidak tersedia.
4. Implementasikan pencocokan aturan dan endpoint cuaca/rekomendasi dengan lokasi serta waktu data yang jelas.
5. Uji kondisi normal/gagal, jalankan regresi fitur noncuaca, finalkan dokumentasi dan paket backend.

Batas lama "tanpa riwayat cuaca" dan target pencocokan <2 detik adalah baseline untuk dibandingkan dengan revisi, bukan keputusan yang dibekukan sekarang. Ketersediaan curah hujan numerik wajib diperiksa sebelum aturan menggunakannya. Jika revisi belum tersedia, B19 tetap tertahan; hasil backend noncuaca tetap dapat diserahkan.

## Pola vertical slice untuk implementasi

Struktur berikut adalah rancangan folder ketika implementasi dimulai, bukan folder yang sudah dibuat pada pekerjaan perencanaan ini:

```text
apps/backend/src/
  app.js
  server.js
  db/                         # koneksi dan migrasi yang sudah ada
  common/
    auth.js
    errors.js
    idempotency.js
    stock-transactions.js     # diekstrak ketika benar-benar dipakai lintas fitur
    cultivation-balances.js  # perhitungan bersama batch/meja/panen
  features/
    auth/login.js
    accounts/create-employee.js
    inventory/create-item.js
    stock/record-movement.js
    nursery/create-sowing.js
    tables/update-table.js
    batches/move-seedlings.js
    damage/record-damage.js
    detections/record-detection.js
    recommendations/create-recommendation.js
    recommendations/decide-recommendation.js
    care/record-care.js
    harvest/record-harvest.js
    sales/record-sale.js
    sync/pull-changes.js
    weather/get-recommendation.js   # B19
```

Setiap operasi sederhana menempatkan schema request/response, validasi, handler, dan deklarasi route berdekatan atau dalam satu file. Handler menjalankan satu use case dan menjadi batas transaksi. Tambahkan tes endpoint/handler pada tahap yang sama. Pecah file bila kompleksitas menuntut; tidak perlu mediator, event bus, atau repository generik untuk memulai.

Handler tidak memanggil handler fitur lain. Contoh: `record-care` tidak memanggil endpoint `record-movement`; keduanya dapat memakai fungsi stok bersama yang menerima transaksi aktif. Registrasi handler untuk replay sinkronisasi dilakukan pada komposisi aplikasi melalui kontrak bersama. Dengan demikian, replay memakai aturan yang sama tanpa membuat `features/sync` bergantung langsung pada implementasi folder fitur lain.

## Cakupan lengkap terhadap backlog dan serahan tim

| Backlog / kebutuhan | Tahap backend | Serahan di luar perubahan backend |
| --- | --- | --- |
| PB-01 autentikasi/hak akses | B01–B03, B17 | Layar login, penyimpanan sesi perangkat, menu berdasarkan role |
| PB-02 inventaris/stok | B05–B06, B14, B17 | Form/list inventaris dan tampilan saldo |
| PB-03 penyemaian | B07, B09, B17 | Form semai dan notifikasi lokal usia 15 hari |
| PB-04 meja/pertumbuhan/kerusakan | B08–B10, B15, B17 | Form meja/batch/kerusakan, tampilan umur dan kapasitas |
| PB-05 deteksi hama | B11 | Dataset, training/evaluasi, TFLite, kamera/galeri, inferensi lokal, tampilan hasil |
| PB-06 rekomendasi/perawatan | B12–B14 | Validasi agronomi oleh perancang/mitra; UI keputusan dan tindakan |
| PB-07 luring/sinkronisasi | B04, setiap penulisan B05–B16, B17–B18 | SQLite perangkat, antrean lokal, retry klien, UI konflik/status dan uji luring nyata |
| PB-08 panen | B09 estimasi, B15, B17 | Form dan tampilan hasil panen |
| PB-09 penjualan | B16–B17 | Form dan tampilan penjualan |
| PB-10 cuaca BMKG | B19 saja | Revisi tim perancangan; UI cuaca setelah kontrak final |
| PB-11 akun/profil | B03 | Layar profil dan pengelolaan pegawai |
| Dokumentasi/pengujian/penyerahan | Setiap tahap, B18, lalu finalisasi B19 | Pengujian usability mitra, APK, serta uji model/perangkat oleh tim terkait |

## Keputusan yang harus ditutup pada tahap terkait

| Keputusan | Temuan / alasan | Selesaikan sebelum |
| --- | --- | --- |
| Matriks hak akses — selesai | Pengguna menetapkan System Request sebagai acuan: pegawai memiliki akses panen dan tidak memiliki akses penjualan. Matrix dan tes guard tersedia pada B002; rincian ada di kontrak API | Diputuskan sebelum B02 |
| Siklus akun/sesi | Bootstrap petani, izin profil, masa berlaku sesi, pencabutan, dan aturan sesi luring belum lengkap pada DDL | B02–B03 |
| Representasi angka dan waktu | Affinity SQLite, desimal uang, zona waktu HSS, dan aturan pembulatan harus konsisten | B01 sebelum B06 |
| Identitas sinkronisasi | PK integer lokal dapat bertabrakan antardevice; DDL belum memiliki ID operasi global, versi, atau catatan konflik | B04 |
| Koreksi catatan dan alokasi bahan | Perlu aturan perubahan transaksi, pemakaian benih/bahan, dan konsistensi histori untuk semai/perawatan/panen | B06–B07 dan sebelum slice turunannya |
| Bentuk hasil deteksi | DDL mengharuskan nama hama/gambar per row; dukungan banyak objek, tanpa deteksi, gagal, dan gambar belum terunggah perlu kontrak serta migrasi tambahan | B11 |
| Aturan dan histori obat | Golongan bahan aktif, versi aturan, hubungan ke aturan yang dipakai, dan kebijakan keputusan belum lengkap pada DDL | B12–B14 |
| Akses layanan eksternal | Staging Turso dan penyimpanan gambar memerlukan kredensial environment. Fixture dapat dipakai untuk tes lokal; tes live tetap menjadi pekerjaan yang harus dituntaskan | Cloudinary B11; Turso B18 |
| Rancangan cuaca baru | Pengguna menyatakan ada perubahan tim; rincian belum diberikan | B19, tanpa menghalangi B01–B18 |

Keputusan ini adalah pekerjaan analisis dalam tahap terkait, bukan alasan untuk menunda seluruh perencanaan. Perubahan struktur dilakukan melalui migrasi baru dengan bukti preservasi data; jangan memaksa perilaku baru ke DDL awal tanpa kontrak.

## Hubungan dengan sprint dan Definition of Done

Periode resmi tetap Sprint 1: 31 Agustus–22 September; Sprint 2: 23 September–15 Oktober; Sprint 3: 16 Oktober–7 November; Sprint 4: 8–28 November 2026. Pada 30 September, kalender sudah memasuki Sprint 2, tetapi keberadaan migrasi saja tidak membuktikan keluaran Sprint 1 telah selesai.

Pemetaan cakupan: B01–B07 menutup fondasi yang sebelumnya menjadi sasaran Sprint 1 (dengan akun/profil dipercepat); B08–B11 sesuai kelompok Sprint 2; B12–B17 menutup kelompok Sprint 3 noncuaca; B18 menyiapkan mutu dan serahan backend; B19 mengerjakan cuaca paling akhir setelah revisi tersedia. Ini pemetaan pekerjaan, bukan janji bahwa seluruhnya muat pada tanggal lama. Estimasi dan komitmen tanggal perlu dihitung dari kapasitas tim, progres aktual, serta tanggal diterimanya revisi BMKG. Target produk pada dokumen tetap 28 November 2026 sampai tim menyepakati perubahan.

Definition of Done untuk setiap slice backend:

1. Endpoint, validasi, otorisasi, handler, dan transaksi memenuhi kriteria penerimaan use case.
2. Migrasi baru jika diperlukan dapat diterapkan pada database kosong dan database versi sebelumnya tanpa kehilangan data yang harus dipertahankan; jalur pemulihan terdokumentasi.
3. Tes sukses, input salah, akses terlarang, retry/konflik, dan kegagalan di tengah transaksi yang relevan lulus.
4. Kontrak request/response serta error dan contoh data tersedia sehingga endpoint dapat diuji tanpa perubahan mobile.
5. Kode ditinjau, hasil terintegrasi, dan tidak ada cacat yang menghambat alur utama, melanggar akses, atau menghilangkan data.
6. Status dicatat terpisah antara backend siap, integrasi mobile belum/selesai, dan validasi perangkat/mitra. Kesiapan backend tidak otomatis menutup keseluruhan PB-05/PB-07 produk.

Pekerjaan konkret berikutnya: **B004/B04**, setelah B001–B003 tersedia. Implementasi BMKG baru dibuka di **B19**.
