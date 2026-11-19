# HidroSense Mobile UI v2: handoff (Session A, in progress)

Plan: `yeonworks/hidro-scope/figma-v2-plan.md` (approved on 2026-11-15 with all defaults).
Figma file: https://www.figma.com/design/KZ7dODi36pWhEPumnRz7RG (name "HidroSense Mobile UI v2", team plan `team::1443190053748366396`).
Old file `jw1JWyJXFrY85MW2wXYkGh` is read-only and untouched.

> **v3 "Royal" re-theme (from 2026-11-16).** The palette, type and shape rules now come from [figma-v3-direction.md](figma-v3-direction.md). This file stays the record for node ids, flows, data and notes. Rollback data for the coral theme is in [figma-v2-coral-snapshot.json](figma-v2-coral-snapshot.json), and the coral "before" screenshots are in [v3-before/](v3-before/). Phase 1 must add radius 12 and 20 variables to the Space collection, which today holds only 16, 24, 32 and pill.

## Decisions taken
- All 5 defaults in the plan were approved: no weather card for pegawai, keep one "Catat pakai" sheet, first login needs internet, illustration style gate before generating the other 11, Session C split into C1 and C2.
- Better Design MCP quota is exhausted (300 free calls used, resets 2026-11-26). The user chose to substitute local skills (ui-ux-pro-max, antislop-ui, outofthebox-ui, outofthebox-a11y, outofthebox-mobile). Every flow must be marked "Better Design review pending" until get-ui-principle, get-ux-principle, get-review-rules, check-comprehension and inspect-spacing can be run. No trial was activated.

## Built so far (all in the Figma file)
Pages (IDs): 00 Foundations `0:1`, 01 Onboarding & Auth `1:2`, 02 Beranda & Notifikasi `1:3`, 03 Akun `1:4`, 04 Inventaris `1:5`, 05 Semaian `1:6`, 06 Meja Tanam & Pertumbuhan `1:7`, 07 Panen `1:8`, 08 Penjualan `1:9`, 09 Perawatan & Hama `1:10`, 10 Cuaca BMKG `1:11`, 11 Sinkron & Profil `1:12`.

Variable collections: Primitives `VariableCollectionId:1:13` (23 colours, hidden scope), Color `VariableCollectionId:1:37` (30 semantic aliases, mode "Light"), Space `VariableCollectionId:1:68` (15 floats: space 4 to 48, radius 16/24/32/pill, size touch-min 48, control 56, tabbar 72, icon 24). Every variable has explicit scopes and WEB code syntax.

Text styles (Poppins): Type/Display 32/40 SemiBold, H1 24/32 SemiBold, H2 20/28 Medium, Body 16/24 Regular, Body Strong 16/24 Medium, Button 16/24 SemiBold, Label 14/20 Medium, Caption 12/16 Regular.
Effect styles: Shadow/Card, Shadow/Button Lip.

Components on page 00 (variant sets, fills, strokes, radius, padding and gap bound to variables; stacked at x=0, y ascending):
- Button `3:46` (20 variants: Primary, Secondary, Tertiary, Destructive by Default, Pressed, Disabled, Focus, Loading; TEXT property Label). Screenshot checked.
- Input `4:26` (Default, Focus, Filled, Error with icon and message, Disabled). Screenshot checked.
- OptionRow `4:44` (Default, Selected with check, Pressed, Disabled, Focus). Screenshot checked.
- Badge `4:65` (Success, Warning, Error, Info, Neutral, each icon plus label). Screenshot checked.
More components, all verified by screenshot:
- TabBar `6:256` (9 variants: Petani 5 tabs, Pegawai 4 tabs, one per active tab). Rebuilt after user feedback on uneven spacing: now a full-width 390 bottom-anchored bar, height 72, top radius 24, 1 px top border, no shadow. Each tab fills equal width (78 for Petani, 98 for Pegawai). Active state is a 56 x 32 coral-tint pill around the icon only, with a SemiBold label below; the label never sits inside the pill. No margin exception remains.
- AppBar `6:276` (Back, Back+Action, Title). Banner `6:299` (Offline, Sync, BMKG, AI, Success).
- Card `7:146` (Plain, Stat, Tint). ListItem `7:180` (Default, Pressed, Archived). Chip `7:189`. Segmented `7:200`. SearchField `7:219`.
- Stepper `8:178`, Dialog `8:193` (Confirm, Destructive, uses Button instances), BottomSheet `8:194` (single component), Toast `8:220`, Skeleton `8:228`.
- Icons frame `5:2`: 15 outline icon components, 24 px, stroke 2 (home, sprout, box, care, more, user, back, search, close, bell, plus, camera, check, cloud, minus), drawn by hand, not an imported library.
- Added variable `color/bg/inverse` (ink 900, FRAME_FILL) for Toast.
- Contrast table `9:177` (22 pairings, all pass, ratios computed from token hex values) and type specimen `9:364`, at x=2200 on page 00. Open item: the primary button's pressed state (coral-400 with coral-700 ring) is not in the table yet. The primary button's fill is 3.05:1 on white and its coral-700 lip is 4.92:1 on cream.
- Illustration gate: user approved the flat vector style ("I approve and accept it"). All 12 missing manifest illustrations are generated (800 x 800 vectors, rescaled to 320 in the grid), named `Illustration/<manifest id>`, in frame `10:1213` at x=0, y=4000 on page 00: nft-growing-table (retried with a stronger NFT-channel prompt), category-seeds, item-romaine-seeds, item-butterhead-seeds, item-abmix-nutrients, item-plant-care, item-rockwool, inventory-stock, nursery-seedlings, harvest-lettuce, sales-produce, weather-greenhouse. No text in any of them. The old candidate `9:398` was deleted.
- The 4 existing PNGs are uploaded as image-filled frames in row `11:1242` (y=5239): mascot-avatar `11:1238`, empty-inventory `11:1239`, empty-nursery `11:1240`, no-search-results `11:1241`. Their light edge specks were not cleaned.
- Style note: the existing mascot PNGs are glossier and more detailed than the new flat vector cats. Avoid showing both mascot styles in the same screen; use the PNGs for the 3 empty states and avatar, and the flat set for feature and inventory art.

Not yet built: chart tiles (cycle ring, NFT hole grid, stock bars, growth and sales charts). Build them with the dataviz skill when the first screen needs them.

## Next steps
1. Session B: pages 01, 02, 03 (device frame 390 x 844 with status bar, flow note above each frame, role chip, "Better Design review pending" tag). Page 01 first.
2. Chart tiles on page 00 when page 02 or 06 needs them.
3. Cleanup of PNG edge specks and the primary button pressed-state row in the contrast table remain open.

## Cat eye fix (after Session A)
User asked why two cats had green eyeballs. Cause: in the harvest-lettuce and sales-produce illustrations the outer eye layer was dark teal (`#24786c`, `#248a76`) with a lime iris, so there was no white eyeball. The other four (nft, inventory, nursery, weather) already had a white one. Fixed in all six: outer layer is plain white, iris `#8BCE66` for the pair detected, dark pupil kept; harvest iris and glow shrunk to nursery proportions. A first pass added a 1.5 px `#24786C` stroke around the eyeballs, and the user rejected it ("I like cateye without dark-teal outer layer"), so all 12 strokes were removed. Do not re-add an outline to the eyes. The illustration art is raw hex by nature (exempt from the token rule). Layer names were lost in the SVG re-import, so eyes are found by position and fill colour, not by name.

## Session B started: scaffold components (page 00, y=6000)
StatusBar `15:177` (390 x 44), HomeIndicator `15:187` (390 x 34), RoleChip `15:195` (Petani, Pegawai, Semua), FlowNote `15:196` (1200 wide, title, note, role chip, "Review Better Design tertunda" tag). Verified by screenshot. Build each screen as a 390 x 844 frame with a StatusBar instance at the top and a HomeIndicator instance at the bottom; instances cannot receive new children, so the frame builder script creates the content itself. Page 01 frames are not built yet.

