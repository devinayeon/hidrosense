# Slice F3: file size, duplication, dead code, over-engineering (Flutter `apps/mobile/lib`)

Scope: goal 9 (files of 200 to 300 lines, not over-engineered) for `apps/mobile/lib` (143 files, 23,199 lines), plus dead and duplicated code.
Method: `wc -l` per file; a Python import-graph script (`scratchpad/review2/f3/imports.py`) for unreachable files; a symbol-reference scan (`sym.py`, `xfile.py`, `prov.py`, `theme.py`) over `lib/` and `test/`; full reads of the 12 largest files; targeted greps for each duplication claim. All paths below are relative to `D:\Dev\Projects\hidrosense\apps\mobile` unless marked backend.

## Verdict table

| Goal | Verdict | Evidence |
|---|---|---|
| 9. Files 200 to 300 lines | **Not met** | 30 of 143 lib files are over 300 lines (12,845 lines = 55% of all lib code); 38 are over 200. Largest: `inventaris_body.dart` 653. 105 files are 200 or less. |
| 9. Not over-engineered | **Partly** | Mostly no frameworks, but 14 orphan widget files (1,073 lines), a second inventory screen, mock model branches, and 6 near-identical "pending command" classes and 5 copy-pasted list scaffolds inflate the code. |
| 8. MVC (touched) | **Partly** | Good file layering (`views`, `viewmodels`, `data`). Leaks: `submitPenjualan(WidgetRef ref, ...)` in a viewmodel (`catat_penjualan_viewmodel.dart:149`); search/filter logic inside views (`panen_body.dart:49-72`, `inventaris_body.dart:149-155`); a view helper `serviceError` lives in `session_viewmodel.dart:59`. |
| 11. Easy to follow (touched) | **Partly** | Big files that mix layout, state, validation and network calls (see F3-2) are the main barrier. Three UI styles side by side (F3-8) make the code feel inconsistent. |

No mock or demo data ships: I grepped `Future.delayed`, `mock`, `Mock`, `sample`, `dummy`, `defaultPenjualanList`, `TODO`, `FIXME` over `lib/` and found nothing relevant. `connected_*` viewmodels have no older mock sibling (see F3-4 for what the name really means).

---

## Findings

### F3-1 [G9] 30 files are over 300 lines, 38 over 200
- Severity: high
- Status: VERIFIED
- Where: `apps/mobile/lib` (full list below)
- What: Goal 9 caps files at 300. 30 lib files break it, and 12,845 of 23,199 lines (55%) sit in them. Another 8 files are in the 201 to 300 band (acceptable but at the edge).
- Evidence: `for f in $(find lib -name '*.dart'); do echo "$(wc -l < $f) $f"; done | sort -rn` (output saved in `scratchpad/review2/f3/lines.txt`).
- Suggested fix: split the 12 largest first (F3-2). That alone brings 12 files from 6,163 lines to about 40 files of 100 to 250 lines. About 5 to 8 working days for all 12.

Files over 300 lines (30):

| Lines | File |
|---|---|
| 653 | views/components/inventaris_body.dart |
| 630 | views/pages/add_form_inventaris_page.dart |
| 582 | views/components/catat_penjualan_body.dart |
| 540 | views/components/dashboard_body.dart |
| 513 | views/widgets/seedling_transfer_sheet.dart |
| 502 | viewmodels/panen_viewmodel.dart |
| 477 | views/components/cuaca_body.dart |
| 469 | views/components/panen_form_body.dart |
| 469 | features/accounts/presentation/widgets/employee_form_sheet.dart |
| 458 | views/components/penjualan_body.dart |
| 452 | views/components/panen_body.dart |
| 450 | features/accounts/presentation/pages/employee_list_page.dart |
| 439 | views/pages/info_seeding_page.dart |
| 436 | views/pages/login_page.dart |
| 417 | data/services/bmkg_weather_service.dart |
| 401 | views/pages/seeding_form_page.dart |
| 399 | views/components/form_catat_kerusakan_body.dart |
| 390 | features/accounts/presentation/pages/profile_page.dart |
| 385 | viewmodels/damage_viewmodel.dart |
| 379 | viewmodels/connected_nursery_viewmodel.dart |
| 377 | views/components/meja_nft_body.dart |
| 375 | views/theme/app_theme.dart |
| 371 | views/components/penyemaian_body.dart |
| 359 | viewmodels/penjualan_viewmodel.dart |
| 350 | views/components/account_body.dart |
| 332 | viewmodels/connected_inventory_viewmodel.dart |
| 318 | data/services/api_client.dart |
| 314 | features/accounts/presentation/viewmodels/employee_viewmodel.dart |
| 306 | views/components/detail_tanaman_meja_body.dart |
| 302 | views/pages/connected_inventory_page.dart (dead in production, see F3-4) |

Files 201 to 300 (8): connected_table_viewmodel 280, form_meja_nft_body 267, meja_nft_card 252, sale_record 248, catat_penjualan_viewmodel 233, header 219, seeding_batch_card 213, custom_dropdown_field 202.

Test files over 300 lines: mobile 18 of 48 (`test/panen_test.dart` 948, `penjualan_test.dart` 789, `seedling_transfer_test.dart` 774, `damage_viewmodel_test.dart` 521, `growth_backend_flow_test.dart` 474, `dashboard_login_test.dart` 470, `harvest_backend_flow_test.dart` 455, `inventory_save_viewmodel_test.dart` 438, `harvest_viewmodel_test.dart` 436, `nursery_remediation_test.dart` 417, `nursery_widget_remediation_test.dart` 385, `growth_layout_test.dart` 378, `inventory_form_layout_test.dart` 375, `connected_table_remediation_test.dart` 367, `inventory_redesign_test.dart` 351, `employee_viewmodel_test.dart` 340, `inventory_save_widget_test.dart` 337, `damage_flow_test.dart` 314). Backend `apps/backend/test`: 3 files, `nursery.test.js` 343, `transfers.test.js` 315, `hunt-002.test.js` 312. Backend `src`: only `db/seed.ts` 215 is over 200 (a seed script, fine). If the "200 to 300" rule also covers tests, 18 + 3 more files need splitting; the three biggest mobile tests are 3 times the cap.

---

