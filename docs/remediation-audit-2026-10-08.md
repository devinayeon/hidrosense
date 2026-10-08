# Hasil remediasi HidroSense

Implementasi pada baseline HEAD `0a6ddd0`, 8 Oktober 2026. Tidak dibuat commit atau deployment. Source backend/mobile bersih saat baseline; graf dan sejumlah file untracked sudah ada sebelum pekerjaan ini dan tidak dibersihkan.

## Status temuan

| Temuan | Status | Bukti dan batas |
| --- | --- | --- |
| P1: kontrak/API panen dan penjualan belum tersedia | Ditunda sesuai keputusan pengguna | [Blueprint sprint berikutnya](backend-harvest-sales-blueprint.md). Tabel dasar tersedia; endpoint dan koneksi mobile belum dibuat. |
| P2: kerusakan mobile terputus | Selesai pada lingkup remediasi | UI memakai batch pemindahan nyata, GET seluruh halaman, POST kerusakan, baca ulang laporan dan kapasitas. Tes HTTP+UI pada backend nyata membuktikan persistensi. |
| P3: limit inventaris tidak dibatasi | Tidak terbukti; regresi ditambahkan | Parser bersama sudah membatasi 100. Default 20 dan limit 100 diterima; 101, 0, -1, 1.5, 999999, leading zero dan newline ditolak 400. Tidak mengganti parser dengan coercion. |

Petani memperoleh `budidaya:write` untuk seluruh budidaya. Route guards dan pemeriksaan dalam `authenticatedWrite` tetap dipakai. Petani/pegawai dapat membuat atau mengubah meja, pemindahan, dan kerusakan. Tes penolakan sesi anonim serta akun nonaktif tetap lulus. Pegawai tidak memperoleh izin penjualan.

## Matriks konektivitas

| Area | Jalur aktual | Bukti | Status |
| --- | --- | --- | --- |
| Inventaris | `InventoryRepository` → `ConnectedInventoryViewModel` → daftar/bottom sheet | Tes UI → HTTP backend → POST deactivate → GET detail dari sesi baru: `status_aktif=0`; state dan SQLite cache kosong | Terhubung dan persistensi arsip terverifikasi |
| Meja | repository/connected table → detail meja → GET meja | Tes detail meja menunjukkan 195/250 setelah kerusakan; GET backend kapasitas tersedia 55 | Terhubung pada alur yang diuji |
| Pemindahan | GET `pemindahan?id_meja=...`, semua halaman | Tes repository filter, pagination, ID string; tes HTTP membaca batch nyata sebelum/sesudah POST | Terhubung pada pembacaan batch kerusakan; alur transfer existing tetap lulus |
| Kerusakan | `DamageRepository` → `DamageViewModel` → batch/form | UI mengirim 5 tanaman; sesi baru membaca laporan dan batch aktif 195 dari 200; kembali ke meja dan membuka ulang laporan berhasil | Terhubung, tersimpan, kapasitas diperbarui |
| Panen | UI/domain legacy; tabel header/detail tersedia | Tidak ada endpoint domain baru dalam remediasi | Blueprint/backlog, belum dinyatakan terhubung |
| Penjualan | UI legacy; access guards sesi | Tes pegawai: tab, kartu dashboard, halaman/form langsung tidak membangun konten penjualan | Izin diperbaiki; persistensi penjualan belum terhubung |

Bukti persistensi memakai Fastify dan LibSQL fixture nyata pada localhost dengan database terisolasi, serta SQLite FFI cache mobile. Ini bukan pengujian perangkat fisik atau database produksi/Turso live.

## Perubahan penting

