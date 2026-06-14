# T-016 — Flutter painter consuming BoxNode

**Milestone:** M5  **Status:** review  **Depends on:** T-009, T-011, T-015

## Goal
A `CustomPainter` (or RenderObject) that paints the box tree — no re-parsing.

## Scope
- `lib/src/render/box_painter.dart` — walk `BoxNode`:
  - `GlyphNode` → `TextPainter` with the mapped `TextStyle` (T-015), positioned by
    baseline (`height`/`depth`).
  - `RuleNode` → `canvas.drawRect`.
  - `HBox` → advance x by child widths; `VBox`/`VList` → place children at vertical shifts.
  - `SpanNode` → apply color; `KernNode` → advance x.
- Compute overall size from root box dims × font size; expose intrinsic size for layout.

## Acceptance criteria
- `flutter analyze` clean.
- A widget test pumps a painter for `\frac{a}{b}` and `x^2` and the layout size matches
  the box-tree dimensions (× font size) within rounding.
- No exceptions painting any gallery expression. `test/painter_test.dart` passes.