## Page 01 Onboarding and Auth: built (11 frames, page `1:2`)
Flow note instance at the top, frame labels above each frame, three rows at y=220, 1180, 2140, 454 px column pitch.
- Row 1: 1.1 Splash `16:178`, 1.2 Welcome 1 `16:273` (Stok tertata), 1.3 Welcome 2 `16:400` (Semai sampai panen), 1.4 Welcome 3 `16:514` (Hama dan cuaca). Coral, sun and leaf hero fields with an arc, flat vector cats, pagination dots, Lanjut and Lewati, Masuk on the last.
- Row 2: 1.5 Login kosong `17:230` (Masuk button Disabled), 1.6 Login terisi `17:261`, 1.7 Login salah `17:292` (error on the password field only, so it does not reveal which one is wrong), 1.8 Akun nonaktif `17:327`. Show/hide password is an overlay "Tampilkan" toggle (48 x 48), not a component variant yet.
- Row 3: 1.9 Offline saat masuk `18:296`, 1.10 Izin notifikasi `18:321`, 1.11 Beranda kosong (Petani) `18:409` (3-step checklist, TabBar Petani).
- Audit script run on all 11 frames: no non-Poppins text, nothing under 12 pt, no unbound solid fills outside illustrations, no target under 48, no off-grid padding or gaps. Icon-only controls (bell, password toggle) carry an annotation with their accessibility label.
- Consistency rework (user request: all cats must match): the PNG mascots in 1.5 to 1.9 were replaced with 3 new flat-vector cats, generated and placed in the illustration grid `10:1213` on page 00 as `mascot-avatar-flat` (login logo, 160 px), `offline-no-internet` (1.9, 320 px) and `inactive-account` (1.8, 320 px). Each was re-imported through SVG at its exact final size (no rescale). The password "Tampilkan" toggles were realigned. The 4 PNG mascots remain on page 00 only as the uploaded originals and are no longer used in any frame. Use flat vector cats for every new screen, including empty states (empty-inventory, empty-nursery, no-search-results still need flat versions).
- Review pass (user asked: every spacing, layout, applied component, mobile-first UX). Fixed:
  - TabBar labels had no text style: added `Type/Label Strong` (14/20 SemiBold) and applied Label or Label Strong to all 41 tab labels.
  - Unbound 4 px paddings in Badge, RoleChip, FlowNote tag and HomeIndicator bottom padding bound to `space/4` and `space/8`. BottomSheet got a description.
  - Password toggle was an absolute overlay: new component set `InputPassword` (5 states, 48 x 48 "Tampilkan" inside the field) at page 00 (0, 6450), swapped into 1.5 to 1.7, overlays deleted.
  - Pagination dots are now component set `Pagination` (Step=1..3) at page 00 (1000, 6150), used in 1.2 to 1.4.
  - Welcome 3 primary button moved to y=682 so it stays where it was on steps 1 and 2.
  - Login logo cropped tight and 112 px tall (via SVG viewBox from render bounds) so fields clear the keyboard on small phones; new frame `1.6a Login terisi (keyboard)` `21:1048` shows a 291 px keyboard with Masuk docked 8 px above it.
  - 1.9 banner removed (it repeated the title); 1.11 gained a primary "Tambah meja tanam" button at y=666 above the tab bar.
  - Annotations added: responsive hero rule on welcome frames, keyboard rule on login frames, tab label text-scale cap (1.2x) on TabBar.
- Audit after fixes (12 frames): no non-Poppins, nothing under 12 pt, every text styled, no unbound solid fills, no target under 48, no overflow. Library audit: all 20 sets bound except decorative radii (handle 2, skeleton bar 8, status bar bits).
- Decision round (user: "apply best practices system design and UI/UX" to all five recommendations) now applied:
  1. Masuk is always enabled; new frame `1.5a Login kosong dikirim (validasi)` `24:575` (x=2270) shows inline errors "Isi username" and "Isi password", icon plus text, with focus-to-first-error annotation. 1.5 now uses the enabled Primary button.
  2. Button set `3:46` gained `Type=Ghost` (5 states, 48 high, coral text, no outline). "Lewati" (1.2, 1.3) and "Nanti" (1.10) use it. Primary now sits at y=690 on every welcome step. Ghost pressed uses dark text because coral text on coral-tint is only 4.42:1 (documented as a Gagal row, not used).
  3. Login has an AppBar Back (48 x 48) at y=44, content starts at y=108, and the line "Lupa password? Hubungi petani." sits under the password field on 1.5, 1.6, 1.7, 1.6a and 1.5a. Small-screen annotation: hide the logo when height is under 700.
  4. New components on page 00 at y=6750: IconButton `24:461` (4 states, INSTANCE_SWAP icon), ScreenHeader `24:470` (Trailing None or Action, TEXT property Judul), Checklist `24:471` (TEXT property Judul, hugs height). 1.11 uses ScreenHeader and Checklist instances. TextButton is the Ghost button.
  5. Contrast table `9:177` has 7 new rows (pressed Primary label 6.43, pressed ring 5.18 and 4.92, Ghost pressed 12.84, rejected coral text 4.42 marked Gagal, error message 6.21, focus ring on card 15.02). The type specimen `9:364` was moved below the taller table.
  Audit after this round: 13 frames on page 01 pass (Poppins only, nothing under 12 pt, all text styled, no unbound fills, no target under 48, no overflow); Ghost variants all 48 high and token-bound.
- Bottom chrome fix (user screenshot of 1.11): TabBar `6:256` is now 390 x 106 (72 for tabs plus 34 safe area), white background continuous to the screen edge, items aligned to the top with 16 pt top padding (was 8, which left a 42 pt white band under the labels and looked unbalanced), no bottom padding; measured inside the bar: pill 17 to 49, label 53 to 73, home indicator top 93, so 17 above the pill and 20 between label and indicator. In 1.11 the HomeIndicator is the last layer (on top of the bar) and the primary "Tambah meja tanam" button sits 24 pt above the bar (button 658 to 714, bar top 738). Rule for every screen that uses TabBar: place the instance at y=738, HomeIndicator above it in z-order, sticky CTA 24 pt above the bar, scrollable content ends above the CTA.
- Earlier recommendations (now resolved above): disabled Masuk button gives no reason on an empty form (prefer enabled plus inline validation); "Lewati" and "Nanti" use the heavy outlined Tertiary button, so a quieter Ghost text button variant (48 high) is advisable; no back from login to welcome; no "lupa password" path (scope has none, suggest the line "Lupa password? Hubungi petani."); Checklist, Header, bell IconButton and TextButton are still custom frames, not components; test the whole page at 360 x 640 and at 1.3x system text size before sign-off; the contrast table still lacks the pressed Primary state.
- Known limits: no keyboard is drawn except in 1.6a; the first-login offline copy assumes the plan's assumption 7 (first login needs internet). No keyboard is drawn. Better Design review still pending, so this page is not yet "reviewed" in the sense of the pipeline.
- Next: page 02 (Beranda P, Beranda W, skeleton, notifikasi list, offline and sync-pending, BMKG unavailable, cycle ring detail). Needs the cycle-ring chart tile built with the dataviz skill.

