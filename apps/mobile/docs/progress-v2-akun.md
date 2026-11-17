# Progress — Slice desain v2 “03 Akun”

Catatan kerja untuk slice ketiga desain v2 setelah
[`01 Onboarding & Auth`](./progress-v2-onboarding-auth.md),
[`progress-v2-login-session.md`](./progress-v2-login-session.md), dan
[`progress-v2-beranda-notifikasi.md`](./progress-v2-beranda-notifikasi.md): tab
terakhir alur v2 — “Lainnya” untuk Petani, “Profil” untuk Pegawai — beserta alur
kelola akun pegawai (daftar, tambah, ubah, nonaktifkan, keluar).

Terakhir diperbarui: 17 November 2026.

## Tujuan

1. Memotong page FigCraft `03 Akun` menjadi view Flutter di
   `apps/mobile/lib/views/v2`, sesuai catatan alur tiap frame.
2. Menyetel ulang widget shared yang dipakai (`V2ScreenHeader`, `V2Dialog`,
   `V2ErrorState`, `V2TextField`, `V2SearchField`) supaya persis page ini /
   halaman `00 Foundations`, tanpa membuat varian duplikat.
3. Membedakan fitur yang bisa diakses Petani dan Pegawai: Petani boleh
   menambah/mengubah/menonaktifkan akun pegawai, Pegawai hanya membaca datanya.
4. Menyambungkan alur akun ke beranda v2 supaya tombol tab terakhir berfungsi.

## Aturan yang disepakati

- Semua kode view baru hanya di `apps/mobile/lib/views/v2`.
- Penyusun khusus halaman → `lib/views/v2/components/`; widget yang bisa
  dipakai halaman lain → `lib/views/v2/widgets/`.
- **Izin diminta lebih dulu** sebelum menambah/menyetel widget reusable. Hasil
  tanya-jawab:
  - Penyetelan ulang `V2ScreenHeader`, `V2Dialog`, `V2ErrorState`,
    `V2TextField`, dan `V2SearchField` **boleh** (rincian di bawah).
  - **Tidak ada widget reusable baru** untuk page 03: seluruh penyusun khusus
    halaman ditaruh di `lib/views/v2/components/v2_akun_*.dart`.
- Tidak menambah file test baru ke suite; verifikasi tambahan memakai skrip
  sekali pakai yang langsung dihapus.
- Bahasa dokumen dan komentar kode: Indonesia.
- Poppins dan suntingan aset di `pubspec.yaml` boleh.
- Catatan progress/task di `apps/mobile/docs`; `graphify update .` dijalankan.

## Sumber desain dan spesifikasi ringkas

File `HidroSense Mobile UI v2`, page `03 Akun` (page id `6630`), semua frame
390×844. Dibaca lewat MCP FigCraft (aplikasi di `localhost:7979`) dan
dicocokkan dengan render referensi `~/Documents/figcraft_work/p03/*.png`.

- FlowNote `6631`: “**03 Akun** — Urutan alur: Lainnya atau Profil, Keluar,
  daftar akun, tambah, ubah, data berubah, nonaktifkan. Setiap frame memuat
  catatan Dari dan Ke.”
- Frame: `3.1 Lainnya (Petani)` `6637`, `3.2 Profil (Pegawai)` `6743`,
  `3.3 Keluar, konfirmasi` `7343`, `3.4 Akun pegawai kosong` `6911`,
  `3.5 Akun pegawai` `6825`, `3.6 Cari tanpa hasil` `7510`,
  `3.7 Tambah pegawai` `6996`, `3.8 Tambah pegawai, validasi` `7041`,
  `3.9 Buang perubahan, konfirmasi` `7606`, `3.10 Pegawai ditambahkan` `7239`,
  `3.11 Detail pegawai` `7098`, `3.12 Ubah pegawai` `7142`,
  `3.13 Data sudah berubah` `7457`, `3.14 Perubahan tersimpan` `7659`,
  `3.15 Nonaktifkan, konfirmasi` `7187`,
  `3.16 Pegawai dinonaktifkan` `7707`, `3.17 Detail pegawai nonaktif` `7797`;
  catatan alur `7839`–`7855`.
