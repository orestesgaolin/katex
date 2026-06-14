/// One comparison row: TeX source + three live renders side by side —
/// **KaTeX JS**, **katex Dart SVG**, and **katex_flutter**.
///
/// The `katex_flutter` cell is its OWN lazy `<iframe>` running a single-view
/// Flutter engine for just this expression (`flutter/index.html?tex=...`). One
/// engine per row keeps every glyph rendering (CanvasKit multi-view drops some)
/// and lines the cell up by construction (the iframe IS the grid cell), unlike a
/// single tall gallery iframe which drifts out of alignment with the DOM list.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../examples.dart';
import 'dart_svg.dart';
import 'katex_js.dart';

/// Minimum per-row cell height (px). Rows grow taller for tall expressions; the
/// Flutter iframe is absolutely positioned so it fills the row without forcing
/// its own intrinsic height.
const int kRowMinHeight = 72;

/// A four-cell comparison row for one [example]:
/// `TeX source | KaTeX JS | katex Dart SVG | katex_flutter`.
class ComparisonRow extends StatelessComponent {
  const ComparisonRow(this.example, {super.key});

  /// The example to render.
  final Example example;

  String get _flutterSrc {
    final tex = Uri.encodeQueryComponent(example.tex);
    return 'flutter/index.html?tex=$tex'
        '&display=${example.displayMode}&fontSize=22';
  }

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
      // Column 4: katex_flutter — its own single-view engine in a lazy iframe.
      div(classes: 'cmp-cell flutter-cell', [
        iframe(
          const [],
          src: _flutterSrc,
          loading: MediaLoading.lazy,
          attributes: {'title': 'katex_flutter: ${example.tex}'},
        ),
      ]),
    ]);
  }
}
