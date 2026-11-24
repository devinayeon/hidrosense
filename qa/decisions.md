# qa/decisions.md — Keputusan & asumsi (HidroSense QA)

Format: tanggal, konteks, pilihan, alasan. Diperbarui 24 November 2026.

## D-01 — Bekerja solo, tanpa subagent (23 Nov 2026)
- **Konteks:** PROMPT §3.1 mengizinkan delegasi opsional (Herdr + TokenHarbor High + automation).
- **Kendala:** satu-satunya model TokenHarbor terdaftar adalah
  `tokenharbor/deepseek-v4.1-flash:free` (tanpa varian effort High yang bisa dipastikan).
  Skill `main-character` melarang delegasi bila effort High tak dapat dipastikan.
- **Pilihan:** kerjakan solo; tidak membuat pane/an automation monitor.

## D-02 — Batas perbaikan bug (23 Nov 2026)
- **Konteks:** permintaan eksplisit client.
- **Pilihan:** bug backend/DB/ML/skema dicatat lengkap di `qa/issues.md` (+ saran), **tidak**
  diubah. Bug di `apps/mobile/` boleh diperbaiki + regression test. Skrip QA (harness/kueri
  audit) boleh diperbaiki bila terbukti salah memodelkan produk (lihat D-12).

## D-03 — Lingkungan uji terisolasi (23 Nov 2026)
- **Pilihan:** semua uji backend memakai SQLite di `/tmp/opencode/hsqa/`, port 3100,
  `DATABASE_URL=file:/tmp/opencode/hsqa/qa.db`. Tidak menyentuh `apps/backend/data/`.
- **Alasan:** deterministik, bisa dihapus, tidak menyentuh data tim.

## D-04 — ~~Area yang belum dibangun dianggap N/A/BLOCKED~~ (DIGANTIKAN, 24 Nov 2026)
- **Konteks:** sesi pertama benar bahwa PB-05/PB-06/ML belum ada.
- **Fakta baru:** backend + AI menyusul; PB-05 (deteksi) dan PB-06 (rekomendasi & perawatan)
  **kini dibangun**, model `ml` ada. Maka status "N/A/BLOCKED karena belum ada" **tidak
  berlaku lagi**; diganti hasil uji nyata (`qa/testing.md`).
- **Yang tetap BLOCKED:** sisi server PB-10 (tak ada `features/weather`, tabel aturan 0 baris)
  dan sebagian uji yang butuh perangkat.

## D-05 — Cakupan "stok menipis" mencakup semua jenis (23 Nov 2026)
- **Pilihan:** kartu "Stok menipis" di Beranda menghitung **semua jenis** barang di bawah
  minimum (termasuk habis). Daftar yang dibuka memakai cakupan sama (paritas, BUG-06).
- **Alasan:** konsistensi angka kartu vs daftar.

## D-06 — Notifikasi in-app dari data nyata; tanpa penjadwalan native (23 Nov 2026)
- **Pilihan:** ringkasan "siap pindah (HSS 15) / stok menipis" di Beranda diambil dari data
  nyata (`v2BerandaNotifikasi`). Notifikasi lokal native terjadwal **belum** ada →
  `MANUAL-PENDING` untuk PB-03 notifikasi 15 hari.

## D-07 — Konkurensi: backend aman; perbaiki hanya bug FE (23 Nov 2026)
- **Fakta:** `qa/backend-concurrency.sh` 22/22 (tulis-terakhir-menang, `409 VERSION_CONFLICT`,
  idempotensi, stok habis, 8 kiriman paralel → 1 efek). Dua bug FE buntu (BUG-09/10) diperbaiki.
- **Gap dicatat, tidak diperbaiki:** `expected_version` belum dikirim untuk semaian/stok/rusak
  (G-13); alur perbaikan non-penjualan tanpa resolver penuh (G-14).

## D-08 — Lokasi deliverable (23 Nov 2026)
- **Pilihan:** dokumen hasil uji → `qa/` (ter-track & terdorong ke git).
  Rencana/status → `mcdocs/` (`PLANS.md`, `TASKS.md`; `mcdocs/` di-gitignore).
- **Alasan:** hasil uji harus terlihat reviewer; rencana internal tidak.

