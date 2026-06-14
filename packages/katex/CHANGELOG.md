# Changelog

## 0.1.0

Initial release. A fresh pure-Dart port of [KaTeX](https://katex.org) — no Flutter dependency.

- Pipeline: Lexer → MacroExpander → Parser → parse-node AST → builders → backend-agnostic
  **box tree** → SVG.
- Public API: `renderToBox(tex, {options})` and `renderToSvg(tex, {options})` + `KatexOptions`.
- CLI: `dart run katex "\frac{a}{b}"` emits self-contained SVG.
- Coverage: fractions, sub/superscripts (+ primes), roots (+ index), big operators
  (`\sum`/`\int`/`\prod`/`\oint`/`\bigcup`) with limits/nolimits, `\left…\right` and sized
  delimiters, accents (incl. stretchy `\widehat`/`\vec`/`\overrightarrow`), fonts
  (`\mathbf`/`\mathbb`/`\mathcal`/…), colors, sizing/styling, spacing, and environments
  (`matrix`/`pmatrix`/`bmatrix`/`aligned`/`cases`).
- Verified against original KaTeX (pinned 0.17.0): box dimensions match the KaTeX oracle on the
  full test gallery within tolerance (most exactly).
- Vendored KaTeX fonts (SIL OFL) embedded in SVG output via `@font-face`.

Stretchy delimiters/accents beyond the Size4 glyph and the full macro set are incremental
follow-ups.
