# Slice F4: Goal 5 (mobile first), Flutter UI

Scope read: `apps/mobile/lib/views/**` (73 files, 14,389 lines), `lib/core/widgets/wavy_header_clipper.dart`, `lib/views/theme/app_theme.dart`, plus the shared pieces they call (`session_viewmodel.dart`, `inventory_draft.dart`, `sale_record.dart`, `formatting.dart`, `main.dart`, `AndroidManifest.xml`, `build.gradle.kts`, `pubspec.yaml`). Some `lib/features/**` widgets were opened where views reuse them (login hero, employee dialogs). I did not run the app or the full test suite. Contrast ratios were computed with a WCAG 2.x script (`scratchpad/review2/f4/c.py`, `d.py`).

## Verdict (goal 5: mobile first)

| Goal | Verdict | One-line evidence |
|---|---|---|
| 5. Mobile first | **Partly** | Layout, text scaling, keyboard, loading/empty/error states and double-submit guards are strong and tested at 320x568 with 2x text. Colour contrast, numeric input, Material localisation, offline reads outside inventory, and memory-only sessions are not phone-in-the-field ready. |
| 1. Offline first (touches F4) | **Partly** | Only inventory has a local cache (`inventory_cache.dart`). Every other screen needs the network to show anything (F4-6). |
| 11. Easy for others to follow (touches F4) | **Partly** | Two colour systems and duplicated widget families (F4-3); technical wording in user text (F4-13). |

## Findings (ranked)

### F4-1 [GOAL 5] Core palette fails WCAG AA for text, badges, icons and field borders
- Severity: high
- Status: VERIFIED (computed ratios; usage read in code)
- Where: `views/theme/app_theme.dart:6-36` (tokens); used at `views/components/cuaca_body.dart:70-109,133-135,240,470`, `views/widgets/stock_status_badge.dart:26-40`, `views/components/catat_penjualan_body.dart:261,566`, `views/components/inventaris_body.dart:101,624-625`, `views/widgets/custom_dropdown_field.dart:70,179`, `views/widgets/custom_input_field.dart:79`, `views/components/custom_bottom_navigation_bar.dart:84`, `views/widgets/col_button.dart:20-22`
- What: The theme tokens used by about 52 files (`AppColors.*`) miss 4.5:1 for normal text, and several miss 3:1 for icons and borders. A second palette, `AppSurfaceColors` (`views/widgets/app_surface_colors.dart:17-30`), passes everywhere, but only about 24 files use it. Outdoors in sunlight the failing pairs are the first to disappear: weather hero text, stock badges, hints, warning buttons.
- Evidence (ratio, then where it matters):

| Pair | Ratio | Used for |
|---|---|---|
| `textPrimary` on canvas | 16.96 | Pass |
| `textSecondary` on white / on canvas | 4.83 / 4.62 | Pass, barely. Fails on `secondarySurface` (4.39) |
| `textTertiary` on white | **2.54** | Placeholders, `caption2` (11sp), chevrons, dropdown hint |
| white on `primaryMint` | **2.09** | Weather hero banner (`cuaca_body.dart:70-109`, includes 11sp caption at 90% alpha), "Simpan Penjualan" button (`catat_penjualan_body.dart:566`), success snackbar (`:261`), account avatar |
| `primaryMint` on white | **2.09** | `ColButton` default text (`col_button.dart:20`), date-picker selection (`catat_penjualan_body.dart:206`) |
| `warningOrange` on white / on `warningBg` | **2.10 / 1.93** | "Stok Menipis" badge text, humidity badge (`cuaca_body.dart:134`), "Arsipkan" button text (`inventaris_body.dart:624`), white label on orange confirm (`:101`) |
| `successGreen` on white / on `successBg` | **2.54 / 2.31** | Icon tint (`account_body.dart:96`), weather status icon (`cuaca_body.dart:277`) |
| `dangerRed` on white / on `dangerBg` | **3.76 / 3.08** | "Stok Habis" badge, inline errors, logout label, error snackbars (white on red 3.76) |
| white on `primaryDarkTeal` (default `ElevatedButton`) | **4.41** | Just under 4.5 |
| `primaryDarkTeal` on `accentMintSoft` over white | 4.09 | "Stok Aman" badge |
| `borderLight` on white (input outline) | **1.24** | Needs 3:1 for non-text; `CustomInputField` and inventory form fields rely on it |
| Passing in `AppSurfaceColors`: secondary 6.03, teal 5.54, error 6.57, warning 6.24, controlBorder 3.87, ink 16.04 | OK | Proof the fix already exists in the repo |

  A local patch confirms the global value is known to be weak: `views/widgets/harvest_access.dart:42` overrides `primary` to `#14675f` (6.70:1) for harvest screens only.
