# Slice F1: monorepo (goal 7), MVC (goal 8), over-engineering by structure (goal 9)

Reviewer F1. Read-only. Repo `D:\Dev\Projects\hidrosense`, branch `main`, 2026-11-05.
Scripts: `scratchpad/review2/f1/reach.py` (Dart import graph, reachability, layer matrix) and `scratchpad/review2/f1/wirekeys.py` (API keys copied by hand). Other counts come from the `grep`/`diff`/`wc` commands quoted in each finding.

## Verdict by goal

| Goal | Verdict | Evidence |
|---|---|---|
| 7 Monorepo best practice | Partly | Both apps sit under `apps/` and have tracked lockfiles. CI uses those lockfiles. But no root command exists, CI never runs the backend checks (lint, typecheck, 319 tests), the API contract is copied into Dart by hand, and no README documents a test or lint command. |
| 8 MVC | Partly; on mobile, mostly by renaming | Backend: routes, services and stores map to Controller and Model in 7 of 11 features. Mobile is MVVM (Riverpod). Views never import repositories or services directly, but they hold business rules (66 permission checks in 21 files; the 15/45-day growth rules). Two folder layouts and two model families exist side by side. |
| 9 Not over-engineered (structure side) | Partly | 14 unreachable files (1,076 lines), an A/B-testing service with one hard-coded variant, a dark theme that `main.dart` never turns on, forwarding wrappers and dead aliases, and six hand-written retry "Command" classes. The backend is lean; its `write.ts` duplication is already in the backend audit. |

## Findings (ranked)

### F1 [GOAL 7] CI never runs the backend's own checks
- Severity: high
- Status: VERIFIED
- Where: `.github/workflows/mobile-ci.yml:29-45`; `apps/backend/package.json:23` (`"check"`)
- What: The only workflow installs backend dependencies, then runs only `flutter analyze` and `flutter test`. CI never runs `tsc`, Biome, `check:lines` or the 319 `node --test` backend tests. A backend change that breaks a route with no Flutter backend-flow test still passes CI.
- Evidence: The workflow steps are `npm ci` (backend), `flutter pub get --enforce-lockfile`, `flutter analyze` and `flutter test --concurrency=1`. It never calls `npm test`, `npm run check` or `npm run lint`. Only 4 Flutter tests start the real backend (`damage_`, `growth_`, `harvest_`, `inventory_backend_flow_test.dart`, through `Process.start('node', …)`).
- Suggested fix: Add a `backend` job with `working-directory: apps/backend`, `npm ci` and `npm run check`. Rename the file to `ci.yml`. Size: 30 minutes.

### F2 [GOAL 7] The API contract is written twice: in TypeScript and by hand in Dart
- Severity: high
- Status: VERIFIED
- Where: `apps/mobile/lib/data/models/*.dart`, `lib/data/repositories/*.dart`, `lib/features/accounts/data/**`; `apps/backend/API.md`; `apps/backend/src/common/permissions.ts:4-15`
- What: No contract is shared between the apps. Dart models spell the backend's snake_case keys by hand, and some models guess between alternative keys. Permission strings and validation limits are copied as literals. `API.md` is the only contract document, and no README links to it.
- Evidence:
  - `wirekeys.py` found 74 snake_case keys in the Dart data and viewmodel layers. 59 of them also appear in backend `src/` or `migrations/`, and they are spelled in 26 Dart files.
  - Key guessing: `nursery_record.dart:76-79` reads `json['stok_konsumsi'] ?? json['consumed_materials'] ?? json['materials']`, but the backend sends only `stok_konsumsi` (`nursery/store.ts:75`). `employee_model.dart:29,33,38` falls back from `id_user` to `id`, from `no_telepon` to `noTelepon`, and from `role` to `nama_role`.
  - Permissions: 78 permission literals in `lib/`. Backend source: `common/permissions.ts`. Mobile gates employee management with `user.role == 'petani'` (`account_body.dart:106`), but the backend checks `pegawai:manage`.
  - Limits: `form_meja_nft_body.dart:79-83` repeats the limits code ≤30, capacity ≤1000 and note ≤1000 from `tables/contracts.ts:6-9`. `sowing_draft.dart:19-35` repeats the nursery limits.
  - `grep -rl "API.md" README.md apps/*/README.md docs` finds nothing.
  - The sales and accounts repositories are tested only against `MockClient` with hand-written JSON (`employee_repository_test.dart:46…`). No real-backend test covers them.