- Catatan alur penting:
  - 3.1 “Dari tab Lainnya. Ke 3.5 Akun pegawai, 3.3 Keluar, Penjualan 8.1,
    Sinkron 11.1.”
  - 3.2 “Dari tab Profil. Ke 3.3 Keluar, Sinkron 11.1. **Data hanya dibaca.**”
  - 3.3 “Dari 3.1 atau 3.2. Keluar ke Masuk (1.5). Batal kembali.”
  - 3.7 “Dari 3.4 atau 3.5. Simpan 3.10. Isian salah 3.8. Kembali 3.9.”
  - 3.8 “Dari Simpan di 3.7. **Fokus ke isian pertama yang salah.** Simpan
    ulang 3.10.”
  - 3.11 “Dari 3.5 atau 3.10. Ubah 3.12. Nonaktifkan 3.15.”
  - 3.13 “Dari Simpan di 3.12. Muat ulang membuka 3.12 dengan data terbaru.”
  - 3.17 “Dari 3.16. Tanpa tombol Nonaktifkan. **Aktivasi ulang tidak ada di
    lingkup.**”
- Dua keluarga bingkai:
  - **Tab shell** (3.1/3.2) — isi tab terakhir beranda. Konten mulai di y=60,
    padding horizontal 24, jarak antar blok 16; `Actions` 390×80 (padding
    bawah 24); `TabBar` 390×106 di bawahnya.
  - **AppBar shell** (3.3–3.17) — rute terpisah. `AppBar` 390×64 di y=44,
    konten mulai di y=116; `Actions` menempel di bawah, 390×98 (satu tombol)
    atau 390×170 (dua tombol), padding bawah 42 = 34 home indicator + 8.
- Kartu `Profil` (3.1/3.2/3.11/3.17): biru `#1565FF`, tinggi 88, sudut 32,
  `Shadow/Card`; avatar 56 bulat `#EAF2FF` berisi inisial `h2` biru tua; nama
  16/24 SemiBold putih; di bawahnya peran 14/20 Medium putih (daftar) atau
  lencana status (detail).
- Kartu `Info` (3.2/3.11/3.17): putih, sudut 24, `Shadow/Card`, padding 24,
  jarak antar baris 16; label 14/20 Medium muted di atas nilai 16/24 Regular
  ink.
- `Grup daftar`: putih sudut 24 dengan `Shadow/Card`; pemisah antar baris
  garis 1px `#E5E8EC` yang **menjorok 76 dari kiri** (sejajar dengan ujung kiri
  judul baris, bukan ikon). Baris Sinkron mandiri di 3.2 memakai sudut 24
  **tanpa bayangan** (bukan bagian grup).
- Toast: pil 342×56 `#111827`, duduk 16 di atas `Actions` (3.10/3.16 di
  y=674, 3.14 di y=602 karena footer dua tombol).
- Dialog dipusatkan pada tinggi 844: 3.3 (h260), 3.9 (h260), 3.13 (h308),
  3.15 (h284).
- Validasi 3.8: `'Isi nama'`, `'Username sudah dipakai'`,
  `'Minimal 12 karakter'`; redaksi dasar `'Isi username'`/`'Isi password'`
  dipakai ulang dari `v2_login_page.dart`.
- Data contoh 3.5: Sari Dewi/`sari.dewi` (0812 3456 7890, Jl. Melati 12,
  Malang), Rina Putri/`rina.putri`, Dedi Kurnia/`dedi.k`, Agus Salim/`agus.s`
  (Nonaktif). 3.10 menambah Tomi Wijaya/`tomi.w` di paling atas; 3.16 membuat
  Sari menjadi Nonaktif; 3.14 menampilkan telepon `0813 9000 1122`.

## Peta file

Baru:

- `lib/views/v2/v2_roles.dart` — `V2BerandaRole` (`petani`/`pegawai`)
  dipindahkan ke sini supaya halaman akun bisa memakainya tanpa membuat
  lingkaran impor dengan beranda. `v2_beranda_page.dart` mengekspornya ulang
  agar pemanggil lama (`app_gate.dart`) tetap menemukannya.
