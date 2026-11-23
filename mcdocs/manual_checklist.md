# mcdocs/manual_checklist.md — Uji manual (perangkat fisik / mitra)

Uji yang **tidak dapat** dijalankan otomatis di lingkungan ini (tanpa emulator/perangkat
Android, tanpa kamera fisik, tanpa mitra) ditandai **`MANUAL-PENDING`**. Ini bukan klaim
lulus — ini daftar yang harus dikerjakan manusia sebelum presentasi.

Konteks lingkungan (nyata): `adb devices` → tidak ada perangkat; `flutter test` hanya
menjalankan widget/unit tes tanpa Android. Karena itu semua butir di bawah belum dijalankan.

---

## A. Perangkat & OS (§5.4)

| ID | Skenario | Langkah | Ekspektasi | Status |
|---|---|---|---|---|
| MC-DEV-01 | Android 8.0 (API 26) batas bawah | Pasang APK di emulator API 26 | App jalan, semua layar tampil benar | `MANUAL-PENDING` |
| MC-DEV-02 | Android terbaru | Pasang APK di emulator/perangkat API terbaru | App jalan tanpa anomali | `MANUAL-PENDING` |
| MC-DEV-03 | Rotasi layar | Putar layar di tiap layar utama | Layout menyesuaikan, tidak crash, tidak reset form | `MANUAL-PENDING` |
| MC-DEV-04 | Font sistem besar | Set 200% font sistem | Teks tidak terpotong, tombol tetap >= 48dp | `MANUAL-PENDING` |
| MC-DEV-05 | Layar 360x640 & tablet | Jalankan di layar kecil & besar | Layout tidak rusak/overflow | `MANUAL-PENDING` |
| MC-DEV-06 | Mode gelap/terang | Ganti tema sistem | Warna kontras, teks terbaca | `MANUAL-PENDING` |
| MC-DEV-07 | Background/foreground | Tekan Home lalu kembali | State form terjaga, tidak crash | `MANUAL-PENDING` |
| MC-DEV-08 | Kill paksa | Force-stop saat alur berjalan | Data yang sudah dicatat tetap ada saat dibuka | `MANUAL-PENDING` |
| MC-DEV-09 | Memori rendah & penyimpanan penuh | Trigger low-memory; isi penyimpanan sampai penuh | Tidak crash; pesan jelas saat gagal simpan | `MANUAL-PENDING` |
| MC-DEV-10 | Jam/zona waktu diubah | Set jam mundur/maju, ganti TZ | HSS/tanggal tetap konsisten WIB; sync tidak rusak | `MANUAL-PENDING` |
| MC-DEV-11 | Build release | `flutter build apk --release` lalu pasang | Tidak ada banner debug; ukuran wajar; tidak crash | `MANUAL-PENDING` |
| MC-DEV-12 | Lokasi Ambulu (WIB) | Jalankan di perangkat TZ WIB | Tanggal tepat di sekitar tengah malam | `MANUAL-PENDING` |

## B. Perizinan & fitur perangkat

| ID | Skenario | Langkah | Ekspektasi | Status |
|---|---|---|---|---|
| MC-PERM-01 | Izin notifikasi (Android 13+) | Tolak lalu izinkan | Frame `1.10` & `11.3` berfungsi, tidak crash | `MANUAL-PENDING` |
| MC-PERM-02 | Izin ditolak saat berjalan | Cabut izin dari Settings | App memberi pesan, tidak crash | `MANUAL-PENDING` |
| MC-PERM-03 | Izin kamera/penyimpanan (deteksi) | — | **Tidak ada implementasi kamera** → tidak berlaku (lihat PB-05 `N/A`) | `N/A` |

## C. Notifikasi umur bibit 15 hari (PB-03)

| ID | Skenario | Langkah | Ekspektasi | Status |
|---|---|---|---|---|
| MC-NOTIF-01 | Muncul tepat hari ke-15 | Semai, majukan tanggal perangkat ke H+15 | Notifikasi muncul sekali | `MANUAL-PENDING` |
| MC-NOTIF-02 | Tidak berulang | Biarkan lewat H+15 | Tidak diulang terus-menerus | `MANUAL-PENDING` |
| MC-NOTIF-03 | Setelah app dibuka ulang | Tutup & buka app | Penjadwalan tetap benar | `MANUAL-PENDING` |
| MC-NOTIF-04 | Setelah reboot | Restart perangkat | Notifikasi terjadwal tetap benar | `MANUAL-PENDING` |

## D. Kinerja pada perangkat nyata (§5.7)

