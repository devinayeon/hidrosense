# Review HidroSense terhadap Rencana Tim

Tanggal: 2026-11-05
Yang diperiksa: backend (`apps/backend`) dan aplikasi Flutter (`apps/mobile`) yang terhubung dengannya, di commit `726fc64` (`main`)
Pembanding: `hidrosense-plan-docs/Hidrosense Plan Document.md` dan 11 tujuan dari tim
Jenis pekerjaan: baca dan telusuri saja. **Tidak ada kode produk, database, atau folder `ml/` yang diubah.**

---

## 1. Ringkasan untuk semua pembaca

Backend sudah matang: logikanya benar dan teruji. Yang belum sesuai rencana ada di aplikasi Flutter, dan pada satu keputusan rancangan.

**Jawaban singkat per tujuan:**

| # | Tujuan tim | Status | Alasan dalam satu kalimat |
|---|---|---|---|
| 1 | Berjalan lokal, offline first | **Belum** | Setiap fitur membaca dan menulis lewat server. Hanya daftar inventaris yang punya salinan di ponsel, dan setelah aplikasi ditutup, ponsel yang tidak ada internet tidak bisa masuk sama sekali |
| 2 | Internet hanya untuk BMKG | **Sebagian** | Aplikasi hanya menghubungi dua alamat (server sendiri dan BMKG), tetapi server sendiri tetap dibutuhkan untuk semua fitur lain |
| 3 | Model AI diunduh dulu | **Belum dimulai** | Sesuai tujuan 4. Tidak ada persiapan unduhan |
| 4 | Fitur AI tidak disentuh | **Terpenuhi** | Tidak ada kode, layar, atau paket AI di aplikasi. Folder `ml/` tidak saya sentuh |
| 5 | Mobile first | **Sebagian** | Tata letak, ukuran teks, keyboard, dan perlindungan dobel-ketuk sudah bagus. Warna teks terlalu pucat di bawah sinar matahari, dan keyboard angka belum tepat |
| 6 | Model AI ditanam di sistem | **Belum dimulai** | Belum ada tempat atau pengaturan untuk model. Tujuan 3 dan 6 saling bertentangan (bagian 4) |
| 7 | Monorepo sesuai praktik terbaik | **Sebagian** | Struktur folder sudah wajar. Pemeriksaan otomatis (CI) belum menjalankan tes backend, dan tidak ada satu perintah untuk memeriksa semuanya |
| 8 | Arsitektur MVC | **Sebagian** | Backend berpola irisan per fitur, aplikasi berpola MVVM. Keduanya mirip MVC tetapi tidak dijelaskan di mana pun |
| 9 | File 200 sampai 300 baris, tidak berlebihan | **Backend terpenuhi, aplikasi belum** | 30 dari 143 file aplikasi lebih dari 300 baris, memuat 55% seluruh kode aplikasi |
| 10 | Komentar pada blok penting | **Belum** | Komentar hanya 3% di backend dan 1% di aplikasi, dan aturan bisnis utama hampir tidak dijelaskan |
| 11 | Mudah dibaca tim lain dan non-teknis | **Sebagian** | Tidak ada peta folder, daftar istilah, atau penjelasan alur. Satu pola penting (perintah ulang yang aman) muncul enam kali tanpa penjelasan |

**Tiga hal paling penting:**

1. **Aplikasi masih "online first", bukan "offline first".** Ini selisih terbesar dengan rencana, dan perbaikannya paling besar: perkiraan pemeriksa 3 sampai 4 minggu untuk satu pengembang. Waktu sampai penyerahan (28 November) tinggal 23 hari.
2. **Satu bug yang bisa menggandakan uang.** Bila jaringan putus tepat setelah penjualan tersimpan di server, mengetuk "Simpan" lagi membuat penjualan kedua. Perbaikannya kecil (sekitar setengah hari).
3. **Rencana sendiri bertentangan pada dasar arsitektur.** Satu bagian menyebut data disinkronkan ke server pusat lewat internet, bagian lain menyebut produk berjalan lokal tanpa internet. Sebelum membangun apa pun yang besar, perlu satu kalimat keputusan (bagian 4).

---

## 2. Cara pemeriksaan dan batasnya

