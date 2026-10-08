# Blueprint panen dan penjualan

Status 8 Oktober 2026: rancangan sprint berikutnya. Endpoint, repository mobile, dan koneksi UI kedua domain belum diimplementasikan dalam remediasi ini. Foto dan antrean offline berada di backlog terpisah.

## Fondasi yang dipakai

Gunakan tabel `panen`, `detail_panen`, `penjualan`, dan `detail_penjualan` pada `apps/backend/migrations/0001_initial_schema.up.sql`. Indeks relasi detail/header dan detail/pemindahan atau detail/panen sudah ada. Jangan membuat ledger atau tabel domain pengganti.

Ikuti slice `features/transfers` dan `features/damage`: `index.ts`, `contracts.ts`, `store.ts`, `service.ts`, `write.ts`; pecah hanya jika file mendekati 400 baris. Gunakan Fastify, Zod strict, SQL berparameter, LibSQL write transaction, `authenticatedWrite`, dan `executeDomainMutation`. ID domain dikirim sebagai string desimal positif; `public_id` UUID dan `version` string mengikuti kontrak sync existing.

## Izin

| Domain | GET list/detail | POST |
| --- | --- | --- |
| Panen | `panen:read`: petani dan pegawai | `panen:write`: pegawai pada permissions saat ini |
| Penjualan | `penjualan:read`: petani | `penjualan:write`: petani |

Penambahan `budidaya:write` kepada petani pada remediasi ini tidak menambahkan `panen:write`. Jika petani perlu mencatat panen, perlu keputusan role terpisah. Periksa izin di route dan ulangi di `authenticatedWrite` setelah memeriksa sesi/akun dalam transaksi. `id_user` selalu dari actor; tolak field tersebut dalam body. Pegawai tetap ditolak untuk seluruh endpoint penjualan.

## Kontrak panen

- `GET /api/v1/panen`: `page`, `limit` existing (default 20, maksimum 100), filter tanggal opsional; urutan stabil tanggal lalu ID. Respons `{data, meta}`.
- `GET /api/v1/panen/:id`: header, `details`, `public_id`, `version`; 404 jika tidak ditemukan.
- `POST /api/v1/panen`: header dan detail dalam satu command; `Idempotency-Key` UUID, optional `X-Client-ID` mengikuti mekanisme create existing. Respons 201 pertama, 200 replay, `Location` menunjuk detail.

```json
{
  "tanggal_panen": "2026-10-08",
  "keterangan": "Panen meja M-01",
  "details": [
    {"id_pemindahan": "1", "jumlah_tanaman": 20, "berat": "4.25"}
  ]
}
```

Tanggal merupakan tanggal kalender valid, tidak melewati hari ini Asia/Jakarta dan tidak mendahului pemindahan setiap detail. `details` 1..100; ID pemindahan unik dalam satu command; jumlah bilangan bulat positif; berat string desimal positif maksimal dua angka pecahan dan sesuai batas penyimpanan. Keterangan optional maksimal 1000 karakter mengikuti slice budidaya.

Dalam write transaction, baca setiap pemindahan dan hitung:

`sisa = jumlah_pemindahan - SUM(kerusakan_tanaman.jumlah_tanaman) - SUM(detail_panen.jumlah_tanaman)`.

Tolak 409 jika jumlah melebihi sisa, termasuk perubahan kapasitas sejak UI dimuat. Jangan hanya menggunakan angka dari klien. Rumus ini sudah digunakan oleh `features/transfers/store.ts`, `features/tables/store.ts`, dan `features/damage/service.ts`; gunakan sumber perhitungan yang konsisten. Buat header, semua detail, identitas sync, version, dan receipt idempotensi dalam transaksi yang sama. Rollback semuanya bila satu detail gagal. Read dan write transaction harus mencegah dua writer mengonsumsi sisa yang sama.

## Kontrak penjualan

- `GET /api/v1/penjualan`: pagination existing dan filter tanggal opsional, urutan stabil.
- `GET /api/v1/penjualan/:id`: header, detail, nilai subtotal/total sebagai string desimal, identitas sync.
- `POST /api/v1/penjualan`: satu header dengan 1..100 detail, atomik; status/replay/header sama seperti panen.

```json
{
  "tanggal_penjualan": "2026-10-08",
  "keterangan": "Penjualan romaine",
  "details": [
    {"id_panen": "1", "jumlah_kg": "2.25", "harga_per_kg": "25000"}
  ]
}
```