### F3-2 [G9] The 12 largest files each mix 3 to 5 concerns; split plan
- Severity: high
- Status: VERIFIED (I read all 12 in full)
- Where: see table
- What: Each file combines layout, local state, validation, formatting or API/command logic. A reader cannot follow one concern without scrolling past the others.
- Evidence: line ranges below, from the files themselves.
- Suggested fix: the splits below. Target sizes are estimates.

**Constraint from tests (verified):** Dart private names (`_X`) cannot be imported from another library, so no test depends on a private class or method. Tests depend only on (a) public class names and the file path in `import 'package:hidrosense_mobile/...'`, (b) text and `ValueKey` finders. Files with test importers: `inventaris_body` 4 tests, `add_form_inventaris_page` 3, `catat_penjualan_body` 1, `dashboard_body` 3, `seedling_transfer_sheet` 4, `panen_viewmodel` 6, `cuaca_body` 1, `penjualan_body` 1, `info_seeding_page` 5, `login_page` 3, `damage_viewmodel` 7, `connected_nursery_viewmodel` 7, `app_theme` 20. The 12 files `panen_form_body`, `employee_form_sheet`, `panen_body`, `employee_list_page`, `meja_nft_body`, `account_body`, `form_catat_kerusakan_body` have no direct test import. Rule: when a public symbol moves, keep an `export 'new_file.dart';` in the old file (the repo already does this at `viewmodels/damage_viewmodel.dart:6`). Keep these keys: `dashboard-quick-actions` (`dashboard_body.dart:223`), `weather-retry`, `weather-retry-inline` (`cuaca_body.dart:365,415`), `batch-<id>` and `harvest-<id>` (`panen_body.dart:278,302`). No test reads `lib/` source text (`grep File('lib` in `test/` is empty).

| # | File (lines) | What it mixes | Proposed split |
|---|---|---|---|
| 1 | `views/components/inventaris_body.dart` (653) | Screen state (search, category) 28-45; detail sheet launcher and archive dialog with API call 52-132; list layout 134-311; 5 private widgets 317-653 (fetched-at text, search bar, category chips, list header, add button, detail sheet). | `inventaris_body.dart` ~230 (state + build). `inventory_detail_sheet.dart` ~190 (`_InventoryDetailSheet` 549-653 plus `_showDetail` 52-81 and `_confirmDeactivate` 83-132, exposed as `InventoryDetailSheet.show`). Delete `_InventorySearchBar` 337-392 (verbatim copy of `SurfaceSearchField`, F3-6). Move `_InventoryCategoryChips` 395-462 to one shared `filter_chip_row.dart` ~70 used by 4 bodies (F3-7). Move `_InventoryAddButton` 507-546 to shared `floating_action_bar.dart` ~50. `_InventoryFetchedAt` + `_InventoryListHeader` (317-334, 465-504) stay in the body or `inventory_list_header.dart` ~60. |
| 2 | `views/pages/add_form_inventaris_page.dart` (630) | Draft restore from pending command 50-83; save and validation call 103-171; "pending draft" gate screen 186-212; form layout 213-407; four private UI helpers `_label/_textField/_selectorField/_openPickerSheet` 409-629 (220 lines). | `add_form_inventaris_page.dart` ~270 (state, save, build). Replace `_textField` with existing `CustomInputField`; replace `_selectorField` + `_openPickerSheet` (451-629) with one shared `OptionPickerSheet<T>` ~110 that `CustomDropdownField` (`views/widgets/custom_dropdown_field.dart`, 202 lines, own sheet at line 25) also uses. `inventory_form_options.dart` ~40 for `_units` (40-48) and the category `iconBuilder` (299-310). |
| 3 | `views/components/catat_penjualan_body.dart` (582) | Controller wiring 39-121; batch-stock business rules `_fallbackBatch/_batchesForForm/_scheduleEditBatchSync/_roundKg` 123-188; date picker 190-218; save + snackbars 220-275; multi-batch notice 277-328; modal grabber/header chrome 361-400; fields 402-552. | `catat_penjualan_body.dart` ~260. `catat_penjualan_batch_options.dart` ~80 (pure functions for 123-188; belongs with the viewmodel, not the view). `multi_batch_notice.dart` ~55 (277-328). `modal_sheet_scaffold.dart` ~50 shared (grabber + title + close; same chrome at `employee_form_sheet.dart:155-181`, `add_form_inventaris_page.dart:527-559`, `custom_dropdown_field.dart:45`). |
| 4 | `views/components/dashboard_body.dart` (540) | One 330-line `build` (22-349) with welcome card, nursery alerts, stat grid, quick actions (permission-gated list 40-67 and grid 205-288), 3 permission-gated module cards 292-339; plus 3 private widgets 356-540. | `dashboard_body.dart` ~170 (welcome, alerts, stats). `dashboard_quick_actions.dart` ~110 (actions + grid). `dashboard_business_modules.dart` ~100 (`_BusinessModuleCard` 478-540 + the 3 cards 292-339). `dashboard_alert.dart` ~80 (`_DashboardAlert` 356-425, `_DashboardStat` 428-475). |
| 5 | `views/widgets/seedling_transfer_sheet.dart` (513) | Idempotent command lifecycle and scope map 42-126, 206-269 (this is logic, not UI); date picker theme 138-178; post-save refresh 180-204; form UI 271-512 with 5 state branches. | `seedling_transfer_sheet.dart` ~200 (form UI). `seedling_transfer_controller.dart` ~170 (a plain `ChangeNotifier` owning `_commands`, `_scope`, `_restoreCommand`, `_acknowledgeSave`, `_submit`; sits beside `SeedlingTransferCommand` in `viewmodels/connected_nursery_viewmodel.dart:29`). `seedling_transfer_status.dart` ~70 (saved / loading / error branches 322-379). Shared `showAppDatePicker` (same themed picker in 5 files, F3-8). |
| 6 | `viewmodels/panen_viewmodel.dart` (502) | State classes 16-61; `HarvestCommand` bookkeeping 47-61 and `_save` 346-451; validation `validateDraft`/`correct` 235-336; refresh/merge/detail 136-228; providers + midnight timer + lifecycle listener 454-502. | `panen_state.dart` ~60 (enums, `HarvestReadState`, `PanenState`). `harvest_validation.dart` ~110 (pure functions: draft and correction checks, take records, transfers, today). `panen_viewmodel.dart` ~250 (refresh, loadDetail, submit, correct, `_save`). `panen_providers.dart` ~70 (providers and the timer). Re-export all from `panen_viewmodel.dart` (6 tests import it). |
| 7 | `views/components/cuaca_body.dart` (477) | One 285-line `build` for banner, 4 metric cards, forecast list, status chip; plus access-denied, error and inline-error states 300-423 (a third copy of the empty/error pattern, F3-9). | `cuaca_body.dart` ~120. `cuaca_location_banner.dart` ~55 (63-112). `cuaca_metric_grid.dart` ~100 (116-158 + `_buildMetricCard` 426-476). `cuaca_forecast_list.dart` ~110 (161-259). States 300-423 replaced by shared state widgets. |
| 8 | `views/components/panen_form_body.dart` (469) | Row controllers 16-32; initial values from pending-command JSON using wire keys (`'tanggal_panen'`, `'id_pemindahan'`, `'details'`) 70-113; date picker 124-149; draft/correction mapping + snackbars 151-209; build 232-375; row card 377-468. | `panen_form_body.dart` ~240. `harvest_row_controllers.dart` ~45. `harvest_batch_row_card.dart` ~110 (`_buildRow`). `panen_form_notices.dart` ~60 (286-319). Move the wire-key parsing 77-95 into `HarvestCommand` (data knowledge in a view). |
| 9 | `features/accounts/presentation/widgets/employee_form_sheet.dart` (469) | Form state 51-124; build 126-329; two field builders 331-468; validators inline 187-247; the 9-argument `onSubmit` function type written out twice (11-21, 26-36). | `employee_form_sheet.dart` ~190. `employee_form_fields.dart` ~150 (`_buildField`, `_buildPasswordField`). `employee_validators.dart` ~45 (pure functions, easy to unit test). One `typedef EmployeeSubmit` (also repeated in `employee_list_page.dart:34-43,66-75`). |
| 10 | `views/components/penjualan_body.dart` (458) | Filter bottom sheet 43-139 (builds its own option rows); error/loading branches 162-185; summary card + search + filter button 224-348; list + empty 359-403; floating button 412-453. | `penjualan_body.dart` ~230. `penjualan_filter_sheet.dart` ~110. `penjualan_summary_header.dart` ~110. Shared `FloatingActionBar` replaces 412-453. |
| 11 | `views/components/panen_body.dart` (452) | Search logic `_filterBatches/_filterRecords` 49-72 (belongs in the viewmodel, as `filteredPenjualanListProvider` does for sales); build 74-374 with overview, 3 notices, search, chips, 5 empty/list states, floating button; `_FilterChips` 376-452. | `panen_body.dart` ~210. Search moves to `PanenViewModel`. `panen_list_states.dart` ~110 (240-321). `_FilterChips` replaced by shared `FilterChipRow`. Shared `FloatingActionBar`. |
| 12 | `features/accounts/presentation/pages/employee_list_page.dart` (450) | Two sheet launchers with the long callback type 27-89; toggle/confirm flow 91-112; search field 173-215; filter chips 218-246, 296-323; list 250-289; four state builders 325-449 (icon circle + title + message + outlined button, repeated). | `employee_list_page.dart` ~210. `employee_filter_bar.dart` ~100 (search + chips; can reuse `SurfaceSearchField` and `FilterChipRow`). State builders 325-449 become calls to one shared state widget (F3-9), saving ~100 lines. |

