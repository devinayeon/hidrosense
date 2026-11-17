# Progress — Slice desain v2 “02 Beranda & Notifikasi”

Catatan kerja untuk slice kedua desain v2 setelah
[`01 Onboarding & Auth`](./progress-v2-onboarding-auth.md) dan
[`progress-v2-login-session.md`](./progress-v2-login-session.md): beranda Petani
dan Pegawai, keadaan memuat/offline/BMKG gagal, notifikasi, dan detail siklus.

Terakhir diperbarui: 17 November 2026.

## Tujuan

1. Memotong page FigCraft `02 Beranda & Notifikasi` menjadi view Flutter di
   `apps/mobile/lib/views/v2`, sesuai catatan alur tiap frame.
2. Menyetel ulang widget shared (`V2TabBar`, `V2CycleRing`, `V2TimelineStep`,
   `V2WeatherCard`) supaya persis page ini / halaman `00 Foundations`, tanpa
   membuat varian duplikat.
3. Menyambungkan login sungguhan supaya sesi yang masuk mendarat di beranda v2.

## Aturan yang disepakati

- Semua kode view baru hanya di `apps/mobile/lib/views/v2`.
- Penyusun khusus halaman → `lib/views/v2/components/`; widget yang bisa
  dipakai halaman lain → `lib/views/v2/widgets/`.
- **Izin diminta lebih dulu** sebelum menambah/menyetel widget reusable.
  Hasil tanya-jawab: `V2WeatherCard` boleh dibuat sebagai widget shared (dipakai
  2.1, 2.6, dan nanti halaman 10), `V2GroupLabel` **tidak** boleh jadi shared →
  ditaruh di `components/`, dan penyetelan ulang `V2TabBar`, `V2CycleRing`,
  `V2TimelineStep` **boleh**.
- Tidak menambah file test baru ke suite; verifikasi tambahan memakai skrip
  sekali pakai yang langsung dihapus.
- Catatan progress/task di `apps/mobile/docs`; `graphify update .` dijalankan.

## Sumber desain dan spesifikasi ringkas

File `HidroSense Mobile UI v2`, page `02 Beranda & Notifikasi` (page id `5939`),
semua frame 390×844. Dibaca lewat MCP FigCraft (aplikasi di `localhost:7979`)
dan dicocokkan dengan ekstraksi CLI sebelumnya.

- `2.1 Beranda (Petani)` `5940`, `2.2 Beranda (Pegawai)` `6063`,
  `2.3 Beranda memuat` `6169`, `2.4 Notifikasi` `6234`,
  `2.5 Offline dan antrean sinkron` `6314`, `2.6 BMKG tidak tersedia` `6432`,
  `2.7 Detail siklus` `6555`; catatan alur `6623`–`6629`.
- FlowNote `6308`: “Beranda Petani dan Pegawai, memuat, notifikasi, offline dan
  antrean sinkron, BMKG tidak tersedia, detail siklus 60 hari. **Kartu cuaca
  hanya untuk Petani.**”
- Catatan alur: 2.1 “…Cuaca: halaman 10.”; 2.2 “tanpa cuaca, tab bar 4 tab”;
  2.3 “Sebelum 2.1 tampil. Rangka kartu.”; 2.4 “Dari bel di 2.1…”;
  2.5 “Dari 2.1 saat offline…” (antrean sinkron 11.4, status sinkron 11.1);
  2.6 “Dari 2.1 saat BMKG gagal. **Coba lagi kembali ke 2.1.**”;
  2.7 “Dari kartu siklus di 2.1. **Buka Meja A2 6.11.**” (koreksi dari `6.1`).
- Susunan frame: StatusBar 44 → jarak 16 → konten (beranda). Frame 2.4/2.7:
  StatusBar 44 → AppBar 64 → jarak 8 → konten. Konten padding horizontal 24;
  beranda jarak antar blok 16, notifikasi 8.
- TabBar: kontainer 390×106, sudut atas 24, border atas `#E5E8EC`; tab 56px,
  pil ikon 56×32 lime `#A3F533` (`r=pill`), ikon 24; label aktif 14/20
  SemiBold `#111827`, nonaktif 14/20 Medium `#6B7280`. Petani 5 tab
  (Beranda/Tanam/Stok/Rawat/Lainnya), Pegawai 4 tab (Beranda/Tanam/Stok/Profil).
