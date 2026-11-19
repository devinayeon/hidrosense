# HidroSense Mobile UI v2: plan for approval

Status: draft, written in Session A, step 1. Nothing has been built in Figma yet.
Target: a NEW Figma file. The old file `jw1JWyJXFrY85MW2wXYkGh` is read-only, used for information-architecture parity only.

## 1. What the references show

Read in full: 13 Headspace screens, 4 Pinterest boards, 4 existing illustrations, the greenhouse image, the logo, `manifest.json`, `project-scope.md`.

### Headspace (layout, spacing, tone)
- Hero zone: a full-bleed saturated colour field (yellow or orange) holding one illustration. The content sheet is white and its top edge is a wide arc (about 48 pt rise across the width). This is the signature shape.
- One primary action per screen: a full-width pill button, about 56 pt high with 24 pt side margins. It sits at the bottom, in the thumb zone. A secondary pill with a soft fill and a thin lip sits under it.
- Titles are centred or left aligned, bold, with tight tracking. Body text is regular and muted grey. There is a lot of whitespace.
- Option rows are pills, about 56 pt high, with a 2 pt light border and a round check on the right. Selected state means a tinted fill and a filled check.
- Small controls: pagination dots, a thin pill progress bar, a segmented pill toggle (dark selected segment), a vertical timeline of coloured circle icons, and a back chevron with a label.
- Illustration: flat shapes, soft depth, round forms, one character face on a simple shape. Never any text inside the artwork.

### Pinterest boards (palette, composition, illustration language)
- Pastel gradient backgrounds, white cards with a 24 pt radius and a soft low shadow, a mascot as the hero of the screen.
- Dashboard pattern: a greeting, three square stat tiles, a progress card, a list with check or progress marks, a floating pill tab bar with a highlighted active item.
- Big dark pill CTA, chip rows, small bar charts, ring progress.
- Warning: several boards use frosted glass blur. A prior review of this repo (finding F4-8, slice-F4) already flagged blur on every main screen as a cost on 3 GB phones. v2 uses flat tinted gradients and no backdrop blur.

### Existing HidroSense art
- Mascot "miaw": a cream cat with teal and green stripes and a lettuce basket. Soft vector shading, transparent PNG. The 4 states on disk (`mascot-avatar`, `empty-inventory`, `empty-nursery`, `no-search-results`) share this look.
- The edges of the PNGs show faint light specks (halo fringe). They need cleanup or regeneration before they sit on a coloured hero.
- Greenhouse row: flat soft vector with depth blur, pale mint and white, lettuce greens, navy pipe accents.
- 12 of the 16 manifest assets are missing from disk (see section 8).

## 2. Direction and trade-offs

- Keep Headspace structure (arc hero, pill controls, generous space). Change only colour: coral/orange primary with fresh green secondary, taken from the Headspace orange and the mascot teal-green.
- Gain: joyful, "pop", friendly to non-technical users. Lose: pure orange fails white-text contrast, so the button label is dark ink, not white (see section 4). Affects: everyone, in glare outdoors. Fits because dark ink on bright coral reads better in sunlight than white on orange.
- Persona: busy, non-technical petani and pegawai, outdoors, one-handed, in glare, Bahasa Indonesia.
- Light mode only. Frame 390 x 844.

## 3. Roles (derived from project-scope.md)

| Area | Petani | Pegawai |
|---|---|---|
| Akun pegawai (tambah, lihat, ubah, nonaktifkan) | yes | no |
| Inventaris (tambah, lihat, ubah, arsip/nonaktif) | yes | yes |
| Semaian (tambah, lihat, ubah, notifikasi 15 hari) | yes | yes |
| Meja tanam, pertumbuhan, HSS, tanaman rusak | yes | yes |
| Ubah status meja tanam | yes (scope item 8, manual) | yes (listed explicitly) |
| Panen (estimasi, tambah, lihat, ubah) | yes | yes |
| Penjualan | yes | no |
| Perawatan (unggah foto, hasil hama, rekomendasi obat, konfirmasi, riwayat) | yes | no |
| Rekomendasi cuaca BMKG | yes | no |

Navigation proposal:
- Petani, 5 tabs: Beranda, Tanam, Stok, Rawat, Lainnya. Lainnya holds Penjualan, Akun pegawai, Sinkron, Profil.
- Pegawai, 4 tabs: Beranda, Tanam, Stok, Profil.
- "Tanam" groups Semaian, Meja Tanam, Pertumbuhan, Tanaman rusak and Panen as sub-sections.

