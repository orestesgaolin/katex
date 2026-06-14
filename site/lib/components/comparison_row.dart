/// One comparison row: the TeX source plus the KaTeX-JS and Dart-SVG renders.
///
/// The third renderer (`katex_flutter`) is shown in a single full-height
/// Flutter-web iframe that spans the whole gallery (see [FlutterGallery] in
/// `app.dart`) — one Flutter engine for the whole page is far more reliable
/// than one iframe per row. Each row here is a fixed height (`kRowHeight`) so
/// the Flutter column's rows line up with these.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../examples.dart';
import 'dart_svg.dart';
import 'katex_js.dart';

/// Fixed per-row height (px) shared by the JS/SVG rows and the Flutter gallery
/// rows so the three columns stay aligned.
const int kRowHeight = 120;

/// A two-cell comparison row (KaTeX JS | Dart SVG) for one [example], with the
/// TeX source and an optional "approx" badge above.
class ComparisonRow extends StatelessComponent {
  const ComparisonRow(this.example, {super.key});

  /// The example to render.
  final Example example;

  @override
  Component build(BuildContext context) {
    return div(classes: 'cmp-row', id: 'row-${example.id}', [
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
      div(classes: 'cmp-cells', [
        div(classes: 'cmp-cell', [
          KatexJs(tex: example.tex, displayMode: example.displayMode),
        ]),
        div(classes: 'cmp-cell', [
          DartSvg(example.tex, displayMode: example.displayMode),
        ]),
      ]),
    ]);
  }
}
