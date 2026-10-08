# HidroSense inventory redesign

The live inventory tab now uses the prepared hydroponic illustrations, a stock overview, readable item cards, and a native stock-detail sheet. Search, dynamic categories, refresh, account navigation, and the existing add form remain connected to their real application behavior.

## Direction and context

Design Read: warm ivory canvas, mint surfaces, dark teal text, product-specific illustrations, and a lime primary action. ENERGY 2 / RHYTHM 2 / MOTION 2. The user's Wondr reference supplies the asymmetric category corner and contextual card art; the HidroSense mascot, lettuce, and hydroponic equipment supply the identity.

Graphify located the live route as `MainPage` → `InventarisBody` → `connectedInventoryProvider`. The older `ConnectedInventoryPage` is not the tab shown in the supplied screenshot. The asset manifest and seed inventory informed the five item overrides and category fallbacks.

The screen's job is to find a supply, check its exact quantity and stock condition, or add a new item. The overview counts active records and categories, and calls attention to low or empty stock. It never totals quantities across incompatible units. Stock precision remains in `InventoryRecord`; the UI does not convert decimal quantities to floating point.

| Decision | Reason |
| --- | --- |
| Ivory canvas and mint overview | Continue HidroSense's greenhouse palette and distinguish the summary from white item surfaces. |
| Dark teal text and lime action | Keep category/status text readable; draw attention to adding inventory and the selected filter. |
| Product art on each item | Identify Romaine, Butterhead, nutrients, plant care, and rockwool at a glance. Unknown names use a category fallback. |
| Full item names and wrapping quantities | Avoid the truncation of names and units in the supplied screen. |
| Asymmetric category corner | Carry one repeated identity motif while keeping stock status beside the quantity. |
| Existing Inter typography token | Preserve consistency with the rest of the app; use clear hierarchy and tabular quantities. |
| 20/24 px spacing, 16 px item corners | Separate tasks and improve scanning; reserve larger curvature for the overview and primary action. |
| Native sheet, chips, fields and buttons | Provide predictable focus, touch, selection and dismissal behavior. |
| Static rows and lazy list | Keep stock immediately readable and construct only visible rows. |
| Mascot account and empty/search art | Tie navigation and recovery states to the existing brand without inventing a person's identity. |

The design follows Apple's emphasis on clear hierarchy, sufficient touch targets, adaptable text, and purposeful motion. Sources: [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), [Layout](https://developer.apple.com/design/human-interface-guidelines/layout), [Motion](https://developer.apple.com/design/human-interface-guidelines/motion).

## Behavior and motion

- The overview art fades in once over 240 ms. Text and quantities are present immediately.
- Category selection uses a 140 ms transition and native selection haptics.
- Item details use the framework's native sheet transition and dismiss with its button, drag, scrim, or Escape.
- Reduce Motion removes the custom fade, chip transition, and sheet transition.
- Refresh keeps existing records visible. Initial loading, first run, no results, service error, and cached data have separate messages and actions.
- A category that disappears from refreshed records resets to All permanently.
- The add action hides while the keyboard is visible. Search clears independently from the selected category; resetting filters clears both.
- Narrow layouts and enlarged text stack the artwork and text, with scrollable content and wrapping labels.

## Verification

25 regression checks pass across `inventory_redesign_test.dart`, `connected_flow_test.dart`, `connected_inventory_page_test.dart`, and `dashboard_login_test.dart`. Coverage includes exact decimal stock, category changes, searches, clearing filters, retry, loading with retained records, add navigation, login/account/logout, keyboard refresh, Escape dismissal, narrow layouts, 2× text, dark mode, and Reduce Motion.

Scoped Dart analysis of the six changed Dart files reports no issues. Whole-project analysis has existing informational diagnostics in unrelated files; these were not changed. Android debug APK builds from the normal `lib/main.dart` entry point. The application APK uses the real providers, not the preview fixtures.

[Visual state gallery](inventory-redesign/index.html) contains 13 final state/layout renders and four native-sheet animation frames. The renders use repository seed data; low stock, cache timestamp, and error cases are explicitly labelled fixtures. The render harness loads Roboto under the existing Inter token to avoid Flutter's test font. Native emulator screenshots were also inspected for the main view and stock sheet.

Native debug taps worked with the emulator's fallback renderer. Default-renderer performance could not be assessed reliably: Android's System UI and services also hit startup ANRs while the host had less than 1 GB available memory. No 60 fps or release-device performance claim is made. Temporary emulator resolution, density and disabled Google packages were restored, and the emulator was closed. The connected physical phone was not operated.

Logs: `.codex/tmp/inventory-final-tests.log`, `inventory-analyze.log`, `inventory-render.log`, `inventory-production-build.log`, and `inventory-graphify-update.log`. Preview harnesses and recordings are QA artifacts outside the application source.

## Delivery gate

The report applies to this inventory redesign and its changed controls. Evidence is the source, the regression tests above, the visual gallery, build logs, and documented runtime limits.

