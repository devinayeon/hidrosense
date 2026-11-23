# TASKS.md — Status pekerjaan QA HidroSense

Sumber: PROMPT.md §4–§5. Status: `TODO`, `IN_PROGRESS`, `BLOCKED`, `REVIEW`, `DONE`.
`DONE` hanya setelah ada bukti nyata di `mcdocs/testing.md`.

## Fase 0 — Orientasi
- [DONE] T0.1: Petakan repo → `mcdocs/architecture.md`
- [DONE] T0.2: Cek tool (flutter 3.47.7, node v22.23.1, adb tanpa perangkat) → `mcdocs/decisions.md`
- [DONE] T0.3: Buat `PLANS.md`, `TASKS.md`, `mcdocs/`
- [DONE] T0.4: Lingkungan uji terisolasi (`/tmp/opencode/hsqa/qa.db`, port 3100) → `qa/reset-backend-qa.sh`

## Fase 1 — Baseline
- [DONE] T1.1: Baseline `flutter analyze` → 2 warning aset lama (`assets/illustrations/inventory|features`)
- [DONE] T1.2: Baseline `flutter test` → 453/453 PASS; akhir 465/465
- [DONE] T1.3: Baseline `npm test` → 359/359 PASS
- [DONE] T1.4: `npm run check` → typecheck OK, lint OK, lines OK, test OK

## Fase 2 — Backend/API (§5.3, PB-01/02/07/11)
- [DONE] T2.1: PB-01 Auth & hak akses (`AU-01..14`) → `qa/backend-api-smoke.sh`
- [DONE] T2.2: Otorisasi dua lapis pegawai vs endpoint petani (`AZ-01..10`)
- [DONE] T2.3: Idempotensi & replay (`ID-01..04`, `SL-06`)
- [DONE] T2.4: IDOR & validasi input server-side (`ST-*`, `AU-12`, `http-boundaries.test.js`)
- [DONE] T2.5: Pagination/limit/parameter tak dikenal (`QS-01..04`)
- [DONE] T2.6: Akun (unik, deaktivasi mencabut sesi) (`AC-01..12`)

## Fase 3 — Logika domain & invarian (§5.8)
- [DONE] T3.1: Stok = sum(masuk)-sum(keluar) >= 0 (`AQ-01`,`AQ-02`)
- [DONE] T3.2: tanaman_aktif = pindah - rusak - panen >= 0 (`AQ-04`,`AQ-08`)
- [DONE] T3.3: kapasitas meja <= lubang; total <= 3000 (`AQ-04`)
- [DONE] T3.4: terjual <= layak; pindah <= benih (`AQ-06`,`AQ-07`,`AQ-10`)
- [DONE] T3.5: Fuzz urutan acak → `apps/backend/qa/fuzz-invariants.mjs` (638 pemeriksaan lulus)
- [DONE] T3.6: Batas persis (14/15 hari, tepat kapasitas, tepat layak) → `qa/backend-boundaries.sh`

## Fase 4 — Mobile front-end
- [DONE] T4.1: Review `core/` (growth, weather, formatting, business_date, uuid)
- [DONE] T4.2: Review `sync_queue` & `v2_sync_replayer`
- [DONE] T4.3: Tes regresi baru untuk bug front-end (`core_formatting_test.dart`,
  `v2_format_desimal_test.dart`, `v2_inventaris_status_test.dart`)
- [DONE] T4.4: Perbaiki bug front-end (BUG-01/02/03, hanya `apps/mobile/`)

## Fase 5 — Sync & offline (PB-07)
- [DONE] T5.1: Telaah urutan induk→anak, retry, konflik (`sync-contract.test.js`, `sync-changes.test.js`)
- [DONE] T5.2: Uji kegagalan sync tidak menghapus data (`write_outcome_test.dart`)
- [DONE] T5.3: Idempotensi setelah respons hilang (`ID-01..04`)

## Fase 6 — AI (§5.5)
- [BLOCKED] T6.1: Evaluasi model — `ml/*.py` 0 byte, tak ada `.tflite`/dataset → `mcdocs/model_evaluation.md`

## Fase 7 — E2E / kinerja / usability
- [DONE] T7.1: Skenario E2E backend utuh → `qa/backend-e2e.sh` (28/28)
- [DONE] T7.2: Ukur kinerja → `qa/perf.sh` (API ~2 ms); perangkat `MANUAL-PENDING`
- [DONE] T7.3: Heuristic usability review + `mcdocs/manual_checklist.md` (usability mitra MANUAL-PENDING)

## Fase 8 — Rekap
- [DONE] T8.1: `mcdocs/testing.md` matriks lengkap (192 test case / kolom status)
- [DONE] T8.2: `mcdocs/issues.md` + statistik severity (3 FIXED, 5 review/gap)
- [DONE] T8.3: `mcdocs/rtm.md` (Business Requirements, kriteria penerimaan, §Gap, DoD)
- [DONE] T8.4: `mcdocs/audit_queries.sql` (AQ-01..AQ-15) + kontrol negatif
- [DONE] T8.5: Regresi penuh setelah perbaikan → backend 359/359, mobile 465/465, analyze 2 warning lama
- [DONE] T8.6: Laporan akhir (pesan tunggal ke client)
