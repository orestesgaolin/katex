# T-036 — Fix remaining approximations + residual Flutter clip/offset

**Milestone:** M6/M7  **Status:** in-progress  **Depends on:** T-034, T-035

## Real renderer bugs
- **RC-arrow** — `\overrightarrow{AB}` renders a plain bar, **no arrowhead** (the stretchy-arrow
  SvgPathNode uses a `slice` aspect that crops the arrowhead off the right). Fix
  `\overrightarrow`/`\overleftarrow`/`\overleftrightarrow` to show the full arrow (shaft + head)
  scaled to base width, in BOTH SVG and Flutter. [accent_builders, svg_geometry, svg_serializer,
  box_painter]
- **RC-array** — `\begin{array}{c|c} a&b \\ \hline c&d \end{array}`: the `\hline` rule and the `|`
  column separator are not drawn. Port KaTeX array hlines + column-border rules (RuleNodes).
  [array_builder]

## Stale APPROX tags (feature works now; verify + un-tag in examples.dart — orchestrator)
- `oint` (`\oint_C \vec{F}\cdot d\vec{r}`), `sized-delims` (Size1–4 graduated — verified correct),
  `thin-space` (`\,\;\quad\qquad` — fixed T-031), `gaussian-cdf` (`\Phi…\int…e^{-t^2/2}\,dt` —
  fixed T-031/T-033). Verify each matches KaTeX, then remove `approx: true`. Un-tag `overrightarrow`
  + `array` once RC-arrow/RC-array land.

## Flutter site
- **RC-clip2** — deeply-nested `\cfrac` chains (the `\cfrac{1}{1+\cfrac{1}{1+x}}` and golden-ratio)
  are STILL clipped at the bottom in the Flutter column, and the Flutter render is **offset toward
  the top**. The per-view `ViewConstraints` height (math_metrics) is correct for moderate heights
  but tall cfrac still clips + the content isn't vertically centered in the view. Fix the embed
  view sizing/centering so tall expressions show fully and aren't top-offset. [site: math_metrics,
  math_cell, flutter_cell] — verify in a real browser incl. the cfrac rows.

## Acceptance
RC-arrow/RC-array: render + rasterize + compare KaTeX (proof PNGs); oracle 26/26; tests green.
Stale tags removed only after visual confirmation. Flutter clip/offset verified in a real browser.
