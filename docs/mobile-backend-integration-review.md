# Laporan Integrasi Lengkap: Frontend Mobile & Backend HidroSense

Tanggal: 6 Oktober 2026  
Status: Terintegrasi & Terverifikasi (13/13 Automated Tests Lulus)  
Dokumen Terkait: [mobile-integration-2026-10-06.md](file:///d:/Dev/Projects/hidrosense/docs/mobile-integration-2026-10-06.md), [status-frontend-mobile.md](file:///d:/Dev/Projects/hidrosense/docs/status-frontend-mobile.md), [A9_PPL IF_WEEK5.docx.md](file:///d:/Dev/Projects/hidrosense/docs/A9_PPL%20IF_WEEK5.docx.md).

---

## 1. Ringkasan Eksekutif & Status Integrasi

Integrasi antara frontend mobile Flutter ([apps/mobile](file:///d:/Dev/Projects/hidrosense/apps/mobile)) dan backend Fastify/libSQL ([apps/backend](file:///d:/Dev/Projects/hidrosense/apps/backend)) telah menghubungkan antarmuka pengguna riil ke API tanpa mock data pada alur utama.

| Modul / Fitur | Endpoint Backend | Status Mobile | Mekanisme Data |
|---|---|:---:|---|
| **Autentikasi & Sesi** | `POST /api/v1/auth/login`<br>`POST /api/v1/auth/refresh`<br>`POST /api/v1/auth/logout` | **Selesai** | Token disimpan dalam memori (`ApiClient`). Rotasi single-use concurrency safe. `AppGate` mengunci navigasi ke `LoginPage` jika sesi kosong/berakhir. |
| **Profil & Hak Akses** | `GET /api/v1/accounts/me` | **Selesai** | Dikonsumsi via `sessionProvider` & `AccountBody`. Menampilkan identitas, username, dan daftar izin/role pengguna. |
| **Master Inventaris** | `GET /api/v1/inventaris`<br>`POST /api/v1/inventaris`<br>`PATCH /api/v1/inventaris/:id` | **Selesai** | DTO `InventoryRecord` & `JenisInventarisRecord`. Validasi ID string signed64. Form tambah/edit barang terhubung penuh. |
| **Saldo & Mutasi Stok** | `GET /api/v1/inventaris/:id/saldo`<br>`POST /api/v1/stok` | **Selesai** | Saldo desimal presisi (`0.25`). Pengambilan berurutan untuk menghindari rate limit. Registrasi stok awal terhubung ke `POST /api/v1/stok`. |
| **Cache SQLite Lokal** | Database `sqflite` lokal per pengguna | **Selesai** | Snapshot master & saldo disimpan atomik per host dan ID pengguna. Fallback offline badge dengan timestamp refresh. |
| **Penyemaian (B007)** | `GET /api/v1/penyemaian`<br>`POST /api/v1/penyemaian`<br>`PATCH /api/v1/penyemaian/:id` | **Selesai** | DTO `SowingRecord`. Listing semaian aktif, filter status, form semaian baru (otomatis memotong stok benih dari inventaris), dan layar detail. |
| **Meja Tanam (B008)** | `GET /api/v1/meja-tanam`<br>`POST /api/v1/meja-tanam`<br>`PATCH /api/v1/meja-tanam/:id` | **Selesai** | DTO `TableRecord`. Listing meja, rasio okupansi lubang terisi vs kapasitas total, filter ketersediaan vs pemeliharaan, form tambah & edit meja. |

---

## 2. Arsitektur Komponen Mobile (`apps/mobile`)

Arsitektur mengikuti rekomendasi *Layered Architecture* (UI -> ViewModel -> Repository -> Service/Local DB):

```
┌─────────────────────────────────────────────────────────────┐
│                    VIEWS & WIDGETS                          │
│   (AppGate, MainPage, InventarisBody, PenyemaianBody,       │
│    MejaNftBody, AccountBody, Form Pages)                    │
└──────────────────────────────┬──────────────────────────────┘
                               │ ref.watch() / ref.read()
┌──────────────────────────────▼──────────────────────────────┐
│                  VIEWMODELS (RIVERPOD)                      │
│   (sessionProvider, connectedInventoryProvider,             │
│    connectedNurseryProvider, connectedTableProvider)        │
└──────────────────────────────┬──────────────────────────────┘
                               │ Panggilan Domain
┌──────────────────────────────▼──────────────────────────────┐
│                    REPOSITORY LAYER                         │
│   (InventoryRepository, NurseryRepository, TableRepo)      │
└──────────────┬──────────────────────────────┬───────────────┘
               │ HTTP API                     │ SQLite Cache
┌──────────────▼──────────────┐┌──────────────▼───────────────┐
│         ApiClient           ││       InventoryCache         │
│  - JWT Bearer               ││  - SQLite Database           │
│  - Single-Flight Refresh    ││  - User/Server Isolation     │
│  - In-Memory Safe Tokens    ││  - Atomic Replace Snapshot   │
└─────────────────────────────┘└──────────────────────────────┘
```

### Struktur Modul Baru

1. **Service & Cache**:
   - `lib/data/services/api_client.dart` (292 baris): HTTP client tersentralisasi, handling token, validasi endpoint HTTPS/localhost, dan single-flight token rotation.
   - `lib/data/services/inventory_cache.dart` (240 baris): Penyimpanan SQLite lokal untuk master dan saldo inventaris.

2. **Model Domain (DTO)**:
   - `lib/data/models/inventory_record.dart`: Model item inventaris dan saldo numerik/desimal ketat.
   - `lib/data/models/jenis_inventaris_record.dart`: Kategori inventaris dari backend.
   - `lib/data/models/stock_movement_record.dart`: Payload transaksi stok masuk/keluar.
   - `lib/data/models/nursery_record.dart`: Record penyemaian benih dan bahan semai.
   - `lib/data/models/table_record.dart`: Record meja tanam, kapasitas lubang, dan okupansi aktif.

3. **Repositories & ViewModels**:
   - `lib/data/repositories/inventory_repository.dart` & `lib/viewmodels/connected_inventory_viewmodel.dart`
   - `lib/data/repositories/nursery_repository.dart` & `lib/viewmodels/connected_nursery_viewmodel.dart`
   - `lib/data/repositories/table_repository.dart` & `lib/viewmodels/connected_table_viewmodel.dart`

---

## 3. Disiplin Batasan Kode (< 300–400 Baris)

Seluruh file yang dibuat dan diperbarui dijaga agar tidak melebihi batas 300–400 baris per file:

| File | Jumlah Baris | Keterangan |
|---|:---:|---|
| `lib/views/components/account_body.dart` | 178 baris | Telah dikompilasi ulang & dibersihkan dari helper redundan |
| `lib/views/pages/add_form_inventaris_page.dart` | 240 baris | Form modular dengan dropdown & textfield ringkas |
| `lib/views/components/penyemaian_body.dart` | 146 baris | List semaian dengan filter & status card |
| `lib/views/components/meja_nft_body.dart` | 175 baris | Monitoring meja tanam dengan pull-to-refresh |
| `lib/views/components/form_meja_nft_body.dart` | 196 baris | Form tambah/edit meja tanam terhubung ke repository |
| `lib/views/components/info_meja_body.dart` | 185 baris | Detail spesifikasi meja & indikator progres okupansi |
| `lib/views/pages/info_seeding_page.dart` | 235 baris | Detail batch penyemaian & daftar konsumsi benih |
| `lib/data/services/api_client.dart` | 292 baris | Terjaga di bawah 300 baris dengan modular error handling |
| `lib/data/repositories/inventory_repository.dart` | 186 baris | CRUD inventaris, fetch saldo, & mutasi stok |

---

## 4. Hasil Verifikasi & Pengujian Otomatis

Pengujian dijalankan melalui Flutter Test framework lokal tanpa membangun APK (`--no-pub`):

```powershell
flutter test --no-pub
```

Hasil: **13 dari 13 tes lulus 100%**:
1. `api_client_test.dart`:
   - Concurrency: Dua request 401 bersamaan hanya melakukan satu rotasi refresh token.
   - Sesi lokal: Login kadaluarsa menolak token lama setelah logout lokal.
2. `inventory_record_test.dart`:
   - Validasi ID signed64 & desimal presisi survive deserialisasi.
   - Penolakan ID numerik, integer overflow, desimal negatif, dan format invalid.
3. `inventory_cache_test.dart`:
   - Isolasi snapshot per server URL dan user ID.
   - Rollback atomik jika pembaruan sebagian gagal.
4. `inventory_repository_test.dart`:
   - Pagination multi-halaman dan pengambilan saldo individual.
5. `nursery_repository_test.dart`:
   - Listing penyemaian aktif & parsing DTO `SowingRecord`.
   - Submit batch semai baru dengan konsumsi bahan benih.
6. `table_repository_test.dart`:
   - Fetching daftar meja tanam & kalkulasi okupansi lubang.
   - Pembuatan meja baru via POST `/api/v1/meja-tanam`.
7. `connected_flow_test.dart`:
   - Alur integrasi lengkap: Login -> Sesi Aktif -> Tampilan Inventaris -> Modal -> Akun -> Logout.
8. `widget_test.dart`:
   - Smoke test app gate membuka layar login tanpa data demo palsu.

---

## 5. Rencana Pekerjaan Selanjutnya (Next Steps)

1. **Modul Panen (B009) & Distribusi**:
   - Tunggu spesifikasi formula estimasi usia panen sebelum backend B009 disentuh.
   - Siapkan DTO panen di mobile untuk mencatat hasil panen dari meja tanam.
2. **Outbox Engine & Sinkronisasi Offline (PB-07 / B017)**:
   - Membuat local mutation queue (outbox table di SQLite) agar mutasi stok dan catat semaian dapat disimpan saat offline dan di-replay saat online.
3. **Penyimpanan Token Aman (Secure Storage)**:
   - Jika pengguna memerlukan *remember me* setelah restart aplikasi, pasang `flutter_secure_storage` untuk menyimpan refresh token secara terenkripsi (Android Keystore / iOS Keychain).
