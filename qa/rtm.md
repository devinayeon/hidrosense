# qa/rtm.md — Requirements Traceability Matrix (PROMPT §5.9)

Sumber requirement: `hidrosense-plan-docs/Hidrosense Plan Document.md` (Business
Requirements, Backlog Fitur PB-01..PB-11 + kriteria penerimaan, use case). Kolom status
memakai status test case nyata dari `qa/testing.md`.

Ringkasan: requirement yang diimplementasikan → **PASS**. Requirement yang belum
dibangun → **BLOCKED**/`N/A` dengan alasan. Perbedaan dokumen vs implementasi → tabel
**§Gap**. Diperbarui **24 November 2026** (fitur deteksi/rotasi kini dibangun).

> Perubahan besar vs versi sebelumnya: PB-05 (deteksi hama) dan PB-06 (rekomendasi &
> perawatan) **kini ada**; evaluasi model AI **tidak lagi BLOCKED**. Gap lama
> G-01/G-02/G-07/G-10/G-11 sebagian besar **RESOLVED**.

---

## 1. Business Requirements (aktor Petani)

| # | Fitur (dari dokumen) | PB | Test case | Status |
|---|---|---|---|---|
| BR-1 | Menambah/melihat/mengubah/menonaktifkan akun pegawai | PB-11 | TC-PB11-01..13 | PASS |
| BR-2 | Inventaris: tambah/lihat/ubah/arsip | PB-02 | TC-PB02-01..16 | PASS |
| BR-3 | Penyemaian: tambah/lihat/ubah | PB-03 | TC-PB03-01..10 | PASS |
| BR-4 | Notifikasi penyemaian 15 hari | PB-03 | TC-PB03-11/14 | MANUAL-PENDING |
| BR-5 | Meja tanam: tambah/lihat/ubah | PB-04 | TC-PB04-01..09 | PASS |
| BR-6 | Pertumbuhan: tambah/lihat/ubah; HSS | PB-04 | TC-PB04-10..12/18 | PASS |
| BR-7 | Tanaman rusak: tambah/lihat/ubah | PB-04 | TC-PB04-13..16 | PASS |
| BR-8 | Panen: estimasi, tambah/lihat/ubah | PB-08 | TC-PB08-01..11 | PASS |
| BR-9 | Penjualan: tambah/lihat/ubah | PB-09 | TC-PB09-01..12 | PASS |
| BR-10 | Unggah gambar untuk deteksi | PB-05 | TC-PB05-01/06 | PASS |
| BR-11 | Lihat hasil deteksi hama | PB-05 | TC-PB05-02/03/08 | PASS |
| BR-12 | Lihat hasil rekomendasi obat | PB-06 | TC-PB06-01/02 | PASS |
| BR-13 | Konfirmasi data perawatan | PB-06 | TC-PB06-03/06 | PASS (deviasi G-12) |
| BR-14 | Lihat data perawatan | PB-06 | TC-PB06-09 | PASS |
| BR-15 | Rekomendasi perawatan berdasarkan cuaca | PB-10 | TC-PB10-01..12 | PASS (client-side) |

## 2. Business Requirements (aktor Pegawai)

| # | Fitur | PB | Test case | Status |
|---|---|---|---|---|
| BR-16 | Inventaris (tambah/lihat/ubah/nonaktif) | PB-02 | TC-PB02-*, `AZ-06` | PASS |
| BR-17 | Penyemaian (tambah/lihat/ubah + notifikasi) | PB-03 | TC-PB03-*, `AZ-08` | PASS |
| BR-18 | Pertumbuhan & meja tanam (ubah status) | PB-04 | TC-PB04-*, `AZ-09` | PASS |
| BR-19 | Panen (tambah/lihat/ubah, estimasi) | PB-08 | `AZ-07` | PASS |
| BR-20 | Pegawai **tidak** akses penjualan/deteksi/rekomendasi/perawatan/cuaca/akun | PB-01 | `AZ-01..05`, `SC-*/RC-*` | PASS |

## 3. Kriteria penerimaan Backlog (PB-01..PB-11)