- `lib/views/v2/pages/v2_akun_tab_page.dart` — `V2AkunTabView`, isi tab
  “Lainnya” (3.1) dan “Profil” (3.2). Bukan rute sendiri: dipasang
  `V2BerandaPage` sebagai isi tab terakhir.
- `lib/views/v2/pages/v2_employee_list_page.dart` — daftar akun pegawai
  (3.5), kosong (3.4), cari tanpa hasil (3.6), notifikasi 3.10/3.16.
- `lib/views/v2/pages/v2_employee_detail_page.dart` — detail pegawai (3.11),
  nonaktif (3.17), dialog nonaktifkan (3.15), toast 3.14.
- `lib/views/v2/pages/v2_employee_form_page.dart` — form tambah/ubah
  (3.7/3.12) dengan konstruktor bernama `.create`, `.validation`, `.edit`,
  `.conflict`, `.discard` untuk pratinjau frame 3.7/3.8/3.12/3.13/3.9.
- `lib/views/v2/components/v2_akun_employee.dart` — model `V2Employee`,
  `v2InitialsOf`, daftar contoh `designEmployees`, dan hasil
  `V2EmployeeDeactivated`.
- `lib/views/v2/components/v2_akun_assets.dart` — `V2AkunAssets
  .mascotAvatarFlat`.
- `lib/views/v2/components/v2_akun_profil_card.dart` — `V2AkunProfilCard`.
- `lib/views/v2/components/v2_akun_info_card.dart` — `V2AkunInfoCard` +
  `V2AkunInfoRow`.
- `lib/views/v2/components/v2_akun_menu_group.dart` — `V2AkunMenuGroup`
  (pemisah menjorok 76, opsi `elevated`).
- `lib/views/v2/components/v2_akun_employee_row.dart` — baris pegawai dengan
  state `Archived` (nama + status jadi `#4B5563`).
- `lib/views/v2/components/v2_akun_action_bar.dart` — footer aksi + toast.
- `lib/views/v2/assets/illustrations/mascot-avatar-flat.png` — ilustrasi
  keadaan kosong 3.4/3.6 (diekspor dari node
  `Illustration/mascot-avatar-flat` di page `00 Foundations`, skala 3 →
  960×960).
- `lib/views/v2/fonts/*` sudah ada; folder aset di `pubspec.yaml` sudah
  terdaftar sebelumnya.

Diubah:

- `lib/views/v2/widgets/v2_app_bar.dart` — `V2ScreenHeader` mendapat tinggi
  minimum 48 dengan judul `h1` (28/36 Bold) dipusatkan secara vertikal,
  menyesuaikan `ScreenHeader` Foundations.
- `lib/views/v2/widgets/v2_dialog.dart` — `enum V2DialogType
  {confirm, destructive}`; dialog mendapat `V2Shadow.card`; jarak tombol
  utama–sekunder 12 → 16; aksi `destructive` memakai tombol merah.
- `lib/views/v2/widgets/v2_error_state.dart` — judul `h2` → `h1` (28/36 Bold)
  dan jarak judul–badan 8 → 16; parameter `actionType` (bawaan
  `V2ButtonType.secondary`) supaya pemanggil bisa memilih gaya tombol.
- `lib/views/v2/widgets/v2_text_field.dart` — ikon pendamping teks error
  `warning` → `close`.
- `lib/views/v2/widgets/v2_select_field.dart` — `V2SearchField`: padding
  kiri–kanan simetris 16; tombol hapus ✕ memakai warna ink `#111827` dan
  tampil selama teks tidak kosong (dulu hanya bila `onClear` diisi).
- `lib/views/v2/pages/v2_beranda_page.dart` — menyimpan `_activeTab`,
  `_akunIndex`, dan `_employees`; tab terakhir merender `V2AkunTabView`;
  `V2TabBar` memakai `activeIndex`; menambah parameter `fullName`, `username`,
  `phone`, `address`, `initialEmployees`, `onLogOut`; membuka daftar pegawai,
  penjualan, sinkron, dan dialog keluar.