The next 18 files over 300 (outline-level read only, so SUSPECTED): `info_seeding_page` 439 (single 400-line `build`, mock `SeedingBatch` branches, F3-5; split header, progress, materials, actions); `login_page` 436 (`_brand` 261-336, `_inputField` 337-436: a 6th text field style; extract `login_form.dart`); `bmkg_weather_service` 417 (HTTP 27-103, parsing `parseBmkgWeather` 105-243, `_BmkgSlot` 244, label helpers 326-417; split `bmkg_parser.dart` and `bmkg_labels.dart`); `damage_viewmodel` 385 and `connected_nursery_viewmodel` 379 (same command + provider + state pattern as panen; extract the shared command base from F3-10 and the slimming follows); `app_theme` 375 (colors, spacing, shadows, glass, type ramp, theme data in one file: `app_colors.dart`, `app_typography.dart`, `app_theme.dart`; keep `export`, 20 tests import it).

---

### F3-3 [G9] 14 widget/model files are imported by nothing (1,073 lines)
- Severity: medium
- Status: VERIFIED
- Where: `lib/views/widgets/category_badge.dart` 58, `col_info_card_sm.dart` 31, `custom_search_bar.dart` 61, `filter_button.dart` 73, `info_card_md.dart` 69, `item_image_placeholder.dart` 132, `item_info_details.dart` 80, `meja_nft_card_content.dart` 74, `seeding_card_content.dart` 141, `stock_history_item.dart` 73, `stock_info_row.dart` 94, `stock_status_badge.dart` 52, `top_info_content.dart` 57, and `lib/models/inventory_item_model.dart` 78.
- What: No file in `lib/` or `test/` imports them, and there are no `part` directives. `stock_status_badge.dart` imports `inventory_item_model.dart`, so the two form an island that nothing reaches. `meja_nft_card_content.dart` and `seeding_card_content.dart` are earlier versions of the live `meja_nft_card.dart` and `seeding_batch_card.dart`.
- Evidence: `python -I scratchpad/review2/f3/imports.py` builds the import graph from `lib/main.dart` and from all tests. Result: 14 files "not reachable from main OR tests"; "lib files imported by nobody in lib (only tests)" shows no test imports them either.
- Suggested fix: delete all 14 (1,073 lines, 4.6% of lib). 0.5 hour. `flutter analyze` and tests stay green because nothing references them.

---

