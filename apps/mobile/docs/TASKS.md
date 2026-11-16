# Task List — HidroSense Mobile

Status: `[x]` selesai, `[~]` sedang jalan, `[ ]` belum, `[—]` di luar scope saat ini.

Terakhir diperbarui: 17 November 2026.

## 1. Slice desain v2 — “01 Onboarding & Auth”

Referensi: file FigCraft `HidroSense Mobile UI v2`, page `01 Onboarding & Auth`.
Catatan progress lengkap: [`progress-v2-onboarding-auth.md`](./progress-v2-onboarding-auth.md).

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
- [ ] Hubungkan login v2 ke `SessionViewModel` / API sungguhan.
- [ ] Restore sesi tersimpan saat buka aplikasi (splash → 2.1).
- [ ] Izin notifikasi sistem sungguhan di 1.10.
- [ ] Aksi “Tambah meja tanam” ke alur 6.6.
- [ ] Tautkan halaman alur v2 dari galeri v2 (`v2_gallery_page.dart`).

## 2. Dokumentasi

- [x] Folder `docs/` berisi task list dan progress (file ini + progress log).
- [x] Catatan alur, masalah, dan rencana lanjutan untuk recovery konteks AI.

## 3. Backend

Lihat [`panduan-menjalankan-backend.md`](./panduan-menjalankan-backend.md).
