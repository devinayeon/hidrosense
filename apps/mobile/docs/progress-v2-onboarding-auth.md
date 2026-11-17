# Progress — Slice “01 Onboarding & Auth” (v2)

Dokumen ini catatan kerja agar konteks bisa dipulihkan tanpa membaca ulang
seluruh riwayat percakapan. Update dokumen ini setiap kali alur v2 berubah.

Terakhir diperbarui: 17 November 2026.

## Tujuan

- Memotong page FigCraft `01 Onboarding & Auth` menjadi halaman Flutter dan
  komponen khusus halaman di `apps/mobile/lib/views/v2/`.
- Memakai ulang widget v2 yang sudah ada untuk bagian yang generik.
- Menyambungkan login lama (di luar v2) supaya bisa membuka alur v2.

## Aturan yang disepakati

- Semua kode view baru hanya di `apps/mobile/lib/views/v2`.
- Komponen khusus halaman diletakkan di `lib/views/v2/components`.
- Sebelum menambah widget reusable baru, tanya dulu.
- Font Poppins dan edit `pubspec.yaml` untuk font/aset sudah diizinkan.
- Tidak menambah file test baru.

## Sumber desain (FigCraft)

File: `HidroSense Mobile UI v2`, page `01 Onboarding & Auth` (page id `4736`).

| Frame | Node | Catatan alur |
| --- | --- | --- |
| 1.1 Splash | 4737 | Sesi tersimpan → 2.1; belum masuk → 1.2 |
| 1.2 Welcome 1 | 4831 | Lanjut → 1.3; Lewati → 1.5 |
| 1.3 Welcome 2 | 4957 | Lanjut → 1.4; Lewati → 1.5 |
| 1.4 Welcome 3 | 5070 | Masuk → 1.5 |
| 1.5 Login kosong | 5165 | — |
| 1.5a Login kosong dikirim | 5822 | Validasi “Isi username” / “Isi password” |
| 1.6 Login terisi | 5261 | — |
| 1.7 Login salah | 5357 | “Username atau password salah” |
| 1.8 Akun nonaktif | 5457 | Hubungi petani; Kembali ke login |
| 1.9 Offline saat masuk | 5515 | Coba lagi |
| 1.10 Izin notifikasi | 5589 | Aktifkan / Nanti → 1.11 atau 2.1 |
| 1.11 Beranda kosong | 5676 | Tambah meja tanam → 6.6 |

Spesifikasi ringkas:

- Hero onboarding 460, ilustrasi 320 di `y84`, konten `y456`, aksi `y690`.
- Login: status bar 44 + app bar 64, konten mulai `y108`; logo 81×112; judul
  28/36; badan 16/24; field 84 (112 saat error); bantuan 14/20; tombol bawah
  padding 42.
- Login salah: field password jadi 112, bantuan pindah ke `y448`.
- Auth state: konten atas 120 (nonaktif), 150 (offline), 96 (izin notifikasi).
- Beranda: konten mulai `y60`, aksi `y658`, tab bar `y738` (Beranda aktif).

## Peta file

Aset:

- `lib/views/v2/assets/illustrations/` — 8 PNG 3x: `splash.png`,
  `welcome-stock.png`, `welcome-cycle.png`, `welcome-weather.png`,
  `login-mascot.png`, `inactive-account.png`, `offline-login.png`,
  `notification-permission.png`.
- `pubspec.yaml` mendaftarkan `lib/views/v2/assets/illustrations/`.

Komponen khusus halaman (`lib/views/v2/components/`):

- `v2_auth_assets.dart` — konstanta path aset.
- `v2_onboarding_slide.dart` — hero biru + ilustrasi + judul/badan (tanpa aksi).
- `v2_auth_state_view.dart` — kerangka halaman status autentik.
- `v2_login_brand.dart` — logo maskot + judul “Masuk” + keterangan.
- `v2_home_empty_state.dart` — sapaan + checklist beranda kosong.

Halaman (`lib/views/v2/pages/`):

- `v2_onboarding_page.dart`
- `v2_login_page.dart`
- `v2_inactive_account_page.dart`
- `v2_offline_login_page.dart`
- `v2_notification_permission_page.dart`
- `v2_home_page.dart`

