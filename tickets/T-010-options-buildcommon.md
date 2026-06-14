# T-010 — Options, Style, buildCommon

**Milestone:** M3  **Status:** review  **Depends on:** T-003, T-009

## Goal
Port KaTeX's `Options.js`, `Style.js`, and `buildCommon.js` glyph/box construction layer.

## Scope
Port from KaTeX `src/`:
- `Style.js` → `lib/src/build/style.dart` (DISPLAY/TEXT/SCRIPT/SCRIPTSCRIPT, sizes,
  `sup`/`sub`/`fracNum`/`fracDen`/`cramp`/`text` transitions, `sizeMultiplier`,
  `isTight`).
- `Options.js` → `lib/src/build/options.dart` (style, color, size, textSize, phantom,
  font, fontFamily, fontWeight, fontShape, `sizeMultiplier`, `havingStyle/Size/Color`,
  `withColor`, etc.).
- `buildCommon.js` → `lib/src/build/build_common.dart` — the box constructors emitting
  **BoxNode** (not DOM): `makeSymbol`/`mathsym`/`makeOrd`, `makeGlyph`, `makeSpan`,
  `makeFragment`, `makeVList` (→ VBox/VList), `makeLineSpan` (→ RuleNode), kerning, and
  `getCharacterMetrics`-driven glyph sizing.

## Acceptance criteria
- `dart analyze` clean.
- `makeSymbol` for `A` at DISPLAY style produces a `GlyphNode` whose height/depth/width
  match the KaTeX font metrics (spot-checked in test).
- `makeVList` stacking matches KaTeX positioning for a 2-element stack (unit test).
- `test/build_common_test.dart` passes.