- Suggested fix: Point `AppColors.textSecondary/Tertiary`, `warningOrange`, `dangerRed`, `successGreen`, `primaryMint` (as text/button fill) and `borderLight` (field outline) at the `AppSurfaceColors` values; use dark text on mint and orange fills. About 1 day, mostly a token swap plus golden/test updates.

### F4-2 [GOAL 5] Numeric fields: wrong keyboard, no formatters, rule not enforced while typing
- Severity: medium
- Status: VERIFIED (code); keyboard behaviour SUSPECTED
- Where: `views/pages/add_form_inventaris_page.dart:365,398` (stock, minimum use `TextInputType.number`); `views/pages/seeding_form_page.dart:347` and `views/components/form_catat_kerusakan_body.dart:312` (integer counts, no `digitsOnly`); `views/components/panen_form_body.dart:442-443` (kg fields, no formatter); `views/components/catat_penjualan_body.dart:486-506` (formatter only allows `[0-9.,]`)
- What: The backend rule is "up to 10 digits and 2 decimals, dot". Only 5 `FilteringTextInputFormatter` exist in the whole app and none enforces that rule. Inventory stock allows decimals in validation (`inventory_draft.dart:16`, units include Kg, Liter, Gram) but the field asks for the plain `number` keyboard, which does not guarantee a decimal key on Android (Flutter docs). If the Indonesian keyboard offers a comma, inventory rejects it (`inventory_draft.dart:17` has no comma-to-dot step), while sales and harvest accept it (`sale_record.dart:52`, `harvest_record.dart:34`, `catat_penjualan_body.dart:102`). The sales price error for "20.000" reads "maksimal dua angka desimal" (`catat_penjualan_viewmodel.dart:135`), which does not tell a user who typed a thousands separator what to do.
- Evidence: `grep TextInputType.number|numberWithOptions` gives 9 plain `number` vs 3 `numberWithOptions`; no `autofillHints` outside login.
- Suggested fix: One shared `DecimalField` (keyboard `numberWithOptions(decimal: true)`, formatter allowing one separator and at most 2 decimals, comma normalised to dot) and `digitsOnly` for counts. About 0.5 to 1 day.

### F4-3 [GOAL 5, 11] Two colour systems, three form styles, duplicated widget families
- Severity: medium
- Status: VERIFIED
- Where: `app_theme.dart` (`AppColors`) vs `widgets/app_surface_colors.dart` + `widgets/inventory_colors.dart` (alias); third teal in `widgets/harvest_access.dart:42`; hard-coded teal `#0E756E` at `components/custom_bottom_navigation_bar.dart:83`; 50 uses of `Colors.white/black/...` outside the theme; 6 raw `Color(0x...)` outside theme files; forms at `components/panen_form_body.dart:226`, `form_catat_kerusakan_body.dart:273-346`, `widgets/seedling_transfer_sheet.dart:380-466` (raw Material default look) vs `widgets/custom_input_field.dart` (themed) vs `add_form_inventaris_page.dart:417-449` (inline `_textField`)
- What: There is one `ThemeData` (`main.dart:11-17`) but the real design lives in at least four places. Duplicate widget families: `InventoryNotice` / `SurfaceNotice` / `_Notice` (`pages/connected_inventory_page.dart:282`); `InventoryEmpty` / `SurfaceEmptyState`; `InventoryPlaceholder` / `SurfacePlaceholder`; the bottom-sheet picker copied between `add_form_inventaris_page.dart:500-629` and `widgets/custom_dropdown_field.dart:23-136`. Header height is computed with three different formulas (`kToolbarHeight*scale`; `scale(21)>30 ? 96 : 64`; `56 + (scale(24)-24)*4.2` in `panen_page.dart:15`). Three unused widgets still carry fixed sizes and 10sp text: `widgets/info_card_md.dart:22` (width 158, height 89), `col_info_card_sm.dart`, `top_info_content.dart` (no call sites).
- Dead code worth noting for goal 5: every `isDark` branch is unreachable, because `MaterialApp` has no `darkTheme` or `themeMode` (`main.dart:13-17`) while `app_surface_colors.dart`, `glass_container.dart`, `header.dart`, `login_page.dart:85` and the nav bar all carry dark variants.
- Suggested fix: Make `AppSurfaceColors` the only palette (see F4-1), move it into `app_theme.dart`, delete the alias and the three unused widgets, merge the duplicated notice/empty/placeholder/picker widgets. About 1 to 2 days.

