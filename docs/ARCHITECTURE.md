# Arsitektur HidroSense

Peta satu halaman untuk anggota tim baru, termasuk yang bukan programmer. Untuk daftar lengkap endpoint, lihat [`apps/backend/API.md`](../apps/backend/API.md). Untuk menjalankan sistem, lihat [`README.md`](../README.md).

## Gambaran besar

HidroSense punya dua bagian dalam satu repositori:

| Folder | Isi | Teknologi |
|---|---|---|
| `apps/mobile` | Aplikasi di ponsel petani dan pegawai | Flutter, Riverpod, SQLite |
| `apps/backend` | Server API dan aturan bisnis | Node, TypeScript, Fastify, SQLite (libSQL/Turso) |
| `ml` | Pelatihan dan ekspor model deteksi hama (thrips, kutu kebul, kutu daun). Hasil `.tflite` ditanam di `apps/mobile/assets/ml/` dan berjalan di ponsel | YOLOv11n, TFLite |

```
  Ponsel                                     Server
┌───────────────────────────────┐         ┌──────────────────────────────┐
│ View        (layar)           │         │ Controller  (rute, validasi) │
│   │                           │         │   │                          │
│ ViewModel   (keadaan layar)   │         │ Model: service (aturan)      │
│   │                           │  HTTPS  │   │                          │
│ Repository  (ambil/kirim data)│◄───────►│ Model: store (SQL)           │
│   │                           │         │   │                          │
│ ApiClient, SQLite cache       │         │ Database SQLite/Turso        │
└───────────────────────────────┘         └──────────────────────────────┘
```

Cuaca diambil aplikasi langsung dari API BMKG, tidak lewat server HidroSense. Saran tindakan cuaca dihitung dengan logika fuzzy di aplikasi, hanya dikirim sebagai notifikasi, dan tidak disimpan.

Deteksi hama berjalan di ponsel. Foto diunggah langsung ke Cloudinary dengan tanda tangan dari server (`api_secret` hanya di server); server menyimpan hasil pindai dan rekomendasi rotasi obat.

## Peta MVC

Rencana menyebut arsitektur MVC. Kodenya tidak memakai folder bernama `controllers`, jadi tabel ini menunjukkan letak tiap peran.

| Peran | Mobile | Backend |
|---|---|---|
| **Model** (data dan aturan) | `lib/data/models`, `lib/models`, `lib/data/repositories`, `lib/data/services`, `lib/core`, `lib/features/*/data` | `features/*/service.ts` (aturan), `features/*/store.ts` (SQL), `common/*`, `migrations/` |
| **View** (yang dilihat pengguna) | `lib/views/pages`, `lib/views/components`, `lib/views/widgets`, `lib/features/*/presentation/{pages,widgets}` | Fungsi pengubah baris ke JSON di `store.ts` (misalnya `tableRow`, `sowingRow`) |
| **Controller** (penghubung) | `lib/viewmodels`, `lib/features/*/presentation/viewmodels` | `features/*/index.ts` dan berkas per aksi (rute), `contracts.ts` (validasi input), `write.ts` (pembungkus tulis) |

Di mobile, peran Controller dijalankan oleh ViewModel (pola MVVM yang umum di Flutter). Arah panggilannya satu jalur: View memanggil ViewModel, ViewModel memanggil Repository, Repository memanggil ApiClient.

## Susunan satu fitur backend

Tiap folder di `apps/backend/src/features/` mengikuti pola yang sama:

| Berkas | Tugas |
|---|---|
| `index.ts` | Daftar rute fitur itu |
| `contracts.ts` | Bentuk input yang diterima |
| `write.ts` | Membungkus tulis: login, izin, transaksi, dan anti-duplikat |
| `service.ts` | Aturan bisnis |
| `store.ts` | SQL dan bentuk JSON keluaran |

