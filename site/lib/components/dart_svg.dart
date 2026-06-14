/// Column 2 — the pure-Dart `package:katex` SVG output.
///
/// In Jaspr **static** mode this runs at build time (`renderToSvg` is pure
/// Dart, no Flutter, no browser). The resulting `<svg>` is inlined verbatim
/// via [RawText], so the column needs no client JS — it is fully pre-rendered.
///
/// `renderToSvg` emits a *self-contained* SVG that re-embeds the whole KaTeX
/// font set (~470 KB) as data-URI `@font-face` rules in a `<defs><style>`
/// block. That is right for a standalone file, but inlining 50+ such SVGs in
/// one HTML page would balloon it to tens of MB. Since this page already loads
/// the vendored `katex.min.css` (which defines the very same `KaTeX_*` font
/// families the SVG `<text>` elements reference), we strip the per-SVG
/// `<defs>…</defs>` font block and let the page-level fonts apply. This shrinks
/// each inlined SVG from ~470 KB to <1 KB with identical rendering.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:katex/katex.dart';

/// Matches the leading `<defs>…</defs>` block that carries the embedded
/// `@font-face` data-URIs (non-greedy, single block at the start of the SVG).
final RegExp _defsBlock = RegExp(r'<defs>.*?</defs>', dotAll: true);

/// Renders [tex] to inline SVG using `package:katex`'s [renderToSvg].
class DartSvg extends StatelessComponent {
  const DartSvg(this.tex, {required this.displayMode, super.key});

  /// The LaTeX math source.
  final String tex;

  /// Whether to typeset as display math.
  final bool displayMode;

  @override
  Component build(BuildContext context) {
    String svg;
    try {
      svg = renderToSvg(
        tex,
        options: KatexOptions(displayMode: displayMode, throwOnError: false),
      );
    } on Object catch (error) {
      return div(
        classes: 'render-error',
        [.text('Dart SVG error: $error')],
      );
    }
    // Drop the embedded font block; the page's katex.min.css provides the
    // identically-named KaTeX_* families.
    final lean = svg.replaceFirst(_defsBlock, '');
    return div(classes: 'dart-svg', [RawText(lean)]);
  }
}
