# katex_flutter

A Flutter widget that renders LaTeX math by painting the backend-agnostic box tree produced by
the pure-Dart [`katex`](https://pub.dev/packages/katex) package. No re-parsing — the widget is a
direct consumer of the same box tree the SVG serializer uses.

## Usage

```dart
import 'package:katex_flutter/katex_flutter.dart';

Math(r'\frac{a}{b}');                          // inline
Math(r'\sum_{i=0}^n i', displayMode: true);    // display
Math(r'x^2', fontSize: 24, color: Colors.indigo);
Math(r'\frac{a}', throwOnError: false,         // graceful error handling
     onError: (context, e) => Text('bad: $e'));
```

## How it works

The `katex` package parses the TeX into a `BoxNode` tree once; `Math` paints it with a
`CustomPainter` — `GlyphNode` → `TextPainter` (using the bundled `KaTeX_*` fonts),
`RuleNode` → `drawRect`, `SvgPathNode` → `drawPath`. Glyph baselines, kerning, and vlist
positioning mirror the `katex` SVG serializer so both backends render identically.

## License

MIT — see `LICENSE`. Ported from KaTeX (MIT). Bundled fonts are SIL OFL (`fonts/OFL.txt`).
