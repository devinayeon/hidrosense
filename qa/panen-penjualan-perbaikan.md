# Hasil — Perbaikan alur Panen & Penjualan (sesi 10 lanjutan 4)

Tanggal: 27 November 2026 · Branch: `wild-fe`
Rencana: `mcdocs/panen-penjualan-perbaikan-plan.md` · Tasks:
`mcdocs/panen-penjualan-perbaikan-tasks.md`

Perubahan **front-end saja** (`apps/mobile/`). Backend tidak disentuh. Field
wire `status_pembayaran` dan model `V2PenjualanBayar` tetap ada agar pemetaan
server/antrean lama tidak berubah; yang berubah hanya tampilan dan pilihan
status di aplikasi.

## Ringkasan

| # | Permintaan | Hasil |
|---|---|---|
| 1 | Catat panen: "Berat layak" hilang saat galat | Kartu kini dirender tanpa syarat `!_adaError`; nilainya tetap terlihat saat petani memperbaiki isian. |
| 2 | Catat panen: pemilih hanya tanaman siap panen | Predikat baru `v2TanamanSiapDipanen`: HST ≥ 45 **atau** HSS ≥ 60. Daftar, chip meja, dan pilihan awal memakai batch siap. Baris galeri tanpa tanggal pindah/HSS tetap tampil. Bila belum ada yang siap, sheet menjelaskan "Belum ada tanaman yang siap dipanen…". |
| 3 | Ubah panen: loading dulu, jangan langsung kembali | Perilaku `showV2ActionDialog` (spinner, tombol batal/back mati, pop hanya setelah `onConfirm`) sudah benar; ditambah tes regresi yang membuktikan spinner muncul, form tetap terbuka, dan galat server tampil sebagai pesan. |
| 4 | Panen: mengapa "lihat data panen" lebih lambat? | **Penyebab:** `PanenViewModel.refresh()` menunggu `Future.wait([riwayat panen, daftar batch])` selesai, padahal riwayat panen dipanggil dengan limit 100 + detail bersarang; tab juga mengambil daftar batch dua kali (VM + `v2AllTransfersProvider`). **Perbaikan:** riwayat dan batch diterbitkan terpisah (`recordsLoaded`/`transfersLoaded`), tab memakai `state.transfers` (satu ambilan), dan tab menampilkan kerangka per chip sampai data chip itu tiba. |
| 5 | Catat penjualan: hapus "Status pembayaran" | Isian segmentasi Pembayaran hilang; setiap simpan mengirim `lunas`. |
| 6 | Penjualan: hapus saringan Lunas/Belum lunas | Saringan, lencana status bayar (daftar + detail), baris "Belum lunas" di ringkasan bulanan, dan tombol "Tandai lunas" dihapus. Baris antrean tetap berlencana "Antrean". |

## Rincian perubahan berkas

- `apps/mobile/lib/views/v2/pages/v2_panen_form_page.dart`
  - `_kartuLayak()` selalu dirender; komentar kelas disesuaikan.
- `apps/mobile/lib/views/v2/components/v2_panen_data.dart`
  - Konstanta `v2PanenUmurHss = 60`.
- `apps/mobile/lib/views/v2/pages/v2_panen_tanaman_sheet.dart`
  - `v2TanamanSiapDipanen()` (HST/HSS; data tak diketahui lolos).
  - `_siap` menyaring `widget.pilihan`; chip meja, pencarian, pilihan awal, dan
    pesan kosong memakai daftar siap.
- `apps/mobile/lib/viewmodels/panen_viewmodel.dart`
  - `PanenState.recordsLoaded`/`transfersLoaded`.
  - `refresh()` menerbitkan `records` dan `transfers` di `.then` masing-masing;
    galat tetap menandai keduanya termuat.
  - `acknowledgeConflict` mempertahankan penanda muat.
- `apps/mobile/lib/views/v2/connected/v2_panen_connected.dart`
  - Tab dan Detail memakai `panenViewModelProvider.transfers` (hapus ambilan
    `v2AllTransfersProvider` yang sama).
  - Meneruskan `estimasiLoading`/`riwayatLoading`.
- `apps/mobile/lib/views/v2/pages/v2_panen_list_page.dart`
  - Properti `estimasiLoading`/`riwayatLoading`; kerangka per chip selama data
    chip belum ada; "Belum ada tanaman" tidak muncul saat estimasi dimuat.
- `apps/mobile/lib/views/v2/pages/v2_penjualan_form_page.dart`
  - Hapus state/segmentasi `_pembayaran`; draft selalu
    `V2PenjualanBayar.lunas`.
- `apps/mobile/lib/views/v2/pages/v2_penjualan_list_page.dart`
  - Hapus `filterIndex`, `_filters`, `_filtered`, `_buildChips`, `extra`/`badge`
    ringkasan, dan konstruktor `.belumLunas`.
- `apps/mobile/lib/views/v2/components/v2_penjualan_row.dart`
  - Lencana hanya "Antrean"; status bayar tidak ditampilkan.
- `apps/mobile/lib/views/v2/pages/v2_penjualan_detail_page.dart`
  - Hapus `_markPaid`, tombol "Tandai lunas", dan lencana status bayar; catatan
    antrean menjadi "Penjualan belum sinkron ke server."
- `apps/mobile/lib/views/v2/pages/v2_penjualan_summary_page.dart`
  - Hapus baris "Belum lunas" (galeri dan data nyata).
- `apps/mobile/lib/views/v2/components/v2_penjualan_data.dart`
  - Hapus `belumLunas`/`adaBelumLunas` dari `V2PenjualanRingkasan`,
    `belumLunas` dari `V2PenjualanRingkasanBulanan`, hitungannya, dan isian
    data contoh.
- Uji baru:
  - `apps/mobile/test/v2_panen_perbaikan_test.dart` (6 kasus).
  - `apps/mobile/test/v2_penjualan_tanpa_bayar_test.dart` (6 kasus).

## Bukti uji

| Perintah | Hasil |
|---|---|
| `flutter analyze` | `No issues found!` |
| `flutter test --concurrency=1` | **922/922 lulus** (910 sebelumnya + 12 kasus baru) |
| `dart format` | Berkas uji baru diformat; churn formatter pada berkas lain yang tidak terkait dibatalkan |

## Catatan "lihat data panen" lebih lambat

Sebelum perbaikan, urutan yang membuat tab Panen terasa lambat:

1. `PanenViewModel.refresh()` memanggil `listHarvests()` dan `listTransfers()`
   bersamaan, lalu **menunggu keduanya** sebelum menulis state.
2. `listHarvests()` memakai halaman `limit=100` dan setiap baris membawa detail
   bersarang, jadi responsnya lebih berat daripada semaian/meja.
3. `V2PanenConnectedTab` juga menonton `v2AllTransfersProvider`, yang
   memanggil `listTransfers()` lagi — daftar batch yang sama diambil dua kali.
4. Karena state baru diisi setelah keduanya selesai, kerangka penuh bertahan
   sampai permintaan terberat selesai.

Sesudah perbaikan, daftar batch bisa langsung mengisi chip Estimasi, riwayat
mengisi chip Riwayat begitu tiba, dan hanya satu ambilan batch yang berjalan.
Tidak ada perubahan kontrak backend.

## Uji ulang di HP (belum dijalankan)

Lihat baris `MC-FIX-74a`–`MC-FIX-74h` di `qa/manual_checklist.md`. Semua masih
berstatus `FIXED di kode, belum diuji ulang di HP`.