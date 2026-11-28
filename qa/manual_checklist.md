# qa/manual_checklist.md — Uji manual (perangkat fisik / mitra)

Uji yang **tidak dapat** dijalankan otomatis di lingkungan ini (tanpa emulator/perangkat
Android, tanpa kamera fisik, tanpa mitra) ditandai **`MANUAL-PENDING`**. Ini bukan klaim
lulus — ini daftar yang harus dikerjakan manusia sebelum presentasi.

Konteks lingkungan (nyata): `adb devices` → tidak ada perangkat; `flutter test` hanya
menjalankan widget/unit tes tanpa Android.

> Diperbarui 24 Nov 2026: **dev FE menguji di HP asli** (24 Nov 2026). Butir yang lulus
> ditulis `PASS` dengan catatan "diuji manual dev FE"; butir yang tidak berlaku karena
> keputusan online-only ditulis `N/A` (lihat `decisions.md` D-14); temuan baru dirujuk ke
> nomor BUG di `issues.md`. Sisa `MANUAL-PENDING` belum dijalankan. Fitur deteksi hama
> (kamera) kini ada, sehingga uji izin kamera tidak lagi `N/A`.
>
> Sesi 4 (24 Nov 2026): perbaikan BUG-33..BUG-38 dan Fitur-1..3 ditambahkan di §H dengan
> status **`FIXED di kode, belum diuji ulang di HP`** — verifikasi visual di HP masih tugas
> dev FE dan **belum diklaim PASS**.
>
> Sesi 5 (25 Nov 2026): temuan lanjutan dari uji manual dev FE (BUG-39..47, Fitur-4)
> diperbaiki di `apps/mobile` dan ditambahkan di §H bagian bawah dengan status
> **`FIXED di kode, belum diuji ulang di HP`**. **Tidak** ada baris baru yang ditulis `PASS`;
> verifikasi ulang di HP akan diisi dev FE.
>
> Sesi 6 (25 Nov 2026): 30 temuan uji manual pelapor (K-01..K-30) ditriase (D-33); 8 di
> antaranya BUG-FE (BUG-48..55) dan ditambahkan di §H (MC-FIX-48..55) dengan status
> **`FIXED di kode, belum diuji ulang di HP`**. Sisanya NOT-A-BUG / DATA-PRASYARAT /
> PERLU-KEPUTUSAN / PERLU-KLARIFIKASI (lihat `qa-sesi6-tasks.md` & `issues.md`).
> **Tidak** ada baris baru yang ditulis `PASS`.
>
> Lanjutan Sesi 6 (26 Nov 2026): keputusan PM D-34/D-35/D-36/D-39 dikerjakan
> (BUG-56..59) dan ditambahkan di §H (MC-FIX-56..59) dengan status
> **`FIXED di kode, belum diuji ulang di HP`**. Catatan penting: D-34 password 6–12
> hanya berlaku di klien; server masih menuntut minimal 12 (BUG-56/G-22, butuh backend).
> **Tidak** ada baris baru yang ditulis `PASS`.

---

## A. Perangkat & OS (§5.4)

| ID | Skenario | Langkah | Ekspektasi | Status |
|---|---|---|---|---|
| MC-DEV-01 | Android 8.0 (API 26) batas bawah | Pasang APK di emulator API 26 | App jalan, semua layar benar | `PASS` (diuji manual dev FE) |
| MC-DEV-02 | Android terbaru | Pasang APK di API terbaru | App jalan tanpa anomali | `PASS` (diuji manual dev FE) |
| MC-DEV-03 | Rotasi layar | Putar layar di tiap layar utama | Layout menyesuaikan, form tak reset | `PASS` (diuji manual dev FE) |
| MC-DEV-04 | Font sistem besar | Set 200% font | Teks tak terpotong, tombol ≥ 48dp | `PASS` (diuji manual dev FE) — layout dibuat fleksibel; 24 uji widget skala 2.0; temuan sisa dicatat BUG-31 |
| MC-DEV-05 | Layar 360x640 & tablet | Jalankan di layar kecil & besar | Tak rusak/overflow | `PASS` (diuji manual dev FE) — diuji lewat simulasi lebar kecil di HP, bukan perangkat 360x640 asli |
| MC-DEV-06 | Mode gelap/terang | Ganti tema sistem | Kontras cukup, teks terbaca | `GAP (D-16)` — aplikasi hanya satu tema; bukan bug |
| MC-DEV-07 | Background/foreground | Buka form, isi sebagian, tekan Home, buka app lain, lalu kembali ke app | Isi form masih ada, tak crash | `PASS` (diuji manual dev FE, 25 Nov 2026) — isian form bertahan saat app di-background, tak crash |
| MC-DEV-08 | Kill paksa | Catat satu data (mis. panen), force-stop app, lalu buka lagi | Data yang sudah tersimpan tetap ada setelah dibuka ulang | `PASS` (diuji manual dev FE, 25 Nov 2026) — data tersimpan bertahan setelah force-stop |
| MC-DEV-09 | Memori rendah & penyimpanan penuh | Trigger low-memory; isi penyimpanan | Tak crash; pesan jelas saat gagal simpan | `MANUAL-PENDING` |
| MC-DEV-10 | Jam/zona waktu diubah | Set jam mundur/maju, ganti TZ | HSS/tanggal tetap WIB; sync tak rusak | `PASS` (diuji manual dev FE) |
| MC-DEV-11 | Build release | `flutter build apk --release` lalu pasang | Tak ada banner debug; TFLite/aset utuh; ukuran wajar | `PASS` (diuji manual dev FE) |
| MC-DEV-12 | Lokasi Ambulu (WIB) | Jalankan di perangkat TZ WIB | Tanggal tepat di sekitar tengah malam | `MANUAL-PENDING` |

## B. Perizinan & fitur perangkat