Pekerjaan dibagi ke lima pemeriksa yang masing-masing membaca satu irisan secara penuh dan tidak tahu riwayat percakapan ini. Setiap pemeriksa menulis laporannya sendiri; laporan itu ada di folder `lampiran-2026-11-05/`.

| Irisan | Isi |
|---|---|
| F1 | Monorepo, MVC, struktur berlebihan |
| F2 | Offline first, BMKG, kesiapan AI, kecocokan aplikasi dengan backend |
| F3 | Ukuran file, kode berulang, kode mati di aplikasi |
| F4 | Mobile first di layar dan kode tampilan |
| F5 | Komentar dan keterbacaan, di backend dan aplikasi |

Audit backend sebelumnya (`yeonworks/review-learn/laporan-review-kode-backend.md`) tidak diulang.

**Yang saya buktikan ulang sendiri, dan hasilnya:**

| Klaim | Hasil |
|---|---|
| Penjualan membuat kunci baru di tiap percobaan (F2-04) | Terbukti: `createSale`, `updateSale`, dan `updateSaleHeader` memanggil `generateUuidV4()` setiap kali; panen menyimpan kunci di objek perintah |
| Tidak ada penyimpanan token dan tidak ada pemakaian `sync/changes` atau `X-Client-Id` (F2) | Terbukti: nol baris di `lib/` dan nol paket penyimpanan di `pubspec.yaml` |
| 14 file yatim, 1.073 baris (F3-3) | Terbukti. Dua hitungan awal yang tampak tidak nol ternyata kecocokan nama sebagian (`row_info_card_md`) dan satu file yang hanya diimpor file yatim lain |
| Layar inventaris lama tidak pernah terbuka di aplikasi (F3-4) | Terbukti dari satu-satunya pemanggil `DashboardBody`, yang selalu memberi `onInventoryTap` |
| 30 file mobile lebih dari 300 baris | Terbukti, 30 |
| CI tidak menjalankan pemeriksaan backend (F1) | Terbukti: nol baris `npm test`, `npm run check`, `biome`, atau `tsc` di workflow |
| `.gitignore` memblokir template `.env.turso.example` | Terbukti lewat `git check-ignore` (aturan `.env.*` di baris 189) |
| Lock file di root hanya stub | Terbukti: 95 byte, dan tidak ada `package.json` di root |

Temuan lain **belum** saya buktikan ulang. Yang bertanda `SUSPECTED` di laporan lampiran hanya hasil membaca kode.

**Tidak diuji:** aplikasi di perangkat nyata atau emulator, kecepatan layar di ponsel 3 GB, pembengkakan memori saat gambar login dimuat, perilaku di Turso atau platform serverless. Tiga ukuran "hari kerja" di laporan ini adalah perkiraan pemeriksa, bukan hasil pengukuran.

**Koreksi atas ucapan saya sebelumnya:** saya pernah menulis bahwa repositori penjualan sudah mengirim kunci anti-duplikat. Itu benar hanya untuk repositorinya. Lapisan view model di atasnya membuat kunci baru tiap panggilan, jadi perlindungannya tidak bekerja (bug nomor 2 di atas).

---

## 3. Temuan per tujuan

### Tujuan 1 dan 2: offline first, internet hanya untuk BMKG

Penelusuran fitur demi fitur saat tidak ada jaringan:

| Fitur | Baca tanpa jaringan | Tulis tanpa jaringan |
|---|---|---|
| Login / sesi | Tidak | Tidak |
| Inventaris (daftar) | Salinan lama, hanya selama aplikasi tidak ditutup | Tidak |
| Formulir tambah barang (daftar jenis) | Tidak | tidak berlaku |
| Stok, penyemaian, pemindahan, kerusakan, panen, penjualan | Hanya selama layar masih terbuka | Tidak |
| Meja tanam | Selama sesi berjalan | Tidak |
| Akun pegawai, profil | Hanya selama layar terbuka | Tidak |
| Cuaca | Hanya selama layar terbuka, butuh internet | tidak berlaku |

Penyebab utama:

| Kode | Temuan | Tingkat |
|---|---|---|
| F2-01 | Server satu-satunya penyimpan data. Ponsel tidak punya sumber data sendiri; `sqflite` hanya dipakai satu file cache inventaris | Kritis |
| F2-02 | Token hanya di memori. Aplikasi yang ditutup atau dimatikan Android harus login ulang, dan login membutuhkan server | Kritis |
| F2-03 | Tidak ada antrean tulis tersimpan. Penulisan tanpa jaringan gagal seketika; draf hilang bersama prosesnya | Kritis |
| F2-04 | Penjualan menggandakan data bila ketuk ulang (di atas) | Tinggi |
| F2-05 | Kontrak sinkronisasi di server tidak dipakai: aplikasi tidak memanggil `sync/changes`, tidak mengirim `X-Client-Id`, dan hanya panen dan penjualan yang mengirim `expected_version` | Tinggi |
| F2-06 | Server belum siap melayani klien offline: batas 120 permintaan per menit per IP (semua ponsel satu Wi-Fi kebun berbagi satu IP), anak data hanya bisa merujuk induk lewat ID angka server, tidak ada endpoint massal | Tinggi |
| F2-07 | Versi rilis menolak server `http://192.168...`. Server di laptop kebun lewat LAN tidak bisa dipakai tanpa sertifikat atau pengecualian | Tinggi |
| F2-08 | Data yang sudah dimuat dibuang saat pindah tab, jadi navigasi biasa pun berakhir sebagai layar galat bila jaringan hilang | Sedang |
| F2-09 | Cuaca butuh login ke server, dan tidak menyimpan prakiraan terakhir yang baik | Sedang |

**Yang sudah benar:** cuaca memanggil BMKG langsung, kegagalannya tidak mengganggu fitur lain, dan tidak ada riwayat cuaca yang disimpan (sesuai rencana). Aplikasi hanya menghubungi dua alamat. Semua 18 penulisan domain mengirim `Idempotency-Key`, dan server sudah menyediakan dasar sinkronisasi yang baik (resi, versi, daftar perubahan).

**Arsitektur terkecil menuju offline first** (perkiraan pemeriksa untuk satu pengembang yang mengenal kodenya):

| Bagian | Isi | Perkiraan |
|---|---|---|
| 1 | SQLite di ponsel sebagai sumber data; tujuh repositori membaca dari sana | 3 sampai 5 hari |
| 2 | Tulis lokal dan satu tabel antrean (outbox) dalam satu transaksi | 3 sampai 4 hari |
| 3 | Pengirim antrean: urut induk sebelum anak, kirim ulang dengan kunci yang sama, tangani penolakan | 3 sampai 4 hari |
| 4 | Tarik perubahan dari `sync/changes`; reset penuh bila kursor ditolak | 2 sampai 3 hari |
| 5 | Sesi tersimpan di penyimpanan aman; buka kunci offline dengan identitas yang disimpan | 1 sampai 2 hari |
| 6 | Penanda status sinkron, daftar yang ditolak server, tes | 3 sampai 5 hari |
| Server | Isi data di daftar perubahan, kuota per pengguna, rujukan induk lewat `public_id` | 3 sampai 5 hari |

Total sekitar 3 sampai 4 minggu. Satu fakta yang membantu: enam kelas "perintah tertunda" yang ada sekarang (F3-10, F1-F12) adalah bentuk awal baris antrean. Menyatukannya menjadi satu kelas adalah langkah pertama yang berguna.

### Tujuan 3, 4, 6: model AI

- Tujuan 4 terpenuhi: tidak ada kode, layar, atau paket AI di aplikasi. Skrip di `ml/` kosong (0 byte); saya hanya melihat nama filenya.
- Menanam model (tujuan 6) butuh paket TFLite, `image_picker` atau `camera`, izin kamera di Android dan iOS, pengaturan `noCompress` untuk `.tflite`, dan folder `assets/models/`. Semuanya belum ada.
- Mengunduh sekali (tujuan 3) butuh tambahan `path_provider`, alamat unduhan, penanda keamanan (checksum), dan layar unduhan pertama. Itu ketergantungan internet kedua selain BMKG.
- Perkiraan ukuran (SUSPECTED): model YOLO11n sekitar 3 MB (int8) sampai 10 MB (float32). APK rilis aplikasi ini diperkirakan 15 sampai 20 MB, jadi model fp16 menambah sekitar 30 sampai 50%. Masih jauh di bawah batas toko aplikasi.
- Ada aturan `*.tflite filter=lfs` di `.gitattributes`, tetapi CI tidak mengambil LFS. Bila model suatu saat di-commit, CI hanya akan menerima file penunjuk. Cukup catat ini saat pekerjaan AI dimulai.

