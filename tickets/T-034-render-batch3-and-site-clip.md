# T-034 — Render batch #3 (integral indices, sqrt clearance) + site Flutter clipping

**Milestone:** M6/M7  **Status:** in-progress  **Depends on:** T-033

## Renderer (packages/katex — SVG + Flutter)

### RC-a — integral indices misplaced  [op_builders.dart]
After T-033 made `\int` nolimits (side sup/sub), the bounds sit too FAR right of the `∫` and too
vertically spread (detached). KaTeX tucks `\int_0^1`'s `1` to the upper-right and `0` to the
lower-right close to the sign, with the integral's italic-correction skew (sup shifted right, sub
left). Reproduce: `\int_0^1 x^2 dx`, `\int_{-\infty}^x`. Compare to KaTeX (`__renderToDomTree` /
DOM positions) and match the sup/sub horizontal + vertical offsets. (Oracle int-limits height/depth
already match 0.000% — the bug is horizontal placement, not captured by that gate.)

### RC-b — sqrt lineClearance too small  [sqrt_builder.dart]
`\sqrt{\cfrac{\infty111}{1111+\cfrac{111111111}{111+x}}}`: the vinculum (top line) nearly touches
the radicand — the clearance gap above the content is too small for tall content. KaTeX uses
`lineClearance = ruleWidth + (φ?)` with a `theta`/`phi` based gap (rule 11: clearance grows in
display). Verify our `lineClearance`/`phi` against `sqrt.ts` and fix so the gap matches KaTeX for
both short (`\sqrt{x+1}`) and tall (the cfrac) radicands.

## Site (site/)

### SITE-clip — Flutter embeds clipped at the bottom (ALL cells)
Every `katex_flutter` cell on the site is clipped along the bottom (descenders / fraction
denominators cut). Likely the `FlutterEmbedView` host / `.flutter-cell` height excludes the math's
depth, or `overflow:hidden` + a too-short view. Fix the embed cell sizing so the full math
(height+depth) shows. Also: the site's embedded Flutter build is stale — rebuild so it picks up the
T-031/T-033 renderer fixes (then `f''`, `\times` etc. render correctly, as the isolated painter
already does).

### SITE-scale-flutter — `\times` (and column) bigger in Flutter than JS
Check the Flutter column's overall scale vs the KaTeX-JS column; if the embed renders larger,
match the MathCell font size to the JS column scale.

## Acceptance
RC-a/RC-b: render + rasterize + compare to KaTeX (proof PNGs); oracle 26/26; tests green.
Site: rebuilt, no bottom clipping, Flutter column scale matches JS — verified in a real browser
(headful Chrome on CDP 9222).
