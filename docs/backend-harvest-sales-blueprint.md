# Blueprint panen dan penjualan

Status 10 Oktober 2026: backend dan mobile panen telah diimplementasikan. UI HTTP terisolasi dan AVD membuktikan pencatatan dua batch, pembacaan ulang melalui sesi baru, serta koreksi berat/catatan. Bukti dan batas verifikasi ada pada [laporan remediasi](reviews/harvest-remediation-2026-10-10.md). Penjualan tetap blueprint sprint berikutnya. Foto, PDF, harga estimasi, hitungan ikat/pcs, offline queue, dan retry lintas restart menjadi backlog.

## Fondasi yang dipakai

Gunakan tabel `panen`, `detail_panen`, `penjualan`, dan `detail_penjualan` pada `apps/backend/migrations/0001_initial_schema.up.sql`. Indeks relasi detail/header dan detail/pemindahan atau detail/panen sudah ada. Jangan membuat ledger atau tabel domain pengganti.

Ikuti slice `features/transfers` dan `features/damage`: `index.ts`, `contracts.ts`, `store.ts`, `service.ts`, `write.ts`; pecah hanya jika file mendekati 400 baris. Gunakan Fastify, Zod strict, SQL berparameter, LibSQL write transaction, `authenticatedWrite`, dan `executeDomainMutation`. ID domain dikirim sebagai string desimal positif; `public_id` UUID dan `version` string mengikuti kontrak sync existing.

## Izin

| Domain | GET list/detail | POST/PATCH |
| --- | --- | --- |
| Panen | `panen:read`: petani dan pegawai | `panen:write`: petani dan pegawai |
| Penjualan | `penjualan:read`: petani | `penjualan:write`: petani |

Petani kini memiliki `panen:write`; izin Pegawai existing dipertahankan. Periksa izin di route dan ulangi di `authenticatedWrite` setelah memeriksa sesi/akun dalam transaksi. `id_user` selalu dari actor; tolak field tersebut dalam body. Pegawai tetap ditolak untuk seluruh endpoint penjualan.

## Kontrak panen

- `GET /api/v1/panen`: `page`, `limit` existing (default 20, maksimum 100); urutan tanggal lalu ID menurun. Respons `{data, meta}` berisi snapshot lengkap. Filter tanggal belum tersedia.
- `GET /api/v1/panen/:id`: header, `details`, `public_id`, `version`; 404 jika tidak ditemukan.
- `POST /api/v1/panen`: header dan detail dalam satu command; `Idempotency-Key` UUID, optional `X-Client-ID` mengikuti mekanisme create existing. Respons 201 pertama, 200 replay, `Location` menunjuk detail.
- `PATCH /api/v1/panen/:id`: `expected_version`, catatan opsional, serta detail koreksi berat berdasarkan `id_detail_panen`; respons 200. Tanggal, batch, dan jumlah tanaman immutable. GET list/detail memakai read transaction untuk snapshot konsisten.

```json
{
  "tanggal_panen": "2026-10-10",
  "keterangan": "Panen meja M-01",
  "details": [
    {"id_pemindahan": "1", "jumlah_tanaman": 20, "berat_total": "4.25", "berat_reject": "0.25"}
  ]
}
```

Tanggal kalender valid berada antara tanggal pemindahan seluruh batch dan hari ini Jakarta, menggunakan clock injeksi. `details` 1..100; ID pemindahan unik; jumlah integer 1..1.000.000. Berat total positif, reject 0..total, maksimal 99.999.999,99 kg per detail dengan dua pecahan bertitik pada wire. Tolak whitespace, eksponen, NaN, infinity, serta field tambahan. Catatan trim maksimal 1000 karakter; kosong/null mengosongkan catatan.

```json
{
  "expected_version": "1",
  "keterangan": null,
  "details": [{"id_detail_panen": "1", "berat_total": "4.50", "berat_reject": "0.25"}]
}
```

