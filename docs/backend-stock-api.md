# Kontrak API Stock Ledger B006

Tanggal: 3 Oktober 2026, Asia/Jakarta. Kontrak berlaku sesudah migrasi `0006_stock_ledger`. [PRD](b006/prd-stock-ledger.md), [arsitektur](b006/architecture-stock-ledger.md), dan [bukti implementasi](backend-b006.md) menjelaskan keputusan serta batas verifikasinya.

Semua endpoint memakai Bearer access token. Petani dan pegawai memiliki `inventaris:read`; hanya pegawai memiliki `inventaris:write`. Write dan replay memeriksa sesi/izin terkini di dalam transaksi. Envelope error mengikuti [kontrak HTTP bersama](backend-api.md).

## Endpoint

| Method | Path | Izin | Respons |
| --- | --- | --- | --- |
| POST | `/api/v1/stok` | `inventaris:write` | 201 movement baru; 200 receipt replay; `Location` menunjuk movement |
| POST | `/api/v1/stok/:id/reverse` | `inventaris:write` | 201 reversal; 200 replay; `Location` menunjuk reversal |
| GET | `/api/v1/stok` | `inventaris:read` | 200 `{data: Movement[], meta}` |
| GET | `/api/v1/stok/:id` | `inventaris:read` | 200 `{data: Movement}`; 404 jika tidak ditemukan |
| GET | `/api/v1/inventaris/:id/saldo` | `inventaris:read` | 200 `{data: Balance}`; 404 jika barang tidak ditemukan |

## Write dan retry

`Idempotency-Key` wajib berupa UUID; teks/casing key dipertahankan dalam namespace aktor. `X-Client-Id` opsional berupa UUID dan dinormalisasi lowercase. Client menyimpan key, client ID dan payload sebelum kirim, lalu mempertahankannya pada retry. Payload kanonis menormalkan desimal, trim satuan/keterangan, mengurutkan detail berdasarkan ID numerik, dan menyamakan keterangan absen dengan null.

Respons write/replay: `{data: Movement, operation, replayed}`. `operation` mengikuti receipt B004. Receipt menyimpan hasil asli; replay tidak menambah ledger, mengurangi saldo, atau menaikkan versi. Replay tetap dapat berhasil setelah barang dinonaktifkan, selama sesi dan izin saat ini valid. Key sama dengan isi/jenis operasi/client identity berbeda menghasilkan 409 `OPERATION_CONFLICT`.

Body create berikut menunjukkan dua detail dengan item berbeda:

```json
{
  "jenis_stok": "masuk",
  "details": [
    {"id_inventaris": "1", "jumlah": "0.25", "satuan": "kg"},
    {"id_inventaris": "2", "jumlah": "2", "satuan": "botol"}
  ],
  "keterangan": "Penerimaan bahan"
}
```

`jenis_stok` hanya `masuk` atau `keluar`. `details` berisi 1–100 item unik. ID adalah string integer positif signed64. `jumlah` berupa string desimal positif `0.01..9999999999.99`, maksimal dua angka pecahan; angka JSON, eksponen, tanda, spasi, tiga pecahan dan newline ditolak. Tidak ada pembulatan atau konversi satuan. Semua satuan memakai skala 100. `satuan` trim 1–30 karakter, case sensitive, harus sama dengan master. Keterangan opsional/null atau string trim 1–1000 karakter. Field tambahan dan query pada write ditolak.

Barang harus aktif untuk create. Seluruh detail, saldo, header, UUID/version dan receipt commit atau rollback bersama. Saldo tidak boleh negatif maupun melampaui batas. Master satuan terkunci sejak memiliki riwayat, termasuk sesudah saldo nol atau reversal.

Body reversal hanya `{"keterangan":"Alasan koreksi"}`; alasan wajib. Reversal membuat movement baru dengan arah berlawanan, jumlah/satuan identik, dan `reversal_of` menunjuk original. Original tetap utuh. Satu original hanya dapat dibalik sekali; reversal tidak dapat dibalik lagi. Barang tidak aktif boleh dibalik jika saldo memenuhi aturan. Membalik pemasukan yang sudah terpakai dapat gagal karena saldo tidak mencukupi.

