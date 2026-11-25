# HidroSense mascot logo: brief

Working brief for the logo and app icon, written 2026-11-16. Design only. Figma file `KZ7dODi36pWhEPumnRz7RG`, page "Logo v3". Palette and shape rules come from [../figma-v3-direction.md](../figma-v3-direction.md). Better Design review is excluded.

## 1. What we are making

| # | Deliverable | Spec |
|---|---|---|
| a | Mark | Full colour, the mascot head as the logo |
| b | App icon | 1024 x 1024 square master. Android adaptive: the mark sits inside the central 66% safe zone (676 px circle). iOS: full-bleed square, no corners (the system applies the mask) |
| c | Mono and reversed | Mono: charcoal `#111827` on white. Reversed: white on Royal Blue `#1565FF` |
| d | Small sizes | 16, 24, 32, 48 px, each hand-tuned (bigger eyes, wider gaps) |
| e | In-context mocks | Splash 1.1 and login 1.5, as clones on "Logo v3" |

Not now (on request only): a mascot expression set (happy, sleepy, alert, working) and a wordmark lockup in Poppins Bold.

## 2. The creature

We evolve the existing HidroSense cat. We do not invent a new animal. Today's cat is warm white with Royal Blue stripes, leaf-green eyes and a pink nose. It appears on 225 screens, so the logo must feel like the same character, simplified.

What the logo says: a friendly helper that grows fresh lettuce on water.

## 3. Shape grammar

- **Base:** one simple shape for the head, a soft blob, a rounded triangle or a rounded square. The head only, or head and shoulders.
- **Eyes:** two big, round, wide-set eyes cut as negative space. They may differ slightly in size, for character. Never give them a dark outline.
- **Signature:** one hydroponic feature, used once:
  - a leaf-shaped ear,
  - a sprout growing between the ears, or
  - a droplet-shaped tail or head tip.
- **Mouth:** a tiny smile, a cat "w", or none.
- **Asymmetry on purpose:** one ear taller, a slight head tilt, or a notch or bite in the silhouette.
- **Economy:** at most about 40 anchor points. Build from circles, triangles and rounded rectangles. Corner radii come only from 12, 16, 20, 24, 32 or pill.
- **Readability:** the silhouette alone, in one flat colour, must be recognisable at 16 px.

What we take from the references:
- From the white glyphs on black: one bold silhouette, negative-space eyes, one signature notch or tilt, 1 to 3 shapes.
- From the app tiles: a bold colour tile, the character filling 60 to 70% of the tile, big eyes, flat planes.
- What we leave out: gradients, glow, soft shadows and blur. HidroSense is flat.

## 4. Colour

Only these colours:

| Colour | Hex | Use in the logo |
|---|---|---|
| Royal Blue | `#1565FF` | Tile, or cat stripes and body |
| Electric Lime | `#A3F533` | Leaf or sprout accent, or tile. Never the whole cat |
| Warm white | `#FFFDF8` | Cat body |
| White | `#FFFFFF` | Eyes, reversed mark |
| Soft Ice Blue | `#EAF2FF` | Tile |
| Charcoal | `#111827` | Cat body (mono), eyes on light cats, tile |
| Leaf green | `#7CCB3E` | Eye colour (from the mascot), optional |
| Warm Amber | `#F59E0B` | A tiny accent only (for example a cheek) |

Rules:
- One dominant colour, one accent, plus white or charcoal for the eyes.
- Creature-to-tile contrast is at least 3:1, measured by script.
- Six colourway recipes to try in Phase 2:
  1. blue tile, warm-white cat, lime leaf
  2. lime tile, charcoal cat, white eyes
  3. ice tile, blue cat, lime leaf
  4. charcoal tile, white cat, lime accent
  5. white tile, blue cat, lime leaf
  6. blue tile, charcoal cat, lime leaf

## 5. Joy checklist

Score each concept yes or no. A pass is 5 or more of 7.

1. Upward energy: a tilt, a bounce or ears up.
2. Big round eyes.
3. Happy expression: a smile, happy closed eyes or a cheek.
4. Soft rounded corners, no sharp hostile points.
5. One surprising detail, such as the leaf ear or a bite.
6. Reads in one second.
7. Still the HidroSense cat (stripes, ears, proportions).

## 6. Tests

| Test | Pass |
|---|---|
| Silhouette at 16 px, one colour | Shape and eyes recognisable |
| Mono and reversed | Both read well; no detail lost |
| Contrast | Creature to tile at least 3:1 |
| Colour vision | Colourway checked with the dataviz validator (protan, deutan, tritan) |
| App icon in context | Reads on a light and a dark wallpaper mock |
| Construction | At most about 40 anchors; no blur, glow or dark eye outline |

## 7. Process and gates

| Phase | Work | Gate |
|---|---|---|
| 0 | This brief | You approve the brief |
| 1 | 12 silhouettes C01 to C12, white on charcoal, 240 px tiles, a 16 px row, joy scores | You pick 3 |
| 2 | 6 colourways per pick on a squircle (radius 32, smoothing 0.6), contrast measured | You pick 1 concept and 1 or 2 colourways |
| 3 | Clean construction: grid, Logo/Mark, AppIcon, Mono, Reversed, Sizes | none |
| 4 | Tests, mocks on 1.1 and 1.5, exports (SVG; PNG at 1024, 512, 192, 48), `usage.md` | You approve the final |
| 5 | Replace the Logo layers on 1.1, 1.5, 1.5a, 1.6 and 1.7 (ids, numbers and notes kept) | Only after Phase 4 approval |

Drawing method:
- Draw by hand with the Figma Plugin API: shapes, `createNodeFromSvg` and boolean operations.
- No H or V path commands. No `rescale()`.
- AI generation (`generate_vector_illustration`) only with your explicit OK, because it costs credits.
- Exports go to `yeonworks/hidro-scope/logo/`. No app code; nothing written outside `yeonworks/`.