| PB | Kriteria penerimaan (ringkas) | Test case | Status |
|---|---|---|---|
| PB-01 | Akses valid; pesan error; batasi pegawai; pembatasan UI **dan** pemrosesan; sesi | TC-PB01-01..35 | PASS (1 manual) |
| PB-02 | Simpan atribut; saldo akumulasi; tanpa transaksi ganda; tolak tak valid & > stok; riwayat tetap | TC-PB02-01..16 | PASS |
| PB-03 | Simpan tanggal/jumlah/status; usia dari semai; konsistensi jumlah dipindah | TC-PB03-01..14 | PASS (2 manual) |
| PB-04 | Kaitkan pindah→semai/meja; tolak > bibit/kapasitas; rusak ke batch; perbarui tanaman & kapasitas | TC-PB04-01..18 | PASS |
| PB-05 | Inferensi lokal offline; thrips/whitefly/aphids; confidence↔batch; gambar invalid; **tak nyatakan bebas hama**; < 5 dtk; evaluasi mAP | TC-PB05-01..10 | PASS (1 manual: kecepatan perangkat) |
| PB-06 | Rekomendasi↔deteksi/aturan; simpan keputusan+alasan; terima ≠ perawatan; kurangi stok; pesan bila kosong | TC-PB06-01..09 | PASS + 1 deviasi (G-12) |
| PB-07 | Data tetap setelah buka ulang; kirim ulang tak ganda; gagal sync tak hapus data; konflik; sync < 1 mnt | TC-PB07-01..19 | PASS (5 manual) |
| PB-08 | Kaitkan panen↔pemindahan; tolak panen > aktif; berat terpisah harga; konsisten saat panen berubah | TC-PB08-01..11 | PASS |
| PB-09 | Kaitkan jual↔panen; tolak berat > tersedia; nilai = berat × harga; tolak invalid | TC-PB09-01..12 | PASS |
| PB-10 | Tampil lokasi & waktu; parameter tersedia; curah hujan numerik; tak simpan riwayat; gagal tak ganggu; < 2 dtk | TC-PB10-01..14 | PASS (client) / BLOCKED (aturan server) |
| PB-11 | Batasi akses akun; tolak isian invalid; cegah escalation | TC-PB11-01..13 | PASS |

## 4. Non-fungsional & lintas-area

| # | Requirement / target | Test case | Status |
|---|---|---|---|
| NFR-1 | Muat halaman utama < 3 dtk | TC-5.7-02 | MANUAL-PENDING |
| NFR-2 | Inferensi lokal per gambar < 5 dtk | TC-PB05-04 | MANUAL-PENDING (host 129,65 ms/gambar) |
| NFR-3 | Sinkronisasi < 1 menit | TC-PB07-19 | MANUAL-PENDING |
| NFR-4 | Pencocokan aturan cuaca < 2 dtk | TC-PB10-11 | PASS |
| NFR-5 | 12 meja × 250 = 3.000 lubang | TC-PB04-17 | PASS |
| NFR-6 | Siklus 60 hari, semai tiap 10 hari (HSS per batch) | TC-PB04-12, TC-PB03-08 | PASS |
| NFR-7 | Stok dari akumulasi transaksi | TC-PB02-09 | PASS |
| NFR-8 | Rekomendasi AI = pendukung keputusan (tak otomatis) | TC-PB06-08 | PASS |
| NFR-9 | Status meja manual (tak auto-deteksi) | TC-PB04-08 | PASS |
| NFR-10 | Invarian §5.8 | TC-5.8-01 | PASS (638 pemeriksaan ×3) |
| NFR-11 | Keamanan (OWASP ringkas) | TC-5.3-01..11 | PASS (2 temuan: BUG-04/05) |
| NFR-12 | Integritas DB & audit | TC-5.2-01..06 | PASS |
| NFR-13 | Evaluasi model AI | TC-5.5-01 | PASS (mAP50 0,8913; leakage 0) |

---

## 5. §Gap — Ketidakcocokan Dokumen vs Implementasi

Ini **bukan** otomatis bug kode. Status: `RESOLVED` (kini cocok), `OPEN`, `PARTIAL`.