| ID | Skenario | Langkah | Ekspektasi | Status |
|---|---|---|---|---|
| MC-PERM-01 | Izin notifikasi (Android 13+) | Tolak lalu izinkan | Frame `1.10` & `11.3` berfungsi, tidak crash | `GAP (D-17)` — izin tak pernah diminta; notifikasi native belum ada (D-06) |
| MC-PERM-02 | Izin ditolak saat berjalan | Cabut izin dari Settings | App memberi pesan, tidak crash | `MANUAL-PENDING` |
| MC-PERM-03 | Izin kamera/penyimpanan (deteksi) | Tolak izin saat pilih foto kamera | Pesan jelas, halaman tetap jalan | `PASS` (diuji manual dev FE) — tak ada izin kamera di Settings, kamera tetap terbuka karena `image_picker` memakai intent kamera sistem (`architecture.md` §8) |
| MC-PERM-04 | Izin kamera dicabut saat app berjalan | Cabut saat di halaman pindai | Pesan jelas, tidak crash | `N/A` (D-14) — tidak ada izin kamera aplikasi yang bisa dicabut |

## C. Notifikasi umur bibit 15 hari (PB-03)

| ID | Skenario | Langkah | Ekspektasi | Status |
|---|---|---|---|---|
| MC-NOTIF-01 | Muncul tepat hari ke-15 | Semai, majukan tanggal perangkat ke H+15 | Notifikasi muncul sekali | `MANUAL-PENDING` |
| MC-NOTIF-02 | Tidak berulang | Biarkan lewat H+15 | Tidak diulang terus-menerus | `MANUAL-PENDING` |
| MC-NOTIF-03 | Setelah app dibuka ulang | Tutup & buka app | Penjadwalan tetap benar | `MANUAL-PENDING` |
| MC-NOTIF-04 | Setelah reboot | Restart perangkat | Notifikasi terjadwal tetap benar | `MANUAL-PENDING` |

> Catatan: sesuai keputusan D-06, ringkasan "siap pindah / stok menipis" di Beranda
> diambil dari **data nyata** (`v2BerandaNotifikasi`), bukan penjadwalan notifikasi
> lokal native. Notifikasi native Android tetap belum ada → `MANUAL-PENDING`/gap.

## D. Kinerja pada perangkat nyata (§5.7)

| ID | Skenario | Cara ukur | Target | Status |
|---|---|---|---|---|
| MC-PERF-01 | Muat halaman utama cold start | Stopwatch / DevTools | < 3 detik | `PASS` (diuji manual dev FE) — < 3 detik |
| MC-PERF-02 | Muat halaman utama warm start | Ulangi setelah cache | < 3 detik | `PASS` (diuji manual dev FE) — < 3 detik |
| MC-PERF-03 | Sinkronisasi setelah koneksi kembali | Matikan data, catat offline, nyalakan | < 1 menit | `MANUAL-PENDING` |
| MC-PERF-04 | Pencocokan aturan cuaca | Dari fetch BMKG sampai kartu tampil | < 2 detik | `MANUAL-PENDING` |
| MC-PERF-05 | Spesifikasi perangkat | Catat RAM/CPU/OS perangkat uji | RAM ≥ 3 GB, Android 8+ | `MANUAL-PENDING` |
| MC-PERF-06 | Inferensi deteksi hama per gambar | Ukur dari foto → hasil (cold & warm) | < 5 detik | `PASS` (diuji manual dev FE) — inferensi rata-rata kasar **1–2 detik** (hitungan kasar dev FE, bukan pengukuran alat), di bawah target 5 detik |
| MC-PERF-07 | Deteksi 50× berturut-turut (memori) | Ulang 50×, pantau memori/ANR | Tak OOM/crash | `PASS` (diuji manual dev FE) — 50× berturut-turut aman; memori aman karena foto hanya diunggah ke Cloudinary dan tidak disimpan di HP |

## E. Sync/offline pada perangkat (PB-07)

| ID | Skenario | Langkah | Ekspektasi | Status |
|---|---|---|---|---|
| MC-SYNC-01 | Catat offline lalu buka ulang | Airplane mode, catat 1 record, tutup paksa, buka | Record tetap ada & "belum tersinkron" | `N/A` (D-14 online-only) |
| MC-SYNC-02 | Putus tepat setelah kirim | Putus data di tengah request sebelum respons | Tidak duplikat setelah sync ulang | `N/A` (D-14 online-only) |
| MC-SYNC-03 | Dua perangkat transaksi keluar bersamaan | Dua akun keluarkan stok total > stok | Salah satu ditolak/server konsisten, tak ada stok negatif | `MANUAL-PENDING` — dev FE belum bisa menguji: keterbatasan perangkat (butuh dua perangkat). Sisi backend sudah lulus `qa/backend-concurrency.sh` 22/22 |
| MC-SYNC-04 | Pertukaran jam perangkat | Set jam mundur lalu sync | Urutan sync tidak rusak | `N/A` (D-14 online-only) |
| MC-SYNC-05 | Migrasi skema antar versi app | Pasang versi lama, isi data, upgrade | Data lama tidak hilang | `MANUAL-PENDING` |

## F. Skenario E2E penuh offline (PROMPT §5.1 varian)

| ID | Skenario | Langkah | Ekspektasi | Status |
|---|---|---|---|---|
| MC-E2E-01 | Seluruh siklus offline lalu sync | Airplane mode: inventaris→semai→pindah→rusak→pest→panen→jual, lalu nyalakan data | Semua terkirim berurutan, angka rekonsiliasi sama dengan varian online | `N/A` (D-14 online-only) |
| MC-E2E-02 | Campuran (putus di tengah) | Mulai online, putus di tengah, lanjut offline, sync | Tidak ada record hilang/ganda | `N/A` (D-14 online-only) |

## Fb. Deteksi hama di perangkat (PB-05)

| ID | Skenario | Langkah | Ekspektasi | Status |
|---|---|---|---|---|
| MC-PEST-01 | Foto nyata dari kamera | Ambil foto daun bergejala | Kelas + confidence tampil, wajar | `PASS` (diuji manual dev FE) |
| MC-PEST-02 | Foto tanpa hama | Foto daun bersih | Pesan netral "tidak ada hama terdeteksi", bukan "bebas hama" | `PASS` (diuji manual dev FE) |
| MC-PEST-03 | Airplane mode | Matikan data, deteksi | Tetap jalan tanpa request server | `N/A` (D-14) — layar deteksi butuh internet untuk memuat data meja/batch |
| MC-PEST-04 | Batal/putar/background saat inferensi | Batalkan & putar layar saat proses | Tidak crash, UI tidak beku | `PASS` (diuji manual dev FE) — pindai yang dibatalkan tidak tersimpan; putar layar saat inferensi aman |

---