- Suggested fix: Code generation is not worth it, because response shapes are built in `store.ts` mappers, not in Zod. Do three cheap things instead:
  - (a) Link `API.md` from the root and mobile READMEs.
  - (b) Add `sales_backend_flow_test.dart` and `accounts_backend_flow_test.dart`, copying the existing `Process.start` pattern.
  - (c) Add one Dart `lib/core/permissions.dart` with constants, and drop the key fallbacks.
  - Size: 1 to 2 days.

### F3 [GOAL 7] No single command to set up or check the whole repo; the root lockfile is an empty stub; no test docs
- Severity: medium
- Status: VERIFIED
- Where: `package-lock.json` (root, 95 bytes, `"packages": {}`), `README.md`, `apps/*/README.md`, `docs/panduan-menjalankan-backend.md`
- What: A new team member must know to `cd` into each app and must guess the test commands. The root lockfile was created by an accidental `npm install` at the root, and git tracks it. It suggests that a root package exists, but none does.
- Evidence: `ls` at the root shows no `package.json`. `grep -nE "npm (run )?(test|lint|check)|flutter (test|analyze)|biome"` over every README and `docs/*.md` returns 0 hits.
- Suggested fix: Add a root `package.json` with scripts only, and no npm workspaces (only one Node package exists): `"setup": "npm ci --prefix apps/backend && cd apps/mobile && flutter pub get"` and `"check": "npm run check --prefix apps/backend && cd apps/mobile && flutter analyze && flutter test"`. Delete the stub lockfile. Add a "Checks" section to the root README. Nx or Turborepo bring no concrete gain for two apps. Size: 1 to 2 hours.

### F4 [GOAL 8] Mobile MVC is met only by folder names; the real pattern is MVVM, split across two layouts
- Severity: high
- Status: VERIFIED
- Where: `apps/mobile/lib/**`; `apps/backend/src/features/**`
- What: The goal says MVC. Neither app is MVC, and nothing in the repo explains how the code maps to MVC. Mobile is MVVM: Riverpod `StateNotifier` view models, no controllers. The backend is a vertical-slice layout. Inside each slice, route files act as Controllers, and `service.ts` plus `store.ts` act as the Model. The "View" is the JSON mapper functions inside `store.ts`.
- Evidence (mapping):

  | Role | Mobile | Backend |
  |---|---|---|
  | Model | `lib/data/models` (10 files, API records); `lib/models` (5 files, UI or legacy); `lib/core/weather_rules.dart`, `business_date.dart`; data access in `lib/data/repositories` (6) and `lib/data/services` (3); `lib/features/accounts/data/**` (4) | `service.ts` (business rules), `store.ts` (SQL), `common/*` (money, weights, sessions), `migrations/` |
  | View | `lib/views/pages` (23), `components` (18, really screen bodies), `widgets` (50); `lib/features/accounts/presentation/{pages,widgets}` (5); `lib/features/auth/presentation/widgets` (1) | 14 `*Response`/`*Row` mappers in `store.ts` files (`sales/store.ts:63`, `nursery/store.ts:12` …) |
  | Controller / ViewModel | `lib/viewmodels` (11 files); `lib/features/accounts/presentation/viewmodels` (2) | `index.ts` and per-action route files, `contracts.ts` (input validation), `write.ts` (idempotent write wrapper) |

  `reach.py` layer matrix: views import viewmodels 55 times and `data/models` 33 times. Views import `data/repositories` or `data/services` 0 times. The direction is mostly right, but the leaks in F5, F6 and F7 break it.
- Suggested fix: Do not rewrite. Add a one-page `docs/ARCHITECTURE.md` with the table above, a box diagram (View → ViewModel → Repository → ApiClient → routes → service → store → SQLite), and one sentence: "Flutter side is MVVM, the Flutter form of MVC: ViewModel = Controller." Then make the moves in F9. Size: 2 hours for the page.

