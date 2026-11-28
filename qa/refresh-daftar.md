# QA — Refresh daftar data dari backend

Tanggal: 28 November 2026. Branch: `wild-fe`.
Rencana: `mcdocs/refresh-daftar-plan.md`. Task: `mcdocs/refresh-daftar-tasks.md`.

## Yang diuji

Setiap menu yang mengambil daftar dari backend bisa dimuat ulang lewat
**tarik-turun** dan **tombol "Muat ulang"**:

| Menu | Interaksi | Sumber refresh |
|---|---|---|
| Beranda (dashboard) | tarik-turun + tombol header | nursery, inventaris, tabel, cuaca, profil (sesuai izin) |
| Lainnya/Profil | tarik-turun + tombol header | callback yang sama dengan Beranda |
| Tanam → Semaian | tarik-turun + tombol header | nursery + inventaris |
| Tanam → Meja | tarik-turun + tombol header | tabel + transfer + sowings + inventaris |
| Tanam → Panen | tarik-turun + tombol header | panen + tabel + inventaris |
| Stok | tarik-turun + tombol header | inventaris + kategori/obat |
| Rawat | tarik-turun + tombol header | damage per meja + tabel + pindai |
| Notifikasi | tarik-turun + tombol AppBar | nursery + inventaris, lalu grup baru |
| Penjualan | tarik-turun + tombol AppBar | `_load()` store |
| Akun pegawai | tarik-turun + tombol AppBar | `_load()` store |
| Sinkron | tarik-turun + tombol AppBar | jam sinkron + `queue.load()` |
| Cuaca | tarik-turun + tombol AppBar | `fetchWeatherData()` |

Halaman detail (riwayat stok, detail meja/panen/semaian/rawat/pegawai) tetap
seperti semula, sesuai keputusan cakupan.

## Perubahan kode

- `views/v2/widgets/v2_icon.dart`: ikon `refresh`.
- `views/v2/widgets/v2_refresh_button.dart` (baru): tombol 48x48, spinner saat
  sibuk, menolak ketukan ganda, semantics "Muat ulang".
- `views/v2/widgets/v2_app_bar.dart`: `trailing` bisa berisi lebih dari satu
  aksi; judul tetap center lewat `Stack` + padding simetris 48px.
- Tiap `*TabView` dan halaman turunan menerima `onRefresh`; `RefreshIndicator`
  dan tombol hanya muncul bila callback diisi, jadi galeri tidak berubah.
- Physics daftar menjadi `AlwaysScrollableScrollPhysics` supaya gestur tetap
  jalan pada daftar pendek.
- Halaman penghubung `connected/*` dan `v2_beranda_connected_page.dart`
  mengisi callback dengan provider nyata.

## Verifikasi

```
cd apps/mobile
flutter analyze
flutter test test/v2_refresh_daftar_test.dart --concurrency=1
flutter test --concurrency=1
```

Hasil:

- `flutter analyze`: **No issues found!**
- `test/v2_refresh_daftar_test.dart`: **9 lulus**.
- Suite penuh: **962 lulus**, 0 gagal.

## Bukti regresi (O-07)

Test baru dijalankan pada kode lama dengan `git stash push -- apps/mobile/lib`.
Hasil: gagal saat kompilasi karena `onRefresh` belum ada di tiap halaman dan
`V2IconName.refresh` belum ada. Setelah perubahan dipulihkan, seluruh test lulus.
Artinya test benar-benar menjaga fitur baru, bukan lulus karena kebetulan.

## Kasus yang dicakup test

1. Tarik-turun memanggil `onRefresh` tepat sekali pada kelima `*TabView`
   (Stok, Semaian, Meja, Panen, Rawat).
2. Tanpa `onRefresh`, tidak ada `RefreshIndicator` maupun ikon refresh.
3. Tombol di header memakai jalur refresh yang sama dengan gestur.
4. Tombol sibuk menampilkan spinner dan ketukan kedua tidak memicu permintaan
   baru.
5. Tombol refresh Penjualan memuat ulang store (`load` dipanggil lagi).
6. Tombol refresh Akun pegawai memuat ulang store.
7. Tarik-turun Notifikasi mengganti grup lama dengan grup terbaru.
8. Tarik-turun Cuaca memanggil sumber muat ulang BMKG.
9. Tarik-turun Sinkron memanggil sumber muat ulang.

## Catatan risiko yang tersisa

- Refresh saat offline memakai penanganan galat yang sudah ada; daftar lama
  tidak dikosongkan.
- Tombol sibuk hanya mencegah ketukan ganda pada tombol; gestur tarik-turun
  mengikuti `RefreshIndicator` yang juga menahan sampai callback selesai.
- Perubahan `V2AppBar` teruji lewat suite penuh, termasuk test overflow responsif
  dan widget bersama.