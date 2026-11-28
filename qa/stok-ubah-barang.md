# QA — Form "Ubah barang": stok tersedia, stok minimum jenis Obat, batas maksimum

Tanggal: 28 Nov 2026. Branch: `wild-fe`.
Rencana: `mcdocs/stok-ubah-barang-plan.md`. Task: `mcdocs/stok-ubah-barang-tasks.md`.

Permintaan client di menu **Stok → detail barang → Ubah barang**:

1. Tampilkan **jumlah stok tersedia** supaya tahu sisa stok saat mengisi stok
   minimum (hanya tampil, tidak bisa diubah).
2. Jenis barang **Obat**: kolom **stok minimum** belum ada, harus muncul.
3. Kolom **stok minimum** belum punya batas maksimum. Keputusan client: batas
   diterapkan **hanya saat nilai minimum diubah**, dan harus **kurang dari**
   stok tersedia (strict `<`, bukan `<=`).

## Ringkasan hasil

| Aturan | Sebelum | Sesudah | Bukti |
|---|---|---|---|
| Stok tersedia di form Ubah | Tidak ditampilkan (hanya catatan teks) | Kolom `Stok tersedia` non-aktif, mis. `12 pak`, helper "Stok diubah lewat Catat stok." | Test `ubah barang menampilkan stok tersedia hanya-baca` |
| Stok minimum jenis Obat | Kolom disembunyikan (`_showStokMin`) | Kolom muncul untuk semua jenis | Test `ubah barang jenis obat menampilkan kolom stok minimum` |
| Batas maksimum stok minimum (Ubah) | Hanya `> 0`, nilai di atas saldo diterima | Saat minimum diubah, `< stok tersedia`; `>=` ditolak | Test `... sama dengan stok tersedia`, `... melebihi stok tersedia`, `... kurang dari stok tersedia diterima` |
| Item stok rendah | Tetap bisa diubah | Tetap bisa selama minimum tidak diubah | Test `... stok rendah tetap bisa disimpan bila minimum tetap` |

Perubahan kode (satu file):
`apps/mobile/lib/views/v2/pages/v2_inventaris_form_page.dart`
- Tambah controller `_stokTersedia` (`<jumlah> <satuan>`), hanya-baca sesuai
  pola kolom "Satuan" yang terkunci.
- `_buildFields` mode ubah: kolom "Stok tersedia" + helper, catatan teks
  terpisah dihapus; kolom stok minimum tampil untuk **semua** jenis (hapus
  `_showStokMin`).
- `_stokMinErrorFor(text, {stokAwal, batasLabel})`: pesan batas atas memakai
  `batasLabel` (`stok awal` di tambah, `stok tersedia` di ubah).
- `_save` mode ubah: batas atas hanya dikirim bila `minimum != item.minimum`.

Test: `apps/mobile/test/v2_inventaris_form_fixes_test.dart` (6 test baru;
pencarian kolom lewat label, bukan indeks `TextField`).

## Daftar risiko (chatter) & hasil

Diurutkan sesuai dampak (data/uang dulu, lalu alur, lalu teks):

1. Stok minimum di atas saldo membuat "menipis" tak pernah aktif. **Ditutup**
   (ditolak saat minimum diubah).
2. Stok minimum `==` saldo (batas ambigu). **Ditutup** (ditolak).
3. Item stok rendah (stok `2`, minimum `3`) diblokir saat sekadar ganti nama.
   **Ditutup** (batas hanya saat minimum berubah).
4. Stok `0` tak bisa diberi minimum baru. **Disetujui** (strict `<`; catat stok
   masuk dulu). Tidak diuji sebagai kasus terpisah.
5. Pengguna tak tahu saldo saat mengisi minimum. **Ditutup** (kolom stok
   tersedia).
6. Kolom stok minimum jenis Obat hilang. **Ditutup** (selalu tampil).
7. Kolom stok tersedia bisa diubah. **Ditutup** (`enabled: false`, diuji).
8. Mode tambah ikut berubah aturannya. **Tetap** (`< stok awal` dari sesi 11;
   test regresi ada).
9. Stok minimum kosong (opsional). **Tetap** (diterima, minimum `null`).
10. Bentuk angka salah (`3,555`) dan nilai `<= 0`. **Tetap** (pesan lama).
11. Kolom stok minimum mode ubah bergeser indeks. **Ditutup** (test lama dan
    baru memakai pencarian lewat label).
12. Mode ubah menyimpan jumlah/riwayat/arsip. **Tetap** (tidak disentuh).

