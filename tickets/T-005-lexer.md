# T-005 — Lexer, Token, SourceLocation, Settings, ParseError

**Milestone:** M2  **Status:** review  **Depends on:** T-001

## Goal
Port KaTeX's lexing layer and supporting types.

## Scope
Port from `reference/node_modules/katex/src/`:
- `Token.js` → `lib/src/parse/token.dart`
- `SourceLocation.js` → `lib/src/parse/source_location.dart`
- `Lexer.js` → `lib/src/parse/lexer.dart` (the catcode/regex tokenizer, `\verb` handling
  may be stubbed for MVP)
- `ParseError.js` → `lib/src/parse/parse_error.dart`
- `Settings.js` → `lib/src/parse/settings.dart` (displayMode, throwOnError, errorColor,
  macros, strict, trust, maxSize, maxExpand)

## Acceptance criteria
- `dart analyze` clean.
- Port unit tests from KaTeX's lexer specs: lexing `\frac{a}{b}`, `x^2_i`, whitespace,
  comments, control sequences, and braces yields the expected token stream.
- `test/lexer_test.dart` passes.