### F5 [GOAL 8] Views hold business rules and whole workflows
- Severity: high
- Status: VERIFIED
- Where: `lib/views/widgets/seedling_transfer_sheet.dart:42-269,456`; `lib/views/components/form_meja_nft_body.dart:61,79-89,129`; `lib/views/components/catat_penjualan_body.dart:135-188`; `lib/views/pages/info_seeding_page.dart:81`; 21 view files with permission checks
- What: Some views decide domain rules, and the same rules also live in view models and in the backend. When a rule changes, a reader must find it in three places.
- Evidence:
  - `seedling_transfer_sheet.dart` (513 lines) is filed as a "widget", but it runs the whole transfer command. It creates the idempotency key with `generateUuidV4()` (235). It keeps a retry scope keyed by `apiClientProvider.serverOrigin` (55, 76, 274). It enforces the 15-day transfer rule (65, 230) and the 45-day harvest estimate (456). It also refreshes two other view models (188-189). The backend holds the same rules in `nursery/store.ts:28` (`siap_pindah: age >= 15`) and `transfers/store.ts:9` (`HARVEST_STANDARD_DAYS = 45`).
  - `form_meja_nft_body.dart:61` repeats the backend rule that the `penuh` status is derived (`tables/service.ts:6-9`). Lines 79-83 repeat the Zod limits.
  - `catat_penjualan_body.dart:150-154,188` computes available stock and rounding. The same logic exists in `penjualan_viewmodel.dart:176-196,279`.
  - `info_seeding_page.dart:81` hard-codes `15`.
  - Permission and role literal checks: 66 in 21 view files, measured with `grep -rhoE "permissions\.contains\('[a-z:]+'\)|role == '(petani|pegawai)'"` over the view folders. Only 12 such checks sit in view models.
- Suggested fix: Move the transfer command and its date rules into `connected_nursery_viewmodel.dart`. Expose `canRead`/`canWrite` and `firstTransferDate` from view models. Better still, read readiness from the API, which already returns `siap_pindah`. Size: 2 to 3 days.

### F6 [GOAL 8] Dependencies point the wrong way: repositories import a view model, and views read the API client
- Severity: medium
- Status: VERIFIED
- Where: `lib/viewmodels/session_viewmodel.dart:8-50`; `lib/features/accounts/data/repositories/employee_repository.dart:3`, `profile_repository.dart:3`; `lib/views/widgets/harvest_access.dart:29`, `seedling_transfer_sheet.dart:55,76,274`
- What: `session_viewmodel.dart` defines `resolveApiBaseUri` (configuration) and `apiClientProvider` (dependency injection). It also holds `serviceError`, the mapping from errors to UI messages. As a result, both accounts repositories import the view-model layer to get the HTTP client. Repository providers are spread across view-model files, so no single place lists the app's services.
- Evidence: `reach.py` reports the edge `features/accounts/data/repositories -> viewmodels : 2`. Seven providers are declared inside view-model files: `tableRepositoryProvider` (connected_table_viewmodel.dart:9), `nurseryRepositoryProvider` (connected_nursery_viewmodel.dart:318), `damageRepositoryProvider` (damage_viewmodel.dart:345), `harvestRepositoryProvider` (panen_viewmodel.dart:64), `salesRepositoryProvider` (penjualan_viewmodel.dart:286), `inventoryCacheProvider` (connected_inventory_viewmodel.dart:11) and `bmkgWeatherServiceProvider` (weather_viewmodel.dart:29). Views read `apiClientProvider` directly 4 times.
- Suggested fix: Create `lib/data/providers.dart` holding `apiClientProvider`, `resolveApiBaseUri` and every repository or service provider. Have view models expose a `scopeKey` so views stop reading `serverOrigin`. Size: 2 to 3 hours.

