# B005 — Master inventaris

Tanggal: 1 Oktober 2026. Cakupan backend: `jenis_inventaris`, `obat`, dan `inventaris`. Mobile dan BMKG tidak berubah.

## Review prasyarat B000–B004

- B000: migrasi versi, checksum, rollback, FK, dan backup menjadi dasar migrasi `0004_inventory_master`.
- B001: error envelope, validasi ketat, pagination, ID string, dan desimal string dipertahankan.
- B002–B003: petani hanya membaca inventaris; pegawai membaca dan menulis. Status dan izin actor diperiksa ulang di transaksi write.
- B004: review menemukan endpoint generik dapat membuat receipt sukses tanpa perubahan bisnis. Endpoint dibatasi menjadi `sync.reserve-id`; seluruh write B005 mengeksekusi perubahan dan receipt secara atomik.

## Implementasi

- Jenis inventaris: tambah, daftar berhalaman/filter status, detail, ubah, nonaktifkan.
- Obat: tambah, daftar berhalaman/filter status, detail, ubah, nonaktifkan.
- Inventaris: tambah, daftar berhalaman/filter status, detail, ubah, nonaktifkan.
- Jenis dan obat nonaktif tetap terbaca untuk histori, tetapi ditolak pada referensi inventaris baru atau perubahan referensi.
- `stok_minimum` divalidasi dan dikirim sebagai string desimal tanpa konversi floating point JavaScript.
- Semua write menerima `Idempotency-Key` UUID. Jika tidak diberikan, server membuat key untuk request tunggal. Replay key dan payload sama tidak mengulang mutasi; isi berbeda memberi `409 OPERATION_CONFLICT`.

## Migrasi dan verifikasi

Migrasi `0004_inventory_master` menambah `jenis_inventaris.status_aktif` dengan default aktif dan index status. Down migration menghapus index dan kolom tersebut.

Tes mencakup CRUD, hak akses, validasi, pagination, deaktivasi dan histori, referensi nonaktif, desimal string, replay atomik, konflik key, serta regresi sinkronisasi. Jalankan `npm run check` dan `npm run build` dari `apps/backend`.

Tahap berikutnya: B006, ledger stok masuk/keluar dan saldo atomik.

Migrasi `0005_sync_resource_links` mengikat UUID publik pada ID domain yang tetap dipertahankan dan memberi versi awal 1 untuk record lama. Down mempertahankan tabel/record domain tetapi menghapus metadata identitas/versi yang ditambahkan; penerapan ulang setelah rollback menghasilkan UUID baru. Receipt domain lama tetap dikembalikan persis seperti tersimpan, termasuk jika belum memuat metadata versi. Migrasi baru diverifikasi pada database pengujian, belum diterapkan ke database deployment atau Turso remote.

## Koreksi audit dan refactor 2 Oktober 2026

Audit lintas B001–B005 menggantikan kesimpulan review awal “No issues found”. Receipt atomik sudah tersedia, tetapi B005 belum mengikat identitas publik dan versi resource; dokumentasi API juga belum memenuhi kontrak lengkap. Refactor ini menutup kedua kekurangan tersebut.

Create mengikat record domain pada UUID publik, menerima UUID klien opsional, dan menolak create baru terhadap UUID klien yang sudah terikat. Update/deactivate mempertahankan UUID publik serta menaikkan versi resource. Receipt menyimpan UUID publik dan versi hasil mutasi sehingga replay mengembalikan hasil asli tanpa menaikkan versi. Mapping, perubahan domain, versi, dan receipt berada dalam satu transaksi.

Batas autentikasi write menyatukan pemeriksaan sesi/izin di transaksi, commit, dan rollback. Interface sinkronisasi menyembunyikan hashing, receipt, mapping, serta versi dari handler domain. Registrasi fitur dan primitive validasi transport dipusatkan untuk mengurangi duplikasi. Kontrak request/response, PATCH, contoh, dan error per endpoint tersedia di [API inventaris](backend-inventory-api.md).

Artefak `apps/**/graphify-out/` diabaikan Git tanpa menghapus file lokal. Graph root tetap menjadi sumber pengetahuan proyek. Validasi refactor mencakup kompatibilitas autentikasi, CRUD, rollback, UUID klien, identitas/versi resource, replay, dan konflik. Jumlah tes final mengikuti hasil `npm run check` pada eksekusi refactor ini; angka 67 merupakan baseline sebelum refactor.
