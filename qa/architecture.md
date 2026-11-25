# qa/architecture.md — Arsitektur HidroSense (hasil orientasi QA)

Diperbarui 24 November 2026. Sumber: pembacaan kode aktual, bukan asumsi laporan.
Melengkapi `docs/ARCHITECTURE.md` (yang ditulis tim).

## 1. Bentuk repositori

| Folder | Isi | Teknologi |
|---|---|---|
| `apps/mobile` | Aplikasi petani & pegawai | Flutter (Dart), Riverpod, sqflite (SQLite lokal), `tflite_flutter`, `image_picker` |
| `apps/backend` | API & aturan bisnis | Node ≥22.13, TypeScript, Fastify 5, Zod 4, libSQL/SQLite |
| `ml` | Pipeline model deteksi hama | Python: `train.py`, `evaluate.py`, `export_tflite.py`, `prepare_dataset.py`, `kaggle_train_entry.py`; artefak + laporan |
| `qa` | Dokumen & skrip QA | bash/Node/Python |
| `docs` | Dokumentasi tim | `ARCHITECTURE.md`, ERD DBML, laporan FE |
| `graphify-out` | Knowledge graph | graphify |

## 2. Fitur backend yang ada

Titik masuk `apps/backend/src/app.ts` (`register*`). Pola per fitur: `index.ts` (rute) /
`contracts.ts` (Zod) / `write.ts` (pembungkus tulis: auth, izin, transaksi, idempotensi) /
`service.ts` (aturan) / `store.ts` (SQL).

| Fitur | Path | Izin |
|---|---|---|
| Auth | `/api/v1/auth/*` | publik / token |
| Accounts (pegawai, profil) | `/api/v1/employees`, `/profile` | `pegawai:manage`, `profil:*` |
| Inventaris | `/api/v1/jenis-inventaris`, `/obat`, `/inventaris` | `inventaris:*` |
| Stok (buku besar) | `/api/v1/stok`, `/inventaris/:id/saldo` | `inventaris:*` |
| Penyemaian | `/api/v1/penyemaian` | `penyemaian:*` |
| Meja tanam | `/api/v1/meja-tanam` | `budidaya:*` |
| Pemindahan | `/api/v1/pemindahan` | `budidaya:*` |
| Kerusakan | `/api/v1/kerusakan` | `budidaya:*` |
| Panen | `/api/v1/panen` | `panen:*` |
| Penjualan | `/api/v1/penjualan` | `penjualan:*` (petani saja) |
| **Unggahan foto** | `/api/v1/unggahan/tanda-tangan` | `deteksi:write` |
| **Pindaian hama** | `/api/v1/pindaian`, `/pindaian/:id` | `deteksi:read/write` |
| **Rekomendasi obat** | `/api/v1/rekomendasi-obat(/:id)(/terima|/tolak)` | `rekomendasi:read/decide`, `perawatan:write` |
| Sinkronisasi | `/api/v1/sync/changes`, `/sync/operations` | per izin |
| Health | `/health/live`, `/health/ready` | publik |

**Matriks izin** (`src/common/permissions.ts`):
- **Petani**: semua `commonReads` + `panen:write`, `inventaris:write`, `penyemaian:write`,
  `budidaya:write`, `pegawai:manage`, `profil:read/write`, `penjualan:read/write`,
  `deteksi:read/write`, `rekomendasi:read/decide`, `perawatan:read/write`, `cuaca:read`.
- **Pegawai**: `commonReads` (`inventaris:read`, `penyemaian:read`, `budidaya:read`,
  `panen:read`) + `inventaris:write`, `penyemaian:write`, `budidaya:write`, `panen:write`.
  **Tanpa** penjualan/deteksi/rekomendasi/perawatan/cuaca/akun.

## 3. Fitur backend yang TIDAK ada

`cuaca:read` ada di izin petani, tetapi **tidak ada** fitur `features/weather` di backend
(cuaca berjalan di klien). Tabel `penanganan_cuaca` hanya menyimpan **aturan**, **0 baris**
(tak diseed) → sisi server PB-10 `BLOCKED`.

> Catatan: `apps/backend/API.md` §"Belum tersedia" (baris 273–275) **usang** — ia masih
> menyatakan deteksi/rekomendasi/perawatan & potong stok "belum dibangun", padahal sudah
> ada (BUG-13). Cuaca BMKG memang tetap di klien.

## 4. Deteksi hama & model (baru)

