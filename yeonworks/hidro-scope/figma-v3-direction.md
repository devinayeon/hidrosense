# HidroSense Mobile UI v3 "Royal": design direction

Standing design instruction for every agent or designer working on Figma file `KZ7dODi36pWhEPumnRz7RG` from 2026-11-16. It replaces the coral and green palette of v2. Layout rules, flows, copy, frame numbering, Dari/Ke notes and node ids from [figma-v2-handoff.md](figma-v2-handoff.md) still apply unless this file changes them.

Scope: design only, no app code. Light mode only. Font stays Poppins. The re-theme is in place: the Color collection's Light values are overwritten. The rollback data is in [figma-v2-coral-snapshot.json](figma-v2-coral-snapshot.json), and the "before" screenshots are in [v3-before/](v3-before/). Better Design review is excluded. No blur or frosted effects.

## 1. Palette

| Role | Name | Hex | Use |
|---|---|---|---|
| Primary | Vibrant Royal Blue | `#1565FF` | Headers, hero tile, primary buttons, active tabs, links |
| Secondary | Electric Lime | `#A3F533` | Highlight badges, active nav pill, action accents. Always a fill. |
| Surface | Pure White | `#FFFFFF` | Cards, tiles, sheets, containers |
| Background | Soft Cool Gray | `#F6F8FA` | Screen background |
| Calm | Soft Ice Blue | `#EAF2FF` | Icon containers, info banners |
| Ink | Charcoal Black | `#111827` | Headings, key values (HSS, stok, kg, Rp, counts) |
| Muted | Muted Slate Gray | `#6B7280` | Subtitles, labels, inactive icons |
| Warm | Warm Amber | `#F59E0B` | Warning and low-stock fill or icon. Never text. |

HidroSense has no ratings or prices. The reference's "star" maps to warning and low stock (Menipis). Its "price" maps to key quantities and Rp values.

### Supporting tones (needed for states; not brand colours)

| Name | Hex | Use |
|---|---|---|
| Blue pressed | `#0F4FD6` | Primary button pressed |
| Blue deep | `#0B4FD1` | Blue text on ice blue, pressed border, info text |
| Blue lip | `#0B3FAE` | Button lip shadow |
| Lime pressed | `#8EDB22` | Lime control pressed |
| Slate strong | `#4B5563` | Secondary text on ice blue or on disabled fill |
| Slate border | `#7A8494` | Strong border, input outline (3:1 on white, gray and ice) |
| Gray 200 | `#E5E8EC` | Disabled fill, soft divider |
| Success | `#1F7A3D` on `#E3F5E1` | Status success. It is dark green, so it never reads as lime. |
| Warning text | `#8A5200` on `#FFF1CC` | Status warning text |
| Error | `#B3261E` on `#FDE7E4` | Status error, destructive button |

Status is never colour alone. Each status shows an icon plus a label. Lime and amber never mean success or error.

## 2. Contrast (measured, WCAG 2.x)

Measured by script on 2026-11-16. The text minimum is 4.5:1; 3:1 applies to bold text of 18.66pt or larger, to icons and to UI edges.

