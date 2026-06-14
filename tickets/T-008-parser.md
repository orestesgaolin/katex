# T-008 — Parser (MVP grammar)

**Milestone:** M2  **Status:** review  **Depends on:** T-005, T-006, T-007, T-004

## Goal
Port KaTeX's `Parser.js` for the MVP grammar producing the parse-node AST.

## Scope
Port from `reference/node_modules/katex/src/Parser.js` + the relevant
`src/functions/*.js` definitions for MVP commands. Implement:
- `parseExpression`, `parseAtom`, `parseGroup`, `parseImplicitGroup`, sup/sub handling
  (`handleSupSubscript`), primes, `handleInfixNodes` (for `\over`-style — at least
  `\frac` via function), argument parsing (`parseArguments`).
- A `functions` registry (`lib/src/functions/`) wiring command name → handler producing a
  parse node, for the MVP set: `\frac`/`\dfrac`/`\tfrac`, `\sqrt`, `\sum`/`\int`/`\prod`
  & operatorname, `\left`/`\right`, `\text`, accents, font commands, `\overline`/
  `\underline`, `\color`/`\textcolor`, sizing/styling, environments
  `matrix`/`pmatrix`/`bmatrix`/`aligned`/`cases`.

## Acceptance criteria
- `dart analyze` clean.
- Parsing each gallery expression (T-002 `gallery.json`) yields an AST without error.
- Port a representative subset of KaTeX's parser test cases; `test/parser_test.dart`
  passes with AST-shape assertions for `\frac{a}{b}`, `x^2_i`, `\sqrt[3]{x}`,
  `\sum_{i=0}^n`, `\left(\right)`, a matrix, and `aligned`.