### F3-4 [G9] A second, older inventory screen is still in the tree (`ConnectedInventoryPage`)
- Severity: medium
- Status: VERIFIED
- Where: `lib/views/pages/connected_inventory_page.dart` (302 lines), its only test `test/connected_inventory_page_test.dart` (184 lines); `lib/views/components/dashboard_body.dart:55-60`.
- What: The product inventory tab is `InventarisBody` (`main_page.dart:82`). `ConnectedInventoryPage` is the plain-Material predecessor (own search, chips, notice, stock status, logout button, floating button). The dashboard action "Cek Stok" carries `page: const ConnectedInventoryPage()` but also `onTap: onInventoryTap`; the tap handler is `action.onTap ?? Navigator.push(page)`. `MainPage` always passes `onInventoryTap` (`main_page.dart:80`), so the page is never opened in the app. It is reachable only when `DashboardBody()` is built without the callback, which only tests do.
- Evidence: `grep -rn "ConnectedInventoryPage" lib test`: 3 hits in lib (definition, import, the dead fallback), 1 test file. `grep "DashboardBody("` in lib: one call, with the callback.
- Suggested fix: delete the page and its test, make `onInventoryTap` required, drop the `page:` field for that action. About 1 hour. This also removes the "two code paths for the same feature" confusion.

The `connected_*` prefix itself is a leftover name, not a sign of a mock twin: `connected_inventory_viewmodel`, `connected_nursery_viewmodel`, `connected_table_viewmodel` have no non-connected sibling in `lib/viewmodels`. Renaming them (`inventory_viewmodel.dart` etc.) would remove the false hint; 1 hour plus import updates in 7 tests each.

---

### F3-5 [G9] Mock models `MejaNft` and `SeedingBatch` still wired into screens through branches no caller reaches
- Severity: medium
- Status: VERIFIED
- Where: `lib/models/meja_nft_model.dart` (82 lines), `lib/models/seeding_batch_model.dart` (60). Dead branches: `views/pages/info_meja_page.dart:13-16,36-37,50`, `views/pages/form_meja_nft_page.dart:10-17,33`, `views/components/info_meja_body.dart:16-19,33-43,132`, `views/components/form_meja_nft_body.dart:14,29,41`, `views/pages/info_seeding_page.dart:16-20,74-91,124-126`.
- What: These two models hold demo values (`location = 'Lokasi Green House Barat'`, `systemType = 'Sistem NFT'`, `totalHss = 15`). The pages accept either the backend record (`TableRecord`, `SowingRecord`) or the mock object, with `assert(a != null || b != null)` and `a?.x ?? mock!.x` chains. In production nobody passes the mock: `InfoMejaPage`/`FormMejaNftPage` are built with `tableRecord:` only (`meja_nft_body.dart:240,290`), `InfoSeedingPage` with `sowingRecord:` only (`dashboard_body.dart:157`, `penyemaian_body.dart:229`). The only callers of `seedingItem:` are `test/app_theme_test.dart:155` and `test/seedling_transfer_test.dart:758`. `MejaNft`/`MejaStatus` appear in no test.
- Evidence: `grep -rn "mejaItem:\|seedingItem:\|MejaNft\|SeedingBatch" lib test`.
- Suggested fix: remove both models and the `mejaItem`/`seedingItem` parameters; rewrite the 2 tests to use `SowingRecord`. This shrinks `info_seeding_page.dart` (439) and `info_meja_body.dart` by about 40 lines each and removes demo text that a reviewer might take for real data. About 3 hours.

---

### F3-6 [G9] "Inventory" copies of shared widgets that the rest of the app already generalised
- Severity: high
- Status: VERIFIED
- Where and what (copy vs the shared widget it ignores):
  - `views/widgets/inventory_notice.dart` (64) vs `surface_notice.dart` (64): same layout, same retry button; only padding constants (`16`/`8` vs `AppSpacing.md`/`xs`) differ.
  - `views/widgets/inventory_colors.dart` (14): a subclass whose own comment says it is the "old name for `AppSurfaceColors`". Used by 7 inventory files only.
  - `views/widgets/inventory_placeholder.dart` (34) vs `surface_placeholder.dart` (44): same skeleton card.
  - `views/widgets/inventory_empty.dart` (80) vs `surface_empty_state.dart` (67): same icon + title + message + text-button column; `InventoryEmpty` hardcodes three cases that `SurfaceEmptyState` takes as parameters.
  - `inventaris_body.dart:337-392` `_InventorySearchBar` vs `views/widgets/surface_search_field.dart` (73): identical `InputDecoration` line for line. The shared widget's own doc says "bergaya inventaris".
  - `views/widgets/inventory_illustration.dart` (66) vs `feature_illustration.dart` (42): both are `ExcludeSemantics(Image.asset(...errorBuilder icon))`; only the fallback icon differs; both define the same three asset paths (`inventory-stock.png`, `empty-inventory.png`, `no-search-results.png`).
  - `views/pages/connected_inventory_page.dart:281-302` `_Notice` (F3-4).
- Evidence: side-by-side reads of the files above. `grep -rlw InventoryColors lib` lists 8 files; `AppSurfaceColors` is used by 17.
- Suggested fix: delete `InventoryNotice`, `InventoryColors`, `InventoryPlaceholder`, `_InventorySearchBar`; make `InventoryEmpty` a thin call of `SurfaceEmptyState`; merge the two illustration widgets (one `AppIllustration` with an optional fallback icon). Net: about 260 lines out, one design vocabulary. About 4 hours, tests `inventory_redesign_test.dart` and `inventory_form_layout_test.dart` need a run.

---

### F3-7 [G9] The list-screen scaffold is copy-pasted into 5 bodies
- Severity: high
- Status: VERIFIED
- Where: `inventaris_body.dart`, `meja_nft_body.dart`, `panen_body.dart`, `penjualan_body.dart`, `penyemaian_body.dart`.
- What: Each body repeats the same skeleton: `ColoredBox` + `Stack` + `RefreshIndicator` + `CustomScrollView`/`ListView`, the keyboard-aware `showAction` flag, `52 * textScaler + AppSpacing.xl` button space, and the floating button on a transparent-to-opaque canvas gradient (`colors.canvas.withValues(alpha: 0)` to `alpha: 0.92`). Each also carries its own `ChoiceChip` row with the same `AnimationStyle(140ms, 100ms, easeOutCubic)` and the same `HapticFeedback.selectionClick` logic.
- Evidence (every copy):
  - gradient: `inventaris_body.dart:523-524`, `meja_nft_body.dart:267-268`, `panen_body.dart:338-339`, `penjualan_body.dart:423-424`, `penyemaian_body.dart:261-262`.
  - keyboard flag `viewInsets.bottom == 0`: `inventaris_body.dart:160`, `meja_nft_body.dart:68`, `panen_body.dart:92`, `penjualan_body.dart:193`, `penyemaian_body.dart:62`.
  - `ChoiceChip` rows: `inventaris_body.dart:425`, `meja_nft_body.dart:338`, `panen_body.dart:413`, `penyemaian_body.dart:332`. Chip animation block: `inventaris_body.dart:412`, `meja_nft_body.dart:325`, `panen_body.dart:400`, `penyemaian_body.dart:319`.
  - a sixth, plainer chip row: `connected_inventory_page.dart:150,159`; a seventh style: `employee_list_page.dart:296-323`.
