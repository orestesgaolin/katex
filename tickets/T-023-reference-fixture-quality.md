# T-023 — Regenerate oracle fixtures at a crisp font size

**Milestone:** M4 (fix)  **Status:** in-progress  **Depends on:** T-002, T-014

## Problem (user-reported)
The reference PNGs in `reference/fixtures/png/` look low-resolution / "out of date" next to
real KaTeX in a browser. Root cause: the harness rendered at the browser-default 16px base
(KaTeX ~19px/em) at DPR 2, so e.g. `\frac{a}{b}` is only 28×70px — tiny and blocky. Rendering
the *same* KaTeX at a 48px base is crisp and correct (delimiters stretch properly, etc.).

This is purely a **visual fixture quality** issue. The metrics JSON comes from KaTeX's
`__renderToDomTree` (em-based, size-independent), so the dimension gate is unaffected.

## Scope
- `reference/generate_fixtures.mjs`: render at a larger, configurable base font size (e.g.
  `#host { font-size: 48px }`), keeping DPR (2) or bumping for crispness; everything else
  (metrics extraction, determinism, font loading) unchanged. Document the chosen size.
- Regenerate all 26 fixtures (`fixtures/png/*` crisper/larger; `fixtures/metrics/*` should be
  byte-identical since em-based — verify via git diff).
- Update `packages/katex/test/svg_golden_test.dart` alignment (the em→device-px zoom factor
  it uses to compare our SVG raster to the reference PNG) to match the new reference scale, so
  the SVG-golden comparison stays meaningful. Re-run and report the new pixel-diff ratios.

## Acceptance criteria
- Reference PNGs are visibly crisp/correct (spot-check `pmatrix`, `frac`, `sqrt`, `sum`).
- `reference/fixtures/metrics/*.json` unchanged (dimension gate still 26/26).
- `dart test` (incl. oracle dimension + svg golden) green; svg-golden zoom updated to the new
  reference scale; report before/after diff ratios honestly.
- No regression to the full Dart + Flutter suites.
