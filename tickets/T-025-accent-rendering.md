# T-025 — Fix accent rendering (\hat \bar \vec \tilde \widehat …)

**Milestone:** M6 (correctness)  **Status:** review  **Depends on:** T-011, T-022

## Problem (user-reported + side-by-side confirmed)
Accents are broadly broken in the Dart renderer. Side-by-side vs KaTeX JS (same size):
- `\hat{x}` — KaTeX: a circumflex centered above `x`. Ours: a tiny grave-like mark mispositioned
  to the upper-LEFT (wrong glyph + wrong position).
- `\vec{x}` — KaTeX: a right-arrow above `x`. Ours: **no arrow at all** (glyph missing — likely
  the combining/arrow codepoint isn't in the embedded font, or `\vec` should use the stretchy
  SVG "vec" path which it currently doesn't).
- Likely `\bar`, `\tilde`, `\widehat`, `\widetilde`, `\overrightarrow` similarly wrong.

## Root cause to investigate
`lib/src/build/builders/accent_builders.dart` vs KaTeX `src/functions/accent.ts`:
- Accent glyph selection: KaTeX picks the accent symbol (e.g. `\hat`→U+005E, `\bar`→U+00AF,
  `\tilde`→U+007E from KaTeX_Main) and, for **stretchy** accents (`\vec`, `\widehat`,
  `\widetilde`, `\overrightarrow`, …), uses an SVG path via `stretchy.ts`/`svgGeometry.ts`
  (the SvgPathNode infrastructure added in T-022) sized to the base width.
- Positioning: the accent is placed in a vlist over the base, horizontally centered over the
  base accounting for the base's italic **skew** (`accent` shifts by `skew`), with the correct
  vertical clearance; `\vec` etc. stretch to the base width.

## Acceptance criteria
- Side-by-side (KaTeX JS vs our `renderToSvg`, same font size) for `\hat{x}`, `\bar{x}`,
  `\vec{x}`, `\tilde{x}`, `\widehat{abc}`, `\overline{x}` is a close visual match: correct glyph,
  centered over the base, arrow present for `\vec`. Attach before/after proof screenshots.
- `\vec\nabla \cdot E = \rho` (the user's Maxwell example) renders arrows correctly.
- Oracle dimension gate stays 26/26 (accent root dims still match `reference/fixtures/metrics`).
- Flutter painter draws the same accents correctly (the painter already handles GlyphNode +
  SvgPathNode; verify accents paint).
- Full Dart + Flutter suites green.
