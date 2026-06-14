# T-031 — Renderer correctness batch (site review bug list)

**Milestone:** M6 (correctness)  **Status:** in-progress  **Depends on:** T-011, T-022, T-025

User reviewed the comparison site and reported 15 rendering bugs. Reproduced + grouped by root
cause (each verified by rendering + rasterizing the failing expression):

## RC-A — `\TextOrMath` undefined → spacing/`\Phi` errors  [→ A]
`\,` `\;` `\quad` `\qquad` expand to `\tmspace{...}` which uses `\TextOrMath`, an **undefined
control sequence** (deferred in T-007). Breaks `a\,b\;c\quad d\qquad e` AND
`\Phi(x)=\frac{1}{\sqrt{2\pi}}\int_{-\infty}^x e^{-t^2/2}\,dt` (has `\,dt`).
Fix: port the `\TextOrMath` builtin macro.

## RC-B — `\nabla` renders blank in SVG  [→ G]
The `∇` char IS emitted but in a font with no glyph (likely Math-Italic instead of Main). KaTeX
`\nabla` is mathord, font **main** (upright). Fix font selection so main-font mathords use Main.
(Affects the Maxwell equation.)

## RC-C — VList children not horizontally centered  [→ G]
Fraction numerator/denominator and big-operator limits are LEFT-aligned, not centered.
Confirmed: `\sum`/`\bigcup`/`\prod` top/bottom limits off-center; `\frac{...}{2a}` denominator
off-center; `\frac{1}{1+\frac{1}{x}}` numerator off-center. Fix: center numer/denom in
genfrac_builder and limits in op_builders (within the vlist width). Do NOT globally change VList
semantics (accents/sqrt are hand-built — keep them working).

## RC-D — stretchy accents drawn over the base, not above  [→ D]
`\widehat{xyz}` / `\widetilde{xyz}` / `\overrightarrow{AB}`: the SvgPathNode accent is drawn at
the baseline THROUGH the letters instead of raised above. Fix accent vertical placement for the
stretchy (SvgPathNode) accents in accent_builders.dart.

## RC-E — SVG viewBox clips content  [→ G]
`\mathcal{ABCL}` (right + top/bottom clipped), `\mathsf`, `x+\scriptstyle y+z`, the golden-ratio
`\cfrac` (bottom clip), and the quadratic's right edge. Oracle box dims are correct, so the SVG
viewBox derived from them clips glyph ink that extends past the metric box. Fix: serializer
viewBox should encompass actual content (pad for ink overflow / italic correction) in
svg_serializer.dart.

## RC-F — `f''(x)` primes sit too low  [→ F]
Primes render to the right of `f` but at mid-height, not raised as a proper superscript. Fix
prime/supsub vertical placement in supsub_builder.dart. (Milder than the rest.)

## Acceptance
Each RC: render the listed expressions, rasterize (rsvg-convert), compare to KaTeX — close match,
attach before/after to /tmp/cmp. Oracle dimension gate stays **26/26**; full Dart + Flutter
suites green. Both SVG and (where builder-level) Flutter columns improve on the site.
