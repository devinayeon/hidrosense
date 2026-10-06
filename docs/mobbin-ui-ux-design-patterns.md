# Pola Desain UI & UX Mobbin untuk Aplikasi Mobile HidroSense

Dokumen ini mendokumentasikan adopsi pola UI/UX berstandar industri dari **Mobbin** (referensi aplikasi kelas dunia seperti *Things 3*, *Linear*, *Apple Health*, dan *Stripe Express*) yang disesuaikan untuk sistem hidroponik HidroSense.

---

## 1. Analisis & Inspirasi Pola Mobbin

Mengacu pada prinsip evaluasi Mobbin (*Taste & Scoping Rules*):
- **Change the least that answers the problem:** Menyederhanakan dan merapikan komponen yang ada tanpa merombak paksa tata letak yang sudah bekerja.
- **One thing leads:** Setiap layar memiliki titik fokus utama (Primary Focal Point) yang tegas dalam 2 detik pertama.
- **Don't add for the sake of adding:** Menghindari dekorasi berlebihan seperti gradien asing atau shadow tebal yang mengaburkan data agronomi.

| Referensi Pola | Karakteristik Utama | Penerapan di HidroSense |
|---|---|---|
| **Apple HIG / Things 3** | Header ringkas dengan tombol aksi sudut ergonomis & *back button* responsif. | [Header](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/views/components/header.dart) dan [CustomBackButton](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/views/widgets/custom_back_button.dart) dengan respons skala sentuh pegas (`0.92`). |
| **Stripe Express** | Kolom input bersih (*inset style*), label jelas di luar kontainer, validasi kartu peringatan kontras. | [LoginPage](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/views/pages/login_page.dart) dengan ikon depan, border tipis abu-abu lembut (`#E5E7EB`), dan tombol pill CTA. |
| **Linear Mobile** | Kartu daftar interaktif dengan pembagi metadata dot (`•`), status badge pastel, dan tactile tap response. | [RowInfoCardMd](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/views/widgets/row_info_card_md.dart) pada modul Inventaris, Penyemaian, dan Meja Tanam. |
| **Apple Health Metrics** | Visualisasi meter progres yang terisi bertahap untuk memvisualisasikan data kuantitatif. | Progres semai (HSS) dan okupansi lubang meja tanam dengan `TweenAnimationBuilder` (400ms, `Curves.easeOutCubic`). |

---

## 2. Peningkatan Nyata pada Layar Aplikasi

### A. Layar Masuk ([LoginPage](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/views/pages/login_page.dart))
1. **Visual Anchor:** Ikon kecambah melingkar dengan aksen warna teal lembut di atas judul utama.
2. **Input Inset:** Kolom pengguna dan kata sandi menggunakan latar putih bersih, radius `16pt`, dan ikon penunjuk yang jelas.
3. **Pesan Kesalahan Terisolasi:** Pesan error server ditampilkan dalam kotak peringatan merah pastel yang mudah dibaca tanpa menggeser tombol masuk secara canggung.
4. **Primary CTA:** Tombol pill lebar penuh dengan warna Dark Navy dan teks Lime (`#DDF45A`).

### B. Beranda & Dasbor ([DashboardBody](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/views/components/dashboard_body.dart))
1. **Ringkasan Kapasitas:** Dua kartu atas (Kapasitas NFT & Estimasi Panen) langsung menyajikan metrik kunci kebun.
2. **Akses Cepat Fungsional:** Tombol pintas `+ Barang`, `+ Semai`, `Cek Stok`, `Meja NFT`, `Cuaca`, dan `Panen` semuanya terhubung ke navigasi riil dengan ripple sentuhan halus.
3. **Feed Peringatan Real-Time:** Kartu notifikasi (semaian siap pindah & cuaca) berbingkai warna oranye dan toska lembut.

### C. Navigasi & Kartu Modul
1. **Sentuhan Fisik Konsisten:** Setiap kartu yang dapat diklik ([RowInfoCardMd](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/views/widgets/row_info_card_md.dart)) dan tombol ([RowButton](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/views/widgets/row_button.dart), [ColButton](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/views/widgets/col_button.dart), [FilterButton](file:///d:/Dev/Projects/hidrosense/apps/mobile/lib/views/widgets/filter_button.dart)) memberikan animasi tekan seketika (100–120ms) agar terasa hidup.
2. **Interpolasi Progres Halus:** Angka rasio bibit sehat dan lubang meja terisi tidak melompat statis, melainkan meluncur mulus.

---

## 3. Hasil Verifikasi & Standar Kode

- **Tes Unit & Integrasi:** 13/13 tes otomatis Flutter tetap lulus 100%.
- **Batas Baris Kode:** Setiap file dirancang modular dengan panjang antara 45 hingga 270 baris (< ambang batas 300–400 baris).
- **Integritas Brand:** Palet warna identitas tidak dirusak: Teal (`#39C6C3`), Dark Navy (`#172231`), Lime (`#DDF45A`), dan Latar Gading Bersih (`#FAFAF7`).