- `lib/views/pages/app_gate.dart` — mengisi `fullName: user.name`,
  `username: user.username`, dan `onLogOut: () =>
  ref.read(sessionProvider.notifier).logout()`.

## Keputusan penting

- **Dua keluarga bingkai.** 3.1/3.2 adalah isi tab terakhir beranda, jadi
  `TabBar` tetap milik `V2BerandaPage` dan footer “Keluar” duduk di antaranya.
  Frame 3.3–3.17 adalah rute `AppBar` yang dipush dari tab itu. Perbedaan ini
  dikodekan lewat `V2AkunActionBar(safeBottom: false)` untuk tab shell dan
  `safeBottom: true` (SafeArea + 8) untuk rute ber-AppBar.
- **Satu halaman untuk tambah dan ubah.** 3.7 dan 3.12 memakai susunan yang
  sama; bedanya hanya judul dan label password. `V2EmployeeFormPage` menangani
  keduanya, dan konstruktor bernama per frame dipakai untuk pratinjau.
- **Baris pegawai tidak memakai `V2ListItem`.** State `Archived` membuat nama
  dan status jadi `#4B5563`; karena `V2ListItem` tidak punya opsi ini,
  dipakai `V2AkunEmployeeRow` khusus halaman.
- **Keadaan pendukung lewat parameter, bukan rute palsu.** Frame tanpa pemicu
  interaksi (3.10, 3.14, 3.16) dihasilkan dari parameter `toast`/`initialEmployees`
  dan konstruktor bernama, mengikuti preseden page 02.
- **Pegawai baru tampil paling atas.** `_update([created, ..._employees])`
  karena 3.10 menampilkan Tomi Wijaya di baris pertama.
- **State akun ada di beranda.** `V2EmployeeListPage` memegang `_employees`
  dan memberi tahu beranda lewat `onChanged`; beranda mengembalikannya lewat
  `initialEmployees` sehingga daftar tetap utuh saat pindah tab. Penyambungan
  backend akun v2 adalah tugas lanjutan.
- **Radius baris mandiri dibungkus lokal.** Pemeriksaan piksel menunjukkan
  baris `ListItem` tunggal di 3.2 bersudut 24 **tanpa** bayangan, sedangkan
  `V2ListItem` (Flutter) tidak punya radius. Penyelesaiannya: bungkus lokal
  `V2AkunMenuGroup(elevated: false)` alih-alih menyetel ulang widget shared.
- **Pegawai = baca saja.** Menu “Akun pegawai” dan “Penjualan” hanya muncul
  untuk Petani; Pegawai mendapat kartu `Info` + baris Sinkron, dan
  `onOpenEmployees`/`onOpenSales` tidak diisi.
- **Mode v2 tetap tujuan pratinjau.** Login lama dan sesi tersimpan tetap
  mendarat di v1 `MainPage`; halaman akun hanya terjangkau lewat alur v2.

## Masalah yang ditemukan dan solusinya

1. **Lingkaran impor `V2BerandaRole`.** Halaman akun butuh peran sementara
   beranda mengimpor halaman akun. Solusi: enum dipindah ke `v2_roles.dart`,
   beranda mengekspornya ulang supaya `app_gate.dart` tidak berubah.
2. **Offset “Tidak ketemu” (3.6).** Awalnya hanya padding horizontal, sehingga
   blok kosong muncul terlalu tinggi. Desain menaruh ilustrasi pada y=64 di
   dalam pad `[64,0,64,0]`; solusi: `EdgeInsets.fromLTRB(64, 64, 64, 0)`.
3. **Verifikasi host tanpa emulator.** Emulator Android `Medium_Phone_API_37.0`
   SIGSEGV saat cold boot (KVM melaporkan sehat), jadi cek visual dilakukan di
   host: skrip golden sekali pakai merender 17 frame 390×844 dengan Poppins +
   MaterialIcons, lalu disandingkan dengan referensi. Dua perbedaan yang
   memang disengaja: (a) render tidak menggambar StatusBar palsu 44px,
   (b) item yang menempel di bawah tampak 34px lebih rendah di host karena
   inset home indicator asli tidak ada — di perangkat keduanya tepat (pad
   bawah 42 = 34 inset + 8).