- Payload kerusakan mengikuti `id_pemindahan`, `tanggal_kejadian`, `jumlah_tanaman`, `jenis_kerusakan`, dan `keterangan`. ID domain string; UUID hanya sebagai `Idempotency-Key`.
- Submit ganda ditolak. Retry jaringan memakai payload/UUID yang sama; isian berubah membuat UUID baru. Retry hasil tidak pasti tetap bisa mereplay command yang sama setelah reload kapasitas menjadi nol. Konflik `DAMAGE_EXCEEDS_ACTIVE` memuat ulang batch tanpa menghapus isian.
- Tanggal dibatasi antara tanggal pemindahan dan hari ini Asia/Jakarta; jumlah dibatasi tanaman aktif. Backend tetap memvalidasi transaksi.
- POST berhasil diikuti refresh laporan, batch dan kapasitas meja. Kegagalan refresh menampilkan pesan bahwa laporan sudah tersimpan; receipt lokal mencegah POST ulang. Perubahan sesi membuang provider lama; respons setelah disposal diabaikan.
- Form tidak lagi memiliki lubang/baris fiktif atau kontrol foto. Tidak ada antrean offline.
- Inventaris mempertahankan bottom sheet dan endpoint deactivation. ViewModel memiliki satu refresh; repository hanya melakukan POST deactivation. Messenger/notifier ditangkap sebelum dialog/sheet ditutup dan completion memeriksa mounted.
- Tab MainPage dan daftar bottom navigation berasal dari daftar yang sama. Indeks negatif/tidak tersedia atau izin penjualan yang hilang kembali ke Beranda; tiga indeks awal tetap sama. Dashboard dan halaman/form langsung memeriksa permissions.
- Diagnostik analyzer ditangani: import, underscore, null-aware elements, `withValues(alpha: ...)`, braces dan context async. Tidak ada migrasi atau dependency baru.

## Ponytail-review

Hapus halaman `info_item_inventaris_page.dart` tanpa pemanggil, mock `inventaris_viewmodel.dart`, `meja_nft_viewmodel.dart`, `penyemaian_viewmodel.dart`, serta model/ViewModel/widget baris tanam yang kehilangan konsumen setelah kerusakan memakai batch nyata. Hapus refresh deactivation duplikat. Pencarian simbol dan analyzer tidak menemukan dangling import. Tidak memperkenalkan abstraction layer atau tabel pengganti.

Review terpisah menemukan replay jaringan yang dapat tertahan ketika kapasitas sudah berkurang setelah commit. Perbaikan menggunakan exact normalized payload dan UUID sebelumnya, dengan regresi di ViewModel dan UI. Tidak ada temuan review yang masih terbuka pada lingkup tersebut.

## Telemetry verifikasi

| Pemeriksaan | Baseline | Hasil akhir |
| --- | --- | --- |
| Backend `npm run check` | 201/201 tes | 202/202 tes; typecheck dan batas 400 baris lulus |
| Mobile `flutter test --no-pub` | 84/84 tes | 113/113 tes lulus |
| `flutter analyze --no-pub` | 1 warning, 29 info | 0 diagnostik |
| `flutter build apk --debug --no-pub` | Tidak dijadikan baseline | Lulus, `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk` |
| `git diff --check` | Source bersih | Lulus |

Tes baru: `inventory-pagination.test.js`; mobile `damage_repository_test.dart`, `damage_viewmodel_test.dart`, `damage_flow_test.dart`, `damage_backend_flow_test.dart`, `inventory_archive_test.dart`, dan `sales_access_test.dart`. Tes HTTP mobile memerlukan dependency backend terpasang dan Node yang sesuai `apps/backend/package.json`; menjalankan fixture sendiri pada port ephemeral.

Skenario mencakup mapping/filter/pagination, response 201/200 replay, refresh token, payload/UUID retry, submit bersamaan, perubahan kapasitas, tanggal salah, izin baca/tulis, session switch, disposal saat GET/POST, POST sukses dengan refresh gagal, cache SQLite, navigasi tanpa izin dan indeks tab invalid. Tes arsip terpisah menghitung tepat satu POST dan satu GET refresh; kegagalan POST mempertahankan data dan tidak memicu refresh.

## Bukti layar dan Delivery Gate antislop

Lingkup gate: form/batch kerusakan dan kontrol/navigasi yang berubah. Halaman panen/penjualan legacy tidak diklaim siap sebagai fitur persistensi. Arah mengikuti keputusan pengguna untuk mempertahankan tema dan pola interaksi HidroSense: canvas hangat, tipografi Inter, navy dan aksen lime pada aksi simpan. ENERGY 1 / RHYTHM 2 / MOTION 1: pencatatan operasional, satu kartu per batch, hanya feedback/transisi existing.

