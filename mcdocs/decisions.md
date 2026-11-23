# mcdocs/decisions.md — Keputusan & asumsi

Format: tanggal, konteks, pilihan, alasan.

## D-01 — Bekerja solo, tanpa subagent (23 Nov 2026)
- **Konteks:** PROMPT §3.1 mengizinkan delegasi opsional (Herdr + TokenHarbor High + automation).
- **Cek prasyarat:** `HERDR_ENV=1`, `herdr` tersedia, pane OpenCode aktif, tool
  `automation_create/list/delete` tersedia di sesi ini.
- **Kendala:** satu-satunya model TokenHarbor yang terdaftar adalah
  `tokenharbor/deepseek-v4.1-flash:free` (tanpa varian effort High yang bisa dipastikan).
  Skill `main-character` §11.3 melarang delegasi bila effort High tidak dapat dipastikan.
- **Pilihan:** kerjakan solo; tidak membuat pane/an automation monitor.
- **Alasan:** aturan skill lebih ketat daripada manfaat paralel; pekerjaan ini juga
  sebagian besar berurutan (baca kode → jalankan suite → analisis → tulis temuan).

## D-02 — Batas perbaikan bug: hanya front-end `apps/mobile/` (23 Nov 2026)
- **Konteks:** permintaan eksplisit client pada sesi ini.
- **Pilihan:** bug backend/DB/ML/skema dicatat lengkap di `issues.md` (+ saran perbaikan),
  **tidak** diubah. Bug di `apps/mobile/` boleh diperbaiki + regression test.
- **Alasan:** instruksi client; menjaga agar perubahan tidak melebar ke kontrak API/skema.

## D-03 — Lingkungan uji terisolasi (23 Nov 2026)
- **Konteks:** PROMPT §3.2 melarang menyentuh data produksi.
- **Pilihan:** semua uji backend memakai SQLite baru di `/tmp/opencode/hsqa/`, port 3100,
  `DATABASE_URL=file:/tmp/opencode/hsqa/...`. Tidak memakai `apps/backend/data/hidrosense.db`.
- **Alasan:** deterministik, bisa dihapus ulang, tidak menyentuh data tim.

## D-04 — Area yang belum dibangun dianggap N/A/BLOCKED, bukan FAIL (23 Nov 2026)
- **Konteks:** PROMPT mengasumsikan PB-05 (deteksi), PB-06 (rekomendasi/perawatan), dan
  backend cuaca sudah ada.
- **Fakta:** `apps/backend/API.md` menyatakan "Deteksi hama, rekomendasi, dan perawatan
  belum dibangun"; `ml/` kosong; tidak ada `.tflite`; tidak ada izin kamera; tidak ada
  folder fitur terkait.
- **Pilihan:** kriteria yang bergantung pada fitur tak ada → `N/A`/`BLOCKED` dengan alasan.
  Ketidaksesuaian laporan vs implementasi dicatat di `rtm.md` sebagai temuan dokumentasi.
- **Alasan:** PROMPT §6 dan §5.9 meminta perbedaan dokumen vs implementasi dilaporkan,
  bukan dinilai sebagai bug kode otomatis.

## A-01 — Interpretasi "pegawai boleh panen" (23 Nov 2026)
- PROMPT §6.1 mencatat inkonsistensi dokumen. Implementasi nyata:
  `common/permissions.ts` memberi pegawai `panen:read` + `panen:write`, tetapi **tidak**
  `penjualan:*`, `deteksi:*`, `rekomendasi:*`, `perawatan:*`, `cuaca:read`, `pegawai:manage`,
  `profil:*`. Asumsi QA: perilaku implementasi ini yang diuji; selisih dengan dokumen
  dicatat sebagai isu dokumentasi.

## A-02 — "HSS" & estimasi panen (23 Nov 2026)
- Server: `estimasi_panen = tanggal_pemindahan + 45 hari`; `hss` = hari sejak semai.
  Implementasi konsisten di `common/growth-rules.ts` dan salinan Dart. Diuji sesuai ini.

## A-03 — Sesi lokal disimpan plaintext di SQLite (23 Nov 2026)
- `session_store.dart` menyimpan access/refresh token sebagai teks di `session.db`.
  Ini bukan "kehilangan password" (password tidak disimpan), tetapi token adalah kredensial.
  Dicatat sebagai temuan keamanan (severity ditentukan di `issues.md`), tidak diperbaiki
  karena menyentuh desain penyimpanan (di luar perbaikan lokal aman).

## §6 — Inkonsistensi spesifikasi (diuji kedua sisi, asumsi dicatat)

Semua dinilai dari kode nyata. Selisih lengkap ada di `rtm.md` §Gap.

1. **Akses pegawai terhadap panen (§6.1).** Business Requirements & use case menyebut pegawai
   punya fitur panen; tabel *User Characteristic* & PB-01 lebih sempit. **Asumsi:** uji perilaku
   aktual. Hasil: pegawai `panen:read/write` = 200 (boleh), tetapi **ditolak** (403) untuk
   penjualan, deteksi, rekomendasi, perawatan, cuaca, dan manajemen akun. Inkonsistensi
   dokumen (G-03), bukan bug kode.
2. **"Mengarsip" vs "menonaktifkan" inventaris (§6.2).** Implementasi konsisten memakai
   `status_aktif`; UI memakai istilah arsip/nonaktif bergantian secara kosmetik. **Asumsi:**
   satu perilaku (nonaktif = `status_aktif=0`, riwayat tetap). Istilah disarankan disatukan (G-05).
3. **Siklus 60 hari vs semai tiap 10 hari (§6.3).** Sistem **tidak** mengasumsikan satu umur;
   HSS dihitung per batch dari tanggal semai. Diuji `growth-policy.test.js` & fuzz.
4. **Stok minimum tanpa kriteria notifikasi (§6.4).** Implementasi punya indikator "menipis"
   (batas `saldo < minimum`) di app, tanpa notifikasi push. **Asumsi:** diperlakukan sebagai
   fitur indikator; tanpa notifikasi = gap (bukan bug). Lihat BUG-03/BUG-06.
5. **Penyimpanan hasil deteksi wajib batch atau tidak (§6.5).** ERD `hasil_deteksi.id_pemindahan`
   NOT NULL → batch **wajib**. Fitur belum dibangun, jadi hanya asumsi skema (G-01).
6. **Tabel cuaca berisi kolom rekomendasi (§6.6).** Tabel nyata `penanganan_cuaca` hanya
   menyimpan **aturan** (rentang + rekomendasi), bukan riwayat; **0 baris** (tak di-seed) dan
   tak ada endpoint → fitur cuaca di app berjalan client-side. Konsisten dengan "tidak
   menyimpan riwayat cuaca" (G-04).
7. **Tombol "ubah" vs "konfirmasi" perawatan (§6.7).** Fitur perawatan belum dibangun; tabel
   `perawatan` hanya punya `id_rekomendasi/id_user/tanggal/catatan` (tanpa kolom bahan/obat,
   `id_rekomendasi NOT NULL`). **Asumsi:** aturan edit/koreksi perawatan belum ada; dicatat
   sebagai gap skema (G-02), tidak diubah (di luar front-end).