### Tujuan 5: mobile first

Verdict: **sebagian**. Kekuatan: tata letak bertahan di layar 320×568 dengan teks 2×, keyboard ditangani, daftar punya keadaan memuat, kosong, dan galat yang seragam, tombol simpan nonaktif saat menyimpan, dan form login menjadi contoh baik.

| Kode | Temuan | Tingkat |
|---|---|---|
| F4-1 | Palet warna tema gagal kontras WCAG AA. Contoh: putih di atas hijau mint 2,09:1; "Stok Menipis" jingga 2,10:1; garis kolom isian 1,24:1. Palet kedua (`AppSurfaceColors`) sudah lulus, tetapi hanya dipakai 24 dari sekitar 76 file | Tinggi |
| F4-2 | Keyboard angka tidak tepat untuk desimal, dan tidak ada pemformat yang menegakkan aturan "paling banyak 2 desimal". Sebagian layar menerima koma, sebagian menolak | Sedang |
| F4-3 | Dua sistem warna, tiga gaya formulir, banyak widget kembar | Sedang |
| F4-4 | Pemilih tanggal tampil berbahasa Inggris karena lokalisasi belum dipasang | Sedang |
| F4-5 | Sesi di memori saja; Android mematikan aplikasi latar di ponsel 3 GB | Sedang |
| F4-7 | Target sentuh 44 dp (di bawah 48), teks 10 sampai 11 sp, tujuh tombol ikon tanpa tooltip | Sedang |
| F4-8 | Efek kaca buram di bilah navigasi dan header pada setiap layar utama: berpotensi berat di GPU lama (belum diukur) | Sedang |
| F4-9 | Gambar login 1,3 MB dan 1,5 MB didekode penuh; sekitar 6 MB RAM | Rendah |
| F4-10 | Pindah tab menghapus keadaan; letak tombol Simpan berbeda antar-formulir | Rendah |
| F4-11 | Sebagian teks galat berbahasa pengembang; satu layar menampilkan `$e` mentah | Rendah |
| F4-12 | Logout dan "Hapus Batch" tanpa konfirmasi | Rendah |
| F4-13 | Layar bisa diputar ke landscape; versi minimum Android belum dipatok ke 26 | Rendah |

Pemeriksa F4 tidak menjalankan aplikasi; temuan tata letak yang tidak bisa dipastikan dari kode ditandai `SUSPECTED`.

### Tujuan 7: monorepo

| Kode | Temuan | Tingkat |
|---|---|---|
| F1-1 | CI hanya menjalankan analisis dan tes Flutter. Tes backend (319), lint, dan pemeriksaan tipe tidak dijalankan. Perubahan backend yang merusak rute tanpa tes alur Flutter tetap lolos CI | Tinggi |
| F1-2 | Kontrak API ditulis dua kali (TypeScript dan Dart manual). 59 kunci JSON disalin tangan di 26 file Dart; `API.md` tidak ditaut dari README mana pun | Tinggi |
| F1-3 | Tidak ada perintah tunggal untuk memasang atau memeriksa semuanya. `package-lock.json` di root hanya stub 95 byte tanpa `package.json`. Tidak satu pun README mendokumentasikan perintah tes atau lint | Sedang |
| F1-15 | `outofthebox/`, `yeonworks/`, `AGENTS.md`, `CLAUDE.md`, `skills-lock.json` masih terlacak. Folder `assets/` 20 MB belum terlacak dan belum diabaikan: `git add .` akan memasukkan 20 MB salinan | Rendah |
| F1-16 | `.gitignore` 507 baris dari tiga templat; aturan `.env.*` menyembunyikan `.env.turso.example`. Tidak ada `.editorconfig` | Rendah |
| F1-17 | Versi Node dan Flutter hanya dipatok di CI; `ml/requirements.txt` tanpa versi | Rendah |
| F1-19 | Dua panduan setup backend yang tumpang tindih; daftar variabel `.env` kurang tiga; folder `macos`, `linux`, `web` (41 file) tidak dipakai | Rendah |

**Yang sudah baik:** semua dependensi dipakai, versi backend dipatok persis, dua lock file terlacak dan dipaksa di CI, tidak ada rahasia yang terlacak, folder hasil pembangkitan diabaikan. Nx atau Turborepo **tidak** diperlukan untuk dua aplikasi.