## 4. Token list (colour values are measured, WCAG 2.x ratios)

### Colour
| Token | Hex | Use | Measured |
|---|---|---|---|
| ink-900 | #2B2430 | primary text, button label | 15.02 on white |
| ink-600 | #5B5463 | secondary text | 7.26 on white |
| ink-500 | #6B6472 | tertiary text | 5.69 on white, 5.41 on cream |
| cream-50 | #FFF8F2 | app background | |
| white | #FFFFFF | cards, sheets | |
| border-strong | #8C8494 | input and control borders | 3.59 on white (UI >= 3) |
| border-soft | #EFE6DF | decorative dividers only | |
| coral-500 | #F26A2E | primary button fill | 3.05 vs white (UI), ink-900 label 4.92 |
| coral-400 | #FF8A4C | hero fields, decorative | ink label 6.43 |
| coral-700 | #C2410C | coral text, links, icons | 5.18 on white, 4.92 on cream |
| coral-100 | #FFE9DC | tints | #B23A0A text on it 5.12 |
| green-700 | #1F7A3D | secondary button fill, success text and icons | white on it 5.37, 5.37 on white |
| green-100 | #E3F5E1 | success tint | green-700 on it 4.71 |
| green-300 | #8FD9A8 | fills, charts | ink on it 9.06 |
| green-500 | #3DAE6B | decorative only | 2.81 vs white, fails 3:1 |
| sun-400 | #FFC93C | hero accent, decorative | ink on it 9.78 |
| amber-100 / amber-800 | #FFF1CC / #8A5200 | warning (stok menipis, cuaca) | 5.69 |
| red-100 / red-700 | #FDE7E4 / #B3261E | error, rusak, destructive | 5.52 |
| blue-100 / blue-700 | #E1EFFC / #1D5FA8 | info, offline | 5.52 |

