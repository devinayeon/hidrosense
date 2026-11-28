# Hasil — Default meja pindah & loading "Tanaman di meja" (sesi 11)

Tanggal: 28 November 2026 · Branch: `wild-fe`
Rencana: `mcdocs/semaian-meja-default-loading-plan.md` · Tasks: `mcdocs/semaian-meja-default-loading-tasks.md`

## Ringkasan

| # | Permintaan | Hasil |
|---|---|---|
| 1 | Penyemaian → Detail semaian → Pindahkan semaian: bawaan selalu **M-02**, padahal daftar sudah diurutkan lubang kosong | Bawaan sekarang **meja paling atas hasil urutan D-27**, yaitu meja tersedia dengan lubang kosong terbanyak. Pilihan eksplisit (mis. "Tambah tanaman" dari Detail meja) tetap menunjuk meja yang benar. |
| 2 | Meja → Lihat detail meja: "Tanaman di meja" menulis "Belum ada tanaman di meja ini." selagi memuat, padahal meja terisi | Kartu menampilkan **kerangka pemuatan** (`V2Skeleton`) saat data pemindahan/penyemaian belum pernah termuat, lalu berganti daftar tanaman setelah data tiba. |

## Akar masalah

1. **Default M-02.** `V2PindahMejaFormPage.mejaAwal` bawaan `0` dipakai sebagai
   indeks daftar **mentah** (`sumber[0]`) lalu dicari ulang di daftar tersortir.
   Jadi yang terpilih adalah meja pertama data backend (M-02), bukan meja paling
   atas hasil urutan. Alur nyata (`v2_semaian_connected.dart::_pindah`) tidak
   mengisi `mejaAwal`, sehingga selalu jatuh ke `sumber[0]`.
2. **Tidak ada loading.** `_V2MejaConnectedDetailPageState.build` membaca
   `v2AllTransfersProvider`/`v2AllSowingsProvider` lewat `valueOrNull ?? const []`.
   Selagi memuat, daftarnya kosong sehingga kartu menganggap meja benar-benar
   kosong.

## Perubahan berkas

- `apps/mobile/lib/views/v2/pages/v2_pindah_meja_page.dart`
  - `mejaAwal` menjadi `int?` (bawaan `null`). `null` = pilih indeks 0 setelah
    `urutkanMejaPindah`; nilai eksplisit tetap dipetakan lewat `tableId`/`nama`.
  - Fallback BUG-29 tetap: pilihan yang tidak tersedia diganti meja tersedia
    pertama.
- `apps/mobile/lib/views/v2/connected/v2_meja_connected.dart`
  - `_tambahTanaman`: `index < 0 ? null : index` (bukan memaksa indeks 0).
  - `build`: menghitung `memuatTanaman` dari provider pemindahan/penyemaian
    (`isLoading && !hasValue`) dan meneruskannya ke Detail meja.
- `apps/mobile/lib/views/v2/pages/v2_meja_detail_page.dart`
  - Parameter `loading` (bawaan `false`) diteruskan ke kartu tanaman.
- `apps/mobile/lib/views/v2/components/v2_meja_detail_cards.dart`
  - `V2MejaTanamanCard` menerima `loading`; saat loading menampilkan
    `_TanamanSkeleton` (dua baris, bentuk mengikuti `V2ListItem`) dengan label
    semantik "Memuat tanaman di meja", bukan pesan kosong.
- Uji baru: `apps/mobile/test/v2_pindah_default_meja_loading_test.dart`.

## Bukti uji

| Perintah | Hasil |
|---|---|
| `flutter analyze` | `No issues found!` |
| `flutter test --concurrency=1` | **967 lulus / 967**, tanpa gagal |
| `graphify update .` | 9297 node, 16148 edge, 322 komunitas |

Kasus baru (`test/v2_pindah_default_meja_loading_test.dart`):

1. **Bawaan pindah memilih meja paling atas hasil urutan.** Daftar mentah
   sengaja menaruh `M-02` (100 lubang kosong) lebih dulu dan `M-01` (300) di
   belakang. Hasil: urutan tampil `M-01, M-02` dan yang terpilih `M-01`.
   Di kode lama yang terpilih `M-02` karena `mejaAwal` 0 menunjuk entri pertama
   mentah.
2. **Kerangka loading pada kartu tanaman.** `v2AllTransfersProvider` ditahan
   dengan `Completer`; meja sudah termuat (`Terisi 40`). Hasil: `V2Skeleton`
   tampil dan teks "Belum ada tanaman di meja ini." **tidak** tampil. Setelah
   data pemindahan dikirim, kerangka hilang dan baris tanaman muncul.
   Di kode lama, teks kosong itulah yang tampil selama memuat.

Uji lama yang menyentuh kedua alur tetap lulus:
`v2_pindah_urut_meja_fitur2_test.dart` (pilihan eksplisit tetap Meja C1),
`v2_pindah_meja_jumlah_test.dart` (bawaan bukan meja penuh),
`v2_tambah_tanaman_bug35_test.dart`, `v2_tanaman_hari_ini_bug36_test.dart`,
`v2_meja_pintu_bersama_bug39_test.dart`, `v2_text_scale_bug24_test.dart`.

## Uji manual di HP

Belum dilakukan. Langkah uji ada di `qa/manual_checklist.md` (MC-FIX-77a..b),
status `FIXED di kode, belum diuji ulang di HP`.

## Catatan

- **Pilihan konteks tetap dihormati.** Alur "Tambah tanaman" dari Detail meja
  (D-25) memang harus membuka form dengan meja itu terpilih, jadi ia mengirim
  indeks eksplisit. Perubahan hanya menyentuh bawaan saat tidak ada pilihan.
- **Data rusak:** tidak ada. Perubahan ini murni tampilan/bawaan pilihan; tidak
  ada data tersimpan yang perlu diperbaiki (O-09).
- **Kerangka beranimasi.** `V2Skeleton` memakai pulse berulang, sama seperti
  kerangka daftar lain di aplikasi. Ini pola proyek yang sudah ada; bila ingin
  mematikan animasi saat `prefers-reduced-motion`, itu perubahan lintas halaman
  terpisah.