# T-029 — Site Flutter column: per-row single-view iframes (glyphs + alignment)

**Milestone:** M7 (site)  **Status:** done  **Depends on:** T-024, T-028

## Problem (user-reported)
"A lot of the examples are still misaligned or missing glyphs in flutter." Two distinct
defects in the site's `katex_flutter` column:
1. **Missing glyphs** — in the CanvasKit *multi-view* embedding, `⟨⟩ ⌈⌉ ⌊⌋`, `\oint`,
   `\bigcup`, `\cdot` rendered as tofu boxes (per-view font-atlas bug) while `a/b/x/y` were fine.
2. **Misalignment** — the interim fix (one full-height single-view iframe rendering the whole
   gallery) drifted out of vertical alignment with the DOM list (independent layout engines):
   by the "Delimiters" section the iframe was already showing "Fonts".

## Fix — per-row single-view iframes
Each comparison row's 4th cell is its **own** lazy `<iframe src="flutter/index.html?tex=…&
display=…&fontSize=22">`. `flutter_host/lib/main.dart` is now a **single-expression** app:
`runApp` reading `tex`/`display`/`fontSize` from `Uri.base.queryParameters` and rendering one
centered `Math`. The iframe is absolutely positioned to fill its grid cell.

Why this fixes both:
- **single-view** engine → every glyph renders (no multi-view atlas bug);
- iframe **is** the grid cell → per-row alignment by construction (no height-matching);
- loads `flutter/index.html` with `<base href="/flutter/">` → bundled `KaTeX_*` fonts resolve;
- `loading="lazy"` → only near-viewport engines boot (keeps it light despite ~68 rows).

Site layout reworked to a true 4-column grid (`TeX source | KaTeX JS | katex Dart SVG |
katex_flutter`) in `app.dart` + `comparison_row.dart`; deleted `flutter_host/lib/examples.dart`
(expressions now arrive via the URL). README updated.

## Resolution / verification
Built + served; headless-Chrome screenshots confirm:
- Previously-missing glyphs now render in the Flutter column: `\oint`, `\bigcup`, `\cdot`,
  `⟨x,y⟩`, `⌈x⌉+⌊y⌋`, nested `([{⟨x⟩}])`, accents/`\vec`.
- Every Flutter cell is aligned in its own row across all sections (Fractions → Delimiters →
  …) — no drift.
`dart analyze` (site) + `flutter analyze` (flutter_host) clean; `jaspr build` + `flutter build
web` succeed. Generated `site/web/flutter/` stays gitignored.

## Note (out of scope)
The Dart-SVG column still renders larger than the JS/Flutter columns (fixed 44u/em vs CSS
sizing) — a separate cosmetic normalization, not part of this fix.