### Tujuan 8: MVC

Peta yang jujur:

| Peran | Aplikasi Flutter | Backend |
|---|---|---|
| Model | `lib/data/models`, `repositories`, `services`; `lib/models` (UI) | `service.ts` (aturan), `store.ts` (SQL), `common/*`, `migrations/` |
| View | `lib/views/pages`, `components`, `widgets` | Pemeta `*Response` di `store.ts` (JSON yang dikirim) |
| Controller | `lib/viewmodels` (Riverpod, ini **MVVM**) | Berkas rute (`index.ts`), `contracts.ts`, `write.ts` |

Kesimpulan: tujuan "MVC" terpenuhi sebagian dan paling banyak dengan penamaan ulang. Flutter dengan Riverpod adalah MVVM, bentuk MVC di Flutter, dan backend berpola irisan vertikal per fitur. Yang kurang adalah dokumen yang menjelaskan pemetaan ini.

| Kode | Temuan | Tingkat |
|---|---|---|
| F1-4 | Tidak ada penjelasan pemetaan MVC; mobile berpola MVVM dengan dua tata letak folder | Tinggi |
| F1-5 | View memegang aturan bisnis: aturan 15 dan 45 hari ada di sheet pemindahan, 66 pemeriksaan izin di 21 file view | Tinggi |
| F1-6 | Arah ketergantungan terbalik: repositori akun mengimpor view model; tujuh provider repositori tersebar di berkas view model | Sedang |
| F1-7 | Lapisan data memformat teks untuk UI; satu view model menyimpan string tampilan sebagai data | Sedang |
| F1-8 | Backend punya tiga tata letak irisan; 41 pernyataan SQL di 12 berkas rute; keputusan bisnis di `store.ts` | Sedang |
| F1-9 | Satu konsep ada dua kali di dua tata letak (`lib/models` vs `lib/data/models`, `lib/features` vs `lib/views`) | Sedang |

Jalur termurah: satu halaman `ARCHITECTURE.md` berisi tabel di atas, satu diagram kotak, dan kalimat "sisi Flutter adalah MVVM, ViewModel berperan sebagai Controller". Lalu pindahkan 13 file `features/*` ke folder berlapis. Tidak perlu menulis ulang.

### Tujuan 9: ukuran file dan keberlebihan

| Ukuran | Backend `src` | Aplikasi `lib` |
|---|---|---|
| Jumlah file | 88 | 143 |
| Lebih dari 200 baris | 1 (`seed.ts`, 215) | 38 |
| Lebih dari 300 baris | 0 | **30** (12.845 baris, 55% kode) |
| Tes lebih dari 300 baris | 3 dari 47 | 18 dari 53 |

Lima file terbesar: `inventaris_body.dart` 653, `add_form_inventaris_page.dart` 630, `catat_penjualan_body.dart` 582, `dashboard_body.dart` 540, `seedling_transfer_sheet.dart` 513.

| Kode | Temuan | Tingkat |
|---|---|---|
| F3-1 | 30 file di atas 300 baris | Tinggi |
| F3-2 | 12 file terbesar masing-masing mencampur 3 sampai 5 urusan (tata letak, state, validasi, jaringan). Rencana pemecahan per file ada di lampiran F3; tes tidak menghalangi karena tidak ada yang mengimpor nama privat | Tinggi |
| F3-6 | Salinan "inventaris" dari widget bersama (`InventoryNotice`, `InventoryEmpty`, dan lainnya), ±260 baris | Tinggi |
| F3-7 | Kerangka layar daftar disalin ke lima body | Tinggi |
| F3-10 | Logika "perintah tertunda" dan penggolongan galat disalin ke enam view model | Tinggi |
| F3-3 | 14 file yatim, 1.073 baris | Sedang |
| F3-4 | Layar inventaris lama (`ConnectedInventoryPage`) tidak pernah terbuka di aplikasi | Sedang |
| F3-5 | Model tiruan `MejaNft` dan `SeedingBatch` dengan cabang yang tidak dijangkau | Sedang |
| F3-8, F3-9, F3-11 | Formulir, pemilih, lembar modal, gerbang izin (74 pemeriksaan di 25 file), pemuatan halaman, dan validasi ID disalin per layar | Sedang |
| F1-11 | Layanan "A/B testing" dengan satu varian yang dikunci dan tidak mengirim apa pun | Sedang |
| F3-12, F3-13 | Anggota mati; pembungkus yang hanya meneruskan; dua proyeksi penjualan | Rendah sampai sedang |

