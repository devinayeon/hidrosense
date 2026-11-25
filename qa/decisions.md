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

## D-14 — Aplikasi dirancang ONLINE-ONLY (keputusan PM, 24 Nov 2026)
- **Konteks:** SRS/Plan menyebut "offline-first" (PB-07, §5.1 varian offline). PM
  memutuskan aplikasi dipakai **saat online**; ketidakmampuan mencatat/mengakses menu
  saat offline adalah perilaku wajar, **bukan bug**.
- **Dampak status uji:** test case yang mengasumsikan kerja offline diubah menjadi
  **N/A** (alasan: keputusan PM online-only, 24 Nov 2026), tanpa dihapus:
  MC-SYNC-01, MC-SYNC-02, MC-SYNC-04, MC-E2E-01, MC-E2E-02, MC-PEST-03, PB-05
  "inferensi offline" di level aplikasi, TC-5.1-02, TC-5.1-03.
- **Catatan (temuan informasi, bukan bug):** inferensi model TFLite tetap **lokal**
  (tidak butuh server), tetapi layar Deteksi hama saat ini memuat data meja/batch dari
  server, jadi membuka layar itu tetap butuh internet.
- **Dampak dokumen:** `qa/rtm.md` menambah gap baru "SRS/Plan menyebut offline-first,
  PM memutuskan online-only" (status OPEN) dan menyesuaikan catatan PB-07. Meski begitu,
  umpan balik sinkron yang salah tetap bug (BUG-21).

## D-15 — Jalur masuk v1 dinonaktifkan, kode v1 tidak dihapus (24 Nov 2026)
- **Konteks:** setelah sesi dipulihkan (app dibuka ulang), aplikasi mendarat di beranda
  v1 (`MainPage`) karena mode v2 tidak tersimpan (BUG-19).
- **Pilihan:** `AppGate` **selalu** membuka beranda v2 (`V2BerandaConnectedPage`) bila ada
  sesi; `v2UiModeProvider` tidak lagi menentukan jalur masuk. **File/kode v1 tidak
  dihapus** — hanya diputus sebagai jalur masuk (permintaan client). Galeri desain v1
  tetap bisa dirender langsung oleh tes.
- **Alasan:** v2 adalah tampilan yang dipakai mitra; v1 disimpan untuk rujukan desain.

## D-16 — Aplikasi hanya memiliki satu tema; mode gelap belum didukung (24 Nov 2026)
- **Konteks:** uji manual dev FE — mengganti tema sistem ke gelap tidak berpengaruh.
- **Investigasi:** aplikasi memang hanya memakai satu tema terang (`AppTheme.lightTheme`
  dan `V2Theme.light`); tidak ada cabang dark mode.
- **Pilihan:** catat sebagai **gap/keputusan** (bukan bug). **Tidak** menambah dark mode
  tanpa persetujuan tim (di luar lingkup & berisiko pada seluruh desain v2).
- **Pertanyaan untuk tim/PM:** apakah mode gelap diperlukan untuk rilis?
  → **Update 24 Nov 2026 (sesi 4): PM memutuskan mode gelap DITUNDA (tidak dibuat
  sekarang).**

## D-17 — Izin notifikasi belum diminta (gap, sesuai D-06) (24 Nov 2026)
- **Konteks:** uji manual dev FE di Android 13+ — izin notifikasi default ditolak dan
  aplikasi tidak pernah memintanya.
- **Fakta:** `POST_NOTIFICATIONS` dideklarasikan di manifes, tetapi tidak ada alur
  permintaan izin, dan notifikasi native belum ada (D-06).
- **Pilihan:** catat sebagai **gap**, jangan membangun fitur notifikasi sekarang.

## D-18 — Build release untuk uji LAN memakai `ALLOW_INSECURE_HTTP` (24 Nov 2026)
- **Konteks:** APK release diuji dev FE terhadap server di laptop dalam satu WiFi
  (`http://192.168.x.x:3000`), yang butuh cleartext.
- **Fakta:** `session_viewmodel.dart` menyediakan `kAllowInsecureHttp`
  (`--dart-define=ALLOW_INSECURE_HTTP=true`); default-nya **false**, sehingga build release
  normal tetap hanya menerima `https`. Perilaku ini diuji di
  `apps/mobile/test/session_insecure_http_test.dart`.
- **Pilihan:** uji perangkat memakai build dengan flag itu; **tidak** mengubah default.
- **Pertanyaan untuk tim/PM:** model penyebaran rilis — server HTTPS (cloud/TLS) atau LAN?
  Bila LAN, butuh sertifikat TLS lokal atau pengecualian cleartext terbatas.
  → **Update 24 Nov 2026 (sesi 4): PM belum memutuskan; opsi dirangkum di
  `qa/deployment-notes.md` (tetap menunggu keputusan).**

