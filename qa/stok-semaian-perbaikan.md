# Hasil — Perbaikan alur Catat stok & Tambah semaian (sesi 10 lanjutan)

Tanggal: 27 November 2026 · Branch: `wild-fe`
Rencana: `mcdocs/stok-semaian-perbaikan-plan.md` · Tasks: `mcdocs/stok-semaian-perbaikan-tasks.md`

Lanjutan dari `qa/inventaris-perbaikan.md`. Semua perubahan di sisi mobile.

## Ringkasan

| # | Permintaan | Hasil |
|---|---|---|
| 1 | Stok (Masuk) punya batas maksimum | Batas = sisa sampai `stok_saldo` backend; pesan `Maksimal N <satuan>` muncul di sheet; tombol plus berhenti di batas. |
| 2 | Angka bawaan tambah stok = 1 | Sheet terbuka dengan jumlah 1 untuk `Pakai` dan `Masuk`, termasuk alur tersambung. |
| 3 | Peringatan di form, bukan di detail | Kasus batas dicegah di dalam sheet; `Simpan` tidak menutup sheet saat galat. |
| 4 | Pesan jumlah benih = "Benih harus angka positif" | Kosong, bukan angka, dan ≤ 0 memakai pesan itu; > 250 tetap "Maksimal 250 benih". |
| 5 | Info stok minus → "Stok tidak mencukupi" | Kartu "Stok berkurang" selalu tampil saat ada bahan; sisa minus jadi "Stok tidak mencukupi" (merah), bukan angka negatif. |
| 6 | Bawaan jumlah benih & bahan = 1 | Benih 1, tiap baris bahan 1; baris baru dan penggantian bahan juga reset ke 1. |

## Perubahan berkas

- `apps/mobile/lib/views/v2/components/v2_inventaris_catat_sheet.dart`
  - `jumlah` bawaan 1 (fungsi pembuka dan widget).
  - `_batasSaldo = 9999999999`, `_maksMasuk`, `_galatStok`, `_galatMaks`.
  - Plus berhenti di `_maksMasuk`; pesan galat menyesuaikan penyebab.
- `apps/mobile/lib/views/v2/pages/v2_inventaris_detail_page.dart` — kirim `jumlah: 1`.
- `apps/mobile/lib/views/v2/connected/v2_inventaris_connected.dart` — kirim `jumlah: 1`.
- `apps/mobile/lib/core/validators.dart` — `jumlahBenihProblem` memakai "Benih harus angka positif".
- `apps/mobile/lib/views/v2/pages/v2_semaian_form_page.dart` — bawaan 1/1, kartu tint selalu tampil, baris minus merah.
- Uji: `test/v2_stok_semaian_perbaikan_test.dart` (baru, 7 kasus),
  `test/v2_validators_sesi7_test.dart`, `test/v2_semaian_bahan_bug38_test.dart`.

## Bukti uji

| Perintah | Hasil |
|---|---|
| `flutter analyze` | `No issues found!` |
| `flutter test --concurrency=1` | **899 lulus / 899**, tanpa gagal |
| `dart format --set-exit-if-changed` | Bersih pada berkas yang diubah |

Kasus baru yang diuji (`test/v2_stok_semaian_perbaikan_test.dart`):

1. Jumlah bawaan catat stok = 1 untuk `Pakai` dan `Masuk`.
2. `Masuk` dengan `9999999998` menampilkan `Maksimal 9999999987 pak`, plus nonaktif, sheet tetap terbuka.
3. `Pakai` melebihi stok tetap `Stok hanya 12 pak`, sheet tetap terbuka.
4. Jumlah benih dan jumlah bahan bawaan = 1.
5. Jumlah benih kosong → "Benih harus angka positif".
6. Info stok cukup: "Benih Romaine: 12 pak jadi 11 pak".
7. Hasil minus: "Benih Romaine: Stok tidak mencukupi" + "Stok hanya 12 pak".

Semua kasus di atas **gagal pada kode lama** (bawaan 2, tidak ada batas `Masuk`,
pesan "Isi jumlah benih"/"Jumlah benih harus angka", kartu tint disembunyikan saat
minus) dan lulus setelah perbaikan.

## Uji manual di HP

Belum dilakukan. Checklist langkah ada di `qa/manual_checklist.md`
(MC-FIX-71a..e), status `FIXED di kode, belum diuji ulang di HP`.

## Catatan

- Batas `9999999999` mengikuti `stok_saldo.saldo_minor <= 999999999999`
  (9999999999.99). Sheet memakai bilangan bulat, jadi batas masuk =
  `9999999999 - stok`.
- Perilaku `Pakai` yang melebihi stok tidak diubah (tetap pesan di dalam sheet).
- Frame galeri 4.21/5.7 yang dulu memakai contoh 2 kini memakai 1; perubahan
  disengaja sesuai permintaan client.