Alasan keputusan: kartu mengelompokkan satu batch beserta laporan; tanggal dan jumlah aktif tampil sebagai teks lengkap agar dapat dibaca pada teks besar; spacing 16/20 memisahkan konteks dan isian; navy/lime menandai aksi simpan dengan kontras 13.11:1; label menyebut aksi domain; ikon kalender membuka pemilih tanggal, back kembali, dan akun membuka halaman akun. Tidak membuat aset visual baru.

Tes `damage_flow_test.dart` menjalankan ukuran 320×568, text scale 2, light/dark, fokus keyboard dan validasi tanpa overflow exception. Target simpan diuji ≥44; simpan minimum 52, tombol tanggal/batch 48, back dan akun 44. `damage_backend_flow_test.dart` melakukan click-through detail meja → batch → form → tanggal → simpan → kembali → buka ulang laporan, lalu daftar inventaris → bottom sheet → dialog arsip → simpan.

Screenshot verifikasi tersedia di `apps/mobile/build/remediation-verification/`: `damage-light-large-text.png`, `damage-dark-large-text.png`, `damage-light-validation.png`, dan `damage-dark-validation.png`. Rekam ulang dengan `RECORD_REMEDIATION_UI=1 flutter test test/damage_flow_test.dart`. Capture test di Windows menggunakan Segoe UI sebagai pengganti font test agar teks terbaca; produksi tetap memakai tema/font existing. Gambar diperiksa secara visual; label jumlah/keterangan, kategori lengkap dan error jumlah dapat dibaca melalui scroll. Log suite tersimpan di `apps/mobile/build/remediation-test-output.txt`.

### Hard Gate

- R-02 PASS: copy baru tidak memakai em dash.
- R-03 PASS: tes 320×568/200% light/dark tanpa overflow; label/error yang semula terpotong diperbaiki dan screenshot diperiksa.
- R-17 PASS: jumlah aktif/kapasitas berasal dari API; angka contoh hanya fixture pengujian.
- R-18 PASS: tidak menambah testimonial atau profil fiktif.
- R-23 PASS: tidak menambah aset; tab permission filtering merupakan bagian rencana pengguna.
- R-24 PASS: tab menggunakan daftar halaman yang sama; tes invalid index dan izin hilang kembali ke Beranda.
- R-25 PASS: checker navy/lime 13.11:1, primary text/canvas 16.96:1, secondary text/white 4.83:1; dark memakai semantic colors Material dan diperiksa pada screenshot.
- R-26 PASS: submit/refresh/date/batch/back menjalankan handler; POST dan arsip benar-benar tersimpan pada tes HTTP.
- R-27 PASS: loading/error/retry/empty/submitting ditampilkan dan diuji; hasil tersimpan dengan refresh gagal memiliki pesan terpisah.
- R-28 PASS: tidak ada FAQ pada layar lingkup remediasi.
- R-32 PASS: form Material/dropdown/button mendukung fokus keyboard; tes Tab mempunyai primary focus; back/akun memakai InkWell dengan feedback/fokus Material.
- R-33 PASS: perubahan berada di source Dart/TypeScript; helper capture hanya membaca render tree dalam test.
- R-34 PASS: form diuji light/dark pada ukuran kecil/teks besar tanpa exception; tema existing dipertahankan.
- R-35 PASS: 113 tes mobile, APK debug dan click-through HTTP nyata lulus; handler UI arsip diuji sesudah sheet ditutup.
- R-36 PASS: tidak menambah klaim keamanan/performa; laporan membatasi bukti pada fixture dan tes yang dijalankan.
- R-37 PASS: arah menggunakan tema/pola interaksi existing yang diminta pengguna; dials dan alasan dicatat di atas.
- R-38 PASS: baris/lubang/foto fiktif dihapus; batch dan laporan baru berasal dari backend.

### Purpose Gate

