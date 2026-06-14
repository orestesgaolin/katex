# Changelog

## 0.1.0

Initial release. A Flutter widget that renders LaTeX math using the pure-Dart
[`katex`](https://pub.dev/packages/katex) package.

- `Math(tex, {displayMode, fontSize, color, onError, throwOnError})` widget.
- Paints the `katex` box tree directly via a `CustomPainter` (`TextPainter` for glyphs,
  `Canvas.drawRect` for rules, `Canvas.drawPath` for stretchy SVG geometry) — no re-parsing.
- Bundles the KaTeX glyph fonts (SIL OFL) as package fonts.
- Painter layout matches the `katex` SVG serializer (verified) so Flutter and SVG agree.
