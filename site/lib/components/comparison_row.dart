/// One comparison row: the TeX source plus three live renders of the same
/// expression — **KaTeX JS** (ground truth, hydrated client-side), **katex
/// Dart SVG** (pre-rendered at build time) and **katex_flutter** (rendered
/// inline via Flutter web multi-view embedding — see [FlutterView]).
///
/// The row is one 4-column CSS grid (`.cmp-row`) — `TeX source | KaTeX JS |
/// katex Dart SVG | katex_flutter` — aligned with the heading strip in
/// `app.dart`, so all four cells sit side by side for the same expression and
/// share a row baseline. The Flutter cell is a fixed-height host `<div>` (the
/// engine needs explicit bounds).
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../examples.dart';
import 'dart_svg.dart';
import 'flutter_view.dart';
import 'katex_js.dart';

/// A four-cell comparison row (TeX source | KaTeX JS | Dart SVG |
/// katex_flutter) for one [example].
class ComparisonRow extends StatelessComponent {
  const ComparisonRow(this.example, {super.key});

  /// The example to render.
  final Example example;

  @override
  Component build(BuildContext context) {
    return div(classes: 'cmp-row', id: 'row-${example.id}', [
      // Column 1: the TeX source + badges.
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
      // Column 3: katex Dart → SVG (pre-rendered at build time).
      div(classes: 'cmp-cell', [
        DartSvg(example.tex, displayMode: example.displayMode),
      ]),
      // Column 4: katex_flutter Math widget (Flutter multi-view, inline).
      div(classes: 'cmp-cell flutter-cell', [
        FlutterView(tex: example.tex, displayMode: example.displayMode),
      ]),
    ]);
  }
}
