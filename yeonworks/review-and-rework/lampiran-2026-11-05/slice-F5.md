# Slice F5: comments and readability (goals 10 and 11)

Scope: `apps/backend/src` (88 files) and `apps/mobile/lib` (143 files). Read-only review. Scripts live in `...\scratchpad\review2\f5\` (`count.sh`, `exports.sh`).

## Goal verdicts

| Goal | Backend | Mobile | Evidence |
|---|---|---|---|
| 10. Important and basic blocks carry comments | Partly | Not met | Backend: the comments that exist are good "why" comments, but they cover security and infra edge cases, not the plan's domain rules. Only 22 of 197 exported declarations and 4 of 60 route handlers have a comment above them. Mobile: 52 comment lines in about 6,750 lines of data, core, model and view-model code (0.8%); 185 of the 237 comment lines sit in `views/` and mostly narrate layout. |
| 11. Flow easy for another team and non-technical readers | Partly | Not met | Backend feature folders are consistent (`index` route, `service` rules, `store` SQL) and `apps/backend/API.md` is a good Indonesian contract. But there is no entry-point doc, no glossary, and the idempotency core (`common/sync.ts`) is dense and unexplained. Mobile has no map of folders and no explanation of the retry-command pattern that appears in 6 view models. |

## 0. Measurements (verified with my own script)

Rule used: a comment line starts (after spaces) with `//`, `///`, `/*` or `*`. Doc comments are lines starting `///` or `/**`.

| | Files | Lines | Comment lines | Doc-comment lines | Files with zero comments |
|---|---|---|---|---|---|
| `apps/backend/src` (.ts) | 88 | 4,613 | 133 (2.9%) | 26 | 50 (57%) |
| `apps/mobile/lib` (.dart) | 143 | 23,199 | 237 (1.0%) | 142 | 82 (57%) |

Both match the figures in the brief. More detail, all VERIFIED:

- Backend: 60 route handlers, 4 with a comment (all in `features/nursery/index.ts`). About 138 `sql:` statements, 3 with a comment above. 197 exported declarations, 22 with a comment above. Migrations: 15 `.up.sql` files, 24 comment lines in total; `0004`, `0011`, `0012`, `0013` have none.
- Mobile: 142 `///` lines but 107 are in `views/` (theme, glass container, widget parameter docs). Only 35 `///` lines are in `data/`, `core/`, `features/`, `viewmodels/`, `models/`. Of 237 comments, 16 are numbered layout labels ("// 3. Section Prakiraan Harian"), 10 are decorative separators (`// ─── Alert semaian ───`).
- Backend comment language: 0 of 133 lines contain Indonesian words, so all English. User-facing messages and `API.md` are Indonesian.
- Mobile comment language: about 132 of 237 lines look Indonesian, the rest English. 10 files mix both inside one file (for example `session_viewmodel.dart`, `connected_inventory_viewmodel.dart`, `bmkg_weather_service.dart`, `dashboard_body.dart`). User-facing strings: Indonesian.

## Findings

### F5-1 [GOAL 10] The plan's core business rules have no comment in either app
- Severity: high
- Status: VERIFIED
- Where: `apps/backend/src/features/transfers/service.ts:45` and `transfers/store.ts:9,12-14,42-46`; `nursery/store.ts:27,89`; `stock/store.ts:97-129`; `harvest/service.ts:9-30`; `tables/store.ts:16-24`; `common/money.ts:33`; mobile `views/widgets/seedling_transfer_sheet.dart:62-66,230,456`.
- What: Batch, HSS/HST, 15-day sowing, 45-day harvest, active plants, table capacity, the stock ledger and sale totals are all implemented, but a reader cannot tell which line is the rule, why it exists, or which plan section it comes from. Example: `if (umurSemaiHari < 15)` has no named constant; `HARVEST_STANDARD_DAYS = 45` is named but not explained; "tanaman aktif" is the SQL expression `batchActive` that nothing describes in words. `HSS` is expanded only in the plan document (line 447); `HST` is defined nowhere in the repo.
- Evidence: `grep -rn "Hari Setelah"` over `apps/` finds no definition of HSS or HST. The 15-day rule appears as bare literal `15` in 4 backend places and 3 mobile places (list in F5-5). The 250-hole figure appears only as a seed default (`db/seed.ts:143`) and a form default (`form_meja_nft_body.dart:34`); neither says where it comes from.
- Suggested fix: add one rule comment per rule (format in section 5), starting with the 25 blocks listed below. About 1 to 2 days for both apps.

### F5-2 [GOAL 11] No entry-point documents and no glossary; `GLOSSARY.md` was deleted on purpose
- Severity: high
- Status: VERIFIED
- Where: repo root `README.md` (7 lines), `apps/backend/README.md`, `apps/mobile/README.md`, deleted `GLOSSARY.md`.
- What: The three READMEs are setup guides only. None has a folder map, a "how a request flows" page, or a list of Indonesian domain terms. `GLOSSARY.md` existed (added in commit `8d415af`, removed in `a6c9bf3` "Keep only the setup and getting started guides", 2026-10-28). It had 25 lines and covered only stock terms (transaksi stok, saldo, reversal, koreksi, asal konsumsi), not batch, HSS, HST, meja tanam, penyemaian, pemindahan, panen or penjualan. The deleted `docs/b006/*` files are still cited by comments (F5-7).
- Evidence: `git log --all -- GLOSSARY.md`; `git show a6c9bf3^:GLOSSARY.md`; `grep -n "Hari Setelah"` finds nothing; README bodies read in full. The best navigation aid that exists is `apps/backend/API.md` (214 lines, Indonesian, accurate against the 60 routes I listed) and `docs/panduan-menjalankan-backend.md`.
- Suggested fix: one `docs/alur-dan-istilah.md` (or per-app `ARSITEKTUR.md`) with a folder map, the glossary table in section 4, and the five flow descriptions in section 3. Half a day.

### F5-3 [GOAL 11, 10] Mobile retry-command pattern is undocumented and repeated 6 times; the "offline queue" a reader looks for does not exist
- Severity: high
- Status: VERIFIED
- Where: `viewmodels/connected_inventory_viewmodel.dart:19-22,190-277`; `connected_nursery_viewmodel.dart:20-62,231-315`; `panen_viewmodel.dart:47-61,247-345`; `damage_viewmodel.dart:34-50`; `connected_table_viewmodel.dart:84-95`; `sowing_draft.dart:39-46`; also `inventory_draft.dart`.
- What: Every write goes through a "command" object with `key`, `attempt`, `uncertain`, `receipt`, `running`. It exists to resend the same `Idempotency-Key` when the answer to a save was lost. The word `uncertain` appears 45 times in 11 files. Not one comment explains the idea. A non-technical reader, or a developer looking for the plan's PB-07 "offline queue", will search for a queue and find nothing: `data/services/inventory_cache.dart:17` says the cache "stores neither sessions nor queued mutations", and the commands live only in Riverpod providers in memory. So the app today needs the network for every write and keeps retry state only until the process dies. No document says this.
- Evidence: `grep -rc uncertain lib` (45 hits); `grep -rn "recordStockMovement\|queue" lib`; read of the five files above.
- Suggested fix: put one 15-line comment on a shared base explanation (or a doc paragraph) that says: what a command is, what `uncertain` means (request sent, answer not seen, so retry must reuse the same key and body), what `attempt` guards (a late reply from an older attempt is ignored), and that nothing survives an app restart. Then one line in each of the 6 classes pointing to it. 2 to 3 hours.

