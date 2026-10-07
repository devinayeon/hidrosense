# Modul 01: Sistem Desain Apple HIG (Design System & Tokens)

Dokumen ini mendefinisikan seluruh token desain antarmuka aplikasi **HidroSense Mobile** mengacu pada spesifikasi resmi **Apple Human Interface Guidelines (HIG)** dengan mempertahankan 100% palet warna produk yang sudah ada.

---

## 1. Sistem Warna Semantik (Semantic Color Tokens)

Apple HIG menekankan penggunaan warna semantik (*Semantic Colors*) daripada hardcoded hex di setiap widget. Warna semantik beradaptasi dengan peran dan konteks hierarki informasi.

### A. Palet Warna Utama (Retained Brand Colors)

```dart
// Definisi Token Warna HidroSense
class AppColors {
  // Brand & Accent Colors
  static const Color primaryMint      = Color(0xFF39C6C5); // rgb(57, 198, 195)
  static const Color primaryDarkTeal  = Color(0xFF168681); // rgb(22, 134, 129)
  static const Color accentLime       = Color(0xFFDDF45A); // rgb(221, 244, 90)
  static const Color darkNavy         = Color(0xFF172231); // rgb(23, 34, 49)

  // System Canvas & Surface
  static const Color canvasWarm       = Color(0xFFFAFAF7); // rgb(250, 250, 247)
  static const Color cardSurface      = Color(0xFFFFFFFF); // rgb(255, 255, 255)
  static const Color secondarySurface = Color(0xFFF3F4F6); // rgb(243, 244, 246)

  // Borders & Dividers
  static const Color borderLight      = Color(0xFFE5E7EB); // rgb(229, 231, 235)
  static const Color borderSubtle     = Color(0xFFF0F0EB); // rgb(240, 240, 235)
  static const Color borderAccent     = Color(0x6639C6C5); // mint 40% opacity

  // Semantic Status Colors
  static const Color successGreen     = Color(0xFF10B981); // Aktif, normal, cukup
  static const Color warningOrange    = Color(0xFFFF9A55); // Stok menipis, semai lewat umur
  static const Color warningBg        = Color(0xFFFFF3EC); // Background kartu peringatan
  static const Color dangerRed        = Color(0xFFEF4444); // Kerusakan, stok habis
  static const Color dangerBg         = Color(0xFFFEE2E2); // Background kartu bahaya
  static const Color infoBlue         = Color(0xFF3B82F6); // Rekomendasi cuaca BMKG
  static const Color infoBg           = Color(0xFFEFF6FF); // Background info BMKG

  // Typography Colors
  static const Color textPrimary      = Color(0xFF111827); // Judul, isi utama
  static const Color textSecondary    = Color(0xFF6B7280); // Subjudul, satuan, timestamp
  static const Color textTertiary     = Color(0xFF9CA3AF); // Placeholder, disabled
  static const Color textOnDark       = Color(0xFFFFFFFF); // Teks di atas Dark Navy
}
```

---

## 2. Skala Tipografi Apple HIG (*Type Ramp*)

Menggunakan font keluarga **Inter** dengan skala hierarki tipografi Apple HIG. Rasio ukuran, tebal huruf (*font weight*), dan tinggi baris (*line height*) distandarisasi untuk kenyamanan membaca di layar sentuh ponsel.

| HIG Role | Size (pt) | Weight | Line Height | Letter Spacing | Penggunaan di HidroSense |
|---|---|---|---|---|---|
| **Large Title** | `34pt` | Bold (`w700`) | `41pt` (1.2) | `-0.5px` | Judul layar utama (misal: "Beranda", "Inventaris") |
| **Title 1** | `28pt` | SemiBold (`w600`) | `34pt` (1.2) | `-0.3px` | Header halaman formulir / modal sheet |
| **Title 2** | `22pt` | SemiBold (`w600`) | `28pt` (1.25) | `-0.2px` | Judul kartu ringkasan batch / meja NFT |
| **Title 3** | `20pt` | SemiBold (`w600`) | `25pt` (1.25) | `-0.1px` | Header section pada dashboard |
| **Headline** | `17pt` | SemiBold (`w600`) | `22pt` (1.3) | `-0.4px` | Nama barang inventaris, label tombol utama |
| **Body** | `17pt` | Regular (`w400`) | `22pt` (1.3) | `-0.4px` | Isi teks deskripsi, catatan perawatan, instruksi |
| **Callout** | `16pt` | Regular (`w400`) | `21pt` (1.3) | `-0.3px` | Teks sorotan pada banner rekomendasi cuaca |
| **Subheadline** | `15pt` | Regular (`w400`) | `20pt` (1.3) | `-0.2px` | Subtitle kartu status, tanggal semai |
| **Footnote** | `13pt` | Regular (`w400`) | `18pt` (1.35) | `0.0px` | Metadata kecil, stok minimum threshold, id batch |
| **Caption 1** | `12pt` | Medium (`w500`) | `16pt` (1.35) | `0.0px` | Label tab bar navigasi, badge status capsule |
| **Caption 2** | `11pt` | Regular (`w400`) | `13pt` (1.2) | `0.1px` | Timestamp sinkronisasi offline |

### Fitur Angka Tabular (*Tabular Numerals*)
Untuk seluruh angka kuantitas stok, saldo inventaris, umur semaian (HSS), dan kapasitas lubang meja tanam, wajib menggunakan varian `fontFeatures: [FontFeature.tabularFigures()]` agar angka tidak bergeser saat nilai berubah (*jitter prevention*).

