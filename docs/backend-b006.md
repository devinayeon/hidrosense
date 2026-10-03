# Implementasi Backend B006 — Stock Ledger

Tanggal: 3 Oktober 2026, Asia/Jakarta. Baseline workspace HEAD `35db8c0`. Scope: implementasi B006 lokal, sesudah permintaan pengguna meninjau empat artifak dan melanjutkan pengembangan. B007–B019 dan deployment remote terpisah.

## Ringkasan review empat artifak

| Artifak | Temuan/keputusan yang dipertahankan |
| --- | --- |
| [PRD](b006/prd-stock-ledger.md) | 12 FR dan 6 NFR; R1/R2 ditutup dengan skala 100, tanpa rounding, batas integer, satuan tetap, saldo atomik |
| [Arsitektur](b006/architecture-stock-ledger.md) | Fastify/Zod/libSQL, vertical slices, transaksi dan receipt B004, immutable sealed ledger, upgrade additive |
| [Tasks](b006/tasks-stock-ledger.md) | I-01–I-08, P-01–P-15; delegasi kontrak, migration dan HTTP; verifikasi multi-client serta failure injection |
| [Readiness](b006/readiness-report-b006-2026-10-03.md) | PASS perencanaan historis; tidak digunakan sebagai klaim deployment. Bukti runtime dicatat di laporan ini |

Pernyataan awal “refinement only / implementation pending” menjelaskan run perencanaan sebelumnya. Permintaan lanjutan mengizinkan kode, migrasi, tes dan dokumentasi B006. Kontrak tidak diperluas ke fase berikutnya.

## Perilaku dan lokasi perubahan

| Bagian | Implementasi |
| --- | --- |
| Kuantitas | `src/common/quantities.ts`: parser/formatter BigInt, skala 100, bounds 999999999999 atoms; reused oleh minimum inventory |
| Kontrak | `src/features/stock/contracts.ts`: schemas strict, 1–100 item unik, canonical sort dan keterangan, ID signed64 |
| Ledger/saldo | `stock/store.ts`: append dalam transaksi caller, bounded conditional update, detail positif dan seal, SQL TEXT untuk ID/atoms |
| Use case | `stock/service.ts`: create, whole reversal sekali, unit/active rules dan internal source consumption |
| Receipt/identity | `stock/write.ts`, `common/sync.ts`: mandatory key, current-auth replay, ledger/projection/receipt/UUID/version commit bersama; secondary linked stock mendapat UUID/version 1 |
| Availability | `stock/errors.ts`, `common/errors.ts`: driver/cause classification, 503 + Retry-After 1; rollback cleanup mempertahankan error utama di `authenticated-write.ts` |
| HTTP | `stock/index.ts`, `app.ts`: lima endpoint stok/saldo; izin `inventaris:read/write`; [kontrak API](backend-stock-api.md) |
| Inventory | `inventory/inventaris.ts`, `inventory/store.ts`: minimum exact companion, unit lock setelah history, respons desimal dari atoms |
| Rekonsiliasi | `stock/reconcile.ts`: read-only snapshot, paginated chronological BigInt fold, report drift/missing projection/unsealed header; tanpa reset otomatis |

Ledger original tidak berubah saat reversal. Koreksi pengganti memakai operasi kedua dan keterangan referensi; bukan transaksi replacement gabungan. Konsumsi penyemaian/perawatan menggunakan transaksi aktif, unique origin dan identitas stok sekunder; domain pemilik pada B007/B014 bertanggung jawab atas auth, primary receipt dan state domain.

## Migrasi 0006 dan recovery

Pasangan `apps/backend/migrations/0006_stock_ledger.{up,down}.sql` menambah `sealed`, `reversal_of`, detail quantity/unit companions, minimum companion, `stok_saldo`, indeks dan triggers. Migrasi 0001–0005 tidak ditulis ulang. Upgrade memvalidasi stock header/detail/minimum dan prefix balance; angka legacy dibaca sebagai canonical numeric text, dipecah digit integer, tanpa REAL × 100 atau ROUND. Ketidakcocokan abort dalam transaksi runner.

Upgrade mempertahankan ID/FK/sequences, nilai kolom lama, receipt dan identity yang sudah ada; melengkapi stock UUID/version yang hilang tanpa membuat receipt historis. Waktu UTC legacy divalidasi dan dirender ISO tanpa mengganti nilai lama. Keystroke desimal dan perubahan unit historis yang sudah hilang karena penyimpanan lama tidak dapat direkonstruksi.

Triggers menolak UPDATE/DELETE audit, REPLACE yang menghapus audit, late detail insert, detail companions invalid, reversal tidak identik dan perubahan unit bersejarah. Projection dipelihara oleh trusted writer dalam transaksi; privileged raw SQL tetap memerlukan maintenance/reconciliation. Guarded down hanya boleh pada state kosong tanpa stock ledger/projection/identity/version/mapping/receipt yang akan hilang. Populated upgrade memakai forward repair; down tidak menghapus audit agar berhasil.

## Bukti verifikasi lokal