### F5-4 [GOAL 11] The idempotency core is the hardest code to read and has the fewest explanations
- Severity: high
- Status: VERIFIED
- Where: `apps/backend/src/common/sync.ts:23-93` (`executeOperation`), `:138-171` (`executeDomainMutation`).
- What: These two functions implement idempotency, replay, client-id to public-id mapping and optimistic version checks, which are the plan's PB-07 acceptance criteria. `executeOperation` is 70 lines with about 28 branches, a legacy-hash path (`legacyHash`, `legacyMatch`, `priorCasingMatches`, lines 49-66) and no function comment. The reader needs 5 helper names to follow it. The inline comments explain upper-case key handling but not the main idea (what is stored, what a retry returns, what a conflict means).
- Evidence: Read in full. Every one of the six `*/write.ts` wrappers (`stock`, `nursery`, `transfers`, `damage`, `harvest`, `sales`) calls this path, so every create flow in section 3 passes through it.
- Suggested fix: a 10-line header on `executeOperation` (what a "receipt" is, replay rule, conflict rule, why legacy matches exist and when they can be deleted) and a 6-line header on `executeDomainMutation` (public id, version, `expectedVersion` absent means last write wins). 1 to 2 hours.

### F5-5 [GOAL 10] The 15-day and 45-day rules are enforced in two layers as bare numbers
- Severity: medium
- Status: VERIFIED
- Where: backend `nursery/store.ts:27` (`age >= 15`), `nursery/store.ts:89` (`julianday(...) - 15`), `transfers/service.ts:45` (`< 15`), `transfers/store.ts:9` (45); mobile `seedling_transfer_sheet.dart:65` (`days: 15`), `:230` (message text "15 hari"), `:456` (`days: 45`), `models/seeding_batch_model.dart:24,50` and `views/pages/info_seeding_page.dart:81` (`totalHss = 15`).
- What: The same two numbers sit in 9 places across two languages. The server is the authority, the app repeats the rule to give early feedback, and nothing says so. A change from 15 to 14 days needs a search for the digit.
- Evidence: `grep -rnE "\b(15|45)\b"` filtered for noise (command in section 3).
- Suggested fix: backend constants `MIN_SOWING_AGE_DAYS = 15` and `HARVEST_STANDARD_DAYS = 45` in one file with a plan reference; mobile constants with a comment "mirror of backend rule; server decides". Better still, the app should read `siap_pindah` and `estimasi_panen` from the API (it already receives both). 1 hour.

### F5-6 [GOAL 11] Very long, dense lines concentrate in the harvest code
- Severity: medium
- Status: VERIFIED
- Where: backend `features/harvest/service.ts:13,19,22,39,47`; `features/harvest/contracts.ts:17,18`; mobile `panen_form_body.dart:434`, `detail_tanaman_meja_body.dart:170`.
- What: Backend has 18 lines over 160 characters; 7 of the top 15 are in `features/harvest/`. Mobile has only 2 lines over 160 characters (`panen_form_body.dart:434`, `detail_tanaman_meja_body.dart:170`); the Dart formatter keeps the rest short. `harvest/service.ts:13` is a 404-character line holding a SQL statement with two correlated subqueries, and it sits inside a `for` loop in a function with no comment. `harvest/service.ts:40` packs `let sold = 0n; for (...) {` on one line, and `:44` is a one-line `if ... throw` with a reduce.
- Evidence: Character-aware count with Python (plain `awk length` counts bytes and wrongly flags UTF-8 box-drawing separator comments, for example `dashboard_body.dart:351,353`, which are under 160 characters).
- Suggested fix: when the file is next touched, break SQL into named constants and split the lines. The duplicate-logic side is in the backend report, not repeated here. 1 to 2 hours.

### F5-7 [GOAL 10] Stale, misleading or placeholder comments
- Severity: medium
- Status: VERIFIED (each item quoted from code)
- Where and what:
  - `apps/backend/migrations/0001_initial_schema.up.sql:1-2`: "Adapted from docs/database/hidrosense.dbml ... See apps/backend/README.md for type mapping and limitations." `docs/database/` no longer exists (the file moved to `apps/backend/test-support/hidrosense.dbml` in `a6c9bf3`) and the README no longer has a type-mapping section (`grep -ci "type mapping" apps/backend/README.md` returns 0).
  - Ticket codes with deleted source documents: `stock/service.ts:15` ("B007/B014 use their primary domain receipt"), `nursery/service.ts:30` ("B006 recordMovement"), `db/seed.ts:79,103,128,140,150` and `seed-cli.ts:26` ("B000-B009"), migration `0006` header and every object it creates (`_b006_guard`, triggers `b006_header_insert`, `b006_detail_update`, and so on). The `docs/b006/` folder that defined these codes was deleted in `a6c9bf3`. A new reader cannot decode them, and the trigger names are permanent schema identifiers.
  - `features/nursery/write.ts:10`: "mandatory Idempotency-Key for create". The code calls `requireIdempotencyKey` for every nursery write, including update. `API.md` says all POST and PATCH. The comment is narrower than the code.
  - `common/permissions.ts:1-3`: describes petani and pegawai in terms of inventaris and penyemaian only; the table below it also grants `budidaya:write`, `panen:write` and (petani) penjualan, deteksi, rekomendasi. The header mentions "System Request" without a document reference.
  - `mobile viewmodels/session_viewmodel.dart:72-76`: an `if` block that contains only a 3-line comment about `adb reverse` and no statement. The comment describes behaviour that is not there (placeholder).
  - `mobile views/widgets/stock_status_badge.dart:3,6,18`: "Sesuaikan relative path jika berbeda" (an instruction to a person, left in), a commented-out enum `// enum StockStatus ...`, and "// Di file stock_status_badge.dart".
  - `models/meja_nft_model.dart:1`, `views/pages/meja_nft_page.dart:1`, `meja_nft_card_content.dart:1`: first line only repeats the file path.
  - `mobile data/models/inventory_record.dart:1` says "IDs and quantities never pass through floating point." `data/models/sale_record.dart:88,90,188` and `catat_penjualan_viewmodel.dart:27-29` (`beratKg * 100` with a `1e-6` tolerance) hold weight and rupiah as `double`. The stated rule is true for inventory and false for sales; no comment says the sales path is different on purpose.
  - Restating comments (low value): `connected_inventory_viewmodel.dart:45,49,53` ("Records yang aktif"), `nursery/service.ts:21` and `:29`, `transfers/service.ts` numbered "1. Fetch & validate penyemaian" steps (they narrate the code instead of giving the rule).