| # | Dokumen (SRS/Plan) | Implementasi nyata | Status | Rekomendasi |
|---|---|---|---|---|
| G-01 | PB-05 deteksi hama: kamera/galeri, YOLO TFLite lokal, thrips/whitefly/aphids | **Ada**: `tflite_flutter`+`image_picker`, model `assets/ml/*.tflite`, golden paritas | RESOLVED | — |
| G-02 | PB-06 rekomendasi & perawatan: rotasi, kurangi stok, riwayat dari tindakan | Endpoint ada (rotasi MoA, potong stok). **Sisa:** `perawatan.id_rekomendasi NOT NULL` → perawatan tanpa rekomendasi tak bisa dicatat | PARTIAL | Bila perlu, izinkan perawatan mandiri (ubah skema) |
| G-03 | §6.1 Akses pegawai (BR & use case menyebut pegawai punya panen) | Pegawai `panen:read/write`; **tidak** penjualan/deteksi/rekomendasi/perawatan/cuaca/akun | OPEN | Selaraskan BR/use case dengan matriks hak akses nyata |
| G-04 | Tabel ERD cuaca memuat kolom rekomendasi | Tabel `penanganan_cuaca` = **aturan**, **0 baris**; aturan berjalan di klien | OPEN | Seed aturan bila memakai backend; jika tidak, orpankan tabel |
| G-05 | "Mengarsip" vs "menonaktifkan" inventaris | Konsisten `status_aktif`; UI bergantian istilah | OPEN | Tetapkan satu istilah |
| G-06 | PB-10 aktor Petani; PROMPT §4 cek pegawai tak akses cuaca | Pegawai tanpa `cuaca:read`; tanpa endpoint server | RESOLVED | — |
| G-07 | "confidence 0-1 dibatasi di DB" (§5.2) | `deteksi_hama.confidence_maks CHECK 0..1` (migrasi 0019) | RESOLVED | — |
| G-08 | PB-11 "petani tak bisa menonaktifkan diri sampai nol petani" | Tak ada endpoint nonaktifkan petani → skenario tak mungkin | OPEN | Catat eksplisit atau tambah guard bila fitur ditambah |
| G-09 | Peta panel ERD menyebut `sync_operation_receipts` | Tabel nyata `sync_operations` (+`sync_changes`, `sync_id_maps`) | OPEN | Perbarui ERD |
| G-10 | "Penyimpanan gambar: Cloudinary" | Endpoint unggah tanda tangan + pindaian + repo mobile ada | RESOLVED | — |
| G-11 | Tabel `obat`; PB-06 rotasi golongan bahan aktif | `obat_katalog.kode_moa` + `moa_groups`; riwayat dari `pemakaian`/perawatan | RESOLVED | — |
| G-12 | PB-06 "Menerima rekomendasi != melakukan perawatan" | `acceptRecommendation` **membuat** `perawatan` + potong stok (terima == tindakan) | OPEN (deviasi desain) | Sepakati: pertahankan, atau pisahkan "keputusan" & "tindakan" |
| G-13 | Konflik multi-perangkat terdokumentasi & konsisten | Panen/penjualan kirim `expected_version`; **semaian/stok/rusak tidak** → konflik LWW tak terdeteksi | OPEN | Tambahkan `expected_version` + guard versi |
| G-14 | Alur perbaikan non-penjualan punya resolusi konflik | Resolver konflik hanya untuk panen/penjualan; kerusakan = "coba lagi" | OPEN | Samakan alur resolusi konflik |
| G-15 | Dokumen API cocok dengan implementasi | `apps/backend/API.md:273-275` masih menyatakan potong-stok "belum dibangun" | OPEN | Perbarui §"Belum tersedia" (lihat BUG-13) |
| G-16 | Repo punya satu branch alur kerja | Branch `wild-fe` memuat seluruh produk; tes ML mengasumsikan branch khusus `ml/` | OPEN | Pisahkan branch ML/CI atau longgarkan asumsi (BUG-12) |

---

## 6. Definition of Done (PROMPT §10) — cek

| # | Syarat | Status | Bukti |
|---|---|---|---|
| 1 | Semua area §4/§5 punya status nyata (tanpa kosong) | PASS | `qa/testing.md` §2 & §3 (204 test case) |
| 2 | S1/S2 diperbaiki & diverifikasi, atau `NEEDS-HUMAN-REVIEW` beralasan | PASS | tak ada S1; S2 (BUG-04) `NEEDS-HUMAN-REVIEW` beralasan di `qa/issues.md` |
| 3 | Regresi penuh setelah perbaikan terakhir | PASS | backend 432/432; mobile 584/584 (§`testing.md` §1) |
| 4 | Invarian §5.8 lulus pada jumlah iterasi tercatat | PASS | 638 pemeriksaan ×3 run |
| 5 | Target kinerja diukur apa adanya | PASS | `testing.md` §4.5 + `manual_checklist.md` (perangkat) |
| 6 | RTM & dokumentasi lengkap/konsisten | PASS | dokumen ini |
| 7 | Tidak ada data/secret tertinggal; lingkungan bersih | PASS | DB uji di `/tmp`; kredensial Cloudinary palsu; tak ada pane/automation |
