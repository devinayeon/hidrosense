# PLANS.md — Strategi QA HidroSense

Terakhir diperbarui: 23 November 2026.

## Prinsip

- **Bukti di atas klaim.** Setiap status PASS/FAIL harus punya perintah + output.
- **Solo by default.** Delegasi hanya jika Herdr + model TokenHarbor High + automation monitor
  semuanya tersedia dan benar-benar menguntungkan. Lihat `mcdocs/decisions.md` (D-01).
- **Batas perbaikan (permintaan client):** bug **hanya** boleh diperbaiki jika berada di
  `apps/mobile/` (front-end). Bug backend/DB/ML dicatat di `mcdocs/issues.md`, tidak diubah.

## Cakupan nyata vs laporan

Laporan/PROMPT mengasumsikan 11 Product Backlog. Implementasi nyata lebih sempit
(lihat `architecture.md` §3). Area PB-05/06 (deteksi, rekomendasi, perawatan) dan sisi
server PB-10 belum dibangun → statusnya `N/A`/`BLOCKED`, bukan PASS palsu.

## Urutan eksekusi (status akhir)

1. **Fase 0 — Orientasi** (SELESAI): peta repo, cek tool, `mcdocs/`, `TASKS.md`, `PLANS.md`.
2. **Fase 1 — Baseline** (SELESAI): backend `npm test` 359/359; mobile `flutter test` 453→465;
   `flutter analyze` 2 warning aset lama; `npm run check` OK.
3. **Fase 2 — Backend/API adversarial** (SELESAI, `/tmp/opencode/hsqa`, port 3100):
   `qa/backend-api-smoke.sh` 73/73; `qa/backend-boundaries.sh` 11/11.
4. **Fase 3 — Invarian domain** (SELESAI): `apps/backend/qa/fuzz-invariants.mjs` 638 pemeriksaan,
   0 pelanggaran; `mcdocs/audit_queries.sql` AQ-01..AQ-15 semua 0 baris.
5. **Fase 4 — Mobile (front-end)** (SELESAI): review `core/` + sync; temukan & perbaiki
   BUG-01/02/03 di `apps/mobile/` dengan tes regresi (kegagalan-terlebih-dahulu).
6. **Fase 5 — Sync/offline** (SELESAI di sisi kode + tes); uji perangkat `MANUAL-PENDING`.
7. **Fase 6 — AI** (BLOCKED): tak ada artefak model/dataset (`ml/*.py` 0 byte).
8. **Fase 7 — E2E / kinerja / usability** (SELESAI): `qa/backend-e2e.sh` 28/28;
   `qa/perf.sh` API ~2 ms; usability perangkat/mitra `MANUAL-PENDING`.
9. **Fase 8 — Rekap** (SELESAI): `testing.md`, `issues.md`, `rtm.md`, `manual_checklist.md`,
   `model_evaluation.md`, `audit_queries.sql`, regresi penuh, laporan akhir.

## Risiko & mitigasi

| Risiko | Mitigasi |
|---|---|
| Menyentuh data asli | Selalu `DATABASE_URL` ke `/tmp/opencode/hsqa/*.db`; jangan pakai `apps/backend/data`. |
| Tidak ada emulator/perangkat | Uji UI lewat `flutter test` (widget); tandai uji perangkat `MANUAL-PENDING`. |
| Kredensial Turso/Cloudinary tidak ada | Tidak dipakai; tidak diperlukan. |
| Model AI tidak ada | `BLOCKED` + alasan di `model_evaluation.md`, tidak mengarang angka. |
| Perbaikan melebar ke backend | Dilarang oleh permintaan client; catat di `issues.md`. |

## Definisi selesai

Lihat PROMPT.md §10. Ringkas: semua area punya status nyata, S1/S2 diperbaiki (jika
front-end) atau didokumentasikan, regresi penuh dijalankan, invarian diuji, kinerja diukur,
RTM & dokumen lengkap, tidak ada data uji/secret tertinggal.