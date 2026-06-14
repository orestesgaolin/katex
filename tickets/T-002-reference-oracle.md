# T-002 — Node reference oracle + gallery + fixtures

**Milestone:** M1  **Status:** review  **Depends on:** T-001

## Goal
A Node harness that renders the shared test gallery with **original KaTeX** and emits the
ground-truth fixtures every Dart test is measured against.

## Scope
- `reference/gallery.json` — array of `{id, tex, displayMode}` covering the MVP grammar:
  `\frac{a}{b}`, `x^2`, `x_i`, `x^2_i`, `\sqrt{x}`, `\sqrt[3]{x}`, `\sum_{i=0}^n i`,
  `\int_0^1`, `\prod`, `\left(\frac{a}{b}\right)`, `\hat{x}`, `\bar{x}`, `\vec{x}`,
  `\tilde{x}`, `\mathbf{x}`, `\mathbb{R}`, `\mathcal{L}`, `\overline{x}`, `\underline{x}`,
  `\alpha+\beta`, `a \cdot b`, `\text{hi}`, `pmatrix`, `bmatrix`, `aligned`, `cases`.
- `reference/generate_fixtures.mjs` — uses KaTeX `renderToString` in a headless browser
  (puppeteer) to: (a) screenshot each expression at a fixed width/DPR → `fixtures/png/<id>.png`,
  and (b) walk KaTeX's internal box output to dump height/depth/width of the root and key
  sub-boxes → `fixtures/metrics/<id>.json`.
- `reference/pin.json` records the resolved KaTeX version.
- A small `metrics` extraction approach documented in a comment (KaTeX exposes
  `__renderToDomTree`-style internals; if not, derive metrics from the rendered DOM's
  computed heights as a documented fallback).

## Acceptance criteria
- `npm install` in `reference/` succeeds; `pin.json` shows the KaTeX version.
- `node generate_fixtures.mjs` produces a PNG and a metrics JSON for every gallery entry.
- Fixtures are deterministic across two runs (same bytes for metrics; PNGs visually identical).
- README note in `reference/` explains how to regenerate.