PATCH menerima detail milik header, dengan berat total/reject bersama. Berat layak = total - reject. Agregat layak tidak boleh di bawah berat terjual yang sudah tercatat; jumlahkan setiap desimal penjualan tervalidasi dengan BigInt, bukan floating-point SUM. Konflik 409: `HARVEST_EXCEEDS_ACTIVE_PLANTS`, `HARVEST_WEIGHT_BELOW_SOLD`, `HARVEST_VERSION_CONFLICT`. Nilai penjualan legacy ambigu juga menghentikan koreksi. Seluruh tanaman dipanen mengurangi tanaman aktif; reject kg merupakan sortasi, bukan laporan kerusakan tanaman tambahan.

Mobile mengirim UUID idempotensi; server tetap menerima klien lama tanpa header. Lookup replay mendahului pemeriksaan saldo/version. Body limit POST/PATCH panen 64 KB mendukung 100 detail; batas global tetap 16 KB.

Dalam write transaction, baca setiap pemindahan dan hitung:

`sisa = jumlah_pemindahan - SUM(kerusakan_tanaman.jumlah_tanaman) - SUM(detail_panen.jumlah_tanaman)`.

Tolak 409 jika jumlah melebihi sisa, termasuk perubahan kapasitas sejak UI dimuat. Jangan hanya menggunakan angka dari klien. Rumus ini sudah digunakan oleh `features/transfers/store.ts`, `features/tables/store.ts`, dan `features/damage/service.ts`; gunakan sumber perhitungan yang konsisten. Buat header, semua detail, identitas sync, version, dan receipt idempotensi dalam transaksi yang sama. Rollback semuanya bila satu detail gagal. Read dan write transaction harus mencegah dua writer mengonsumsi sisa yang sama.

## Kontrak penjualan (belum diimplementasikan)

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

Di dalam transaksi, gunakan saldo layak integer `detail_panen.berat_minor` dikurangi jumlah penjualan minor per header panen. Tolak 409 jika berat terjual melebihi berat tersedia. Schema saat ini menghubungkan penjualan ke header panen, sehingga transaksi menjual agregat panen tersebut. Pelacakan grade/varietas atau baris panen tertentu membutuhkan keputusan dan relasi tambahan; jangan mengarang kolom itu.

## Desimal dan transaksi

Pakai pola `common/quantities.ts`: validasi string, `toMinor`/`fromMinor`, penjumlahan/perbandingan dengan `bigint`. Hindari `Number`, REAL, dan `SUM` desimal SQLite untuk saldo berat/uang yang harus persis.

Untuk harga minor per kg dikalikan berat minor, produk mempunyai skala 10000. Tetapkan pembulatan half-up ke sen minor pada subtotal baris: `(beratMinor * hargaMinor + 50n) / 100n`. Jumlahkan subtotal baris yang sudah dibulatkan; dokumentasikan ini dalam kontrak dan tes. Gunakan formatter uang dengan batasnya sendiri: batas kuantitas `MAX_QUANTITY_MINOR` tidak otomatis cocok untuk total uang hasil perkalian. Validasi overflow sebelum INSERT dan sebelum membentuk respons.

Satu POST menggunakan satu write transaction untuk autentikasi ulang, replay lookup, validasi sisa, header/detail, sync link/version, dan receipt. Same actor + same UUID + same normalized payload mengembalikan receipt tersimpan tanpa mengurangi saldo lagi. Same UUID + payload berbeda menghasilkan 409 `OPERATION_CONFLICT`. Replay diperiksa sebelum validasi kapasitas domain, agar respons yang hilang setelah commit tetap dapat dipulihkan.

## Migrasi panen tersedia; migrasi penjualan berikutnya

