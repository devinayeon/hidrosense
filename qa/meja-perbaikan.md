# Hasil — Perbaikan alur Meja (sesi 10 lanjutan 2)

Tanggal: 27 November 2026 · Branch: `wild-fe`
Rencana: `mcdocs/meja-perbaikan-plan.md` · Tasks: `mcdocs/meja-perbaikan-tasks.md`

## Ringkasan

| # | Permintaan | Hasil |
|---|---|---|
| 1 | Tambah meja: kode meja tidak boleh di-input manual | Field "Kode meja" `enabled: false`, diisi sistem (`v2KodeMejaBerikutnya`, fallback `A1`), helper "Kode dibuat otomatis". |
| 2 | Tambah meja: placeholder lubang "maksimal 1.000" → 250 | Hint jadi `Contoh: 240 (maksimal 250)`, sesuai validator `jumlahLubangProblem`. |
| 3 | Ubah meja: kode meja tidak boleh di-input manual | Field yang sama `enabled: false`, menampilkan kode meja yang ada. |
| 4 | Detail meja status Perawatan: hilangkan tombol "Tambah tanaman" | Footer Perawatan hanya catatan "Meja Perawatan tidak menerima tanaman baru.", tanpa tombol. |

## Perubahan berkas

- `apps/mobile/lib/views/v2/pages/v2_meja_form_page.dart`
  - Field "Kode meja" `enabled: false` + helper "Kode dibuat otomatis".
  - `initState`: kode selalu diisi sistem, fallback `A1` saat belum ada meja berpola.
  - Hint jumlah lubang `Contoh: 240 (maksimal 250)`.
- `apps/mobile/lib/views/v2/pages/v2_meja_detail_page.dart`
  - `_footer`: status `perawatan` mengembalikan bar aksi tanpa tombol.
- Uji: `test/v2_meja_perbaikan_test.dart` (baru, 6 kasus),
  `test/v2_meja_form_test.dart`, `test/v2_meja_d35_test.dart`,
  `test/v2_confirm_loading_sesi9_test.dart`.

## Bukti uji

| Perintah | Hasil |
|---|---|
| `flutter analyze` | `No issues found!` |
| `flutter test --concurrency=1` | **904 lulus / 904**, tanpa gagal |
| `dart format --set-exit-if-changed` | Bersih pada berkas yang diubah |

Kasus baru (`test/v2_meja_perbaikan_test.dart`):

1. Tambah meja: field kode `enabled == false`, terisi lanjutan `A3` dari `{A2}`, helper tampil.
2. Tambah meja: kode `A1` saat belum ada meja.
3. Tambah meja: hint menulis "maksimal 250", bukan "maksimal 1.000".
4. Ubah meja: field kode `enabled == false`, menampilkan `A2`.
5. Detail meja Perawatan: `Tambah tanaman` tidak ada, catatan ada.
6. Detail meja Tersedia: `Tambah tanaman` ada.

Semua kasus di atas **gagal pada kode lama** (kode bisa diketik, hint "maksimal
1.000", footer Perawatan menampilkan tombol mati) dan lulus setelah perbaikan.

Uji lama yang diperbarui agar tidak lagi mengetik kode: `v2_meja_form_test.dart`
(kasus "kode > 30 karakter" dan "kode sudah dipakai" dihapus karena tidak bisa
dipicu pemakai; diganti kasus kode otomatis), `v2_meja_d35_test.dart`, dan
`v2_confirm_loading_sesi9_test.dart`.

## Uji manual di HP

Belum dilakukan. Langkah uji ada di `qa/manual_checklist.md` (MC-FIX-72a..d),
status `FIXED di kode, belum diuji ulang di HP`.

## Temuan / catatan

- **Ketidaksesuaian batas backend.** `apps/backend/src/features/tables/contracts.ts`
  mengizinkan `jumlah_lubang` sampai **1000**, sedangkan mobile membatasi **250**
  (`jumlahLubangProblem`: "Maksimal 250 lubang"). Perubahan kali ini hanya
  menyelaraskan teks placeholder dengan batas mobile. Bila ingin backend juga
  memakai 250, itu perubahan backend terpisah dan menunggu izin client.
- **Kode duplikat.** Generator kode menghindari kode yang ada di `takenCodes`.
  Bila daftar meja di HP basi, server tetap penentu akhir; galatnya tampil
  sebagai pesan dan form tidak menutup. Karena field tidak bisa diketik,
  perbaikan hanya mungkin dengan memuat ulang data.
- **Frame galeri 6.6/6.7.** Field kode kini tampil abu-abu (disabled) walau
  masih menampilkan pesan validasi pada frame 6.7. Perubahan disengaja.