- `ListItem` (terverifikasi, tidak diubah): 342×80, `r=24`, padding horizontal 16,
  gap 16, lead 48, chevron 24, tanpa shadow.
- `CycleRing`: `Size=Compact` 112 dengan stroke 12 (hero), `Size=Large` 224
  dengan stroke 20 (2.7). Hero: track putih 22%, jendela semai putih 30%,
  progres + cap lime, isi putih. 2.7: track `#E5E8EC` (gray200), jendela
  `#E3F5E1` (green100), progres `#1565FF` (blue500), cap bulat 20, tick HSS 15
  22×3 ink, unit 14/20 muted, nilai 34/40.
- `TimelineStep`: 342×56, marker 32, gap isi 16, **tidak ada garis penghubung**;
  langkah berjarak 8. Marker aktif = lingkaran border blue700 2px + sprout ink;
  selesai = green100 + centang; berikutnya = border slate400 kosong.
- `Legend` (2.7): tick 12×3 + teks 20, gap 8, rata tengah.
- Kartu cuaca: `Shadow/Card` (blur 24, offset 0,8). Hero biru `r=32` tanpa
  shadow.

## Peta file

Baru:

- `lib/views/v2/pages/v2_beranda_page.dart` — 2.1/2.2 + `V2BerandaState`
  (`ready`/`loading`/`offline`/`weatherUnavailable`) + `V2BerandaRole`
  (`petani`/`pegawai`), konstruktor bernama `.loading`, `.offline`,
  `.weatherUnavailable`.
- `lib/views/v2/pages/v2_notifications_page.dart` — 2.4 (`V2Notification`,
  `V2NotificationGroup`, `designGroups`).
- `lib/views/v2/pages/v2_cycle_detail_page.dart` — 2.7 (`V2CycleStep`,
  `designSteps`).
- `lib/views/v2/v2_ui_mode.dart` — `v2UiModeProvider` (`StateProvider<bool>`).
- `lib/views/v2/components/v2_beranda_hero.dart` — kartu hero siklus.
- `lib/views/v2/components/v2_beranda_stats.dart` — dua petak statistik.
- `lib/views/v2/components/v2_beranda_skeleton.dart` — rangka 2.3.
- `lib/views/v2/components/v2_group_label.dart` — label grup daftar.
- `lib/views/v2/components/v2_cycle_legend.dart` — keterangan tick 2.7.

Diubah:

- `lib/views/v2/widgets/v2_tab_bar.dart` — pil 56×32, ikon 24, label `V2Type.label`
  (14/20) SemiBold aktif / Medium nonaktif, warna ink vs `V2Colors.muted`.
- `lib/views/v2/widgets/v2_cycle_ring.dart` — ditulis ulang: parameter
  `strokeWidth`, `trackColor`, `windowColor`, `progressColor`, `contentColor`,
  `unitColor`, `valueStyle`, `tickValue`, `tickColor`; cap bulat pada progres;
  tick 22×3 opsional; gaya angka 28/36 (≤140) atau 34/40 (>140).
- `lib/views/v2/widgets/v2_timeline_step.dart` — tinggi 56, tanpa connector,
  tanpa `isLast`, marker 32 dengan border untuk aktif/berikutnya.
- `lib/views/v2/widgets/v2_checklist.dart` — `V2WeatherCard` diperluas dengan
  `V2WeatherCardState {available, unavailable}` + `onRetry` (lead amber dan
  tombol ghost “Coba lagi” pada `unavailable`).
- `lib/views/v2/theme/v2_tokens.dart` — `V2Shadow.card` diselaraskan ke
  Foundations (`blurRadius: 24, offset: Offset(0, 8)`).
- `lib/views/v2/components/v2_foundation_gallery.dart` — pratinjau
  `V2TimelineStep` menyesuaikan penghapusan `isLast`.
- `lib/views/pages/login_page.dart` — `_v2Login` menyalakan `v2UiModeProvider`
  setelah sesi sukses; `_submit` (form lama) mematikannya.
- `lib/views/pages/app_gate.dart` — memantau `v2UiModeProvider`; kunci
  `Navigator` dibuat ulang saat pengguna **atau** mode v2 berubah, lalu
  merutekan ke `V2BerandaPage` (nama + peran dari `SessionUser`).

## Keputusan penting