| Foreground on background | Ratio | Verdict |
|---|---|---|
| White on Royal Blue | 4.84 | Text OK |
| White on Blue pressed | 6.75 | Text OK |
| Charcoal on Lime | 13.23 | Text OK. The only text allowed on lime. |
| Charcoal on Lime pressed | 10.40 | Text OK |
| Charcoal on Amber | 8.26 | Text OK (badge fill) |
| Charcoal on White / Gray / Ice | 17.74 / 16.66 / 15.75 | Text OK |
| Royal Blue on White | 4.84 | Text OK (links) |
| Royal Blue on Gray | 4.55 | Text OK, small margin |
| Royal Blue on Ice | 4.30 | **Not used for text.** Icons and graphics only (3:1 OK). |
| Blue deep on Ice | 6.11 | Text OK. Use this for blue text on ice. |
| Slate on White | 4.83 | Text OK |
| Slate on Gray | 4.54 | Text OK, small margin |
| Slate on Ice | 4.29 | **Not used for text.** Use Slate strong (6.71). |
| Slate on Gray 200 | 3.93 | Disabled text only (WCAG exempt). Prefer Slate strong (6.15). |
| Lime on White | 1.34 | **Not used** (no lime icon or text on white) |
| Lime on Gray | 1.26 | **Not used** |
| Lime on Royal Blue | 3.61 | Graphics only (badge dot, icon accent on the hero) |
| Lime on Blue pressed | 5.04 | Graphics only |
| Amber on White | 2.15 | **Not used** as text or a lone icon. Fill or icon only next to a label. |
| Amber on Gray | 2.02 | **Not used** |
| Slate border on White / Gray / Ice | 3.78 / 3.55 / 3.36 | UI edge OK |
| Success on White / on its tint | 5.37 / 4.71 | Text OK |
| Warning text on White / on its tint | 6.39 / 5.74 | Text OK |
| Error on White / on its tint | 6.54 / 5.52 | Text OK |
| White on Error | 6.54 | Text OK (destructive button) |

Rule: a pair not in this table is measured before use and added here.

## 3. Token map (Phase 1)

Primitive variables are renamed and revalued in place. Their ids stay, so every alias and binding keeps working. No new primitives are needed.

| Primitive id | v2 name and value | v3 name and value |
|---|---|---|
| `1:14` | ink/900 `#2b2430` | charcoal/900 `#111827` |
| `1:15` | ink/600 `#5b5463` | slate/600 `#4B5563` |
| `1:16` | ink/500 `#6b6472` | slate/500 `#6B7280` |
| `1:17` | neutral/strong `#8c8494` | slate/400 `#7A8494` |
| `1:18` | neutral/soft `#efe6df` | gray/200 `#E5E8EC` |
| `1:19` | cream/50 `#fff8f2` | gray/50 `#F6F8FA` |
| `1:20` | white | white (unchanged) |
| `1:21` | coral/100 `#ffe9dc` | blue/50 `#EAF2FF` |
| `1:22` | coral/400 `#ff8a4c` | blue/600 `#0F4FD6` |
| `1:23` | coral/500 `#f26a2e` | blue/500 `#1565FF` |
| `1:24` | coral/700 `#c2410c` | blue/700 `#0B4FD1` |
| `1:25` | coral/800 `#b23a0a` | blue/800 `#0B3FAE` |
| `1:26` to `1:29` | green/100, 300, 500, 700 | unchanged (success and plant deco) |
| `1:30` | sun/400 `#ffc93c` | amber/500 `#F59E0B` |
| `1:31`, `1:32` | amber/100, amber/800 | unchanged |
| `1:33`, `1:34` | red/100, red/700 | unchanged |
| `1:35` | blue/100 `#e1effc` | lime/400 `#A3F533` |
| `1:36` | blue/700 `#1d5fa8` | lime/500 `#8EDB22` |

Semantic aliases (Color collection, Light mode):

| Token | v3 alias | Note |
|---|---|---|
| bg/app | gray/50 | Screen background |
| bg/card | white | |
| bg/hero | blue/500 | Was coral/400 |
| bg/disabled | gray/200 | |
| bg/inverse | charcoal/900 | Toast |
| text/primary | charcoal/900 | |
| text/secondary | slate/500 | Was ink/600 |
| text/tertiary | slate/500 | No lighter tone passes 4.5:1 |
| text/accent | blue/500 | Links, on white or gray only |
| text/on-primary | white | Was ink/900 |
| text/on-secondary | white | Unchanged. In v2 it means "text on a dark fill" (toast, destructive button, selected segment), not "text on secondary". |
| text/on-accent (new, `98:610`) | charcoal/900 | Text and glyphs on lime (secondary button, active tab pill) |
| text/on-muted (new, `98:611`) | slate/600 | Secondary text on gray/200 or ice-blue fills (6.15 and 6.71) |
| data/fill (new, `98:11952`) | blue/500 | Chart bars, CycleRing arc, progress fill, filled HoleGrid holes. Scopes: frame, shape and stroke. |
| text/success, warning, error | unchanged | |
| text/info | blue/700 | Blue text on ice |
| action/primary | blue/500 | |
| action/primary-pressed | blue/600 | |
| action/secondary | lime/400 | Was green/700 |
| action/destructive | red/700 | unchanged |
| border/strong | slate/400 | |
| border/soft | gray/200 | |
| border/focus | blue/500 | HIG focus colour |
| border/pressed | blue/700 | |
| tint/coral, renamed tint/brand | blue/50 | Icon containers |
| tint/info | blue/50 | Info banners |
| tint/success, warning, error | unchanged | |
| deco/sun | amber/500 | Weather sun |
| deco/leaf | lime/400 | Plant highlight |
| deco/leaf-deep | green/500 | Plant body |