4. **`hintText` selalu ada di pohon.** Saat menyusun skrip alur, `find.text`
   menemukan dua `'Minimal 12 karakter'` (petunjuk di dalam `InputDecoration`
   tetap ada walau teks sudah diisi, hanya beropasitas 0) → pencarian teks
   error disaring lewat warna merah. Bukan masalah produk.
5. **Tombol berbagi label di dialog.** `find.text('Nonaktifkan')`/`'Keluar'`
   cocok untuk tombol halaman **dan** aksi dialog; tap perlu dibatasi ke
   `V2Dialog`. Bukan masalah produk.

## Verifikasi

- `flutter analyze`: bersih, kecuali 2 warning lama (folder aset
  `assets/illustrations/inventory/` dan `assets/illustrations/features/` tidak
  ada).
- `flutter test`: **424 tes lulus** (tidak ada test baru yang ditambahkan).
- **Cek visual host (3.1–3.17).** Skrip golden sekali pakai merender tiap frame
  pada kanvas 390×844 dengan Poppins + MaterialIcons, lalu disandingkan dengan
  `~/Documents/figcraft_work/p03/*.png`. Cocok: susunan kedua keluarga bingkai,
  pemisah grup (268/349/430 di 3.5), baris medan cari, isi dialog/tombol,
  kartu Profil/Info, dan keadaan kosong. Perbedaan yang disengaja dicatat pada
  masalah nomor 3.
- **Cek wiring alur page 03.** Skrip widget sekali pakai (Poppins dimuat),
  tujuh kasus, semuanya lulus:
  1. Petani membuka “Lainnya” → “Akun pegawai”; tambah pegawai baru muncul
     paling atas + toast “Pegawai ditambahkan”; daftar tetap setelah kembali
     ke beranda dan membuka lagi.
  2. Validasi tambah pegawai menahan simpan (`Isi nama`,
     `Username sudah dipakai`, `Minimal 12 karakter`) dan tidak memanggil
     `onChanged` sampai isian benar.
  3. Buang perubahan: “Lanjut isi” tetap di form, “Buang” kembali ke detail.
  4. Nonaktifkan dari detail: dialog konfirmasi → toast
     “Sari dinonaktifkan”, baris Sari menjadi `Nonaktif, sari.dewi`.
  5. Pegawai: tanpa menu kelola akun; ada kartu Info, Sinkron, dan Keluar.
  6. Keluar: “Batal” tidak menutup sesi, aksi utama memanggil `onLogOut`.
  7. Tab lain tetap memunculkan penanda “belum tersedia”.
  Berkas skrip lalu dihapus (tidak masuk suite).
- `graphify update .` dijalankan di root repo.

## Rencana lanjutan

1. Sambungkan daftar akun pegawai ke backend v2 (buat/ubah/nonaktifkan),
   menggantikan daftar contoh `designEmployees`.
2. Aktivasi ulang akun pegawai (di luar lingkup 3.x, tapi tombolnya masuk akal
   di 3.17).
3. Alur Penjualan (page 08) dan Sinkron (page 11) dari menu 3.1/3.2.
4. Halaman notifikasi/beranda yang lain lewat tab v2 yang belum tersedia.
5. Simpan pilihan mode v2 supaya sesi tersimpan langsung mendarat di alur v2.

## Cara menguji ulang

```bash
cd apps/mobile
flutter analyze
flutter test
# cek visual lewat skrip golden sekali pakai lalu hapus:
# flutter test --update-goldens test/_scratch_p03_render_test.dart
# cek wiring alur:
# flutter test test/_scratch_p03_flow_test.dart
# aplikasi biasa + backend di 127.0.0.1:3000 (adb reverse tcp:3000 tcp:3000)
flutter run
```
