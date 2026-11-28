# QA — Form "Tambah barang": stok awal minimal 1 & stok minimum < stok awal

Tanggal: 28 Nov 2026. Branch: `wild-fe`.
Rencana: `mcdocs/stok-tambah-barang-plan.md`. Task: `mcdocs/stok-tambah-barang-tasks.md`.

Permintaan client: di menu **Stok → Tambah barang**, isian **stok awal** minimal
**1**, dan **stok minimum** tidak boleh sama dengan stok awal (harus **kurang
dari** stok awal).

## Ringkasan hasil

| Aturan | Sebelum | Sesudah | Bukti |
|---|---|---|---|
| Stok awal minimal 1 | `0` diterima | `< 1` ditolak: "Stok awal minimal 1." | Test `stok awal 0 ditolak...`, `stok awal desimal di bawah 1 ditolak` |
| Stok minimum vs stok awal | `==` diterima, `>` ditolak | `>=` ditolak: "Stok minimum harus kurang dari stok awal." | Test `stok minimum sama dengan stok awal ditolak`, `stok minimum harus kurang dari stok awal saat menambah` |
| Terima nilai sah | `1` diterima | `1` diterima | Test `stok awal 1 tanpa stok minimum tersimpan`, `stok minimum di bawah stok awal diterima` |

Perubahan kode (satu file):
`apps/mobile/lib/views/v2/pages/v2_inventaris_form_page.dart`
- `_stokAwalErrorFor`: tambah cabang `angka < 1` → "Stok awal minimal 1."
- `_stokMinErrorFor`: `angka > stokAwal` menjadi `angka >= stokAwal`, pesan
  menjadi "Stok minimum harus kurang dari stok awal."
- Placeholder kolom "Stok awal": `0` menjadi `Contoh: 1`, karena `0` kini
  menyesatkan (bukan nilai yang sah).

Test: `apps/mobile/test/v2_inventaris_form_fixes_test.dart` (pesan lama
diperbarui + 6 test baru).

## Daftar risiko (chatter) & hasil

Diurutkan sesuai dampak (data/uang dulu, lalu alur, lalu teks):

1. Stok awal `0` menghasilkan barang tanpa saldo. **Ditutup** (ditolak).
2. Stok minimum `==` stok awal (batas "menipis" ambigu). **Ditutup** (ditolak).
3. Stok minimum `>` stok awal. **Ditutup** (pesan baru, tetap ditolak).
4. Nilai desimal di bawah 1 (`0,5`). **Ditutup** (ditolak, pesan minimal 1).
5. Nilai sah `1` (batas bawah). **Diuji** (diterima, jumlah tersimpan = 1).
6. Stok minimum `<` stok awal (`4` vs `5`). **Diuji** (diterima, minimum = 4).
7. Stok minimum kosong (opsional). **Diuji** (diterima, minimum = null).
8. Nilai negatif (`-3`). **Tetap** (pesan "Angka tidak boleh negatif" lebih dulu).
9. Bentuk angka salah (`1.234`, `3,555`). **Tetap** (pesan bentuk angka).
10. Stok minimum `<= 0` (`0`). **Tetap** (pesan "Stok minimum harus lebih dari 0.").
11. Mode ubah (tanpa stok awal). **Tetap** (hanya cek `> 0`; relasi tidak berlaku).
12. Pesan sisa "melebihi" di test lama. **Ditutup** (test diperbarui ke aturan baru).

## Bukti yang dijalankan (hasil nyata)

```
$ flutter analyze
No issues found! (ran in 4.4s)

$ flutter test --concurrency=1
... +937: All tests passed!
```

Bukti aturan gagal pada kode lama (O-07): file sumber di-stash, suite dijalankan.
4 test gagal dengan alasan benar, lalu lulus setelah perubahan dikembalikan:

```
$ git stash push -- apps/mobile/lib/views/v2/pages/v2_inventaris_form_page.dart
$ flutter test test/v2_inventaris_form_fixes_test.dart --concurrency=1
Failing tests:
  stok awal 0 ditolak dengan pesan minimal 1            (findsNothing: "Stok awal minimal 1.")
  stok awal desimal di bawah 1 ditolak                  (findsNothing: "Stok awal minimal 1.")
  stok minimum harus kurang dari stok awal saat menambah (findsNothing: pesan baru)
  stok minimum sama dengan stok awal ditolak            (findsNothing: pesan baru; == dulu diterima)
$ git stash pop
```

Test terima (`stok awal 1 ...`, `stok minimum di bawah stok awal diterima`)
lulus di kode lama maupun baru, sesuai harapan (bukan gerbang aturan baru).

## Real run

Form nyata (`V2InventarisFormPage`) dijalankan lewat widget test: isi kolom,
tekan "Simpan", konfirmasi "Tambah", lalu nilai yang tersimpan diperiksa
(`jumlah`, `minimum`). Alur tersambung penuh (tab Stok → `saveItem` → repository)
tidak dijalankan lewat perangkat karena tidak ada emulator/HP di lingkungan ini.

## Delivery Gate (outofthebox, DURING)

Block 1 — Hard Gate:
- [x] Tidak ada check yang menulis ke data dev/produksi (O-01/O-02). PASS: hanya widget test beralur tiruan.
- [x] Tidak ada PASS berdasarkan tebakan (O-03). PASS: setiap hasil dikutip dari perintah/test.
- [x] Tidak ada check yang dilonggarkan agar hijau (O-05). PASS: test lama diperbarui ke aturan baru, bukan dihapus.
- [x] Tidak ada sisa sementara (O-06). PASS: `git stash pop` mengembalikan file; tidak ada file sementara baru.

Block 2 — Must Probe:
- [x] Setiap check baru gagal pada kode lama dengan alasan benar (O-07). PASS: 4 test, kutipan di atas.
- [x] Setiap sumbu atlas ditelusuri atau disebut dilewati (O-08). PASS: 12 kasus di daftar risiko.
- [x] Data lama diperiksa dampaknya (O-09). PASS: tidak relevan, batas hanya pada input baru; tidak ada baris lama yang harus diperbaiki.
- [x] Suite penuh dijalankan dengan angka (O-10). PASS: 937/937 lulus.
- [x] Produk nyata dijalankan minimal sekali (O-11). PASS (parsial): form nyata lewat widget test; perangkat tidak tersedia.
- [x] Lingkungan kirim diuji (O-12). PASS: test berjalan pada mesin & versi Flutter yang sama dengan build.
- [x] Putaran terakhir tidak menemukan kasus baru. PASS: 12 kasus, tidak ada tambahan.

Block 3 — Quality Locks:
- [x] Dampak diurutkan (O-13), check deterministik (O-14), assertion pada nilai penting (O-15), daftar tak-teruji disebut (O-16).

## Yang tidak diuji

- Uji jalan di perangkat/emulator Android (tidak ada perangkat di lingkungan ini); status HP tetap `MANUAL-PENDING`.
- Skenario sinkronisasi offline: payload stok awal/minimum sudah divalidasi sebelum masuk antrean (form menolak lebih dulu), tapi antrean itu sendiri tidak diputar ulang di test ini.
- Perilaku backend: `POST /inventaris` tidak menerima stok awal, jadi relasi tidak berlaku di server; tidak ada endpoint yang diubah.
