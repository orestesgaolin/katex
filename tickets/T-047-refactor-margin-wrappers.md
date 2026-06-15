# T-047 — Unify the margin/kern wrapper helpers

**Milestone:** M9 (refactor/simplify)  **Status:** todo  **Depends on:** —

## Problem
Three near-identical kern-margin wrappers:
- `build/builders/supsub_builder.dart` `_withMargins({left, right})`
- `build/builders/op_builders.dart` `_withSideMargins({left, right})` — identical body
- `build/builders/op_builders.dart` `_withLeftMargin(margin)` — the left-only special case

## Change
Add one shared `withMargins(BoxNode elem, {double left = 0, double right = 0})` in
`build/build_common.dart`; delete all three local copies and route callers through it
(`_withLeftMargin(m)` becomes `withMargins(elem, left: m)`).

## Acceptance criteria
- Single `withMargins` helper; the three local wrappers removed.
- Emitted box trees byte-identical (kern children, ordering, values unchanged).
- `dart analyze` clean; `dart test` 304 passing; oracle gate 26/26.
