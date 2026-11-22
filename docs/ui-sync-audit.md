# UI sync audit: Figma v3 vs apps/mobile and apps/backend

Date: 22 November 2026
Branch at time of audit: `feature/ml-production-pipeline` (working tree dirty)
Status: audit only. No app code, backend code or Figma content was changed.

Sources: Figma file `KZ7dODi36pWhEPumnRz7RG` (read through the Figma MCP: page list, frame
list per page, variables of `Foundations/Color`), `apps/mobile/lib`, `apps/backend/src`,
`apps/backend/API.md`, `docs/laporan-frontend-v2-untuk-backend.md`. Import graph computed
from `import` and `export` statements in `apps/mobile/lib` (306 Dart files).

How to read the status columns. "Referenced" means the frame number appears in v2 code
(page, component or doc comment). It does not prove the pixels match Figma. A visual pass
per screen is still needed (see "Not verified").

## 1. Headline findings

1. The Figma file has **225 screen frames** on pages 01 to 11 (not 85). It also has `00 Foundations`
   (components), `QA v3` (6 screens x 2 widths: 390 and 360) and `Logo v3`.
2. **The v3 theme is already in code.** Every colour and type token read from Figma
   `Foundations/Color` matches `lib/views/v2/theme/v2_tokens.dart` exactly (Royal blue `#1565FF`
   primary, lime `#A3F533` / `#8EDB22`, neutrals, status colours, Poppins ramp). No coral v2
   values found. Only 2 files still hard-code hex outside the token file:
   `views/v2/widgets/v2_button.dart`, `views/v2/widgets/v2_card.dart`.
3. **223 of 225 frames are referenced in v2 code.** Not referenced: `1.3 Welcome 2` and
   `1.6a Login terisi (keyboard)`. These are probably covered by a shared onboarding list and a
   keyboard state, and need a visual check.
4. **The running app still opens v1 by default.** `lib/main.dart` uses the v1 `AppTheme` and
   `AppGate`. `AppGate` shows v1 `MainPage` unless `v2UiModeProvider` is true (default
   `false`, set only by the v2 login form). So v1 deletion needs a switch of the default
   path, not only file removal.
5. **91 files are legacy v1** (not reachable from any v2 file). 65 non-v2 files are shared with v2
   and must stay. 30 test files import legacy code and must be removed or rewritten with it.
6. **Backend:** every feature the v2 screens use has an endpoint, except treatment records
   (`09 Perawatan`). Detection, photo and recommendation are AI and are skipped.
   Notifications are implemented but undocumented in `API.md`.

## 2. Screens: Figma page to Flutter