- **Beranda adalah satu halaman.** 2.3/2.5/2.6 adalah keadaan beranda, bukan
  halaman terpisah: satu `V2BerandaPage` dengan `V2BerandaState` dan konstruktor
  bernama per frame. “Coba lagi” di 2.6 kembali ke `ready` (sesuai catatan alur:
  kembali ke 2.1).
- **Hanya Petani melihat kartu cuaca.** Peran menentukan jumlah tab dan
  keberadaan kartu cuaca (2.1 vs 2.2) serta blok cuaca di rangka 2.3.
- **Izin widget.** Karena `V2WeatherCard` sudah ada di `v2_checklist.dart`
  (state Default), ia diperluas di tempat dengan `V2WeatherCardState` alih-alih
  membuat berkas/varian baru — sesuai izin yang diberikan.
- **Mode v2 dipisah dari sesi.** `v2UiModeProvider` sengaja terpisah supaya
  tombol “Coba tampilan v2” bisa membuka alur prototipe tanpa mengubah rute
  sesi. Hanya halaman login v2 yang menyalakannya; menekan tombol pratinjau
  tidak. Penandaan terjadi **sebelum** permintaan login dikirim dan
  dikembalikan kalau login gagal, sebab sesi bisa terpasang lebih dulu
  daripada kesempatan menyetel mode (lihat masalah nomor 6).
- **Kunci navigator memakai identitas.** `AppGate` membangun ulang `Navigator`
  saat `user.id` berubah, atau saat mode v2 berubah **dan** sudah ada pengguna.
  Mode yang ditandai selagi login berlangsung (sesi masih kosong) tidak boleh
  membangun ulang apa pun, karena itu akan membuang tumpukan pratinjau
  (onboarding + login) sebelum terlihat.
- **Gaya angka cincin ikut ukuran.** 112 memakai 28/36, 224 memakai 34/40,
  supaya satu widget menutupi hero dan halaman detail tanpa override manual.
- **Tautan alur yang belum ada** (tab lain, 5.16, 4.9, 6.11, halaman cuaca 10)
  sementara memunculkan `SnackBar` penanda, bukan navigasi palsu.

## Masalah yang ditemukan dan solusinya

1. **`const Offset` di painter cincin** memakai `radius` yang bukan konstanta →
   dua error `invalid_constant`. Solusi: `const` dilepas dari kedua `Offset`
   tick.
2. **`V2AppBar` butuh `Overlay`.** `IconButton` dengan `tooltip` (“Kembali”)
   menuntut leluhur `Overlay`; skrip render awal tidak punya `MaterialApp`
   sehingga halaman 2.4/2.7 gagal. Solusi: skrip membungkus halaman dengan
   `MaterialApp`. Bukan masalah produk.
3. **Metrik teks skrip render.** Tanpa memuat Poppins dan `MaterialIcons`, teks
   dan ikon jatuh ke font cadangan (ikon jadi kotak kosong). Solusi: skrip
   memuat kedua font dari `pubspec`/cache Flutter sebelum menggambar.
4. **Overflow di onboarding saat skrip wire.** Muncul hanya karena font cadangan
   lebih lebar; setelah Poppins dimuat, alur onboarding → login → beranda v2
   bersih tanpa exception. Tidak ada perubahan kode.
5. **`V2TimelineStep.isLast`.** Garis penghubung tidak ada di desain, jadi
   parameter itu dihapus; pemanggil di galeri ikut disesuaikan.
6. **Login v2 tetap mendarat di beranda v1.** `_v2Login` menyetel mode v2
   *setelah* `await login()` selesai. Di dalam `login()`, sesi sudah terpasang
   **sebelum** penulisan sesi ke sqflite, dan satu frame bisa berjalan selama
   penantian itu: `AppGate` mengganti layar (kunci `Navigator` berubah) dan
   melepas halaman login. Pemeriksaan `if (!mounted)` lalu mengembalikan sukses
   tanpa pernah menyalakan mode v2, jadi layar akhirnya beranda v1. Terbukti
   deterministik di skrip (dulu: `V2BerandaPage` tidak ditemukan).
   Solusi, tiga bagian:
   - Mode v2 ditandai **sebelum** menunggu layanan (`_v2Login`) dan
     dikembalikan ke `false` kalau login gagal. Begitu sesi terpasang,
     `AppGate` sudah tahu tujuannya, jadi beranda v1 tidak pernah berkedip.
   - `AppGate` hanya membangun ulang `Navigator` saat **identitas** berubah
     (`user.id` + mode v2, tapi mode hanya dihitung kalau sudah ada pengguna).
     Tanpa ini, penandaan mode selagi login berlangsung (sesi masih kosong)
     akan membuang tumpukan rute pratinjau sebelum terlihat.
   - Sisa pekerjaan `_v2Login` memakai `ProviderContainer` yang dipegang di
     awal, bukan `ref` halaman yang bisa sudah dilepas, sehingga status sesi
     tetap terbaca walau widget-nya hilang.
   Form login lama ikut menandai mode v1 sebelum menunggu, supaya arah
   sebaliknya (v1 → v2) tidak berkedip juga.