- Suggested fix: fix or delete each item (about 1 hour); rename future triggers by meaning (`stok_header_tidak_boleh_diubah`) rather than by ticket.

### F5-8 [GOAL 10] No comment-language policy; mobile mixes two languages inside single files
- Severity: medium
- Status: VERIFIED
- Where: see section 0 and section 2.
- What: Backend comments are English, mobile comments roughly half Indonesian, user messages and docs Indonesian, plan document Indonesian. Readers are Indonesian students and non-technical stakeholders.
- Suggested fix: adopt Indonesian for comments (section 5). 10 minutes to write the rule; convert files as they are touched.

### F5-9 [GOAL 10] Mobile comments narrate layout; logic files have almost none; this also breaks the repo's own antislop rule
- Severity: low
- Status: VERIFIED
- Where: `views/components/cuaca_body.dart:62-262`, `catat_penjualan_body.dart:410-554`, `rekomendasi_cuaca_body.dart:26-169`, `dashboard_body.dart:111-353`, `header.dart:47,118`.
- What: 78% of mobile comment lines are in `views/`. Many are numbered section labels or ruled separators ("// ─── Statistik semaian ───"), which `.agents/skills/antislop-code/SKILL.md` lists as tells to remove (Decorative Separators, Workflow Narration). Meanwhile `viewmodels/`, `data/repositories/`, `data/models/` carry the money, weight, date and retry logic with 52 comment lines in total.
- Suggested fix: spend comments where the rules are (section 1); do not add more layout labels.

### F5-10 [GOAL 11] Terminology drift: one concept, three or four names
- Severity: medium
- Status: VERIFIED
- Where: across both apps; table in section 4.
- What: sowing is `penyemaian` (table, route, permission, Dart UI file names), `nursery` (backend folder, mobile `connected_nursery_viewmodel`), `sowing` (functions `createSowing`, Dart `SowingRecord`), and "batch" in the UI (`'Batch #$id'`). Transfer is `pemindahan` / `transfers` / `TransferRecord`. Harvest is `panen` / `harvest` / `HarvestRecord`. Table is `meja_tanam` / `tables` / `TableRecord` / `meja_nft` / `MejaNft`. Quantities are "minor units" (`jumlah_minor`, `toMinor`), "scale-100 atoms" (`common/quantities.ts:6`, `weights.ts:4`) and "scaled" (`weightScaled`). The same weight rule is called "berat_layak", "layak", "saleable" and "stokTersedia" in four layers. "Batch" in the plan means a transfer (`pemindahan`), but the UI names a sowing "Batch #id" too; `sales` uses `id_panen` for the "batch" field (`API.md`: "Batch, berat, dan harga harus diisi bersama" refers to a harvest).
- Suggested fix: the glossary in section 4 and a rule "new code uses the DB word for domain nouns".

### F5-11 [GOAL 11] No map of the mobile folders; two homes for models and three for UI pieces
- Severity: medium
- Status: VERIFIED
- Where: `apps/mobile/lib/` has `models/` (5 legacy files) next to `data/models/` (11), `features/` (2 folders) next to flat `viewmodels/` and `views/{components,pages,widgets}` (about 100 files). The 5 legacy files in `lib/models/` are still imported by 9 other files, so they are not dead.
- What: A newcomer cannot tell where a screen's logic lives. Example for "create a sowing": page in `views/pages/seeding_form_page.dart`, rules in `viewmodels/sowing_draft.dart`, retry logic in `viewmodels/connected_nursery_viewmodel.dart`, HTTP in `data/repositories/nursery_repository.dart`, model in `data/models/nursery_record.dart`, plus a second model `models/seeding_batch_model.dart` used by the info page. No document gives this chain.
- Suggested fix: add the folder map and the five flows (section 3) to the new doc from F5-2.

### F5-12 [GOAL 11] README accuracy: correct but incomplete
- Severity: low
- Status: VERIFIED
- Where: `apps/backend/README.md:44`, root `README.md`, `apps/mobile/README.md`.
- What: Every command in the backend README exists in `package.json` (`db:migrate`, `db:seed`, `dev`, `build`, `start`, `auth:bootstrap`), the Node version matches (`>=22.13.0`), and the claim "Server menolak startup jika masih ada migrasi tertunda" matches `server.ts:12`. The mobile README matches `API_BASE_URL` and `BMKG_ADM4` in code. Gaps: the backend README lists `.env` keys as `NODE_ENV, HOST, PORT, LOG_LEVEL, CORS_ORIGINS, TRUSTED_PROXIES` but `.env.example` also has `DATABASE_URL`, `DATABASE_AUTH_TOKEN`, `TRUST_PROXY_HOPS`. The root README has no folder map for `apps/`, `ml/`, `docs/`, `hidrosense-plan-docs/`, `yeonworks/`. Root `AGENTS.md` and `CLAUDE.md` are instructions for AI agents, not for people.
- Suggested fix: add the three missing keys and a 10-line folder map. 20 minutes.

### F5-13 [GOAL 10] SQL with business rules is almost never commented; schema triggers carry rules without names
- Severity: medium
- Status: VERIFIED
- Where: backend: 3 of about 138 `sql:` statements have a comment above; migrations `0006` triggers (`b006_header_insert` ... `b006_minimum_update`), `0012_table_occupancy_status.up.sql` (the "full table" rule written a third time), `refresh.ts:16-23` (the `MIN(?,created_at+?)` expiry clamp, one line of comment for 8 lines of SQL).
- What: The stock ledger immutability rule lives in two places, SQL triggers (`0006:99-150`) and TypeScript (`stock/service.ts:24`, `store.ts:101-104`), and neither points to the other. The two-phase write in `appendMovement` (insert header with `sealed=0`, insert lines, then `sealed=1`) only makes sense with the trigger, and no comment says so.
- Suggested fix: one comment per rule at both ends, naming the other end. See example B in section 5.

## 1. Top 25 uncommented blocks per app

Definition applied: an "important or basic block" is an exported function or class; a route handler; a SQL statement that encodes a business rule; a status change; a money, weight, date or capacity calculation; a transaction boundary; or a rule enforced in two layers. Ranked by importance to the plan (batch, HSS, 15/45 days, 250 holes, stock ledger, idempotency, offline queue).

### Backend