## D-09 — Instal dependensi ML untuk menguji nyata (24 Nov 2026)
- **Konteks:** awalnya `ml/tests` tak jalan (dep hilang). Diinstal via `pip install --user`:
  `pytest`, `imagehash`, `opencv-python-headless`, `ai-edge-litert`, `ultralytics` (+ torch).
- **Hasil:** `python3 -m pytest ml/tests` → 165 lulus, 3 gagal (cacat harness, BUG-12).
  Model diuji ulang langsung via `ai_edge_litert` (input `[1,640,640,3]`).

## D-10 — Ambil model nyata via git-lfs (24 Nov 2026)
- **Pilihan:** pasang `git-lfs` (tanpa sudo, ke `~/.local/bin`) dan tarik artefak model asli.
- **Bukti:** sha256 `cd388bda…` cocok `model_metadata.json`; `ml/artifacts/` &
  `apps/mobile/assets/ml/` byte-identik.

## D-11 — Mode skill (24 Nov 2026)
- `antislop`: **during** (session override). `outofthebox`: **during**.
  Sub-skill outofthebox dimuat: `-qa`, `-api`, `-ai`, `-mobile`.

## D-12 — Perbaiki kueri audit QA yang salah memodelkan skema (24 Nov 2026)
- **Konteks:** fuzz §5.8 gagal pada AQ-10 ("terjual > layak") saat `berat_reject > 0`.
- **Investigasi:** `detail_panen.berat_minor` **sudah** menyimpan berat layak; kueri lama
  mengurangi reject dua kali. Produk benar (jual 2,50→201, 2,51→409).
- **Pilihan:** perbaiki AQ-09/AQ-10 di `qa/audit_queries.sql` **dan**
  `apps/backend/qa/fuzz-invariants.mjs` (QA tooling). Produk **tidak** diubah.
- **Alasan:** tes harus benar; melonggarkan assertion tanpa sebab dilarang, tetapi
  memperbaiki kesalahan model skema dengan bukti repro adalah sah (BUG-11).

## D-13 — Perawatan disatukan dengan "Terima" (24 Nov 2026)
- **Konteks:** `acceptRecommendation` membuat baris `perawatan` + memotong stok; SRS
  memisahkan "keputusan" dan "tindakan aktual".
- **Pilihan:** uji dan laporkan perilaku nyata sebagai **deviasi desain** (G-12),
  **tidak** mengubahnya (di luar batas perbaikan & berisiko tinggi).

---

## §6 — Inkonsistensi spesifikasi (diuji kedua sisi, asumsi dicatat)

Selisih lengkap ada di `qa/rtm.md` §Gap.

1. **Akses pegawai terhadap panen (§6.1).** Pegawai `panen:read/write` = 200, tetapi
   ditolak (403) untuk penjualan, deteksi, rekomendasi, perawatan, cuaca, akun.
   Inkonsistensi dokumen (G-03), bukan bug kode.
2. **"Mengarsip" vs "menonaktifkan" inventaris (§6.2).** `status_aktif` konsisten;
   istilah UI bergantian secara kosmetik (G-05).
3. **Siklus 60 hari vs semai tiap 10 hari (§6.3).** HSS per batch dari tanggal semai; tidak
   ada asumsi satu umur. Diuji `growth-policy.test.js` & fuzz.
4. **Stok minimum tanpa kriteria notifikasi (§6.4).** Ada indikator "menipis"
   (`saldo < minimum`) & ringkasan in-app, tanpa notifikasi push (gap, bukan bug).
5. **Penyimpanan hasil deteksi wajib batch atau tidak (§6.5).** `hasil_deteksi.id_pemindahan`
   NOT NULL → batch **wajib**; mobile memaksa pilih meja sebelum simpan.
6. **Tabel cuaca berisi kolom rekomendasi (§6.6).** `penanganan_cuaca` = aturan (bukan
   riwayat), 0 baris; fitur cuaca berjalan di klien (G-04).
7. **Tombol "ubah" vs "konfirmasi" perawatan (§6.7).** Perawatan dibuat lewat "Terima";
   belum ada alur edit/koreksi perawatan terpisah (G-02/G-12).