**Backend memenuhi tujuan ini**: tidak ada file di atas 300 baris. Duplikasi dan kode mati backend dibahas di audit sebelumnya.

### Tujuan 10 dan 11: komentar dan keterbacaan

| Ukuran | Backend | Aplikasi |
|---|---|---|
| Baris komentar | 133 dari 4.613 (2,9%) | 237 dari 23.199 (1,0%) |
| File tanpa satu pun komentar | 50 dari 88 | 82 dari 143 |
| Penangan rute yang berkomentar | 4 dari 60 | tidak berlaku |
| Pernyataan SQL yang berkomentar | 3 dari sekitar 138 | tidak berlaku |

Yang ada berkualitas baik tetapi hanya mencakup keamanan dan konkurensi. Aturan domain dari rencana (batch, HSS, 15 hari semai, 45 hari panen, 250 lubang, buku stok) **tidak** dijelaskan di kode mana pun. Kata HSS dan HST tidak didefinisikan di repositori; HST hanya bisa ditebak dari kode.

| Kode | Temuan | Tingkat |
|---|---|---|
| F5-1 | Aturan bisnis inti tanpa komentar di kedua aplikasi | Tinggi |
| F5-2 | Tidak ada dokumen titik masuk atau daftar istilah. `GLOSSARY.md` dihapus 2026-10-28 dan hanya memuat 5 istilah stok | Tinggi |
| F5-3 | Pola perintah ulang aman muncul di enam view model, kata `uncertain` 45 kali, tanpa satu penjelasan; pembaca yang mencari "antrean offline" tidak akan menemukannya karena memang tidak ada | Tinggi |
| F5-4 | `executeOperation` di `sync.ts`: 70 baris, sekitar 28 cabang, tanpa komentar fungsi | Tinggi |
| F5-5 | Angka 15 dan 45 muncul sebagai angka telanjang di 9 tempat di dua bahasa pemrograman | Sedang |
| F5-6 | 18 baris backend di atas 160 karakter, 7 dari 15 terpanjang ada di panen; satu baris 404 karakter | Sedang |
| F5-7 | Komentar usang atau salah: merujuk `docs/database/` dan kode tiket B006 yang dokumennya sudah dihapus, blok `if` berisi komentar saja, instruksi untuk manusia yang tertinggal | Sedang |
| F5-8 | Tidak ada aturan bahasa komentar: backend Inggris, aplikasi campuran (10 file bercampur dalam satu file) | Sedang |
| F5-10 | Satu konsep, tiga sampai empat nama (`penyemaian`/`nursery`/`sowing`/`seeding`/`seedling`) | Sedang |

**Lima alur diperiksa** (login, catat stok masuk, buat penyemaian, pindah ke meja, panen lalu jual): jalur terpanjang adalah penyemaian, 15 lompatan antar-file. Backend umumnya mudah sampai sedang; sisi aplikasi umumnya sulit. Penjelasan satu halaman untuk tiap alur dalam bahasa sehari-hari sudah disusun pemeriksa F5 di lampiran dan bisa langsung dipakai sebagai dokumen alur.

Standar komentar yang diusulkan (satu halaman, belum diterapkan): komentar berbahasa Indonesia, tiga format (fungsi, aturan bisnis, SQL), identitas kode dan kode galat tetap bahasa Inggris, dan kata domain Indonesia (`penyemaian`, `pemindahan`, `meja_tanam`) tidak diubah di batas data. Tiga contoh sebelum dan sesudah dari kode asli ada di lampiran F5.

---

## 4. Empat pertentangan di dalam rencana yang perlu diputuskan

Pemeriksa menemukan bahwa dokumen rencana dan tujuan tim tidak sepenuhnya selaras. Ini bukan kesalahan kode, tetapi keputusan yang menentukan banyak pekerjaan lain.

**1. Di mana backend berjalan, dan apakah internet dibutuhkan untuk sinkronisasi?**