## Verifikasi

- `flutter analyze`: bersih, kecuali 2 warning lama (folder aset
  `assets/illustrations/inventory/` dan `assets/illustrations/features/` tidak
  ada).
- `flutter test`: **424 tes lulus**.
- **Cek visual host (2.1–2.7).** Skrip golden sekali pakai merender tiap
  frame pada kanvas 390×844 dengan Poppins + MaterialIcons, lalu gambar
  disandingkan dengan render referensi `~/Documents/figcraft_work/p02/*.png`.
  Hasil: susunan, ukuran kartu, pil tab bar, cincin (warna/ketebalan/cap/tick),
  label grup, dan linimasa cocok. Perbedaan yang memang disengaja: halaman tidak
  menggambar StatusBar palsu (di perangkat diisi status bar sistem lewat
  `SafeArea`), serta nama/angka memakai nilai parameter.
- **Cek wiring login → beranda v2.** Skrip widget sekali pakai (Poppins dimuat),
  lima kasus:
  1. mode v2 + sesi → `AppGate` menampilkan `V2BerandaPage` dengan peran
     `pegawai` dari `SessionUser`, sapaan “Halo, Sari”, 4 tab, tanpa kartu
     cuaca. Lulus.
  2. alur penuh: halaman login → “Coba tampilan v2” → onboarding → login v2
     dengan kredensial sungguhan (API tiruan) → sesi terpasang, mode v2 menyala,
     dan `AppGate` mengganti layar ke `V2BerandaPage`. Lulus.
  3. **regresi bug nomor 6**: penulisan sesi ke penyimpanan ditahan dengan
     `Completer` supaya ada satu frame di antara “sesi terpasang” dan “mode v2
     ditandai”, lalu dilepas setelah halaman login dilepas `AppGate`.
     - versi lama → `V2BerandaPage` **tidak ditemukan** (berakhir di `MainPage`);
     - versi sekarang → `V2BerandaPage` sudah tampil pada frame pertama setelah
       sesi terpasang (`MainPage` tidak pernah muncul), dan tetap di sana
       setelah penulisan sesi selesai.
  4. login v2 dengan password salah → tetap di halaman login v2, pesan
     “Username atau password salah”, dan mode v2 kembali `false`.
  5. form login lama → `MainPage` (v1), mode v2 tetap `false`.
  Berkas skrip lalu dihapus (tidak masuk suite).
- `graphify update .` dijalankan di root repo.

## Rencana lanjutan

1. Izin notifikasi sistem sungguhan di 1.10, didorong setelah login sungguhan.
2. Sambungkan beranda v2 ke data nyata (semaian siap pindah, stok menipis,
   lubang terisi, cuaca BMKG) menggantikan angka desain.
3. Navigasi tab v2 (Tanam/Stok/Rawat/Lainnya), tautan 5.16, 4.9, 6.11, dan
   halaman cuaca BMKG (10).
4. Tautkan halaman alur v2 dari galeri v2 (`v2_gallery_page.dart`).
5. Simpan pilihan mode v2 (mis. di `SessionStore`) supaya sesi tersimpan yang
   dibuka lagi langsung mendarat di beranda v2, bukan kembali ke alur v1.
6. Aksi “Tambah meja tanam” ke alur 6.6.

## Cara menguji ulang

```bash
cd apps/mobile
flutter analyze
flutter test
# cek visual lewat skrip golden sekali pakai lalu hapus:
# flutter test --update-goldens test/_scratch_p02_render_test.dart
# aplikasi biasa + backend di 127.0.0.1:3000 (adb reverse tcp:3000 tcp:3000)
flutter run
```