### F4-4 [GOAL 5] Flutter Material pickers render in English (no localisation set up)
- Severity: medium
- Status: VERIFIED (config); rendering SUSPECTED
- Where: `main.dart:13-17` (no `locale`, `supportedLocales`, `localizationsDelegates`); `pubspec.yaml` has no `flutter_localizations`; 5 `showDatePicker` calls: `catat_penjualan_body.dart:197`, `form_catat_kerusakan_body.dart:86`, `panen_form_body.dart:137`, `seeding_form_page.dart:134`, `seedling_transfer_sheet.dart:147`
- What: Without delegates Flutter falls back to en-US: "OK", "CANCEL", "SELECT DATE", month and weekday names in English. Harvest date uses `DatePickerEntryMode.inputOnly` (`panen_form_body.dart:139`), so the field shows the US `mm/dd/yyyy` pattern while the rest of the app shows ISO or "06 Oktober 2026". Date text elsewhere is also inconsistent: ISO `YYYY-MM-DD` shown to users at `seeding_form_page.dart:295`, `form_catat_kerusakan_body.dart:356`, `seedling_transfer_sheet.dart:452`; Indonesian long form at `catat_penjualan_body.dart:78`.
- Suggested fix: Add `flutter_localizations`, set `locale: Locale('id')` and delegates, show dates through `formatTanggalIndo` everywhere. About 0.5 day.

### F4-5 [GOAL 5] Session lives only in memory; Android will kill the app on 3 GB phones
- Severity: medium
- Status: VERIFIED (text and behaviour); impact SUSPECTED
- Where: `views/components/account_body.dart:141-142` ("Sesi hanya tersimpan di memori perangkat dan berakhir saat aplikasi ditutup."); `viewmodels/session_viewmodel.dart` (no storage)
- What: Matches the owner's session policy, but on a mid-range phone Android drops background apps under memory pressure, and a farmer who takes a call or switches to the camera comes back to the login screen. In-progress form drafts are in memory too (`pendingDraft` in the viewmodels), so they die with the process.
- Suggested fix: Decide explicitly. Option: keep the policy, but persist only the draft fields locally (the `sqflite` dependency exists) and show the login screen with a "draft kept" note. About 1 to 2 days. Record the product decision either way.

### F4-6 [GOAL 1, 5] Offline reads exist only for inventory; weather and all other lists need the network
- Severity: medium (high for field use; owned by the offline-first reviewers)
- Status: VERIFIED
- Where: `data/services/inventory_cache.dart` and `viewmodels/connected_inventory_viewmodel.dart:118-181` are the only `sqflite` users (`grep sqflite` gives 3 files); `viewmodels/weather_viewmodel.dart:60-65` (no cache); panen, penjualan, penyemaian, meja, dashboard have none
- What: UI states themselves are good: loading skeletons (`SurfacePlaceholder`, `InventoryPlaceholder`), empty states with illustrations and retry (`panen_body.dart:240-272`, `penjualan_body.dart:168-185`), inline errors with "Coba lagi", `LinearProgressIndicator` while refreshing, and pull to refresh on 9 screens. Inventory also says "Salinan lokal. Saldo mungkin sudah berubah." (`inventaris_body.dart:192-197`). But without network the other lists show "Data panen belum dapat ditampilkan ... Periksa koneksi" (`panen_body.dart:243-247`) and nothing else, and every request waits up to 20 s (`api_client.dart:115`, `bmkg_weather_service.dart:57`) with no cancel. There is no connectivity indicator; offline is only discovered after a failed call. The weather page has an app-bar refresh button and inline retry but no pull to refresh (`cuaca_body.dart:44`, `SingleChildScrollView`).
- Suggested fix: Extend the cache pattern to the other read models (or one generic cached-GET layer), shorten the timeout for reads to about 8 s with an explicit "tidak ada koneksi" state. About 2 to 4 days; belongs to the offline-first work.