- R-01 PASS: tidak menambah gradient/glow.
- R-04 PASS: ikon kalender/back/akun memiliki aksi domain yang disebutkan di atas; tidak menambah ikon dekoratif.
- R-06 PASS: mempertahankan tipografi tema untuk konsistensi; tidak menambah monospace atau label tracking lebar.
- R-07 PASS: tidak menambah grid/dot/background dekoratif.
- R-08 PASS: panah back menjalankan navigasi, tidak menambah panah dekoratif pada tombol aksi.
- R-09 PASS: tidak menambah badge promosi.
- R-10 PASS: tidak menambah glassmorphism.
- R-12 PASS: kartu menggunakan elevasi tema existing untuk kelompok batch; tidak menambah shadow besar.
- R-13 PASS: tidak menambah glow.
- R-14 PASS: kartu batch konsisten karena masing-masing merepresentasikan transfer; tinggi mengikuti jumlah laporan aktual.
- R-19 PASS: tidak menambah animasi template; MOTION 1 sesuai transisi dan feedback Material existing.
- R-22 PASS: tidak menambah ilustrasi generik.

### Liveliness

- Dials PASS: ENERGY 1 / RHYTHM 2 / MOTION 1 dinyatakan untuk pencatatan operasional.
- Konsistensi PASS: screenshot menunjukkan form tenang, konteks batch terpisah dan feedback aksi; tidak menambah choreography.
- Focal point PASS: form memiliki satu aksi simpan; batch mengutamakan jumlah aktif dan laporan tersimpan.
- Whitespace PASS: padding 20 dan gap 16 memisahkan konteks/isian serta laporan di dalam kartu.
- Accent PASS: lime pada aksi simpan memakai navy agar kontras jelas; token brand existing dipertahankan.
- Motif PASS: navy/lime, tipografi tema dan nama meja/batch mengikat layar dengan HidroSense existing.
- Design Read PASS: arah berasal dari instruksi mempertahankan tema dan interaksi; alasan perubahan tertulis sebelum serah-terima.

### Craftsmanship dan quality locks

- C-1 PASS: alasan warna, kartu, teks lengkap, spacing dan ikon tercatat; tanpa keputusan dekoratif default.
- C-2 PASS: penyimpanan, tanggal, retry, navigasi dan arsip mempunyai handler yang diuji.
- C-3 PASS: komposisi berasal dari meja → batch → laporan; section/mock tanpa konsumen dihapus.
- C-4 PASS: small screen/large text/themes/loading/errors/submitting/session disposal diuji tanpa exception.
- C-5 PASS: bukti HTTP/backend/cache dipisahkan dari domain backlog; tidak mengklaim koneksi panen/penjualan.
- R-05 PASS: hierarki data operasional, tanpa hero/marketing/template sections.
- R-11 PASS: kartu/input memakai radius tema; tombol date dan aksi Material mempunyai bentuk berbeda.
- R-15 PASS: CTA menyebut `Catat Kerusakan`, `Simpan Laporan Kerusakan`, `Muat ulang batch`, dan `Arsipkan`.
- R-16 PASS: copy baru berupa petunjuk/status konkret tanpa buzzword pemasaran.
- R-20 PASS: nama meja, batch pemindahan, jumlah tanaman dan identitas tema mengikuti produk HidroSense.
- R-21 PASS: tidak memaksa default dark atau mengganti pengaturan tema; form mendukung kedua mode yang diuji.
- R-29 PASS: token brand existing navy/teal dan satu aksen lime; error memakai warna semantik.
- R-30 PASS: tidak mengadopsi tampilan produk lain.
- R-31 PASS: alasan keputusan visual utama dicatat dalam paragraf di atas.

## Graf dan backlog

`graphify update .` memperbarui graf kode melalui AST, tanpa token/API LLM. Pembaruan juga memangkas source yang dihapus. SQL tidak diekstrak karena `tree_sitter_sql` tidak tersedia; migrasi dibaca langsung untuk blueprint. Header C++ Linux existing memiliki satu syntax warning dari parser. Nama komunitas dapat berubah mengikuti hub; tidak menjalankan pelabelan LLM. Dokumen baru belum diklaim mempunyai semantic extraction.

Backlog: implementasi blueprint panen/penjualan beserta migrasi exact minor-unit dan sync registration, koneksi repository/ViewModel/UI kedua domain, keputusan izin panen petani, foto dengan kontrak storage/security tersendiri, serta pengujian perangkat fisik dan lingkungan deploy. Tidak ada antrean offline kerusakan dalam perubahan ini.
