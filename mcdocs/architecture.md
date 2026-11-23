# Arsitektur HidroSense (hasil orientasi QA)

Tanggal orientasi: 23 November 2026. Sumber: pembacaan kode aktual, bukan asumsi laporan.
Peta ringkas ini melengkapi `docs/ARCHITECTURE.md` (yang ditulis tim) dan menambah fakta yang
relevan untuk pengujian.

## 1. Bentuk repositori

| Folder | Isi | Teknologi |
|---|---|---|
| `apps/mobile` | Aplikasi petani & pegawai | Flutter (Dart), Riverpod, sqflite (SQLite lokal) |
| `apps/backend` | API & aturan bisnis | Node >=22.13, TypeScript, Fastify 5, Zod 4, libSQL/SQLite |
| `ml` | Rencana model deteksi hama | **Kosong** (`train.py`, `evaluate.py`, `export_tflite.py` = 0 byte) |
| `docs` | Dokumentasi tim | - |
| `graphify-out` | Knowledge graph | - |

Tidak ada model `.tflite`/`.onnx`/`.pt` di repo atau di `apps/mobile/assets`. Tidak ada
dependensi kamera/image-picker di `pubspec.yaml`.

## 2. Daftar fitur backend yang BENAR-BENAR ada

Titik masuk: `apps/backend/src/app.ts` (`register*`). Tiap fitur punya pola
`index.ts` (rute) / `contracts.ts` (validasi Zod) / `write.ts` (pembungkus tulis:
autentikasi, izin, transaksi, idempotensi) / `service.ts` (aturan) / `store.ts` (SQL).

| Fitur | Path | Izin |
|---|---|---|
| Auth | `/api/v1/auth/*` | publik / token |
| Accounts (pegawai, profil) | `/api/v1/employees`, `/api/v1/profile` | `pegawai:manage`, `profil:*` |
| Inventaris | `/api/v1/jenis-inventaris`, `/obat`, `/inventaris` | `inventaris:*` |
| Stok (buku besar) | `/api/v1/stok`, `/inventaris/:id/saldo` | `inventaris:*` |
| Penyemaian | `/api/v1/penyemaian` | `penyemaian:*` |
| Meja tanam | `/api/v1/meja-tanam` | `budidaya:*` |
| Pemindahan | `/api/v1/pemindahan` | `budidaya:*` |
| Kerusakan | `/api/v1/kerusakan` | `budidaya:*` |
| Panen | `/api/v1/panen` | `panen:*` |
| Penjualan | `/api/v1/penjualan` | `penjualan:*` (petani saja) |
| Sinkronisasi | `/api/v1/sync/changes`, `/api/v1/sync/operations` | per izin |
| Health | `/health/live`, `/health/ready` | publik |

## 3. Fitur backend yang TIDAK ADA (padahal disebut laporan/PROMPT)

`apps/backend/API.md` bagian "Belum tersedia" menyatakan sendiri:

> Deteksi hama, rekomendasi, dan perawatan belum dibangun.
> Cuaca BMKG berjalan di aplikasi mobile, bukan di backend.

Konfirmasi: tidak ada folder `features/detection`, `features/recommendation`,
`features/maintenance`, `features/weather`. Izin `deteksi:*`, `rekomendasi:*`,
`perawatan:*`, `cuaca:read` sudah ada di `common/permissions.ts` (hanya petani),
tetapi tidak ada rute yang memakainya.

**Implikasi uji:** PB-05 (deteksi hama), PB-06 (rekomendasi & perawatan), dan sisi
server PB-10 (cuaca) → mayoritas `N/A`/`BLOCKED`; banyak kriteria penerimaan PB-05/06
hanya punya mock desain di aplikasi (lihat `lib/views/v2/pages/v2_rawat_*.dart`,
`v2_rawat_data.dart` = "Data contoh untuk slice desain v2").

## 4. Cuaca BMKG (sisi klien)

- `lib/data/services/bmkg_weather_service.dart`: panggil `https://api.bmkg.go.id/publik/prakiraan-cuaca?adm4=...`
  langsung dari perangkat. Default `adm4=35.09.12.2002` (Desa Sabrang, Ambulu, Jember). Bisa
  ditimpa `--dart-define=BMKG_ADM4`.
- `lib/core/weather_rules.dart`: pencocokan ambang suhu/kelembapan/hujan/angin → daftar tindakan.
- **Tidak ada** tabel riwayat cuaca (sesuai spesifikasi). Tidak ada proxy backend.

## 5. Aturan domain kunci (sumber server; klien menyalin untuk umpan balik cepat)

- HSS minimal pindah = **15 hari**; estimasi panen = tanggal pindah + **45 hari**
  (`common/growth-rules.ts` = salinan `lib/core/growth_rules.dart`).
- Stok = akumulasi buku besar `stok`/`detail_stok` (`stok_saldo` sebagai cache saldo);
  koreksi lewat **transaksi pembalik** (`reversal_of`), bukan hapus.
- Idempotensi tulis lewat header `Idempotency-Key`; replay kunci+isi sama → `200 replayed:true`.
- Konflik versi lewat `version`/`expected_version` (`409 VERSION_CONFLICT`; panen & penjualan
  punya kode khusus `HARVEST_VERSION_CONFLICT`/`SALE_VERSION_CONFLICT`).
- Nominal uang & berat disimpan **minor** (perseratus) untuk menghindari galat floating point.
- Tanggal dibandingkan dalam **WIB (Asia/Jakarta)**; tanggal masa depan → `400`.

## 6. Sinkronisasi & offline (mobile)

- `lib/data/services/sync_queue.dart`: tabel SQLite `sync_queue`, PK `(server_origin,user_id,key)`,
  versi skema 2 (ada `onUpgrade`). `enqueue` pakai `ConflictAlgorithm.replace` (kunci sama menimpa).
- `lib/viewmodels/v2_sync_queue.dart` + `v2_sync_replayer.dart`: pengirim berurutan, induk dulu
  (urutan `SyncQueueJenis.index`), kunci idempoten, baris `konflik`/`gagal` tetap di antrean.
- `lib/data/services/session_store.dart`: tabel SQLite `sessions` (token **plaintext** di DB SQLite
  perangkat, bukan secure storage). `lib/data/services/api_client.dart` menahan token di memori.

## 7. Perangkat & build

- `AndroidManifest.xml` (main): hanya `INTERNET` + `POST_NOTIFICATIONS`. **Tidak ada CAMERA**.
- Target Android 8.0+ (dari laporan) belum diverifikasi di `build.gradle.kts` (lihat testing.md).
- `apps/mobile/android/` tanpa kamera → konsisten dengan deteksi hama yang belum dibangun.

## 8. Cara menjalankan cepat

```bash
# backend
cd apps/backend && npm ci && npm run db:migrate && npm run db:seed && npm run dev
# mobile
cd apps/mobile && flutter pub get && flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
# tes
cd apps/backend && npm test
cd apps/mobile && flutter analyze && flutter test
```

Akun seed: `petani`/`Petani123456!` (petani), `pegawai`/`Pegawai123456!` (pegawai).