- Suggested fix: add three shared widgets in `lib/views/widgets`: `FloatingActionBar` (gradient + `RowButton`, ~50 lines), `FilterChipRow<T>` (~70 lines), `RefreshableListScaffold` (canvas, refresh, keyboard flag, bottom space, ~90 lines). Each body loses 60 to 90 lines, so they drop below 300 without further splitting. About 1.5 days.

---

### F3-8 [G9] Form fields, pickers and sheets are re-built per screen; shared components exist but 8 forms ignore them
- Severity: medium
- Status: VERIFIED
- Where: shared components `views/widgets/custom_input_field.dart`, `custom_dropdown_field.dart` (own bottom-sheet picker), `custom_text_area.dart`. Ignoring copies:
  - text fields built by hand: `add_form_inventaris_page.dart:417-449`, `employee_form_sheet.dart:331-468`, `panen_form_body.dart:211-231`, `form_catat_kerusakan_body.dart:308,361`, `seedling_transfer_sheet.dart:420,459`, `login_page.dart:337-436`, `employee_list_page.dart:174`, `transfer_note_dialog.dart:80`.
  - pickers: `add_form_inventaris_page.dart:451-629` (own sheet, 180 lines), `seeding_form_page.dart:144-220` (`_chooseSeed`), plus `DropdownButtonFormField` in `form_catat_kerusakan_body.dart:273,328`, `form_meja_nft_body.dart:203`, `panen_form_body.dart:403`, `seedling_transfer_sheet.dart:380`.
  - `CustomDropdownField` is used by one screen only (`catat_penjualan_body.dart:435,522`).
  - modal grabber chrome: `employee_form_sheet.dart:155-181`, `catat_penjualan_body.dart:361-400`, `add_form_inventaris_page.dart:527-559`, `custom_dropdown_field.dart:45`; `showDragHandle: true` at `inventaris_body.dart:59` and `penjualan_body.dart:51`.
  - `showDatePicker`, five times with their own theme builder: `catat_penjualan_body.dart:197`, `form_catat_kerusakan_body.dart:86`, `panen_form_body.dart:137`, `seeding_form_page.dart:134`, `seedling_transfer_sheet.dart:147`.
  - `showModalBottomSheet`, 9 call sites with different options: `employee_form_sheet.dart:38`, `catat_penjualan_body.dart:26`, `inventaris_body.dart:54`, `penjualan_body.dart:46`, `add_form_inventaris_page.dart:508`, `info_seeding_page.dart:416`, `seeding_form_page.dart:146`, `custom_dropdown_field.dart:25`, `transfer_seedling_bottom_sheet.dart:19`.
- What: The app has three visual dialects: (a) `AppSurfaceColors` (adaptive, light/dark) in inventory, nursery, panen, penjualan bodies; (b) raw `AppColors` in cuaca, accounts/employees, add-inventory, catat-penjualan; (c) default Material styling in `panen_form_body.dart`, `seedling_transfer_sheet.dart`, `connected_inventory_page.dart`. Forms in (c) look unlike the rest and cannot follow dark mode.
- Suggested fix: standardise on `CustomInputField` / `CustomDropdownField` / one `OptionPickerSheet` / one `showAppDatePicker` / one `ModalSheetScaffold`; migrate (b) and (c) to `AppSurfaceColors`. About 3 days, mostly mechanical. Layout tests (`*_layout_test.dart`) will catch overflow regressions.

---

### F3-9 [G9] Permission gates and error/empty/access-denied states are repeated everywhere
- Severity: medium
- Status: VERIFIED
- Where: `permissions.contains(` appears 74 times in 25 lib files (most: `seedling_transfer_sheet.dart` 7, `panen_form_body.dart` 5, `form_catat_kerusakan_body.dart` 5, `dashboard_body.dart` 5). "Akses ... tidak diizinkan" text is written 19 times: `profile_page.dart:321`, `catat_penjualan_body.dart:336`, `cuaca_body.dart:314`, `detail_tanaman_meja_body.dart:43`, `form_catat_kerusakan_body.dart:197`, `form_meja_nft_body.dart:142`, `info_meja_body.dart:26`, `laporan_panen_body.dart:31`, `meja_nft_body.dart:56`, `panen_body.dart:78`, `panen_form_body.dart:239`, `penjualan_body.dart:151`, `add_form_inventaris_page.dart:181`, `catat_penjualan_page.dart:30`, `info_seeding_page.dart:39`, `penjualan_page.dart:27`, `seeding_form_page.dart:237`, `harvest_access.dart:24`, `seedling_transfer_sheet.dart:284`. Penjualan alone checks `penjualan:read` in 4 places (`main_page.dart:67`, `penjualan_body.dart:143`, `penjualan_page.dart`, `catat_penjualan_body.dart:221,332`).
- What: `SessionUser` (`data/services/api_client.dart:15`) has no `can('x')` helper; there is no shared `PermissionGate` widget (there is a one-feature `HarvestAccess`, `views/widgets/harvest_access.dart`). Error-with-retry states exist as `_buildErrorState` (`cuaca_body.dart:326`, `employee_list_page.dart:369`), `_buildAccessDenied` (`cuaca_body.dart:300`, `profile_page.dart:318`), `_buildStateMessage` (`employee_list_page.dart:398`), `SurfaceEmptyState`, `InventoryEmpty`, `_Notice`. The same outlined-teal retry button style (`side: width 1.2`, pill, padding 20/12) is spelled out at `employee_list_page.dart:337,359,383`, `cuaca_body.dart:375`, `profile_page.dart:374`, `account_body.dart:184`.
- Suggested fix: `SessionUser.can(String)`; a `PermissionGate({required String permission, required Widget child})` that shows one "no access" state; reuse `SurfaceEmptyState` for all empty/error/denied pages. About 1 day; removes about 150 lines.

