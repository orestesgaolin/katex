# T-004 — Symbols + spacing generators → Dart tables

**Milestone:** M1  **Status:** review  **Depends on:** T-001

## Goal
Port KaTeX's symbol table and spacing data to Dart const tables.

## Scope
- `packages/katex/tool/gen_symbols.dart` — reads `reference/node_modules/katex/src/symbols.js`
  and emits `lib/src/symbols/symbols.g.dart`: the `defineSymbol(mode, font, group, replace,
  name)` registrations as Dart data (math + text modes; atom groups: bin, rel, open, close,
  punct, op, inner, mathord, textord, accent, spacing).
- `lib/src/symbols/symbols.dart` — `Symbols` lookup API (mode → name → `{font, group,
  replace}`), mirroring KaTeX `symbols` map.
- Port `spacingData.js` (`src/spacingData.js`) → `lib/src/symbols/spacing_data.g.dart`
  (inter-atom spacing in mu).
- Port the unicode accent/symbol helper tables needed by the MVP (subset of
  `unicodeSymbols`, `unicodeAccents` as needed).

## Acceptance criteria
- `dart run tool/gen_symbols.dart` regenerates the table; analyzes clean.
- `Symbols.lookup(Mode.math, '\\alpha')` etc. return the correct group/replace for a spot
  set of symbols checked against KaTeX source during review.
- Spacing table values match KaTeX's `spacings`/`tightSpacings`.
