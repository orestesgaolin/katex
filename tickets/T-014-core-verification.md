# T-014 — Core verification: dimension + SVG goldens

**Milestone:** M4  **Status:** review  **Depends on:** T-002, T-011, T-012

## Goal
Hold the core renderer to **original KaTeX** output, numerically and visually.

## Scope
- `test/oracle_dimension_test.dart` — for each gallery entry, compare our root (and key
  sub-box) height/depth/width against `reference/fixtures/metrics/<id>.json` within a
  documented tolerance (e.g. ≤2% or ≤0.5px equivalent). Report worst offenders.
- `test/svg_golden_test.dart` — rasterize our `renderToSvg` output to PNG (via resvg CLI
  if available, else the puppeteer harness in `reference/`), pixel-diff against
  `reference/fixtures/png/<id>.png` (pixelmatch-style) with a per-pixel + total-diff
  threshold; write diff images to `test/.diffs/` on failure.
- Document tolerances and the rasterizer used in a test header comment.

## Acceptance criteria
- Dimension test runs over the whole gallery; passing entries are within tolerance and
  failures clearly name the expression + the mismatched dimension.
- SVG golden test runs over the gallery and reports pass/fail per expression with diff
  artifacts on failure.
- A summary of pass-rate is printed; known-failing expressions (if any) are listed as
  follow-up tickets rather than silently skipped.
