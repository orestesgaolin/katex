# T-009 — Box tree node types (primary public model)

**Milestone:** M3  **Status:** review  **Depends on:** T-001

## Goal
The backend-agnostic box tree — the project's PRIMARY public model. No HTML/CSS, no Flutter.

## Scope
- `lib/src/box/box_node.dart` — sealed `BoxNode` base with `height`, `depth`, `width`
  (all logical units, em-based like KaTeX), plus:
  - `GlyphNode` — `{int codepoint, FontFamily family, FontVariant variant, double size,
    double italic, double skew}`.
  - `HBox` — `{List<BoxNode> children}`; children advance by width; supports interleaved
    `KernNode`.
  - `VBox`/`VList` — `{List<VListChild> children}` stacked at explicit shifts (port
    KaTeX `buildCommon.makeVList` positioning semantics: `individualShift`/`top`/`bottom`/
    `firstBaseline` modes).
  - `RuleNode` — `{double width, height, depth}` filled rect.
  - `SpanNode` — wrapper carrying `color`, `classes`, sizing metadata + one/many children.
  - `KernNode` — `{double width}`.
  - `SvgPathNode` — `{String pathName, ...}` stub for M6 stretchy glyphs.
- Each node exposes its computed `height`/`depth`/`width` so consumers never recompute.

## Acceptance criteria
- `dart analyze` clean.
- Types are pure data + dimension accessors; zero dependency on `dart:ui`/Flutter.
- A hand-built tiny tree (e.g. an HBox of two glyphs) reports correct aggregate
  width/height/depth in a unit test. `test/box_tree_test.dart` passes.
