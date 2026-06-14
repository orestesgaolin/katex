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

/// Captures the outer `<svg …>` tag's intrinsic `width="…" height="…"` (in SVG
/// user units, where the serializer maps 1 em → 44 user units — see
/// `package:katex`'s `defaultFontSize`). Group 1 = width, group 2 = height.
final RegExp _svgSize = RegExp(
  r'(<svg\b[^>]*?)\bwidth="([\d.]+)" height="([\d.]+)"',
);

/// SITE-1: the SVG serializer sizes its intrinsic `width`/`height` at 44 user
/// units per em, so an inline `<svg>` renders ~44 px/em — far larger than the
/// KaTeX-JS column, which renders math at `1.21em × page-font-size` (~16 px →
/// ~19 px/em; see `.katex{font:normal 1.21em …}` in `katex.min.css`) and the
/// Flutter column. To match, we rewrite only the *outer* `width`/`height` to
/// `em` units (leaving the `viewBox` in user units, so all internal coordinates
/// and the aspect ratio are untouched and the browser scales content to fit).
///
/// Dividing the user-unit extent by [_emPerUserUnitDivisor] = 44 / 1.21 makes
/// one em of math equal `1.21em` of CSS — exactly the KaTeX-JS scale — so the
/// SVG now tracks the page font-size like the other two columns.
const double _emPerUserUnitDivisor = 44 / 1.21;

/// Renders [tex] to a lean, page-scaled inline SVG string via `package:katex`'s
/// [renderToSvg]: strips the embedded font `<defs>` (the page's `katex.min.css`
/// provides the `KaTeX_*` families) and rescales the intrinsic size to em so it
/// matches the KaTeX-JS / Flutter scale (SITE-1). Pure Dart — runs at build time
/// (static prerender) *and* in the compiled `@client` bundle (the live editor).
String renderLeanScaledSvg(String tex, {required bool displayMode}) {
  final svg = renderToSvg(
    tex,
    options: KatexOptions(displayMode: displayMode, throwOnError: false),
  );
  final lean = svg.replaceFirst(_defsBlock, '');
  return lean.replaceFirstMapped(_svgSize, (Match m) {
    final w = double.parse(m[2]!) / _emPerUserUnitDivisor;
    final h = double.parse(m[3]!) / _emPerUserUnitDivisor;
    return '${m[1]}width="${_emStr(w)}em" height="${_emStr(h)}em"';
  });
}

/// Formats an em value compactly (trim trailing zeros, cap precision).
String _emStr(double v) {
  var s = v.toStringAsFixed(4);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}

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
      svg = renderLeanScaledSvg(tex, displayMode: displayMode);
    } on Object catch (error) {
      return div(
        classes: 'render-error',
        [.text('Dart SVG error: $error')],
      );
    }
    return div(classes: 'dart-svg', [RawText(svg)]);
  }
}