## G. Lembar Observasi Usability (PROMPT §5.6 — bersama mitra non-teknis)

Tujuan: menilai apakah petani non-teknis dapat menyelesaikan tugas tanpa bantuan.
Isi per baris: **berhasil / berhasil dengan bantuan / gagal**, waktu, dan catatan.

### Skenario tugas

| No | Tugas | Ukur | Hasil | Catatan |
|---|---|---|---|---|
| U-1 | Login dan melihat Beranda | Berhasil? waktu? langkah? | | |
| U-2 | Catat panen satu batch | Jumlah langkah, kesalahan | | |
| U-3 | Catat penjualan dari hasil panen | Berhasil? sisa panen jelas? | | |
| U-4 | Catat penyemaian baru | Berhasil? | | |
| U-5 | Pindah bibit ke meja | Batas/kapasitas dipahami? | | |
| U-6 | Catat stok masuk/keluar | Berhasil? | | |
| U-7 | Lihat stok menipis | Indikator dipahami? | | |
| U-8 | Lihat cuaca & rekomendasi | Lokasi/waktu prakiraan jelas? | | |
| U-9 | Deteksi hama dengan kamera | Berhasil? hasil dipahami? | | *(fitur kini ada)* |
| U-10 | Terima rekomendasi perawatan & catat bahan | Stok berkurang dipahami? | | |

### Daftar periksa heuristik (diisi penguji)

- [ ] Target sentuh utama ≥ 48dp (tombol simpan, tab, FAB).
- [ ] Pesan error berbahasa Indonesia dan bisa ditindaklanjuti (bukan kode teknis).
- [ ] Kontras teks cukup untuk dibaca di bawah sinar matahari (periksa rasio kontras).
- [ ] Istilah konsisten: "HSS", "batch", "meja", "lahan" (tidak bergantian).
- [ ] Konfirmasi sebelum aksi destruktif (hapus/nonaktifkan).
- [ ] Jumlah langkah tugas utama wajar (catat: catat panen = … langkah).
- [ ] Ikon + label terbaca tanpa mengandalkan warna saja.
- [ ] Tidak ada jargon teknis pada layar yang dilihat petani.

**Status keseluruhan §5.6:** review heuristik statis selesai (lihat `testing.md` §5.6);
**usability test nyata bersama mitra `MANUAL-PENDING`**.

---

## H. Verifikasi perbaikan bug di HP (dev FE, 24–25 Nov 2026)

Bagian ini mencatat hasil uji **manual dev FE di HP asli** (bukan uji otomatis), sebagai
bukti bahwa perbaikan sesi 1 benar-benar terasa di perangkat. Baris bertanggal
**25 Nov 2026** adalah hasil verifikasi ulang sesi 4 (BUG-33..38, Fitur-1..3) dan BUG-31.
Beberapa perbaikan lulus sebagian dan melahirkan temuan lanjutan (BUG-39..47, Fitur-4)
yang dicatat dengan status apa adanya.

