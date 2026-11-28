# QA — Arsip barang, batas 10000, dan pagination riwayat stok

Tanggal: 28 Nov 2026. Branch: `wild-fe`.
Rencana: `mcdocs/stok-arsip-batas-riwayat-plan.md`.
Task: `mcdocs/stok-arsip-batas-riwayat-tasks.md`.
Lingkungan: Flutter 3.47.7 stable, Dart 3.13.5.

Permintaan client saat uji manual:

1. Menu **Stok → detail barang → Arsipkan**: setelah proses selesai tidak ada
   notifikasi/pop-up bahwa arsip berhasil. Perlu pesan sukses; jalur gagal juga
   harus dipastikan memberi pesan.
2. Menu **Stok → tambah barang**: isian **stok awal** dibatasi maksimal **10000**.
3. **Detail barang → catat stok masuk**: dibatasi maksimal **10000** sekali input.
4. **Riwayat stok** di detail barang: dipaginasi **3 entri per halaman**.

## Ringkasan hasil

| Aturan | Sebelum | Sesudah | Bukti |
|---|---|---|---|
| Notif arsip sukses (alur tersambung) | Halaman detail menutup tanpa pesan | SnackBar `'<nama> diarsipkan.'` di daftar | Test `arsip berhasil memberi SnackBar "Benih Uji diarsipkan."` |
| Arsip gagal | Sudah ada: SnackBar `serviceError`, halaman tetap terbuka | Tidak diubah, ditambah test regresi | Test `arsip gagal: halaman tetap terbuka dan pesan galat tampil` |
| Stok awal (tambah barang) | Tanpa batas atas | `> 10000` ditolak, pesan `Stok awal maksimal 10000.` | Test `stok awal 10001 ditolak ...`, `stok awal 10000 diterima` |
| Catat stok masuk | Dibatasi saldo backend (sampai 9999999987) | Maksimal 10000 sekali input, tetap menghormati sisa saldo | Test `catat stok Masuk menolak jumlah di atas 10000 di dalam sheet`, `... menerima tepat 10000 sekali input` |
| Riwayat stok | Dipotong tetap 3 entri, sisanya tak bisa dilihat | Paginasi 3/halaman, kontrol sebelum/berikutnya + `1/2` | Test `riwayat 5 entri dipaginasi 3 per halaman`, `riwayat 3 entri tidak menampilkan kontrol halaman` |

Perubahan kode (lima file):

- `apps/mobile/lib/views/v2/connected/v2_inventaris_connected.dart`
  - `_bukaDetail`: tambah cabang `!item.arsip && hasil.arsip` →
    `_pesan(context, '${item.nama} diarsipkan.')`. Cabang pemulihan arsip tetap.
- `apps/mobile/lib/views/v2/pages/v2_inventaris_form_page.dart`
  - `_stokAwalErrorFor`: konstanta `_stokAwalMaks = 10000`; nilai di atas batas
    ditolak dengan `Stok awal maksimal 10000.`. Urutan cek: negatif → batas
    bawah → batas atas → bentuk angka.
- `apps/mobile/lib/views/v2/components/v2_inventaris_catat_sheet.dart`
  - Konstanta `_batasMasuk = 10000`; `_maksMasuk = min(sisaSaldo, 10000)`.
- `apps/mobile/lib/views/v2/pages/v2_inventaris_detail_page.dart`
  - State `_riwayatPage` + `_riwayatPerHalaman = 3`; `_riwayat()` menampilkan
    potongan halaman aktif dan kontrol sebelum/berikutnya bila > 1 halaman.
    Halaman direset hanya saat `id` barang berganti.
  - Widget privat `_RiwayatPagerButton` (tombol bulat 44px, `Semantics`
    berlabel `Riwayat sebelumnya`/`Riwayat berikutnya`).
- `apps/mobile/lib/views/v2/components/v2_inventaris_data.dart`
  - Hapus `riwayatTampil` (pemotongan tetap) karena diganti paginasi.

Test: `apps/mobile/test/v2_inventaris_arsip_notif_test.dart` (2 test baru),
`apps/mobile/test/v2_inventaris_riwayat_pagination_test.dart` (2 test baru), dan
tambahan test di `v2_inventaris_form_fixes_test.dart` (2) serta
`v2_stok_semaian_perbaikan_test.dart` (2).

## Daftar risiko (chatter) & hasil

Diurutkan sesuai dampak (data/uang dulu, lalu alur, lalu teks):

1. Arsip baru tidak memberi kepastian ke pengguna. **Ditutup** (SnackBar setelah
   daftar kembali).
2. Arsip gagal menutup halaman seolah berhasil. **Ditutup** (sudah benar; kini
   dikunci test: halaman tetap terbuka, pesan galat tampil).
3. Catat stok masuk bisa sampai miliaran sehingga salah input merusak saldo.
   **Ditutup** (batas 10000 sekali input).
4. Batas 10000 menimpa batas saldo backend saat saldo mendekati maksimum.
   **Ditutup** (`min(sisaSaldo, 10000)`; saldo tetap tak melewati batas).
5. Stok awal bisa diisi 10001+ lewat ketik bebas. **Ditutup** (`> 10000`
   ditolak).
6. Riwayat ke-4 dan seterusnya tak pernah bisa dilihat. **Ditutup** (paginasi).
7. Kontrol halaman muncul saat riwayat hanya 1 halaman (chatter visual).
   **Ditutup** (kontrol hanya bila `total > 1`).
8. Tombol panah terlalu kecil / tak terbaca pembaca layar. **Ditutup** (44px,
   `Semantics` berlabel).
