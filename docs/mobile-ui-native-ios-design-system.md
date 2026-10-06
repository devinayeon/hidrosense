# Panduan Desain Mobile Native & Animasi Halus HidroSense

Dokumen ini menjelaskan penyelarasan antarmuka mobile Flutter ([apps/mobile](file:///d:/Dev/Projects/hidrosense/apps/mobile)) mengacu pada standar *Apple Human Interface Guidelines (HIG)*, *Mobile-Native Feeling*, serta filosofi animasi fisik responsif (*Emil Kowalski's Motion Principles*).

---

## 1. Filosofi & Pendekatan Desain

Tujuan perbaikan ini adalah membuat aplikasi terasa seperti aplikasi mobile native berkualitas tinggi saat disentuh di layar ponsel, bukan seperti halaman web yang dibungkus webview.

Tiga pilar utama yang diterapkan:
1. **Kejelasan & Sentuhan Fisik (Physical Tactile Feedback):** Setiap tombol dan kartu interaktif memberikan respons seketika saat jari menyentuh layar (micro-scale `0.975` - `0.985` dengan kurva `Curves.easeOutCubic` durasi 100–120 milidetik).
2. **Kepatuhan Palet Warna Asli (Color Consistency):** Warna identitas HidroSense tidak diubah sedikit pun, melainkan disempurnakan transisinya:
   - **Teal Primer:** `Color.fromRGBO(57, 198, 195, 1)` (elemen aktif, tombol konfirmasi, progress bar semai).
   - **Dark Navy:** `Color.fromRGBO(23, 34, 49, 1)` (tombol aksi utama, teks header tebal).
   - **Lime Aksen:** `Color.fromRGBO(221, 244, 90, 1)` (kontras teks tombol aksi utama).
   - **Latar Bersih:** `Color.fromRGBO(250, 250, 247, 1)` (background kanvas alami).
   - **Garis Batas Halus:** `Color.fromRGBO(229, 231, 235, 1)` dan `Color.fromRGBO(240, 240, 235, 1)`.
3. **Animasi Berbobot Alami (Smooth Interpolation):** Indikator progres (seperti usia semaian dan okupansi lubang meja tanam) bergerak secara bertahap dan halus menggunakan `TweenAnimationBuilder` (durasi 400ms), bukan lompat kaku.

---

## 2. Komponen yang Ditingkatkan

### A. Kartu Informasi Interaktif ([RowInfoCardMd](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/views/widgets/row_info_card_md.dart))
- **Perubahan:** Menambahkan deteksi tekan (`onHighlightChanged`) dan `AnimatedScale`.
- **Sensasi Pengguna:** Saat disentuh, kartu menyusut sangat halus ke skala `0.985` dan kembali membal saat jari diangkat. Jika kartu bersifat statis (tidak memiliki aksi tap), kartu tetap kokoh tanpa animasi.

### B. Tombol Aksi Utama ([RowButton](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/views/widgets/row_button.dart))
- **Perubahan:** Diberi animasi kompresi skala `0.975` dengan kurva `easeOutCubic`.
- **Sensasi Pengguna:** Pengguna merasakan klik nyata di jari tanpa jeda (zero-lag tap feeling).

### C. Tombol Sekunder & Outlined ([ColButton](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/views/widgets/col_button.dart))
- **Perubahan:** Penyesuaian skala halus `0.975` saat ditekan dengan splash warna teal lembut.

### D. Tombol Filter Status ([FilterButton](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/views/widgets/filter_button.dart))
- **Perubahan:** Dilengkapi respons sentuh cepat `0.94` dengan transisi warna pill yang mulus dan bayangan elevasi halus.

### E. Meter Progres Semai & Okupansi Meja Tanam
- **File:** [info_meja_body.dart](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/views/components/info_meja_body.dart) dan [info_seeding_page.dart](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/views/pages/info_seeding_page.dart).
- **Perubahan:** Mengganti pengisian seketika menjadi interpolasi `TweenAnimationBuilder<double>` dari nilai awal ke rasio riil.

---

## 3. Disiplin Teknis & Batas Baris Kode

Seluruh berkas yang disempurnakan tetap mematuhi batas arsitektur ketat:
- [row_info_card_md.dart](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/views/widgets/row_info_card_md.dart): 65 baris
- [row_button.dart](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/views/widgets/row_button.dart): 65 baris
- [col_button.dart](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/views/widgets/col_button.dart): 72 baris
- [filter_button.dart](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/views/widgets/filter_button.dart): 54 baris
- [info_meja_body.dart](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/views/components/info_meja_body.dart): 158 baris
- [info_seeding_page.dart](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/views/pages/info_seeding_page.dart): 276 baris

Semua file berada di bawah ambang batas maksimum 300–400 baris.

---

## 4. Hasil Verifikasi

Semua 13 pengujian otomatis Flutter (`flutter test --no-pub`) tetap lulus 100%. Peningkatan interaksi visual ini tidak mengganggu fungsionalitas logika bisnis, state management Riverpod, maupun alur navigasi terintegrasi.