| ID | Bug yang diverifikasi | Skenario singkat | Hasil |
|---|---|---|---|
| MC-FIX-15 | BUG-15 — kontrol segmen Deteksi hama | Buka Deteksi hama, ganti segmen | `PASS` (diuji manual dev FE) |
| MC-FIX-17 | BUG-17 — lokasi cuaca | Buka Cuaca, lihat lokasi/prakiraan | `PASS` (diuji manual dev FE) — Sabrang/Ambulu/Jember tampil benar |
| MC-FIX-18 | BUG-18 — kartu "Lubang terisi" | Tekan kartu di Beranda | `PASS` (diuji manual dev FE) — membuka Tanam → Meja |
| MC-FIX-19 | BUG-19 — sesi dipulihkan | Tutup paksa lalu buka aplikasi | `PASS` (diuji manual dev FE) — langsung beranda v2 |
| MC-FIX-16 | BUG-16 — simpan pindaian | Deteksi → simpan & minta saran obat | `PASS` (diuji manual dev FE) — env Cloudinary server sudah diisi; simpan berhasil |
| MC-FIX-20/24 | BUG-20/BUG-24 — font 200% | Set ukuran font 200%, buka layar utama | `PASS` (diuji manual dev FE) — kecuali label grafik Ringkasan penjualan yang dicatat ulang sebagai BUG-31 |
| MC-FIX-22..25 | BUG-22..BUG-25 — temuan sesi 2 | Lihat `issues.md` per bug | `PASS` (diuji manual dev FE) — 24 Nov 2026 |
| MC-FIX-26 | BUG-26 — cuaca dari Beranda | Tekan kartu cuaca, cek tanggal/lokasi prakiraan | `PASS` (diuji manual dev FE) |
| MC-FIX-27 | BUG-27 — tanggal bawaan form | Buka form Catat rusak & penjualan, cek tanggal | `PASS` (diuji manual dev FE) |
| MC-FIX-28 | BUG-28 — tombol halaman sukses "Pindah ke meja" | Pindah semaian, tekan tiap tombol di halaman sukses | `PASS` untuk tombolnya (diuji manual dev FE) — tetapi data setelahnya basi, dicatat **BUG-34** |
| MC-FIX-29 | BUG-29 — jumlah form pindah | Tahan plus/minus, ketik angka, cek bawaan meja | `PASS` (diuji manual dev FE) |
| MC-FIX-30 | BUG-30 — notifikasi bisa diketuk | Buka notifikasi, ketuk baris, cek tujuan & status dibaca | `PASS` (diuji manual dev FE) |
| MC-FIX-31 | BUG-31 — daftar nilai per bulan penjualan | Buka Ringkasan penjualan, cek daftar per bulan | `PASS` (diuji manual dev FE, 25 Nov 2026) — kini daftar ke bawah (nama bulan kiri, nilai kanan), label bulan yang tidak sejajar dihapus |
| MC-FIX-32 | BUG-32 — riwayat rotasi | Buka Riwayat rotasi, cek filter & lipat entri | `PASS` (diuji manual dev FE) |
| MC-FIX-33 | BUG-33 — pemilih tanaman Catat panen | Catat panen dengan dua batch bernama sama, pilih keduanya | `PASS` (diuji manual dev FE, 25 Nov 2026) |
| MC-FIX-34 | BUG-34 — data meja setelah pindah | Selesai pindah, buka daftar/detail meja tujuan | `PASS` untuk bagian form sisa & invalidasi (diuji manual dev FE, 25 Nov 2026); tombol **"Lihat meja"** masih salah/basi → **BUG-39**, **BUG-41** |
| MC-FIX-35 | BUG-35 — "Tambah tanaman" di detail meja | Tekan "Tambah tanaman", pastikan lewat form pindah | `PASS` untuk bagian form pindah (diuji manual dev FE, 25 Nov 2026); pemilih **tidak mengenali semaian siap pindah** → **BUG-40** |
| MC-FIX-36 | BUG-36 — HST & perkiraan panen tanaman tersambung | Buka tanaman tersambung, cek HST & perkiraan panen | `PASS` (diuji manual dev FE, 25 Nov 2026) — tanggal benar (WIB) |
| MC-FIX-37 | BUG-37 — jumlah besar bisa diketik | Ketik angka besar di stok/semaian/rusak/rawat/panen | `PASS` (diuji manual dev FE, 25 Nov 2026) |
| MC-FIX-38 | BUG-38 — "Tambah bahan" menambah baris | Tambah semaian, tekan "Tambah bahan" 2–3×, simpan | `PASS` untuk bagian UI "Tambah bahan" (diuji manual dev FE, 25 Nov 2026); **stok terpakai** di Detail semaian masih salah → **BUG-44** |
| MC-FIT-1 | Fitur-1 (D-28) — riwayat rotasi per tanggal | Buka Riwayat rotasi, cek header tanggal WIB & lipat entri | `PASS` (diuji manual dev FE, 25 Nov 2026); pengguna masih butuh **filter rentang tanggal** → **Fitur-4** |
| MC-FIT-2 | Fitur-2 (D-27) — urutan daftar meja di form pindah | Buka "Pindah ke meja", cek urutan (tersedia dulu, penuh di bawah) | `PASS` (diuji manual dev FE, 25 Nov 2026) |
| MC-FIT-3 | Fitur-3 (D-29) — potong stok hanya Nutrisi & Obat | Setujui rekomendasi, cek daftar bahan hanya nutrisi/obat | **TIDAK LULUS** (diuji manual dev FE, 25 Nov 2026) — bahan **obat tidak muncul** → **BUG-46** |
| MC-FIX-39 | BUG-39 — Detail meja dari halaman sukses "Lihat meja" | Selesai pindah, tekan "Lihat meja", bandingkan data dengan daftar Meja | `FIXED di kode, belum diuji ulang di HP` — Detail meja kini satu pintu masuk & selalu baca ulang dari server |
| MC-FIX-40 | BUG-40 — semaian siap pindah di pemilih "Tambah tanaman" | Buat semaian HSS ≥ 15, buka Detail meja → Tambah tanaman | `FIXED di kode, belum diuji ulang di HP` — pemilih memakai aturan sama dengan daftar Semaian |
| MC-FIX-41 | BUG-41 — "Lihat semaian" di pemilih | Tekan "Lihat semaian" saat pemilih kosong | `FIXED di kode, belum diuji ulang di HP` — membuka daftar Semaian |
| MC-FIX-42 | BUG-42 — "Catat penjualan" dari Detail panen | Buka Detail panen, tekan "Catat penjualan", isi & simpan | `FIXED di kode, belum diuji ulang di HP` — tanggal hari ini (WIB) dan tersimpan ke server |
| MC-FIX-43 | BUG-43 — "Terjual"/"Sisa" setelah penjualan | Catat penjualan, buka kembali Detail panen | `FIXED di kode, belum diuji ulang di HP` — "Terjual" bertambah dari batch penjualan |
| MC-FIX-44 | BUG-44 — "Stok terpakai" semua bahan | Buat semaian 2 bahan, buka Detail semaian | `FIXED di kode, belum diuji ulang di HP` — semua bahan tampil |
| MC-FIX-45 | BUG-45 — tombol simpan punya spinner | Simpan yang butuh jaringan (login/karyawan/penjualan) | `FIXED di kode, belum diuji ulang di HP` — tombol menampilkan spinner & tak bisa ditekan ulang |
| MC-FIX-46 | BUG-46 — stok obat muncul di lembar terima | Terima rekomendasi hama, cek daftar bahan | `FIXED di kode, belum diuji ulang di HP` — obat (mis. Abamectin) & nutrisi bisa dipilih |
| MC-FIX-47 | BUG-47 — catatan tanaman tampil | Ubah catatan tanaman, simpan, lihat Detail tanaman | `FIXED di kode, belum diuji ulang di HP` — baris "Catatan" tampil di kartu info |
| MC-FIT-4 | Fitur-4 (D-32) — filter rentang tanggal riwayat | Buka Riwayat rotasi, pilih rentang tanggal, hapus filter | `FIXED di kode, belum diuji ulang di HP` — dari–sampai inklusif (WIB) + tombol hapus |
| MC-FIX-48 | BUG-48 (K-04) — nonaktifkan pegawai | Akun pegawai → Nonaktifkan, cek pesan & status daftar | `FIXED di kode, belum diuji ulang di HP` — server 204 tanpa body kini diterima |
| MC-FIX-49 | BUG-49 (K-07) — "Tambah barang" tak menunggu jaringan | Buka tab Stok, tekan "Tambah barang" | `FIXED di kode, belum diuji ulang di HP` — kategori/obat dihangatkan saat tab dibuka |
| MC-FIX-50 | BUG-50 (K-08) — "Kategori barang belum tersedia" | Tambah barang saat kategori kosong / jaringan putus | `FIXED di kode, belum diuji ulang di HP` — pesan dibedakan & muncul sebelum form |
| MC-FIX-51 | BUG-51 (K-14) — kode meja duplikat | Tambah meja dengan kode yang sudah ada, Simpan | `FIXED di kode, belum diuji ulang di HP` — ditolak di form, isian tak hilang |
| MC-FIX-52 | BUG-52 (K-15) — galat form meja tak hilang | Isi jumlah 0 → Simpan → perbaiki angka | `FIXED di kode, belum diuji ulang di HP` — galat hilang saat isian berubah |
| MC-FIX-53 | BUG-53 (K-17) — umpan balik simpan meja | Tambah meja → Simpan, amati daftar sebelum jawaban | `FIXED di kode (sebagian), belum diuji ulang di HP` — pesan "Menyimpan meja..." muncul segera; jeda jaringan tetap ada |
| MC-FIX-54 | BUG-54 (K-26) — form "Catat penjualan" mulai kosong | Penjualan → Catat penjualan (alur nyata), langsung Simpan | `FIXED di kode, belum diuji ulang di HP` — isian kosong, panen wajib dipilih |
| MC-FIX-55 | BUG-55 (K-28) — pemilih "Meja tanam" di deteksi | Buka Foto tanaman saat belum ada meja bertanaman | `FIXED di kode, belum diuji ulang di HP` — pesan prasyarat meja tampil |
| MC-FIX-56 | BUG-56 (K-02/D-34→D-40) — password 6–8 huruf+angka & telepon 10–13 | Tambah/ubah pegawai dengan password 6–8 huruf+angka, telepon 10–13, alamat bukan angka saja | `FIXED di kode, belum diuji ulang di HP` — validasi klien 6–8 + huruf&angka; server `newPasswordSchema` min 6 (max 128) |
| MC-FIX-57 | BUG-57 (K-03/K-18/D-35) — pop-up konfirmasi simpan | Ubah pegawai/meja lalu Simpan | `FIXED di kode, belum diuji ulang di HP` — pop-up konfirmasi muncul; Batal tak menutup form; form tambah tanpa pop-up |
| MC-FIX-58 | BUG-58 (K-05/D-36) — tombol "Aktifkan" pegawai | Nonaktifkan pegawai, buka detailnya, tekan "Aktifkan" | `FIXED di kode, belum diuji ulang di HP` — pegawai kembali aktif + toast "diaktifkan kembali" |
| MC-FIX-59 | BUG-59 (K-25/D-39) — keterangan penjualan | Catat/ubah penjualan, isi "Keterangan", simpan, buka detail | `FIXED di kode, belum diuji ulang di HP` — keterangan tersimpan, tampil di detail, terbawa dari antrean |