| # | file:line | What the comment must say |
|---|---|---|
| 1 | `common/sync.ts:23-93` executeOperation | Receipt model: same key plus same body returns the stored result with `replayed: true`; same key plus other body is `409`; why the legacy hash and casing paths exist and when they can go. |
| 2 | `common/sync.ts:138-171` executeDomainMutation | Public id and version per record; `expectedVersion` absent means last write wins; present and different means `VERSION_CONFLICT`. |
| 3 | `stock/store.ts:97-129` appendMovement | The ledger only grows: header is inserted `sealed=0`, lines added, then sealed; the balance is a projection that must always equal the sum of lines. |
| 4 | `stock/store.ts:116-122` guarded UPDATE | The `BETWEEN 0 AND 999999999999` check is what makes "cannot use more than in stock" safe under concurrent writes. |
| 5 | `stock/service.ts:21-31` reverseMovement | A correction is a new opposite movement; sowing-origin movements cannot be reversed here, they are corrected through their owner. |
| 6 | `stock/service.ts:7-19` recordMovement | Domain callers (penyemaian) may only consume (`keluar`); `origin` links the movement to its owner and prevents double consumption. |
| 7 | `transfers/service.ts:16-91` createTransfer | One-sentence summary of the 7 checks; the rule list: sowing active, age at least 15 days, seedlings left, table available, table capacity (holes), auto-finish sowing. |
| 8 | `transfers/service.ts:45` and `nursery/store.ts:27,89` | "15 days after sowing (HSS) before seedlings may be moved" with plan reference. |
| 9 | `transfers/store.ts:9,42-46` | 45 days from sowing date is the planned harvest date; definitions of HSS (days since sowing) and HST (days since transfer). |
| 10 | `transfers/store.ts:12-14` batchActive | "Active plants" = moved minus damaged minus harvested; same formula in `tables/store.ts:7`, `harvest/service.ts:13`, `damage/service.ts:43`, migration `0012`. |
| 11 | `transfers/service.ts:76-88` | Why table status and two derived-change records are written after the insert; sowing becomes `selesai` once everything is moved (state change). |
| 12 | `tables/store.ts:16-24` occupancyStatus, effectiveStatusSql | `penuh` is derived (active plants at or above the hole count), other statuses are manual and never overwritten. |
| 13 | `tables/store.ts:25-37` tableRow | What `saldo_valid: false` means and why such a table is still listed. |
| 14 | `harvest/service.ts:9-30` createHarvest | Per row: harvest date not before transfer, count not above active plants; one `panen` header plus detail rows; table status and change log updated. |
| 15 | `harvest/service.ts:21` | Sellable weight (`berat_layak`) = total weight minus reject weight; both stored in hundredths of a kilogram. |
| 16 | `harvest/service.ts:31-51` updateHarvest + `:44` | A harvest cannot be edited below the weight already sold. |
| 17 | `harvest/store.ts:27-61` harvestResponse | `rejectKnown`: old rows without reject weight produce null totals instead of wrong totals. |
| 18 | `sales/service.ts:17-36` harvestForSale | A harvest is sellable only when every line has a known good weight. |
| 19 | `sales/service.ts:38-63` soldForHarvest | Legacy rows stored kg as text; they are read only if the value round-trips exactly. |
| 20 | `sales/service.ts:65-81` validateLine | Sale date not before harvest date; weight not above remaining sellable weight; error message gives the remainder. |
| 21 | `common/money.ts:33-35` saleLineTotal | Line total = kg x price per kg, in hundredths, rounded half up. |
| 22 | `common/quantities.ts:3`, `common/weights.ts:2`, `money.ts:16-17` | Why numbers are stored as integer hundredths ("minor"), the maximum values, and why no floating point. |
| 23 | `damage/service.ts:16-58, 60-122` | Damage cannot exceed active plants; lowering a damage count gives plants back and must still fit the table's holes. |
| 24 | `features/sync/changes.ts:28-67` | Cursor protocol: device sends last cursor, gets record names only, re-reads through the permission-checked API; `SYNC_CURSOR_RESET` means reload everything. |
| 25 | `features/auth/refresh.ts:16-23`, `app.ts:78-94` | Session clamp (7 days since refresh, 30 since login, in `sessions.ts:7-10`); 120 requests per minute per IP and HTTPS rule in production. |

### Mobile

| # | file:line | What the comment must say |
|---|---|---|
| 1 | `data/services/api_client.dart:205-271` _authRequest | Refresh flow: on `401` rotate the token once, retry once, then end the session; `_generation` makes a late answer from an old session harmless. |
| 2 | `data/services/api_client.dart:55-63,182-203` | What `_generation`, `_refreshing`, `requireSessionGeneration` guard; refresh tokens are single use. |
| 3 | `viewmodels/connected_inventory_viewmodel.dart:190-277` saveItem | Two-step save (item, then opening stock); which step is unconfirmed (`uncertain`); `canFinishWithoutStock` exit; same keys reused on retry. |
| 4 | `viewmodels/connected_inventory_viewmodel.dart:237-248` | This is the only place the app writes stock (opening balance at item creation). |
| 5 | `viewmodels/connected_nursery_viewmodel.dart:231-315` saveSowing | Create or update with one key; sowing consumes seed stock on the server, so inventory is refreshed afterwards. |
| 6 | `viewmodels/connected_nursery_viewmodel.dart:20-62,168-194` | Transfer command lifecycle: start, complete, fail; `definitivelyRejected` (4xx) allows a new key, anything else forces the same-key retry. |
| 7 | `viewmodels/connected_nursery_viewmodel.dart:344-363` | The midnight Jakarta timer exists because HSS ("days after sowing") changes at midnight, so the list must reload. |
| 8 | `viewmodels/sowing_draft.dart:19-36` errors | Local checks mirror the server: date not in the future, 1 to 1,000,000 seeds, stock amount with 2 decimals. |
| 9 | `viewmodels/sowing_draft.dart:39-46` SowingCommand | See F5-3. |
| 10 | `views/widgets/seedling_transfer_sheet.dart:62-66,215-232` | 15-day rule (mirror of server), date window from day 15 to today. |
| 11 | `views/widgets/seedling_transfer_sheet.dart:456` | "45 HSS" harvest estimate is a fixed planning number from the plan. |
| 12 | `data/models/nursery_record.dart:58-66` canTransfer, statusLabel | Ready to move = active, age at least 15 days, seedlings remaining. |
| 13 | `data/models/transfer_record.dart:57-63` | Meaning of `activePlants`, `hss`, `hst`, `seedlingAgeDays` and which come from the server. |
| 14 | `viewmodels/panen_viewmodel.dart:136-169` validateDraft | Mirror of the server checks: 1 to 100 distinct batches, count not above active plants, date not before transfer, reject not above total. |
| 15 | `viewmodels/panen_viewmodel.dart:37-54` _merge | Server rows and local receipts are merged by version; the higher version wins. |
| 16 | `viewmodels/panen_viewmodel.dart:247-345` _save | Same key and same body retry; a changed body while `uncertain` is refused. |
| 17 | `data/models/harvest_record.dart:22-60` HarvestWeight | Weights are exact hundredths in `BigInt`; `ui: true` accepts a comma. |
| 18 | `viewmodels/catat_penjualan_viewmodel.dart:27-48` | Float tolerance check for two decimals; why `double` is used here and `BigInt` for harvest (see F5-7). |
| 19 | `viewmodels/catat_penjualan_viewmodel.dart:36` (`totalEstimasi`) and `data/models/sale_record.dart:133` | Totals on screen are estimates; the server total (`total_harga`) is the record. |
| 20 | `viewmodels/catat_penjualan_viewmodel.dart:55-130` submitPenjualan | Create vs edit; multi-batch sales can only change the header. |
| 21 | `viewmodels/session_viewmodel.dart:66-94` resolveApiBaseUri | Order: dart-define, debug default, otherwise empty (and then every call fails with CONFIGURATION). Remove the empty `if`. |
| 22 | `viewmodels/session_viewmodel.dart:128-169` | `_operation` counter drops stale replies; logout clears the screen first, server revoke second. |
| 23 | `core/business_date.dart:1-18` | Farm time is UTC+7; why not device time. |
| 24 | `data/services/inventory_cache.dart` (whole file) | What is cached, what is not (no tokens, no writes), when the cache is shown (flag `cached`). |
| 25 | `viewmodels/damage_viewmodel.dart:34-50,183-260` and `connected_table_viewmodel.dart:84-95,176-245` | Same command pattern as F5-3; damage refreshes the table because active plants change. |

