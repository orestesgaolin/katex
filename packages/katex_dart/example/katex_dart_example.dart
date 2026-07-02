// Example: render LaTeX math to a box tree and to self-contained SVG with the
// pure-Dart `katex_dart` package (no Flutter dependency).
//
// Run from the package root:
//   dart run example/katex_dart_example.dart
//
// Or use the bundled CLI:
//   dart run katex_dart "\frac{a}{b}" > out.svg
import 'dart:io';

import 'package:katex_dart/katex_dart.dart';

void main() {
  const options = KatexOptions(displayMode: true);

  // The primary public model is a backend-agnostic box tree whose dimensions
  // (height/depth/width) are expressed in em and match original KaTeX.
  final box = renderToBox(r'\frac{a}{b}', options: options);
  stdout.writeln('Box tree root: ${box.runtimeType}');

  // The SVG serializer is a pure consumer of that same box tree. The output is
  // self-contained (KaTeX fonts embedded via @font-face).
  final svg = renderToSvg(r'\sum_{i=0}^n i^2', options: options);
  File('sum.svg').writeAsStringSync(svg);
  stdout.writeln('Wrote sum.svg (${svg.length} bytes)');
}
