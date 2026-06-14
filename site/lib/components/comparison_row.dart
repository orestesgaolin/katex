/// One comparison row: TeX source + three live renders side by side —
/// **KaTeX JS**, **katex Dart SVG**, and **katex_flutter**.
///
/// The `katex_flutter` cell is a `FlutterCell` — a `jaspr_flutter_embed`
/// `FlutterEmbedView` hosting the `MathCell` widget. All cells share one Flutter
/// engine (one embedded view each), which avoids the per-iframe WebGL-context
/// exhaustion that blanked cells on click.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../examples.dart';
import 'dart_svg.dart';
import 'flutter_cell.dart';
import 'katex_js.dart';

/// Minimum per-row cell height (px). Rows grow taller for tall expressions.
const int kRowMinHeight = 72;

/// A four-cell comparison row for one [example]:
/// `TeX source | KaTeX JS | katex Dart SVG | katex_flutter`.
class ComparisonRow extends StatelessComponent {
  const ComparisonRow(this.example, {super.key});

  /// The example to render.
  final Example example;

  @override
  Component build(BuildContext context) {
    return div(classes: 'cmp-row', id: 'row-${example.id}', [
      // Column 1: TeX source + badges.
      div(classes: 'cmp-source', [
        code([.text(example.tex)]),
        if (example.displayMode) span(classes: 'badge mode', [.text('display')]),
        if (example.approx)
          span(
            classes: 'badge approx',
            attributes: {'title': example.note ?? 'known MVP approximation'},
            [.text('approx')],
          ),
      ]),
      // Column 2: KaTeX JS (hydrated client-side).
      div(classes: 'cmp-cell', [
        KatexJs(tex: example.tex, displayMode: example.displayMode),
      ]),
      // Column 3: katex Dart SVG (pre-rendered at build time).
      div(classes: 'cmp-cell', [
        DartSvg(example.tex, displayMode: example.displayMode),
      ]),
      // Column 4: katex_flutter via jaspr_flutter_embed (one shared engine).
      div(classes: 'cmp-cell flutter-cell', [
        FlutterCell(tex: example.tex, displayMode: example.displayMode),
      ]),
    ]);
  }
}