## 2. Comment quality and language

What is good (backend): the 107 plain comments explain intent, not code. Examples: `login.ts:14-17` (why the rate limit key includes the username, and the accepted gap), `refresh.ts:14` ("One conditional write makes concurrent refresh single-use"), `sync.ts:95-98`, `stock/errors.ts:1`, `serverless.ts:11-13`, `sessions.ts:7-10`, `tables/store.ts:6`. This is the style to copy. The gap is subject matter: nearly all of it is security, concurrency and infrastructure; the farm rules are bare.

What is weak:
- Restating: `nursery/service.ts:21`, `connected_inventory_viewmodel.dart:45,49,53`, `catat_penjualan_body.dart:410-554` (numbered form field labels), `info_card_md.dart:33-55` ("Text Atas / Tengah / Bawah").
- Stale or wrong: see F5-7 (8 items).
- Placeholder: `session_viewmodel.dart:72-76`, `stock_status_badge.dart:3,6,18`.
- Numbered step narration in `transfers/service.ts` (7 steps), `damage/service.ts` (2 steps), `seed.ts` (9 steps). Those steps do carry rule content in `transfers/service.ts`, so keep the rule, drop the numbering.
- TODO or FIXME markers: none found (`grep -rniE "TODO|FIXME|XXX|HACK"` over both `src` and `lib` returns nothing).
- Language mix: backend all English; mobile mixed, with Indonesian in `employee_form_sheet.dart:109-110`, `catat_penjualan_body.dart`, `bmkg_weather_service.dart`, `formatting.dart`, `weather_rules.dart` and English in `api_client.dart`, `session_viewmodel.dart`, `connected_inventory_viewmodel.dart`.

Recommendation: write code comments in Indonesian. Reasons: the readers are Indonesian students and non-technical partners; the plan, `API.md`, the setup guides, every user message and half of the existing mobile comments are already Indonesian; the farm rules come from Indonesian sources. Keep in English: identifiers, file names, error codes (`SEEDLING_NOT_READY`), commit messages and technical terms that have no common Indonesian word (idempotency key, rollback, cursor); write those in the sentence as is.

Identifiers: do not rename now. The database, routes, JSON fields and permissions already use Indonesian domain words (`penyemaian`, `pemindahan`, `meja_tanam`, `jumlah_tanaman`, `tanggal_semai`) and those are the shared language with the plan, so keep them wherever they cross a boundary (SQL, JSON, route, permission). Inside code, English helper names are fine (`createTransfer`, `activePlants`). Needed rules: (1) at every boundary file (`store.ts`, `*_repository.dart`, `*_record.dart`) put the mapping once in a comment or in the glossary; (2) pick one English word per domain noun and use it in new code (table below); (3) never mix both inside one name (`kodeTable`, `meja_table`).

## 3. Readability of the five main flows

Method: I followed each flow from the screen to the database. A "hop" is a move to another file. Steps in (A) are for a non-technical reader.

### Flow 1: login
- Files in order, mobile: `main.dart` -> `views/pages/app_gate.dart` -> `views/pages/login_page.dart:65-80` (`_submit`) -> `viewmodels/session_viewmodel.dart:140` (`login`) -> `data/services/api_client.dart:160` (`login`, `_request` :94, `_tokens` :149). Backend: `app.ts` -> `features/auth/index.ts` -> `auth/login.ts:12-30` -> `common/validation.ts`, `rate-limit.ts`, `passwords.ts`, `sessions.ts:50` (`createSession`), `maintenance.ts`.
- Hops: 5 mobile, 7 backend; 12 total. The route has an obvious entry (`login.ts`), 30 lines.
- Hard to follow: `app_gate.dart` swaps screens by watching `user == null` with a re-keyed Navigator and no comment on why; `api_client.dart` `_generation` (see Top 25 mobile 1-2); backend `createSession` INSERT ... SELECT (`sessions.ts:50-65`) that re-checks the account at commit time (one comment, good). `login.ts` is readable.
- Plain-language description: "The person types a username and password. The app sends them to the server. The server allows at most 10 tries per 15 minutes for that username from that address, finds the account, checks the password, and, if the account is active and a farmer or employee, creates a session with a short-lived access token (15 min) and a refresh token (7 days, 30 days at most). The app keeps both tokens only in memory. When the access token expires the app trades the refresh token for a new pair, once; if that fails the person is returned to the login screen."
- Verdict: backend easy; mobile medium (token rotation hard).

### Flow 2: record stock in
- Files, mobile: `views/pages/add_form_inventaris_page.dart` (630 lines) -> `viewmodels/inventory_draft.dart` -> `viewmodels/connected_inventory_viewmodel.dart:190` (`saveItem`) -> `data/repositories/inventory_repository.dart` (`createItem`, `recordStockMovement`) -> `api_client.dart`. Backend: `stock/index.ts:13` -> `stock/write.ts` -> `common/authenticated-write.ts` -> `common/sync.ts:138` -> `stock/service.ts:7` -> `stock/store.ts:97` -> `sync.ts:119` (`initializeStockIdentity`).
- Hops: 5 mobile, 7 backend; 12 total, the longest chain for a plain "add a number".
- Hard to follow: the 88-line `saveItem` with `uncertain`, `canFinishWithoutStock`, `attempt`; the `append` function mixes header, lines, balance and change log with no description of why the balance is updated before the line is inserted; `jumlah_minor` hundredths.
- Observation for the other reviewers (VERIFIED): the only call of `recordStockMovement` in the app is the opening balance when a new item is created (`connected_inventory_viewmodel.dart:237`, note "Saldo awal registrasi barang"). No mobile screen records a later delivery, a manual use, or a reversal, although the plan's PB-02 lists them and the server supports them (`POST /stok`, `/stok/:id/reverse`).
- Plain-language description: "Every change in stock is a new line in a book that is never erased. The balance is the total of all lines. Adding an item with an opening quantity writes the item first, then one 'in' line. If the answer is lost the app resends the same request with the same ticket number, and the server recognises the ticket and does not write twice. An 'out' line larger than the balance is refused. A mistake is fixed by adding an opposite line, never by editing."
- Verdict: backend medium (the ledger logic is compact but unexplained); mobile hard.

