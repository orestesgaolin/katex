# T-043 — Unify duplicated box dimension math (sum-width / max-height / max-depth)

**Milestone:** M9 (refactor/simplify)  **Status:** todo  **Depends on:** —

## Problem
Identical manual width/height/depth loops are duplicated:
- `lib/src/box/box_node.dart` — `HBox` and `SpanNode` have byte-identical `width`/`height`/`depth`
  getters (sum widths, max heights, max depths over `children`).
- `lib/src/build/builders/delimiter_builders.dart` and
  `lib/src/build/builders/array_builder.dart` — same "track max height/depth over children" loops.

## Change
Add shared private helpers in `box_node.dart` (top-level, file-private):
`double sumWidth(List<BoxNode>)`, `double maxHeight(List<BoxNode>)`, `double maxDepth(List<BoxNode>)`
using `fold` + `math.max`. Use them in both `HBox` and `SpanNode`. Where the builders track
max height/depth over children, switch their manual `if (x > m) m = x` loops to `math.max`
(or the shared helper if importable without a cycle).

## Acceptance criteria
- `HBox`/`SpanNode` dimension getters share one implementation; no duplicated loops.
- Builder max-over-children loops use `math.max` (no behavior change for empty lists — must
  still yield 0.0, matching current code).
- `dart analyze` clean; `dart test` 304 passing; oracle dimension gate still 26/26 (this is
  the authoritative numeric check — dimensions must be byte-identical).