ID panen unik per command. Tanggal tidak melewati hari ini Jakarta dan tidak mendahului tanggal panen. Berat dan harga berupa string desimal positif, maksimal dua angka pecahan, dengan batas kolom masing-masing. Total/subtotal dihitung server; klien tidak mengirim total terpercaya.

Di dalam transaksi, `kg_tersedia = SUM(detail_panen.berat) - SUM(detail_penjualan.jumlah_kg)` per header panen. Tolak 409 jika berat terjual melebihi berat tersedia. Schema saat ini menghubungkan penjualan ke header panen, sehingga transaksi menjual agregat panen tersebut. Pelacakan grade/varietas atau baris panen tertentu membutuhkan keputusan dan relasi tambahan; jangan mengarang kolom itu.

## Desimal dan transaksi

Pakai pola `common/quantities.ts`: validasi string, `toMinor`/`fromMinor`, penjumlahan/perbandingan dengan `bigint`. Hindari `Number`, REAL, dan `SUM` desimal SQLite untuk saldo berat/uang yang harus persis.

Untuk harga minor per kg dikalikan berat minor, produk mempunyai skala 10000. Tetapkan pembulatan half-up ke sen minor pada subtotal baris: `(beratMinor * hargaMinor + 50n) / 100n`. Jumlahkan subtotal baris yang sudah dibulatkan; dokumentasikan ini dalam kontrak dan tes. Gunakan formatter uang dengan batasnya sendiri: batas kuantitas `MAX_QUANTITY_MINOR` tidak otomatis cocok untuk total uang hasil perkalian. Validasi overflow sebelum INSERT dan sebelum membentuk respons.

Satu POST menggunakan satu write transaction untuk autentikasi ulang, replay lookup, validasi sisa, header/detail, sync link/version, dan receipt. Same actor + same UUID + same normalized payload mengembalikan receipt tersimpan tanpa mengurangi saldo lagi. Same UUID + payload berbeda menghasilkan 409 `OPERATION_CONFLICT`. Replay diperiksa sebelum validasi kapasitas domain, agar respons yang hilang setelah commit tetap dapat dipulihkan.

## Versioning dan migrasi yang diperlukan nanti

Tidak ada migrasi dalam remediasi saat ini. Untuk implementasi sprint berikutnya:

1. Tambahkan kolom integer exact `berat_minor`, `jumlah_kg_minor`, dan `harga_per_kg_minor`, serta subtotal uang minor bila diputuskan disimpan. Backfill data legacy yang tervalidasi; jangan melakukan konversi diam-diam dari REAL yang sudah kehilangan presisi. Audit data tidak valid dan sediakan backup sebelum migrasi.
2. Gunakan expand-contract: pertahankan kolom DECIMAL legacy saat backfill dan kompatibilitas dibutuhkan; tambahkan CHECK positif/batas (atau rebuild SQLite terkendali jika constraint membutuhkan rebuild), kemudian aktifkan pembacaan minor. Jangan mengganti schema langsung tanpa audit data.
3. Backfill `sync_resource_links` dan `sync_resource_versions` untuk header panen/penjualan legacy. Tabel sync existing menerima resource type string; tidak perlu tabel sync baru. Header menjadi aggregate root version; detail immutable berada di snapshot header. Koreksi/void di masa depan harus menaikkan version header, bukan mengubah detail tanpa receipt.
4. Indeks relasi dasar sudah tersedia. Tambahkan indeks tanggal+ID hanya setelah query plan/list contract membutuhkannya; jangan menduplikasi indeks yang ada.
5. Daftarkan resource `panen`/`penjualan` pada kontrak, dispatcher, dan filter izin sync saat dukungan sync diaktifkan. Schema sync generik saja belum berarti domain dapat disinkronkan. Header/detail mutation, versions, dan change receipt tetap atomik.

## Penerimaan sprint berikutnya

Tes meliputi permissions kedua role, anonim/nonaktif, pagination, tanggal kalender/Jakarta, ID string besar, payload strict, duplikasi detail, multi-detail rollback, konkurensi panen/kerusakan, konkurensi penjualan, berat desimal, pembulatan subtotal, overflow, replay UUID, payload conflict, legacy backfill, sync versions dan permission filtering. Mobile baru boleh dinyatakan terhubung setelah create dari UI lalu baca ulang melalui sesi baru berhasil dan saldo backend berubah tepat sekali.