> Catatan: baris `PASS` di atas berasal dari laporan dev FE, bukan dari lingkungan QA ini
> (tidak ada perangkat Android di sini). Baris yang menyebut temuan lanjutan
> (BUG-39..59, Fitur-4) berarti bagian itu **belum lulus** di HP; semuanya kini
> **sudah diperbaiki** di `apps/mobile` dengan regression test (baris MC-FIX-39..59 &
> MC-FIT-4). Verifikasi visual ulang di HP wajib dilakukan dev FE sebelum dinyatakan
> tuntas untuk rilis.

---

> Sesi 7 (26 Nov 2026): bug FE dari testing pelapor + keputusan SA dikerjakan
> (BUG-60..67, D-40..D-50) dan ditambahkan di §H (MC-FIX-60..67) dengan status
> **`FIXED di kode, belum diuji ulang di HP`**. Tiga butir **butuh backend** dan
> sengaja tidak diubah di klien: hapus "belum lunas"/pembeli penjualan, dropdown
> obat dari katalog AI, dan riwayat perawatan (`docs/backend-change-requests.md`).
> **Tidak** ada baris baru yang ditulis `PASS`.

| Kode | Bug/keputusan | Langkah uji di HP | Status |
|---|---|---|---|
| MC-FIX-60 | BUG-60 — arsip stok tidak termuat | Arsipkan barang → buka chip "Arsip" → cek barang muncul; "Semua" tidak memuatnya | `FIXED di kode, belum diuji ulang di HP` |
| MC-FIX-61 | BUG-61 — ubah jenis barang | Ubah barang Benih→Nutrisi → Simpan → cek kategori ikut berubah | `FIXED di kode, belum diuji ulang di HP` |
| MC-FIX-62 | BUG-62 — pindah meja dobel submit/sisa bibit/estimasi | Pindah meja: tekan "Pindahkan" dua kali cepat; isi jumlah > sisa bibit; ubah tanggal | `FIXED di kode, belum diuji ulang di HP` — tombol loading, input terkunci, "Sisa bibit hanya N", estimasi HST dari tanggal pindah |
| MC-FIX-63 | BUG-63 — "Lihat semaian" menumpuk route | Dari Detail meja tekan "Lihat semaian" | `FIXED di kode, belum diuji ulang di HP` — kembali ke dashboard lalu tab Semaian |
| MC-FIX-64 | BUG-64 — keterangan tidak tampil di detail | Isi keterangan semaian/meja/panen → buka detail | `FIXED di kode, belum diuji ulang di HP` |
| MC-FIX-65 | BUG-65 — grafik panen data contoh | Catat 2–4 panen di tanggal berbeda → buka Riwayat Panen | `FIXED di kode, belum diuji ulang di HP` — grafik dari data asli, maks 3 tanggal, hari sama dijumlahkan |
| MC-FIX-66 | BUG-66 — pegawai bisa buka cuaca | Masuk sebagai pegawai → buka detail siklus | `FIXED di kode, belum diuji ulang di HP` — baris cuaca tidak ada (tanpa 403) |
| MC-FIX-67 | BUG-67 — kode meja otomatis | Tambah meja saat sudah ada A1/A2 | `FIXED di kode, belum diuji ulang di HP` — kode terisi A3, masih bisa ditimpa |

---

> Sesi 8 (27 Nov 2026): daftar menu umum diurutkan "perubahan terakhir" (BUG-68, D-51).
> Backend + FE berubah. Status **`FIXED di kode, belum diuji ulang di HP`**. **Tidak** ada
> baris baru yang ditulis `PASS`.

| Kode | Bug/keputusan | Langkah uji di HP | Status |
|---|---|---|---|
| MC-FIX-68a | BUG-68 — urutan Stok | Buka Stok → ubah/perbarui satu barang lama (atau catat panen yang mengubah saldo) → buka Stok lagi | `FIXED di kode, belum diuji ulang di HP` — barang yang baru diubah paling atas |
| MC-FIX-68b | BUG-68 — urutan Semaian & Meja | Catat semaian baru; pindah tanaman ke meja lama | `FIXED di kode, belum diuji ulang di HP` — semaian/meja yang baru berubah paling atas |
| MC-FIX-68c | BUG-68 — urutan Panen & Penjualan | Koreksi panen/penjualan lama (ubah berat/jumlah) tanpa mengubah tanggal → buka daftar | `FIXED di kode, belum diuji ulang di HP` — baris yang dikoreksi naik ke atas walau tanggalnya lama |
| MC-FIX-68d | BUG-68 — urutan Akun pegawai | Ubah data satu pegawai (atau aktif/nonaktifkan) → buka daftar akun | `FIXED di kode, belum diuji ulang di HP` — pegawai yang baru diubah paling atas |
| MC-FIX-68e | BUG-68 — tulis lalu refresh | Catat/ubah satu baris, amati daftar sebelum dan sesudah muat ulang | `FIXED di kode, belum diuji ulang di HP` — baris yang baru diubah tampil paling atas setelah server menjawab dan daftar disegarkan |