## Bukti yang dijalankan (hasil nyata)

```
$ flutter analyze
No issues found! (ran in 1.9s / 3.0s)

$ flutter test --concurrency=1
... +943: All tests passed!
```

Bukti aturan gagal pada kode lama (O-07): file sumber di-stash, suite fokus
dijalankan. 8 test gagal dengan alasan benar (4 aturan sesi 11 + 4 aturan sesi
12), lalu lulus setelah perubahan dikembalikan:

```
$ git stash push -- apps/mobile/lib/views/v2/pages/v2_inventaris_form_page.dart
$ flutter test test/v2_inventaris_form_fixes_test.dart --concurrency=1
Failing (sesi 12, alasan benar):
  ubah barang menampilkan stok tersedia hanya-baca            (findsNothing: "Stok tersedia")
  ubah barang jenis obat menampilkan kolom stok minimum       (findsNothing: "Stok minimum (opsional)")
  ubah barang menolak stok minimum sama dengan stok tersedia  (findsNothing: "Stok minimum harus kurang dari stok tersedia.")
  ubah barang menolak stok minimum melebihi stok tersedia     (findsNothing: pesan yang sama)
Failing (sesi 11, regresi terjaga):
  stok awal 0 ditolak dengan pesan minimal 1
  stok awal desimal di bawah 1 ditolak
  stok minimum harus kurang dari stok awal saat menambah
  stok minimum sama dengan stok awal ditolak
$ git stash pop
```

Test terima (`... kurang dari stok tersedia diterima`, `... stok rendah tetap
bisa disimpan`) lulus di kode lama maupun baru, sesuai harapan (bukan gerbang
aturan baru).

## Real run

Form nyata (`V2InventarisFormPage` mode ubah) dijalankan lewat widget test: isi
kolom, tekan "Simpan", konfirmasi dialog "Simpan perubahan barang?", lalu nilai
yang tersimpan diperiksa (`minimum`). Alur tersambung penuh (halaman detail →
`saveItem` → repository) tidak dijalankan lewat perangkat karena tidak ada
emulator/HP di lingkungan ini.

## Delivery Gate (outofthebox, DURING)

Block 1 — Hard Gate:
- [x] Tidak ada check yang menulis ke data dev/produksi (O-01/O-02). PASS: hanya widget test beralur tiruan.
- [x] Tidak ada PASS berdasarkan tebakan (O-03). PASS: setiap hasil dikutip dari perintah/test.
- [x] Tidak ada check yang dilonggarkan agar hijau (O-05). PASS: 2 test lama disesuaikan ke pencarian lewat label, bukan dihapus.
- [x] Tidak ada sisa sementara (O-06). PASS: `git stash pop` mengembalikan file; tidak ada file sementara baru.

Block 2 — Must Probe:
- [x] Setiap check baru gagal pada kode lama dengan alasan benar (O-07). PASS: 4 test sesi 12, kutipan di atas.
- [x] Setiap sumbu atlas ditelusuri atau disebut dilewati (O-08). PASS: 12 kasus di daftar risiko.
- [x] Data lama diperiksa dampaknya (O-09). PASS: tidak relevan, batas hanya pada input baru; item stok rendah tidak diblokir.
- [x] Suite penuh dijalankan dengan angka (O-10). PASS: 943/943 lulus.
- [x] Produk nyata dijalankan minimal sekali (O-11). PASS (parsial): form nyata lewat widget test; perangkat tidak tersedia.
- [x] Lingkungan kirim diuji (O-12). PASS: test berjalan pada mesin & versi Flutter yang sama dengan build.
- [x] Putaran terakhir tidak menemukan kasus baru. PASS: 12 kasus, tidak ada tambahan.

Block 3 — Quality Locks:
- [x] Dampak diurutkan (O-13), check deterministik (O-14), assertion pada nilai penting (O-15), daftar tak-teruji disebut (O-16).

## Yang tidak diuji

- Uji jalan di perangkat/emulator Android (tidak ada perangkat di lingkungan ini); status HP tetap `MANUAL-PENDING`.
- Item dengan stok `0` yang minimumnya diubah (pasti ditolak karena strict `<`); konsisten dengan keputusan, tidak diuji sebagai kasus terpisah.
- Perilaku backend: `PATCH`/`POST` inventaris hanya menerima stok minimum; relasi terhadap saldo tetap ditegakkan di form.
- Skenario sinkronisasi offline: payload sudah divalidasi sebelum masuk antrean, tapi antrean tidak diputar ulang di test ini.
