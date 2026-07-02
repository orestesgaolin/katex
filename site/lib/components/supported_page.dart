/// The `/supported` catalog page — a categorized reference of KaTeX commands
/// mirroring <https://katex.org/docs/supported>.
///
/// For every command/symbol in [kSupportedEntries] (generated from KaTeX's
/// `docs/supported.md`) it shows, side by side:
///   1. the command source (`code`),
///   2. the ground-truth **KaTeX JS** render (reusing the `@client` [KatexJs]),
///   3. the **katex Dart → SVG** render (build-time [DartSvg], same em-scaling
///      as the comparison page), and
///   4. a **status badge** computed at build time by trying `renderToBox`:
///      success → ✓ supported (green), any throw → ✗ unsupported (red).
///
/// Per-command Flutter is intentionally omitted — hundreds of embedded Flutter
/// views would exhaust the web engine. Flutter rendering lives on the
/// comparison page (`/`) and its live editor.
///
/// Everything except the KaTeX-JS column is pre-rendered statically, so the
/// support counts ("Supported: X / Y") are honest build-time results.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:katex_dart/katex_dart.dart';

import 'dart_svg.dart';
import 'gh_issue.dart';
import 'katex_js.dart';
import 'site_nav.dart';
import '../supported_data.dart';

/// The catalog is rendered as inline math (matching the doc's `$…$` cells).
const bool _kDisplayMode = false;

/// Whether [tex] renders successfully through `package:katex` at build time.
///
/// Uses `throwOnError: true` so a `ParseError` (or any other failure in the
/// parse/build pipeline) surfaces as a thrown exception and is reported as
/// "unsupported" rather than silently rendering an error glyph.
bool _isSupported(String tex) {
  try {
    renderToBox(tex, options: const KatexOptions(displayMode: _kDisplayMode));
    return true;
  } on Object {
    return false;
  }
}

/// A category section with its entries grouped by optional subcategory.
class _Category {
  _Category(this.title);
  final String title;
  final List<SupportedEntry> entries = [];
}

/// Groups the flat [kSupportedEntries] list into ordered categories, preserving
/// first-seen order of both categories and entries.
List<_Category> _groupByCategory() {
  final out = <_Category>[];
  _Category? current;
  for (final e in kSupportedEntries) {
    if (current == null || current.title != e.category) {
      current = _Category(e.category);
      out.add(current);
    }
    current.entries.add(e);
  }
  return out;
}

class SupportedPage extends StatelessComponent {
  const SupportedPage({super.key});

  @override
  Component build(BuildContext context) {
    final categories = _groupByCategory();
    final total = kSupportedEntries.length;
    // Precompute support status once per entry (build time).
    final supported = <SupportedEntry, bool>{
      for (final e in kSupportedEntries) e: _isSupported(e.tex),
    };
    final totalOk = supported.values.where((ok) => ok).length;

    return div(classes: 'page', [
      const SiteNav(active: SiteRoute.supported),
      header(classes: 'site-header', [
        h1([.text('Supported functions')]),
        p(classes: 'subtitle', [
          .text('The KaTeX command set — every command/symbol from '),
          a(
            href: 'https://katex.org/docs/supported',
            target: Target.blank,
            attributes: const {'rel': 'noopener'},
            [.text('katex.org/docs/supported')],
          ),
          .text(' — rendered by our pure-Dart port. Each row shows the '),
          strong([.text('KaTeX JS')]),
          .text(' ground truth beside our '),
          strong([.text('katex Dart → SVG')]),
          .text(' output, with a build-time support status. Per-command '),
          strong([.text('Flutter')]),
          .text(' is omitted here (hundreds of embedded engines would not '),
          .text('load); see the '),
          a(href: '.', [.text('comparison page')]),
          .text(' for the Flutter renderer.'),
        ]),
        div(classes: 'overall-summary', [
          .text('Supported: '),
          strong([.text('$totalOk / $total')]),
          .text(' commands render without error.'),
        ]),
        div(classes: 'legend', [
          span(classes: 'badge ok', [.text('✓ supported')]),
          .text(' renders without error  '),
          span(classes: 'badge bad', [.text('✗ unsupported')]),
          .text(' parse/build error (caught, shown — not a crash).'),
        ]),
      ]),
      for (final cat in categories)
        _categorySection(cat, supported),
    ]);
  }

