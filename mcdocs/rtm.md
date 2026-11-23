# mcdocs/rtm.md — Requirements Traceability Matrix (PROMPT §5.9)

Sumber requirement: `hidrosense-plan-docs/Hidrosense Plan Document.md` (Business Requirements,
Backlog Fitur PB-01..PB-11 + kriteria penerimaan, use case). Kolom status memakai status test
case nyata dari `mcdocs/testing.md`.

Ringkasan: requirement yang diimplementasikan → **PASS**. Requirement yang belum dibangun →
**N/A/BLOCKED** dengan alasan. Perbedaan dokumen vs implementasi → tabel **§Gap**.

---

## 1. Business Requirements (aktor Petani)

| # | Fitur (dari dokumen) | PB | Test case | Status |
|---|---|---|---|---|
| BR-1 | Menambah/melihat/mengubah/menonaktifkan akun pegawai | PB-11 | TC-PB11-01..12 | PASS |
| BR-2 | Inventaris: tambah/lihat/ubah/arsip | PB-02 | TC-PB02-01..16 | PASS |
| BR-3 | Penyemaian: tambah/lihat/ubah | PB-03 | TC-PB03-01..10 | PASS |
| BR-4 | Notifikasi penyemaian 15 hari | PB-03 | TC-PB03-11/14 | MANUAL-PENDING |
| BR-5 | Meja tanam: tambah/lihat/ubah | PB-04 | TC-PB04-01..09 | PASS |
| BR-6 | Pertumbuhan: tambah/lihat/ubah; HSS | PB-04 | TC-PB04-10..12/18 | PASS |
| BR-7 | Tanaman rusak: tambah/lihat/ubah | PB-04 | TC-PB04-13..16 | PASS |
| BR-8 | Panen: estimasi, tambah/lihat/ubah | PB-08 | TC-PB08-01..11 | PASS |
| BR-9 | Penjualan: tambah/lihat/ubah | PB-09 | TC-PB09-01..12 | PASS |
| BR-10 | Unggah gambar untuk deteksi | PB-05 | TC-PB05-01 | N/A (tak ada kamera/model) |
| BR-11 | Lihat hasil deteksi hama | PB-05 | TC-PB05-02 | N/A |
| BR-12 | Lihat hasil rekomendasi obat | PB-06 | TC-PB06-01 | N/A |
| BR-13 | Konfirmasi data perawatan | PB-06 | TC-PB06-02/03 | BLOCKED |
| BR-14 | Lihat data perawatan | PB-06 | TC-PB06-04/05 | N/A |
| BR-15 | Rekomendasi perawatan berdasarkan cuaca | PB-10 | TC-PB10-01..12 (client) | PASS (client) |

## 2. Business Requirements (aktor Pegawai)

| # | Fitur | PB | Test case | Status |
|---|---|---|---|---|
| BR-16 | Inventaris (tambah/lihat/ubah/nonaktif) | PB-02 | TC-PB02-*, `AZ-06` | PASS |
| BR-17 | Penyemaian (tambah/lihat/ubah + notifikasi) | PB-03 | TC-PB03-*, `AZ-08` | PASS |
| BR-18 | Pertumbuhan & meja tanam (ubah status) | PB-04 | TC-PB04-*, `AZ-09` | PASS |
| BR-19 | Panen (tambah/lihat/ubah, estimasi) | PB-08 | `AZ-07` | PASS |
| BR-20 | Pegawai **tidak** akses penjualan/deteksi/perawatan/cuaca/akun | PB-01 | `AZ-01..05` | PASS |

## 3. Kriteria penerimaan Backlog (PB-01..PB-11)