- Model `ml/artifacts/yolo11n_lettuce_pests.tflite` (sha256 `cd388bda…`, 5,159 MB,
  input `[1,640,640,3]` NHWC FP16, output `[1,7,8400]`), byte-identik dengan
  `apps/mobile/assets/ml/`. Kelas: thrips, whitefly, aphids.
- Mobile: `lib/features/pest/data/pest_detector.dart` memuat via
  `Interpreter.fromAsset`; pra-proses (EXIF + letterbox 640, pad 114, RGB 0–1) di
  isolate (`compute`); NMS ambang 0,35 / IoU 0,45 (`yolo_decoder.dart`).
- Alur simpan: unggah Cloudinary (tanda tangan `/unggahan/tanda-tangan`) → simpan
  `pindaian` (jumlah per hama + confidence) → buat `rekomendasi-obat` per hama.
- Offline: inferensi sepenuhnya lokal; unggah terjadi saat simpan.

## 5. Rotasi obat (baru)

- `features/rotation/engine.ts`: jendela `ROTATION_WINDOW = 2` (hanya aplikasi ber-MoA);
  dua MoA terakhir diblokir; aturan `ROT-PHT` (ringan→hayati/nabati), `ROT-MOA`
  (kimia MoA berbeda), `ROT-FALLBACK`. Katalog null → `409 NO_RECOMMENDATION`.
- `acceptRecommendation` (`rotation/service.ts`): **membuat `perawatan` + potong stok**
  (`recordMovement`) dalam satu transaksi; replay aman (`200 replayed:true`), isi beda →
  `409 RECOMMENDATION_ALREADY_DECIDED`. (Deviasi SRS → G-12.)
- Migrasi `0019_pest_rotation` + `0020_catalog_phi`: tabel `deteksi_hama`,
  `hasil_deteksi`, `rekomendasi_perawatan`, `perawatan`, `obat_katalog`, `moa_groups`,
  `katalog_hama`, seed katalog, trigger/guard (`uq_rekomendasi_menunggu`, keputusan satu
  arah, trigger `perawatan`, masa tunggu panen/PHI).

## 6. Aturan domain kunci (server; klien menyalin untuk umpan balik cepat)

- HSS minimal pindah = **15 hari**; estimasi panen = tanggal pindah + **45 hari**.
- Stok = akumulasi buku besar `stok`/`detail_stok` (`stok_saldo` cache saldo); koreksi
  lewat **transaksi pembalik** (`reversal_of`), bukan hapus.
- **Berat panen**: `detail_panen.berat_minor` menyimpan **berat layak** (total − reject);
  reject di `berat_reject_minor`. Penjualan dibatasi `SUM(berat_minor)`.
- Idempotensi tulis lewat header `Idempotency-Key`; replay kunci+isi sama → `200 replayed:true`.
- Konflik versi lewat `version`/`expected_version` (`HARVEST_VERSION_CONFLICT`/
  `SALE_VERSION_CONFLICT`). **Semaian/stok/rusak belum mengirim `expected_version`** (G-13).
- Uang & berat disimpan **minor** (perseratus). Tanggal dibandingkan dalam **WIB**;
  tanggal masa depan → `400`.

## 7. Sinkronisasi & offline (mobile)

- `lib/data/services/sync_queue.dart`: tabel SQLite `sync_queue`, PK
  `(server_origin,user_id,key)`, versi skema 2 (`onUpgrade`); `enqueue` pakai
  `ConflictAlgorithm.replace`.
- `v2_sync_queue.dart` + `v2_sync_replayer.dart`: pengirim berurutan (induk dulu),
  kunci idempoten, baris `konflik`/`gagal` tetap di antrean; `send` dipisah dari `remove`.
- `session_store.dart`: tabel SQLite `sessions` (token **plaintext**; BUG-05).

## 8. Perangkat & build

- `AndroidManifest.xml` (main): `INTERNET` + `POST_NOTIFICATIONS`. **Tanpa CAMERA** —
  diharapkan: `image_picker` memakai intent sistem (tidak butuh izin CAMERA di manifest).
- Target Android 8.0+ (dari laporan) belum diverifikasi di `build.gradle.kts`.

## 9. Cara menjalankan cepat

```bash
# backend
cd apps/backend && npm ci && npm run db:migrate && npm run db:seed && npm run dev
# mobile
cd apps/mobile && flutter pub get && flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
# tes
cd apps/backend && npm test
cd apps/mobile && flutter analyze && flutter test
python3 -m pytest ml/tests -q      # dari root repo
```

Akun seed: `petani`/`Petani123456!` (petani), `pegawai`/`Pegawai123456!` (pegawai).
