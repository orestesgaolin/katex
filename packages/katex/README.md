# katex

A Flutter widget that renders LaTeX math by painting the backend-agnostic box tree produced by
the pure-Dart [`katex_dart`](https://pub.dev/packages/katex_dart) package. No re-parsing — the
widget is a direct consumer of the same box tree the SVG serializer uses.

See Flutter demo at [roszkowski.dev/katex](https://roszkowski.dev/katex).

See [main README](https://github.com/orestesgaolin/katex) for a comparison with other Flutter math libraries, and for the architecture of the `katex_dart` + `katex` combo.

## Usage

```dart
import 'package:katex/katex.dart';

Math(r'\frac{a}{b}');                          // inline
Math(r'\sum_{i=0}^n i', displayMode: true);    // display
Math(r'x^2', fontSize: 24, color: Colors.indigo);
Math(r'\frac{a}', throwOnError: false,         // graceful error handling
     onError: (context, e) => Text('bad: $e'));
```

See [`example/`](example/) for a runnable gallery demo.

### Line breaking

A long expression stays on one line and overflows by default — KaTeX's own behaviour.
Pass `softWrap: true` to break it across lines instead:

```dart
Math(r'a + b + c = d + e + f + g + h', softWrap: true);   // wraps to the parent
Math(r'a + b + c = d', maxWidth: 200);                     // wraps at 200px
```

Breaks land only where TeX allows one — after a top-level binary operator (`+`, `-`,
`\times`, …), a top-level relation (`=`, `<`, `\rightarrow`, …), or an explicit
`\allowbreak`; the operator ends the line rather than starting the next. `\nobreak`
(and `~`) suppresses the opportunity beside it. Nothing inside `{...}`, a fraction, or
a `\left…\right` pair is ever broken, so a single over-wide `\frac` still overflows —
there is nowhere legal to cut it.

`softWrap` needs a bounded width constraint; under an unbounded one (a horizontal
`ListView`, an unconstrained `Row`) it has nothing to wrap to and the expression stays
on one line. `maxWidth` takes precedence and works anywhere.

## How it works

The [`katex_dart`](https://pub.dev/packages/katex_dart) package parses the TeX into a `BoxNode`
tree once; `Math` paints it with a `CustomPainter` — `GlyphNode` → `TextPainter` (using the
bundled `KaTeX_*` fonts), `RuleNode` → `drawRect`, `SvgPathNode` → `drawPath`. Glyph baselines,
kerning, and vlist positioning mirror the `katex_dart` SVG serializer so both backends render
identically.

## License

MIT — see `LICENSE`. Ported from KaTeX (MIT). Bundled fonts are SIL OFL (`fonts/OFL.txt`).


## Previous katex library

The previous `katex` library is now deprecated and available [on GitHub](https://github.com/motorcityadam/katex.dart). The previous library was a wrapper around the original KaTeX JavaScript library. Thank you, Adam, for handing over the package to me. The new `katex` library is a pure Dart implementation of KaTeX, with no JavaScript dependency.