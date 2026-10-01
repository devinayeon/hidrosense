# Review B001/B002

Tanggal: 1 Oktober 2026. Cakupan: `apps/backend/src`, migrasi autentikasi, tes HTTP/auth, konfigurasi build, serta kontrak B001/B002. Tidak mencakup mobile atau fitur BMKG.

## Hasil dan perbaikan

Dua cacat terverifikasi pada B001/B002 telah diperbaiki pada 1 Oktober 2026.

- **B001, prioritas P1:** URL API dengan karakter terenkode, misalnya `/%61pi/v1/auth/login`, dapat melewati pemeriksaan HTTPS dan throttle karena hook membandingkan URL mentah. Hook kini mendekode path sebelum pemeriksaan. Tes produksi membuktikan login terenkode tanpa HTTPS menerima 426; tes throttle membuktikan path terenkode memakai bucket IP yang sama.
- **B002, prioritas P2:** bootstrap gagal ketika `id_user` melebihi rentang integer aman JavaScript karena SQLite mengembalikan integer sebagai number. Query `RETURNING` kini melakukan `CAST(id_user AS TEXT)`. Tes membuat ID `9007199254740992` dan memastikan bootstrap berhasil tanpa kehilangan presisi.

Implementasi tetap memakai error boundary, konfigurasi terpusat, validasi Zod, transaksi, dan vertical slice yang ada. BFRI perubahan bernilai 2 karena menyentuh boundary autentikasi; risiko diisolasi pada hook dan query bootstrap, lalu ditutup dengan tes integrasi. Tidak ada perubahan mobile, migrasi, atau kontrak API.

Pemeriksaan mengikuti alur login → hash password → sesi database → guard → refresh/logout; lalu boundary migrasi, konfigurasi, HTTPS/proxy, error, readiness, dan startup. Bukti utama:

- Login memakai parameter SQL dan verifikasi scrypt; respons tidak memuat hash password. Akun nonaktif/role tidak didukung ditolak.
- Guard membaca status, role, dan kecocokan hash kredensial saat request. Hak panen pegawai tersedia; penjualan ditolak melalui tes guard. Endpoint bisnis panen/penjualan sendiri tetap B15/B16.
- Rotasi refresh menggunakan satu UPDATE bersyarat; pengiriman bersamaan hanya mempunyai satu pemenang. Logout dan perubahan password menggugurkan sesi.
- Rate limit memakai database bersama, bukan counter lokal per proses. Proxy dipercaya hanya sesuai konfigurasi eksplisit.
- Error internal tidak membocorkan SQL atau input rahasia. Readiness menolak skema yang belum lengkap. Migrasi menguji checksum, rollback, dan preservasi data.

Ini adalah hasil review berbasis kode dan tes, bukan klaim bahwa deployment produksi atau seluruh ancaman telah diuji. Turso remote, reverse proxy produksi, beban berkelanjutan, dan integrasi mobile belum diverifikasi. Kebijakan refresh kehilangan respons memerlukan login ulang sudah dinyatakan dalam kontrak, bukan retry token lama.

## Penggunaan skill

- `backend-code-review` dari `langgenius/dify` dijalankan dengan `npx skills use`; seluruh output dibaca. Supporting files diakses relatif terhadap direktori yang diberikan CLI. Prinsip evidence-first, severity, dan penelusuran boundary diterapkan sesuai permintaan pengguna. Aturan khusus `api/`, Python/SQLAlchemy, dan PostgreSQL/MySQL tidak dipaksakan pada proyek Node.js/SQLite ini.
- `typescript-expert` dari `sickn33/agentic-awesome-skills` dijalankan dan seluruh output dibaca. Implementasi mempertahankan strict TypeScript, NodeNext/ESM, import `.js`, validasi `unknown`, serta tes runtime dan build.
- `backend-patterns` dari `affaan-m/ecc` dan `nodejs-backend-patterns` dari `wshobson/agents` dipasang melalui `npx skills add ... --skill ... -y` dan dibaca. Pola dipilih sesuai kebutuhan: validasi, parameter SQL, transaksi, shared rate limit, logging aman, dan pengujian. Tidak menambahkan framework/layer generik yang tidak diperlukan.

## Perubahan untuk B003

`authenticate` menerima `Pick<Client, 'execute'>`, sehingga guard yang sama dapat dijalankan menggunakan transaksi write. Perilaku B002 dipertahankan dan diuji ulang. Endpoint B003 mengulang autentikasi/izin di dalam transaksi, mencabut sesi atomik bersama perubahan kredensial/status, dan mempertahankan pengguna yang masih direferensikan histori. Rincian tersedia pada [breakdown B003](./backend-b003.md).
