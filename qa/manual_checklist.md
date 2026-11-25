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

> Catatan: baris `PASS` di atas berasal dari laporan dev FE, bukan dari lingkungan QA ini
> (tidak ada perangkat Android di sini). Baris yang menyebut temuan lanjutan
> (BUG-39..47, Fitur-4) berarti bagian itu **belum lulus** di HP dan sudah/sedang
> diperbaiki di `apps/mobile` dengan regression test; verifikasi visual ulang di HP
> wajib dilakukan dev FE sebelum dinyatakan tuntas untuk rilis.