---

## 3. Sistem Grid & Spasi (*Spacing & Layout Rhythm*)

HIG menerapkan ritme spasi kelipatan 4pt dan 8pt. Seluruh komponen harus menggunakan token spasi berikut:

```dart
class AppSpacing {
  static const double xxs = 4.0;   // Jarak mikro antar badge/ikon kecil
  static const double xs  = 8.0;   // Jarak antar teks dan subtitle
  static const double sm  = 12.0;  // Padding internal tombol kecil / chip
  static const double md  = 16.0;  // Standar padding horizontal halaman & kartu
  static const double lg  = 20.0;  // Jarak antar kartu vertikal
  static const double xl  = 24.0;  // Margin tepi layar form / header section
  static const double xxl = 32.0;  // Jarak pemisah antar modul besar
  static const double xxxl= 40.0;  // Jarak hero ilustrasi / empty state
}
```

### Pedoman Layout:
- **Horizontal Screen Inset:** `16.0pt` pada ponsel standar; `24.0pt` pada layar tablet.
- **Max Content Width:** `480.0pt` untuk menjaga form tidak melar pada layar landscape/tablet.
- **Safe Area Inset:** Selalu gunakan `SafeArea` untuk menghormati dynamic island, notch, dan home indicator gesture bar.

---

## 4. Radius Sudut Melengkung Mulus (*Continuous Corner Radii / Squircles*)

Apple HIG menggunakan kurva sudut kontinyu (*superellipse/squircle*) untuk menghindari sudut tajam yang kaku.

```dart
class AppRadius {
  static const double badge = 8.0;   // Capsule status & chip kategori
  static const double input = 12.0;  // Input textfield & dropdown
  static const double card  = 16.0;  // Kartu inventaris, meja tanam, semai
  static const double modal = 24.0;  // Sudut atas modal bottom sheet
  static const double pill  = 999.0; // Filter button pill & floating action
}
```

---

## 5. Kedalaman & Efek Material (*Depth, Shadows & Vibrancy*)

Apple HIG membedakan hirarki melalui lapisan material dan bayangan difusi lembut (*soft diffusion shadow*):

### Bayangan Kartu (*Elevation Levels*)
- **Level 1 (Subtle Surface Card):**
  - Blur radius: `8.0pt`, Spread: `0.0pt`, Offset: `(0, 2)`, Warna: `Color.fromRGBO(0, 0, 0, 0.04)`.
  - Border pelindung: `Border.all(color: AppColors.borderSubtle, width: 1.0)`.
- **Level 2 (Active/Lifted Card):**
  - Blur radius: `16.0pt`, Spread: `0.0pt`, Offset: `(0, 6)`, Warna: `Color.fromRGBO(0, 0, 0, 0.08)`.
- **Level 3 (Modal Sheet & Floating Navigation):**
  - Blur radius: `24.0pt`, Spread: `0.0pt`, Offset: `(0, -4)`, Warna: `Color.fromRGBO(0, 0, 0, 0.10)`.

### Efek Material Translusen (*Blur / Vibrancy*)
- Pada Header/App Bar dan Bottom Navigation Bar, gunakan `BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16))` dengan warna latar `Color.fromRGBO(250, 250, 247, 0.85)` agar konten di belakangnya terlihat lembut saat digulir (*iOS scroll-under translucency*).

---

## 6. Token Komponen Standar

### A. Tombol Aksi Utama (Primary Action Button)
- **Background:** `AppColors.darkNavy` (`#172231`).
- **Teks/Ikon:** `AppColors.cardSurface` (`#FFFFFF`) atau `AppColors.accentLime` (`#DDF45A`).
- **Tinggi:** `52.0pt` (memenuhi standar touch target HIG $\ge 44pt$).
- **Radius:** `14.0pt` atau `AppRadius.card`.
- **Micro-interaction:** Animated scale `0.975` saat ditekan.

### B. Tombol Aksi Cepat / Highlight (Accent Action Button)
- **Background:** `AppColors.accentLime` (`#DDF45A`).
- **Teks/Ikon:** `AppColors.darkNavy` (`#172231`).
- **Penggunaan:** Tombol "+ Semai" dan "Panen Cepat".

### C. Kartu Status & Info (Interactive Row Card)
- **Background:** `AppColors.cardSurface` (`#FFFFFF`).
- **Border:** `1.0pt` solid `AppColors.borderLight`.
- **Padding:** `16.0pt` horizontal, `14.0pt` vertikal.
- **Leading:** Ikon bulat dalam container tint `AppColors.primaryMint` (15% opacity).
- **Trailing:** Chevron `Icons.chevron_right_rounded` dengan warna `AppColors.textTertiary`.

### D. Badge Status Kapsul (Capsule Badge)
- **Tinggi:** `26.0pt`, Padding: `horizontal: 10.0pt, vertical: 4.0pt`.
- **Radius:** `AppRadius.pill` (`999.0pt`).
- **Varian:**
  - *Aktif / Tersedia:* Background `Color(0x1A10B981)`, Teks `AppColors.successGreen`.
  - *Peringatan / Siap Pindah:* Background `AppColors.warningBg`, Teks `AppColors.warningOrange`.
  - *Habis / Perbaikan:* Background `AppColors.dangerBg`, Teks `AppColors.dangerRed`.
