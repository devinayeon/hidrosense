# B001 dan B002: fondasi API dan autentikasi

B001/B002 adalah nama tiga digit untuk B01/B02 pada [rencana backend](./rencana-backend.md). Implementasi hanya berada pada backend. B03 pengelolaan pegawai/profil, fitur operasional, sinkronisasi perangkat, dan BMKG masih mengikuti antrean berikutnya.

## Keputusan akses yang sudah disepakati

Arahan pengguna pada 30 September 2026 menetapkan System Request sebagai acuan: **pegawai memiliki akses panen, tetapi tidak memiliki akses penjualan**. Perbedaan PB-01/PB-08 pada dokumen sumber telah diselesaikan oleh keputusan ini. Matrix pada [kontrak API](./backend-api.md) dan kode `src/common/permissions.ts` mengikuti keputusan tersebut.

## Breakdown dan hasil

| Item | Pekerjaan | Implementasi / bukti |
| --- | --- | --- |
| B001.1 | Host HTTP dan konfigurasi | Fastify, TypeScript, validasi environment, host/port, build dan start |
| B001.2 | Health, readiness, dan shutdown | `/health/live`, `/health/ready`, pemeriksaan histori migrasi, penutupan HTTP dan database pada SIGINT/SIGTERM |
| B001.3 | Batas request dan validasi | JSON Schema pada request, penolakan field tambahan, batas body 16 KiB, timeout request, CORS allowlist, security headers |
| B001.4 | Respons dan observabilitas | Envelope sukses/error, ID request dari server, log terstruktur tanpa body/credential, error internal disamarkan |
| B001.5 | Kontrak lintas fitur | Versi `/api/v1`, matriks akses, ID string, tanggal/waktu, pagination, dan aturan representasi desimal didokumentasikan |
| B002.1 | Skema autentikasi | Migrasi `0002_auth_sessions` menambah sesi dan rate limit; tabel/data domain `0001` dipertahankan |
| B002.2 | Bootstrap pertama | CLI khusus membuat petani pertama dan dua role, hash scrypt, transaksi atomik, menolak penggantian akun lama |
| B002.3 | Login | Username/password, respons gagal seragam, verifikasi hash, hanya akun aktif dan role yang dikenal |
| B002.4 | Sesi dan refresh | Token opaque acak, hash SHA-256 pada database, access 15 menit, refresh maksimum 7 hari sejak login, rotasi atomik |
| B002.5 | Identitas dan logout | `/auth/me` mengembalikan identitas/izin aktual; logout menghapus sesi dan kedua tokennya |
| B002.6 | Otorisasi | Guard reusable membaca status, role, dan hash password terkini; tes pegawai boleh panen dan ditolak penjualan |
| B002.7 | Rate limit | Counter atomik pada database bersama; berlaku lintas proses yang memakai database sama; respons 429 dan Retry-After |
| B002.8 | Verifikasi | Tes HTTP nyata/injection, bootstrap, upgrade/down/reapply, kedaluwarsa, concurrent refresh, pencabutan, akses, throttle, HTTPS/proxy |

Semua bagian implementasi di atas tersedia. Bukti yang dijalankan untuk menyatakan tahap backend selesai: `npm run check` (typecheck, batas baris, tes) dan `npm run build`. Database Turso remote, terminasi TLS pada deployment, dan integrasi Flutter tetap memerlukan environment masing-masing; kelulusan lokal tidak menyatakan integrasi itu sudah dilakukan.

Hasil verifikasi 30 September 2026: 29 tes lulus, typecheck/build lulus, file kode terbesar 234 baris. Smoke test pada database sementara menjalankan CLI migrasi, CLI bootstrap, server hasil build, readiness, login, pembacaan identitas, logout, dan penolakan token yang sudah dicabut. Migrasi `0002_auth_sessions` juga sudah diterapkan ke database pengembangan lokal setelah backup; akun petani pada database kerja tidak dibuat otomatis. `apps/mobile` tidak berubah.

## Pilihan implementasi

- Kode API baru memakai TypeScript. Utilitas migrasi JavaScript yang sudah ada tetap dipakai dan ikut disalin ke `dist` melalui build.
- Organisasi vertical slice: satu operasi dalam satu file di `features/auth`; sesi, password, izin, error, dan throttle berada di `common`. Tidak ada tambahan lapisan repository generik.
- Sesi opaque dipilih agar logout dan pencabutan dapat diverifikasi langsung di database. Tidak memerlukan secret JWT; token memiliki 256 bit random dan tidak disimpan mentah.
- Hash password memakai scrypt `N=32768, r=8, p=3`, salt acak 16 byte, key 64 byte. Hash lama yang tidak dikenali tidak diterima sebagai password plaintext.
- Password yang berubah membatalkan sesi melalui pencocokan hash kredensial. Role dan status aktif diperiksa lagi pada setiap request yang dilindungi. Pada B03, penonaktifan akun harus sekaligus menghapus semua sesinya agar reaktivasi tidak memulihkan token lama.
- Rate limit memakai database yang sudah tersedia, sehingga tidak membutuhkan Redis untuk tahap ini. Semua replica harus memakai database pusat yang sama; file SQLite berbeda bukan counter bersama. Untuk skala lebih besar, evaluasi pemindahan throttle ke gateway/store khusus.
- Migrasi awal tidak diubah. Rollback `0002` menghapus sesi dan counter sehingga pengguna perlu login kembali; akun dan transaksi domain tetap tersimpan.
- Batas keras kode: 400 baris/file, dengan target di bawah 300. `npm run check:lines` memeriksa source, tes, helper, script, dan SQL; dependency/generated output/lockfile tidak dihitung sebagai kode yang ditulis tim.

## Aturan sesi luring

Server hanya menerima request dengan sesi aktif yang belum kedaluwarsa. Ketika perangkat terputus, backend tidak dapat mengesahkan sesi atau membuktikan status akun terkini. Penyimpanan antrean lokal dan pengalaman sesi luring termasuk B04/B17 serta implementasi mobile.

Saat koneksi pulih: bila access token kedaluwarsa, klien mencoba refresh; bila refresh gagal atau melewati tujuh hari sejak login, pengguna login ulang. Server tetap memeriksa hak akses saat operasi dikirim. Status izin yang tersimpan di perangkat tidak mengalahkan hasil pemeriksaan server. Token disimpan dalam penyimpanan aman perangkat ketika tim mobile mengintegrasikan fitur ini.

## Langkah berikutnya

B03: endpoint pengelolaan akun pegawai dan perubahan profil, menggunakan guard dan kontrak B001/B002. Tes akses panen/penjualan saat ini memakai route khusus tes; endpoint panen baru dibangun B15 dan penjualan B16. BMKG tetap B19.