| ID | Skenario | Cara ukur | Target | Status |
|---|---|---|---|---|
| MC-PERF-01 | Muat halaman utama cold start | Stopwatch / Flutter DevTools | < 3 detik | `MANUAL-PENDING` |
| MC-PERF-02 | Muat halaman utama warm start | Ulangi setelah cache | < 3 detik | `MANUAL-PENDING` |
| MC-PERF-03 | Sinkronisasi setelah koneksi kembali | Matikan data, catat offline, nyalakan | < 1 menit | `MANUAL-PENDING` |
| MC-PERF-04 | Pencocokan aturan cuaca | Dari fetch BMKG sampai kartu tampil | < 2 detik | `MANUAL-PENDING` |
| MC-PERF-05 | Spesifikasi perangkat | Catat RAM/CPU/OS perangkat uji | RAM >= 3 GB, Android 8+ | `MANUAL-PENDING` |

## E. Sync/offline pada perangkat (PB-07)

| ID | Skenario | Langkah | Ekspektasi | Status |
|---|---|---|---|---|
| MC-SYNC-01 | Catat offline lalu buka ulang | Airplane mode, catat 1 record, tutup paksa, buka | Record tetap ada & "belum tersinkron" | `MANUAL-PENDING` |
| MC-SYNC-02 | Putus tepat setelah kirim | Putus data di tengah request sebelum respons | Tidak duplikat setelah sync ulang | `MANUAL-PENDING` |
| MC-SYNC-03 | Dua perangkat transaksi keluar bersamaan | Dua akun keluarkan stok total > stok | Salah satu ditolak/server konsisten, tak ada stok negatif | `MANUAL-PENDING` |
| MC-SYNC-04 | Pertukaran jam perangkat | Set jam mundur lalu sync | Urutan sync tidak rusak | `MANUAL-PENDING` |
| MC-SYNC-05 | Migrasi skema antar versi app | Pasang versi lama, isi data, upgrade ke versi baru | Data lama tidak hilang | `MANUAL-PENDING` |

## F. Skenario E2E penuh offline (PROMPT §5.1 varian)

| ID | Skenario | Langkah | Ekspektasi | Status |
|---|---|---|---|---|
| MC-E2E-01 | Seluruh siklus offline lalu sync | Airplane mode: inventaris→semai→pindah→rusak→panen→jual, lalu nyalakan data | Semua terkirim berurutan, angka rekonsiliasi sama dengan varian online | `MANUAL-PENDING` |
| MC-E2E-02 | Campuran (putus di tengah) | Mulai online, putus di tengah, lanjut offline, sync | Tidak ada record hilang/ganda | `MANUAL-PENDING` |

---

## G. Lembar Observasi Usability (PROMPT §5.6 — bersama mitra non-teknis)

Tujuan: menilai apakah petani non-teknis dapat menyelesaikan tugas tanpa bantuan.
Isi per baris: **berhasil / berhasil dengan bantuan / gagal**, waktu, dan catatan.

### Skenario tugas

| No | Tugas | Ukur | Hasil | Catatan |
|---|---|---|---|---|
| U-1 | Login dan melihat Beranda | Berhasil? waktu? langkah? | | |
| U-2 | Catat panen satu batch | Jumlah langkah, kesalahan | | |
| U-3 | Catat penjualan dari hasil panen | Berhasil? sisa panen tampil jelas? | | |
| U-4 | Catat penyemaian baru | Berhasil? | | |
| U-5 | Pindah bibit ke meja | Batas/kapasitas dipahami? | | |
| U-6 | Catat stok masuk/keluar | Berhasil? | | |
| U-7 | Lihat stok menipis | Indikator dipahami? | | |
| U-8 | Lihat cuaca & rekomendasi | Lokasi/waktu prakiraan jelas? | | |
| U-9 | Deteksi hama dengan kamera | *(N/A — fitur belum ada)* | | |

### Daftar periksa heuristik (diisi penguji)

- [ ] Target sentuh utama >= 48dp (tombol simpan, tab, FAB).
- [ ] Pesan error berbahasa Indonesia dan bisa ditindaklanjuti (bukan kode teknis).
- [ ] Kontras teks cukup untuk dibaca di bawah sinar matahari (periksa rasio kontras).
- [ ] Istilah konsisten: "HSS", "batch", "meja", "lahan" (tidak bergantian).
- [ ] Konfirmasi sebelum aksi destruktif (hapus/nonaktifkan).
- [ ] Jumlah langkah tugas utama wajar (catat: catat panen = ... langkah).
- [ ] Ikon + label terbaca tanpa mengandalkan warna saja.
- [ ] Tidak ada jargon teknis pada layar yang dilihat petani.

**Status keseluruhan §5.6:** review heuristik statis selesai (lihat `testing.md`
TC-UX-*); **usability test nyata bersama mitra `MANUAL-PENDING`**.
