# Permintaan Perubahan Backend — Sesi 7 (26 Nov 2026)

> Sesi 8 (27 Nov 2026): server **sudah berubah** untuk urutan daftar "perubahan
> terakhir" (client memilih "Backend exact last-changed"). Lihat §6.

Batas sesi 7: perubahan klien hanya di `apps/mobile/`. Backend **hanya** boleh berubah
untuk panjang password (min 6). Semua temuan berikut tidak dapat diselesaikan benar
hanya dari sisi klien; jangan dipaksakan dengan nilai pengganti (placeholder) yang
menyembunyikan data.

Status tiap butir: `BUTUH BACKEND`, `SUDAH DIKERJAKAN`, atau `PERTANYAAN`.

---

## 1. Password: batas atas server vs klien — `SUDAH DIKERJAKAN (sebagian)`

- **Fitur/bug terkait:** BUG-56 / D-34 (revisi SA Sesi 7: password 6–8 + huruf & angka).
- **Berkas/endpoint:** `apps/backend/src/common/validation.ts` (`newPasswordSchema`),
  `apps/backend/src/features/auth/bootstrap.ts` (teks bantuan CLI).
- **Alasan:** keputusan SA menetapkan password **6–8 karakter** dan wajib memuat huruf
  **dan** angka. Klien menegakkan aturan itu.
- **Yang sudah diubah:** `newPasswordSchema` `min(12)` → `min(6)`. `max(128)` **tidak**
  diubah menjadi 8 karena fixture/tes backend memakai password panjang
  (`'Fixture password 2026!'`) dan batas 8 akan mematahkan kontrak lama.
- **Pertanyaan terbuka:** apakah server harus ikut menolak >8 karakter, atau klien tetap
  menjadi satu-satunya penegak batas atas? Bila server harus 8, perlu migrasi akun lama
  yang password-nya >8 (tidak mungkin tanpa reset) — jadi rekomendasi: biarkan 128.

---

## 2. Penjualan: hapus status "belum lunas" dan nama pembeli — `BUTUH BACKEND`

- **Fitur/bug terkait:** keputusan SA Sesi 7 "penjualan: hapus belum lunas & nama pembeli".
- **Berkas/endpoint:**
  - `apps/backend/src/features/sales/contracts.ts` — `pembeli` wajib
    (`z.string().trim().min(1).max(100)`), `status_pembayaran`
    (`z.enum(['lunas', 'belum_lunas'])`).
  - `POST /api/v1/penjualan`, `PATCH /api/v1/penjualan/:id`,
    `POST /api/v1/penjualan/:id/bayar`.
  - Klien: `apps/mobile/lib/data/models/sale_record.dart`,
    `lib/viewmodels/v2_penjualan_store.dart`, `lib/views/v2/components/v2_penjualan_data.dart`,
    `v2_penjualan_mappers.dart`, `v2_penjualan_form_page.dart`,
    `v2_penjualan_detail_page.dart`, `v2_penjualan_row.dart`.
- **Alasan:** kedua isian wajib di kontrak sehingga klien tidak bisa menghapusnya tanpa
  mengirim nilai palsu. Nilai palsu akan tampil di riwayat/detail dan merusak laporan.
- **Usulan perubahan:**
  1. Jadikan `pembeli` opsional (boleh `null`) atau hapus dari kontrak, lalu hapus
     kolom terkait dari tabel `penjualan` (migrasi baru + backfill `NULL`).
  2. Hapus `status_pembayaran` dari kontrak, atau pertahankan kolom dengan nilai tetap
     `'lunas'` dan jangan tampilkan di UI. Semua transaksi karena itu dianggap lunas.
  3. Sesuaikan `GET /penjualan` (ringkasan "belum lunas" tidak lagi dihitung).
- **Yang dibutuhkan dari SA:** pilih "hapus kolom" atau "pertahankan, sembunyikan di UI".
  Tanpa pilihan itu, klien tidak boleh mengarang pembeli/status.

---

## 3. Stok: "Nama barang" obat harus dropdown dari katalog AI — `BUTUH BACKEND`

- **Fitur/bug terkait:** keputusan SA Sesi 7 "stok nama barang = dropdown dari katalog
  yang sama dengan rekomendasi AI".
- **Berkas/endpoint:**
  - `apps/backend/migrations/0019_pest_rotation.up.sql` — tabel `obat_katalog`
    (bahan aktif untuk mesin rotasi AI), **tidak** diekspos API.
  - `apps/backend/src/features/inventory/obat.ts` — `GET /api/v1/obat` membaca tabel
    `obat` (master yang dikelola pengguna), **berbeda** dari `obat_katalog`.
  - `apps/backend/src/features/rotation/store.ts` — rekomendasi AI memakai `obat_katalog`.
  - Klien: `lib/views/v2/connected/v2_inventaris_connected.dart` (`_obatPilihan`),
    `lib/views/v2/pages/v2_inventaris_form_page.dart`, `inventory_repository.listObat`.
- **Alasan:** daftar obat di form stok (`/obat`, mis. "Abamectin 18 EC") bukan daftar
  yang dipakai rekomendasi AI (`obat_katalog`, mis. "Abamektin"). Menyamakan keduanya
  butuh sumber data yang sama.
