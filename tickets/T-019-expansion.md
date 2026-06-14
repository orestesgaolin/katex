# T-019 — Expand command/environment coverage (ongoing)

**Milestone:** M6  **Status:** todo  **Depends on:** T-014, T-018

## Goal
Grow coverage toward full KaTeX after the MVP pipeline is green end-to-end.

## Scope (incremental, additive — no architecture change)
- Stretchy delimiters/accents via `SvgPathNode` + KaTeX `stretchy.js`/`svgGeometry.js`.
- More functions/environments: `\binom`, `\overbrace`/`\underbrace`, `array` with column
  specs, `cases`/`rcases`, `\xrightarrow`, `\boxed`, `\mathop`, more accents, more fonts.
- Full macro set from `macros.js`; `\def`/`\newcommand`.
- Glyph→path extraction fallback for non-browser SVG rasterizers.
- Optional MathML output.
- Expand `gallery.json` as coverage grows; each new batch gets its own ticket carved from
  this one and verified against the oracle.

## Acceptance criteria
- Each expansion batch: oracle dimension + golden pass for the newly covered expressions;
  no regression on previously-passing gallery entries.