---

> Sesi 9 (27 Nov 2026): setiap tombol proses tulis memakai pop-up konfirmasi ulang dengan
> spinner sampai proses selesai, baru layar berpindah (BUG-69, D-52). **FE saja**. Status
> **`FIXED di kode, belum diuji ulang di HP`**. **Tidak** ada baris baru yang ditulis `PASS`.

| Kode | Bug/keputusan | Langkah uji di HP | Status |
|---|---|---|---|
| MC-FIX-69a | BUG-69 — semaian | Tambah semaian; ubah semaian; pindah semaian ke meja (jaringan lambat) | `FIXED di kode, belum diuji ulang di HP` — pop-up konfirmasi + spinner; layar pindah setelah selesai |
| MC-FIX-69b | BUG-69 — meja | Tambah meja; ubah meja; ubah status meja | `FIXED di kode, belum diuji ulang di HP` — pop-up konfirmasi + spinner di tombolnya |
| MC-FIX-69c | BUG-69 — kerusakan & catatan | Catat tanaman rusak; ubah laporan rusak; ubah catatan tanaman | `FIXED di kode, belum diuji ulang di HP` — pop-up konfirmasi + spinner |
| MC-FIX-69d | BUG-69 — panen | Catat panen; koreksi berat panen | `FIXED di kode, belum diuji ulang di HP` — pop-up konfirmasi + spinner |
| MC-FIX-69e | BUG-69 — penjualan | Catat penjualan; ubah penjualan; tandai lunas | `FIXED di kode, belum diuji ulang di HP` — pop-up konfirmasi + spinner |
| MC-FIX-69f | BUG-69 — stok | Tambah barang; ubah barang; catat stok; arsipkan barang | `FIXED di kode, belum diuji ulang di HP` — pop-up konfirmasi + spinner (arsip: pop-up destruktif) |
| MC-FIX-69g | BUG-69 — rekomendasi obat | Terima rekomendasi (pilih/tanpa potong stok); tolak rekomendasi (pilih alasan) | `FIXED di kode, belum diuji ulang di HP` — pop-up konfirmasi muncul setelah lembar terima/tolak |
| MC-FIX-69h | BUG-69 — tambah/ubah pegawai | Tambah pegawai; ubah pegawai (jaringan lambat) | `FIXED di kode, belum diuji ulang di HP` — pop-up konfirmasi + spinner |
| MC-FIX-69i | BUG-69 — aktif/nonaktif pegawai | Nonaktifkan pegawai; aktifkan kembali pegawai nonaktif | `FIXED di kode, belum diuji ulang di HP` — pop-up konfirmasi + spinner |
| MC-FIX-69j | BUG-69 — navigasi & galat | Halaman hasil pindah: tekan "Lihat meja"; lalu jalankan proses saat server menolak | `FIXED di kode, belum diuji ulang di HP` — navigasi loading tanpa pop-up; galat server tampil sebagai pesan dan form tetap terbuka |

---

> Sesi 10 (27 Nov 2026): perbaikan alur Inventaris dari uji manual di HP. Backend + FE
> berubah (nama unik, validasi stok di form, obat dari `obat_katalog`, aktifkan kembali).
> Status **`FIXED di kode, belum diuji ulang di HP`**. **Tidak** ada baris baru yang
> ditulis `PASS`.

| Kode | Perbaikan | Langkah uji di HP | Status |
|---|---|---|---|
| MC-FIX-70a | Nama barang unik | Tambah barang "Pupuk A"; lalu tambah lagi "  pupuk a " | `FIXED di kode, belum diuji ulang di HP` — pesan "Nama barang sudah dipakai" tampil di kolom nama, form tetap terbuka; nama barang arsip tetap dipesan |
| MC-FIX-70b | Batas stok awal & minimum | Tambah barang: stok awal `5`, stok minimum `10`; lalu coba stok awal `1.234` | `FIXED di kode, belum diuji ulang di HP` — "Stok minimum harus kurang dari stok awal." / "Gunakan maksimal 10 digit dan 2 angka desimal." |
| MC-FIX-70c | Obat dari katalog | Tambah barang → pilih jenis Obat | `FIXED di kode, belum diuji ulang di HP` — kolom "Nama barang" hilang, dropdown obat dari `obat_katalog`, nama barang = nama obat |
| MC-FIX-70d | Galat stok minimum saat Ubah | Ubah barang → isi stok minimum `0` atau `3,555` → Simpan | `FIXED di kode, belum diuji ulang di HP` — pesan tampil di form sesuai penyebab, tidak muncul di halaman detail |
| MC-FIX-70e | Aktifkan kembali barang arsip | Arsipkan barang → chip "Arsip" → buka barang → "Aktifkan kembali" | `FIXED di kode, belum diuji ulang di HP` — tombol ada, minta konfirmasi, barang kembali ke "Semua" + toast |
| MC-FIX-71a | Stok awal minimal 1 | Tambah barang: coba stok awal `0` dan `0,5` | `FIXED di kode, belum diuji ulang di HP` — "Stok awal minimal 1.", form tetap terbuka; `1` diterima |
| MC-FIX-71b | Stok minimum kurang dari stok awal | Tambah barang: stok awal `5`, stok minimum `5` | `FIXED di kode, belum diuji ulang di HP` — "Stok minimum harus kurang dari stok awal."; `4` diterima, kosong tetap diterima |
| MC-FIX-72a | Stok tersedia di Ubah barang | Ubah barang → lihat kolom "Stok tersedia" | `FIXED di kode, belum diuji ulang di HP` — saldo terkini tampil (mis. `12 pak`), kolom terkunci, ada keterangan "Stok diubah lewat Catat stok." |
| MC-FIX-72b | Stok minimum untuk jenis Obat | Ubah barang jenis Obat | `FIXED di kode, belum diuji ulang di HP` — kolom "Stok minimum (opsional)" muncul (sebelumnya tersembunyi) |
| MC-FIX-72c | Batas maksimum stok minimum saat Ubah | Ubah barang stok `12` → stok minimum `12` lalu `13` | `FIXED di kode, belum diuji ulang di HP` — "Stok minimum harus kurang dari stok tersedia."; `11` diterima; minimum yang tidak diubah tidak diblokir (stok `2`, minimum `3` tetap bisa Simpan) |

