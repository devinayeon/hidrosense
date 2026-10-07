# Implementasi Backend B009 — Pemindahan Bibit ke Meja Tanam

Tanggal: 7 Oktober 2026 (Asia/Jakarta).
Status: **Selesai (100% Teruji)**.

---

## 1. Ringkasan Implementasi

Modul `features/transfers/` mengimplementasikan fitur **B009 — Pemindahan Bibit ke Meja (*Seedling Transfer to Growing Table*)**. Fitur ini menghubungkan modul penyemaian (B007) dengan meja tanam NFT (B008), mengelola alur pemindahan bibit semai yang telah mencapai umur minimal 15 hari ke lubang meja tanam, dan menghitung estimasi tanggal panen secara otomatis.

### Keputusan Standar Panen
Standar durasi panen ditetapkan secara eksplisit pada **baseline 45 hari** (45 Hari Setelah Semai / HSS):
- Umur Bibit Semai: minimal 15 hari ($T_{\text{pindah}} \ge T_{\text{semai}} + 15\text{ hari}$).
- Periode Pembesaran di Meja Tanam: 30 hari.
- Estimasi Tanggal Panen: $T_{\text{semai}} + 45\text{ hari kalender}$.
- Hari Setelah Tanam (HST): $\text{Hari Ini} - T_{\text{pemindahan}}$.
- Hari Setelah Semai (HSS): $\text{Hari Ini} - T_{\text{semai}}$.
- Sisa Hari Panen: $\max(0, \text{Estimasi Panen} - \text{Hari Ini})$.

---

## 2. Struktur Modul & Skema

- **Migrasi**:
  - [apps/backend/migrations/0009_transfers_list_index.up.sql](file:///d:/Dev/Projects/hidrosense/apps/backend/migrations/0009_transfers_list_index.up.sql): Indeks komposit `idx_pemindahan_date` pada `pemindahan(tanggal_pemindahan DESC, id_pemindahan DESC)`.
- **Modul Backend (`apps/backend/src/features/transfers/`)**:
  - [contracts.ts](file:///d:/Dev/Projects/hidrosense/apps/backend/src/features/transfers/contracts.ts): Skema Zod untuk create, list query, dan patch keterangan.
  - [store.ts](file:///d:/Dev/Projects/hidrosense/apps/backend/src/features/transfers/store.ts): Query DTO, join sinkronisasi public UUID dan versi, perhitungan HSS/HST/estimasi panen, serta kalkulasi tanaman aktif per meja.
  - [service.ts](file:///d:/Dev/Projects/hidrosense/apps/backend/src/features/transfers/service.ts): Validasi invarian bisnis: umur bibit $\ge 15$ hari, ketersediaan bibit semai (B007), ketersediaan lubang meja (B008), status meja, dan otomatisasi status penyemaian menjadi `selesai` saat bibit habis.
  - [write.ts](file:///d:/Dev/Projects/hidrosense/apps/backend/src/features/transfers/write.ts): Integrasi `executeDomainMutation` dengan dukungan `Idempotency-Key` dan `X-Client-Id`.
  - [index.ts](file:///d:/Dev/Projects/hidrosense/apps/backend/src/features/transfers/index.ts): Fastify route handler dengan otorisasi `budidaya:write` (Pegawai) dan `budidaya:read` (Petani & Pegawai).
- **Spesifikasi & Kontrak API**:
  - [docs/b009/spec-pemindahan-bibit.md](file:///d:/Dev/Projects/hidrosense/docs/b009/spec-pemindahan-bibit.md)
  - [docs/b009/tasks-pemindahan-bibit.md](file:///d:/Dev/Projects/hidrosense/docs/b009/tasks-pemindahan-bibit.md)
  - [docs/backend-transfers-api.md](file:///d:/Dev/Projects/hidrosense/docs/backend-transfers-api.md)

---

## 3. Hasil Pengujian & Gate Kualitas

- **Unit & Integration Test Suite (`test/transfers.test.js`)**: 7/7 tes lolos.
  1. Kalkulasi umur semai, estimasi tanggal panen (standar 45 hari), dan tanaman aktif.
  2. Penolakan bibit berusia di bawah 15 hari dan format tanggal tidak valid.
  3. Penegakan batas ketersediaan bibit semai dan otomatisasi status semai `selesai`.
  4. Penegakan batas kapasitas lubang meja tanam dan status meja perbaikan/rusak.
  5. Pengujian list, detail, pagination, dan filter.
  6. Pengujian patch keterangan dan replay idempotensi.
  7. Penegakan matriks hak akses: Pegawai (write/read) vs Petani (read-only).
- **Full Backend Check Gate (`npm run check`)**:
  - Typecheck: 0 errors.
  - Line checks: Seluruh file di bawah batas maksimum 400 baris (file terbesar 318 baris).
  - Test Suite: **184/184 tes lolos (100% lulus)**.
- **Mobile Regression Check (`flutter test --no-pub`)**:
  - **13/13 tes lolos (0 regresi)**.
