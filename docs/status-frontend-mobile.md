# Laporan Status Penyelesaian Frontend Mobile (Flutter)

Dokumen ini merekam evaluasi kelengkapan fitur, arsitektur, dan kesiapan operasional dari modul `apps/mobile` terhadap spesifikasi PRD/SRS ([A9_PPL IF_WEEK5.docx.md](../docs/A9_PPL%20IF_WEEK5.docx.md)) dan acuan timeline ([timeline-pengembangan.md](../docs/timeline-pengembangan.md)).

---

## 1. Ringkasan Eksekutif

| Indikator | Status | Catatan |
|---|---|---|
| **Penyelesaian UI / Screen** | **~80%** | Sebagian besar halaman CRUD, visualisasi dashboard, dan form telah diimplementasikan menggunakan Flutter & Riverpod. |
| **Integrasi Data / Backend** | **0% (Mock Data)** | Seluruh ViewModel masih memakai in-memory dummy/mock list (`Future.delayed`). Belum ada HTTP client (`dio`/`http`). |
| **Offline-First & SQLite** | **0%** | Belum ada plugin database lokal (`sqflite`/`drift`) dan sinkronisasi ke backend Turso. |
| **Model ML / TFLite** | **0%** | Deteksi hama YOLO/TFLite serta integrasi kamera/galeri belum ada di `apps/mobile`. |
| **Autentikasi & RBAC** | **20% (UI profil statis)** | Tidak ada alur login/token sesi; pembatasan peran Petani vs Pegawai belum diimplementasikan di UI routing. |

---

## 2. Matriks Penyelesaian Backlog (PB)

| Kode PB | Modul / Fitur | Status UI | Status Logika & Data | Gap Utama |
|---|---|:---:|:---:|---|
| **PB-01** | Autentikasi & Hak Akses | ⚠️ Sebagian | ❌ Belum | Ada `AccountPage`, tetapi tidak ada flow Login, refresh token, maupun guards menu (Petani vs Pegawai). |
| **PB-02** | Inventaris & Stok | ✅ Lengkap | ⚠️ Mock | `InventarisBody`, form tambah, dan detail item lengkap; mutasi hanya disimpan di state Riverpod lokal. |
| **PB-03** | Penyemaian & Batch | ✅ Lengkap | ⚠️ Mock | `PenyemaianBody`, form semai, dan info seeding ada; umur bibit dihitung lokal. |
| **PB-04** | Meja NFT & Kerusakan | ✅ Lengkap | ⚠️ Mock | List meja, baris tanam, form meja, form catat kerusakan ada; belum ada validasi batas kapasitas meja vs backend. |
| **PB-05** | Deteksi Hama (YOLO) | ❌ Belum | ❌ Belum | Belum ada layar pemindaian kamera, pipeline inferensi TFLite, dan penyimpanan riwayat deteksi hama. |
| **PB-06** | Rekomendasi Perawatan | ⚠️ Sebagian | ⚠️ Mock | Halaman rekomendasi cuaca ada; rekomendasi penanganan hama berbasis riwayat obat belum ada. |
| **PB-07** | Sinkronisasi & SQLite | ❌ Belum | ❌ Belum | Dependensi `sqflite` belum ada di `pubspec.yaml`; belum ada skema lokal maupun sync engine. |
| **PB-08** | Panen | ✅ Lengkap | ⚠️ Mock | `PanenPage`, form catat panen, dan laporan panen selesai secara UI. |
| **PB-09** | Penjualan | ✅ Lengkap | ⚠️ Mock | `PenjualanPage` dan form catat penjualan ada; belum ada pembatasan hak akses eksklusif Petani. |
| **PB-10** | Cuaca BMKG | ✅ Lengkap | ⚠️ Mock | `CuacaPage` dan `RekomendasiCuacaPage` selesai secara UI; data cuaca masih mock statis. |

---

## 3. Temuan Teknis & Code Review (`/caveman-review`)

- `pubspec.yaml:L30-40`: 🔴 bug: dependensi network & local persistence nihil (`http`/`dio`, `sqflite`). Tambahkan paket untuk koneksi API & offline-first.
- `apps/mobile/lib/main.dart:L20`: 🟡 risk: aplikasi langsung membuka `MainPage` tanpa session/auth guard. Pasang routing guard berbasis status login.
- `apps/mobile/lib/views/components/dashboard_body.dart:L55`: 🔵 nit: tombol action `+ Semai` kosong. Hubungkan ke `SeedingFormPage`.
- `apps/mobile/lib/views/components/dashboard_body.dart:L112`: 🔵 nit: action `Cek Stok` kosong. Hubungkan tab/navigasi ke `InventarisBody`.
- `apps/mobile/lib/viewmodels/inventaris_viewmodel.dart:L54`: 🟡 risk: mock data statis hardcoded dengan `Future.delayed`. Abstraksikan ke Repository layer untuk injeksi HTTP/SQLite.
- `apps/mobile/lib/views/pages/penjualan_page.dart:L1`: 🔴 bug: penjualan terbuka bebas tanpa verifikasi role Petani. Terapkan RBAC guard sesuai System Request.
- `pubspec.yaml:L30`: 🔴 bug: tidak ada library camera/tflite untuk YOLO (PB-05). Pasang `camera`, `image_picker`, dan runtime TFLite saat sprint ML dimulai.

---

## 4. Rekomendasi Langkah Selanjutnya

1. **Abstraksi Repository Layer:**
   Buat antarmuka repository (`InventoryRepository`, `NurseryRepository`, dll.) agar UI beralih dari mock data ke API backend `apps/backend`.
2. **Setup SQLite & Sync Engine (PB-07):**
   Implementasikan penyimpanan tabel lokal berbasis SQLite untuk mendukung operasi offline hidroponik di lapangan.
3. **Penguatan RBAC (Role-Based Access Control):**
   Sembunyikan menu Penjualan bagi Pegawai sesuai aturan hak akses di dokumen arsitektur.