| Figma page | Frames | Flutter pages / components (lib/views/v2) | Status | Backend | Status |
|---|---|---|---|---|---|
| 01 Onboarding & Auth | 13 (1.1-1.11, 1.5a, 1.6a) | `v2_onboarding_page`, `v2_login_page`, `v2_inactive_account_page`, `v2_offline_login_page`, `v2_notification_permission_page`, `v2_home_empty_state` | Referenced, except 1.3 and 1.6a | `POST /auth/login`, `/auth/refresh`, `/auth/me`, `/auth/logout`; `403 ACCOUNT_DEACTIVATED` | EXISTS |
| 02 Beranda & Notifikasi | 7 | `v2_beranda_page`, `v2_beranda_connected_page`, `v2_notifications_page`, `v2_cycle_detail_page`, beranda hero, stats, skeleton | Referenced | notifications feature (read state, migration 0019); sync queue | EXISTS (not in API.md) |
| 03 Akun | 17 | `v2_akun_tab_page`, `v2_employee_list/detail/form_page` | Referenced | `/employees` CRUD, activate, deactivate; `/profile` | EXISTS |
| 04 Inventaris | 31 | `v2_inventaris_list/detail/form_page`, catat stok sheet, archive state | Referenced | `/jenis-inventaris`, `/obat`, `/inventaris`, `/stok`, `/stok/:id/reverse`, `/inventaris/:id/saldo` | EXISTS |
| 05 Semaian | 31 | `v2_semaian_list/detail/form/edit_page`, `v2_pindah_meja_page`, date sheet | Referenced | `/penyemaian`, `/pemindahan`, `expected_version` | EXISTS |
| 06 Meja Tanam & Pertumbuhan | 30 | `v2_meja_list/detail/form_page`, `v2_pilih_semaian_page`, `v2_detail_tanaman_page`, `v2_tanaman_rusak_page` | Referenced | `/meja-tanam`, `/pemindahan`, `/kerusakan` | EXISTS |
| 07 Panen | 23 | `v2_panen_list/detail/form/edit_page` | Referenced | `/panen` (create, list, detail, patch with `expected_version`) | EXISTS |
| 08 Penjualan | 24 | `v2_penjualan_list/detail/form/summary_page`, form `.edit` constructor (8.21) | Referenced | `/penjualan` (create, list, detail, patch) | EXISTS |
| 09 Perawatan & Hama | 28 | `v2_rawat_list/foto/hasil/obat/konfirmasi/detail_page`, `v2_rawat_ai_banner`, `v2_rawat_foto_card` | UI referenced. The connected tab shows damage reports only; "Foto tanaman" only explains the missing endpoint | No `/perawatan`, `/hama`, photo or recommendation endpoints (`API.md` "Belum tersedia") | **MISSING**: photo, detection and recommendation are AI = SKIPPED. Treatment record (9.21-9.27: confirm, deduct medicine stock, detail) is non-AI: needs a decision |
| 10 Cuaca BMKG | 11 | `v2_cuaca_page`, cuaca cards, location sheet (10.5), AI-advice states (10.3, 10.4, 10.10, 10.11) | Referenced | BMKG is called from the app, not the backend. Advice states are AI | SKIPPED (AI) |
| 11 Sinkron & Profil | 10 | `v2_sinkron_page` (incl. conflict 11.8, fix data 11.9, session ended 11.10), sinkron skeleton and rows | Referenced | `GET /sync/changes`, `POST /sync/operations`, idempotency, conflict `409` | EXISTS |
| 00 Foundations | 53 nodes (components, tokens) | `views/v2/widgets`, `views/v2/components`, `theme/v2_tokens.dart`, `v2_foundation_gallery` | Tokens match. Component parity not checked per component | n/a | n/a |
| QA v3 | 12 frames (6 screens at 390x844 and 360x640) | `test/responsive_overflow_test.dart` is a v1-era test | Not verified at 360 width | n/a | n/a |
| Logo v3 | 1 page | not audited | Not verified | n/a | n/a |

## 3. Token map (v3, Royal blue primary)

Read from Figma `Foundations/Color` (node `122:14755`) and compared with `v2_tokens.dart`.

| Role | Token | Hex | In code |
|---|---|---|---|
| Primary action, nav, active | `blue-500` / `blue-600` / `blue-700` / `blue-800` | `#1565FF` / `#0F4FD6` / `#0B4FD1` / `#0B3FAE` | match |
| Tint surface | `blue-50` | `#EAF2FF` | match |
| Secondary accent (highlight, success, chart) | `lime-400` / `lime-500` | `#A3F533` / `#8EDB22` | match |
| Ink, secondary text | `charcoal-900`, `slate-400/500/600`, `color-text-secondary` | `#111827`, `#7A8494`, `#6B7280`, `#4B5563` | match |
| Canvas, card, border | `gray-50`, `prim-white`, `gray-200` | `#F6F8FA`, `#FFFFFF`, `#E5E8EC` | match |
| Status | `green-700/100`, `amber-500/800/100`, `red-700/100` | as in file | match |
| Type | Poppins H1 28/36 Bold, H2 20/28 SemiBold, Label Strong 14/20 | | match (H1, H2 confirmed) |

Deviations: `v2_button.dart` and `v2_card.dart` hard-code hex. Lime must not be a primary or a
fill for mascot, illustration or icon. This was not checked per screen.

## 4. Backend gaps (non-AI)

| Need | Endpoint today | Status | Proposed work |
|---|---|---|---|
| Notifications list and read | `registerNotifications`, table `notification_reads` | EXISTS | Document in `API.md` |
| Field-level validation errors | `error.message` only | PARTIAL | Add `error.details[{field,message}]` (recommended in `laporan-frontend-v2-untuk-backend.md`). Optional, not release-blocking |
| Limits in `API.md` (1000 holes, 30-char code, 1000-char note) | undocumented | PARTIAL | Document |
| Low-stock card count by type | aggregate over all types | DECISION | Product decides option A (seed only) or B (no type filter) |
| Treatment record (confirm care, deduct medicine, history) | none | MISSING | **Decision needed.** Non-AI. Needs table, `POST/GET /perawatan`, stock ledger link. Otherwise keep the damage-report mapping as is |
| Pest detection, photo analysis, recommendation, weather advice | none | SKIPPED (AI) | not in scope |