Migrasi aditif `0011_harvest_weights` menambah `berat_minor` (layak, skala 100), `berat_reject_minor` nullable, dan indeks tanggal/ID. Kolom `berat` tetap saldo layak kompatibel. Backfill serta identitas/version panen legacy berjalan dalam transaksi migrasi existing. Desimal divalidasi bersama SQL roundtrip untuk mendeteksi CAST SQLite yang menyembunyikan presisi REAL; nilai ambigu/tidak valid membatalkan seluruh migrasi tanpa pembulatan/koreksi SQL otomatis. Reject legacy tetap null; total/reject ditampilkan belum tercatat. Koreksi berat memerlukan total/reject bersama; catatan saja dapat diubah tanpa merekayasa sortasi.

Urutan rollout: backup/audit, migrasi, backend, mobile. Down memerlukan `allowDataLoss` existing dan menghapus kolom minor/identitas panen; jangan rollback saat mobile baru masih memakai kontrak ini. Untuk penjualan sprint berikutnya:

1. Tambahkan kolom integer exact `jumlah_kg_minor` dan `harga_per_kg_minor`, serta subtotal uang minor bila diputuskan disimpan. Backfill data legacy yang tervalidasi; jangan melakukan konversi diam-diam dari REAL yang sudah kehilangan presisi. Audit data tidak valid dan sediakan backup sebelum migrasi.
2. Gunakan expand-contract: pertahankan kolom DECIMAL legacy saat backfill dan kompatibilitas dibutuhkan; tambahkan CHECK positif/batas (atau rebuild SQLite terkendali jika constraint membutuhkan rebuild), kemudian aktifkan pembacaan minor. Jangan mengganti schema langsung tanpa audit data.
3. Backfill identitas/version penjualan legacy. Panen sudah memiliki identitas/version melalui migrasi dan mutasi HTTP; PATCH menaikkan version aggregate header dan receipt secara atomik. Tabel sync existing menerima resource type string; tidak perlu tabel sync baru.
4. Indeks relasi dasar sudah tersedia. Tambahkan indeks tanggal+ID hanya setelah query plan/list contract membutuhkannya; jangan menduplikasi indeks yang ada.
5. Daftarkan resource `panen`/`penjualan` pada kontrak, dispatcher, dan filter izin sync saat dukungan sync diaktifkan. Schema sync generik saja belum berarti domain dapat disinkronkan. Header/detail mutation, versions, dan change receipt tetap atomik.

## Estimasi dan penerimaan

Estimasi memakai batch aktif nyata, backend semai +45 hari, HSS/HST, dan sisa tanaman. Tidak ada proyeksi berat/grade tanpa sumber. Estimasi bukan record panen atau kepastian tanggal; create memakai ID batch nyata. Refresh usia pada tengah malam Jakarta/resume. State mobile mengikuti sesi/server dan menggabungkan receipt sebelum refresh; refresh gagal tetap dilabeli tersimpan. Request belum pasti memakai payload/UUID yang sama selama proses hidup. Offline queue dan retry lintas restart belum tersedia.

Backend panen: `npm run check` 230/230 lulus, termasuk 16 regresi panen/migrasi, typecheck, dan batas 400 baris. UI HTTP memverifikasi dua detail, tiga receipt berbeda, version 3, berat layak 4,00 menjadi 4,50 kg, pengosongan catatan, serta jumlah tanaman dan kapasitas yang tetap setelah koreksi. Capture AVD dan telemetry akhir dicatat pada laporan remediasi.

Tes panen yang tersedia meliputi permissions kedua role, anonim/nonaktif, pagination, tanggal kalender/Jakarta, ID string besar, payload strict, duplikasi detail, multi-detail rollback, konkurensi panen/kerusakan, berat desimal, replay UUID, payload conflict, legacy backfill, dan version/receipt atomik. UI HTTP dan AVD memenuhi bukti create lalu baca ulang melalui sesi baru dengan perubahan saldo tepat sekali. Penerimaan penjualan sprint berikutnya masih harus menambah konkurensi penjualan, pembulatan subtotal uang, overflow, serta dispatcher/filter izin sync domain tersebut; hal ini belum menjadi bukti endpoint penjualan tersedia.