Pratinjau & penghubung:

- `lib/views/v2/v2_auth_preview_main.dart` — entry tanpa login lama:
  `flutter run -t lib/views/v2/v2_auth_preview_main.dart`
- `lib/views/pages/login_page.dart` — tombol “Coba tampilan v2” (setelah
  tombol Masuk) membuka `V2OnboardingPage.route()`.

Widget reusable yang dipakai: `V2Button`, `V2TextField`, `V2PasswordField`,
`V2Checklist`, `V2TabBar`, `V2AppBar`, `V2ScreenHeader`, `V2Pagination`,
`V2IconButton`, plus token di `theme/v2_tokens.dart`.

## Keputusan penting

- Ilustrasi diekspor sebagai PNG transparan 3x, bukan digambar ulang sebagai
  vektor, supaya bentuk maskot dan properti persis desain.
- Perilaku submit login bisa disuntik lewat `onLogin` (`V2LoginHandler`).
  Tanpa injeksi, username sentinel memicu cabang demo:
  `nonaktif` → 1.8, `offline` → 1.9, `salah` → 1.7, lainnya sukses.
- Onboarding memakai satu `PageView` untuk ilustrasi + teks; pagination dan
  tombol berada di luar pager (lihat “Animasi” di bawah).
- Semua halaman v2 dibungkus `Theme(data: V2Theme.light, ...)` supaya tidak
  mewarisi `AppTheme` lama saat dibuka dari login lama.

## Animasi onboarding

Masalah awal: seluruh isi (pagination + tombol) ikut tergeser bersama
`PageView`, jadi terasa seperti gambar yang hanya digeser.

Perbaikan (di `v2_onboarding_page.dart`):

- `PageView` hanya berisi `V2OnboardingSlide` (hero + judul + badan), tinggi
  viewport `heroHeight + 100` (100 = tinggi teks terbesar).
- Pagination berada di bawah pager, di dalam `AnimatedSwitcher`; dot memakai
  `V2Pagination` yang sudah memakai `AnimatedContainer`, jadi lebar dot
  bermorfosis saat indeks berganti (`220ms`, `Curves.easeOutCubic`). Saat
  splash tidak ada dot.
- Tombol berada di bawah pager. Tiap slot tombol (primer 56, sekunder 48)
  selalu memesan tinggi, termasuk saat kosong, jadi blok aksi tingginya
  konstan dan tombol utama tidak pernah bergeser.
  Slot memakai `AnimatedSwitcher` dengan kunci dari label: “Lanjut” →
  “Lanjut” (Welcome 1 → 2) tidak beranimasi karena kuncinya sama dan benar
  benar diam; “Lanjut” → “Masuk” (Welcome 3) memudar di tempat yang sama,
  sedangkan “Lewati” memudar keluar dari slotnya.
- `_animateTo` menaikkan `_index` lebih dulu, jadi saat splash auto-lanjut
  pagination dan tombol langsung ikut berganti tanpa menunggu
  `onPageChanged`.
- Alasan tombol utama tidak di-anchor ke bawah: di desain FigCraft tombol
  utama selalu di `y690`, baik di 1.2 (Lanjut + Lewati) maupun 1.4 (Masuk
  saja). Menyediakan slot kosong mereproduksi `y690` di kedua frame.

## Masalah yang ditemukan dan solusinya

1. Ikon status bar gelap di atas hero biru.
   → `AnnotatedRegion` onboarding diganti ke `SystemUiOverlayStyle.light`.
   Ternyata masih kurang: `SafeArea` atas menyisakan 44 dp area kanvas
   terang, jadi ikon putih malah nyaris tak terlihat.
   → `SafeArea` onboarding dibuat `top: false` sehingga hero biru benar-benar
   full-bleed di belakang status bar, sama seperti desain (`Hero` rect
   `y0..460`, ilustrasi `y84`).