---

> Sesi 10 lanjutan (27 Nov 2026): perbaikan alur Catat stok (mode Masuk) dan
> Tambah semaian. Status **`FIXED di kode, belum diuji ulang di HP`**. **Tidak**
> ada baris baru yang ditulis `PASS`.

| Kode | Perbaikan | Langkah uji di HP | Status |
|---|---|---|---|
| MC-FIX-71a | Angka bawaan catat stok 1 | Detail barang → Catat stok; cek angka awal di `Pakai`, lalu pindah ke `Masuk` | `FIXED di kode, belum diuji ulang di HP` — angka awal 1 di kedua mode |
| MC-FIX-71b | Batas maksimum stok masuk | Catat stok → `Masuk` → ketik `9999999998` → Simpan | `FIXED di kode, belum diuji ulang di HP` — pesan "Maksimal ... pak" tampil di sheet, sheet tetap terbuka, tombol plus berhenti di batas |
| MC-FIX-71c | Angka bawaan tambah semaian 1 | Penyemaian → Tambah; cek jumlah benih dan jumlah bahan | `FIXED di kode, belum diuji ulang di HP` — keduanya 1 |
| MC-FIX-71d | Pesan jumlah benih | Tambah semaian → kosongkan/isi `0` jumlah benih → Simpan | `FIXED di kode, belum diuji ulang di HP` — "Benih harus angka positif" di kolom |
| MC-FIX-71e | Info stok tidak mencukupi | Tambah semaian → jumlah bahan `15` (stok 12) | `FIXED di kode, belum diuji ulang di HP` — info bawah "Benih Romaine: Stok tidak mencukupi", bukan angka minus |

---

> Sesi 10 lanjutan 2 (27 Nov 2026): perbaikan alur Meja. Status **`FIXED di
> kode, belum diuji ulang di HP`**. **Tidak** ada baris baru yang ditulis `PASS`.

| Kode | Perbaikan | Langkah uji di HP | Status |
|---|---|---|---|
| MC-FIX-72a | Kode meja tidak bisa diketik (tambah) | Meja → Tambah; coba ketuk/ketik kolom "Kode meja" | `FIXED di kode, belum diuji ulang di HP` — kode terisi otomatis (mis. A1/A3), kolom abu-abu tidak bisa diketik |
| MC-FIX-72b | Kode meja tidak bisa diketik (ubah) | Detail meja → Ubah meja; coba ketuk/ketik kolom "Kode meja" | `FIXED di kode, belum diuji ulang di HP` — menampilkan kode meja, tidak bisa diubah |
| MC-FIX-72c | Placeholder jumlah lubang 250 | Meja → Tambah; lihat placeholder kolom "Jumlah lubang" | `FIXED di kode, belum diuji ulang di HP` — "Contoh: 240 (maksimal 250)" |
| MC-FIX-72d | Tombol tambah tanaman saat Perawatan | Detail meja → Ubah status → Perawatan; lihat footer | `FIXED di kode, belum diuji ulang di HP` — tombol "Tambah tanaman" hilang, hanya catatan "Meja Perawatan tidak menerima tanaman baru." |

---

> Sesi 10 lanjutan 3 (27 Nov 2026): perbaikan alur Tanaman & Tanaman Rusak.
> Status **`FIXED di kode, belum diuji ulang di HP`**. **Tidak** ada baris baru
> yang ditulis `PASS`.

| Kode | Perbaikan | Langkah uji di HP | Status |
|---|---|---|---|
| MC-FIX-73a | Tombol "Catat rusak" di Detail tanaman | Meja → Detail meja → ketuk salah satu tanaman → lihat footer | `FIXED di kode, belum diuji ulang di HP` — footer hanya "Ubah"; pencatatan dari menu Tanaman rusak |
| MC-FIX-73b | Laporan baru tetap tampil saat daftar dibuka lagi | Detail tanaman → Tanaman rusak → Catat rusak → Simpan → kembali ke Detail tanaman → buka Tanaman rusak lagi | `FIXED di kode, belum diuji ulang di HP` — baris baru masih ada dan jumlah di subjudul ikut naik |
| MC-FIX-73c | Detail kerusakan sebelum ubah | Tanaman rusak → ketuk salah satu baris | `FIXED di kode, belum diuji ulang di HP` — halaman "Detail kerusakan" (jumlah, tanggal, keterangan) dengan tombol "Ubah kerusakan" |
| MC-FIX-73d | Ubah dari halaman detail | Detail kerusakan → Ubah kerusakan → ubah jenis/jumlah → Simpan | `FIXED di kode, belum diuji ulang di HP` — detail menampilkan data baru; kembali ke daftar, baris ikut berubah |
| MC-FIX-73e | Kategori "Penyakit" | Tanaman rusak → Catat rusak, lalu Ubah kerusakan → lihat chip jenis | `FIXED di kode, belum diuji ulang di HP` — chip "Penyakit" menggantikan "Busuk akar" |
| MC-FIX-73f | Tombol kembali HP setelah mencatat | Catat rusak → Simpan → tekan tombol kembali HP (bukan panah di layar) sampai Detail tanaman, lalu buka Tanaman rusak lagi | `FIXED di kode, belum diuji ulang di HP` — baris tetap ada walau keluar lewat tombol kembali HP |

---

> Sesi 10 lanjutan 4 (27 Nov 2026): perbaikan alur Panen & Penjualan.
> Status **`FIXED di kode, belum diuji ulang di HP`**. **Tidak** ada baris baru
> yang ditulis `PASS`.