### Flow 3: create a sowing (consumes stock)
- Files, mobile: `views/pages/seeding_form_page.dart:104` -> `viewmodels/sowing_draft.dart` -> `viewmodels/connected_nursery_viewmodel.dart:231` -> `data/repositories/nursery_repository.dart:95` -> `api_client.dart` -> then `connected_inventory_viewmodel.dart` (inventory refresh via the closure at :338). Backend: `nursery/index.ts:17` -> `nursery/contracts.ts` -> `nursery/write.ts:13` -> `authenticated-write.ts` -> `sync.ts` -> `nursery/service.ts:12` -> `stock/service.ts:7` -> `stock/store.ts:97` -> `nursery/store.ts:57`.
- Hops: 6 mobile, 9 backend; 15 total. This is the deepest flow.
- Hard to follow: `saveSowing` (85 lines) nests a ternary create or update inside `command.receipt ?? (...)` inside a try; the refresh closure passed through a provider (`refreshInventory`) hides the fact that inventory is re-read because stock changed; on the server `createSowing` calls `recordMovement` which calls `appendMovement`, three names for one write.
- Plain-language description: "The farmer enters sowing date, seed count and which seed stock was used. The server checks the date is not in the future, writes the sowing as 'active', and in the same transaction takes the used quantity out of stock. If the stock is too low the whole thing is cancelled and nothing is saved. The app then reloads both the sowing list and the inventory list."
- Verdict: backend medium (good doc comment on `createSowing`); mobile hard.

### Flow 4: move seedlings to a table (pemindahan)
- Files, mobile: `views/widgets/seedling_transfer_sheet.dart` (513 lines; submit at :215-250) -> `connected_nursery_viewmodel.dart:168` (`submitTransfer`) -> `nursery_repository.dart:51` -> `api_client.dart`. Backend: `transfers/index.ts:19` -> `transfers/write.ts` -> `authenticated-write.ts` -> `sync.ts` -> `transfers/service.ts:16` -> `transfers/store.ts` (`countMovedSeedlings`, `countTableActive`, `insertTransfer`) -> `tables/store.ts:62` (`syncTableStatus`).
- Hops: 3 mobile, 8 backend; 11 total. Only `transfers/service.ts` is needed to understand the rules, and it is well structured (numbered checks) but without the "why".
- Hard to follow: bare `15`; `batchActive` SQL; the derived table status (`penuh`) written as a side effect in `syncTableStatus`; `transferSowing` exists in both the view model (`:147`) and the repository, and the view model copy appears unused by the sheet (it calls `submitTransfer`); that is a duplicate trap for a reader.
- Plain-language description: "A sowing can be moved only when seedlings are at least 15 days old, the sowing is still active, no more seedlings are moved than remain, the table is 'available', and the table has enough free holes (250 per table in the seed data). On success the table becomes 'full' when all holes are used, and the sowing is closed when every seedling has moved. The estimated harvest date is sowing date plus 45 days."
- Verdict: backend easy to medium; mobile medium (the sheet is 513 lines with 62 branch tokens).

### Flow 5: harvest, then sell
- Files, mobile: `views/pages/panen_form_page.dart` -> `views/components/panen_form_body.dart` (469 lines; long line :434) -> `viewmodels/panen_viewmodel.dart:171` (`submit`), `:247` (`_save`) -> `data/repositories/harvest_repository.dart` -> `api_client.dart`; then sale: `views/pages/catat_penjualan_page.dart` -> `views/components/catat_penjualan_body.dart` (582 lines) -> `viewmodels/catat_penjualan_viewmodel.dart:55` -> `viewmodels/penjualan_viewmodel.dart:111` -> `data/repositories/sales_repository.dart` -> `api_client.dart`. Backend: `harvest/index.ts:19` -> `harvest/write.ts` -> `sync.ts` -> `harvest/service.ts:9` -> `harvest/store.ts`; then `sales/index.ts` -> `sales/write.ts` -> `sales/service.ts:98` (`createSale`, `validateLine`, `harvestForSale`, `soldForHarvest`) -> `common/weights.ts`, `money.ts`.
- Hops: 5 + 7 mobile, 5 + 6 backend; 23 total over two flows.
- Hard to follow: `harvest/service.ts` (51 lines, 5 lines over 200 characters, single-letter `d`, `a`, `b`); `panen_viewmodel.dart` (502 lines, 69 branch tokens, `_save` about 100 lines); `catat_penjualan_viewmodel.dart` validation with float tolerance; the sale checks weight against "good weight minus already sold" through `harvestForSale` and `soldForHarvest` with legacy fallbacks.
- Plain-language description: "A harvest records, per batch moved to a table, how many plants were cut and the total weight and the rejected weight. Good weight is total minus reject. A harvest cannot be larger than the plants still alive, and a batch's plants are freed from its table. A sale picks one harvest, and a weight and price per kilogram. The weight sold cannot exceed good weight minus what was already sold; the total is weight times price. A harvest weight cannot later be lowered below what was sold."
- Verdict: backend hard (dense, uncommented); mobile hard.

### Densest code

Longest lines (characters, `awk 'length>160'`; command: `grep -rn --include=*.ts '' backend/src | awk ...`):

Backend (18 lines over 160; top 15):
`harvest/service.ts:13` 404; `harvest/contracts.ts:18` 343; `harvest/contracts.ts:17` 262; `harvest/service.ts:22` 238; `inventory/store.ts:32` 224; `harvest/service.ts:19` 223; `harvest/service.ts:39` 212; `harvest/service.ts:47` 206; `inventory/jenis-inventaris.ts:31` 198; `db/harvest-weights.ts:6` 191; `db/cli.ts:9` 188; `inventory/store.ts:62` 184; `db/migrate.ts:52` 175; `db/migrate.ts:62` 171; `inventory/obat.ts:32` 170.