Done in Phase 1 (2026-11-16):
- Shadow/Button Lip is bound to blue/800. Shadow/Card is charcoal at 8%.
- Space has radius/12 (`97:610`) and radius/20 (`97:611`).
- Data marks never use lime: lime on white is 1.34:1 and fails the 3:1 graphics minimum.
- The TabBar active pill is lime, with an on-accent glyph and label.
- The welcome heroes (1.2, 1.4) use bg/hero. deco/sun is amber now and must not fill large areas.
- Illustrations: the first hue-shift pass made cats, the sun and the greenhouse lime. It was replaced by the context mapping in section 8a.

## 4. Type (Poppins, HIG hierarchy)

The HIG ratios are mapped onto Poppins. Poppins is wider than SF Pro, so the sizes stay one step tighter where it would reflow.

| Style | v2 | v3 | HIG role |
|---|---|---|---|
| Type/Display | 32/40 SemiBold | 34/40 Bold | Large Title (top-level screens) |
| Type/H1 | 24/32 SemiBold | 28/36 Bold | Title 1. Fallback 24/32 Bold if the overflow audit fails. |
| Type/H2 | 20/28 Medium | 20/28 SemiBold | Title 3 |
| Type/Body | 16/24 Regular | 16/24 Regular | Callout. Kept at 16, not 17 (decision 2026-11-16). |
| Type/Body Strong | 16/24 Medium | 16/24 SemiBold | Headline |
| Type/Button | 16/24 SemiBold | 16/24 SemiBold | |
| Type/Label | 14/20 Medium | 14/20 Medium | Subhead |
| Type/Label Strong | 14/20 SemiBold | 14/20 SemiBold | |
| Type/Caption | 12/16 Regular | 12/16 Regular | Footnote and caption floor |
| Type/Value (new) | none | 28/36 Bold | Key figure in a tile or card |
| Type/Value Large (new) | none | 34/40 Bold | One hero figure per screen |

Rules:
- Primary information is bold. That means the value people came to read: HSS, stok, kg, Rp, hole counts, harvest date.
- Values are Charcoal on white, or White on the blue hero.
- Labels use Muted Slate, Type/Label or Caption.
- Use at most 3 type sizes per screen, excluding the status bar and tab bar.
- Nothing is smaller than 12pt.
- Controls hug their text with a minimum height, so 1.3x text still fits.

## 5. Shape and corner

- Use continuous corners: `cornerSmoothing = 0.6` on cards, tiles, buttons, sheets and icon containers.
- Radius scale: 12, 16, 20, 24, 32, pill. Nothing else.
- Cards are 24. Bento tiles are 20 or 24. The hero tile and sheets are 32 at the top. Chips, buttons, the tab-bar active pill and search are pill. Icon containers are 16, or a circle for avatars and status dots.
- Corners are concentric: inner radius = outer radius minus padding. For example, a 24 card with 8 padding holds a 16 inner tile.
- Use one shape family per screen. Do not mix sharp and round.

## 6. Layout and bento

- Frames are 390x844. Margins are 24. Use the 8pt grid. Default gap is 16.
- Bento grid: 2 columns of 163 with a 16 gap.
  - 1x1 tile: 163x163
  - 2x1 tile: 342x163
  - 1x2 tile: 163x342
  - Wide strip: 342x88