### F7 [GOAL 8] The data layer formats text for the UI; one view model stores display strings as data
- Severity: medium
- Status: VERIFIED
- Where: `lib/data/services/bmkg_weather_service.dart:6,235,330,383`; `lib/viewmodels/penjualan_viewmodel.dart:217-219,248-250,332-333`; `lib/views/components/form_meja_nft_body.dart:129`
- What: The BMKG service builds ready-to-show strings, such as `'… mm'` and Indonesian dates with `WIB`, so the weather model can no longer be tested or reused without its formatting. The data layer also writes about 139 user-facing Indonesian exception messages across 20 files. `serviceError` hides `FormatException` text, but one view prints `$e` raw. In MVVM, formatting inside a view model is acceptable. The defect is that `PenjualanItem` keeps formatted values: `kuantitas: '50 Kg'`, money as `double`, and a formatted date. The search provider then filters on the formatted `kuantitas` string.
- Evidence: `grep` counts of `Exception(`/`StateError(` in `lib/data` and `features/accounts/data`. `formatting.dart` is imported by one data service, two view models and four views.
- Suggested fix: Have the weather service return raw numbers and `DateTime`, and format them in `WeatherViewModel`. Keep numeric fields in `PenjualanItem` and format only in widgets. Replace `'Gagal menyimpan meja: $e'` with `serviceError(e)`. Size: 0.5 to 1 day.

### F8 [GOAL 8] Backend: three slice layouts, SQL in route files, business decisions in stores
- Severity: medium
- Status: VERIFIED
- Where: `apps/backend/src/features/{accounts,auth,inventory,sync}/*`; `*/service.ts`; `nursery/store.ts:28`, `transfers/store.ts:9,41-44`, `tables/store.ts:6-8,15-23,62-73`, `stock/store.ts:84-120`
- What: Seven features follow `contracts/index/service/store/write`. `inventory` uses one route file per entity. `accounts` and `auth` use one file per use case, with SQL inside the route handler. Inside the "standard" slices, `service.ts` also runs SQL, and `store.ts` makes domain decisions. So the file names do not reliably tell a reader where the rules live.
- Evidence:
  - Route files that contain `sql:`/`execute(`/`batch(`: 12 files, 41 occurrences. Examples: `inventory/obat.ts:26-31,41-46,67,76`, `accounts/read-employees.ts:57-65`, `auth/login.ts`, `sync/changes.ts`. The 7 other features' `index.ts` files contain 0.
  - SQL in `service.ts`: damage 8, harvest 6, nursery 4, sales 10, transfers 6. stock and tables have 0.
  - Store decisions with 409 or 422 errors: 14. Examples: `stock/store.ts:84,86,102,120` (`INSUFFICIENT_STOCK`, `UNIT_MISMATCH`) and `sales/store.ts:28,37,64`.
  - The table-occupancy rule exists twice in one file: once in TypeScript (`tables/store.ts:15-19`) and once as SQL (`:20-23`).
- Suggested fix: Do not rewrite. Document the convention in `ARCHITECTURE.md` (F4): "`store.ts` = Model data access and JSON shape; `service.ts` = Model rules; route files = Controller". When `inventory/*.ts` and `accounts/*.ts` are next touched, move their SQL into `store.ts`. Size: 2 hours for the docs; 1 day for the moves.