## D-19 — "Tidak ada data untuk disinkronkan" saat online adalah benar (24 Nov 2026)
- **Konteks:** uji manual dev FE — tombol "Sinkron sekarang" menampilkan "Tidak ada data
  untuk disinkronkan" baik saat offline maupun online.
- **Fakta:** sesuai D-14 aplikasi online-only. Tiap simpan langsung dikirim ke server;
  antrean sinkron hanya berisi kiriman yang **gagal** (mis. jaringan putus di tengah
  proses). Jadi antrean kosong saat online memang berarti semua data sudah di server.
- **Pilihan:** **bukan bug**; perilakunya dipertahankan. Menampilkan "Tidak ada data"
  adalah umpan balik yang jujur (BUG-21 sudah memperbaiki klaim sukses palsu).
- **Pertanyaan untuk tim/PM:** menu Sinkron dipertahankan atau disembunyikan untuk
  pengguna online-only? Bila dipertahankan, kalimat yang disarankan saat antrean kosong
  dan online: **"Semua data sudah tersimpan di server"** (lebih menenangkan daripada
  "tidak ada data"). Keputusan ini menunggu PM; belum ada perubahan kode.
  → **Update 24 Nov 2026 (sesi 4): PM masih bingung; tetap OPEN, kode tidak diubah.**

## D-20 — BUG-23 diperbaiki di sisi mobile, bukan backend (24 Nov 2026)
- **Konteks:** setelah "Setujui" rekomendasi dengan potong stok, stok di layar tidak
  berkurang sampai aplikasi di-restart.
- **Bukti:** riwayat pemakaian menampilkan "pakai 10" dan server sudah memotong stok;
  hanya tampilan mobile yang basi. Karena itu akar masalah ada di cache provider mobile.
- **Pilihan:** invalidasi `connectedInventoryProvider` setelah penerimaan berhasil yang
  memotong stok (opsi a: mobile tidak menyegarkan). Backend/DB tidak diubah.
- **Pertanyaan untuk tim/PM:** apakah potong stok dari rekomendasi memang boleh mengenai
  jenis selain `obat` (mis. `benih`)? Pada uji manual, rekomendasi mengenai benih "test"
  (100 → 90). Aturan produknya belum terdokumentasi; untuk sementara semua jenis
  diperlakukan sama seperti server.
  → **Update 24 Nov 2026 (sesi 4): DITUTUP. PM memutuskan potong stok dari rekomendasi
  hanya untuk jenis NUTRISI dan OBAT (D-29).**

## D-21 — BUG-24 adalah lanjutan BUG-20 (skala teks 200%) (24 Nov 2026)
- **Konteks:** BUG-20 (S3) sudah diperbaiki untuk Beranda/hero, Deteksi hama, Cuaca,
  Sinkron. Uji manual dev FE 24 Nov 2026 menemukan layar lain masih meluber pada font
  200% (Siklus berjalan, Siap pindah, daftar Tanaman, Detail pegawai, Ringkasan
  penjualan, Detail meja).
- **Pilihan:** catat sebagai BUG-24 (S3) yang melanjutkan BUG-20, bukan membuka ulang
  BUG-20. Pola perbaikan sama: tinggi tetap → tinggi **minimum**, teks boleh membungkus
  (`Wrap`/`Flexible`), teks di dalam bentuk tetap (cincin) diskalakan dengan
  `FittedBox`, dan tinggi area teks dihitung dari `TextPainter` bila perlu (onboarding).
- **Bukti:** `test/v2_text_scale_bug24_test.dart` merender 15 layar pada `textScaler 2.0`
  di lebar 360 dan memastikan tidak ada overflow. Audit cepat juga dijalankan untuk
  seluruh halaman v2 lain (hasil bersih) — tetapi verifikasi visual di HP asli tetap
  tugas dev FE.

## D-22 — Segmen awal tab Tanam bersifat sekali pakai (BUG-25) (24 Nov 2026)
- **Konteks:** kartu "Lubang terisi" membuka Tanam → Meja. Setelah itu, mengetuk tab
  Tanam selalu membuka Meja (segmen tersimpan), padahal default-nya Semaian.
- **Pilihan:** segmen awal dari kartu hanya dipakai sekali. Setiap ketukan langsung ke
  tab Tanam mereset segmen ke Semaian (0), dan pergantian peran juga mereset. Perilaku
  di dalam tab (pengguna memilih Meja sendiri) tidak diubah.
- **Alasan:** konsisten dengan tab Stok yang sudah mereset saringan saat diketuk langsung
  (BUG-06). Tidak mengubah desain kartu maupun urutan segmen.