Mobile (2 lines over 160 characters; top 15 by length):
`panen_form_body.dart:434` 209; `detail_tanaman_meja_body.dart:170` 183; `rekomendasi_cuaca_body.dart:171` 160; `add_form_inventaris_page.dart:263` 157; `panen_form_body.dart:399` 152; `form_catat_kerusakan_body.dart:302` 148; `seedling_transfer_sheet.dart:456` 140; `panen_form_body.dart:308` 135; `employee_dialogs.dart:17` 129; `core/business_date.dart:7` 126; `seeding_form_page.dart:368` 125; `connected_inventory_viewmodel.dart:269` 125; `weather_rules.dart:67` 125; `weather_rules.dart:130` 124; `weather_rules.dart:38` 124. Only 16 mobile lines exceed 120 characters. Note: `awk 'length>160'` on this repo reports 7 mobile lines because it counts bytes and the `// ───` separators in `dashboard_body.dart` are multi-byte; I used a character count.

Deepest nesting (leading spaces / 2):
- Backend: 7 in the four `*/write.ts` wrappers (`transfers/write.ts:53`, `sales/write.ts:52`, `harvest/write.ts:52`, `damage/write.ts:53`), 6 in `sync/changes.ts:43`, 5 in `stock/reconcile.ts:28`. Modest.
- Mobile: widget trees 26 deep (`penjualan_body.dart:290`, `dashboard_body.dart:260`), 23 (`login_page.dart:187`), 22 (`detail_tanaman_meja_body.dart:246`), 21 (`penyemaian_body.dart:114`, `meja_nft_body.dart:123`, `cuaca_body.dart:225`). Deep widget trees are normal Flutter but make screens long.

Most branches (count of `if/else/case/for/while/catch`, `?:`, `&&`, `||` per file):
- Backend: `common/sync.ts` 28 (171 lines), `sales/service.ts` 25 (145 lines), `db/migrate.ts` 22, `harvest/service.ts` 17 (51 lines, the highest density), `stock/store.ts` 17.
- Mobile: `panen_viewmodel.dart` 69 (502 lines), `seedling_transfer_sheet.dart` 62 (513), `damage_viewmodel.dart` 55 (385), `panen_form_body.dart` 53, `bmkg_weather_service.dart` 45, `form_catat_kerusakan_body.dart` 45, `catat_penjualan_body.dart` 44, `connected_inventory_viewmodel.dart` 43.
- Longest functions I read: `saveItem` (88 lines), `saveSowing` (85), `_save` in `panen_viewmodel` (about 100), `_authRequest` (66), `executeOperation` (70), `createTransfer` (75).

Other readability smells measured: single-letter lambda parameters in backend about 7 lines (harvest and sales; `d`, `a`, `b`, `r`), mobile about 14 lines with a nested ternary on one line (`grep -rnE "\? .*: .*\? "`), 332 multi-line ternary continuations (normal for widget code). Async chains: only 4 `.then`/`.whenComplete`/`.catchError` calls; the code uses `await`, which is readable. Helper names that hide meaning: `batchActive` (SQL), `effectiveStatusSql`, `stockWrite`/`nurseryWrite`/`transferWrite`/`harvestWrite`/`salesWrite`/`damageWrite` (all "wrap one write in auth, idempotency and a transaction"), `currentAttempt()`, `command.uncertain`, `_set` in `panen_viewmodel`, `_merge`.

Entry point: backend has one (`app.ts:111-121` lists the 11 `register*` calls, 20 lines to read), mobile has one (`main.dart` -> `app_gate.dart`), but neither tells the reader where a feature lives.

## 4. Navigation aids

| Aid | Backend | Mobile | Root |
|---|---|---|---|
| README | Setup only; accurate (F5-12) | Setup only; accurate | 7 lines, links only |
| Folder map | None. Layout is guessable: `features/<noun>/{index,service,store,write,contracts}.ts` repeated in 9 folders | None. 5 top-level folders plus `features/` | None |
| Glossary of domain terms | None | None | None. `GLOSSARY.md` deleted in `a6c9bf3`; it held 5 stock terms only |
| API reference | `API.md`, 214 lines, Indonesian, matches the 60 routes | n/a | `docs/panduan-menjalankan-backend.md` (244 lines) |
| Flow descriptions | None | None | None |
| Decision records | None (the deleted `docs/b006/*` held them) | None | `yeonworks/` holds reviews, not guides |

`GLOSSARY.md`: does not exist in the working tree. History: added in `8d415af` ("refactor(stock): satukan guard dalam append"), re-added in checkpoint commits `178b4fc` and `644edcf`, removed in `a6c9bf3` on 2026-10-28 together with `docs/b006/*`, `docs/A9_PPL IF_WEEK5.docx.md`, `apps/mobile/docs/bmkg-weather-integration.md` and others. Only `.agents/skills/...` still refer to it (generic text, not project content).

Proposed glossary (starting point; confirm the HST definition with the team because no document defines it):

| Term | Meaning | DB / API name | Dart name | Plan |
|---|---|---|---|---|
| Batch | A group of plants from one sowing moved to one table; the plan traces history per batch | `pemindahan` row (`id_pemindahan`) | `TransferRecord` (UI also says "Batch #id" for a sowing) | PB-04, PB-08 |
| HSS | Hari Setelah Semai: days since sowing date | `usia_hari`, `hss` | `ageDays`, `hss` | line 447 |
| HST | Hari Setelah Tanam: days since transfer to the table (inferred from code, undefined in plan) | `hst` | `hst` | none |
| Penyemaian | Sowing: seeds started in the nursery; consumes seed stock | `penyemaian`, `/penyemaian` | `SowingRecord` | PB-03 |
| Pemindahan | Transfer of seedlings to a table; allowed from 15 HSS | `pemindahan` | `TransferRecord` | PB-04 |
| Meja tanam | Planting table (NFT); capacity in holes (250 in seed data) | `meja_tanam`, `jumlah_lubang` | `TableRecord`, `MejaNft` | PB-04 |
| Tanaman aktif | Moved minus damaged minus harvested | `tanaman_aktif` | `activePlants` | PB-04, PB-08 |
| Panen | Harvest event with count and weight per batch; planned at 45 HSS | `panen`, `detail_panen` | `HarvestRecord` | PB-08 |
| Berat layak | Good weight = total minus reject | `berat_layak` | `HarvestWeight` | PB-08 |
| Penjualan | Sale of a harvest: kg x price per kg | `penjualan`, `detail_penjualan` | `SaleRecord` | PB-09 |
| Transaksi stok / saldo | Immutable stock line / total of lines | `stok`, `detail_stok`, `stok_saldo` | `StockMovementRecord` | PB-02 |
| Reversal | Opposite stock line that cancels an earlier one | `reversal_of` | n/a | PB-02 |
| Idempotency key | Ticket number so a retry does not write twice | header `Idempotency-Key` | `key` in commands | PB-07 |
| Minor unit | Quantities stored in hundredths (`2.50` kg = 250) | `*_minor` | `minor` | n/a |

## 5. Proposed comment standard (one page; not applied)

Language: Indonesian, plain sentences, no jargon without a gloss. Identifiers, error codes and file names stay as they are.