### F9 [GOAL 8] The same mobile concept exists twice under two layouts
- Severity: medium
- Status: VERIFIED
- Where: see table
- What: The app mixes a layer-first layout (`lib/models`, `lib/viewmodels`, `lib/views`, `lib/data`: 129 files) with a feature-first layout (`lib/features/accounts/{data,presentation}`: 12 files, and `lib/features/auth`: 1 file). It also keeps legacy UI models next to API records. A reader cannot tell which copy is current.
- Evidence:

  | Duplicate | Copy A (purpose) | Copy B (purpose) | Status |
  |---|---|---|---|
  | Models | `lib/data/models/*_record.dart` (API wire records, 10) | `lib/models/*_model.dart` (prototype UI models, 5) | `InventoryItem` is unused; only its `StockStatus` enum is used, by an unreachable widget. `MejaNft` is never constructed in `lib/` (`grep "MejaNft("` finds only the model), yet 4 views carry `mejaItem` branches (`info_meja_body.dart:33-43`, `form_meja_nft_page.dart`, `info_meja_page.dart`). `SeedingBatch` is constructed only in tests, yet `info_seeding_page.dart:16-20,74-91` branches on it. `PenjualanItem` is a live view-model projection of `SaleRecord`. `WeatherData` is live and has no twin. |
  | Accounts models | `lib/features/accounts/data/models` (2) | (none in `lib/data/models`) | Same role as `lib/data/models`, different place |
  | View models | `lib/viewmodels` (11) | `lib/features/accounts/presentation/viewmodels` (2) | Same role |
  | Views | `lib/views/{pages,components,widgets}` | `lib/features/accounts/presentation/{pages,widgets}` | Cross-imports in both directions (`views/components -> features/accounts/presentation/pages : 2`; accounts pages import `views/widgets`, `views/components` and `viewmodels`) |
  | Auth | `lib/views/pages/login_page.dart`, `lib/viewmodels/session_viewmodel.dart` | `lib/features/auth/presentation/widgets/login_header_hero.dart` (the only file) | Feature folder holds 1 of 3 auth files |
  | Drafts | `lib/data/models/harvest_draft.dart` | `lib/viewmodels/inventory_draft.dart`, `sowing_draft.dart` | Same concept, two layers |
  | Colors | `views/widgets/app_surface_colors.dart` | `views/widgets/inventory_colors.dart:5-9` (an empty subclass, "Nama lama", meaning "old name") | Alias |
  | Empty/notice/placeholder widgets | `surface_empty_state`, `surface_notice`, `surface_placeholder` | `inventory_empty`, `inventory_notice`, `inventory_placeholder` | Inventory-only twins |
  | Names | The nursery concept goes by 6 names across 12 files: `nursery_*`, `sowing_*`, `seeding_*`, `seedling_*`, `penyemaian_*`, `semai` | The table concept goes by `table_*`, `meja_nft_*`, `tanaman_meja` | Hard for another team to search |
- Suggested fix: Keep the layer-first layout, which already holds 129 of 143 files. Move the 13 `features/*` files into `lib/data/...`, `lib/viewmodels/` and `lib/views/pages/accounts/`. Delete `InventoryItem`, `MejaNft` and `SeedingBatch` together with their dead branches. Move `penjualan_model.dart` next to its view model. Pick one name per concept (for example the backend feature names `nursery`, `tables`, `harvest`, `sales`) for new files. Size: 1 day of moves only.

### F10 [GOAL 9] 14 mobile files (1,076 lines) are unreachable from `main.dart` and from tests
- Severity: medium
- Status: VERIFIED
- Where: `lib/models/inventory_item_model.dart`; `lib/views/widgets/{category_badge, col_info_card_sm, custom_search_bar, filter_button, info_card_md, item_image_placeholder, item_info_details, meja_nft_card_content, seeding_card_content, stock_history_item, stock_info_row, stock_status_badge, top_info_content}.dart`
- What: These files are leftovers from a static prototype. `flutter analyze` does not flag unused files, so they stay unnoticed and inflate the View layer that another team must read.
- Evidence: `reach.py` reports "reachable from main.dart: 129 of 143". `grep -rl "/<name>.dart" test` returns 0 for each of the 14 files.
- Suggested fix: Delete all 14. Size: 30 minutes.

### F11 [GOAL 9] The A/B-testing "telemetry" service has one hard-coded variant and sends nothing
- Severity: medium
- Status: VERIFIED
- Where: `lib/core/telemetry/ab_testing_service.dart:4-40`; `lib/features/accounts/presentation/viewmodels/employee_viewmodel.dart:91,131,160,232,252,312`; `test/employee_viewmodel_test.dart:130-218`
- What: This is configuration for a need that does not exist. `activeVariant` always returns `variantBHub` (line 12), and `variantAInline` is referenced nowhere. Events go into an in-memory list that only a test reads. The offline-first plan has no analytics backend.
- Evidence: `grep -rn "EmployeeLayoutVariant|activeVariant|loggedEvents"` finds hits only in the service and the test.
- Suggested fix: Delete the service, the 5 `logEvent` calls and the test assertions. Size: 1 hour.