Open item for Session A: the pressed state of the primary button. White on coral-600 (#D8501F) is 4.13 and fails, so pressed will be coral-400 with a coral-700 ring, then re-measured. Focus ring: 3 pt ink-900 offset 2 pt.

Rule: status never relies on colour alone. Each status is icon plus short label.
Chart rule: marks with contrast under 3:1 against the background (green-500, coral-400) get a direct value label or a pattern.

### Type (Poppins only)
Display 32/40 SemiBold, H1 24/32 SemiBold, H2 20/28 Medium, Body 16/24 Regular, Label 14/20 Medium, Caption 12/16 Regular.
Rule added by me: Caption is for non-essential metadata only. Anything a user decides on (stock number, HSS, status) is Label 14 or larger.

### Space, shape, elevation
- Spacing 8/16/24/32/40/48. 4 allowed inside icon and label pairs. Side margin 24.
- Radius: pill 999 for buttons, inputs and options (height 56), card 24, sheet top 32, hero arc.
- Elevation: card shadow 0 8 24 at 8% ink-900, and a 2 pt button lip. No blur effects.
- Touch targets at least 48 x 48 with 8 gaps. Primary action in the bottom third. Tab bar item width is 68 at 5 tabs, which clears 48.

### Components and variants
Button (primary, secondary, tertiary, destructive; default, pressed, disabled, focus, loading), Input (default, focus, filled, error, disabled, password with show/hide), Select, OptionRow (single, multi), Card, Badge (status with icon), AppBar, TabBar (petani 5, pegawai 4), BottomSheet, Dialog, Banner (offline, sync pending, BMKG unavailable, info), Toast, Skeleton, ListItem, Stepper, Segmented toggle, Chip, Search field, Chart tiles.
Charts and diagrams (dataviz skill): growth and harvest chart, sales chart, 60-day cycle ring and timeline (15 semai + 45 tumbuh), NFT hole grid (terisi, kosong, rusak, with age), stock level bars.
Icons: one set, chosen with find-icon-library in Session A.

## 5. Gaps found in the prompt and scope (decisions needed or assumed)

1. Pegawai has no Perawatan, Penjualan, Akun or weather recommendation in the scope. I will not draw them for pegawai. Question: should pegawai see a read-only weather card on Beranda? Default: no.
2. "First-run setup" is not a scope feature, and there is no sign-up. Default: no wizard. Beranda shows a three-item empty checklist (tambah meja, tambah stok, mulai semai).
3. Automatic stock deduction has no explicit trigger in the scope. Default: it happens inside "tambah semaian" (benih, rockwool) and "konfirmasi perawatan" (obat), with a preview of the deduction before saving. A manual "Catat pakai" sheet on inventory detail for pupuk and media is an addition. Question: keep it? Default: keep, one sheet only.
4. Tanaman rusak belongs to Meja Tanam and Pertumbuhan in the scope, not to Panen. The new file follows the scope.
5. "Report" and "summary" for panen and penjualan are not scope features. Default: read-only derived summaries and charts, no export or PDF.
6. Settings are not a scope feature. Default: Profil (view and edit own account), Sinkron status, permissions status, logout. Nothing else.
7. Login offline. The scope says internet is needed only for sync and BMKG. Assumption: the first login needs internet and later opens reuse the stored session. Needs your confirmation or the backend owner's.
8. Real backend rules shape the forms (from `apps/backend/src/common/validation.ts` and `accounts/contracts.ts`): username 1 to 50 characters, no hidden characters, stored lowercase; password 12 to 128 characters; nama up to 100; email optional; telepon optional, up to 20 characters of digits, +, space, ( ) and -; alamat optional, up to 1000. A 12 character minimum is hard to type one-handed outdoors, so every password field gets show/hide and a live length hint.
9. The backend returns 403 for a deactivated employee at login, and writes carry an `expected_version`. The design needs an "akun nonaktif" login error and an "data sudah berubah" conflict dialog on edit forms.
10. Notification of "semaian 15 hari" needs an in-app list and a push or banner. Default: a notification list screen plus a banner on Beranda.
11. Hama types are three now and "can grow". The result screen is built as a list of detections, not three hard-coded layouts.
12. HSS is the scope's term. Screens show "HSS 23". The detail screen spells it out once: "Hari setelah semai".
13. Item 6 of the original prompt said "parent persona". Replaced with the farm persona above.
14. "DONT SYSTEM" is read as "design system and font". Poppins is mandatory.
15. The Headspace blue CTA does not belong in a coral palette. Replaced by coral-500 with ink label.

## 6. Screen inventory (about 100 frames)

Counts are frames including states. Role tag P = Petani, W = Pegawai.

| Page | Frames | Contents |
|---|---|---|
| 00 Foundations | n/a | tokens, text styles, contrast table, components, icons, illustrations, annotation legend |
| 01 Onboarding and Auth | 11 | splash, 3 welcome, login default, login filled, login error, akun nonaktif, offline at first login, notification priming, empty Beranda with checklist |
| 02 Beranda and Notifikasi | 7 | Beranda P, Beranda W, skeleton, notifikasi list, offline and sync-pending banner, BMKG unavailable card (P), cycle ring detail |
| 03 Akun (P, plus profile W) | 11 | profil P, profil W, daftar pegawai, empty, tambah, validation error, detail, ubah, nonaktifkan confirm, success, logout confirm |
| 04 Inventaris | 12 | list, search, filter sheet, no results, empty, detail, tambah, ubah with validation, catat pakai, arsip confirm, daftar arsip, stok menipis |
| 05 Semaian | 9 | list, empty, tambah with deduction preview, detail with HSS timeline, ubah, notifikasi 15 hari, pindah ke meja, success, stok kurang error |
| 06 Meja Tanam dan Pertumbuhan | 14 | meja list, empty, meja detail with hole grid, hole and age detail, tambah meja, ubah meja, ubah status sheet, tambah pertumbuhan, pertumbuhan chart and list, ubah pertumbuhan, rusak list, tambah rusak, ubah rusak, skeleton |
| 07 Panen | 7 | estimasi panen, tambah, list, detail and ubah, chart, empty, success |
| 08 Penjualan (P) | 7 | list with summary, tambah, detail, ubah, empty, chart summary, validation |
| 09 Perawatan dan Hama (P) | 16 | hub and riwayat, photo tips, camera priming, camera denied, capture, preview and upload, analyzing, hasil (hama found), hasil (several detections), low confidence, tanaman sehat, rekomendasi obat and rotasi, konfirmasi perawatan with deduction, success, riwayat detail, offline upload error |
| 10 Cuaca BMKG (P) | 6 | kondisi, prakiraan, rekomendasi perawatan AI, BMKG unavailable, skeleton, offline cached |
| 11 Sinkron dan Profil | 5 | status sinkron, syncing, gagal, antrean offline, izin status |
| Total | about 105 | |

Every AI screen (09, 10) carries the decision-support note: the recommendation supports the petani, it does not replace their decision.

State matrix applied per screen where it can occur: default, skeleton, empty, error, offline or sync pending, BMKG unavailable, camera or storage permission denied, low-confidence detection, form validation, success, destructive confirm, version conflict. Petani versus Pegawai differences are marked with a role chip in the flow note above each frame.

## 7. Flow map

- Login: Splash, Welcome 1 to 3, Login, (error or akun nonaktif), notification priming, Beranda.
- Stok flow: Stok list, detail, tambah or ubah, catat pakai, arsip.
- Siklus: Tambah semaian, Semaian detail (HSS rising), notifikasi at 15 days, Pindah ke meja, Meja detail (hole grid, status), Pertumbuhan records, Rusak records, Estimasi panen (HSS 60), Tambah panen, Penjualan.
- Perawatan: Rawat hub, Tips foto, Kamera (permission), Analisis, Hasil, Rekomendasi obat and rotasi, Konfirmasi (stok berkurang), Riwayat.
- Cuaca: Beranda card, Cuaca detail, Rekomendasi perawatan.
- Cross-cutting: Sinkron banner on every list; offline state; version conflict on every edit form.

## 8. Illustrations

Existing, to upload: `mascot-avatar`, `empty-inventory`, `empty-nursery`, `no-search-results`.
Missing and to generate, named by manifest id: `category-seeds`, `item-romaine-seeds`, `item-butterhead-seeds`, `item-abmix-nutrients`, `item-plant-care`, `item-rockwool`, `inventory-stock`, `nursery-seedlings`, `nft-growing-table`, `harvest-lettuce`, `sales-produce`, `weather-greenhouse`.
Extra spot illustrations the design needs that the manifest does not list (about 12): splash, 3 welcome, login hero, notification priming, camera priming, offline, error, BMKG unavailable, success, tanaman sehat, low confidence, and the 3 hama. Default: reuse the mascot with props and generate extras only when a frame needs one.
Style gate: generate ONE missing illustration first and show it next to the mascot and greenhouse references. Continue with the other 11 only after you approve the match, because the vector tool may not reproduce the soft-shaded mascot look.
No text baked into any illustration. No text on busy illustration areas.

## 9. Method

1. Plan approved (this document).
2. `find-design-system` and `get-design-system-kit` for the Headspace-like base, `get-ui-principle` before styling, `get-ux-principle` before flows.
3. `create_new_file`, `create_session`, load `figma-use` before each `use_figma`.
4. Page order: 00 Foundations, then one page per flow, frames numbered 1.1, 1.2 and so on, with a flow note above each.
5. Foundations first: variables, Poppins text styles, components, contrast table. Screenshot and check.
6. Assemble screens in batches by flow. After each flow: `get_screenshot`, `inspect-spacing`, `check-comprehension`, `get-review-rules`, then outofthebox-ui, a11y and mobile passes. Fix every critical and serious finding. Re-screenshot.
7. Figma gotchas: call `setCurrentPageAsync` before creating sections; `resize()` on an auto-layout frame fixes the height, so reset sizing to AUTO.

## 10. Sessions

Scope is about 105 frames. Four sessions as asked, with a recommended split of C:
- A: plan approval, design system, foundations, illustration style gate, contrast table.
- B: pages 01, 02, 03.
- C: pages 04 to 08. Heavy. Recommended to split into C1 (04, 05, 06) and C2 (07, 08, plus 10 and 11).
- D: page 09, whatever remains, a cross-flow audit, fixes, final summary.
Each session ends with a handoff note in `yeonworks/` (Figma URL, page map, finished frames, open issues).
Models: Opus for planning and the audit, Sonnet for builds.

## 11. Acceptance

- Every feature in project-scope.md has at least one flow, with the listed states where they apply.
- No raw hex in layers, no non-Poppins text, no text under 12 pt, no spacing off the 8 pt scale (exceptions reported).
- Contrast table delivered and passing. All touch targets at least 48.
- 12 missing illustrations generated and matching the greenhouse and mascot references.
- All critical and serious review findings fixed.
- Final summary lists the Figma URL, page map, screen count and open items.
- Out of scope: sign-up, social login, dark mode, parent or child content, app code changes, edits to the old Figma file.
