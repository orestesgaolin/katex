# T-033 — Render refinements (site review #2) + live editor feature

**Milestone:** M6 / M7  **Status:** in-progress  **Depends on:** T-031

## Renderer issues (affect SVG + Flutter — `packages/katex`)

### RC-1 — superscript/subscript sizing + horizontal overlap  [supsub_builder.dart]
- `b^2`: the `2` overlaps `b` and looks too big.
- `e^{-t^2/2}`: the FIRST-level exponent shrinks correctly, but the NESTED `t^2` superscript does
  NOT shrink to scriptscript — its `2` is the same size as the script-level `t`.
- `f''`/`f'` primes still slightly off.
Likely: scripts must be built via `options.havingStyle(style.sup()/sub())` so nesting advances
(text→script→scriptscript); and the superscript x-position must include the base's **italic
correction** (+ scriptspace) so it doesn't overlap a slanted base. Port from KaTeX
`functions/supsub.ts` + `buildHTML` sup/sub layout. Verify `b^2`, `e^{-t^2/2}`, `x^2_i`, `f''`.

### RC-2 — integral bounds stacked instead of to the side  [op_builders.dart]
`\int_0^1 x^2 dx` (display): our renderer stacks `1` above and `0` below the ∫ (limits style).
KaTeX `\int` is **nolimits** — bounds go to the upper-right (sup) / lower-right (sub), with the
big-operator italic/skew correction so they don't overlap the slanted ∫. Fix op/integral handling
so `\int` (and `\oint` etc.) use side sup/sub. Verify `\int_0^1`, `\int_{-\infty}^x` (bigger
bounds), `\oint`.

### RC-3 — sqrt index slightly off  [sqrt_builder.dart]
`\sqrt[3]{x}` index still slightly off vs KaTeX; verify with bigger indices (`\sqrt[10]{x}`,
`\sqrt[123]{x}`). Refine the index placement (KaTeX `sqrt.ts` `\rootBox`).

### RC-4 — `\vec{F}` arrow off (esp. Flutter)  [accent_builders.dart + katex_flutter box_painter.dart]
`\vec{F}` arrow position is off — more in Flutter than SVG (so the SvgPathNode accent placement
and/or the Flutter painter's SvgPathNode handling differ). Align both to KaTeX; verify SVG and
Flutter match.

## Site (`site/`)

### SITE-1 — SVG column renders bigger than KaTeX/Flutter
The `katex Dart SVG` column is visibly larger than the JS + Flutter columns. Scale the inlined SVG
to the same em size as the others (e.g. render at a matching font size, or CSS-scale the SVG cell)
so all three columns are the same scale.

### SITE-2 (feature) — live editor at the top
Add a text input at the top of the page to type a LaTeX expression and see it rendered live —
**at minimum the katex_flutter output**, ideally all three (KaTeX JS via `katex.render`; Flutter
via a `FlutterEmbedView` that rebuilds on input; Dart SVG via client-side `renderToSvg` if
feasible). Debounce input; show parse errors gracefully.

## Acceptance
Each RC: render + rasterize + compare to KaTeX (proof PNGs), oracle gate 26/26, Dart+Flutter tests
green. Site: `jaspr serve` works; SVG column matches scale; editor renders live in a real browser.
