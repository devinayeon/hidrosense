# Task List — HidroSense Mobile

Status: `[x]` selesai, `[~]` sedang jalan, `[ ]` belum, `[—]` di luar scope saat ini.

Terakhir diperbarui: 17 November 2026.

## 1. Slice desain v2 — “01 Onboarding & Auth”

Referensi: file FigCraft `HidroSense Mobile UI v2`, page `01 Onboarding & Auth`.
Catatan progress lengkap: [`progress-v2-onboarding-auth.md`](./progress-v2-onboarding-auth.md).
Pekerjaan lanjutan (logo, login sungguhan, sesi):
[`progress-v2-login-session.md`](./progress-v2-login-session.md).

- [x] Export ilustrasi FigCraft ke PNG 3x (`lib/views/v2/assets/illustrations/`).
- [x] Daftarkan folder aset di `pubspec.yaml`.
- [x] Komponen khusus halaman: assets, onboarding slide, auth state, login brand, home empty state.
- [x] Halaman onboarding (splash + Welcome 1–3).
- [x] Halaman login (kosong, terisi, salah, validasi).
- [x] Halaman akun nonaktif (1.8).
- [x] Halaman offline saat masuk (1.9).
- [x] Halaman izin notifikasi (1.10).
- [x] Halaman beranda kosong Petani (1.11).
- [x] Tombol “Coba tampilan v2” di login lama.
- [x] Pagination onboarding beranimasi, tidak ikut tergeser.
- [x] Tombol onboarding tetap saat sama, fade saat berbeda.
- [x] Tombol utama onboarding tidak bergeser walau tombol kedua muncul/hilang.
- [x] Hero onboarding full-bleed supaya ikon status bar terang terlihat.
- [x] Hilangkan outline bawaan input di halaman login v2.
- [x] Kursor & sorotan seleksi input v2 memakai warna v2, bukan teal theme lama.
- [x] Halaman v2 dibungkus `V2Theme.light` (tidak mewarisi theme lama).
- [x] `flutter analyze`, `flutter test` (424 tes), dan cek visual di emulator.
- [x] `graphify update .`.
- [x] Perbaiki logo kucing login v2 (kotak putih latar di belakang maskot).
- [x] Hubungkan login v2 ke `SessionViewModel` / API sungguhan.
- [x] Sesi tersimpan: lewati login dalam masa berlaku `refresh_expires_at`.
- [ ] Izin notifikasi sistem sungguhan di 1.10.
- [ ] Aksi “Tambah meja tanam” ke alur 6.6.
- [ ] Tautkan halaman alur v2 dari galeri v2 (`v2_gallery_page.dart`).

## 2. Slice desain v2 — “02 Beranda & Notifikasi”

Referensi: file FigCraft `HidroSense Mobile UI v2`, page `02 Beranda & Notifikasi`.
Catatan progress lengkap: [`progress-v2-beranda-notifikasi.md`](./progress-v2-beranda-notifikasi.md).

- [x] Setel ulang widget shared: `V2TabBar` (pil 56×32, ikon 24, label 14/20),
      `V2CycleRing` (warna/cap/tick/nilai 34/40), `V2TimelineStep` (tinggi 56,
      tanpa garis penghubung), `V2WeatherCard` (`available`/`unavailable`).
- [x] Selaraskan `V2Shadow.card` ke halaman `00 Foundations` (blur 24, offset 0,8).
- [x] Komponen halaman: hero siklus, dua petak statistik, rangka 2.3, label
      grup, dan keterangan tick siklus.
- [x] Halaman beranda Petani (2.1) dan Pegawai (2.2) — kartu cuaca hanya Petani.
- [x] Keadaan beranda: memuat (2.3), offline + antrean sinkron (2.5), BMKG tidak
      tersedia dengan “Coba lagi” kembali ke 2.1 (2.6).
- [x] Halaman notifikasi dua kelompok + “Tandai semua dibaca” (2.4).
- [x] Halaman detail siklus 60 hari: cincin besar, tick HSS 15, linimasa 4
      langkah, tombol “Buka Meja A2” (2.7).
- [x] `v2UiModeProvider` + `AppGate` merutekan sesi v2 ke `V2BerandaPage`.
- [x] Perbaiki login v2 yang tetap mendarat di beranda v1: mode v2 ditandai
      sebelum menunggu layanan, dan `AppGate` hanya membangun ulang `Navigator`
      saat identitas (pengguna + mode) berubah.
- [x] `flutter analyze`, `flutter test` (424 tes), cek visual host 2.1–2.7.
- [x] `graphify update .`.
- [ ] Sambungkan beranda v2 ke data nyata (semaian, stok, lubang, cuaca BMKG).
- [ ] Navigasi tab v2 dan tautan 5.16 / 4.9 / 6.11 / halaman cuaca 10.

## 3. Slice desain v2 — “03 Akun”

Referensi: file FigCraft `HidroSense Mobile UI v2`, page `03 Akun`.
Catatan progress lengkap: [`progress-v2-akun.md`](./progress-v2-akun.md).

- [x] Pindahkan `V2BerandaRole` ke `v2_roles.dart` (hindari lingkaran impor),
      tetap diekspor ulang dari `v2_beranda_page.dart`.
- [x] Setel ulang widget shared: `V2ScreenHeader` (tinggi 48, judul 28/36
      Bold), `V2Dialog` (`Type=Destructive`, shadow, jarak tombol 16),
      `V2ErrorState` (judul `h1`, `actionType`), `V2TextField` (ikon error
      `close`), `V2SearchField` (pad simetris, ✕ ink saat ada teks).
- [x] Komponen halaman: model + baris pegawai, kartu Profil, kartu Info,
      grup daftar, footer aksi + toast, aset maskot, dan `v2_roles`.
- [x] Tab “Lainnya” Petani (3.1) dan “Profil” Pegawai (3.2) — Pegawai hanya
      membaca data.
- [x] Daftar akun pegawai: kosong (3.4), terisi (3.5), cari tanpa hasil (3.6).
- [x] Form tambah/ubah pegawai (3.7/3.12), validasi (3.8), konfirmasi buang
      perubahan (3.9), data sudah berubah (3.13).
- [x] Detail pegawai aktif/nonaktif (3.11/3.17), dialog nonaktifkan (3.15),
      toast tambah/ubah/nonaktif (3.10/3.14/3.16).
- [x] Dialog Keluar + `onLogOut` yang menutup sesi (3.3); `AppGate` mengisi
      identitas akun.
- [x] `flutter analyze`, `flutter test` (424 tes), cek visual host 3.1–3.17,
      dan skrip wiring alur 7 kasus.
- [x] `graphify update .`.
- [ ] Sambungkan daftar akun pegawai ke backend v2 (buat/ubah/nonaktifkan).
- [ ] Alur Penjualan (page 08) dan Sinkron (page 11) dari menu 3.1/3.2.
- [ ] Aktivasi ulang akun pegawai (di luar lingkup 3.x).

## 4. Dokumentasi

- [x] Folder `docs/` berisi task list dan progress (file ini + progress log).
- [x] Catatan alur, masalah, dan rencana lanjutan untuk recovery konteks AI.

## 5. Backend

Lihat [`panduan-menjalankan-backend.md`](./panduan-menjalankan-backend.md).
