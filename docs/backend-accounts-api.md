# API akun pegawai dan profil — B003

Base path `/api/v1`. Semua endpoint memerlukan `Authorization: Bearer <access_token>` petani. Aturan transport, rate limit, serta envelope error mengikuti [kontrak utama](./backend-api.md).

## Endpoint

| Method | Path | Hasil |
| --- | --- | --- |
| POST | `/employees` | 201 `{ data: akun }`, header `Location` detail pegawai |
| GET | `/employees` | 200 `{ data: akun[], meta: { page, limit, total, total_pages } }` |
| GET | `/employees/:id` | 200 `{ data: akun }` |
| PATCH | `/employees/:id` | 200 `{ data: akun }` |
| POST | `/employees/:id/deactivate` | 204 tanpa body; request tanpa body; aman diulang |
| GET | `/profile` | 200 `{ data: akun }` milik sesi petani |
| PATCH | `/profile` | 200 `{ data: akun }` milik sesi petani |

Pegawai mendapat 403 pada seluruh endpoint tabel ini; tanpa sesi mendapat 401. Target petani pada `/employees/:id` diperlakukan sebagai tidak ditemukan (404). Akun pegawai nonaktif tetap dapat dilihat dan diedit oleh petani, tetapi tidak diaktifkan kembali melalui PATCH.

## Field input

| Field | Aturan |
| --- | --- |
| `nama` | String, trim, 1–100 karakter; wajib saat create |
| `username` | String 1–50 karakter, tidak diawali/diakhiri whitespace, tanpa line break; unik case-sensitive termasuk akun nonaktif; wajib saat create |
| `password` | String 12–128 karakter; wajib saat create, opsional saat PATCH; spasi password tidak dipangkas |
| `email` | Email valid maksimum 100 karakter, trim, opsional; `null` untuk mengosongkan |
| `no_telepon` | String trim 1–20 karakter berupa angka, spasi, kurung, tanda hubung, serta `+` opsional di awal; opsional/nullable |
| `alamat` | String trim 1–1000 karakter; opsional/nullable |
| `current_password` | Hanya PATCH profil; wajib bila mengirim username atau password, 1–128 karakter |

PATCH harus mengandung sedikitnya satu field perubahan. Body kosong, hanya `current_password`, field asing, `role`, `id_role`, `id_user`, `permissions`, dan `status_aktif` ditolak. Field yang tidak dikirim tidak berubah. Username/password/nama tidak menerima null. Role create selalu `pegawai`, status awal selalu 1.

`:id` adalah string bilangan bulat positif tanpa nol di awal, maksimum `9223372036854775807`. SQL mengikat ID sebagai string dan memproyeksikan ID sebagai TEXT untuk menghindari pembulatan JavaScript.

Query daftar: `page` default 1 (1–999999), `limit` default 20 (1–100), `status_aktif` opsional `0` atau `1`; tanpa filter mencakup semua pegawai. Query asing, nilai ganda, pecahan, nol, atau negatif ditolak. Urutan `id_user` menaik. Halaman melewati jumlah data mengembalikan array kosong. Daftar kosong memiliki `total_pages: 0`.

## Contoh

Create pegawai (`password` di bawah hanya contoh, bukan akun bawaan):

```json
{
  "nama": "Budi",
  "username": "budi",
  "password": "Ganti dengan password unik!",
  "email": "budi@example.test",
  "no_telepon": "081234567890",
  "alamat": null
}
```

Respons akun:

```json
{
  "data": {
    "id_user": "3",
    "nama": "Budi",
    "username": "budi",
    "email": "budi@example.test",
    "no_telepon": "081234567890",
    "alamat": null,
    "status_aktif": 1,
    "role": "pegawai"
  }
}
```

PATCH profil kontak: `{ "nama": "Pemilik Kebun", "email": null }`.

PATCH profil kredensial: `{ "password": "Password baru yang unik!", "current_password": "password-saat-ini" }`. Setelah 200, seluruh sesi petani dicabut; login ulang menggunakan kredensial baru. PATCH username saja juga mencabut seluruh sesi, sekalipun nilai sama dikirim. Reset username/password pegawai oleh petani mencabut sesi pegawai saja.

Penonaktifan dilakukan dengan `POST /api/v1/employees/3/deactivate` tanpa body. Riwayat penyemaian dan transaksi lain tetap menunjuk pengguna yang sama.

## Error tambahan

| Status | Kode | Kondisi |
| --- | --- | --- |
| 400 | `VALIDATION_ERROR` | Input body, parameter ID, atau query melanggar kontrak |
| 403 | `CURRENT_PASSWORD_INVALID` | Verifikasi password profil gagal; tidak ada perubahan tersimpan |
| 404 | `ACCOUNT_NOT_FOUND` | Target tidak ditemukan atau bukan role pegawai pada endpoint pegawai |
| 409 | `USERNAME_TAKEN` | Username sudah dipakai; seluruh perubahan dibatalkan |
| 409 | `ACCOUNT_CHANGED` | Kredensial profil berubah selama verifikasi; ulangi setelah login |
| 503 | `NOT_READY` | Role pegawai belum tersedia pada database |

Kegagalan transaksi menghasilkan 500 generik tanpa SQL/password. Jika sesi dicabut atau kedaluwarsa selama proses, pemeriksaan ulang sebelum penulisan menghasilkan 401; perubahan hak actor menghasilkan 403. Tidak ada endpoint DELETE, aktivasi kembali, atau penulisan role.