- Hub, detail and summary screens have one hero in Royal Blue (Beranda Hero, GridCard, SummaryCard, Profil, Cek hama). It has white text and at most one lime accent. Every other tile is white with Shadow/Card.
- Lists and forms have no hero.
- Tile anatomy: an ice-blue icon container top-left (40 to 48), then a bold value, then a short label. At most 3 text lines. The tap target is the whole tile.
- Reading order is the hero, then tiles left to right and top to bottom. A creative layout must still read in one pass.
- The primary action stays in the thumb zone: y=658 on tab screens (above the tab bar at y=738), y=746 elsewhere. Toast at y=586 on tab screens and y=674 elsewhere.
- Actions is an opaque bg/app footer that reaches the tab bar or the bottom edge, so scrolled content never collides with the CTA. Rows, tiles and controls must survive 1.3x text and 360pt width (see page "QA v3").
- Charts use ChartBar `122:15376`: one series, data/fill, the value written above each bar.
- Lists stay lists. Use bento for summaries and hubs (Beranda, Stok summary, Detail meja, Rawat hub). Do not use it for long records.
- A helper text that explains a disabled CTA sits in Actions, directly above the button. A toast sits 16 above Actions (or above the tab bar), never over text.
- Summary cards put the value in Type/Value and the label in Type/Label. Never the reverse.
- List-row lead icons name the entity:
  - Benih: sprout. Nutrisi: droplet. Media: layers. Obat and treatment: care.
  - Buyer: user. Damage: warning on tint/warning. Sales: chart. Sync: sync. Stock: box.
- Lists of 2 or more rows use one inset grouped card ("Grup daftar": white, radius 24, Shadow/Card, 1pt border/soft dividers inset 76). Inside an existing card, the group has no fill or shadow.
- BentoTile `114:1127` is the 1x1 tile component (Tone=Default or Warning; Value, Label and Icon properties).

## 7. Colour play

- Blue is the energy: the hero, the primary action and the active tab.
- Lime is the spark: one accent cluster per screen, such as a badge, the active nav pill or a highlight chip. Lime on a blue hero is the signature pairing.
- Ice blue is the calm: icon containers and info banners.
- Amber appears only where something needs attention (Menipis, Habis, a weather warning).
- White space beats decoration. Use no gradients, except the existing hero arcs recoloured.

## 8. Icons

- Use a Headspace-style duotone family: friendly, joyful, rounded. A 2pt round outline plus a "Tone" fill layer (same colour, 30% node opacity) behind closed bodies. When you recolour an instance, set the outline stroke and the Tone fill to the same variable.
- Icons are 2-tone filled: a blue base with an ice-blue or lime accent, and soft rounded ends.
- Sizes are 24, 32 and 48. Icons sit on 16-radius ice-blue containers.
- Icon states:
  - Default: blue on ice.
  - Selected: white glyph on a blue fill, or a charcoal glyph on lime in the tab bar.
  - Disabled: slate.
- Use one family across the whole file. No mixing with line icons.
- Draw icons as vectors with the Plugin API. SVG paths use M and L, plus C or Q curves only. No H or V commands.
- AI generation (`generate_vector_illustration`) is not used unless the user approves the credit cost.
- Recolour the cat illustrations by editing their vector fills in place. Never use `rescale()`. Cat eyes never get a dark outline.

## 8a. Colour by context (mascot, illustration, icon)

Lime is never the main colour of a character, a building, the sky or an icon. It only marks something alive and fresh (a leaf highlight, a sprout) or the one active accent on a screen (active tab, highlight badge). Blue carries the objects people use. Warm white carries the mascot. Each thing keeps its natural colour, so the art reads at a glance.