### F12 [GOAL 9] Six hand-written retry "Command" classes repeat the same idempotent-write machinery
- Severity: medium
- Status: VERIFIED
- Where: `connected_table_viewmodel.dart:84-94,176-243`; `damage_viewmodel.dart:34`; `inventory_draft.dart:39`; `panen_viewmodel.dart:47,58`; `sowing_draft.dart:39`; `connected_nursery_viewmodel.dart:29`
- What: Each feature re-implements the same parts: a UUID key, `uncertain`/`running`/`receipt` flags, a commands map in a provider keyed by `(serverOrigin, userId)`, and generation counters. Each copy differs slightly. The table view model also builds a backend-keyed map (`'kode_meja'`, `'jumlah_lubang'`) only to unpack it again for the repository (lines 198-214, 250-267). This is the natural seam for the planned offline outbox (goal 1), but today it exists 6 times. The backend `write.ts` copies are already counted in `laporan-review-kode-backend.md:130`.
- Evidence: `grep -rnE "^class \w*(Command|Operation|Pending)\w* " lib` finds 7 classes. `grep -rl uncertain lib` finds 11 files, 3 of them views.
- Suggested fix: Write one `PendingWrite<T>` class in `lib/data/` with key, attempt and state, and reuse it in all view models. That class can later become the SQLite outbox row. Size: 1 to 2 days, best combined with the offline-sync work.

### F13 [GOAL 9] Dark mode is coded but `main.dart` never enables it
- Severity: low
- Status: VERIFIED
- Where: `lib/main.dart:17-19` (only `theme: AppTheme.lightTheme`); `lib/views/widgets/app_surface_colors.dart:17-31`; brightness checks in `custom_bottom_navigation_bar.dart:25,80`, `header.dart:45`, `login_page.dart:85,350` and `glass_container.dart:61`
- What: Every dark branch is unreachable in the shipped app. Only the debug tool `tool/harvest_device_qa.dart:16-22` sets `darkTheme`.
- Evidence: `grep -rn "darkTheme|themeMode" lib tool` finds hits only in `tool/`.
- Suggested fix: Decide. Either add `darkTheme` and `themeMode: ThemeMode.system` to `main.dart`, or drop the dark branches. Size: 1 hour to decide and apply.

### F14 [GOAL 9] Forwarding wrappers, dead aliases and test-only APIs
- Severity: low
- Status: VERIFIED
- Where and what:
  - `views/widgets/transfer_seedling_bottom_sheet.dart:5-35` only forwards to `SeedlingTransferSheet`. It has 1 caller (`penyemaian_body.dart:233`), while `info_seeding_page.dart:421` uses the inner widget directly.
  - `penjualan_viewmodel.dart:46` `fetchPenjualanData() => refresh()`: 0 callers.
  - `api_client.dart:290-294` `delete(...)`: 0 callers (the only `.delete(` hit is a sqflite call).
  - `api_client.dart:302-305` `setTokens`: 0 callers in `lib`, 31 in tests.
  - `session_viewmodel.dart:14-18`: an `if` block whose body is only a comment.
  - Three identical clock providers: `connected_nursery_viewmodel.dart:16`, `damage_viewmodel.dart:47` and `penjualan_viewmodel.dart:282`.
  - Backend: 9 `contracts.ts` files re-export `parseInput`/`idParamSchema` from `common/validation.js` (for example `sales/contracts.ts:6`).
- Suggested fix: Delete the wrapper, the alias, `delete` and the empty `if`. Merge the clocks into one `clockProvider`. Size: 1 hour.