---

### F3-10 [G9] "Pending command" and error-classification logic is copied across 6 viewmodels
- Severity: high
- Status: VERIFIED
- Where: six command classes with the same fields (`key`/`itemKey`, `uncertain`, `running`, `receipt`, `attempt`):
  - `HarvestCommand` `panen_viewmodel.dart:47-56` (+ `HarvestCommands` 58-61)
  - `TableCommand` `connected_table_viewmodel.dart:84-90`
  - `DamageCommand` `damage_viewmodel.dart:34-42`
  - `SowingCommand` `sowing_draft.dart:39-46`
  - `InventorySaveCommand` `inventory_draft.dart:39-47`
  - `SeedlingTransferCommand` `connected_nursery_viewmodel.dart:29-58` (a `ChangeNotifier` variant)
  Each is stored in a map-in-a-Provider keyed by `(origin, userId[, id])`: `harvestCommandsProvider`, `tableCommandsProvider`, `damageCommandsProvider`, `sowingCommandsProvider`, `inventoryCommandsProvider`, `seedlingTransferCommandsProvider`.
- What (copies of the same rules):
  - "Is the failure uncertain?" `e is! ApiException || e.status == 0 || e.status >= 500 || e.code == 'SESSION_CHANGED'`: `connected_table_viewmodel.dart:233-237`, `damage_viewmodel.dart:238-242`, `panen_viewmodel.dart:428-432`. The negated form "definitely rejected" (4xx and not SESSION_CHANGED): `connected_nursery_viewmodel.dart:187-190` and `274-278`, `connected_inventory_viewmodel.dart:254-258`.
  - "Denied" (401/403 clears the list): `connected_inventory_viewmodel.dart:177`, `damage_viewmodel.dart:130-131`, `panen_viewmodel.dart:173`, `penjualan_viewmodel.dart:100-101`.
  - "same target and same JSON body, so reuse the key": `connected_table_viewmodel.dart:182-186,191-196` and `panen_viewmodel.dart:357-374` use `jsonEncode(command.body) != jsonEncode(body)` twice each.
  - Result enums identical: `HarvestSubmitResult` (`panen_viewmodel.dart:18`) and `DamageSubmitResult` (`damage_viewmodel.dart:32`), both `{ saved, savedRefreshFailed, failed, busy }`. Same warning string `'Tersimpan. Data terbaru belum dapat dimuat: $warning'` at `panen_viewmodel.dart:422` and `damage_viewmodel.dart:232`.
  - Stale-response guard `++_generation` ... `generation == _generation`: `connected_table_viewmodel.dart` (3), `panen_viewmodel.dart` (2), `penjualan_viewmodel.dart` (2).
  - Three identical clocks `Provider<DateTime Function()>((ref) => DateTime.now)`: `growthClockProvider` (`damage_viewmodel.dart:47`), `nurseryClockProvider` (`connected_nursery_viewmodel.dart:16`), `penjualanClockProvider` (`penjualan_viewmodel.dart:282`). The harvest viewmodel imports the damage file just for its clock (`panen_viewmodel.dart:13`).
- Suggested fix: one `lib/viewmodels/support/` with `IdempotentCommand` (key, uncertain, running, receipt), `isDefinitelyRejected(Object)` / `isUncertain(Object)` / `isAccessDenied(Object)` on `ApiException`, one `SubmitResult` enum, one `clockProvider`. Estimated 1.5 to 2 days; removes about 120 lines and makes each rule readable in one place. Tests in `*_viewmodel_test.dart` already cover the behaviour, so they are the safety net.

---

### F3-11 [G9] Repeated wiring and parsing in the data layer
- Severity: medium
- Status: VERIFIED
- Where:
  - Repository providers, 8 copies of `Provider((ref) => XRepository(ref.watch(apiClientProvider)))`: `connected_table_viewmodel.dart:9`, `connected_nursery_viewmodel.dart:318`, `damage_viewmodel.dart:345`, `panen_viewmodel.dart:64`, `penjualan_viewmodel.dart:286`, `connected_inventory_viewmodel.dart:316`, `employee_repository.dart:189`, `profile_repository.dart:63`. They live in viewmodel files, not next to the repositories.
  - Pagination loops with inline meta checks (`meta['total_pages'] is! int`, `data.length > N`, "duplicate", "incomplete"): `table_repository.dart:33`, `nursery_repository.dart:28`, `damage_repository.dart:126`, `harvest_repository.dart:105`, `sales_repository.dart:25`, `inventory_repository.dart:144`, `employee_repository.dart:70` (7 copies, each 30 to 45 lines). `ApiClient` has no `getAllPages`.
  - Positive-integer-as-string ID validation: `harvest_record.dart:3-12` (`harvestId`), `sale_record.dart:4-13` (`saleId`, identical body, other message), `damage_record.dart:19-21`, `transfer_record.dart:34-36`, `inventory_record.dart:135-141` (`_id`), `inventory_repository.dart:155-157`. `nursery_record.dart` and `table_record.dart` cast with `as String` instead, so validation strictness differs by model.
  - `YYYY-MM-DD` validation `DateTime.tryParse(v)` + `apiDate(parsed) != v`: `harvest_record.dart:14-20`, `sale_record.dart:15-21`, `sowing_draft.dart:22-24`, `damage_viewmodel.dart:272`; `damage_record.dart` and `transfer_record.dart` use a weaker `tryParse == null`.
  - Formatters: `seedling_transfer_sheet.dart:128` `_formatDate` duplicates `apiDate` (`core/business_date.dart:6`) and is the only `DateFormat` yyyy-MM-dd; `_roundKg` is defined twice (`penjualan_viewmodel.dart:279`, `catat_penjualan_body.dart:188`); `DateFormat('dd/MM HH:mm')` (`inventaris_body.dart:329`) vs `DateFormat('dd/MM/yyyy HH:mm')` (`connected_inventory_page.dart:130`) vs `formatTanggalIndo` (`core/formatting.dart`) for the same "last updated" idea. Currency and weight formatting are centralised (`formatRupiah`, `formatAngka`) and used consistently: good.
  - `serviceError()` (error to user text) is defined once (`session_viewmodel.dart:59`), which is correct, but it sits in the session viewmodel and is imported by 6 views; it belongs in `core/`.