## D-23 — Notifikasi in-app: dibaca/belum, ketuk buka tujuan, simpan lokal (BUG-30) (24 Nov 2026)
- **Konteks:** halaman "2.4 Notifikasi" hanya menampilkan baris; tidak ada status dibaca,
  baris tidak bisa ditekan, dan "Tandai semua dibaca" selalu aktif. Tanpa push native
  (D-06/D-17), notifikasi ini murni in-app.
- **Pilihan:**
  1. **Dibaca/belum** ditandai penanda **bukan warna** (titik bentuk + label semantik
     "Belum dibaca"), supaya tetap terbaca tanpa membedakan warna.
  2. **Ketuk baris** = tandai dibaca + tutup halaman + buka tujuan relevan. Halaman hanya
     mengembalikan `V2NotificationTarget`; Beranda yang tahu indeks tab lalu berpindah
     (Semaian → tab Tanam, Stok → tab Stok + saringan "Menipis").
  3. **"Tandai semua dibaca"** nonaktif saat tidak ada yang belum dibaca.
  4. **Status disimpan lokal per pengguna** dengan **id stabil** (`semaian-<id>`,
     `stok-menipis`) di `notification_read.db`, terpisah per alamat layanan.
  5. Tanpa push native (tetap D-06/D-17).
- **Alasan:** notifikasi dibangun ulang dari data tiap kali Beranda dibuka, jadi status
  harus disimpan terpisah dengan kunci stabil. Ketukan yang membuka tab relevan
  menghilangkan "jalan buntu" pada baris.

## D-24 — Riwayat rotasi: entri bisa dilipat, filter dibungkus (BUG-32) (24 Nov 2026)
- **Konteks:** filter riwayat rotasi terlalu rapat (meluber pada skala teks 2.0) dan
  daftarnya terasa sangat panjang.
- **Pilihan:** filter dibungkus (`Wrap`) dengan jarak token; **tiap entri bisa dilipat**
  (tertutup = ringkasan, terbuka = rincian), bukan satu dropdown besar untuk seluruh
  daftar. Tombol lipat ≥ 48dp dengan label teks + ikon (bukan warna saja).
- **Alasan:** per-entri menjaga konteks baris yang sedang dibaca dan tidak menyembunyikan
  seluruh riwayat sekaligus. Alternatif pengelompokan per tanggal tetap terbuka bila PM
  menilai lebih baik.

> **Update 24 Nov 2026 (sesi 4):** PM **menyetujui** D-23 dan D-24. PM menilai
> pengelompokan riwayat rotasi **per tanggal** lebih bagus → jadi fitur tambahan (D-28),
> entri di bawah header tetap bisa dilipat.

## D-25 — "Tambah tanaman" mengarah ke form "Pindah ke meja", bukan mengisi langsung (BUG-35) (24 Nov 2026)
- **Konteks:** dari Beranda → Siklus berjalan → Detail meja → "Tambah tanaman", meja
  langsung terlihat terisi penuh, tetapi setelah kembali data tidak tersimpan/basi.
- **Pilihan (permintaan dev FE):** "Tambah tanaman" **tidak** mengisi langsung. Tombol
  membuka form **Pindah ke meja** dengan default menyesuaikan konteks: meja terpilih =
  meja tersebut, semaian terpilih = semaian yang dipilih, jumlah default =
  `min(sisa bibit, sisa kapasitas meja)`. Penyimpanan lewat alur pindah yang sudah ada.
- **Alasan:** satu jalur tulis (pindah) menghindari logika tulis kedua yang menyebabkan
  data basi; form pindah sudah menangani kapasitas, validasi, dan sinkron.

## D-26 — Kontrak bahan penyemaian (BUG-38) (24 Nov 2026)
- **Konteks:** tombol "Tambah bahan" di form Tambah semaian hanya mengganti bahan, tidak
  menambah baris kedua.
- **Hasil audit kontrak server** (`apps/backend/API.md`, `POST /penyemaian`): endpoint
  menerima **`materials[]`** — minimal **satu** baris, tiap baris punya `id_inventaris`
  yang **unik** dalam satu kiriman. Jadi server **sudah mendukung banyak bahan**;
  masalahnya murni di mobile yang hanya mengirim satu bahan. **Backend tidak diubah.**
- **Keputusan:** "Tambah bahan" **menambah baris** (bukan mengganti). Form semaian
  multi-baris: pilih/hapus baris, bahan yang sudah terpakai tidak ditawarkan lagi,
  galat stok per baris; saat simpan, semua baris dikirim sebagai `materials[]`.
- **Alasan:** menyesuaikan UI dengan kontrak server yang sudah ada, tanpa perubahan
  backend.

