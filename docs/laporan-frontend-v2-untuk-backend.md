# Laporan Front-end v2 untuk Backend

Tanggal: 19 November 2026
Konteks: pengujian langsung alur v2 memakai akun `petani` (seed) di
`apps/mobile`. Empat temuan dicatat pengguna; semuanya diperbaiki di sisi
front-end tanpa mengubah `apps/backend`.

## Ringkasan

| # | Temuan | Penyebab utama | Status front-end | Perlu backend? |
|---|--------|----------------|------------------|----------------|
| 1 | Menu Lainnya > Penjualan berhenti di skeleton | Halaman hanya menangani satu jenis galat; galat lain meninggalkan status memuat | Selesai: semua galat menutup skeleton dan menampilkan "Gagal memuat" + "Coba lagi" | Tidak wajib; endpoint sudah 200 |
| 2 | Kartu "stok menipis" di Beranda berbeda dari tab Stok dan bottom nav mati | Kartu membuka halaman fixture (`V2InventarisListPage.menipisBenih`) yang memakai `V2TabBar` tanpa `onTap` | Selesai: kartu membuka tab Stok tersambung dengan saringan Benih + Menipis; navigasi bawah tetap hidup | Perlu keputusan definisi angka (lihat bawah) |
| 3 | Semaian 12 Nov pada 19 Nov menampilkan HSS 3 | Model desain memakai tanggal acuan tetap 15 Nov 2026 | Selesai: data tersambung memakai `usia_hari` dari server | Tidak; backend sudah mengirim `usia_hari` dan `siap_pindah` |
| 4 | Tambah meja menampilkan "Input tidak sesuai kontrak API." | `jumlah_lubang` 1231 melebihi batas kontrak 1000; aplikasi hanya memvalidasi > 0 | Selesai: validasi field lokal + terjemahan pesan validasi teknis | Disarankan: detail field pada respons validasi |

## Detail dan catatan untuk backend

### 1. Penjualan berhenti di skeleton

- Endpoint yang dipakai sudah diverifikasi dengan token `petani`:
  - `POST /api/v1/auth/login` berhasil.
  - `GET /api/v1/penjualan?page=1&limit=100` mengembalikan 200, 2 baris,
    `meta.total_pages = 1`.
  - `GET /api/v1/panen?page=1&limit=100` mengembalikan 200, 1 baris.
- Jadi tidak ada kontrak backend yang dilanggar pada data seed saat ini.
  Penyebab yang terbukti di front-end: `_load()` hanya menangkap
  `V2PenjualanStoreException`. Galat lain (mis. bentuk respons berubah,
  `FormatException`) membuat status memuat tidak pernah ditutup.
- Perbaikan front-end: `_load()` sekarang memakai `finally` sehingga skeleton
  selalu berakhir, dan galat tak terduga dipetakan lewat `serviceError`.
- Yang bisa dilakukan backend:
  1. Pertahankan bentuk respons `data` + `meta` seperti sekarang.
  2. Saat ada galat, sertakan `request_id` (sudah ada) dan pastikan pesan
     tidak berubah-ubah bentuknya, supaya log tester bisa dicocokkan.

### 2. Kartu "stok menipis" Beranda

- Sebelum perbaikan, kartu membuka halaman fixture desain, bukan data
  tersambung. Itu sebabnya isinya berbeda dari tab Stok, dan `V2TabBar` di
  halaman itu tidak punya aksi sehingga bottom nav terasa mati.
- Sesudah perbaikan, kartu berpindah ke tab Stok yang sama dengan tab Stok
  biasa, lalu menerapkan saringan **Benih + Menipis** (frame 4.9). Tab
  bawah tetap bisa dipakai dan tombol kembali perangkat bekerja normal.