  Component _categorySection(_Category cat, Map<SupportedEntry, bool> supported) {
    final ok = cat.entries.where((e) => supported[e] == true).length;
    return section(classes: 'sup-category', [
      h2(classes: 'group-heading', [
        .text(cat.title),
        span(classes: 'cat-summary', [.text('$ok / ${cat.entries.length}')]),
      ]),
      table(classes: 'sup-table', [
        thead([
          tr([
            th(classes: 'th-cmd', [.text('Command')]),
            th([.text('KaTeX JS')]),
            th([.text('katex Dart → SVG')]),
            th(classes: 'th-status', [.text('Status')]),
          ]),
        ]),
        tbody([
          for (final e in cat.entries) _row(e, supported[e] == true),
        ]),
      ]),
    ]);
  }

  Component _row(SupportedEntry e, bool ok) {
    return tr(classes: ok ? 'sup-row' : 'sup-row unsupported', [
      td(classes: 'cell-cmd', [
        code([.text(e.name)]),
        a(
          classes: 'issue-link',
          href: ghIssueUrl(e.tex, displayMode: _kDisplayMode),
          target: Target.blank,
          attributes: const {
            'rel': 'noopener',
            'title': 'Report a rendering issue with this command',
          },
          [.text('⚠')],
        ),
      ]),
      td(classes: 'cell-render', [
        KatexJs(tex: e.tex, displayMode: _kDisplayMode),
      ]),
      td(classes: 'cell-render', [
        DartSvg(e.tex, displayMode: _kDisplayMode),
      ]),
      td(classes: 'cell-status', [
        ok
            ? span(classes: 'badge ok', [.text('✓')])
            : span(classes: 'badge bad', [.text('✗')]),
      ]),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
        css('.overall-summary').styles(
          margin: Margin.symmetric(vertical: 8.px),
          fontSize: 1.05.rem,
        ),
        css('.badge.ok').styles(
          color: const Color('#0a6b2e'),
          backgroundColor: const Color('#d8f5e2'),
        ),
        css('.badge.bad').styles(
          color: const Color('#b00020'),
          backgroundColor: const Color('#ffe0e0'),
        ),
        css('.sup-category').styles(margin: Margin.only(bottom: 32.px)),
        css('.group-heading', [
          css('&').styles(
            display: Display.flex,
            padding: Padding.only(bottom: 6.px),
            margin: Margin.only(top: 24.px, bottom: 12.px),
            border: Border.only(
              bottom: BorderSide(color: const Color('#222'), width: 2.px),
            ),
            alignItems: AlignItems.baseline,
            gap: Gap.all(12.px),
            fontSize: 1.3.rem,
          ),
          css('.cat-summary').styles(
            color: const Color('#666'),
            fontSize: 0.8.rem,
            fontWeight: FontWeight.normal,
          ),
        ]),
        css('.sup-table', [
          css('&').styles(
            width: 100.percent,
            raw: {'border-collapse': 'collapse', 'table-layout': 'fixed'},
          ),
          css('th, td').styles(
            padding: Padding.symmetric(horizontal: 8.px, vertical: 6.px),
            border: Border.only(
              bottom: BorderSide(color: const Color('#eee'), width: 1.px),
            ),
            textAlign: TextAlign.left,
            raw: {'vertical-align': 'middle'},
          ),
          css('th').styles(
            color: const Color('#333'),
            fontSize: 0.8.rem,
            textTransform: TextTransform.upperCase,
          ),
          css('.th-cmd').styles(width: 28.percent),
          css('.th-status').styles(width: 80.px, textAlign: TextAlign.center),
          css('.cell-cmd code').styles(
            padding: Padding.symmetric(horizontal: 5.px, vertical: 2.px),
            radius: BorderRadius.circular(4.px),
            color: const Color('#24292f'),
            fontFamily: const FontFamily.list([
              FontFamily('SFMono-Regular'),
              FontFamily('Menlo'),
              FontFamilies.monospace,
            ]),
            fontSize: 0.8.rem,
            backgroundColor: const Color('#f6f8fa'),
            raw: {'word-break': 'break-all'},
          ),
          css('.cell-render').styles(
            overflow: Overflow.auto,
            backgroundColor: const Color('#fafafa'),
          ),
          css('.cell-status').styles(textAlign: TextAlign.center),
          css('.sup-row.unsupported .cell-render').styles(
            backgroundColor: const Color('#fff6f6'),
          ),
        ]),
        // Small variant of the issue link used in the catalog rows.
        css('.cell-cmd .issue-link').styles(
          margin: Margin.only(left: 6.px),
          color: const Color('#bbb'),
          textDecoration: const TextDecoration(line: TextDecorationLine.none),
          fontSize: 0.75.rem,
        ),
      ];
}
