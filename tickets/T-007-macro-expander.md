# T-007 — MacroExpander + Namespace

**Milestone:** M2  **Status:** review  **Depends on:** T-005, T-006

## Goal
Port the macro expansion layer that sits between Lexer and Parser.

## Scope
Port from KaTeX `src/`:
- `Namespace.js` → `lib/src/parse/namespace.dart` (scoped macro/symbol storage with
  begingroup/endgroup).
- `MacroExpander.js` → `lib/src/parse/macro_expander.dart` (token pushback, `expandOnce`,
  `expandNextToken`, `consumeArgs`, builtin macro support).
- `macros.js` subset → `lib/src/parse/macros.g.dart` or `macros.dart`: the builtin macros
  needed by the MVP gallery (`\dfrac`, `\tfrac`, `\bmod`, `\cdots`, common aliases). Full
  macro set can be expanded later in M6.

## Acceptance criteria
- `dart analyze` clean.
- A simple `\def`-free expansion path works; builtin alias macros expand correctly.
- Unit test: expanding `\dfrac` → `\genfrac`-style tokens matches KaTeX behavior for the
  MVP cases. `test/macro_expander_test.dart` passes.