| Bagian rencana | Isi |
|---|---|
| Software Interfaces | SQLite di ponsel, **Turso** sebagai basis data pusat, backend untuk BMKG dan proses bisnis, Cloudinary untuk gambar. Ini model server pusat di internet |
| Constraints (baris 417) | "Sistem membutuhkan koneksi internet untuk **sinkronisasi data** dan mengakses API BMKG". Bertentangan dengan tujuan 2 |
| Design Constraints | Delapan fitur harus bisa dicatat offline dan disinkronkan otomatis. Ini offline first |

Tiga pembacaan yang mungkin:

| Pembacaan | Artinya |
|---|---|
| Server pusat (serverless + Turso, keputusanmu sebelumnya) | Ponsel menyimpan data lokal dan menyinkronkan lewat internet. "Internet hanya untuk BMKG" lalu berarti: pencatatan harian tanpa internet, sinkronisasi dan BMKG dan gambar butuh internet |
| Server di laptop kebun | Backend berjalan di laptop atau mini PC di kebun lewat Wi-Fi tanpa internet. Aplikasi perlu dukungan alamat LAN (F2-07) |
| Hanya di ponsel | Tidak mungkin: Node tidak berjalan di ponsel, dan petani serta pegawai di ponsel berbeda tidak akan berbagi data |

Kode saat ini diam-diam memilih model pertama (versi rilis hanya menerima HTTPS yang ditetapkan saat build).

**2. Model AI: diunduh dulu (tujuan 3) atau ditanam (tujuan 6)?** Ditanam di APK tidak butuh unduhan, karena memasang APK adalah satu-satunya unduhan. Keduanya tidak bisa sekaligus tanpa ada perbedaan makna.

**3. BMKG lewat backend atau langsung dari aplikasi?** Rencana menyebut backend sebagai pengintegrasi BMKG; kode memanggil BMKG langsung dari aplikasi. Pemeriksa menilai cara langsung lebih cocok dengan "internet hanya untuk BMKG". Cukup ubah satu baris di dokumen rencana.

**4. "MVC" apakah harus berarti struktur MVC murni?** Flutter dengan Riverpod adalah MVVM. Tim perlu memutuskan apakah dokumen pemetaan sudah cukup, atau struktur memang akan diubah.

---

## 5. Rencana kerja yang saya sarankan

Urutan dari yang paling murah dan paling berisiko dikoreksi. Perkiraan waktu berasal dari pemeriksa.

### Tahap A: hari ini sampai besok (sekitar 2 hari, tanpa keputusan baru)

| # | Pekerjaan | Rujukan | Waktu |
|---|---|---|---|
| 1 | Perbaiki kunci anti-duplikat penjualan; salin probe pemeriksa menjadi tes | F2-04 | 3 sampai 4 jam |
| 2 | Tambah job backend di CI (`npm run check`) | F1-1 | 30 menit |
| 3 | Root `package.json` dengan skrip `setup` dan `check`; hapus lock file stub; bagian "Cara memeriksa" di README | F1-3 | 1 sampai 2 jam |
| 4 | Hapus 14 file yatim, layar inventaris lama, dua model tiruan beserta cabangnya, layanan A/B | F3-3, F3-4, F3-5, F1-11 | sekitar 1 hari |
| 5 | Tulis `docs/ARCHITECTURE.md` (peta MVC, diagram, daftar istilah, lima alur) memakai bahan pemeriksa F5 dan F1 | F1-4, F5-2 | 0,5 hari |
| 6 | Komentar untuk 25 blok teratas di backend, dimulai dari `sync.ts`; satukan angka 15 dan 45 menjadi konstanta | F5-1, F5-4, F5-5 | 1 sampai 2 hari |
| 7 | Perbaikan kecil backend dari audit sebelumnya: target absolut melewati kuota (A1), rollback salah sasaran (B1), dan seterusnya | `laporan-review-kode-backend.md` bagian 8 | 0,5 hari |

### Tahap B: setelah keputusan di bagian 4

| # | Pekerjaan | Waktu |
|---|---|---|
| 8 | Fondasi offline first: satukan enam kelas perintah tertunda menjadi satu, simpan sesi, SQLite lokal, antrean, pengirim, tarik perubahan | 3 sampai 4 minggu (semua bagian) |
| 9 | Siapkan sisi server: isi data di daftar perubahan, kuota per pengguna, rujukan induk lewat `public_id` | 3 sampai 5 hari |
| 10 | Kirim `expected_version` dari lima fitur, baca `version` di penyemaian, tangani konflik | 1 hari |