2. Outline input ganda di halaman login v2 (hitam bawaan + biru custom).
   Penyebab: halaman v2 dibuka dari login lama sehingga mewarisi `AppTheme`,
   yang punya `inputDecorationTheme` dengan `focusedBorder`/`enabledBorder`.
   `V2TextField` hanya mengeset `border`, jadi `focusedBorder` dari theme ikut
   terpakai → muncul outline kedua saat fokus.
   → `V2TextField` kini mengeset semua border (`border`, `enabledBorder`,
   `disabledBorder`, `focusedBorder`, `errorBorder`, `focusedErrorBorder`) ke
   `InputBorder.none`, `filled: false`, dan `contentPadding: EdgeInsets.zero`.
   → Tiap halaman v2 juga dibungkus `V2Theme.light`.
3. Kursor input v2 berwarna teal, bukan biru.
   Penyebab: `MaterialApp` membuat `DefaultSelectionStyle` dari theme lama
   (`AppTheme` → `primaryDarkTeal`), dan nilainya lebih diutamakan daripada
   `Theme` v2 terdekat untuk `cursorColor`/`selectionColor`.
   → `V2TextField` membungkus `TextField`-nya dengan `DefaultSelectionStyle`
   (`cursorColor` = `blue500`, `selectionColor` = `blue500` 40%).
4. Aset diekspor lewat MCP `file.export` tidak bisa menulis langsung ke path
   project; disiasati dengan server HTTP sementara di `/tmp/opencode` lalu
   `fetch` dari runtime Code Mode (sudah selesai, tidak perlu diulang).

## Verifikasi

- `flutter analyze`: bersih, kecuali 2 warning lama (folder
  `assets/illustrations/inventory/` dan `assets/illustrations/features/`
  tidak ada).
- `flutter test`: 424 tes lulus.
- Onboarding (dicek di emulator): tombol Lanjut/Lewati berada di
  `[63,1996][1017,2143]` dan `[63,2164][1017,2290]` di Welcome 1 maupun
  Welcome 2 (tidak bergeser); saat digulir setengah jalan (motionevent
  tahan) pagination dan tombol tetap di posisi yang sama; di Welcome 3
  tombol Masuk menempati `[63,1996][1017,2143]` alias sama persis dengan
  Lanjut. Hero biru menutup area status bar dengan ikon putih.
- Splash (tangkapan layar berurutan tiap 180 ms): area tombol dan pagination
  kosong tanpa mengubah posisi, lalu Lanjut/Lewati memudar masuk (tangkapan
  berikutnya menunjukkan tombol masih ~67% opasitas, baru kemudian penuh).
- Tidak ada exception/overflow di log `flutter run`.
- Cek visual emulator Android 17 (1080×2400, density 420 ≈ 411×914 dp):
  splash, Welcome 1–3, login kosong, validasi kosong, password salah, izin
  notifikasi, beranda, akun nonaktif, offline, dan kembali dari login → 1.4.
- Login v2 dibuka dari aplikasi asli (`main.dart` → login lama → “Coba
  tampilan v2”) dengan theme lama aktif: saat field username difokuskan hanya
  ada satu outline biru `#1565FF` (scan piksel baris tengah: kanvas → biru
  6 px → putih → biru → kanvas, tanpa garis hitam). Kursor kini biru
  `#1565FF` (dulu teal `#168681`), pegangan seleksi juga biru.
- `graphify update .` dijalankan di root repo.

## Rencana lanjutan

1. Ganti handler demo login dengan pemanggilan API/sesi sungguhan
   (`SessionViewModel`), termasuk pesan error server.
2. Restore sesi tersimpan saat aplikasi dibuka: splash → 2.1 bila ada sesi.
3. Integrasi izin notifikasi sistem di 1.10 (`onAllow` sudah tersedia).
4. Sambungkan tombol “Tambah meja tanam” ke alur 6.6.
5. Tambahkan tautan ke halaman alur v2 dari galeri v2 agar mudah direview.
6. Bila diperlukan, tambah tes widget untuk animasi onboarding dan validasi
   login (saat ini belum ada file test baru).

## Cara menjalankan ulang

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test
# pratinjau alur auth tanpa login lama:
flutter run -t lib/views/v2/v2_auth_preview_main.dart
# pratinjau galeri widget v2:
flutter run -t lib/views/v2/v2_preview_main.dart
```

Dari aplikasi biasa: buka halaman login lama, lalu tekan “Coba tampilan v2”.