`apps/backend/src/app.ts` adalah titik masuk: bacalah daftar `register*` di sana untuk melihat semua fitur. Di mobile, titik masuknya `lib/main.dart`, lalu `lib/views/pages/app_gate.dart`.

## Enam alur utama

**1. Login.** Pengguna mengisi username dan password. Server membatasi 10 percobaan per 15 menit untuk satu username dari satu alamat, memeriksa password, lalu membuat sesi. Token akses berlaku 15 menit. Sesi berakhir 7 hari setelah refresh terakhir, dan paling lama 30 hari sejak login.
Berkas: `login_page.dart`, `session_viewmodel.dart`, `api_client.dart`, `features/auth/login.ts`.

**2. Mencatat stok.** Setiap perubahan stok adalah baris baru di buku yang tidak pernah dihapus. Saldo adalah jumlah semua baris. Stok keluar yang melebihi saldo ditolak. Kesalahan dibetulkan dengan menambah baris yang berlawanan.
Berkas: `add_form_inventaris_page.dart`, `connected_inventory_viewmodel.dart`, `inventory_repository.dart`, `features/stock/service.ts`, `features/stock/store.ts`.

**3. Menyemai.** Petani mengisi tanggal semai, jumlah benih, dan stok benih yang dipakai. Server menyimpan penyemaian berstatus aktif dan mengurangi stok dalam satu transaksi. Bila stok kurang, tidak ada yang tersimpan.
Berkas: `seeding_form_page.dart`, `connected_nursery_viewmodel.dart`, `nursery_repository.dart`, `features/nursery/service.ts`.

**4. Memindahkan bibit ke meja.** Boleh bila bibit berumur minimal 15 hari, penyemaian masih aktif, jumlahnya tidak melebihi sisa bibit, meja berstatus tersedia, dan lubangnya cukup. Meja menjadi penuh bila semua lubang terisi. Penyemaian selesai bila semua bibit sudah pindah. Estimasi panen 45 hari dari tanggal pindah.
Berkas: `seedling_transfer_sheet.dart`, `connected_nursery_viewmodel.dart`, `features/transfers/service.ts`.

**5. Panen lalu jual.** Panen mencatat jumlah tanaman, berat total, dan berat reject per batch. Berat layak adalah total dikurangi reject. Penjualan memilih satu panen, berat, dan harga per kilogram. Berat yang dijual tidak boleh melebihi berat layak dikurangi yang sudah terjual.
Berkas: `panen_form_body.dart`, `panen_viewmodel.dart`, `catat_penjualan_body.dart`, `penjualan_viewmodel.dart`, `features/harvest/service.ts`, `features/sales/service.ts`.

**6. Pindai hama lalu rotasi obat.** Hanya petani. Foto dianalisis di ponsel (YOLOv11n). Saat disimpan, foto diunggah ke Cloudinary, hasilnya disimpan sebagai `hasil_deteksi` dengan hitungan per hama di `deteksi_hama`, lalu satu `rekomendasi_perawatan` dibuat per hama. Mesin rotasi menghindari kelompok MoA (IRAC) dari 2 `perawatan` ber-MoA terakhir di meja itu dan mengikuti urutan PHT. Menerima membuat baris `perawatan` (tindakan nyata, sumber riwayat rotasi); menolak wajib beralasan. Keputusan final dijaga trigger database.
ERD: `docs/erd-deteksi-rotasi.dbml`.
Berkas: `features/pest/presentation/pages/pest_scan_page.dart`, `pest_scan_viewmodel.dart`, `pest_repository.dart`, `yolo_decoder.dart`, `features/scans/service.ts`, `features/rotation/engine.ts`, `features/rotation/service.ts`.

## Daftar istilah