## 5. Legacy classification (apps/mobile/lib)

Computed from imports. `V2-ONLY` = `lib/views/v2/**`. `SHARED` = non-v2 file reachable from v2.
`LEGACY-v1` = reachable from `main.dart` but not from any v2 file. No v2 file imports a
LEGACY file.

| Class | Files |
|---|---|
| V2-ONLY | 150 |
| SHARED (keep) | 65 |
| LEGACY-v1 (delete after review) | 91 |
| Total | 306 |

Needed before deleting:

- `lib/main.dart` imports `AppTheme` (`views/theme/app_theme.dart`) and `views/pages/app_gate.dart`.
  `AppGate` also imports v1 `LoginPage` and `MainPage`. Switch the default path to v2, with a
  v2 theme built from `V2Colors` and `V2Type`, and remove `v2UiModeProvider` (it is the
  v1/v2 toggle).
- 30 test files import legacy code (list in Appendix B). Delete them with their feature, or
  port the cases to v2 first.
- The LEGACY list below must be re-run just before deleting, because the working tree is dirty.

## 6. Not verified

- Pixel parity per screen. Needs per-frame screenshots against the running app.
- `1.3` and `1.6a`, and every state frame (loading, error, empty) beyond a frame reference.
- 360 px width frames from `QA v3`.
- `Foundations` component parity (Button, Input, Card and so on) against `views/v2/widgets`.
- `Logo v3` and app icons.
- Whether each v2 screen uses connected data or fixtures (`views/v2/connected` covers cuaca,
  inventaris, meja, notifications, panen, rawat, semaian and tanam).

## 7a. Prompt 2 result (22 November 2026, branch `feat/ui-v2-default`)

Done:

- Replaced the 2 hard-coded hex values with `V2Colors.bone` and `V2Colors.red800`. Same colours.
- `1.3` is covered by the onboarding slide range (1.2-1.4). `1.6a` is covered by the
  keyboard-visible branch in `v2_login_page.dart`. Neither has a pixel check yet.
- `QA v3`: new `test/v2_qa_v3_responsive_test.dart` checks the 6 screens at 390x844 with text
  scale 1.3 and at 360x640. All 12 cases pass, no overflow.
- v2 is now the default entry: `main.dart` uses `V2Theme.light`; `AppGate` shows
  `V2OnboardingPage` (signed out, with the new `v2SessionLogin` handler) or
  `V2BerandaConnectedPage` (signed in). v1 `MainPage` and `LoginPage` are no longer reachable
  from the entry.
- Tests updated for the new entry: `app_gate_back_test`, `widget_test`, `connected_flow_test`
  (rewritten as a v2 login and logout gate test).
- Result: `flutter analyze` shows only the 2 known asset-directory warnings; 470 tests pass
  (458 before).

Left for the legacy-removal step (Prompt 3): `v2UiModeProvider` and `views/v2/v2_ui_mode.dart` are
now unused except by the v1 `LoginPage`, so they go with it. The remaining legacy-importing tests
still pass because the v1 files still exist.

## 7b. Prompt 3 result: v1 removed (branch `chore/remove-v1`, commit 863e83c)

- Deleted 89 unreachable v1 lib files plus `views/v2/v2_ui_mode.dart`, and 27 v1-UI test files
  (237 test cases) that only exercised the removed screens. Kept `main.dart` and
  `views/pages/app_gate.dart` (the entry). Kept all SHARED code (core, data, models, viewmodels
  that v2 imports).
- Removed the v1-only top-level `assets/` folder and its 6 `pubspec.yaml` entries (2 pointed at
  folders that did not exist). v2 uses `lib/views/v2/assets`.
- `tool/harvest_device_qa.dart` now uses `V2Theme`.
- Result: `flutter analyze` no issues; 233 tests pass (470 before removal).
- Coverage note: the data layer keeps its repository and viewmodel tests. The removed tests were
  widget tests of v1 screens, so v1-only layout and flow checks are gone with the screens.