- Suggested fix: `ApiClient.getAllPages<T>(path, parse, {pageSize})`; `core/wire_validators.dart` with `positiveId(value, label)` and `isoDate(value, label)`; move repository providers into `data/repositories/providers.dart`; move `serviceError` to `core/`. About 2 days; removes about 250 lines and makes the validation uniform.

---

### F3-12 [G9] Dead members and unused constants inside live files
- Severity: low
- Status: VERIFIED (each by `grep -rnw` over `lib/` and `test/`)
- Where (zero callers anywhere): `availableBatchPanenProvider` (`penjualan_viewmodel.dart:309`), `PenjualanViewModel.fetchPenjualanData` (`:46`), `CatatPenjualanViewModel.validateForm` (`catat_penjualan_viewmodel.dart:146`), `PanenViewModel.pendingCorrection` (`panen_viewmodel.dart:102`), `InventoryRepository.fetchCategories` (`inventory_repository.dart:18`; `inventoryCategoriesProvider` calls `fetchInventoryCategories` instead), `TableRecord.isInactive` (`table_record.dart:30`), `SeedingBatch.progressRatio` (`seeding_batch_model.dart:38`), `AbTestingService.clearLogs` (`ab_testing_service.dart:33`), `AppRadius.dialog` (`app_theme.dart:56`), `AppGlass.navBlurSigma`, `headerBlurSigma`, `navTintLight`, `navTintDark`, `borderLight`, `borderDark` (`app_theme.dart:99,100,107,113,117,119`), `FeatureIllustration.weather` and `.emptyInventory` (`feature_illustration.dart:15,17`).
  Used only by tests (production never calls them): `CatatPenjualanViewModel.setHargaPerKg` (`:85`, test `penjualan_test.dart:423`), `ApiClient.setTokens` (`api_client.dart:302`, 31 test references, 0 in lib), `SalesRepository.getSale` (`sales_repository.dart:57`; the test fixture re-implements it), `AbTestingService.loggedEvents`.
- Asset: `assets/illustrations/features/weather-greenhouse.png` (230 KB) is referenced only by the unused `FeatureIllustration.weather`; every other asset is used (three inventory PNGs are referenced by name without extension in `inventory_illustration.dart:19-35`, which is why a plain filename grep misses them). The two login images are 1.28 MB and 1.45 MB (`assets/logo/hidrosense-miaw.png`, `assets/side-ultility/Modern Hydroponic Greenhouse Row.png`; the folder name `side-ultility` is a typo).
- Fields written but never read: not found in a sample of the viewmodel states (`refreshWarning`, `counts`, `conflictId` are all read). I did not audit every field of 143 files, so treat this as not exhaustively checked.
- Suggested fix: delete the list above; about 1 hour. `availableBatchPanenProvider` is the only top-level provider with no reader (checked by `prov.py`).

---

### F3-13 [G9] Over-engineering and thin wrappers
- Severity: medium
- Status: VERIFIED
- Where and what:
  1. `lib/core/telemetry/ab_testing_service.dart` (40 lines): an "A/B testing" service with an experiment key, an enum of two layout variants (`variantAInline`, `variantBHub`), and a getter hard-coded to `variantBHub`. `EmployeeLayoutVariant` is read nowhere outside the file. Events go to an in-memory list and `debugPrint`; they never leave the device. It is injected into `EmployeeViewModel` (`employee_viewmodel.dart:85,131,160,232,252`) only to log 4 events. For an offline-first product with no analytics backend it is a framework for one non-use. Remove it and the 3 test assertions in `employee_viewmodel_test.dart:186-218`, or reduce to a one-line `debugPrint`.
  2. `views/widgets/transfer_seedling_bottom_sheet.dart` (35 lines): a widget whose `build` returns `SeedlingTransferSheet` with the same arguments, plus a `show` helper. Used once (`penyemaian_body.dart:233`); `info_seeding_page.dart:416-428` opens the same sheet by hand with identical options. Make `SeedlingTransferSheet.show` and use it in both places; delete the wrapper (and adapt `transfer_seedling_bottom_sheet_test.dart`).
  3. `InventoryColors` (alias subclass, F3-6) and `InventoryNotice`/`InventoryPlaceholder` (copies).
  4. Two projections of the same sale: `SaleRecord`/`SaleDetail` (`data/models/sale_record.dart`, 248 lines, exact BigInt weights) and `PenjualanItem`/`PenjualanLine`/`BatchPanen` (`models/penjualan_model.dart`, 115 lines) with a 60-line mapper `_toItem/_toBatches` (`penjualan_viewmodel.dart:198-260`). The mapper converts BigInt hundredths to `double` (`_minorToDouble`), which gives up the exactness the data layer worked to keep. Views could read `SaleRecord` directly or `PenjualanItem` could wrap it.
  5. `abstract class EmployeeRepository` + `EmployeeRepositoryImpl`, and `ProfileRepository` + `ProfileRepositoryImpl`: one production implementation each. They are justified only because tests fake them (`employee_viewmodel_test.dart:10`, `profile_test.dart:46`). Every other repository (`HarvestRepository`, `TableRepository`, ...) is a concrete class and is faked through the `ApiClient` or provider overrides, so the accounts feature is the odd one out. Low value to change; mention for consistency.
  6. Provider-held mutable maps used as a process-lifetime cache for in-flight commands (F3-10) are a pattern, not a framework, but they are the hardest thing for a new reader to follow; they deserve one doc comment in one place after F3-10.
  7. Test seams in production signatures: `autoLoad`, `initialState`, `clock`, `commands` constructor parameters on 6 viewmodels, and `ApiClient.setTokens` (test-only). Acceptable, but each adds a branch a newcomer must read.
  8. `pubspec.yaml:84-95`: the `fonts:` block is commented out, yet `AppTypography.fontFamily = 'Inter'` (`app_theme.dart:124`) is applied to every text style. No font file is bundled, so the setting has no effect and the app falls back to the platform font. Either bundle Inter or remove the constant.
- Suggested fix: items 1, 2, 4 first. About 1 day together.

---