Comment these, always:
1. Every exported function or class, one or two lines: what it does and what it guarantees (not how).
2. Every business rule, at the line that enforces it: the rule in words, the number, and the plan reference (`PB-04`) or the reason.
3. Every money, weight, date or capacity calculation: the unit and the rounding.
4. Every state change and transaction boundary: which states, what must succeed together.
5. Every rule enforced in two layers: say which layer is the authority and name the other one.
6. Every SQL statement that encodes a rule, and every trigger.
7. Every workaround, legacy path or retry trick: what it protects and when it can be deleted.

Do not comment:
- What the next line already says, numbered steps, layout labels, decorative separators, commented-out code, "Helper" or "Text Atas" labels (matches `.agents/skills/antislop-code`).
- Ticket codes (B006) or file paths that will move. Use the glossary term or the plan id.

Function format (doc comment, `/** */` in TypeScript, `///` in Dart):
```
/** <Apa yang dilakukan>. <Jaminan atau akibat>. <Kapan gagal: kode galat>. */
```
Business rule format (one line above the check):
```
// Aturan: <aturan dalam kata>. Alasan/sumber: <PB-xx atau alasan>. Server berwenang; <aplikasi hanya menyalin>.
```
SQL format (above the statement or constant):
```
-- Aturan: <apa yang dijaga>. Dijaga juga di: <file lain>. 
```

### Example A: rule with a magic number (backend, `transfers/service.ts:33-47`)

Before:
```ts
  // 2. Validate seedling age (minimum 15 days)
  const semaiMs = Date.parse(`${String(sowingRow.tanggal_semai)}T00:00:00Z`);
  ...
  if (umurSemaiHari < 15) {
    throw new ApiError(400, 'SEEDLING_NOT_READY', 'Bibit belum mencapai umur minimal 15 hari untuk dipindahkan.');
  }
```
After:
```ts
// Aturan: bibit boleh dipindah ke meja tanam paling cepat 15 HSS (hari setelah semai).
// Alasan: bibit yang lebih muda belum kuat untuk sistem NFT (PB-04). Server berwenang;
// aplikasi hanya menyalin angka ini untuk umpan balik cepat (seedling_transfer_sheet.dart).
const MIN_SOWING_AGE_DAYS = 15;
...
  const umurSemaiHari = Math.floor((pindahMs - semaiMs) / dayMs);
  if (umurSemaiHari < MIN_SOWING_AGE_DAYS) {
    throw new ApiError(400, 'SEEDLING_NOT_READY', 'Bibit belum mencapai umur minimal 15 hari untuk dipindahkan.');
  }
```
(The reason text is an assumption; the team must confirm the agronomic reason.)

### Example B: ledger write and SQL guard (backend, `stock/store.ts:97-127`)

Before:
```ts
export async function appendMovement(tx: Transaction, actorId: string, now: number,
  input: {...}, reversalOf: string | null = null, origin?: Origin) {
  // Keep persistence prerequisites inside append, before any ledger or balance write.
  ...
    const update = await tx.execute({ sql: `UPDATE stok_saldo SET saldo_minor=saldo_minor+CAST(? AS INTEGER)
      WHERE id_inventaris=? AND saldo_minor+CAST(? AS INTEGER) BETWEEN 0 AND 999999999999`,
      args: [delta, line.id_inventaris, delta] });
    if (update.rowsAffected !== 1) {
```
After:
```ts
/**
 * Menambah satu transaksi stok (masuk, keluar, atau pembalik) ke buku stok.
 * Buku hanya bertambah, tidak pernah diubah. Saldo (`stok_saldo`) adalah ringkasan
 * dari seluruh baris dan harus selalu sama dengan jumlahnya (dicek `reconcileStock`).
 * Urutan: header `sealed=0`, baris detail, lalu `sealed=1`; trigger di migrasi 0006
 * menolak perubahan pada transaksi yang sudah disegel.
 * Gagal: INSUFFICIENT_STOCK (saldo tidak cukup), STOCK_LIMIT_EXCEEDED, STOK_ALREADY_REVERSED.
 */
...
    // Aturan: saldo tidak boleh negatif atau melewati batas (dalam seperseratus satuan).
    // Pengecekan ada di dalam UPDATE yang sama agar dua permintaan bersamaan tidak
    // sama-sama lolos. rowsAffected 0 berarti pengecekan gagal.
```

### Example C: mobile rule copy (`seedling_transfer_sheet.dart:62-66`)

Before:
```dart
  DateTime? get _firstDate {
    final sowingDate = DateTime.tryParse(widget.sowingRecord.sowingDate);
    return sowingDate == null
        ? null
        : DateUtils.dateOnly(sowingDate).add(const Duration(days: 15));
  }
```
After:
```dart
  /// Tanggal paling awal untuk memindahkan bibit: 15 hari setelah tanggal semai (15 HSS).
  /// Ini salinan aturan server (SEEDLING_NOT_READY); server yang memutuskan.
  /// Bila tanggal semai tidak terbaca, mengembalikan null dan form menolak simpan.
  DateTime? get _firstDate {
    final sowingDate = DateTime.tryParse(widget.sowingRecord.sowingDate);
    return sowingDate == null
        ? null
        : DateUtils.dateOnly(sowingDate).add(const Duration(days: minSowingAgeDays));
  }
```
(`minSowingAgeDays` is a new shared constant; see F5-5.)

## Met and fine

- Backend "why" comments are clear and correct where they exist (`login.ts`, `refresh.ts`, `sync.ts:95`, `sessions.ts:7-10`, `serverless.ts`, `stock/errors.ts`, `tables/store.ts:6`).
- `nursery/service.ts:8-11,40-43` and `nursery/write.ts:8-12` are model doc comments for the rest of the codebase.
- `apps/backend/API.md` and `docs/panduan-menjalankan-backend.md` are accurate against the code (60 routes, 15 minute access token, 7 and 30 day session, 120 per minute limit) and are in the team's language.
- Setup READMEs are accurate; the commands, Node version and dart-define names match the code.
- Backend folder layout is uniform (`index`, `service`, `store`, `write`, `contracts` per feature), which makes a flow findable once the pattern is known.
- Mobile has good docs on weather (`bmkg_weather_service.dart:22-26,100-104`, `weather_rules.dart:11-15`), formatting (`formatting.dart:18-34`) and `ApiClient` memory-only tokens (`:45`).
- No TODO, FIXME or HACK markers remain; few comments restate code in the backend.
- `flutter analyze` and `tsc` clean (per brief); lines per code file are not my slice.

## Count by severity

High 4 (F5-1, F5-2, F5-3, F5-4); medium 7 (F5-5, F5-6, F5-7, F5-8, F5-10, F5-11, F5-13); low 2 (F5-9, F5-12). Total 13.

## Housekeeping note

My count script first wrote a temporary file `apps/nocomment.tmp` inside the repo by mistake. I deleted it immediately; `git status --short | grep tmp` is empty. No other repo file was touched.