## 7c. Prompt 4 result: backend (non-AI) (branch `feat/backend-ui-gaps`)

- `VALIDATION_ERROR` now carries `error.details[{field,message}]` (Indonesian, capped at 20, never
  echoes submitted values). Six new tests in `apps/backend/test/validation-details.test.js`.
- `API.md` documents `details`, the notifications routes (`GET /notifications`,
  `POST /notifications/read-all`) and the meja field limits.
- Notifications feature (migration 0019, store, routes, test) was already in the working tree as
  uncommitted work. It is verified (suite green) and committed with this branch.
- Mobile: `ApiException` parses `details`; `serviceError` shows "Ada isian yang belum sesuai
  (jumlah lubang): Maksimal 1000." when the backend sends it, and the generic sentence otherwise.
- Not built, by decision: treatment records (`/perawatan`). The `perawatan` table requires a
  recommendation (`id_rekomendasi NOT NULL`), which belongs to the AI detection chain, so it
  stays out of scope.
- Not changed: the low-stock card count (aggregate over all types) still needs a product
  decision (option A or B).
- Result: backend typecheck, lint, line limit and 368 tests pass; mobile analyze clean, 236 tests pass.

## 7. Prioritised plan

1. Decide the treatment-record question (section 4).
2. Replace the 2 hard-coded hex values with tokens. Check 360 px QA frames. Visual pass on 1.3 and 1.6a.
3. Make v2 the default entry: v2 theme, `AppGate` straight to v2, remove the v2 toggle.
4. Delete LEGACY-v1 files in batches, with their tests, on branch `chore/remove-v1`, after approval of Appendix A.
5. Backend (non-AI): document notifications and limits in `API.md`; add validation `details` if approved;
   add treatment endpoints only if approved.

## Appendix A: LEGACY-v1 files (91)

Review notes before deleting: `lib/main.dart` is the app entry. It is listed only because no v2
file imports it. Keep it and edit it (step 3 of the plan), do not delete it. Files outside
`lib/views/` (for example `lib/core/growth_rules.dart`, `lib/viewmodels/catat_penjualan_viewmodel.dart`,
`lib/features/accounts/presentation/**`) are not imported by v2 but may hold business rules that v2
should reuse. Check each against the v2 equivalent first.

