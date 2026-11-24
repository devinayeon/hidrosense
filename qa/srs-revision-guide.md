# qa/srs-revision-guide.md — Panduan revisi SRS (offline-first → online-only)

Dokumen ini **panduan untuk SA (System Analyst)** merevisi SRS/Plan Document agar
selaras dengan keputusan PM **D-14: aplikasi online-only**. Dibuat sesi 4 (24 Nov 2026)
sesuai **D-30**; gap terkait = **G-17** di `qa/rtm.md`.

Tujuan: menghilangkan perbedaan antara dokumen ("offline-first": menyimpan lokal lalu
sinkron) dan produk nyata (setiap simpan langsung ke server). Ini **bukan** bug kode;
kode sudah benar.

Sumber yang direvisi: `hidrosense-plan-docs/Hidrosense Plan Document.md`.
QA **tidak** mengubah SRS; dokumen ini hanya menunjukkan **apa** dan **di mana** yang
perlu diubah, supaya SA dapat memutuskannya.

---

## 1. Ringkasan perubahan yang diusulkan

| Hal | Kalimat sekarang (inti) | Usulan setelah revisi |
|---|---|---|
| Sifat penyimpanan | "Menyimpan data lokal, sinkron otomatis saat online" (offline-first) | "Setiap perubahan langsung dikirim ke server saat ada internet; bila gagal, disimpan di antrean untuk dicoba ulang" |
| Kemampuan offline | "Mendukung pencatatan saat tidak terhubung internet" (PB-07) | "Pencatatan/mengakses menu saat offline **tidak** didukung (wajar)" — atau dijadwalkan untuk rilis berikutnya |
| Lokasi proses deteksi hama | deteksi TFLite lokal (tetap) | **tidak berubah** — inferensi model tetap lokal di perangkat |
| Target "sinkron < 1 menit" | sinkronisasi otomatis < 1 menit | tetap, tetapi dibaca sebagai "pengiriman ulang kiriman gagal < 1 menit saat koneksi kembali" |

## 2. Lokasi konkret di `Hidrosense Plan Document.md`

Nomor baris mengacu versi 24 Nov 2026; SA sebaiknya mencari frasa, bukan mengandalkan
angka baris.

| Baris (±) | Bagian | Kalimat kini | Usulan |
|---|---|---|---|
| 106 | Special Issues / Constraints | "Sistem membutuhkan koneksi internet untuk sinkronisasi data…" | OK, bisa tetap; pertegas bahwa tanpa internet pencatatan tidak jalan |
| 295 | Asumsi | "Aktor membutuhkan koneksi internet untuk melakukan sinkronisasi data…" | "…untuk melakukan pencatatan dan sinkronisasi data…" |
| 355, 386 | Software Interfaces / Interfaces with Services | "SQLite sebagai basis data lokal dan Turso (libSQL) sebagai basis data sinkronisasi" | Tetap benar sebagai teknologi; tambahkan catatan: SQLite kini cache/antrean kiriman gagal, bukan basis kerja offline |
| 376 | Operations | "Sistem melakukan sinkronisasi data ke server pusat secara otomatis ketika perangkat terhubung ke internet" | "Sistem mengirim data ke server pusat secara otomatis saat ada koneksi; kiriman yang gagal dicoba ulang saat koneksi kembali" |
| 592 | Persyaratan Numerik Statis | "…sinkronisasi data … kurang dari 1 menit setelah perangkat terhubung ke internet" | Baca sebagai batas **pengiriman ulang** kiriman gagal; tidak berlaku sebagai penyimpanan offline |
| 616, 643 | Availability / Reliability | "Sistem menangani kegagalan sinkronisasi melalui pengulangan otomatis…" | Tetap; tambahkan bahwa kerja offline tidak disediakan |
| 725 | PB-07 | "Menyimpan data pada perangkat dan menyinkronkannya ketika koneksi tersedia. Mendukung pencatatan saat perangkat tidak terhubung ke internet." | **Ubah** menjadi PB-07 (revisi): "Mengirim data ke server saat koneksi tersedia, dengan antrean kiriman gagal dan pengulangan otomatis." Hapus klaim "mendukung pencatatan saat offline" |
| 746 | Use case PB-07 | skenario menyimpan ke SQLite lalu menandai perubahan belum tersinkron | Sesuaikan: pengguna mencatat → sistem **langsung** mengirim ke server → bila gagal, masukkan antrean dan coba ulang. Kriteria "data lokal" diganti "data tidak hilang saat kiriman gagal" |
| 803 | Product scope | "Penyimpanan lokal SQLite, sinkronisasi ke Turso…" | Tetap; pertegas peran SQLite |
| 853 | Tabel risiko koneksi tidak stabil | "Sistem menggunakan penyimpanan lokal dan pengulangan pengiriman" | "Sistem mengulangi pengiriman saat koneksi kembali; pencatatan baru menunggu koneksi" |

Catatan: **inferensi hama tetap lokal** (baris 346/553/647 "dijalankan secara lokal…
tanpa koneksi internet" untuk modelnya) — jangan dihapus. Yang berubah hanya sifat
**penyimpanan/pencatatan** data, bukan inferensi.

## 3. Langkah untuk SA

1. Buka `hidrosense-plan-docs/Hidrosense Plan Document.md`.
2. Sunting baris-baris pada tabel §2 sesuai usulan.
3. Pastikan **Use Case PB-07** (§746) dan **Business Requirement PB-07** (§725) tidak
   lagi menjanjikan pencatatan saat offline.
4. Pertahankan klaim inferensi model **lokal** (tanpa server) apa adanya.
5. Setelah SRS direvisi, ubah status gap **G-17** di `qa/rtm.md` dari `OPEN` →
   `RESOLVED` dan catat tanggal + versi dokumen.
6. Bila PM memilih **menyediakan** offline-first di rilis berikutnya, arah revisi
   berubah: SRS tetap, tetapi produk yang harus ditambah (kebalikan dari langkah di
   atas) — tanyakan PM dulu.

## 4. Rujukan

- Keputusan: `qa/decisions.md` — **D-14** (online-only), **D-30** (G-17 dikerjakan SA),
  **D-19** (menu Sinkron).
- Gap: `qa/rtm.md` — **G-17**, **G-18**.
- Catatan penyebaran: `qa/deployment-notes.md`.
