# Hasil — Perbaikan alur Tanaman & Tanaman Rusak (sesi 10 lanjutan 3)

Tanggal: 27 November 2026 · Branch: `wild-fe`
Rencana: `mcdocs/tanaman-rusak-perbaikan-plan.md` · Tasks:
`mcdocs/tanaman-rusak-perbaikan-tasks.md`

Perubahan **front-end saja** (`apps/mobile/`). Backend tidak disentuh: kolom
`jenis_kerusakan` sudah berupa teks bebas (maks 100 karakter).

## Ringkasan

| # | Permintaan | Hasil |
|---|---|---|
| 1 | Detail tanaman: hilangkan tombol "Catat rusak" | Footer Detail tanaman kini hanya berisi "Ubah" (catatan tanaman). Pencatatan rusak hanya dari halaman Tanaman rusak. |
| 2 | Laporan baru hilang saat daftar rusak dibuka lagi | Detail tanaman menyimpan salinan daftar per batch. Halaman Tanaman rusak mengabari setiap catat/ubah lewat `onChanged`, jadi subjudul jumlah dan daftar saat dibuka lagi langsung segar. **BUG-73**. |
| 3 | Ketuk tanaman rusak → Detail kerusakan dulu | Halaman baru `V2DetailKerusakanPage`: kartu ringkasan + info (jumlah, tanggal, keterangan) + tombol "Ubah kerusakan". Form ubah 6.28 baru terbuka dari tombol itu. |
| 4 | Kategori "Busuk akar" → "Penyakit" | Chip form tambah/ubah memakai "Penyakit". Data contoh galeri ikut diganti (`designKerusakanPenyakit`). |

## Perubahan berkas

- `apps/mobile/lib/views/v2/pages/v2_detail_tanaman_page.dart`
  - `_rusak` lokal per batch; subjudul "Tanaman rusak" memakai daftar itu.
  - `_bukaRusak` meneruskan `onChanged` yang memperbarui salinan lokal.
  - Hapus `_catatRusak` dan tombol "Catat rusak" dari `V2ActionBar`.
- `apps/mobile/lib/views/v2/pages/v2_tanaman_rusak_page.dart`
  - `onChanged` pada halaman + `route`; `_catat`/`_bukaDetail` memanggilnya.
  - Baris membuka `V2DetailKerusakanPage` (bukan langsung form ubah).
  - Kelas baru `V2DetailKerusakanPage` dengan `PopScope` yang mengembalikan
    laporan terbaru.
  - Chip `_jenis` dan nilai bawaan: "Penyakit".
- `apps/mobile/lib/views/v2/components/v2_meja_data.dart`
  - `designKerusakanBusukAkar` → `designKerusakanPenyakit` (jenis "Penyakit");
    komentar `judul`/jenis disesuaikan.
- `apps/mobile/lib/views/v2/pages/v2_gallery_page.dart`
  - Teks pratinjau 6.24/6.27/6.28 memakai "penyakit".
- Uji baru: `apps/mobile/test/v2_tanaman_rusak_perbaikan_test.dart` (6 kasus).

## Bukti uji

| Perintah | Hasil |
|---|---|
| `flutter analyze` | `No issues found!` |
| `flutter test --concurrency=1` | **910 lulus / 910**, tanpa gagal (904 + 6 baru) |
| `dart format` | Bersih pada berkas yang diubah |

Kasus baru (`test/v2_tanaman_rusak_perbaikan_test.dart`):

1. Detail tanaman tidak lagi punya tombol "Catat rusak"; "Ubah" tetap ada.
2. Baris rusak membuka "Detail kerusakan", bukan form ubah (tidak ada "Simpan").
3. Tombol "Ubah kerusakan" di detail membuka form ubah (ada "Simpan" dan
   "Tanggal kejadian").
4. Ubah dari detail memperbarui baris daftar ("2 tanaman, layu").
5. Chip form memakai "Penyakit", bukan "Busuk akar".
6. Laporan baru tetap tampil saat daftar rusak dibuka lagi dari Detail tanaman
   (BUG-73): tambah 2 tanaman → kembali ke Detail tanaman → buka daftar lagi →
   baris "2 tanaman, penyakit" masih ada dan subjudul menjadi
   "2 tanaman. Lihat daftar".

**Bukti kode lama.** Kasus 6 dijalankan pada worktree bersih di HEAD
`a339c83` (`/tmp/opencode/hs-old`) dengan salinan `.dart_tool`; tes lulus dengan
`findsNothing` setelah daftar dibuka ulang, artinya baris baru memang hilang di
kode lama. Kasus 1–5 gagal di kode lama karena tombol "Catat rusak" masih ada,
baris membuka form ubah langsung, dan chip masih "Busuk akar". Worktree sudah
dihapus setelah verifikasi.

## Uji manual di HP

Belum dilakukan. Langkah uji ada di `qa/manual_checklist.md` (MC-FIX-73a..f),
status `FIXED di kode, belum diuji ulang di HP`.

## Temuan / catatan

- **Tidak ada perubahan backend.** `POST/PATCH /api/v1/kerusakan` menerima
  `jenis_kerusakan` sebagai teks (1–100 karakter), jadi "Penyakit" langsung
  tersimpan tanpa migrasi.
- **Data lama "Busuk akar".** Database remote baru di-refresh dan seeder tidak
  membuat laporan kerusakan, jadi tidak ada baris lama. Bila di kemudian hari
  ada data berjenis "Busuk akar", detail menampilkannya apa adanya dan pemakai
  dapat memilih "Penyakit" saat mengubah.
- **Galeri.** `V2DetailKerusakanPage.biasa()` disediakan untuk pratinjau, tetapi
  baris galeri belum ditambahkan agar nomor frame yang ada tidak bergeser.