| Istilah | Arti | Nama di database dan API | Nama di Dart |
|---|---|---|---|
| Penyemaian | Benih mulai ditanam di tempat semai; memakai stok benih | `penyemaian` | `SowingRecord` |
| HSS | Hari Setelah Semai | `usia_hari`, `hss` | `ageDays` |
| Pemindahan | Bibit dipindah ke meja tanam; minimal 15 HSS | `pemindahan` | `TransferRecord` |
| HST | Hari sejak pindah ke meja (dari kode; rencana tidak mendefinisikannya) | `hst` | `hst` |
| Batch | Sekelompok tanaman dari satu pemindahan | `id_pemindahan` | `TransferRecord` |
| Meja tanam | Meja NFT; kapasitasnya dalam lubang | `meja_tanam`, `jumlah_lubang` | `TableRecord` |
| Tanaman aktif | Dipindahkan dikurangi rusak dikurangi dipanen | `tanaman_aktif` | `activePlants` |
| Panen | Hasil panen per batch | `panen`, `detail_panen` | `HarvestRecord` |
| Berat layak | Berat total dikurangi berat reject | `berat_layak` | `HarvestWeight` |
| Penjualan | Penjualan panen: berat kali harga per kilogram | `penjualan`, `detail_penjualan` | `SaleRecord` |
| Transaksi stok | Satu catatan stok masuk atau keluar yang tidak pernah diubah | `stok`, `detail_stok` | `StockMovementRecord` |
| Saldo | Total semua transaksi stok | `stok_saldo` | `balance` |
| Reversal | Transaksi berlawanan yang membatalkan transaksi lama | `reversal_of` | tidak ada |
| Idempotency-Key | Nomor tiket tulis, supaya pengiriman ulang tidak mencatat dua kali | header `Idempotency-Key` | `key` |
| Versi | Nomor perubahan record, untuk mendeteksi dua orang mengubah data yang sama | `version`, `expected_version` | `version` |
| Minor | Angka disimpan dalam perseratus: 2,50 menjadi 250 | `*_minor` | `minor` |
| Hasil deteksi | Satu foto pindai beserta hitungan per hama | `hasil_deteksi`, `deteksi_hama` | `PestScanResult`, `ScanFindingDraft` |
| MoA | Kelompok cara kerja insektisida (skema IRAC); yang dirotasi, bukan merek | `moa_groups`, `kode_moa` | `moaCode` |
| Rekomendasi | Saran obat untuk satu meja dan hama; menunggu, diterima, atau ditolak | `rekomendasi_perawatan` | `PestRecommendation` |
| Perawatan | Tindakan nyata saat rekomendasi diterima; sumber riwayat rotasi | `perawatan` | `appliedOn`, `careNote` |

## Aturan yang ada di dua tempat

Server selalu menjadi penentu. Aplikasi menyalin beberapa aturan hanya supaya formulir bisa memberi tahu lebih cepat.

| Aturan | Server | Aplikasi |
|---|---|---|
| 15 hari sebelum pindah, estimasi panen 45 hari dari tanggal pindah | `apps/backend/src/common/growth-rules.ts` | `apps/mobile/lib/core/growth_rules.dart` |
| Kode hama (`thrips`, `whitefly`, `aphids`) dan urutan kelas model | `apps/backend/src/common/pests.ts`, tabel `hama` | `apps/mobile/lib/features/pest/domain/pest_summary.dart` (`PestKind`), `assets/ml/labels.txt` |
| Tingkat serangan dan alasan penolakan | `apps/backend/src/features/rotation/contracts.ts` | `pest_summary.dart` (`PestSeverity`), `pest_models.dart` (`RejectReason`) |

## Bila respons server hilang saat menulis

Aplikasi tidak tahu apakah kiriman sudah tersimpan. Isian dikunci dan hanya bisa dikirim ulang dengan isi dan kunci yang sama, sehingga server tidak mencatat dua kali. Penolakan 401, 403, dan 429 tidak melepas kuncian, karena server menolaknya sebelum memeriksa kunci. Berkas: `lib/data/services/write_outcome.dart`, `lib/viewmodels/sale_command.dart`.