### F4-7 [GOAL 5] Touch targets under 48 dp, text under 12 sp, and custom controls without semantics
- Severity: medium
- Status: VERIFIED
- Where: header avatar 44x44 `components/header.dart:198-199`; `CustomBackButton` 44x44 `widgets/custom_back_button.dart:35-36`; `minimumSize: Size(44, ...)` in `form_catat_kerusakan_body.dart:350,372`, `form_meja_nft_body.dart:246`, `detail_tanaman_meja_body.dart:278`, `seedling_transfer_sheet.dart:486`, `surface_notice.dart:55`; edit icon `Icons.edit_outlined` size 18 `detail_tanaman_meja_body.dart:256`; nav label 10.5sp `custom_bottom_navigation_bar.dart:148`; 10sp in `info_card_md.dart:39,61` (unused), `top_info_content.dart:28,50` (unused); 11sp `detail_tanaman_meja_body.dart:248`; `caption2` 11sp colour `textTertiary` (2.54:1)
- What: Targets of 44 dp are just under the 48 dp guidance; the repo itself uses 48 to 52 for main buttons, so this is mostly the header and secondary actions. Bottom navigation items are `GestureDetector` with no `Semantics` (`custom_bottom_navigation_bar.dart:86`), as are the dropdown trigger (`custom_dropdown_field.dart:153`), the inventory picker field (`add_form_inventaris_page.dart:459`, `InkWell` with no role) and `CapsuleBadge` (`capsule_badge.dart:76`). 7 of 16 `IconButton` have no `tooltip`: `catat_penjualan_body.dart:389`, `add_form_inventaris_page.dart:552`, `seeding_form_page.dart:173`, `custom_dropdown_field.dart:67` (all "close" buttons), `employee_list_page.dart:194`, `employee_form_sheet.dart:176,453`. The strong side: 24 `Semantics` uses, `liveRegion` on errors, `semanticLabel: 'Kembali'`, `ExcludeSemantics` on decorative art.
- Suggested fix: Raise the 44 dp controls to 48 dp, add `Semantics(button: true, selected: ...)` to nav items and picker triggers, add tooltips to the 7 icon buttons, set a 12sp floor. About 0.5 day.

### F4-8 [GOAL 5] Frosted-glass blur on every main screen is a cost on 3 GB phones
- Severity: medium
- Status: SUSPECTED (cost not measured)
- Where: `widgets/glass_container.dart:93-96` (`BackdropFilter`, `ImageFilter.blur`); users: `components/custom_bottom_navigation_bar.dart:36-38` (sigma 24 + 4, always on) and `components/header.dart:68-70` (sigma 24, when scrolled); `main_page.dart:94-95` (`extendBodyBehindAppBar`, `extendBody` so scrolling content sits under both)
- What: A live backdrop blur over scrolling content forces an offscreen layer every frame. On Android 8 class GPUs this is the common cause of dropped frames. It also makes the contrast of the nav labels depend on whatever scrolls behind (60% tint; `textSecondary` 4.62:1 only on a clean canvas). The design is also iOS-flavoured (26 `CupertinoIcons` uses, `CupertinoAlertDialog` at `features/accounts/presentation/widgets/employee_dialogs.dart:11`, a Material `AlertDialog` at `inventaris_body.dart:88`), for an Android-first user base.
- Suggested fix: Replace the blur with a solid or 95%-opaque surface (or gate the blur on a device-performance check); use one dialog style. About 0.5 day. Measure with `flutter run --profile` on a 3 GB device before and after.

