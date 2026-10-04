# Kontrak API Meja Tanam B008

Tanggal: 4 Oktober 2026 (Asia/Jakarta). Scope implementasi lokal. Autentikasi: `Authorization: Bearer <access_token>`.

## Endpoint dan hak akses

| Method | Path | Akses |
| --- | --- | --- |
| POST | `/api/v1/meja-tanam` | Pegawai, `budidaya:write` |
| GET | `/api/v1/meja-tanam` | Pegawai dan petani, `budidaya:read` |
| GET | `/api/v1/meja-tanam/:id` | Pegawai dan petani, `budidaya:read` |
| PATCH | `/api/v1/meja-tanam/:id` | Pegawai, `budidaya:write` |

Matriks mengikuti System Request dan permission backend yang sudah berlaku. Akun nonaktif dan sesi tidak valid ditolak. Tidak ada endpoint hapus; histori batch tetap terhubung.

## Create dan update

Contoh POST:

```json
{"kode_meja":"M-01","jumlah_lubang":250,"status_meja":"tersedia","keterangan":null}
```

`kode_meja` wajib, trim 1–30 karakter, unik case-sensitive. `jumlah_lubang` wajib berupa integer positif hingga `Number.MAX_SAFE_INTEGER`. Tidak ada batas tetap 12 meja atau kapasitas 250. `status_meja` opsional pada create, default `tersedia`, teks manual trim 1–30 karakter. Tidak ada enum status fisik resmi dalam dokumen; label tidak diubah otomatis ketika meja penuh. `keterangan` opsional, null atau teks trim hingga 1000 karakter.

PATCH menerima subset field yang sama, minimal satu field. Field yang tidak hadir dipertahankan; `keterangan: null` menghapus catatan. Field asing ditolak. Mengurangi `jumlah_lubang` di bawah tanaman aktif menghasilkan 409 `TABLE_UNDERCAPACITY` dan seluruh perubahan dibatalkan.

Respons create 201 (header Location), replay 200, PATCH 200:

```json
{
  "data": {
    "id_meja":"1", "public_id":"<uuid>", "version":"1",
    "kode_meja":"M-01", "jumlah_lubang":250, "status_meja":"tersedia",
    "keterangan":null, "tanaman_aktif":0, "kapasitas_tersedia":250
  },
  "operation":{"operation_key":"<uuid>","revision":"1","public_id":"<uuid>","version":"1"},
  "replayed":false
}
```

ID dan version selalu string; ID route adalah integer desimal positif hingga signed64. Baris legacy yang belum mempunyai identitas sinkronisasi menampilkan `public_id`/`version` null sampai perubahan pertama.

## Daftar dan kapasitas

GET list menerima `page` (default 1, maksimum 999999), `limit` (default 20, maksimum 100), dan `status_meja` opsional dengan kecocokan persis. Urutan ID menaik. Respons `{data: [...], meta: {page, limit, total, total_pages}}`. GET detail mengembalikan `{data: {...}}`. Query asing ditolak.

Tanaman aktif per batch = jumlah pemindahan − total kerusakan − total detail panen. Jumlah per meja menjumlahkan seluruh batch meja tersebut. Kerusakan dan panen diagregasi secara terpisah agar beberapa baris anak tidak menggandakan perhitungan. Kapasitas tersedia = jumlah lubang − tanaman aktif. Status fisik tidak mengubah perhitungan ini.

Saldo batch negatif, nilai kapasitas tidak valid, atau okupansi melebihi kapasitas menghasilkan 409 `TABLE_BALANCE_INVALID`; data lama perlu direkonsiliasi, bukan ditutupi dengan hasil nol. Pemeriksaan dan update kapasitas berada dalam transaksi write yang sama. B009/B010/B015 nantinya wajib menjaga invariant yang sama saat menulis pemindahan, kerusakan dan panen.

## Sinkronisasi dan error

`Idempotency-Key` opsional berupa UUID mengikuti master B005. Klien yang memerlukan retry aman harus mengirim key yang sama: key dan payload sama mengembalikan receipt lama tanpa perubahan tambahan; payload berbeda menghasilkan 409 `OPERATION_CONFLICT`. Tanpa key, server membuat key baru dan retry dianggap operasi baru. PATCH replay mengembalikan snapshot receipt, bukan kondisi terbaru.

`X-Client-Id` opsional hanya pada POST, dinormalisasi ke lowercase, resource type `meja-tanam`. Dapat memakai identitas yang sudah direservasi lewat B004. Identitas yang sudah terikat menghasilkan 409 `RESOURCE_ALREADY_EXISTS`. Header ini pada PATCH ditolak 400. Identitas, version, receipt dan perubahan meja commit/rollback bersama.

Error tambahan: 400 `VALIDATION_ERROR`, 401 untuk sesi tidak sah, 403 `FORBIDDEN`, 404 `TABLE_NOT_FOUND`, 409 `TABLE_CODE_CONFLICT`. Format error mengikuti kontrak API utama.

## Batas bukti

Skema meja, unique kode dan indeks relasi sudah tersedia; tidak ada migrasi baru. Pengujian memakai SQLite/libSQL lokal. Deployment Turso, tampilan mobile, endpoint B009 dan full sync B017 belum dibuktikan oleh pekerjaan ini.