### Tahap C: kebersihan aplikasi (boleh paralel dengan Tahap B)

| # | Pekerjaan | Waktu |
|---|---|---|
| 11 | Widget bersama: `FloatingActionBar`, `FilterChipRow`, `RefreshableListScaffold`, `OptionPickerSheet`, `ModalSheetScaffold`, `showAppDatePicker`, `PermissionGate`, `getAllPages` | 3 sampai 4 hari; sekaligus mengurangi 60 sampai 90 baris per layar |
| 12 | Pecah 12 file terbesar sesuai rencana F3-2 | 5 sampai 8 hari |
| 13 | Pindahkan `features/*` ke tata letak berlapis dan satukan provider di `lib/data/providers.dart` | 1 hari |
| 14 | Pindahkan aturan bisnis dari view ke view model | 2 sampai 3 hari |

### Tahap D: kenyamanan layar

| # | Pekerjaan | Waktu |
|---|---|---|
| 15 | Samakan palet ke `AppSurfaceColors` dan perbaiki kontras | 1 hari |
| 16 | Satu `DecimalField`, pemformat angka, lokalisasi Indonesia, tooltip, target 48 dp | 1,5 hari |
| 17 | Konfirmasi logout dan "Hapus Batch"; kunci portrait; pin `minSdk = 26`; ukur efek kaca di perangkat 3 GB | 0,5 hari |

**Jujur tentang waktu:** Tahap A selesai dalam 2 hari. Tahap B saja memakan 3 sampai 4 minggu menurut pemeriksa, sedangkan penyerahan 28 November tinggal 23 hari dan Tahap C dan D memerlukan 15 hari atau lebih untuk satu orang. Tidak semuanya muat. Pilihan yang saya sarankan: kerjakan Tahap A penuh, lalu putuskan bersama Product Owner apakah offline first penuh masuk 28 November atau ditunda, dengan potongan minimum yang tetap berguna: sesi tersimpan, draf dan antrean tulis tersimpan, dan salinan baca untuk daftar utama. Perkiraan potongan itu perlu dihitung ulang setelah keputusan nomor 1.

---

## 6. Keputusan yang saya butuhkan darimu

1. Backend berjalan di mana, dan apa arti "internet hanya untuk BMKG" (bagian 4, nomor 1)?
2. Model AI ditanam atau diunduh (nomor 2)?
3. Apakah dokumen pemetaan MVC cukup (nomor 4)?
4. Seberapa banyak offline first yang harus masuk sebelum 28 November?
5. Apakah aturan 200 sampai 300 baris juga berlaku untuk tes? (18 tes aplikasi dan 3 tes backend lebih dari 300 baris; tiga terbesar sekitar 3× batas.)
6. Setuju komentar berbahasa Indonesia (rekomendasi pemeriksa)?

---

## 7. Catatan kebersihan

- Seorang pemeriksa meninggalkan file `apps/nocomment.tmp` (sudah dihapus pemeriksa itu) dan satu file `apps/160` (6 byte, kata "count"; saya hapus). Keduanya hasil perintah salah kutip, bukan bagian pekerjaanmu. Tidak ada file lain di repositori yang berubah karena review ini.
- `726fc64` (commit lokal "berhenti melacak file agen") masih **belum di-push**.
- `yeonworks/review-backend-hidrosense.md` sudah kamu pindahkan ke `review-learn/`; dua tautan yang putus sudah saya perbaiki.
- Folder `yeonworks/review-learn/` dan laporan ini belum di-commit.

## 8. Lampiran

Folder `lampiran-2026-11-05/`:

| File | Isi |
|---|---|
| `slice-F1.md` | Monorepo, MVC, keberlebihan |
| `slice-F2.md` | Offline first, BMKG, kesiapan AI, kecocokan kontrak |
| `slice-F3.md` | Ukuran file, rencana pemecahan 12 file, kode berulang dan mati |
| `slice-F4.md` | Mobile first dan kontras warna terhitung |
| `slice-F5.md` | Komentar, lima alur, 25 blok teratas per aplikasi, glosarium, standar komentar |
| `probe-f2/` | Dua tes Flutter pembuktian milik pemeriksa F2 (penjualan menggandakan, login offline) |
