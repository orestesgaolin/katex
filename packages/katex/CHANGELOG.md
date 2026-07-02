# Changelog

## 0.1.0

Initial release. A Flutter widget that renders LaTeX math using the pure-Dart
[`katex_dart`](https://pub.dev/packages/katex_dart) package.

- `Math(tex, {displayMode, fontSize, color, onError, throwOnError})` widget.
- Paints the `katex_dart` box tree directly via a `CustomPainter` (`TextPainter` for glyphs,
  `Canvas.drawRect` for rules, `Canvas.drawPath` for stretchy SVG geometry) — no re-parsing.
- Bundles the KaTeX glyph fonts (SIL OFL) as package fonts.
- Painter layout matches the `katex_dart` SVG serializer (verified) so Flutter and SVG agree.