## Page 02 Beranda and Notifikasi: built (7 frames, page `1:3`)
Flow note at the top; row 1 at y=220: 2.1 Beranda (Petani) `28:260`, 2.2 Beranda (Pegawai) `28:362`, 2.3 Beranda memuat `28:446`, 2.4 Notifikasi `28:506`; row 2 at y=1180: 2.5 Offline dan antrean sinkron `29:503`, 2.6 BMKG tidak tersedia `29:599`, 2.7 Detail siklus `29:700`.
- Layout of Beranda Petani, top to bottom: ScreenHeader with bell, "Siap pindah" tint card, CycleCard (ring plus Meja A2, 37 hari lagi), two Stat cards (Stok menipis 3, Lubang terisi 184), WeatherCard. Pegawai has no weather card and uses the 4-tab bar. Content ends at y=636 (Petani), well above the tab bar at 738.
- New components on page 00 (y=7000 to 7300): CycleRing `27:276` (Compact 112, Large 224; annulus-segment arcs with round caps, tick at HSS 15, example value HSS 23 of 60), WeatherCard `27:255` (Default, Unavailable with Coba lagi), CycleCard `28:223`, TimelineStep `28:259` (Done, Current, Upcoming; status in text, not colour alone). The ring is a static example, not parametric: when real values are needed, edit the arc end angle.
- Dataviz rules applied: single-value ring (not a chart), direct label inside plus text equivalent below on 2.7, rounded ends, text in text tokens (not series colour). Decorative: the green-100 semai window on the track.
- Fixed while building: first ring used stroked wedges (looked like pies), rebuilt as annulus segments; tick no longer sticks out of the ring; weather title wraps instead of clipping; two clipped notification sublines shortened.
- Audit on all 7 frames: no non-Poppins, nothing under 12 pt, all text styled, no unbound fills, no target under 48, no overflow, margins 24, content clears the tab bar and CTA in every frame. Annotations added for role differences, loading, offline, BMKG and the ring text equivalent. Better Design review still pending.
- Review round (user screenshots): (1) WeatherCard is now two lines and 80 high in both states (Default: Berawan, 29°C plus Hujan 14.00; Unavailable: Cuaca BMKG plus Tidak tersedia, Coba lagi 96 wide); the "Cuaca" kicker was removed. (2) The black line on the ring is a fixed marker at HSS 15 (25% of the 60-day scale, 3 o'clock); it does not follow progress, only the green arc does. It was removed from the Compact ring (unexplained mark) and kept on Large with a legend line "Garis: HSS 15, pindah ke meja" on 2.7. (3) "Grey blur" was card shadows clipped by auto-layout wrapper frames (Content, Stats, Timeline, Actions): `clipsContent = false` was set on 43 wrapper frames on pages 01 and 02. Rule: every auto-layout wrapper that holds shadowed cards must have clipsContent off; only the 390 x 844 screen root clips.
- Not done on this page: no unread badge on the bell (the notification list separates "Baru" and "Sebelumnya" by text); no Pegawai notification list (reuse 2.4 without the Hujan row); no real data binding for the ring.

## Page 03 Akun: built (17 frames, page `1:4`, flow order)
Flow note at top; 4 columns, rows at y=220, 1180, 2140, 3100, 4060 (pitch 454 x 960); label above each frame (y-32); a "Dari ... Ke ..." note under each (y+852). Order was reworked after the user's flow review: numbering follows the user's path, not build order.
- Row 1 entry and exit: 3.1 Lainnya (Petani) `34:250`, 3.2 Profil (Pegawai) `34:347`, 3.3 Keluar konfirmasi `34:1509` (Keluar goes to Masuk 1.5), 3.4 Akun pegawai kosong `34:498`.
- Row 2 list and add: 3.5 Akun pegawai `34:423`, 3.6 Cari tanpa hasil `35:979` (new), 3.7 Tambah pegawai `34:979`, 3.8 Tambah validasi `34:1026`.
- Row 3: 3.9 Buang perubahan konfirmasi `35:1080` (new, Destructive "Buang" plus "Lanjut isi"; from Kembali on 3.7 or 3.12 with typed data), 3.10 Pegawai ditambahkan `34:1424`, 3.11 Detail pegawai `34:1085`, 3.12 Ubah pegawai `34:1131`.
- Row 4: 3.13 Data sudah berubah `34:1611` (expected_version), 3.14 Perubahan tersimpan `35:1133` (new, Detail plus toast), 3.15 Nonaktifkan konfirmasi `34:1370`, 3.16 Pegawai dinonaktifkan `35:1181` (new, list shows Sari as Nonaktif plus toast).
- Row 5: 3.17 Detail pegawai nonaktif `35:1263` (new; Badge Neutral "Nonaktif", no Nonaktifkan button; reactivation is not in scope).
- Path: 3.1 to 3.5 (or 3.4 when empty) to 3.7 to 3.8 to 3.10 to 3.11 to 3.12 to 3.14 or 3.13, then 3.15 to 3.16 to 3.17. Logout: 3.1 or 3.2 to 3.3 to 1.5. Pegawai has no route to 3.5.
- Components used: ScreenHeader, AppBar, ListItem (Lead icon swapped; Archived for Nonaktif), SearchField (Default, Filled), Input and InputPassword (Default, Filled, Error), Button, Badge (Success, Neutral), Dialog (Confirm, Destructive), Toast, TabBar. Custom frames: profile card, info card, initials Avatar. Dialog frames are clones with a `Scrim` rectangle (color/bg/inverse, node opacity 0.6) and a centred Dialog.
- Decisions: email not asked (backend has optional email; open question); password reset by petani is "Password baru (opsional)" on 3.12; Pegawai profile read-only; status in text, never colour alone; Penjualan reuses the box icon until page 08.
- Audit on 17 frames: Poppins only, nothing under 12 pt, all text styled, no unbound fills, no target under 48, no overflow, content clears actions. Better Design review pending.
- Not done: keyboard state on forms (reuse 1.6a), no prototype links (notes only), 360 x 640 and 1.3x text only annotated.

## Session C1: pages 04, 05, 06 rebuilt after the UI/UX review (77 frames). Review fixes applied.
Rules: numbering follows the user's path; every frame has a "Dari ... Ke ..." note under it (text named "Catatan alur", y+852); labels at y-32; 4 columns, pitch 454 x 960, rows from y=220; `clipsContent=false` on wrappers; flat-vector cats only; audit each page. Pages 01 and 02 now have Dari/Ke notes too. A failed `use_figma` script rolls back entirely. Several `setCurrentPageAsync` calls in one script worked fine.
Canonical data: today 15 Nov 2026. Stok: Romaine 12 pak, Butterhead 2 pak (menipis), AB Mix 8 kg, Rockwool 40 lembar, Obat Nabati 1 botol (menipis). Semaian: Romaine semai 29 Okt HSS 17 siap pindah (200 benih), Butterhead 5 Nov HSS 10 (150), Romaine 12 Nov HSS 3 (180), selesai: Romaine semai 23 Okt 42 benih pindah 7 Nov ke Meja A2. Meja A2 240 holes, 40 filled (42 moved, 2 rusak, HST 8, panen 22 Des = pindah + 45 days, 37 hari lagi, matches page 02 ring HSS 23); A3 120 of 240; B1 240 of 240 penuh; D1 perawatan; C1 new (0 of 180).
Backend facts: inventory item = nama, jenis (Benih, Media, Nutrisi, Obat with id_obat), satuan, stok minimum, saldo from movements, version. Semaian status is only `aktif` or `selesai`; selesai cannot be edited (409 SOWING_COMPLETED); materials deduct stock; pemindahan can be partial (sisa_benih). Meja status free text; `penuh` is derived. Pertumbuhan = pemindahan record (hst, estimasi_panen = pindah + 45 days, PATCH keterangan only). Kerusakan: tanggal, jumlah, jenis (free text), keterangan.
New components (page 00, y from 7800): Icon/chevron-down `49:550`, Icon/calendar `49:552`, Badge Status=Pending, Select `49:604` (Type Select or Date x State Default, Filled, Error), Qty `49:680`, StockItem `49:758` (State Default, Low, Out, Pending, Ready, Archived; used for stock, semaian and meja rows; Low badge label can be overridden), Sheet/Pilih `49:995` (Status, Jenis), Sheet/CatatStok `49:1059`, Sheet/Tanggal `49:1060`, HoleGrid `51:1294`, GridCard `51:1295`, SummaryCard `51:1570` (Basic, Progress), ErrorState `51:1571`. Text override names: StockItem Title, Sub, Qty; Select Label, Value, Message; Qty Value, Unit; GridCard Nama, Ringkas, Terisi, Kosong; SummaryCard Kicker, Value, Meta, Extra (Basic) or Kicker, Value, Awal, Akhir, Extra (Progress).
Review items resolved: page 02 data aligned; result frames for every edit; out-of-stock, full table, semaian selesai list, partial move, no free table, status Selesai (confirm), semaian and meja and stock load failure (ErrorState), skeletons on all three lists, offline "Tersimpan di HP" frames with Antrean badge, keyboard frames, date picker sheet, two-dimension filter (status chips plus Jenis chip with sheet), scannable stock rows (qty and status badge at right), numeric Qty field with +/-, Select and Date fields for pickers, Obat picker, one summary card component, sheets as components, hole grid as component, Arsipkan uses Destructive like other irreversible actions, error helper left-aligned in sheets.
- Page 04 (29 frames, `1:5`, reordered in path order after the flow review): 4.1 Stok `52:1504`, 4.2 Pegawai `52:1627`, 4.3 Memuat `52:1742`, 4.4 Gagal `52:1818`, 4.5 Kosong `52:1934`, 4.6 Cari tanpa hasil `52:2094`, 4.7 Pilih jenis `52:2176`, 4.8 Stok jenis Benih (new) `75:2172`, 4.9 Stok menipis plus Benih `52:2322`, 4.10 Tambah `53:1612`, 4.11 Jenis Obat `53:1666`, 4.12 Pilih obat sheet (new, Sheet/Pilih Type=Obat) `75:2189`, 4.13 Keyboard `53:1722`, 4.14 Validasi `53:1778`, 4.15 Ditambahkan `52:2414`, 4.16 Tersimpan di HP `52:2530`, 4.17 Detail barang baru (new, Lollo Rossa 8 pak) `75:2128`, 4.18 Detail menipis (new, Butterhead 2 pak) `75:2150`, 4.19 Detail Romaine 12 pak `53:1844`, 4.20 Detail habis (now Rockwool 0 lembar, reached from the Habis row in 4.1) `53:2101`, 4.21 Catat stok `53:1895`, 4.22 Stok kurang `53:1969`, 4.23 Stok tercatat `53:2046`, 4.24 Ubah `53:2155`, 4.25 Perubahan tersimpan `53:2206`, 4.26 Arsipkan konfirmasi `53:2261`, 4.27 Diarsipkan `52:2639`, 4.28 Arsip `52:2755`, 4.29 Detail arsip `53:2320`. Rockwool rows in 4.1, 4.2, 4.7 and 4.27 now use StockItem Out (0 lembar, Habis). Cross-page notes updated: page 02 points to 4.9 (Stok menipis), page 05 to 4.21 (Catat stok). Old numbers elsewhere in this file are stale.
- Page 05 (30 frames, `1:6`, reordered in path order after the flow review): 5.1 Semaian `55:1253`, 5.2 Pegawai `55:1363`, 5.3 Memuat `55:1465`, 5.4 Gagal `55:1546`, 5.5 Kosong `55:1667`, 5.6 Selesai list `55:1799`, 5.7 Tambah `55:1880`, 5.8 Pilih tanggal `55:1939`, 5.9 Keyboard `55:2105`, 5.10 Validasi `55:2174`, 5.11 Stok tidak cukup `55:2225`, 5.12 Ditambahkan `55:2285`, 5.13 Tersimpan di HP `55:2399`, 5.14 Detail semaian baru HSS 0 (new) `72:2191`, 5.15 Detail HSS 10 Butterhead `56:1554`, 5.16 Detail siap pindah `56:1614`, 5.17 Pindah ke meja `56:1823`, 5.18 Pindah berhasil `56:2235`, 5.19 Detail selesai dipindah semua (new, 29 Okt, 200 to A2) `72:2203`, 5.20 Tidak ada meja kosong `56:1950`, 5.21 Lubang kurang `56:1886`, 5.22 Pindah sebagian `56:2067`, 5.23 Detail siap pindah dengan sisa `56:2176`, 5.24 Pindah sisa (new, jumlah 80, A3 penuh) `72:2223`, 5.25 Ubah Butterhead `56:1673`, 5.26 Perubahan tersimpan `56:1715`, 5.27 Ubah Romaine (new, from 5.16, 5.23, 5.14) `72:2241`, 5.28 Tandai selesai konfirmasi (now Romaine 200) `56:1775`, 5.29 Detail selesai sisa tidak dipindah (new, 120 to A3, 80 not moved) `72:2213`, 5.30 Detail selesai 23 Okt `56:2340`. Cross-page notes updated: 2.x and 7.x point to 5.16; 6.x point to 5.17 (pindah) and 5.18 (sukses). Gotcha: right after `clone()` the nested instance layers are not readable in the same script; clone in one call and edit by id in the next. Changing an OptionRow `State` replaces its inner text node ids, so set the variant first and re-find the label.
- Page 06 (28 frames, `1:7`, reordered in path order after the flow review): 6.1 Meja `57:1347`, 6.2 Pegawai `57:1459`, 6.3 Memuat `57:1563`, 6.4 Gagal `57:1644`, 6.5 Kosong `57:1765`, 6.6 Tambah `57:1917`, 6.7 Validasi `57:1954`, 6.8 Ditambahkan `57:1999`, 6.9 Tersimpan di HP `57:2111`, 6.10 Detail meja kosong (new, Meja C1 0/180, "Belum ada tanaman di meja ini") , 6.11 Detail meja A2 `58:1239`, 6.12 Ubah status `58:1538`, 6.13 Status diubah `58:1851` (Tambah tanaman now Disabled plus the reason line "Meja Perawatan tidak menerima tanaman baru."), 6.14 Pilih semaian `58:2539`, 6.15 Belum ada semaian siap `58:2577`, 6.16 Detail meja penuh `58:2670` (Meja A2 240/240 after the move, reached from 5.24 and from Penuh tables in 6.1), 6.17 Ubah meja `58:2157`, 6.18 Lubang kurang `58:2195`, 6.19 Meja diubah `58:2236`, 6.20 Detail tanaman `58:3218`, 6.21 Ubah catatan `58:3272`, 6.22 Catatan tersimpan `58:3302`, 6.23 Daftar rusak `58:3360`, 6.24 Catat rusak `58:3396`, 6.25 Validasi `58:3457`, 6.26 Dicatat `58:3524`, 6.27 Ubah kerusakan `58:3575`, 6.28 Kerusakan diubah `58:3636`. Rows: list states, add, detail and status, tambah tanaman (pilih, belum siap, penuh), ubah meja, tanaman, rusak. Cross-page notes updated: 5.19 and 5.24 point to 6.11 and 6.16, 2.7 to 6.11. Old 6.x numbers elsewhere in this file are stale.
- Audit on all three pages passes (Poppins only, nothing under 12 pt, all text styled, no unbound fills, no target under 48, no overflow, content clears actions); no dangling note references; remaining one-way note links are siblings or cross-page.
- Cross-page note numbers: 2.1, 2.2, 2.4 point to 5.15 (siap pindah) and 4.8 (stok menipis); 2.7 to 6.10; 1.11 to 6.6; 5.x to 4.16, 6.10, 6.6; 4.x to 3.9, 3.13.
- Not done: no prototype links (notes only); the discard dialog and version-conflict dialog are not redrawn (3.9, 3.13); 360 x 640 and 1.3x text scale not drawn; Better Design review pending until 2026-11-26; the Badge set `4:65` bounds were not auto-resized after adding the Pending variant (cosmetic).

## Next: Session C2 (07 Panen, 08 Penjualan, 10 Cuaca BMKG, 11 Sinkron dan Profil), then Session D (09 Perawatan dan Hama) and a final audit. Use the new components (StockItem, Select, Qty, Sheet/*, SummaryCard, ErrorState) and the same state checklist: kosong, memuat, gagal, offline Antrean, keyboard, validasi, hasil, konfirmasi.

## Polish round (user: fix 5.23 screenshot, mobile-first rework, exclude Better Design)
- Better Design review is excluded from this work by the user (2026-11-16): do not run it and do not mention it as pending. The "Review Better Design tertunda" tag was removed from the FlowNote component. Ignore older "review pending" lines above.
- 5.23 bug: SummaryCard Basic let the Meta text run out of the card. SummaryCard Basic is now Judul row (Kicker plus status Badge at the right), Value, Meta (full width, wraps), Extra. Progress variant start label is "Tanam" (was a duplicate of the HST value).
- Duplicate frame labels removed on pages 01 to 06 (Figma already shows the frame name above each frame; my text labels overlapped it). Keep the "Catatan alur" notes.
- Dynamic type rule: Button, ListItem, StockItem, Chip, OptionRow, Toast, Banner, SearchField, TimelineStep, Qty and the Field frame of Input and Select now hug content with a minimum height (their old fixed height), so larger system text grows the control instead of clipping. Banner AI grows to 72 for its two-line message.
- Scans run on pages 01 to 06: no text overflows its card or frame (apart from the intended scrolling chip rows), no clipped fixed-width text; audit passes (page 01 unbound count is the imported illustration vectors and hero arcs, unchanged).

## Session C2: pages 07, 08, 10, 11 built (50 frames). Better Design review excluded by the user.
- Tanam tab now has three segments (Semaian | Meja tanam | Panen) using new component Segmented3 `61:616` (Selected Left, Middle, Right); pages 05 and 06 frames were swapped to it. CycleCard kicker on page 02 now says "Siklus berjalan" (the ring is Meja A2, HSS 23); the real nearest harvest is Meja B1 (HST 45, siap panen hari ini).
- Data: panen records 12 Okt 180 kg, 29 Okt 210 kg, 6 Nov 240 kg (Meja A1, 255 total, 15 reject, 90 kg sold, 150 left), new panen 15 Nov Meja B1 270 total, 18 reject, 252 layak. Estimasi: B1 hari ini, A3 (Butterhead 120, HST 26) 19 hari, A2 37 hari. Sales: Toko Segar 12 Nov 60 kg x Rp 40.000 belum lunas; Pasar Induk 8 Nov 30 kg lunas; Resto Hijau 2 Nov 100 kg lunas; new Warung Sari 15 Nov. November: Rp 7.460.000, 190 kg. Weather: Malang, 29 C berawan, hujan 14.00 sampai 17.00.
- Sheet/Pilih `49:995` gained Type=Batch and Type=Panen.
- Page 07 Panen (21 frames, `1:8`, reordered in path order after the flow review): 7.1 Estimasi Petani `62:613` (tap Meja B1 opens Catat panen with B1 selected), 7.2 Pegawai `62:722`, 7.3 Memuat `62:823`, 7.4 Gagal `62:905`, 7.5 Kosong (now with Primary "Lihat semaian") `62:1027`, 7.6 Riwayat with bar chart `62:1177`, 7.7 Riwayat kosong `62:1287`, 7.8 Catat panen `62:1437`, 7.9 Pilih tanaman `62:1497`, 7.10 Keyboard `62:1574`, 7.11 Validasi `62:1628`, 7.12 Melebihi tanaman `62:1680`, 7.13 Panen dicatat `62:1741`, 7.14 Detail panen baru (new, 15 Nov, Meja B1, 252 kg, belum terjual) `80:1586`, 7.15 Tersimpan di HP `62:1839`, 7.16 Detail panen antrean (new, Badge Pending, Catat penjualan Disabled with reason) `80:1605`, 7.17 Detail panen 6 Nov `62:2415`, 7.18 Detail Pegawai `62:2464`, 7.19 Ubah `62:2511`, 7.20 Berat di bawah terjual `62:2548`, 7.21 Perubahan tersimpan `62:2588`. Page 08 note for 8.6 now says the sale form preselects the panen it came from (7.13: panen 15 Nov, sisa 252 kg). Page 06 frames were not changed: the Panen segment is the entry for harvesting a ready table. Old 7.x numbers elsewhere in this file are stale.
- Page 08 Penjualan (22 frames, `1:9`, Petani only): 8.1 Daftar `63:613` (AppBar Back+Action with Icon/chart `82:610` opens Ringkasan; accessibility label "Ringkasan"), 8.2 Memuat `63:706`, 8.3 Gagal `63:749`, 8.4 Kosong `63:832`, 8.5 Ringkasan with bar chart `63:927`, 8.6 Belum lunas filter `82:1352`, 8.7 Catat penjualan (Panen 6 Nov, sisa 150 kg; from 7.17 or the list) `63:974`, 8.8 Catat penjualan, panen baru (new, Panen 15 Nov, sisa 252 kg; from 7.13 and 7.14) `83:1479`, 8.9 Pilih panen `63:1033`, 8.10 Keyboard `63:1109`, 8.11 Validasi `63:1171`, 8.12 Melebihi sisa `63:1243`, 8.13 Tanggal sebelum panen `63:1303`, 8.14 Dicatat `63:1363`, 8.15 Detail baru Warung Sari `82:1369`, 8.16 Tersimpan di HP `63:1460`, 8.17 Detail antrean `82:1378`, 8.18 Detail Toko Segar belum lunas `63:1952`, 8.19 Detail Pasar Induk lunas `82:1387`, 8.20 Ditandai lunas `63:1991`, 8.21 Ubah `63:2029`, 8.22 Perubahan tersimpan `63:2086`. Page 07 notes: 7.13 and 7.14 point to 8.8, 7.17 to 8.7. Old 8.x numbers elsewhere in this file are stale.
- Page 10 Cuaca BMKG (11 frames, `1:11`, Petani only, reordered after the flow review): 10.1 Kondisi `64:1117`, 10.2 Prakiraan `64:1227`, 10.3 Saran (AI banner, cards with "Dasar", read-only, no link to page 09) `64:1302`, 10.4 Saran kosong (new) `89:997`, 10.5 Pilih lokasi (new, Sheet/Pilih Batch relabelled; location line is now a 48 pt row with Icon/chevron-down on every frame) `89:877`, 10.6 Memuat `64:1351`, 10.7 BMKG tidak tersedia `64:1387`, 10.8 Kondisi tanpa internet `64:1468`, 10.9 Prakiraan tanpa internet (new) `89:967`, 10.10 Saran tanpa internet (new) `89:982`, 10.11 Saran AI tidak tersedia `64:1583`. Entry points: card in 2.1 and the Cuaca dan saran row in 9.1. Old 10.x numbers elsewhere in this file are stale.
- Page 11 Sinkron (10 frames, `1:12`, both roles, reordered after the flow review): 11.1 Terkini `65:854` (also reached from Offline and Sync banners and Antrean badges on any page), 11.2 Memuat `65:888`, 11.3 Izin notifikasi mati `65:1240`, 11.4 Antrean tanpa internet `65:1067` (sync button Disabled with reason; also reached from 2.5), 11.5 Berjalan `65:924` (Loading button now reads "Mengirim..."; Sync banner icon is the cloud), 11.6 Selesai `65:1029`, 11.7 Gagal sebagian `65:1172`, 11.8 Konflik data (new, Dialog Confirm: Pakai data server or Kirim ulang punya saya) `91:2025`, 11.9 Perbaiki data (new, Ubah penjualan with the amount error, "Simpan dan kirim ulang") `91:2036`, 11.10 Sesi berakhir (new, leads to Masuk 1.5; data stays safe on the phone) `91:2093`. Queue item names now match the other pages (Warung Sari). Notes on 2.5 and 1.5 point to 11.4 and 11.10. Library fix: Button Loading variants bind their label to the Label property; Banner Sync uses Icon/cloud. Old 11.x numbers elsewhere in this file are stale.
- Notes: Dari/Ke on every frame; 3.1, 3.2 and 5.1 notes now point to 8.1, 11.1 and the Panen segment. Audit on 07, 08, 10, 11 passes (Poppins only, no text under 12 pt, all styled, no unbound fills, no target under 48, no overflow or clipped text, content clears actions).
- Known: the Button Loading variant always reads "Memuat" (label property not applied in that state); Banner Sync uses a check icon. Chart bars are hand-built (not a component). Discard and version-conflict dialogs are not redrawn (3.9, 3.13).
- Next: Session D, page 09 Perawatan dan Hama (hub and riwayat, photo tips, camera priming and denied, capture, preview and upload, analyzing, hasil with one or several detections, low confidence, tanaman sehat, rekomendasi obat and rotasi, konfirmasi perawatan with stock deduction, success, riwayat detail, offline upload error), then a final audit across all pages. The Rawat tab is the entry; Petani only.

- Spacing fix (user screenshot of the Tanam segmented control): in Segmented3 each segment is 111 wide, so "Meja tanam" left only 7 pt padding in its pill. The label is now "Meja" on pages 05, 06 and 07 (and in their notes). Rule: a 3-segment label must leave at least 14 pt each side (text width 83 or less at Body 16); a scan of pills, chips and badges on pages 05, 06, 07 and 10 found no other tight label.

## Session D: page 09 Perawatan dan Hama built (23 frames, `1:10`, Petani only). All 11 pages now built; frame counts changed after the flow reviews (check the per-page lines).
- Frames (27, path order after the flow review): 9.1 Rawat hub `76:622`, 9.2 Memuat `76:750`, 9.3 Gagal `76:823`, 9.4 Belum ada perawatan `76:936`, 9.5 Tips foto `76:1020` (first time only), 9.6 Izin kamera `76:1111`, 9.7 Izin ditolak `76:1158`, 9.8 Kamera `76:1231`, 9.9 Pratinjau `76:1577`, 9.10 Foto tanpa internet `76:2404`, 9.11 Foto tersimpan antrean (new, hub with Banner Offline, Foto daun Antrean, toast) `86:1478`, 9.12 Mengunggah `76:1687`, 9.13 Menganalisis `76:1796`, 9.14 Hasil hama (Thrips 87%) `76:1843`, 9.15 Hasil beberapa hama `76:2085`, 9.16 Keyakinan rendah `76:1966`, 9.17 Tanaman sehat `76:2229`, 9.18 Analisis gagal `76:2323`, 9.19 Rekomendasi Thrips `77:1248`, 9.20 Rekomendasi Kutu daun (new, Sabun insektisida recommended, last for Kutu daun Obat Nabati 5 Nov) `86:1491`, 9.21 Konfirmasi `77:1294`, 9.22 Stok obat kurang `77:1352`, 9.23 Perawatan dicatat `77:1411`, 9.24 Detail perawatan baru (new, 15 Nov) `86:1505`, 9.25 Perawatan tersimpan di HP `77:1509`, 9.26 Detail perawatan antrean (new) `86:1591`, 9.27 Detail perawatan 12 Nov `77:1601`. 9.15 sends Thrips to 9.19 and Kutu daun to 9.20. Old 9.x numbers elsewhere in this file are stale.
- Facts: the backend does not have detection or recommendations yet (API.md); this is design only. Detection types: Thrips, Kutu kebul (whitefly), Kutu daun (aphids). AI result always shows the "Saran AI membantu. Keputusan tetap di tangan petani." banner; photo quality tips and a low-confidence state are included; the photo is a "Foto contoh" placeholder card.
- Cross-page: page 10 saran says "Perawatan: halaman 09"; 9.20 points to 4.21 (Catat stok).
- Final audit (pages 01 to 11, 197 frames): Poppins only, nothing under 12 pt, all text styled, no unbound fills outside illustrations, no target under 48, no overflow, every frame has a Dari/Ke note, no dangling note references. The only flagged clipping is the intended scrolling chip rows on 4.x and 6.x.
- Remaining optional work: prototype links (notes only today), 360 x 640 and 1.3x text-scale test frames, discard and version-conflict dialogs redrawn per page (3.9 and 3.13 serve as the patterns), chart bars as a component, (Button Loading label fixed: it now follows the Label property.)

## Gotchas to remember
- Paint-level `opacity` set through `{...boundPaint, opacity}` was ignored for a scrim; set `node.opacity` instead.
- `ListItem` lead icon: `Lead` frame child 0 is an Icon instance, use `swapComponent` with the icon component id (user 5:31, box 5:17, cloud 5:60).
- Component text override keys: Button label property `Label#3:0`, ScreenHeader `Judul#24:10`; Input and InputPassword text layers `Label`, `Value`, `Message`; Dialog texts `Title`, `Body`, `Label` (index 0 primary, 1 secondary).
- Do not use `node.rescale()` on generated illustrations. After rescaling to 320, the user's Figma client drew them oversized and cropped even though the server render and the node data were correct. Fix used: export each as SVG string and re-import with `createNodeFromSvg` at the final size, so the geometry is native. The 12 illustrations in frame `10:1213` are now these re-imported nodes (new ids, e.g. `13:177` nft-growing-table). Their old ids in the list above are stale.
- Call `setCurrentPageAsync` before creating sections, once per `use_figma` call.
- `resize()` on auto-layout frames fixes the height, so reset sizing to AUTO.
- Poppins styles available in Figma: Regular, Medium, SemiBold (and others).
- Never run `use_figma` calls in parallel; build sequentially.

## v3 Royal re-theme, Phase 1: token swap (2026-11-16, done)
Rules: [figma-v3-direction.md](figma-v3-direction.md). The user saved the Figma version "v2 coral, before Royal" first. Rollback data: [figma-v2-coral-snapshot.json](figma-v2-coral-snapshot.json). Screenshots: coral in [v3-before/](v3-before/), after Phase 1 in [v3-phase1/](v3-phase1/), same 10 frames.

Variables and styles:
- 14 primitives were renamed and revalued in place (ids kept), and 18 Color aliases retargeted, as in section 3 of the direction doc. `color/tint/coral` is renamed `color/tint/brand` (same id `1:60`).
- New variables:
  - `color/text/on-accent` `98:610`: charcoal, text on lime
  - `color/text/on-muted` `98:611`: slate/600, secondary text on gray/200 or ice
  - `color/data/fill` `98:11952`: blue/500, data marks
  - `radius/12` `97:610` and `radius/20` `97:611`
- `text/on-secondary` stays white: in this file it means text on a dark fill.
- Text styles:
  - Display 34/40 Bold
  - H1 28/36 Bold
  - H2 20/28 SemiBold
  - Body Strong 16/24 SemiBold
  - new: Type/Value 28/36 Bold and Type/Value Large 34/40 Bold
  - Body, Button, Label and Caption unchanged
- Effects: Shadow/Button Lip is bound to blue/800; Shadow/Card is charcoal at 8%.

Component and frame changes:
- 32 texts on page 00 were rebound: lime fills to on-accent; slate on grey or ice to on-muted; accent on ice to text/info.
- Keyboard captions and "Foto contoh" placeholders on pages 01 and 04 to 09 were rebound to on-muted.
- TabBar: the active IconPill fill is now action/secondary (lime).
- Data marks were rebound from lime to data/fill:
  - HoleGrid and GridCard filled holes
  - CycleRing arc and caps
  - SummaryCard progress
  - chart bars on 7.6 and 8.5
- Welcome heroes 1.2 and 1.4 are bound to bg/hero.
- Illustrations on pages 00 to 11 (about 3,000 paints) were recoloured by hue mapping. Pinks are kept, and cat eyes are untouched.
- Wrap fixes:
  - "29°C" hugs its width on page 10.
  - The weather text column fills its width; the location text hugs.
  - "Riwayat" headings (4.x) fill their width.
  - 14 more fixed-width texts that wrapped early now fill their width.
  - StockItem Ready title wraps instead of clipping.
- The contrast table on page 00 (`9:177`) was rebuilt from live tokens: 35 rows, 6 new.
  - Gagal: disabled text (labelled WCAG-exempt) and blue text on ice (not used).
- The type specimen (`9:364`) is updated and shows the Value rows.

Audit after Phase 1 (pages 01 to 11):
- Poppins only, nothing under 12pt, all text styled.
- No unbound fills outside illustrations, no target under 48.
- Contrast passes everywhere except disabled controls (exempt) and the 9.8 camera text, which sits on a dark viewfinder (false positive).
- Dataviz validator: blue and amber pass CVD and normal vision. Amber is under 3:1 on the surface, so it is always labelled.

Left for Phase 2: list-row icon containers are still green tint with green glyphs (StockItem, ListItem, Rawat). The direction doc wants ice-blue containers with blue glyphs, done with the icon redraw.

### Phase 1b: colour by context (2026-11-16)
The user flagged three problems: lime as a main colour on cats, the sun and the greenhouse looks wrong.
- Fix for illustrations:
  - Original v2 fills were recovered per node id from version `2422142971721022423` ("v2 coral, before Royal").
  - They were remapped by role with [tools/illustration-remap.js](tools/illustration-remap.js) and re-applied on pages 00 to 11: 3,416 paints, none missed.
  - Result: warm-white cats with blue stripes, blue objects, ice glass and ground, leaf-green plants with lime highlights only, an amber sun and sand rockwool.
- Fix for icons:
  - New tokens `color/icon/default` `107:610` (blue/500) and `color/icon/muted` `107:611` (slate/500).
  - ListItem and StockItem Lead containers changed from tint/success to tint/brand (ice). The glyph is icon/default; the Archived glyph is icon/muted.
  - 73 green glyph overrides on screen instances were rebound, on pages 02, 03, 06, 09 and 10.
  - Status badges and TimelineStep "done" markers stay success green.
- The full rule table is in section 8a of the direction doc.

### Review of the four "still fails" items (2026-11-16)
- **Disabled text at 3.93:1.** WCAG exempts it. Kept. Disabled controls still read as disabled and stay legible.
- **Blue text on ice at 4.30:1.** Confirmed unused: the audit finds no text/accent on tint/brand or tint/info. Text on ice uses text/info (6.11) or on-muted (6.71).
- **Camera text (9.8).** The flag was a false positive on the placeholder, but a real live feed can be bright, so it is fixed:
  - Frame `76:1231` fill is now bg/inverse.
  - The hint text sits in a "Petunjuk" scrim pill `108:11950`: bg/inverse at 64% node opacity, 240x40.
  - "Tutup" is a 48-high touch target with the same scrim, `108:11952` (was 41x20 text).
- **Amber under 3:1.** Amber is not used anywhere in the UI, only in illustrations (sun, coins). Rule kept: amber only with a label.

## v3 Phase 2: icon set (2026-11-16, waiting for user OK)
- Style: Headspace-like duotone on the 24 grid.
  - The 2pt outline (round caps and joins) is kept. Node ids are unchanged, so the ~1,000 instance colour overrides survive.
  - A soft "Tone" fill layer at 30% node opacity sits behind each closed body: home, sprout leaves, box, shield, user, search lens, bell, camera, cloud, calendar.
- Tone colour follows context. Every Icon instance's Tone fill is set to the same variable as its outline stroke: 70 on page 00 and 441 on pages 01 to 11.
- New components (duotone):
  - Icon/warning `110:719`, Icon/info `110:726`, Icon/sun `110:733`
  - Icon/edit `110:746`, Icon/trash `110:752`, Icon/sync `110:761`, Icon/chevron-right `110:767`
  - These are not yet wired into components such as the badges. That happens in rollout.
- All icon vectors use SCALE constraints, so 32 and 48 sizes work; use a 2.5 and 3 stroke override.
- Review sheet: `Icons/States` `111:719` on page 00. It shows default (icon/default on tint/brand), selected (white on blue), active tab (charcoal on lime), muted (icon/muted), and sizes 24/32/48 in 40/48/72 containers (radius 12/16/24).
- Renders are in [v3-phase2/](v3-phase2/): icon-sheet-1x.png and tabbar.png.

## v3 Phase 3: pilot redesign (2026-11-16, waiting for user approval)
Pilot frames are clones on page "Pilot v3" `113:1106`. The originals on pages 02, 04, 06 and 09 are unchanged. Copy, data, flow and notes are unchanged.
- New component BentoTile `114:1127` on page 00:
  - 1x1 tile, 163x163, radius 24, padding 16, Shadow/Card
  - variants Tone=Default and Tone=Warning
  - properties Value `Value#114:0`, Label `Label#114:3`, Icon swap `Icon#114:6`
- **2.1 Beranda** `113:1650`:
  - Blue hero `114:1732`: "Siklus berjalan / Meja A2 (Type/Value) / 37 hari lagi" plus a CycleRing Compact. The arc is lime; track and window are white at 22% and 30%.
  - "Siap pindah" is now a ListItem row with a chevron.
  - Stats are BentoTiles: "2 Stok menipis" is Warning (box icon on amber tint); "400 Lubang terisi" is Default (sprout).
  - The weather row is kept.
- **4.1 Stok** `113:3481`: the four StockItems sit in one inset grouped card "Grup stok" `114:1786` (radius 24, shadow). Hairline dividers are inset 76; item fills are cleared.
- **6.11 Detail meja** `113:6369`:
  - The GridCard instance is restyled as the hero: bg/hero, radius 32.
  - Text is white and "40" is in Type/Value Large.
  - Filled holes are lime (deco/leaf, graphic on blue 3.61:1). Empty holes are white outlines at 45%. The legend matches.
  - Content ends at y 676, clear of the CTA.
- **9.1 Rawat** `113:7480`:
  - "Cek hama" is the blue hero, radius 32, with the title in Type/H1 white. The illustration sits on an ice tile so the blue bottle stays visible.
  - The history is grouped in one card "Grup riwayat" `114:1793`.
- Renders are in [v3-phase3/](v3-phase3/). Each compare-*.png strip shows coral v2, then after the token swap, then the pilot.
- Follow-ups noted, not done:
  - Stok rows all use the sprout icon, including Nutrisi and Media. Per-category icons would help.
  - The Warning BentoTile's default icon slot is box.
- Rollout (Phase 4): apply the same edits to the original frames, not replace them, so node ids, numbering and Dari/Ke notes stay. Then delete page "Pilot v3".

## v3 Phase 4: rollout (2026-11-16, done)
The user approved the pilot. The edits were applied to the original frames, so node ids, numbering and Dari/Ke notes are unchanged. Page "Pilot v3" is deleted.
- **Grouped lists.** 39 stacks of 2 or more StockItem/ListItem became one inset card "Grup daftar": radius 24, Shadow/Card, dividers inset 76, white item fills cleared. Pages:
  - 03: 3.1, 3.3, 3.5, 3.10, 3.16
  - 04: 4.1, 4.2, 4.7, 4.8, 4.15, 4.16, 4.27, 4.28
  - 05: 5.1, 5.2, 5.12, 5.13
  - 06: 6.1, 6.2, 6.8, 6.9, 6.16, 6.26
  - 07: 7.1, 7.2, 7.15
  - 08: 8.1, 8.14, 8.16
  - 09: 9.1, 9.11, 9.15, 9.25
  - 11: 11.4, 11.5, 11.7, 11.8
  - Archived and pressed rows keep their own tint.
  - On 6.16 the group sits inside the existing "Tanaman" card, so it was flattened (no fill, shadow or radius).
- **Beranda.** 2.1, 2.2, 2.5 and 2.6 each have:
  - a blue Hero: kicker, Type/Value title, sub, and CycleRing with a lime arc
  - a "Siap pindah" ListItem row
  - Stats as BentoTiles: Warning for "Stok menipis", Default with sprout for "Lubang terisi"
  - Values were read from each frame (2.5 and 2.6 show 2 semaian HSS 15, 3 and 184).
  - The 2.3 skeleton was reordered to match: hero 160, row 80, tiles 163, weather.
- **Detail meja.** GridCard heroes on 6.10, 6.11, 6.12, 6.13, 6.16 and 6.19: bg/hero, radius 32, white text, leading count in Type/Value Large, lime filled holes, white outline empty holes at 45%.
- **Rawat.** 9.1 "Cek hama" `76:636` is the blue hero with an ice illustration tile and a white Type/H1 title.
- **Audit (pages 01 to 11):**
  - Poppins only, nothing under 12pt, all text styled.
  - No unbound fills outside illustrations, no target under 48, no early wraps.
  - The only contrast flags are disabled buttons and options at 3.93 (WCAG exempt).
  - Content clears the CTA or tab bar on every converted frame.
- **Not changed, flagged for the user:** 6.16 "Detail meja penuh" shows Meja A2 at 240/240, while the canonical data says the full table is B1. This was already the case before v3. Stok rows all use the sprout icon.

## v3 fix round: components and spacing (2026-11-16)
- **Grouped rows.** Grey archived rows inside "Grup daftar" broke the card, with rounded grey rows and gaps at the dividers.
  - Rows bound to bg/disabled are cleared (4 rows on page 03, 2 on page 04).
  - Every row in a group has radius 0.
  - The archived state now reads from the muted text and a muted icon.
- **Disabled-CTA helper text** moved into Actions, above the button: 6.13, 6.16, 7.16, 8.17, 11.4. Actions stays bottom-anchored at 802 and the toast sits 16 above it. On 6.13 the toast covered the caption before.
- **Toast placement** normalised to 16 above Actions: 4.23 and 4.25 (was 100), 6.23, 7.21 and 8.22.
- **Forms.**
  - 4.14, 7.8, 7.9, 8.7, 8.8 and 8.9: Content gap 16 to 12, so the CTA clearance is 30.
  - Summary cards ("Berat layak", "Total") on 7.8 to 7.10 and 8.7 to 8.10 had the hierarchy inverted. Fixed: the label is Type/Label on-muted and the value is Type/Value charcoal.
- **GridCard detail screens (6.x).** Content gap 12; Tanaman card padding 12 at top and bottom. 6.13 clearance to the toast is 22. 6.20 "Meja diubah" is 14 (toast, transient).
- **Entity icons on list rows.**
  - New duotone icons: Icon/droplet `118:1116` and Icon/layers `118:1121`.
  - Assignments: Benih sprout, Nutrisi droplet, Media layers, Obat care; buyers (8.x) user; treatments (9.x) care, Foto daun camera; damage (6.x) and Rusak (11.x) warning on tint/warning; Stok (11.x) box; Penjualan (3.x, 11.x) chart; Sinkron (3.x) sync.
  - Glyph colour comes from context: icon/default; text/warning on a warning tint; icon/muted when archived.
  - Gotcha: a paint bound from a black placeholder renders black inside instance overrides until its stored colour matches. Always write the resolved colour into the paint as well. A file-wide sweep confirms none are left.
- **Meja B1 decision.**
  - 6.16 stays "Meja A2 penuh" (it is the result of 5.18: 40 + 200 = 240). Its note now says it comes from 5.18.
  - New frame **6.17 Detail meja siap panen (B1)** `118:12053`: Meja B1 240/240, Penuh, one Romaine row "Siap panen hari ini", Primary CTA "Catat panen" to 7.8 with B1 selected.
  - Reached from the 6.1 B1 row. The 7.8 note lists 6.17 as an entry.
  - Old 6.17 to 6.28 became **6.18 to 6.29**. Page 06 now has 29 frames, laid out in path order with notes moved. No other page referenced the shifted numbers.
- **Audit after this round (pages 01 to 11):**
  - Style, unbound fills, contrast (disabled excepted), wraps, toast-over-text and targets are all clean.
  - The only overflow flags are the intended scrolling chip rows (4.8, 4.9, 6.1, 6.2, 6.8, 6.9).

## v3 completion round: QA, heroes, icons, HIG, dialogs, chart (2026-11-16)
- **QA page "QA v3"** `121:14863` holds clones of 2.1, 3.1, 4.1, 6.11, 7.8 and 9.1.
  - Row 1: all text at 1.3x (font size and line height). Row 2: 360x640 with stretch constraints.
  - Found:
    - StockItem and ListItem titles and subs clipped.
    - BentoTile at fixed 163 overflowed 360 (right edge 366).
    - Content collided with the fixed CTA.
  - Fixed:
    - Row Text columns now FILL and hug height; titles and subs wrap with truncation off. Rows hug height with min 80.
    - BentoTiles in Stats are FILL.
    - Actions is an opaque bg/app footer, extended to the tab bar or the bottom edge, with HomeIndicator and Toast kept on top (193 frames).
  - Re-test: no clipped text at 1.3x, nothing past 360.
- **Heroes.**
  - SummaryCard `51:1570` (both variants) is the blue hero: bg/hero, radius 32, white text, Value in Type/Value Large, Progress bar track action/primary-pressed with a lime fill. It covers the detail and summary screens in 4.x, 5.x, 7.x and 8.x. No screen has two heroes.
  - Profil cards are blue heroes on 3.1, 3.2, 3.3, 3.11, 3.14, 3.15 and 3.17. Badge overrides were reset to keep status colours.
  - Lists and forms intentionally have no hero.
- **Icons in components.**
  - Badge glyph frames are now icon instances at 16pt with a 1.5 stroke: check, warning, close, info, minus; Pending uses sync.
  - Banner Sync uses sync. Toast Info uses info.
  - Every "Icon/back rotated 180" chevron is now Icon/chevron-right (ListItem and 2 more on page 00).
- **Page 00.**
  - Five component descriptions no longer say coral or green: Button, OptionRow, Card, Checklist, CycleRing.
  - New sheet `Foundations/Color` `122:14755`: 21 token-bound swatches (brand, supporting, status).
- **HIG.**
  - Every tab screen already used the large-title ScreenHeader.
  - Sheet grabbers are 36x5 (9 variants); top radius 32 confirmed.
  - Native annotations: swipe-back on AppBar Back variants; spring motion plus Reduce Motion on Toast, BottomSheet, Sheet/Pilih, Sheet/CatatStok, Sheet/Tanggal and Dialog.
- **Dialogs per page.** The "seperti 3.9 / 3.13" references are replaced by real frames, appended at the end of each page with notes:
  - 4.30 Buang perubahan (from 4.10) `122:14850`; 4.31 Data sudah berubah (from 4.24) `122:14892`
  - 5.31 (from 5.25 or 5.27) `122:14934`; 6.30 (from 6.18) `122:14969`
  - 7.22 Buang (from 7.8) `122:15004`; 7.23 Data (from 7.19) `122:15043`
  - 8.23 Buang (from 8.7) `122:15078`; 8.24 Data (from 8.21) `122:15119`
  - 9.28 Buang (from 9.21) `122:15160`
  - Source notes now point to these frames.
- **Chart component** ChartBar `122:15376`:
  - Value and Label text properties; Bar FILL bound to data/fill with only the top corners rounded (4).
  - Column height = bar + 48.
  - The six columns on 7.6 and 8.5 are instances with data heights 60/70/80 and 83/102/120.
- **Frame counts:** 01: 13, 02: 7, 03: 17, 04: 31, 05: 31, 06: 30, 07: 23, 08: 24, 09: 28, 10: 11, 11: 10 (225 total).
- **Final audit (pages 01 to 11):**
  - No style issues, no unbound fills, no contrast failures (disabled excepted).
  - No early wraps, no overflow (chips excepted), no target under 48.

## Logo v3 (started 2026-11-16)
The brief is [logo/brief.md](logo/brief.md): evolve the cat, flat style, 3 gates. Phase 0 (brief) is written and waits for the user's OK. Nothing has changed in Figma yet. Page "Logo v3" will be created in Phase 1.
- **Phase 1 done (2026-11-16):**
  - Page "Logo v3" holds sheet `131:1147` "Fase 1 / Siluet".
  - 12 concept components C01 to C12 (240 box). Each mark is one flattened vector: union of the shapes, minus the eye cuts. Constraints SCALE. 16/24/32/48 previews below each.
  - Joy scores: C02 and C10 7/7; C01 and C08 6/7; C03, C04, C06 and C07 5/7; C11 4/7; C05, C09 and C12 3/7.
  - Render: [logo/phase1-silhouettes.png](logo/phase1-silhouettes.png). Waiting for the user to pick 3.
- **Phase 2 done (2026-11-16):**
  - Sheet `132:1194` "Fase 2 / Warna": C10, C02 and C01 in 6 flat colourways on 240 tiles (radius 54, smoothing 0.6, iOS-like).
  - Each tile has three vector layers: Body (holes for eyes and smile), Accent (drop, sprout or leaf) and Eyes.
  - Contrast results:
    - Cat to tile passes everywhere (3.7 to 17.5).
    - The lime accent fails on ice (W3, 1.2) and white (W5, 1.3).
  - The mark fills only about 45% of the tile; Phase 3 enlarges it to 60 to 70%.
  - Render: [logo/phase2-colourways.png](logo/phase2-colourways.png). Waiting for the user to pick 1 concept and 1 or 2 colourways.
- **Phases 3 and 4 done (2026-11-16):** the user chose C10 with colourways 1 (blue) and 4 (charcoal).
  - **Construction** on sheet `134:1194` "Fase 3 / Konstruksi":
    - The mark now has a 7-unit gap between the drop and the head.
    - In the colour versions the eyes are a separate layer under the body holes.
    - Components:
      - Logo/Mark `134:1196` and Mark Arang `134:1225`
      - Mono `134:1254` and Reversed `134:1277`
      - Size 16/24/32/48: `134:1336`, `134:1361`, `134:1386`, `134:1411`
      - AppIcon iOS Biru `134:1441` and iOS Arang `134:1469`
      - Android Foreground `134:1497`
    - Plus a construction grid.
  - **Tests** on sheet `134:2059` "Fase 4 / Uji":
    - Mocks: 1.1 splash and 1.5 login (clones, originals untouched), and home screens on light and dark wallpaper.
    - Small sizes are readable at 16 px.
    - Colour vision: ΔE 30 or more for blue/lime, blue/cream and cream/charcoal.
  - **Exports** in [logo/](logo/): 7 SVGs, PNG at 1024, 512, 192 and 48, and [logo/usage.md](logo/usage.md).
  - Waiting for the user to approve before Phase 5, which swaps the Logo layers on 1.1, 1.5, 1.5a, 1.6 and 1.7.
- **Phase 5 done (2026-11-16):** the final logo is approved and swapped in on page 01.
  - The Logo frames are now Logo/Mark instances: 80x80, radius 18, named "Logo".
    - 1.5 `141:1468`, 1.6 `141:1472`, 1.7 `141:1476`, 1.5a `141:1480`
  - The 1.1 Splash illustration is replaced by Logo/Mark 220x220, radius 50, `141:1484`.
  - Frame ids, numbering and notes are unchanged.
  - Page "Logo v3" stays as the record: phase sheets and mocks.
  - Logo rules: [logo/usage.md](logo/usage.md).