9. Halaman riwayat terlempar saat riwayat menyegar (mis. setelah catat stok).
   **Ditutup** (reset hanya saat `id` barang berganti).
10. Test lama `Maksimal 9999999987 pak` jadi salah. **Ditutup** (diubah ke
    `Maksimal 10000 pak`, bukan dilonggarkan).
11. Notif arsip dobel dengan toast halaman galeri. **Tetap** (hanya alur
    tersambung diubah; galeri punya `_openDetail` sendiri).
12. Mode `Pakai` ikut berubah. **Tetap** (tetap dibatasi stok yang ada).
13. Data lama di luar batas rusak. **Tidak berlaku** (batas hanya pada input
    baru; saldo hasil catat lama tetap sah).

## Bukti yang dijalankan (hasil nyata)

```
$ flutter analyze
No issues found! (ran in 2.0s)

$ flutter test --concurrency=1
... +953: All tests passed!
```

Bukti aturan gagal pada kode lama (O-07): lima file sumber di-stash, suite fokus
dijalankan. 4 test gagal dengan alasan benar (satu per aturan baru), lalu lulus
setelah perubahan dikembalikan:

```
$ git stash push -- <5 file lib>
$ flutter test \
    test/v2_inventaris_arsip_notif_test.dart \
    test/v2_inventaris_riwayat_pagination_test.dart \
    test/v2_inventaris_form_fixes_test.dart \
    test/v2_stok_semaian_perbaikan_test.dart --concurrency=1
Failing (alasan benar):
  arsip berhasil memberi SnackBar "Benih Uji diarsipkan."   (findsNothing: "Benih Uji diarsipkan.")
  riwayat 5 entri dipaginasi 3 per halaman                  (findsNothing: "1/2")
  stok awal 10001 ditolak dengan pesan maksimal 10000        (findsNothing: "Stok awal maksimal 10000.")
  catat stok Masuk menolak jumlah di atas 10000 di dalam sheet (findsNothing: "Maksimal 10000 pak")
$ git stash pop
```

Test terima/lulus-di-keduanya (`arsip gagal ...`, `riwayat 3 entri ...`,
`stok awal 10000 diterima`, `Masuk menerima tepat 10000`) lulus di kode lama
maupun baru, sesuai harapan (bukan gerbang aturan baru).

## Real run

Alur arsip nyata dijalankan lewat widget test beralur tiruan: tab Stok
tersambung (`V2InventarisConnectedTab`) membuka detail barang, menekan
"Arsipkan", mengonfirmasi dialog, lalu diperiksa SnackBar dan posisi halaman.
Cache inventaris memakai basis data di memori sehingga penyegaran daftar pasca
arsip benar-benar tuntas. Paginasi riwayat dijalankan di `V2InventarisDetailPage`
nyata (ketuk panah berikutnya/sebelumnya, periksa entri per halaman). Alur penuh
di perangkat Android tidak dijalankan karena tidak ada emulator/HP di lingkungan
ini.

## Delivery Gate (outofthebox, DURING)

Block 1 — Hard Gate:
- [x] Tidak ada check yang menulis ke data dev/produksi (O-01/O-02). PASS: hanya widget test beralur tiruan + DB memori.
- [x] Tidak ada PASS berdasarkan tebakan (O-03). PASS: setiap hasil dikutip dari perintah/test.
- [x] Tidak ada check yang dilonggarkan agar hijau (O-05). PASS: test lama diperbarui ke batas baru, bukan dihapus.
- [x] Tidak ada sisa sementara (O-06). PASS: `git stash pop` mengembalikan file; tidak ada file sementara baru.

Block 2 — Must Probe:
- [x] Setiap check baru gagal pada kode lama dengan alasan benar (O-07). PASS: 4 test, kutipan di atas.
- [x] Setiap sumbu atlas ditelusuri atau disebut dilewati (O-08). PASS: 13 kasus di daftar risiko.
- [x] Data lama diperiksa dampaknya (O-09). PASS: batas hanya pada input baru; saldo lama tetap sah; halaman riwayat tidak terlempar saat menyegar.
- [x] Suite penuh dijalankan dengan angka (O-10). PASS: 953/953 lulus.
- [x] Produk nyata dijalankan minimal sekali (O-11). PASS (parsial): alur tersambung + paginasi nyata lewat widget test; perangkat tidak tersedia.
- [x] Lingkungan kirim diuji (O-12). PASS: test berjalan pada mesin & versi Flutter yang sama dengan build.
- [x] Putaran terakhir tidak menemukan kasus baru. PASS: 13 kasus, tidak ada tambahan.

Block 3 — Quality Locks:
- [x] Dampak diurutkan (O-13), check deterministik (O-14), assertion pada nilai penting (O-15), daftar tak-teruji disebut (O-16).

## Yang tidak diuji

- Uji jalan di perangkat/emulator Android (tidak ada perangkat di lingkungan ini); status HP tetap `MANUAL-PENDING`.
- Saldo yang benar-benar mendekati batas backend sekaligus lebih kecil dari 10000 (cabang `sisaSaldo < 10000` pada `_maksMasuk` tidak diuji terpisah; logika lulus analisis dan tetap memakai rumus lama).
- Perilaku backend saat deactivate mengembalikan galat jaringan (timeout) — diuji lewat galat HTTP 500; jalur `ApiException` lain mengikuti `serviceError` yang sama.
- Riwayat yang lebih dari 20 entri: server hanya mengirim 20 terbaru (`fetchLatestStockHistory`), jadi paginasi klien bekerja pada himpunan itu.
