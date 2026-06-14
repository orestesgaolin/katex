# katex

A pure-Dart port of [KaTeX](https://katex.org). Parses LaTeX math into a backend-agnostic
**box tree** and serializes it to SVG — with **no Flutter dependency**, so it runs in CLI,
server, and web/SSR contexts. For a Flutter widget, see
[`katex_flutter`](https://github.com/orestesgaolin/katex/tree/main/packages/katex_flutter).

## Usage

```dart
import 'package:katex/katex.dart';

void main() {
  // Primary API: a backend-agnostic box tree (height/depth/width in em).
  final box = renderToBox(r'\frac{a}{b}', options: const KatexOptions(displayMode: true));

  // Self-contained SVG (KaTeX fonts embedded via @font-face).
  final svg = renderToSvg(r'\sum_{i=0}^n i', options: const KatexOptions(displayMode: true));
}
```

## CLI

```sh
dart run katex "\frac{a}{b}" > out.svg
dart run katex --display "\int_0^1 x^2\,dx" -o integral.svg
```

## How it works

`Lexer → MacroExpander → Parser → parse-node AST → builders → box tree → SVG`. The box tree
(`BoxNode`: `GlyphNode`, `HBox`, `VList`, `RuleNode`, `SpanNode`, `SvgPathNode`) is the primary
public model — both the SVG serializer and the separate `katex_flutter` painter are pure
consumers of it. Box dimensions are verified against original KaTeX (pinned 0.17.0).

## Status

Covers a broad MVP of KaTeX (fractions, scripts, roots, big operators, delimiters, accents,
fonts, environments, …). Full command/macro coverage and stretchy-glyph stacking are incremental.

## License

MIT (this port) — see `LICENSE`. Ported from KaTeX (MIT). Bundled fonts are SIL OFL; see
`assets/fonts/OFL.txt`.