### F4-9 [GOAL 5] Images decoded far larger than shown; login decodes two 1 to 1.6 MP PNGs
- Severity: low
- Status: VERIFIED (sizes), memory effect SUSPECTED
- Where: `widgets/feature_illustration.dart:33` and `widgets/inventory_illustration.dart:55` (`cacheWidth: 512` for images drawn at 34 to 72 dp, e.g. the header avatar at 34 dp, `header.dart:209-212`); `pages/login_page.dart:285` (logo 1254x1254, 1.28 MB, drawn at 80 dp, no `cacheWidth`); `features/auth/presentation/widgets/login_header_hero.dart:28,52` (1672x941, 1.45 MB, no `cacheWidth`)
- What: `assets/` is 6.1 MB in 18 PNGs. 16 illustrations are 512x512 (180 to 290 KB each, 1 MB decoded each); the two big ones decode to about 6.3 MB each. All asset folders are bundled whole by `pubspec.yaml:55-60`. This is acceptable for storage, but wasteful for RAM at login, the first screen.
- Suggested fix: Set `cacheWidth` to `size * devicePixelRatio`, ship the two large images as WebP at display size (about 90% smaller). About 2 hours.

### F4-10 [GOAL 5] Tab switch discards state; long forms are not lazy; Save button location differs by form
- Severity: low
- Status: VERIFIED
- Where: `pages/main_page.dart:114-116` (`pages[_selectedIndex]`, not `IndexedStack`: search text, category chip and scroll position reset on every tab change); non-lazy lists: `components/panen_body.dart:142` (`ListView(children: [for ...])`), `detail_tanaman_meja_body.dart:49,70`, `pages/connected_inventory_page.dart:107,185`, `laporan_panen_body.dart:56`, `panen_form_body.dart:278` (up to 100 batch cards x 3 controllers, `:340`); Save placement: pinned in `bottomNavigationBar` for inventory (`add_form_inventaris_page.dart:229`), seeding (`seeding_form_page.dart:386`), sales; at the end of the scroll for harvest (`panen_form_body.dart:350`), damage (`form_catat_kerusakan_body.dart:370`), table (`form_meja_nft_body.dart:244`), transfer sheet (`seedling_transfer_sheet.dart:482`) and "Pindahkan ke Meja" (`info_seeding_page.dart:407`)
- What: The builder-based lists (`SliverList.builder`/`.separated` in inventory, nursery, sales, table) are right. The non-lazy ones are small in practice, so this is low. The inconsistent Save position matters more for one-handed use: the pinned pattern is better.
- Suggested fix: `IndexedStack` or `AutomaticKeepAliveClientMixin` for the four tabs; use the pinned Save pattern in the four forms. About 0.5 day.

### F4-11 [GOAL 5] User text with developer wording and raw exceptions
- Severity: low
- Status: VERIFIED
- Where: `form_meja_nft_body.dart:129` (`'Gagal menyimpan meja: $e'` bypasses `serviceError()`, `session_viewmodel.dart:59`, which gives clean Indonesian elsewhere); `panen_form_body.dart:258,261,301` ("Request koreksi panen ... belum pasti. Ulangi request yang sama", "Ulangi Request yang Sama"); `seedling_transfer_sheet.dart:476-479`; `account_body.dart:90,97` (shows "ID Pengguna" and the raw permission list "panen:read, ..."); `login_page.dart:149,164` ("Masukkan username")
- What: The retry-safe flow is good engineering but its wording speaks to a developer. Farmers need "Simpan belum terkonfirmasi. Tekan Simpan lagi, data tidak akan tercatat dua kali."
- Suggested fix: One wording pass, route the meja error through `serviceError`. About 2 hours.

### F4-12 [GOAL 5] Accidental-tap protection is uneven
- Severity: low
- Status: VERIFIED
- Where: logout runs on one tap with no confirmation (`components/account_body.dart:158-166`); "Hapus Batch" drops entered weights with no confirmation (`panen_form_body.dart:453-462`); navigation taps are unguarded, so a double tap pushes the form twice (`panen_body.dart:356-364`, `dashboard_body.dart:237-243`, `RowButton` has haptics but no debounce, `row_button.dart:45-50`)
- What: Destructive server actions are well covered: archive (`inventaris_body.dart:86-131`) and employee deactivation (`employee_dialogs.dart:13-30`) both ask first, and every save button disables while saving (`_saving`, `state.submitting`, `session.busy`, `PopScope(canPop: !_saving)`). The gaps are the three above.
- Suggested fix: Confirmation dialog on logout and "Hapus Batch"; a `_navigating` guard in `RowButton`. About 2 hours.

