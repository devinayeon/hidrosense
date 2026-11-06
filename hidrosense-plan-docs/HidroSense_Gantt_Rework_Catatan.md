# Catatan Perbaikan Gantt Chart HidroSense (ProjectLibre)

File hasil: `HidroSense_A9_Revisi_ProjectLibre_v2.pod` (file asli `HidroSense_A9_Revisi_ProjectLibre.pod` tidak diubah).

## Komentar reviewer

> Di ProjectLibre, kalau warnanya biru, artinya ada yang tidak benar. Bisa jadi ada pekerjaan yang selesai lebih dulu dari yang lain.

Di ProjectLibre, batang **merah = jalur kritis**, **biru = tugas yang punya kelonggaran waktu (slack)**. Jadwal yang benar punya satu jalur merah dari tugas pertama sampai penyerahan. Di file lama jalur itu tidak ada.

## Temuan di file lama (diukur dari file, bukan perkiraan)

| Temuan | File lama | Dampak |
|---|---|---|
| Tanggal dikunci manual | 120 dari 120 tugas dikunci: 118 "Start No Earlier Than" dan 2 "Must Start On" | Tanggal tidak mengikuti urutan kerja. Hubungan antartugas tidak lagi menentukan jadwal. |
| Jalur kritis | Hanya 2 tugas kritis dari 120 | Hampir semua batang biru. Ini yang dilihat reviewer. |
| Tugas tanpa kelanjutan | 5.4.7 (usability testing) tidak mengarah ke tugas mana pun; 5.2.2 (perbaikan desain berdasarkan usability testing) tidak tersambung ke 5.4.7 | Hasil uji kegunaan tidak memengaruhi apa pun. |
| Urutan tidak masuk akal | 1.8 (rancangan proses bisnis) mulai 21 Agt, sebelum 1.2 (identifikasi proses bisnis) selesai 24 Agt | Pekerjaan hilir selesai lebih dulu dari hulunya. |
| Penyerahan | Milestone 5.5.5 dikunci ke Sabtu 28 Nov (hari non-kerja) | Tanggal tidak bisa bergeser walau pekerjaan sebelumnya terlambat. |

## Yang diubah

- Semua batasan tanggal dihapus (semua tugas menjadi "As Soon As Possible").
- Tautan antartugas dibangun ulang dari urutan kerja: 195 tautan (181 selesai-ke-mulai, 4 mulai-ke-mulai, 10 selesai-ke-selesai).
- Setiap tugas kecuali 1.1 punya predecessor, dan semua tugas bermuara ke penyerahan (5.5.6 adalah tugas terakhir).
- Milestone 5.5.5 tidak lagi dikunci. Deadline 28 Nov 2026 17:00 dipasang sebagai deadline (tidak menggeser jadwal).
- Pembagian ketersediaan 25% per anggota dihitung ulang supaya tidak ada yang kelebihan beban.

**Tidak diubah:** nama tugas, nomor WBS, catatan, sumber daya, kalender kerja, dan **durasi semua tugas**.

## Hasil

Semua tahap selesai tepat di tanggal rencana dokumen:

| Tahap | Selesai |
|---|---|
| Tahap awal | Jum 28 Agt 2026 |
| Sprint 1 | Sel 22 Sep 2026 |
| Sprint 2 | Kam 15 Okt 2026 |
| Sprint 3 | Jum 6 Nov 2026 |
| Sprint 4 | Jum 27 Nov 2026 (milestone penyerahan 15:00, deadline 28 Nov) |

76 tugas kritis (merah), 44 tugas dengan kelonggaran (biru). Tidak ada kelebihan beban sumber daya (0 jam di atas 25%).

## Keputusan yang perlu diketahui tim

Dengan urutan yang benar dan durasi lama, jadwal tidak muat: draf pertama berakhir 9 Des 2026. Agar muat di 28 Nov tanpa mengubah durasi, jadwal memakai tumpang-tindih yang wajar:

1. **Uji berjalan bersamaan dengan implementasi** (selesai 0,5–1 hari setelah implementasi): 2.4.2, 2.4.3, 3.4.2, 3.4.3, 4.4.2 sampai 4.4.4, 4.4.6.
2. **Retest mulai 1 hari setelah code review mulai**: 2.4.5, 3.4.6, 4.4.7, 5.4.9.
3. **Sprint 2:** 3.3.7 (hubungkan deteksi ke batch) tidak menunggu 3.3.6 karena dikerjakan orang lain; 3.4.5 (waktu inferensi) mengikuti model hasil konversi 3.3.5.
4. **Sprint 3:** implementasi mulai setelah Class Diagram (4.2.3), tidak menunggu seluruh desain antarmuka (4.2.4).
5. **Sprint 4:** ProjectLibre menolak tautan melingkar antarkelompok peran (usability test → perbaikan desain → perbaikan UI → regresi). Perbaikan desain 5.2.2 diberi jeda 5 hari kerja setelah 5.2.1 supaya jatuh sesudah usability testing 5.4.7. **Jika jadwal 5.4.7 bergeser, jeda ini harus disesuaikan manual.**
6. **Sprint 4:** tautan 5.1.3 → 5.4.7 dihapus (skenario validasi disepakati bersama Tester); usability testing 5.4.7 mengikuti 5.3.3 dan 5.4.1.

## Risiko

- Semua sprint zero-slack di jalur utama. Satu hari keterlambatan di jalur merah menggeser penyerahan satu hari.
- Jadwal ini mengandalkan tumpang-tindih uji dan implementasi. Jika Tester tidak bisa mulai bersamaan, sprint terkait melewati batasnya.

## Verifikasi

- Jadwal dihitung ulang oleh ProjectLibre sendiri dan dicocokkan dengan penjadwal terpisah: 120 dari 120 tugas cocok sampai jam.
- Pemeriksaan tautan memakai tanggal dari ProjectLibre: 0 pelanggaran.
- File dibuka di aplikasi ProjectLibre dan batang merah/biru tampil sesuai.

## Yang masih perlu dilakukan

- Ganti gambar Gantt Chart di bagian 4.3 dokumen rencana dengan tangkapan layar dari file v2 (gambar lama masih menampilkan jadwal lama).
- Saat dibuka, ProjectLibre menandai file "belum disimpan" (tanda `*`) karena menghitung ulang jadwal. Simpan sekali (Ctrl+S) jika ingin menimpa.