Final `npm run check`: **153/153 PASS**, 0 fail/cancelled/skipped/todo, durasi suite sekitar 52,2 detik. Termasuk **68 tes stok baru dan 85 regresi existing**. Typecheck dan check:lines lulus; file kode terbesar 288 baris, maksimum 400. `npm run build` lulus (`tsc`, exit 0). Waktu suite adalah bukti eksekusi lokal, bukan benchmark API atau SLA.

| Suite B006 | Tes lulus |
| --- | --- |
| Contracts | 5 |
| Migration | 34 |
| HTTP/business + sync/rollback | 18 |
| Independent-process concurrency | 2 |
| Failures/retry/transport | 7 |
| Read-only reconciliation | 2 |
| Total B006 | 68 |

| Proof | File test / verifikasi |
| --- | --- |
| P-01/02 exact arithmetic dan bounds | `stock-contracts.test.js`, `stock.test.js`, `stock-reconcile.test.js` |
| P-03/08 rollback multi-line/detail/seal/mapping/version/receipt | `stock-sync.test.js` |
| P-04/05 independent writers / identical-key concurrency | `stock-concurrency.test.js`: dua koneksi file-backed dalam proses terpisah |
| P-06/07 response loss, replay, actor namespace/canonical conflict | `stock-sync.test.js`, `stock-failures.test.js` |
| P-09/10 immutable reversal/unit lock/sealing | `stock.test.js`, `stock-sync.test.js`, `stock-migration.test.js` |
| P-11 linked/inactive rules | `stock-sync.test.js`, `stock.test.js` |
| P-12 permissions/signed64/read response | `stock.test.js`, `stock-sync.test.js`, suite auth sebelumnya |
| P-13 populated upgrade/invalid legacy/down guards/preservation | `stock-migration.test.js`; historical 0005 rollback test tetap scoped ke lima migrasi pertama |
| P-14 exact minimum/projection/reconciliation | `stock.test.js`, `stock-reconcile.test.js` |
| P-15 contention/uncertain results | real local lock, actual fetch socket loss, injected durable-success commit loss dan rollback failure dalam `stock-failures.test.js` |

P-15 transport test memakai socket lokal yang benar-benar diputus; ambiguous-commit test memproksikan commit database lokal yang benar-benar sukses sebelum melempar error. Bukti tersebut tidak mewakili percobaan remote Turso. Tes rekonsiliasi memeriksa drift dan menjamin tidak ada implicit repair.

Review independent meliputi kontrak dan migration/atomicity; scoped re-review tidak menyisakan temuan. Temuan runtime yang diperbaiki: cause socket Undici menjadi retry503; UUID/version secondary linked consumption dibuat dalam transaksi; rollback cleanup tidak menutupi error utama. Fixture concurrency memakai proses terpisah agar handle SQLite native ditutup deterministik di Windows. Review dokumentasi menambahkan kode konflik identity yang sempat belum tercantum; tabel API sekarang sesuai PRD/implementasi.

Pemeriksaan tautan/whitespace enam dokumen B006 dan scoped diff lulus. `graphify update .` selesai tanpa LLM: 2092 nodes, 3127 edges, 193 communities. Graph kode AST diperbarui; 12 file SQL tidak diekstrak karena `tree_sitter_sql` belum terpasang. Warning parser pada header mobile di luar B006 dan label komunitas lama dicatat oleh tool; tidak ada klaim ekstraksi SQL, semantic docs, atau label LLM baru. Migrasi divalidasi melalui 34 tes SQL, bukan graph.

## Deployment yang belum dilakukan

Remote migrations 0001–0005 telah applied menurut [bukti sebelumnya](deployment-turso-migrations.md). **Migrasi 0006 belum diterapkan ke remote dalam run ini.** Tidak ada kredensial production diakses atau operasi live stock dijalankan.

Deployment memerlukan disposable staging Turso: populated preflight, snapshot/restore proof, apply0006, reconciliation, independent writers/response-loss, workload measurement, health/schema evidence. Ikuti deployment/recovery sequence pada arsitektur, hentikan stock writer lama dan deploy B005 companion writer bersama B006. Jangan menjalankan down pada ledger populated atau mengaktifkan mixed old/new writers.

## Skills dan pelaksanaan

Graphify query digunakan untuk orientasi; graph di-refresh setelah kode berubah. `npx skills use "https://github.com/vercel-labs/skills" --skill "find-skills"` dijalankan dengan output lengkap dibaca pada aktivitas review, implementasi, migration, tests dan verifikasi; tidak ada supporting-files relatif pada output. Existing backend guidelines, migration, nodejs backend patterns dan TypeScript guidance dipakai sesuai stack proyek, tanpa menambahkan ORM/framework.

Skill caveman-learn dibaca. `caveman learn report --json` tidak dapat dijalankan karena CLI tidak tersedia. Tidak ada laporan biaya/savings atau perubahan konfigurasi optimasi yang diklaim. Pekerjaan B006 memakai todo/task dan delegasi terpisah; perubahan workspace lain dipertahankan.
