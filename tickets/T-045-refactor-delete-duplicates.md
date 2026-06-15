# T-045 — Delete outright-duplicate functions/constants/imports

**Milestone:** M9 (refactor/simplify)  **Status:** todo  **Depends on:** —

## Problem — verbatim duplicates
- `functions/functions.dart`: `_pmbBinrelClass` is byte-for-byte identical to `_binrelClass` →
  delete it, call `_binrelClass` from the pmb registration.
- `parse/macros.dart`: `\newline` is registered twice with identical body → delete the second.
- `build/builders/sqrt_builder.dart`: private `_sizeToMaxHeight` duplicates the public
  `sizeToMaxHeight` in `delimiter_builders.dart` → import & use the public one, delete the copy.
- `build/build_expression.dart` `_styleFromStr` == `build/builders/styling_builders.dart`
  `_styleFor` (identical StyleStr→Style switch) → one shared `styleFromStr(StyleStr)` (in
  `build/style.dart`), both call it.
- `build/katex_options.dart`: duplicate `ParseError` import (imported via both the barrel and
  the direct path) → keep one.

## Acceptance criteria
- Each named duplicate removed; the single surviving definition is used at all call sites.
- `dart analyze` clean (watch for now-unused imports); `dart test` 304 passing; oracle gate 26/26.