- **Usulan perubahan (pilih satu):**
  1. **Ekspos katalog:** tambah `GET /api/v1/obat-katalog` (read-only) yang mengembalikan
     `id_katalog`, `bahan_aktif`, `jenis`, `kode_moa`; lalu form stok memakai endpoint
     itu sebagai dropdown.
  2. **Satukan tabel:** seed `obat` dari `obat_katalog` dan tautkan
     `inventaris.id_obat` ke entri katalog, sehingga `/obat` dan AI memakai daftar sama.
- **Pertanyaan terbuka:** apakah "nama barang" untuk jenis Obat harus **otomatis** mengisi
  nama dari katalog (tidak bisa diketik bebas) atau tetap bebas dengan saran dropdown?

---

## 4. Riwayat perawatan: belum ada endpoint daftar — `BUTUH BACKEND`

- **Fitur/bug terkait:** "riwayat perawatan ngebug" (hasil investigasi Sesi 7).
- **Berkas/endpoint:**
  - Tabel `perawatan` ada di `apps/backend/migrations/0019_pest_rotation.up.sql`
    (dipakai `POST /api/v1/rekomendasi-obat/:id/terima` untuk mencatat pemakaian).
  - **Tidak ada** `GET /api/v1/perawatan` maupun `GET /api/v1/perawatan/:id`.
  - Klien: `lib/views/v2/connected/v2_rawat_connected.dart` — tab Rawat saat ini
    menampilkan laporan **kerusakan** (`DamageRepository`), bukan riwayat perawatan.
- **Alasan:** tidak ada cara membaca riwayat perawatan, sehingga tab Rawat tidak bisa
  menampilkan data yang benar walau UI-nya sudah ada.
- **Usulan perubahan:** tambah `GET /api/v1/perawatan` (filter tanggal/meja/obat,
  paginasi seperti daftar lain, izin `perawatan:read`) dan `GET /api/v1/perawatan/:id`.
  Klien lalu memetakan hasilnya ke kartu riwayat yang sudah ada.
- **Catatan:** perawatan dibuat lewat "Terima" rekomendasi; belum ada alur edit/koreksi
  terpisah (gap G-02/G-12), jadi endpoint baca dulu yang dibutuhkan.

---

## 5. Profil pegawai: izin baca profil sendiri — `BUTUH BACKEND`

- **Fitur/bug terkait:** role Pegawai (keputusan SA Sesi 7: sembunyikan/blokir route
  terlarang).
- **Berkas/endpoint:** `apps/backend/src/common/permissions.ts` — `pegawai` tidak punya
  `profil:read`/`profil:write`; `GET /api/v1/profil` karena itu 403.
- **Alasan:** tab "Profil" pegawai hanya bisa menampilkan nama/username dari sesi;
  telepon dan alamat tampil `-` karena profil tidak boleh dibaca. Data itu ada di server
  dan seharusnya boleh dibaca pemiliknya (read-only).
- **Usulan perubahan:** tambahkan `profil:read` untuk `pegawai` (tetap **tanpa**
  `profil:write`), atau sediakan `GET /api/v1/profil/saya` yang hanya mengembalikan data
  pengguna yang sedang login.
- **Catatan:** klien sudah menahan tampilan read-only dan tidak menawarkan ubah profil
  untuk pegawai; tidak ada perubahan klien yang diperlukan setelah izin ditambah.

---

## 6. Daftar: urutkan "perubahan terakhir" — `SUDAH DIKERJAKAN`

- **Fitur/bug terkait:** BUG-68 / D-51 (permintaan client Sesi 8).
- **Berkas/endpoint:**
  - `apps/backend/migrations/0023_list_last_changed.{up,down}.sql` — indeks
    `idx_sync_changes_resource_domain` + kolom `users.updated_at`.
  - `apps/backend/src/common/sync.ts` — helper `lastChangedAt()`; respons tulis membaca
    ulang `MAX(changed_at)`.
  - `apps/backend/src/features/{inventory,nursery,tables,harvest,sales}/store.ts` — kolom
    `updated_at` + `ORDER BY COALESCE(updated_at,0) DESC, <id> DESC`.
  - `apps/backend/src/features/accounts/*.ts` — tulis/baca `users.updated_at`, urut
    `COALESCE(updated_at,0) DESC, id_user DESC`.
- **Alasan:** urutan "paling baru diubah" hanya benar bila waktu ubah berasal dari server;
  `sync_changes` sudah memuat perubahan turunan (saldo stok, tanaman aktif meja, pindah,
  kerusakan, panen) sehingga koreksi pada baris lama pun naik ke atas.
- **Perubahan kontrak:** `GET` daftar inventaris/penyemaian/meja/panen/penjualan/pegawai
  kini menyertakan `updated_at` (integer epoch ms, **nullable**). Klien lama yang tidak
  membaca field baru tetap aman.
- **Catatan:** akun tidak ikut registry sync, jadi waktu ubahnya disimpan di
  `users.updated_at` (baris lama `NULL` → diurut paling bawah). Tidak ada backfill.

---

## Ringkasan prioritas

| # | Butir | Dampak | Status |
|---|---|---|---|
| 1 | Password min 6 (max 128) | BUG-56 | SUDAH DIKERJAKAN |
| 2 | Hapus pembeli & belum lunas | Penjualan | BUTUH BACKEND + keputusan SA |
| 3 | Dropdown obat dari katalog AI | Stok | BUTUH BACKEND |
| 4 | Endpoint riwayat perawatan | Rawat | BUTUH BACKEND |
| 5 | `profil:read` untuk pegawai | Profil pegawai | BUTUH BACKEND |
| 6 | `updated_at` + urut daftar terbaru | BUG-68 | SUDAH DIKERJAKAN |