| PB | Kriteria penerimaan (ringkas) | Test case | Status |
|---|---|---|---|
| PB-01 | Akses valid; pesan error; batasi pegawai; pembatasan UI **dan** pemrosesan; aturan sesi luring | TC-PB01-01..34 | PASS (1 manual) |
| PB-02 | Simpan nama/jenis/satuan/min/status; saldo akumulasi; tanpa transaksi ganda; tolak jumlah tak valid & > stok; riwayat tetap saat nonaktif | TC-PB02-01..16 | PASS |
| PB-03 | Simpan tanggal/jumlah/status; jumlah bulat positif; usia dari tanggal semai; konsistensi jumlah dipindah | TC-PB03-01..10, 12/13 | PASS |
| PB-04 | Kaitkan pindah→semai/meja; tolak > bibit/kapasitas; kaitkan rusak ke batch; tolak rusak > aktif; perbarui tanaman & kapasitas; status meja manual | TC-PB04-01..18 | PASS |
| PB-05 | Inferensi lokal offline; kelas thrips/whitefly/aphids; tampil kelas+confidence↔batch; tangani gambar invalid; **tak nyatakan bebas hama**; < 5 dtk; evaluasi mAP | TC-PB05-01..06 | N/A (belum dibangun) |
| PB-06 | Kaitkan rekomendasi↔deteksi/aturan; simpan keputusan+alasan; bedakan terima vs perawatan; riwayat dari tindakan; kurangi stok; keterangan bila kosong | TC-PB06-01..05 | N/A/BLOCKED |
| PB-07 | Data tetap setelah buka ulang; kirim ulang tak ganda; gagal sync tak hapus data; konflik multi-perangkat terdokumentasi; sync < 1 mnt | TC-PB07-01..19 | PASS (5 manual) |
| PB-08 | Kaitkan panen↔pemindahan; tolak panen > aktif; berat terpisah dari harga; konsistensi saat panen berubah | TC-PB08-01..11 | PASS |
| PB-09 | Kaitkan jual↔panen; tolak berat > hasil tersedia; nilai = berat x harga; tolak berat/harga invalid | TC-PB09-01..12 | PASS |
| PB-10 | Tampil lokasi & waktu prakiraan; pakai parameter tersedia; pastikan curah hujan numerik; tak simpan riwayat; gagal layanan tak ganggu; < 2 dtk | TC-PB10-01..14 | PASS (client) / BLOCKED (server rules) |
| PB-11 | Batasi akses data akun; tolak isian invalid; cegah escalation via profil | TC-PB11-01..13 | PASS |

## 4. Non-fungsional & lintas-area

| # | Requirement / target | Test case | Status |
|---|---|---|---|
| NFR-1 | Muat halaman utama < 3 dtk | TC-5.7-02 | MANUAL-PENDING |
| NFR-2 | Inferensi lokal per gambar < 5 dtk | TC-PB05-04 | N/A (tak ada model) |
| NFR-3 | Sinkronisasi < 1 menit | TC-PB07-19 | MANUAL-PENDING |
| NFR-4 | Pencocokan aturan cuaca < 2 dtk | TC-PB10-11 | PASS |
| NFR-5 | 12 meja x 250 = 3.000 lubang | TC-PB04-17 | PASS |
| NFR-6 | Siklus 60 hari, penyemaian tiap 10 hari (HSS per batch) | TC-PB04-12, TC-PB03-08 | PASS |
| NFR-7 | Stok dari akumulasi transaksi | TC-PB02-09 | PASS |
| NFR-8 | Rekomendasi AI = pendukung keputusan (tak otomatis) | PB-06 | N/A (belum ada) |
| NFR-9 | Status meja manual (tak auto-deteksi) | TC-PB04-08 | PASS |
| NFR-10 | Invarian §5.8 | TC-5.8-01 | PASS (638 pemeriksaan) |
| NFR-11 | Keamanan (OWASP ringkas) | TC-5.3-01..11 | PASS (2 temuan) |
| NFR-12 | Integritas DB & audit | TC-5.2-01..06 | PASS (1 temuan) |
| NFR-13 | Evaluasi model AI | TC-5.5-01 | BLOCKED |

---

## 5. §Gap — Ketidakcocokan Dokumen vs Implementasi

Ini **bukan** otomatis bug kode; ini hal yang perlu disepakati tim sebelum presentasi ke dosen.

