# T-022 — Real stretchy delimiters + surd via SvgPathNode geometry

**Milestone:** M6 (first expansion slice, carved from T-019)  **Status:** review  **Depends on:** T-011, T-012, T-016

## Goal
Replace the fixed-glyph approximations for `\left…\right` delimiters and `\sqrt` surd with
real KaTeX stretchy SVG-path geometry, end-to-end (box tree → SVG output → Flutter paint).

## Scope
- **Geometry data**: port `reference/node_modules/katex/src/svgGeometry.ts` (the `path` map
  of SVG path `d` strings) → `lib/src/svg/svg_geometry.g.dart` (or a generator
  `tool/gen_svg_geometry.dart`). Port the relevant parts of `stretchy.ts` for delimiter
  assembly if needed.
- **Box model**: flesh out `SvgPathNode` in `lib/src/box/box_node.dart` so it carries the
  resolved path name + viewBox + explicit width/height/depth (it already has placeholder
  fields — make them load-bearing). Keep it backend-agnostic.
- **Builders**: update `delimiter_builders.dart` (`\left`/`\right`, `\bigl`… stacking) and
  `sqrt_builder.dart` to emit `SvgPathNode`-based stretchy geometry sized to content,
  matching KaTeX's `delimiter.ts` `makeStackedDelim`/`sqrtImage` math. Dimensions must still
  match the oracle (don't regress the 26/26 gate).
- **SVG serializer**: emit `<path d="…" transform=…>` for `SvgPathNode` (replace the comment
  stub) with correct scaling from the path viewBox to the node's box size.
- **Flutter painter**: draw `SvgPathNode` via `Canvas.drawPath` (parse the SVG `d` string to a
  `ui.Path` — a small path-parser, or reuse one) instead of the current no-op.

## Acceptance criteria
- `dart test` oracle dimension gate stays **26/26** (delimiters/sqrt dims unchanged or closer).
- `renderToSvg(r'\left(\frac{a}{b}\right)')` emits a `<path>` for each delimiter; output still
  valid XML.
- Flutter painter draws the delimiter/surd paths (a widget/paint test confirms non-empty ink
  for `\left(\frac{a}{b}\right)` and `\sqrt{x}` beyond just the radicand).
- SVG visual golden diff for delimiter/sqrt entries improves vs the fixed-glyph baseline
  (report the before/after pixel-diff ratio honestly).
- No regression to the full Dart + Flutter test suites.
