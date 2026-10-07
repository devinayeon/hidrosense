# Task Breakdown B009: Pemindahan Bibit ke Meja Tanam

## Tahapan Eksekusi

- [x] **Task 1: Perencanaan & Dokumen Kontrak**
  - [x] Tulis `docs/b009/spec-pemindahan-bibit.md`
  - [x] Tulis `docs/backend-transfers-api.md`
  - [x] Tetapkan baseline durasi panen 45 hari

- [x] **Task 2: Skema Database & Migrasi 0009**
  - [x] Buat `apps/backend/migrations/0009_transfers_list_index.up.sql`
  - [x] Buat `apps/backend/migrations/0009_transfers_list_index.down.sql`

- [x] **Task 3: Validasi & Kontrak Zod (`contracts.ts`)**
  - [x] Validasi kalender riil YYYY-MM-DD
  - [x] Validasi integer ID & payload transfer
  - [x] Validasi query list & patch keterangan

- [x] **Task 4: Lapisan Database Store & Kalkulasi Panen (`store.ts`)**
  - [x] Query batch pemindahan lengkap dengan link public_id & version
  - [x] Perhitungan HSS, HST, estimasi tanggal panen (baseline 45 hari), sisa hari panen
  - [x] Perhitungan sisa bibit semai & kapasitas lubang meja tanam
  - [x] Query list dengan pagination & filter

- [x] **Task 5: Lapisan Logika Bisnis & Invarian Transaksi (`service.ts`)**
  - [x] Pengecekan umur bibit $\ge 15$ hari
  - [x] Pengecekan ketersediaan bibit semai
  - [x] Pengecekan kapasitas lubang meja & ketersediaan status meja
  - [x] Eksekusi atomik transfer bibit

- [x] **Task 6: Lapisan Write & Sinkronisasi Idempotensi (`write.ts`)**
  - [x] Pembungkus `executeDomainMutation` untuk `pemindahan.create` dan `pemindahan.update`
  - [x] Manajemen `Idempotency-Key` dan `X-Client-Id`

- [x] **Task 7: Rute & Registrasi Server (`index.ts` & `app.ts`)**
  - [x] Handler rute GET, POST, PATCH di `/api/v1/pemindahan`
  - [x] Registrasi ke `src/app.ts`

- [x] **Task 8: Pengujian Menyeluruh (`test/transfers.test.js`)**
  - [x] Uji alur sukses create, detail, list, patch
  - [x] Uji validasi umur bibit < 15 hari
  - [x] Uji batas kapasitas semai dan meja tanam
  - [x] Uji idempotensi replay & pencegahan duplikasi
  - [x] Uji otorisasi peran (Petani vs Pegawai)