| # | Dokumen (SRS/Plan) | Implementasi nyata | Dampak | Rekomendasi |
|---|---|---|---|---|
| G-01 | PB-05 Deteksi hama: kamera/galeri, YOLO TFLite lokal, thrips/whitefly/aphids | **Belum ada**: tak ada plugin kamera, tak ada izin CAMERA, tak ada `.tflite`; layar deteksi = mockup desain | Fitur inti judul proyek belum ada | Selesaikan model + integrasi, atau ubah klaim judul/presentasi |
| G-02 | PB-06 Rekomendasi & perawatan: rotasi golongan obat, kurangi stok, riwayat dari tindakan aktual | **Belum ada** endpoint; tabel `perawatan.id_rekomendasi NOT NULL` (perawatan tanpa rekomendasi tak bisa dicatat) dan tabel tak punya kolom bahan/obat | Kriteria "perawatan tanpa rekomendasi bisa dicatat" & "kurangi stok" tak terpenuhi di skema | Bangun fitur; bila tidak, revisi skema `perawatan` |
| G-03 | §6.1 Akses pegawai (BR & use case menyebut pegawai punya panen) | Pegawai punya `panen:read/write` tetapi **tidak** penjualan/deteksi/rekomendasi/perawatan/cuaca/akun | Inkonsistensi dokumen internal | Selaraskan BR/use case dengan matriks hak akses nyata |
| G-04 | Tabel ERD "perangkat/kondisi cuaca" memuat kolom rekomendasi | Tabel nyata `penanganan_cuaca` = **aturan** (rentang suhu/kelembapan/hujan + rekomendasi), **0 baris** (tak ada seed aturan) | Aturan cuaca server kosong; fitur cuaca hanya client-side | Seed aturan cuaca bila akan memakai backend; jika client-side, hapus tabel/orpankan |
| G-05 | "Mengarsip" vs "menonaktifkan" inventaris dipakai bergantian | Konsisten: `status_aktif`, UI memakai istilah "arsip/nonaktif" | Kebingungan istilah | Tetapkan satu istilah |
| G-06 | PB-10 actor Petani; PROMPT §4 menambahkan cek pegawai tak akses cuaca | Pegawai tidak punya `cuaca:read` (sesuai PROMPT), tak ada endpoint server | — | — (konsisten dengan PROMPT) |
| G-07 | Kriteria "confidence 0-1 dibatasi di DB" (§5.2) | `hasil_deteksi.confidence DECIMAL(5,4)` tanpa CHECK rentang | Tabel belum dipakai; risiko data tak valid bila fitur dibangun | Tambah `CHECK(confidence BETWEEN 0 AND 1)` saat fitur dibangun |
| G-08 | PB-11 "petani tak bisa menonaktifkan diri sampai nol petani" | Tak ada endpoint menonaktifkan akun **petani** (hanya pegawai) → skenario lockout tak mungkin dari API | Requirement tak dapat dilanggar/terpenuhi | Catat eksplisit atau tambahkan guard bila fitur ditambah |
| G-09 | Peta panel ERD menyebut tabel `sync_operation_receipts` | Tabel nyata bernama `sync_operations` (+`sync_changes`, `sync_id_maps`, …) | Nama berbeda dari ERD | Perbarui ERD |
| G-10 | "Penyimpanan gambar: Cloudinary" | Tidak ada integrasi Cloudinary di app | Upload gambar belum ada | Bangun bersama fitur deteksi |
| G-11 | Tabel `obat` ada; PB-06 rotasi golongan | `obat.jenis_obat` (bukan "golongan bahan aktif"); tak ada relasi riwayat | Dasar rotasi belum jelas | Definisikan kolom golongan + histori penggunaan |

## 6. Definition of Done (PROMPT §10) — cek

| # | Syarat | Status | Bukti |
|---|---|---|---|
| 1 | Semua area §4/§5 punya status nyata (tanpa kosong) | PASS | `testing.md` §2 & §3 |
| 2 | S1/S2 diperbaiki & diverifikasi, atau `NEEDS-HUMAN-REVIEW` beralasan | PASS | `issues.md` (S2 → NEEDS-HUMAN-REVIEW dengan alasan; 3 bug front-end FIXED) |
| 3 | Regresi penuh setelah perbaikan terakhir | PASS | `testing.md` §1 |
| 4 | Invarian §5.8 lulus pada jumlah iterasi tercatat | PASS | 638 pemeriksaan (`fuzz-invariants.mjs`) |
| 5 | Target kinerja diukur apa adanya | PASS | `testing.md` §4.5 + `manual_checklist.md` (perangkat) |
| 6 | RTM & dokumentasi lengkap/konsisten | PASS | dokumen ini |
| 7 | Tidak ada data/secret tertinggal; lingkungan bersih | PASS | DB uji di `/tmp`; tak ada pane/automation |