### F15 [GOAL 7] Non-product files in the repo and an unmanaged 20 MB asset folder
- Severity: low
- Status: VERIFIED
- Where: tracked: `outofthebox/` (2 files), `yeonworks/` (5 files; `review-backend-hidrosense.md` is deleted in the working tree), `AGENTS.md`, `CLAUDE.md`, `skills-lock.json`. Untracked and not ignored: `assets/` (20 MB, 21 files), `hidrosense-plan-docs/` (2.7 MB), `yeonworks/review-learn/`, `apps/nocomment.tmp`
- What: Agent-tooling files stay tracked even though commit `726fc64` said it stopped tracking them. `AGENTS.md` points readers to `.agents/` and `.codex/`, which are ignored. The root `assets/` holds the original art plus `prompts.json`, `manifest.json` and `contact-sheet.jpg`; `apps/mobile/assets` (6.1 MB) holds the shipped copies, with different hashes. A `git add .` would commit 20 MB of duplicates.
- Evidence: `git ls-files | awk -F/ '{print $1}' | sort | uniq -c`; `git status --porcelain --ignored`; `du -sh`; `md5sum` comparison of the two asset trees (no hash matches).
- Suggested fix: Move the reports to `docs/reports/`, or keep them outside the code repo. Either track `assets/` as `design/source-art/` with a README, or add it to `.gitignore`. Add `*.tmp`. Size: 1 hour.