## D-27 — Urutan daftar meja di form "Pindah ke meja" (Fitur-2) (24 Nov 2026)
- **Konteks:** BUG-29 menanyakan urutan daftar meja. **PM menjawab: BOLEH diubah.**
- **Pilihan:** urutkan **meja tersedia dulu**, lalu **sisa lubang kosong terbanyak**, lalu
  **kode meja**. Meja **penuh/perawatan diletakkan di bawah** dan tetap **disabled**.
- **Alasan:** meja yang paling siap dipakai muncul lebih dulu; meja penuh tidak lagi
  menghalangi di atas.

## D-28 — Riwayat rotasi dikelompokkan per tanggal (Fitur-1) (24 Nov 2026)
- **Konteks:** PM menilai pengelompokan per tanggal lebih bagus daripada daftar datar.
- **Pilihan:** kelompokkan riwayat rotasi **per tanggal WIB** (header tanggal), entri di
  bawah header **tetap bisa dilipat** seperti D-24. Aman pada skala teks 2.0.
- **Alasan:** memudahkan membaca riwayat berdasarkan hari; melanjutkan D-24 tanpa
  membuang fitur lipat.

## D-29 — Potong stok dari rekomendasi hanya untuk jenis NUTRISI dan OBAT (menutup D-20) (24 Nov 2026)
- **Konteks:** D-20 menanyakan apakah potong stok rekomendasi boleh mengenai jenis selain
  `obat` (mis. `benih`).
- **Keputusan PM:** potong stok dari rekomendasi **hanya** untuk jenis **nutrisi** dan
  **obat**. Saat "Setujui" dengan potong stok, daftar barang yang ditawarkan **hanya**
  barang berjenis nutrisi/obat; jenis lain (mis. benih) **tidak** ditawarkan. Mobile saja;
  server tidak diubah. Bila tidak ada barang yang cocok, tampilkan pesan jelas.
- **Alasan:** membatasi efek samping stok ke jenis yang memang dipakai perawatan.

## D-30 — Keputusan PM lain (sesi 4) (24 Nov 2026)
- **D-23/D-24:** disetujui PM (lihat update di atas).
- **D-16 (mode gelap):** untuk sementara **ditunda** (tidak dibuat).
- **D-19 (menu Sinkron):** PM masih bingung → **tetap OPEN**, kode tidak diubah.
- **D-18 (TLS/LAN):** PM belum memutuskan → **cukup didokumentasikan** di
  `qa/deployment-notes.md` (tetap menunggu keputusan).
- **G-17 (SRS offline-first → online-only, D-14):** **SA** yang merevisi SRS → panduan
  revisi dibuat di `qa/srs-revision-guide.md`.

## D-31 — Pencocokan jenis potong stok pakai pengenal stabil / kata kunci (BUG-46) (25 Nov 2026)
- **Konteks:** Fitur-3 (D-29) hanya menawarkan stok berjenis "nutrisi"/"obat". Di data
  nyata nama jenis bisa berbeda (mis. seed backend memakai **"Obat & Pestisida"**), jadi
  pencocokan nama persis membuat obat tidak pernah muncul (BUG-46).
- **Keputusan:** jangan menebak atau mengganti nama jenis di server. Barang inventaris
  yang punya **`id_obat`** (pengenal stabil) dianggap obat; untuk sisanya, nama jenis
  dicocokkan per **kata kunci** (`nutrisi`, `obat`, `pestisida`), bukan sama persis.
  Backend **tidak** diubah; hanya `apps/mobile/`.
- **Alasan:** mengandalkan pengenal stabil lebih tahan terhadap variasi ejaan nama jenis,
  sementara kata kunci menutup barang nutrisi/obat yang belum tertaut katalog obat.

## D-32 — Filter rentang tanggal WIB di Riwayat rotasi (Fitur-4, melengkapi D-28) (25 Nov 2026)
- **Konteks:** dev FE menilai Riwayat rotasi (Fitur-1) perlu filter rentang tanggal,
  bukan hanya filter status/hama/meja.
- **Pilihan:** tambahkan filter **dari–sampai** (inklusif) berbasis **tanggal WIB** yang
  sama dengan pengelompokan D-28, berdampingan dengan filter lama dan pengelompokan
  header tanggal. Sediakan tombol **hapus filter**; bila rentang mengosongkan daftar,
  tampilkan pesan netral ("Tidak ada riwayat pada rentang tanggal ini") + tombol hapus.
  Filter berjalan **di layar** lewat `saringRiwayatTanggal`; server tidak diubah.
- **Alasan:** batas inklusif + tanggal WIB konsisten mencegah entri tengah malam masuk
  kelompok yang salah. Aman pada skala teks 2.0.

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