### F4-13 [GOAL 5] Landscape, tablet and keyboard insets are untested edges
- Severity: low
- Status: SUSPECTED
- Where: no `setPreferredOrientations`, no `screenOrientation` in `AndroidManifest.xml` (so landscape is allowed); only `login_page.dart:115` caps width (480); `form_catat_kerusakan_body.dart:230-235` and `panen_form_body.dart:279-284` add `viewInsets.bottom` as padding inside a `Scaffold` that already resizes (`windowSoftInputMode="adjustResize"`, `AndroidManifest.xml:16`), which can double the space under the last field; `android/app/build.gradle.kts:22` uses `flutter.minSdkVersion`, not the plan's Android 8 (API 26)
- What: Tests cover 240 to 390 wide portrait (320x568 at 2x text in 9 files; 800x1400 for sales and harvest; login at 1024x1366), but none in landscape. In a phone landscape, a pinned Save bar plus keyboard leaves little room. This is a guess; nothing here is confirmed by running it.
- Suggested fix: Lock to portrait for a phone-first product (one line), or add a landscape test; pin `minSdk = 26`. About 1 hour.

## Met and fine

- **No fixed-width layout on the live screens.** Only one literal `width >= 150` exists in `lib/` (`info_card_md.dart:22`) and it is unused. Content width comes from `Expanded`, `Wrap`, and `LayoutBuilder` (dashboard quick actions 1/2/4 columns by width, `dashboard_body.dart:211-217`; stat cards stack under 300 dp, `:183`).
- **Text scaling is honoured, never capped.** No `textScaleFactor` clamp; 30 `textScaler` call sites resize button and toolbar heights (`52 * scale` in 9 places). Date pickers clamp to 1.3 only (`form_catat_kerusakan_body.dart:111`). Tests run 320x568 at 2x (`growth_layout_test.dart:53-174`, `inventory_form_layout_test.dart:30-70`, `panen_test.dart:298,531,553,912`, `harvest_layout_supplement_test.dart:30,89`, `nursery_widget_remediation_test.dart:335`, `login_header_hero_test.dart:70-82`) and 240x900 at 2x (`connected_inventory_page_test.dart:172-174`).
- **Keyboard handling.** `adjustResize`; add buttons hide while the keyboard is open (`inventaris_body.dart:160`, `panen_body.dart:89-92`, `penjualan_body.dart:193`); `keyboardDismissBehavior.onDrag` on 7 lists; modal sheets pad by `viewInsets` and use `isScrollControlled` (9 `showModalBottomSheet` calls, 9 `isScrollControlled`).
- **One-handed reach.** Primary actions sit at the bottom (floating add buttons on inventory, panen, penjualan; pinned Save in 3 forms); pull to refresh on 9 screens; chips scroll horizontally.
- **List states.** Loading skeleton, empty (first-run vs filtered), error with retry, and inline refresh bar exist and look the same across inventory, nursery, sales, table, harvest. Errors flow through `serviceError()` in plain Indonesian.
- **Forms.** Login is a model: `AutofillGroup`, autofill hints, `next`/`done` actions, focus hand-off, disabled while busy, `Semantics` on labels (`login_page.dart:116-180,371-431`). 13 `textInputAction`, `maxLength`, `errorMaxLines`, and saving labels ("Menyimpan...") on all save buttons. Double-submit is blocked everywhere that writes.
- **Lazy lists on the long screens.** `SliverList.builder` / `.separated` in inventory, nursery, sales and table; picker sheets use `ListView.separated`.
- **Assets.** Illustrations are consistent 512 px PNGs under 300 KB; total assets 6.1 MB.
- **`flutter analyze`** is clean (given), and `AppSpacing`/`AppRadius`/`AppTypography` tokens are used throughout.

## Count by severity

critical 0, high 1 (F4-1), medium 7 (F4-2, F4-3, F4-4, F4-5, F4-6, F4-7, F4-8), low 5 (F4-9 to F4-13). Total 13.