| Kode | Perbaikan | Langkah uji di HP | Status |
|---|---|---|---|
| MC-FIX-74a | "Berat layak" tetap tampil saat galat | Panen → Catat panen → kosongkan berat total → Simpan; lihat kartu biru "Berat layak" | `FIXED di kode, belum diuji ulang di HP` — pesan galat muncul, kartu "Berat layak" tetap terlihat dan ikut berubah saat berat diisi |
| MC-FIX-74b | Pemilih hanya tanaman siap panen | Panen → Catat panen → Pilih tanaman; bandingkan dengan batch yang baru dipindah | `FIXED di kode, belum diuji ulang di HP` — hanya batch HST ≥ 45 atau HSS ≥ 60; batch muda tidak muncul; bila belum ada yang siap muncul penjelasan HST 45/HSS 60 |
| MC-FIX-74c | Ubah panen: loading dan tetap terbuka saat galat | Detail panen → Ubah → Simpan → konfirmasi; matikan internet tepat setelah konfirmasi | `FIXED di kode, belum diuji ulang di HP` — tombol dialog menampilkan spinner, layar tidak langsung kembali; saat gagal muncul pesan dan form masih terbuka dengan isian utuh |
| MC-FIX-74d | Muat Panen tidak menunggu daftar batch | Buka tab Tanam → Panen berulang kali dengan riwayat panjang, atau jaringan lambat | `FIXED di kode, belum diuji ulang di HP` — chip Estimasi/Riwayat terisi begitu datanya tiba, kerangka per chip, bukan satu layar tunggu |
| MC-FIX-74e | Tanpa isian status pembayaran | Penjualan → Catat penjualan; gulir seluruh form | `FIXED di kode, belum diuji ulang di HP` — tidak ada "Pembayaran"/"Lunas"/"Belum lunas"; simpan tetap berhasil |
| MC-FIX-74f | Tanpa saringan status bayar | Penjualan (daftar); lihat bawah kartu ringkasan | `FIXED di kode, belum diuji ulang di HP` — tidak ada chip Semua/Belum lunas/Lunas, tidak ada baris "Belum lunas" di kartu ringkasan |
| MC-FIX-74g | Detail penjualan tanpa "Tandai lunas" | Penjualan → ketuk penjualan lama yang dulu belum lunas | `FIXED di kode, belum diuji ulang di HP` — footer hanya "Ubah"; tidak ada lencana Lunas/Belum lunas; penjualan antrean tetap berlencana "Antrean" |
| MC-FIX-74h | Ringkasan penjualan tanpa "Belum lunas" | Penjualan → ikon grafik (Ringkasan penjualan) | `FIXED di kode, belum diuji ulang di HP` — kartu info hanya "Total 3 bulan" dan "Rata-rata per kg" |

---

> Sesi 10 lanjutan 5 (27 Nov 2026): perbaikan alur Perawatan (deteksi & riwayat
> stok). Status **`FIXED di kode, belum diuji ulang di HP`**. **Tidak** ada baris
> baru yang ditulis `PASS`.

| Kode | Perbaikan | Langkah uji di HP | Status |
|---|---|---|---|
| MC-FIX-75a | Foto tanpa hama berlabel "Tidak terdeteksi" | Rawat → bagian "Pindaian terbaru"; lihat foto daun yang bersih | `FIXED di kode, belum diuji ulang di HP` — keterangan kanan baris berbunyi "Tidak terdeteksi", bukan "Tanpa keyakinan" |
| MC-FIX-75b | Detail deteksi tanpa hama tanpa tombol rotasi | Rawat → ketuk baris foto yang tidak mendeteksi hama | `FIXED di kode, belum diuji ulang di HP` — kartu menampilkan "Tidak ada hama" + "Tidak terdeteksi"; tombol "Lihat riwayat rotasi obat" tidak ada |
| MC-FIX-75c | Detail deteksi berhama tetap punya tombol rotasi | Rawat → ketuk baris foto yang mendeteksi hama | `FIXED di kode, belum diuji ulang di HP` — meta "Keyakinan NN%", tombol "Lihat riwayat rotasi obat" tetap ada dan membuka riwayat |
| MC-FIX-75d | Potongan stok perawatan masuk riwayat | Rawat → terima rekomendasi dengan potong stok → Stok → buka barang obat itu → kartu "Riwayat" | `FIXED di kode, belum diuji ulang di HP` — baris "Pakai N ml" terbaru muncul paling atas, walau barang sudah punya banyak catatan |

---

> Sesi 10 lanjutan 6 (27 Nov 2026): perbaikan Ubah profil petani & pegawai.
> Status **`FIXED di kode, belum diuji ulang di HP`**. **Tidak** ada baris baru
> yang ditulis `PASS`.

| Kode | Perbaikan | Langkah uji di HP | Status |
|---|---|---|---|
| MC-FIX-76a | Ubah profil minta konfirmasi dulu | Akun → Akun saya → Ubah → ubah nama → Simpan | `FIXED di kode, belum diuji ulang di HP` — muncul dialog "Simpan perubahan profil?"; data baru dikirim setelah menekan Simpan di dialog |
| MC-FIX-76b | Ubah profil menampilkan loading | Dialog konfirmasi → Simpan (jaringan lambat) | `FIXED di kode, belum diuji ulang di HP` — tombol dialog menampilkan spinner, form belum kembali; berhasil → toast "Perubahan tersimpan", gagal → form tetap terbuka dengan isian utuh |

---

> Sesi 11 (28 Nov 2026): default meja "Pindah ke meja" & loading "Tanaman di
> meja". Status **`FIXED di kode, belum diuji ulang di HP`**. **Tidak** ada baris
> baru yang ditulis `PASS`.

| Kode | Perbaikan | Langkah uji di HP | Status |
|---|---|---|---|
| MC-FIX-77a | Bawaan meja pindah = meja paling atas (lubang kosong terbanyak) | Semaian → buka semaian siap pindah → Pindahkan → lihat meja terpilih tanpa menyentuh daftar | `FIXED di kode, belum diuji ulang di HP` — yang terpilih adalah baris paling atas (lubang kosong terbanyak), bukan M-02 yang kebetulan pertama di data |
| MC-FIX-77b | Loading pada "Tanaman di meja" | Meja → buka detail meja yang terisi dengan jaringan lambat, atau dari halaman sukses "Lihat meja" | `FIXED di kode, belum diuji ulang di HP` — kartu menampilkan kerangka baris tanaman, bukan "Belum ada tanaman di meja ini."; setelah data tiba, baris tanaman muncul |
