# T-021 — Flutter golden harness renders real glyphs

**Milestone:** M5 (follow-up)  **Status:** review  **Depends on:** T-018

## Goal
Make the `flutter_test` golden harness rasterize the bundled KaTeX glyphs as real glyphs
instead of filled "tofu" boxes, so goldens guard glyph shapes — not just layout + rules.

## Background (from T-018)
The `Math` widget renders correctly on a real device (the painter uses the bundled
`KaTeX_*` fonts via `TextPainter`). But in headless `flutter_test`, even a correctly
package-referenced `TextPainter` for a KaTeX font paints a fully-filled rectangle — a
known Flutter headless font-rasterization limitation. Rules (fraction bars, sqrt/overline
lines) render fine, so the current self-captured goldens protect layout/positioning/rule
geometry but not glyph shapes. The `example/` app (run on device) is the glyph-level
visual-confirmation path today.

## Ideas to try
- `FontLoader` with the exact bundled bytes + `tester.runAsync` so the font engine fully
  registers before pumping.
- Confirm whether `flutter test` needs `--enable-impeller`/skia config or a specific
  `TestWidgetsFlutterBinding` font setting to rasterize embedded TTFs.
- Alternatively, render via the SVG path (rasterize with resvg) for the visual golden and
  compare to the KaTeX reference PNG with an ink-box/baseline-aligned comparison (shared
  with the T-014 SVG-golden tightening follow-up).

## Acceptance criteria
- Golden test for at least a few gallery entries shows real glyph shapes (not solid boxes),
  OR a documented, working SVG-rasterization-based visual golden replaces it.
- No regression to the existing layout/geometry goldens.

## Resolution (real glyphs now render — root cause was font registration, not a Skia limitation)
The "tofu" fallback was **not** a flutter_test rasterization limitation. It was a
FontLoader family-name mismatch:

- The painter builds its `TextStyle` with `package: 'katex_flutter'`, which Flutter
  resolves internally to the prefixed family `packages/katex_flutter/KaTeX_<Family>`.
- The old `golden_test.dart` `setUpAll` registered each `FontLoader` under the **bare**
  family `KaTeX_<Family>`. The painter's prefixed lookup therefore missed and fell back
  to a solid filled rectangle.

**Pixel probe (definitive).** Rendering glyph 'R' at 64px through
`TextStyle(fontFamily: 'KaTeX_Main', package: 'katex_flutter')`:
  - FontLoader registered as `KaTeX_Main` (bare)                  -> bbox fill ratio **1.000** = SOLID/tofu
  - FontLoader registered as `packages/katex_flutter/KaTeX_Main`  -> bbox fill ratio **0.415** = REAL GLYPH (interior counters)
(A standalone probe with a bare `TextStyle` family and no `package` also rendered real
glyphs at 0.415, confirming the engine rasterizes embedded TTFs fine; the package prefix
was the only missing link.)

**Fix.** `_loadKatexFonts` now registers every `FontLoader` under the package-prefixed
name `packages/katex_flutter/KaTeX_<Family>`. The 26 gallery goldens were regenerated and
now show real KaTeX glyph shapes (verified visually: e.g. `greek-alpha-beta.png` shows
"α + β", `frac-a-b.png` shows a/b over a rule, `sqrt-index-3-x.png` shows a real cube root).

**Cross-check.** Added `test/svg_glyph_golden_test.dart`: serializes a few formulas via
`package:katex`'s `renderToSvg`, rasterizes with `rsvg-convert` (zoom 2.0), and byte-compares
to self-captured PNGs under `goldens/svg/`. This independently proves glyph SHAPES render via
the SVG path; it SKIPS cleanly if no `rsvg-convert`/`resvg` is on PATH.

**What a verifier should run** (from `packages/katex_flutter/`):
  - `flutter analyze` — clean for the T-021 files (the only remaining infos are pre-existing
    lints in `painter_test.dart`, owned by the concurrent painter work, not T-021).
  - `flutter test test/golden_test.dart test/svg_glyph_golden_test.dart` — 31 green
    (26 glyph goldens + 5 SVG goldens).
  - Open `test/goldens/greek-alpha-beta.png` to eyeball real glyphs.
