# T-037 — "Supported functions" reference subpage (mirror katex.org/docs/supported)

**Milestone:** M7 (site)  **Status:** review  **Depends on:** T-024

## Goal
A second page on the comparison site — a categorized **catalog of TeX commands/symbols**, mirroring
<https://katex.org/docs/supported>, showing for each entry how our port renders it and whether it's
supported. Turns the site into both a comparison demo AND a coverage reference.

## Data source
KaTeX's by-category doc: <https://raw.githubusercontent.com/KaTeX/KaTeX/main/docs/supported.md>
(~732 lines; categories: Accents, Delimiters, Environments, Letters & Unicode, Layout, Logic & Set
Theory, Macros, Operators [Big/Binary/Fractions/Math Operators/sqrt], Relations [Negated/Arrows],
Special Notation, Style/Color/Size/Font, Symbols & Punctuation, Units). Each row has the
command + an example (the `$…$` rendered cell / source column). Parse it into category → entries
`{name, exampleTex}`. (The alphabetical `support_table.md` is an alternate source.) Generate a Dart
data file from it (a small generator/script, committed output) — don't hand-copy hundreds of rows.

## Page design
- New Jaspr route `/supported` (add `jaspr_router` or jaspr's routing; keep `/` as the comparison
  page). A header nav linking the two pages.
- For each category → a table; per entry, columns: **command (code)** | **KaTeX JS** (client render,
  reuse `KatexJs`) | **katex Dart → SVG** (build-time `renderToSvg`, reuse `DartSvg`) | **status badge**.
  Status computed at build time by trying `renderToBox`/`renderToSvg`: ✓ renders · ✗ error/unsupported
  (catch ParseError) · optionally ≈ if it renders but is a known approximation.
- **No per-command Flutter** — hundreds of `FlutterEmbedView`s would exhaust the engine; Flutter
  stays on the main comparison page (and the live editor). Note this in the page.
- A summary line per category / overall (e.g. "Supported: X / Y").
- Reuse the existing SVG-scaling + issue-button helpers.

## Acceptance
- `cd site && jaspr build` produces `/` and `/supported`; `jaspr serve` serves both with working nav.
- The supported page lists the KaTeX categories with each command rendered by KaTeX-JS and our
  Dart-SVG, plus an honest support status (errors are caught and shown as unsupported, not crashes).
- Verified in a real browser (headful Chrome): both pages load, nav works, status badges reflect
  reality. `dart analyze` clean.
- Deployed by the existing Pages workflow (static multi-page build under `/katex/`).
