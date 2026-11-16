# Rework Sesi dan Serverless

Tanggal: 2026-11-04
Dasar kerja: keputusan pemilik untuk T-05 dan T-03 (produk akan serverless)
Lanjutan dari: [rework-2026-11-04.md](rework-2026-11-04.md)
Status: selesai dan teruji di lokal, **belum di-commit, belum pernah dijalankan di platform serverless atau Turso**.

## 1. Hasil

| Pemeriksaan | Hasil |
|---|---|
| `npm run check` | **289/289 lulus** (sebelumnya 270) |
| Flutter, 4 test alur backend | 5/5 lulus |
| `npm run build`, impor `dist/serverless.js` | berhasil; tidak membuka port |
| Server hasil build lewat HTTP, database file sementara | semua skenario sesuai |
| Test baru dijalankan pada kode lama | 15 dari 20 gagal dengan alasan yang benar; 5 sisanya menjaga perilaku |

Suite Flutter penuh tidak saya jalankan ulang untuk tahap ini; hasil terakhirnya 322/322, sebelum perubahan sesi.

## 2. T-05: masa berlaku sesi

| Aturan | Sebelum | Sesudah |
|---|---|---|
| Sesi aktif | Berakhir 7 hari setelah login | Berlanjut; tiap refresh memperpanjang 7 hari |
| Sesi menganggur | Berakhir 7 hari setelah login | Berakhir 7 hari setelah refresh terakhir |
| Batas mutlak | Tidak ada | 30 hari sejak login |
| Refresh token lama dipakai ulang | `401` | `401`, sesi lain dan token terbaru tetap jalan |

Kode: `SESSION_MAX_AGE_MS` di `src/common/sessions.ts` dan satu `UPDATE` di `src/features/auth/refresh.ts`, jadi refresh tetap sekali pakai walau ada request bersamaan. Tidak perlu migrasi, karena kolom `created_at` sudah ada.

**Batasan besar:** manfaat ini belum sampai ke pengguna. Aplikasi Flutter menyimpan token hanya di memori (`_access`, `_refresh` di `api_client.dart`) dan `pubspec.yaml` tidak memuat penyimpanan aman. Begitu aplikasi ditutup, pengguna harus login lagi, terlepas dari masa sesi di server. Rincian ada di [scope-vs-kode-2026-11-04.md](scope-vs-kode-2026-11-04.md).

## 3. T-03: rate limit tetap di database

Saran saya sebelumnya untuk memindahkan rate limit umum ke memori **saya batalkan**. Di serverless, tiap instance punya memori sendiri, jadi batas 120 request per menit akan berlipat sesuai jumlah instance. Limiter di database memang benar untuk kasus ini; `test/auth-infrastructure.test.js` dan dokumen B001/B002 sudah menetapkannya.

Biayanya tetap ada: satu penulisan database per request API. Dampaknya di Turso belum diukur, jadi saya tidak mengubahnya tanpa angka.

## 4. Masalah serverless yang ditemukan dan diperbaiki

### Identitas klien di balik proxy
- **Masalah:** `TRUSTED_PROXIES` hanya menerima IP tetap, yang tidak dimiliki platform serverless. Jika dikosongkan, semua request produksi kena `426 HTTPS_REQUIRED`. Jika proxy dipercaya tanpa batas, klien bisa memalsukan `X-Forwarded-For` untuk lolos dari kuota.
- **Perbaikan:** variabel baru `TRUST_PROXY_HOPS`, yang membaca alamat dari jumlah hop.
- **Teruji:** tiap klien punya kuota sendiri, pemalsuan alamat paling kiri tidak meloloskan kuota, HTTP biasa tetap `426`, kuota berlaku lintas instance, dan penyerang yang kena batas login tidak menghalangi petani di alamat lain.

### Entry point
`src/serverless.ts` mengekspor handler Node `(req, res)` tanpa `listen`.
- Satu instance hanya membuka satu app, walau request cold start datang bersamaan.
- Gagal cold start dibalas `503 NOT_READY` tanpa detail internal, lalu dicoba lagi pada request berikutnya.
- Database file ditolak, karena disk function tidak menetap.
- Produksi tanpa konfigurasi proxy ditolak saat start dengan pesan di log, bukan `426` untuk semua request.
- Handler menunggu respons selesai, karena sebagian platform membekukan instance saat handler kembali.
- Migrasi tidak dicek saat cold start. Migrasi dijalankan dari pipeline deploy, sehingga risiko `tsx` di produksi pada rework sebelumnya tidak berlaku untuk function.

### Pembersihan sesi (koreksi pekerjaan saya sendiri)
Timer per jam dari rework sebelumnya (`startAuthMaintenance`) **saya hapus beserta test-nya**, karena instance serverless bisa dibekukan di antara request. Pembersihan kini berjalan di dalam login dan refresh. Kalau pembersihan gagal, login tetap berhasil dan kegagalan hanya dicatat di log.

Batasannya: kalau tidak ada yang login atau refresh dalam waktu lama, baris kedaluwarsa menunggu sampai ada yang melakukannya. Tidak berbahaya, karena autentikasi sudah memeriksa waktu.

## 5. Bukti test baru gagal di kode lama

File: `test/session-sliding.test.js` dan `test/serverless.test.js`. Modul `src/serverless.ts` diberi stub saat itu agar file bisa dimuat.

| Test | Kegagalan di kode lama |
|---|---|
| Pengguna aktif melewati hari ke-7 | `refresh_expires_at` tidak bergeser |
| Batas 30 hari | refresh ditolak sebelum hari ke-30, jadi data sesi kosong |
| Pembersihan saat login dan refresh | baris kedaluwarsa masih ada |
| Handler dan cold start | `501 !== 200`, `501 !== 503` (stub) |
| Penolakan database lokal dan proxy kosong | `Missing expected rejection` |
| `TRUST_PROXY_HOPS` | `undefined !== 2` |
| Lima test kuota di balik proxy | `426 !== 401`, `426 !== 429` |

Lima yang lulus di kode lama menjaga perilaku yang tidak boleh berubah: sesi menganggur berakhir, token lama ditolak, refresh yang ditolak tidak memperpanjang sesi (dua test), dan pembersihan yang gagal tidak menggagalkan login.

## 6. Belum diuji

- **Turso remote:** semua test memakai SQLite lokal. Saya tidak menyentuh `.env` atau `.env.turso`.
- **Platform serverless nyata:** platform belum dipilih. Handler `(req, res)` cocok untuk platform bergaya Node seperti Vercel. AWS Lambda butuh adapter tambahan. Cloudflare Workers perlu diperiksa terpisah, karena kode memakai `node:crypto` scrypt.
- **Waktu cold start** dibanding target SRS: halaman utama kurang dari 3 detik, sinkronisasi kurang dari 1 menit.
- **Waktu scrypt di function** dengan memori kecil. Di mesin ini sekitar 150 ms; CPU function bisa jauh lebih lambat.
- `concurrency: 1` di `src/db/client.ts` berlaku juga untuk remote. Tidak saya ubah karena tidak bisa diuji tanpa Turso.

## 7. Dokumen yang diperbarui

- `docs/panduan-menjalankan-backend.md`: bagian 6 sesi login dan bagian 7 deploy serverless.
- `.env.example`, `.env.turso.example`: `TRUST_PROXY_HOPS`.
