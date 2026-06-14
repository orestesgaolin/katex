# T-027 — Glyph skew offset misplaced slanted glyphs (prime overlap + SVG clipping)

**Milestone:** M6 (correctness)  **Status:** done  **Depends on:** T-012, T-016

## Problem (user-reported)
`f'` / `f''` primes overlapped the `f`, and slanted glyphs were clipped at the right edge of
the SVG viewBox. Same misalignment in the Flutter painter.

## Root cause (single bug, both renderers)
The SVG serializer and Flutter painter offset every glyph horizontally by its font **`skew`**.
For math-italic `f` that's 0.167em. `skew` is metadata the *builders* use for accent/supsub
placement (already baked into the box tree); it must NOT move the glyph in normal flow. The
bogus offset pushed slanted glyphs rightward into the following superscript (primes over the
`f`) and past the computed viewBox width (the clipping).

## Fix
Render glyphs at their box origin — drop the skew offset — in both `svg_serializer.dart` and
`box_painter.dart`. `skew` stays on the node for builders.

## Resolution
Fixed in commit `7b3a807` (fork agent). `f'`/`f''` now match KaTeX (primes upper-right, no
overlap, no clipping); oracle dimension gate held 26/26; 19 affected Flutter goldens
regenerated. Tests: katex 266, katex_flutter 59, both analyze clean. Confirmed in the site's
SVG column (`f''(x) + f'(x)` renders correctly).