### F16 [GOAL 7] `.gitignore` is three concatenated templates; no `.editorconfig`
- Severity: low
- Status: VERIFIED
- Where: `.gitignore` (507 lines): lines 13-29 come from the Flutter SDK repository template (`/dev/bots/`, `/packages/flutter/coverage/`, a bare `version`), line 285 is the Python `lib/` rule, lines 297-298 add the `!apps/mobile/lib/` workaround, and line 189 is `.env.*`
- What: Most rules do not apply to this repo. The Python `lib/` rule needs a negation hack to keep the Flutter source tracked. `.env.*` also hides `apps/backend/.env.turso.example`, a template that exists locally and was meant to be shared. No `.editorconfig` exists, so Dart and TypeScript files have no shared indent or EOL rule (Biome's formatter is off, `biome.json:6`).
- Evidence: `git check-ignore -v apps/backend/.env.turso.example` reports `.gitignore:189:.env.*`.
- Suggested fix: Rewrite the file to about 60 relevant lines, add `!.env.*.example`, and add a 10-line `.editorconfig`. Size: 1 hour.

### F17 [GOAL 7] Toolchain versions are pinned only in CI; ML dependencies are unpinned
- Severity: low
- Status: VERIFIED
- Where: `.github/workflows/mobile-ci.yml:33,40` (Node 22, Flutter 3.44.0); `apps/mobile/pubspec.yaml:21-22` (`sdk: ^3.12.0`, no `flutter:` constraint); no `.nvmrc` or `.fvmrc`; `ml/requirements.txt` (`ultralytics`, `tensorflow`, no versions, no trailing newline); `ml/*.py` are 0 bytes
- What: Locally the machine runs Node v24.20.0 while CI uses 22. That is allowed by `engines >=22.13`, but untested. Nothing tells a developer which Flutter version to use. Backend dependencies are pinned exactly, and both lockfiles are enforced in CI (good).
- Suggested fix: Add `flutter: 3.44.0` under `environment:` in `pubspec.yaml` and a `.nvmrc` with `22`. Pin `ml/requirements.txt` when ML work starts (not now: goal 4). Size: 15 minutes.

### F18 [GOAL 7] No decided home for the model artifact; LFS rule without LFS checkout
- Severity: low
- Status: SUSPECTED (design reasoning; the config facts are verified)
- Where: `.gitattributes:1` (`*.tflite filter=lfs`); `.gitignore` (`*.pt`, `ml/venv/`, `ml/dataset/raw/`); `apps/mobile/pubspec.yaml:61-67` (no `models/` asset folder); `mobile-ci.yml:27-28` (`actions/checkout@v4` without `lfs: true`)
- What: Goal 3 says the model is downloaded once over the internet. If so, the `.tflite` should not ship in the APK or sit under `apps/mobile/assets`. The LFS rule suggests that someone plans to commit it to git. If a `.tflite` were committed, CI would check out only the LFS pointer file.
- Suggested fix: Write a short `ml/README.md` covering three points: training outputs go to ignored `ml/runs/`; the exported `.tflite` is published as a release asset or to storage with a checksum; the app downloads it once to its support directory. If the model is bundled instead, use `apps/mobile/assets/models/` and add `lfs: true` to the checkout step. Do not touch `ml/` code (goal 4). Size: 30 minutes of documentation.

### F19 [GOAL 7] Docs: two backend setup guides, a partial env list, unused platform scaffolds
- Severity: low
- Status: VERIFIED
- Where: `apps/backend/README.md` and `docs/panduan-menjalankan-backend.md` (overlapping setup steps that link to each other); `apps/backend/README.md:59` (lists `NODE_ENV, HOST, PORT, LOG_LEVEL, CORS_ORIGINS, TRUSTED_PROXIES`, but not `DATABASE_URL`, `DATABASE_AUTH_TOKEN` or `TRUST_PROXY_HOPS`, which are in `.env.example`); `apps/mobile/{macos,linux,web}` (41 tracked files) for a product the plan targets at Android (plan line 381); `pubspec.yaml:2` `description: "A new Flutter project."`
- What: The documented commands exist and match the code. All backend README and guide commands exist as scripts in `package.json`. `npm run lint` passes (148 files) and `npm run check:lines` passes (largest file 343 lines). `API_BASE_URL` and `BMKG_ADM4` are read at `session_viewmodel.dart:9` and `bmkg_weather_service.dart:31`. The defects are the duplication and the gaps.
- Suggested fix: Merge the guide into `apps/backend/README.md`, or keep the guide and shrink the README to a link. Complete the env list. Remove the `macos`, `linux` and `web` folders; keep `windows` because the README uses it for development. Size: 1 hour.

## Cheapest path to legible MVC and a tidy monorepo (most benefit, least work)

1. CI backend job (F1): 30 minutes.
2. Root `package.json` with `setup` and `check` scripts, delete the stub lockfile, add a "Checks" section to the README (F3): 1 to 2 hours.
3. `docs/ARCHITECTURE.md`: the mapping table from F4, one diagram, the backend file convention from F8, and a link to `API.md`: 2 hours.
4. Delete the 14 unreachable files, the 3 legacy models with their branches, and the A/B service (F9, F10, F11): 2 hours.
5. Fold `lib/features/*` (13 files) into the layer-first folders, and move every provider into `lib/data/providers.dart` (F6, F9): about 1 day.
6. Later, with the offline-sync work: move the rules out of views into view models (F5), and use one `PendingWrite` class (F12).

## Met and fine

- Every runtime dependency is used. Backend: `@fastify/cors` and `@fastify/helmet` in `app.ts:2-3`; `@libsql/client`, `fastify` and `zod` imported across `src/`. Dev dependencies are used by `lint`, `build`, `typecheck` and the `tsx` scripts. Mobile: `flutter_riverpod` in 46 files, `intl` in 4, `http` in 3, `sqflite` and `path` in `inventory_cache.dart:3-4`, `cupertino_icons` (font for 27 `CupertinoIcons` uses), dev `sqflite_common_ffi` in 8 tests.
- Backend dependencies are pinned exactly, and `engines.node >=22.13.0` is set. Both lockfiles are tracked. CI runs `npm ci` and `flutter pub get --enforce-lockfile`.
- Secrets: the only tracked env file is `apps/backend/.env.example`, which has an empty token. `.env`, `.env.local` and `.env.turso` are ignored (`git status --ignored`).
- Generated and agent folders are ignored: `.worktrees/` (2.3 GB), `graphify-out/`, `.bob/`, `agent/`, `apps/backend/{data,dist,backups}`.
- Mobile views never import `data/repositories` or `data/services` (0 edges in `reach.py`). 48 of the 50 `views/widgets` files are pure presentation.
- In 7 of 11 backend features, the route files contain no SQL and delegate to `write.ts`, `service.ts` and `store.ts`. `common/permissions.ts` is the single source of role permissions on the backend.
- The documented backend and mobile commands exist and run. `npm run lint` and `npm run check:lines` pass.
- Folder naming at the top level (`apps/backend`, `apps/mobile`, `ml`, `docs`) is conventional and small enough. Nx, Turborepo and workspaces are not needed.

## Count by severity

- critical: 0
- high: 4 (F1, F2, F4, F5)
- medium: 8 (F3, F6, F7, F8, F9, F10, F11, F12)
- low: 7 (F13, F14, F15, F16, F17, F18, F19)
- Total: 19