Koreksi dilakukan sebagai reversal, lalu movement pengganti dengan key baru. Keduanya operasi terpisah: jika pengganti gagal, reversal tetap tercatat. Client mencantumkan ID original dan reversal dalam keterangan pengganti; tidak ada relasi replacement yang dipaksakan server. Link penyemaian/perawatan tidak diterima pada API manual; koreksinya harus melalui domain pemilik pada fase berikutnya.

503 `STOCK_WRITE_UNAVAILABLE` disertai `Retry-After: 1` berarti hasil belum dapat dipastikan. Tunggu/backoff, kirim ulang operasi yang sama dengan key yang sama. Jangan menyimpulkan operasi belum commit. Receipt menyelesaikan retry jika commit sebenarnya sudah berhasil. Error tak terduga tetap 500 `INTERNAL_ERROR`; respons tidak mengungkap SQL/error driver.

## Read

`Movement` memuat `id_stok`, `public_id`, `version`, `id_user`, `id_penyemaian`, `id_perawatan`, `tanggal_stok`, `jenis_stok`, `keterangan`, `reversal_of`, dan `details`. Seluruh ID/versi non-null berupa string; public identity berupa UUID. Link domain/keterangan/reversal yang tidak ada bernilai null. Waktu UTC ISO 8601 ditetapkan server. Setiap detail memuat `id_detail_stok`, `id_inventaris`, `jumlah`, `satuan`; jumlah berasal dari integer atoms dan dirender kanonis (`0.10` menjadi `0.1`).

List menerima `page` (default 1), `limit` (default 20, maksimum 100), `id_inventaris` dan `jenis_stok` opsional. Urutan header/detail berdasarkan ID numerik ascending. Filter barang memilih header yang mengandung barang tersebut dan tetap mengembalikan semua detail header. `meta` berisi integer `page`, `limit`, `total`, `total_pages`; total menghitung header unik. Halaman kosong berisi `data: []`. Riwayat mencakup barang tidak aktif, original dan reversal. Query tak dikenal ditolak; detail dan saldo tidak menerima query.

`Balance` berisi `id_inventaris`, `satuan`, `saldo`, `stok_minimum`, `di_bawah_minimum`. Saldo tanpa riwayat adalah `"0"`. Minimum null menghasilkan `di_bawah_minimum: false`; selain itu flag true hanya jika saldo lebih kecil, bukan sama. Saldo/minimum berupa string desimal kanonis; minimum memakai integer companion yang diperbarui bersama master B005.

## Error bisnis

| Status | Code | Makna |
| --- | --- | --- |
| 400 | `VALIDATION_ERROR` | Body, ID, query atau header tidak sesuai |
| 401/403 | Error auth bersama / `FORBIDDEN` | Sesi atau izin tidak memenuhi |
| 404 | `STOK_NOT_FOUND` / `INVENTARIS_NOT_FOUND` | Sumber read/reversal tidak ada |
| 422 | `INVENTARIS_NOT_AVAILABLE` / `UNIT_MISMATCH` | Referensi create atau satuan tidak valid |
| 409 | `INSUFFICIENT_STOCK` / `STOCK_LIMIT_EXCEEDED` | Update saldo melanggar batas |
| 409 | `STOK_ALREADY_REVERSED` / `REVERSAL_NOT_ALLOWED` | Reversal melanggar aturan audit/domain |
| 409 | `OPERATION_CONFLICT` | Key sudah dipakai dengan payload/jenis operasi/client identity berbeda |
| 409 | `RESOURCE_ALREADY_EXISTS` | Client ID sudah terikat ke resource saat create memakai key baru |
| 409 | `CLIENT_ID_CONFLICT` | Mapping UUID legacy bertentangan/ambigu |
| 409 | `UNIT_LOCKED` | PATCH master mengganti satuan setelah riwayat |
| 503 | `STOCK_WRITE_UNAVAILABLE` | Contention/transport/hasil commit tidak pasti; retry key sama |

Throttle HTTP bersama tetap dapat menghasilkan 429. Konsumsi internal domain, rekonsiliasi dan perbaikan saldo tidak diekspos sebagai endpoint publik B006.