- **Perlu keputusan produk/backend:** angka pada kartu dihitung dari
  `inventory.activeRecords.where((item) => item.isLow)` untuk **semua jenis**
  barang, sedangkan tujuan kartu disaring ke **Benih** saja. Pada data seed
  saat ini angkanya kebetulan cocok (hanya satu benih yang menipis), tetapi
  bisa berbeda bila nutrisi atau perlengkapan juga di bawah minimum.
  - Opsi A: angka kartu dihitung khusus benih (paling cocok dengan tujuan 4.9).
  - Opsi B: tujuan kartu tidak difilter jenis, hanya "Menipis".
  - Front-end siap mengikuti keputusan mana pun; saat ini memakai Opsi A
    secara tampilan (daftar Benih + Menipis), tetapi angka masih agregat.

### 3. Perhitungan HSS semaian

- Backend sudah mengirim:
  - `usia_hari`: selisih hari kalender dari `tanggal_semai` sampai hari ini
    (basis Asia/Jakarta, `jakartaDate`).
  - `siap_pindah`: `usia_hari >= 15`.
- Front-end sebelumnya mengabaikan `usia_hari` dan menghitung sendiri dari
  tanggal acuan desain `15 Nov 2026`, sehingga semaian 12 Nov selalu HSS 3.
- Perbaikan front-end: `v2SemaianItemFromRecord` memakai `record.ageDays`
  (field `usia_hari`) sebagai HSS. Data contoh galeri tetap memakai tanggal
  acuan desain agar frame tidak bergeser.
- Yang bisa dilakukan backend:
  1. Pertahankan `usia_hari` dan `siap_pindah` di semua respons penyemaian
     (daftar dan detail).
  2. Pastikan perhitungan tetap memakai tanggal kalender Asia/Jakarta, bukan
     UTC mentah, agar pergantian hari tidak menghasilkan selisih satu hari.

### 4. Pesan validasi tambah meja

- Kasus pengguna: kode `test`, jumlah lubang `1231`, keterangan `tset`.
- Kontrak backend (`apps/backend/src/features/tables/contracts.ts`):
  - `kode_meja`: string 1–30 karakter.
  - `jumlah_lubang`: bilangan bulat positif, maksimum **1000**.
  - `keterangan`: maksimum 1000 karakter.
- `1231` melanggar batas `jumlah_lubang`. Pesan yang keluar adalah
  `Input tidak sesuai kontrak API.` tanpa menyebut field mana.
- Perbaikan front-end:
  - Form meja memvalidasi `jumlah_lubang` 1–1000 dan `kode_meja` maksimal 30
    karakter, dengan pesan tepat di bawah field.
  - `serviceError` menerjemahkan pesan validasi teknis menjadi
    "Ada isian yang belum sesuai. Periksa kembali data yang Anda masukkan."
    Pesan validasi yang sudah jelas (mis. "Tanggal panen tidak boleh di masa
    depan.") tidak diubah.
- Rekomendasi untuk backend (tidak memblokir rilis):
  1. Kirim detail field pada respons validasi, misalnya:

     ```json
     {
       "error": {
         "code": "VALIDATION_ERROR",
         "message": "Input tidak sesuai kontrak API.",
         "details": [
           { "field": "jumlah_lubang", "message": "Maksimal 1000." }
         ]
       }
     }
     ```

     Front-end bisa langsung menempelkan pesan itu ke field yang salah.
  2. Cantumkan batas angka (1000 lubang, 30 karakter kode, 1000 karakter
     keterangan) di `API.md` supaya bisa dicek tanpa membaca kode.

## Berkas front-end yang berubah

- `lib/views/v2/pages/v2_penjualan_list_page.dart`
- `lib/views/v2/pages/v2_beranda_page.dart`
- `lib/views/v2/pages/v2_beranda_connected_page.dart`
- `lib/views/v2/components/v2_semaian_data.dart`
- `lib/views/v2/connected/v2_semaian_connected.dart`
- `lib/views/v2/pages/v2_meja_form_page.dart`
- `lib/viewmodels/session_viewmodel.dart`

## Verifikasi

- `flutter analyze`: hanya 2 peringatan aset lama
  (`assets/illustrations/inventory/` dan `assets/illustrations/features/`).
- `flutter test`: 453 tes lulus (sebelumnya 443), termasuk tes baru untuk
  keempat temuan.