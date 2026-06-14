# T-003 — Font metrics generator + vendored fonts

**Milestone:** M1  **Status:** review  **Depends on:** T-001

## Goal
Faithful, regenerable Dart font-metrics tables + vendored KaTeX fonts with attribution.

## Scope
- `packages/katex/tool/gen_font_metrics.dart` — reads
  `reference/node_modules/katex/dist/contrib/.../fontMetricsData.js` (or
  `src/fontMetricsData.js`) and emits `lib/src/font/font_metrics_data.g.dart`: a
  `const Map<String, Map<int, List<double>>>` (family → charcode → `[depth, height,
  italic, skew, width]`).
- `lib/src/font/font_metrics.dart` — `FontMetrics` accessor + `getCharacterMetrics`,
  plus the global `fontMetrics` map (axis-height, rule-thickness, etc. from KaTeX's
  `fontMetrics.js` sigmas/xis).
- `lib/src/font/font_types.dart` — font family + variant enums.
- Vendor the `*.ttf` files from `reference/node_modules/katex/dist/fonts/` into
  `packages/katex/assets/fonts/` plus `OFL.txt`.
- `packages/katex/tool/gen_font_bytes.dart` (stub ok for M1) — will emit base64 font
  bytes const for SVG embedding (used by T-012).

## Acceptance criteria
- `dart run tool/gen_font_metrics.dart` regenerates `font_metrics_data.g.dart` and it
  analyzes clean.
- `getCharacterMetrics('A'.codeUnitAt(0), family)` returns the same numbers KaTeX has for
  a few spot-checked glyphs (compare against KaTeX source values in the ticket review).
- Fonts present in `assets/fonts/` with `OFL.txt`.