| Context | Colour | Hex |
|---|---|---|
| Mascot cat: body | Warm white | `#FFFDF8`, shade `#F7F3EA`, `#ECE6D8` |
| Mascot cat: stripes, ears inside | Royal blue family | `#1565FF`, `#3F7CFF` |
| Mascot cat: eyes | Leaf green, navy pupil | `#7CCB3E`, `#1B2A4A` |
| Mascot cat: nose, cheeks | Pink (kept) | `#E86866`, `#F69786` |
| Outlines, dark details | Navy ink | `#1B2A4A`, `#111A33` |
| Objects (greenhouse frame, table, tray, bottles, crates, seed packs) | Royal blue family | `#0B4FD1`, `#1565FF`, `#3F7CFF`, `#6E9BFF`, `#9DBCFF` |
| Glass, ground, shadows, sky shapes | Ice | `#AEC8FF`, `#C6D9FF`, `#DCE8FF`, `#EEF4FF` |
| Leaves, lettuce | Leaf green | `#3B8F2E`, `#5BB236`, `#7CCB3E` |
| Leaf highlights, sprouts, seed-pack accents | Lime (accent only) | `#B8EE6A`, `#C8F57A`, `#A3F533` |
| Sun | Amber and yellow | `#F5A623`, `#FFC94D`, `#FFD978` |
| Rockwool cubes, paper, cardboard | Sand | `#B08F55`, `#C9A96B`, `#DCC48F`, `#E6D3A3`, `#EFE3C0` |
| Coins | Amber | `#F5A623` |
| UI icon, default | `color/icon/default` (`107:610`) = blue/500 on `tint/brand` ice container | |
| UI icon, inactive or archived | `color/icon/muted` (`107:611`) = slate/500 | |
| UI icon, on a blue fill | white (`text/on-primary`) | |
| UI icon, active tab | charcoal glyph on a lime pill (`text/on-accent` on `action/secondary`) | |
| Status icon (badge, toast, timeline done) | Its status colour (success, warning, error, info), always with a label | |

Illustrations use raw hex (the allowed exception). They were mapped from the v2 originals, recovered from the named version "v2 coral, before Royal", by colour role:
- Teal became blue.
- Pale mint became ice.
- Cream became warm white.
- Green became leaf, with lime highlights.
- Olive became sand.
- The sun's three yellow-greens became amber.
- Pinks were kept.

The mapping script is [tools/illustration-remap.js](tools/illustration-remap.js). Its input is version-snapshot JSON from `figma_get_file_at_version`. Re-run it from the originals; never on top of the previous result.

## 9. Apple HIG for mobile

- Follow the HIG principles: clarity, deference, depth. Content first, chrome quiet.
- Touch targets are at least 48 (the HIG minimum is 44).
- Respect safe areas: the status bar and the 34pt home indicator.
- Top-level tab screens use a large-title header (Type/Display). Pushed screens use a standard back with the title, plus an annotation for swipe back.
- Sheets have a grabber and a 32 top radius. Dialogs only for destructive or blocking choices.
- Tab bar: at most 5 items, labels always shown. The active item is a lime pill with a charcoal glyph and label. Inactive items are slate.
- Motion is spring-style, written as annotations only.
- Depth comes from Shadow/Card and layering. No blur.
- Light mode only.

## 10. Process rules

- Before any `use_figma` call, load `figma-use`, plus `figma-generate-design` for frames or `figma-generate-library` for page 00.
- Run one script at a time. Clone in one call and edit by id in the next.
- Never put raw hex in frames. Every fill, stroke and text colour is bound to a variable. Illustrations are the only exception.
- Audit after each page:
  - Poppins only, nothing under 12pt, all text styled
  - no unbound fills, no target under 48, no overflow
  - contrast pairs only from section 2
- Gates, each waiting for the user:
  - Phase 0: this document
  - Phase 2: the icon sheet
  - Phase 3: the 4-screen pilot (2.1, 4.1, 6.11, 9.1)
- Phase 4 rollout starts only after the pilot is approved.
- Never touch the old file `jw1JWyJXFrY85MW2wXYkGh`. Never change flows, frame numbers, notes or copy.

## 11. Logo
The HidroSense logo is C10 "Telinga tetes": a warm-white cat with a lime drop ear and charcoal eyes, on a Royal Blue tile (the charcoal tile is for dark backgrounds). The component is Logo/Mark `134:1196` on page "Logo v3". The tile radius is 22.5% of its width. Rules and files: [logo/usage.md](logo/usage.md).
