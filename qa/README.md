# qa/ — Bukti & Dokumen QA HidroSense

Hasil QA/testing HidroSense (tugas PPL, Universitas Jember, Kelompok A9) untuk
audit oleh dosen penguji. Semua status berasal dari **bukti nyata**, bukan asumsi.

> Pengujian terakhir: **24 November 2026** — re-QA menyeluruh setelah backend + AI (`ml`)
> menyusul. Fitur deteksi hama (PB-05) dan rekomendasi & perawatan (PB-06) kini dibangun.
> Hari yang sama: hasil **uji manual dev FE di HP asli** dimasukkan (`manual_checklist.md`),
> **11 bug baru (BUG-15..BUG-25) diperbaiki** + regression test, dan `flutter analyze` kini
> **bersih**. Aplikasi dinyatakan **online-only** oleh PM (D-14) → kasus uji offline jadi N/A.
> Sesi 2 (24 Nov 2026) menambah BUG-22..BUG-25 dari laporan manual yang sama; total
> `flutter test` mobile kini **632 PASS**.

## Dokumen

| Berkas | Isi |
|---|---|
| `testing.md` | **Matriks seluruh test case** (204) + status + cara menjalankan ulang |
| `issues.md` | Semua bug/temuan (format PROMPT §8) + statistik severity + saran perbaikan |
| `rtm.md` | Requirements Traceability Matrix + §Gap dokumen vs implementasi + DoD |
| `manual_checklist.md` | Uji perangkat fisik/mitra (sebagian `PASS` hasil dev FE + `MANUAL-PENDING`) + lembar observasi usability |
| `model_evaluation.md` | Evaluasi model AI (§5.5): nilai, provenance, paritas pra-pemrosesan |
| `audit_queries.sql` | Kueri audit integritas data (AQ-01..AQ-28), dapat dijalankan ulang |
| `architecture.md` | Peta arsitektur hasil orientasi (endpoint, izin, aturan domain) |
| `decisions.md` | Asumsi & keputusan (termasuk inkonsistensi spesifikasi §6) |

## Skrip uji

| Skrip | Cakupan |
|---|---|
| `reset-backend-qa.sh` | Bangun ulang DB uji deterministik (`/tmp/opencode/hsqa/qa.db`) |
| `backend-api-smoke.sh` | Adversarial API: auth, injeksi, otorisasi 2 lapis, stok, pagination (73) |
| `backend-boundaries.sh` | Batas persis domain (14/15 hari, kapasitas, layak, dll) (11) |
| `backend-e2e.sh` | Satu siklus utuh + rekonsiliasi angka (28) |
| `backend-concurrency.sh` | Balapan tulis: versi, idempotensi, stok habis (22) |
| `backend-pest-rotation.sh` | Unggahan, pindaian, rotasi MoA, terima/tolak + potong stok (109) |
| `perf.sh` | Latensi endpoint inti |
| `apps/backend/qa/fuzz-invariants.mjs` | Fuzz invarian §5.8 (638 pemeriksaan) |

## Cara menjalankan ulang (ringkas)

```bash
bash qa/reset-backend-qa.sh
cd apps/backend
DATABASE_URL=file:/tmp/opencode/hsqa/qa.db PORT=3100 \
  CLOUDINARY_CLOUD_NAME=hsqa CLOUDINARY_API_KEY=123456789012 \
  CLOUDINARY_API_SECRET=hsqa_secret_123 node --import tsx src/server.ts   # terminal lain

sqlite3 /tmp/opencode/hsqa/qa.db "DELETE FROM auth_rate_limits;"
BASE_URL=http://127.0.0.1:3100/api/v1 bash qa/backend-api-smoke.sh
BASE_URL=http://127.0.0.1:3100/api/v1 CLOUDINARY_API_SECRET=hsqa_secret_123 \
  bash qa/backend-pest-rotation.sh

cd apps/backend && node --import tsx qa/fuzz-invariants.mjs
cd apps/mobile  && flutter analyze && flutter test
python3 -m pytest ml/tests -q
sqlite3 -header /tmp/opencode/hsqa/qa.db < qa/audit_queries.sql
```

Detail lengkap per perintah ada di `testing.md` §0.

## Keselamatan data

- DB uji selalu di `/tmp/opencode/hsqa/` — **tidak** menyentuh data produksi
  (`apps/backend/data/`, Turso).
- Tidak memakai kredensial produksi; Cloudinary memakai kredensial **palsu** khusus uji.