### F3-14 [G7/G9] Two folder conventions and two model folders
- Severity: low
- Status: VERIFIED
- Where: `lib/features/accounts/**` and `lib/features/auth/**` (11 + 1 files, feature-first) next to the layer-first `lib/views`, `lib/viewmodels`, `lib/data`. `lib/models` (5 files: `penjualan_model`, `weather_model` live; `meja_nft_model`, `seeding_batch_model` mock; `inventory_item_model` dead) next to `lib/data/models` (10 wire models). `SowingDraft` and `InventoryDraft` live in `viewmodels/` while `HarvestDraft`, `DamageDraft`, `SalesDraft` live in `data/models/`. `SessionUser` is defined in `data/services/api_client.dart:15`. `lib/features/accounts` imports `../../../../views/theme/app_theme.dart` and `views/components/header.dart` upward, so it is not independent of `views/`.
- What: A reader cannot guess where a model or form lives. Only `accounts/auth` follow the feature layout.
- Suggested fix: pick one. Cheapest: move `features/accounts` and `features/auth` into the layer folders, move `lib/models/*` that survive F3-5 into `data/models`, and put all drafts next to their records. About 1 day (imports only).

---

## Duplicate-code index (for quick lookup)

| Pattern | Copies (file:line) | Shared component that exists but is ignored |
|---|---|---|
| Search field | `inventaris_body.dart:337`, `connected_inventory_page.dart:135`, `employee_list_page.dart:174`, `custom_search_bar.dart` (dead) | `surface_search_field.dart` (used by meja, panen, penjualan, penyemaian) |
| Category/status chips | `inventaris_body.dart:395`, `meja_nft_body.dart:304`, `panen_body.dart:376`, `penyemaian_body.dart`, `employee_list_page.dart:296`, `connected_inventory_page.dart:144`, `filter_button.dart` (dead) | none (create `FilterChipRow`) |
| Notice banner | `inventory_notice.dart`, `connected_inventory_page.dart:281`, `cuaca_body.dart:392`, `penjualan_body.dart:229`, `employee_form_sheet.dart:258` | `surface_notice.dart` |
| Empty / error state | `inventory_empty.dart`, `cuaca_body.dart:326`, `employee_list_page.dart:325-449`, `penjualan_body.dart:168` | `surface_empty_state.dart` |
| Loading skeleton | `inventory_placeholder.dart` | `surface_placeholder.dart` |
| Floating bottom button | 5 bodies (F3-7) | `row_button.dart` is used, the gradient wrapper is not shared |
| Text field | 9 hand-built (F3-8) | `custom_input_field.dart`, `custom_text_area.dart` |
| Picker sheet | `add_form_inventaris_page.dart:500`, `seeding_form_page.dart:144`, `custom_dropdown_field.dart:25` | `custom_dropdown_field.dart` |
| Date picker | 5 (F3-8) | none |
| Status badge / capsule | `capsule_badge.dart` is widely used (16 files): good. `category_badge.dart`, `stock_status_badge.dart` (dead) were earlier copies | `capsule_badge.dart` |
| Cards | `base_col_card.dart` (BaseColCard) and `row_info_card_md.dart` (RowInfoCardMd) differ only in press feedback and shape defaults; `info_card_md.dart` (dead) was a third | merge into one `AppCard` |
| Buttons | `col_button.dart` (3 uses, `info_seeding_page.dart`) and `row_button.dart` (16 uses) are two pill buttons with different parameter names | merge |
| Page = Scaffold + Header + Body | 11 thin page files (19 to 53 lines); `Header` text-scale formula is pasted in 4 pages (`meja_nft_page.dart:19`, `detail_tanaman_meja_page.dart:12`, `panen_page.dart:14`, `laporan_panen_page.dart:14`) | a `HeaderHeight.forScale(context)` helper |
| Snackbars | 19 `showSnackBar` calls, 33 `HapticFeedback` calls, each assembling its own colours/text | a small `showAppSnack(context, message, {error})` |

## Two code paths for the same feature (summary, goal 9 item 4)

- Inventory: `InventarisBody` (live) vs `ConnectedInventoryPage` (unreachable) , F3-4.
- Meja (tables) and Penyemaian detail: backend records vs `MejaNft` / `SeedingBatch` mocks, F3-5.
- Sales: wire `SaleRecord` vs UI `PenjualanItem`, both live, F3-13.4.
- `lib/models` vs `lib/data/models`, `lib/features` vs `lib/views`: layout split, F3-14. Not a behavioural double path.
- Screens still on mock data instead of the backend: none found. Every viewmodel loads through a repository; the only fixed lists are UI option lists (`_units` in `add_form_inventaris_page.dart:40`, status options). The BMKG weather service is the one network call outside the backend, as the plan allows.

## Met and fine

- No `Future.delayed` fake, no `mockData`, no `defaultPenjualanList`, no TODO or FIXME in `lib/`.
- All declared asset folders exist and every image is referenced (one const unused, F3-12).
- Of the top-level providers checked by `prov.py`, all but one (`availableBatchPanenProvider`, F3-12) are read by other `lib/` code.
- `core/formatting.dart` and `core/business_date.dart` are the right size (42 and 18 lines) and the currency/number/Indonesian-date formatters are used consistently.
- `CapsuleBadge`, `SurfaceSectionHeader`, `SurfaceSearchField`, `SurfaceEmptyState`, `RowButton` are well-reused shared widgets (used by 4 to 16 files each).
- 105 of 143 files are 200 lines or less; 75 are 100 or less. The oversize problem is concentrated in about 30 files, so it is fixable.
- Backend `src` is within the rule (only `db/seed.ts` at 215).
- `flutter analyze` is clean, but note it cannot see F3-3 (unused public files) or F3-12; those need the import-graph check done here.

## Count by severity

- critical 0
- high 5 (F3-1, F3-2, F3-6, F3-7, F3-10)
- medium 7 (F3-3, F3-4, F3-5, F3-8, F3-9, F3-11, F3-13)
- low 2 (F3-12, F3-14)
- Total 14.

Suggested order of work (rough total 10 to 14 days for one developer): F3-3 and F3-12 deletions (half a day, zero risk) , F3-4 and F3-5 (half a day), F3-6 and F3-7 shared widgets (2 days), F3-10 and F3-11 shared logic (4 days), then F3-2 splits of the 12 files (about 5 days, shorter because F3-6/7/8 already remove 60 to 90 lines from most of them).