- R-02 PASS: edited UI strings contain no em dash.
- R-03 PASS: 320 px, 390 px, landscape, and 2× text renders have no text escaping its container; regression tests report no layout exceptions.
- R-17 PASS: counts derive from active provider records; attention counts derive from real stock conditions.
- R-18 PASS: no testimonials or fictional people are present.
- R-23 PASS: the user explicitly requested the prepared illustrations and their implementation; no new identity or navigation structure was invented.
- R-24 PASS: existing four tabs, account page, and add form are real routes; connected-flow tests exercise inventory and account navigation.
- R-25 PASS: normal text contrasts exceed 4.5:1; teal on mint 4.87:1, secondary on ivory 5.77:1, navy on lime 13.11:1. Input boundary is 3.87:1 against white and meets the 3:1 non-text requirement. Dark teal text on its mint surface is 7.41:1.
- R-26 PASS: search, clear, reset, category selection, retry, refresh, item details, close, add, account, and tab controls have real handlers; tests record their outcomes.
- R-27 PASS: loading, empty, no-results, cached and service-error renders show the relevant cause and recovery action.
- R-28 PASS: no FAQ is present.
- R-32 PASS: Tab then Enter triggers refresh and Escape closes the detail sheet in a retained regression test; native controls retain focus feedback.
- R-33 PASS: implementation edits were written directly with source patches, not injected by external scripts.
- R-34 PASS: light and dark inventory renders preserve labels, artwork and layout; dark-mode regression test passes.
- R-35 PASS: normal-entry-point Android build and recorded automated click-through pass; native main and detail views were inspected. Device frame-rate validation remains explicitly unclaimed.
- R-36 PASS: no security, compliance, customer or performance claims appear in the UI or this report.
- R-37 PASS: Design Read and ENERGY 2 / RHYTHM 2 / MOTION 2 were declared before implementation, based on the user's reference and assets.
- R-38 PASS: runtime data comes from existing providers; review fixtures are labelled separately and excluded from the app entry point.
- R-01 PASS: flat brand surfaces are used; no decorative gradient or glow is present.
- R-04 PASS: search, refresh, add, notice and disclosure icons describe their actual actions or states; no decorative emoji or magic icons.
- R-06 PASS: existing typography is retained for app consistency; quantities use tabular styling, without decorative monospace or tracked uppercase.
- R-07 PASS: no background grid, blueprint or dot pattern.
- R-08 PASS: chevrons disclose item details; they are absent from primary buttons.
- R-09 PASS: category corners describe inventory type; stock text describes quantity state. No promotional badges or duplicate eyebrow label.
- R-10 PASS: no glass surfaces.
- R-12 PASS: item cards use a thin boundary rather than elevated shadows; the native modal owns its elevation.
- R-13 PASS: no glows.
- R-14 PASS: consistent item rows support comparing the same fields; summary, controls, empty states and detail sheet use different compositions.
- R-19 PASS: the one-shot art fade, selection feedback and detail transition serve explicit moments; no decorative looping motion. Reduce Motion is tested.
- R-22 PASS: illustrations depict the actual inventory categories and existing HidroSense mascot.
- Dials PASS: ENERGY 2 / RHYTHM 2 / MOTION 2 are explicit and match the restrained illustration-led screen.
- Focal point PASS: inventory art anchors the overview; the lime add action anchors the task controls.
- Whitespace PASS: spacing separates summary, search, filters, records and the persistent action.
- Accent PASS: lime marks the primary action and selected category; other surfaces use neutral/mint tones.
- Identity PASS: hydroponic product art and the asymmetric category corner repeat deliberately.
- Design Read PASS: direction was declared before generation and is documented above.
- C-1 PASS: color, type, spacing, illustration, card and motion choices each have a written product reason.
- C-2 PASS: retained interaction tests cover the changed controls and real destinations.
- C-3 PASS: all sections support finding, inspecting, refreshing or adding supplies.
- C-4 PASS: the verified narrow/landscape/text/theme/state matrix renders without layout exceptions; keyboard interaction is tested.
- C-5 PASS: exact values and counts are sourced from provider records; no fabricated claims.
- R-05 PASS: an overview, native controls, comparable item rows and recovery states vary composition according to their content.
- R-11 PASS: input, item card, category corner, overview and primary action have distinct shapes.
- R-15 PASS: task-specific labels include Cari barang, Tambah barang, Coba lagi, Hapus filter and Tutup.
- R-16 PASS: no marketing buzzwords in the changed screen.
- R-20 PASS: Romaine/Butterhead, nutrient bottles, rockwool and the HidroSense mascot make the screen specific to hydroponic supplies.
- R-21 PASS: the existing light default remains; dark support follows the ambient theme.
- R-29 PASS: ivory/mint neutrals, teal and navy, plus one lime accent; warning/error colors carry stock or service meaning.
- R-30 PASS: the reference informs hierarchy and corner art; HidroSense content, layout, stock behavior and illustration identity remain distinct.
- R-31 PASS: every major visual decision has a one-line explanation in the decision table.