```
lib/core/growth_rules.dart
lib/core/widgets/wavy_header_clipper.dart
lib/features/accounts/presentation/pages/employee_list_page.dart
lib/features/accounts/presentation/pages/profile_page.dart
lib/features/accounts/presentation/viewmodels/employee_viewmodel.dart
lib/features/accounts/presentation/widgets/employee_dialogs.dart
lib/features/accounts/presentation/widgets/employee_form_sheet.dart
lib/features/accounts/presentation/widgets/employee_tile.dart
lib/features/auth/presentation/widgets/login_header_hero.dart
lib/main.dart
lib/viewmodels/catat_penjualan_viewmodel.dart
lib/viewmodels/sale_form_seed.dart
lib/views/components/account_body.dart
lib/views/components/catat_penjualan_body.dart
lib/views/components/catat_penjualan_fields.dart
lib/views/components/cuaca_body.dart
lib/views/components/custom_bottom_navigation_bar.dart
lib/views/components/dashboard_body.dart
lib/views/components/detail_tanaman_meja_body.dart
lib/views/components/form_catat_kerusakan_body.dart
lib/views/components/form_meja_nft_body.dart
lib/views/components/header.dart
lib/views/components/info_meja_body.dart
lib/views/components/inventaris_body.dart
lib/views/components/laporan_panen_body.dart
lib/views/components/meja_nft_body.dart
lib/views/components/panen_body.dart
lib/views/components/panen_form_body.dart
lib/views/components/penjualan_body.dart
lib/views/components/penyemaian_body.dart
lib/views/components/rekomendasi_cuaca_body.dart
lib/views/pages/account_page.dart
lib/views/pages/add_form_inventaris_page.dart
lib/views/pages/app_gate.dart
lib/views/pages/catat_kerusakan_page.dart
lib/views/pages/catat_penjualan_page.dart
lib/views/pages/cuaca_page.dart
lib/views/pages/detail_tanaman_meja_page.dart
lib/views/pages/form_meja_nft_page.dart
lib/views/pages/info_meja_page.dart
lib/views/pages/info_seeding_page.dart
lib/views/pages/laporan_panen_page.dart
lib/views/pages/login_page.dart
lib/views/pages/main_page.dart
lib/views/pages/meja_nft_page.dart
lib/views/pages/panen_form_page.dart
lib/views/pages/panen_page.dart
lib/views/pages/penjualan_page.dart
lib/views/pages/rekomendasi_cuaca_page.dart
lib/views/pages/seeding_form_page.dart
lib/views/theme/app_theme.dart
lib/views/widgets/app_surface_colors.dart
lib/views/widgets/base_col_card.dart
lib/views/widgets/capsule_badge.dart
lib/views/widgets/card_icon_box.dart
lib/views/widgets/col_button.dart
lib/views/widgets/custom_back_button.dart
lib/views/widgets/custom_dropdown_field.dart
lib/views/widgets/custom_input_field.dart
lib/views/widgets/custom_text_area.dart
lib/views/widgets/estimasi_total_card.dart
lib/views/widgets/feature_illustration.dart
lib/views/widgets/feature_overview_card.dart
lib/views/widgets/fluid_capacity_meter.dart
lib/views/widgets/glass_container.dart
lib/views/widgets/harvest_access.dart
lib/views/widgets/inventory_card.dart
lib/views/widgets/inventory_colors.dart
lib/views/widgets/inventory_empty.dart
lib/views/widgets/inventory_illustration.dart
lib/views/widgets/inventory_notice.dart
lib/views/widgets/inventory_placeholder.dart
lib/views/widgets/inventory_stock_label.dart
lib/views/widgets/inventory_stock_overview.dart
lib/views/widgets/meja_nft_card.dart
lib/views/widgets/panen_card.dart
lib/views/widgets/penjualan_card.dart
lib/views/widgets/row_button.dart
lib/views/widgets/row_info_card_md.dart
lib/views/widgets/sale_date_picker.dart
lib/views/widgets/sale_multi_batch_notice.dart
lib/views/widgets/sale_uncertain_notice.dart
lib/views/widgets/seeding_batch_card.dart
lib/views/widgets/seedling_transfer_sheet.dart
lib/views/widgets/surface_empty_state.dart
lib/views/widgets/surface_notice.dart
lib/views/widgets/surface_placeholder.dart
lib/views/widgets/surface_search_field.dart
lib/views/widgets/surface_section_header.dart
lib/views/widgets/transfer_note_dialog.dart
lib/views/widgets/transfer_seedling_bottom_sheet.dart
```

## Appendix B: test files importing LEGACY-v1 code (30)

```
apps/mobile/test/app_gate_back_test.dart
apps/mobile/test/app_theme_test.dart
apps/mobile/test/connected_flow_test.dart
apps/mobile/test/damage_backend_flow_test.dart
apps/mobile/test/damage_flow_test.dart
apps/mobile/test/dashboard_login_test.dart
apps/mobile/test/employee_viewmodel_test.dart
apps/mobile/test/fluid_capacity_meter_test.dart
apps/mobile/test/growth_backend_flow_test.dart
apps/mobile/test/growth_layout_test.dart
apps/mobile/test/growth_note_dialog_test.dart
apps/mobile/test/harvest_backend_flow_test.dart
apps/mobile/test/harvest_layout_supplement_test.dart
apps/mobile/test/inventory_archive_test.dart
apps/mobile/test/inventory_form_layout_test.dart
apps/mobile/test/inventory_redesign_test.dart
apps/mobile/test/inventory_save_widget_test.dart
apps/mobile/test/inventory_stock_label_test.dart
apps/mobile/test/login_header_hero_test.dart
apps/mobile/test/nursery_widget_remediation_test.dart
apps/mobile/test/panen_test.dart
apps/mobile/test/penjualan_test.dart
apps/mobile/test/penjualan_uncertain_form_test.dart
apps/mobile/test/profile_test.dart
apps/mobile/test/responsive_overflow_test.dart
apps/mobile/test/sales_access_test.dart
apps/mobile/test/seedling_transfer_test.dart
apps/mobile/test/transfer_seedling_bottom_sheet_test.dart
apps/mobile/test/weather_test.dart
apps/mobile/test/widget_test.dart
```
