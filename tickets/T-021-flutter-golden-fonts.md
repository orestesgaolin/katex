# T-021 — Flutter golden harness renders real glyphs

**Milestone:** M5 (follow-up)  **Status:** todo (backlog)  **Depends on:** T-018

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
