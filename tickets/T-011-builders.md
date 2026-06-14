# T-011 — buildExpression + per-group builders (MVP)

**Milestone:** M3  **Status:** review  **Depends on:** T-008, T-010

## Goal
Port `buildHTML.js`'s box-building path + per-function `htmlBuilder`s for the MVP set,
turning the parse-node AST into the box tree.

## Scope
Port from KaTeX `src/buildHTML.js` and each MVP `src/functions/*.js` `htmlBuilder`:
- `buildExpression`/`buildGroup`/`buildHTML` → `lib/src/build/build_expression.dart`
  emitting BoxNode (incl. inter-atom spacing from `spacingData`, atom class tracking).
- Per-group builders in `lib/src/build/builders/`:
  - supsub, genfrac (`\frac`/`\dfrac`/`\tfrac`), sqrt (+index), op/operatorname
    (`\sum`/`\int`/`\prod` with limits), leftright/delimsizing (`\left…\right`),
    accent (`\hat`/`\bar`/`\vec`/`\tilde`), text, font, color, sizing, styling,
    `\overline`/`\underline`, array (matrix/pmatrix/bmatrix/aligned/cases).
- Wire `renderToBox(tex, options)` in `lib/katex.dart`: lex → expand → parse → build.

## Acceptance criteria
- `dart analyze` clean.
- `renderToBox` returns a box tree for every gallery expression without throwing.
- `test/build_expression_test.dart`: root box dimensions for a handful of expressions are
  finite/positive and structurally correct (full numeric oracle match is T-014).
