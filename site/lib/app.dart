/// The comparison site root.
///
/// Layout: a header, a legend, then for every category a heading followed by
/// the comparison rows. Each row shows the TeX source plus **three inline
/// renders of the same expression**, side by side in one grid:
/// **KaTeX JS** (ground truth, hydrated client-side), **katex Dart SVG**
/// (pre-rendered at build time) and **katex_flutter** (rendered inline via
/// Flutter web *multi-view* embedding — one engine, one view per row; see
/// `components/flutter_view.dart` + `web/flutter_embed.js`).
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'components/comparison_row.dart';
import 'examples.dart';

/// Category heading height (px).
const int kHeadingHeight = 64;

class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'page', [
      header(classes: 'site-header', [
        h1([.text('KaTeX renderer comparison')]),
        p(classes: 'subtitle', [
          .text('Every expression rendered three ways, side by side: '),
          strong([.text('KaTeX JS')]),
          .text(' (ground truth) · '),
          strong([.text('katex')]),
          .text(' Dart → SVG · '),
          strong([.text('katex_flutter')]),
          .text(' Math widget (Flutter web, inline per row).'),
        ]),
        div(classes: 'legend', [
          span(classes: 'badge mode', [.text('display')]),
          .text(' display-mode expression  '),
          span(classes: 'badge approx', [.text('approx')]),
          .text(' known MVP approximation — expected JS/Dart difference, not a bug.'),
        ]),
      ]),
      div(classes: 'compare', [
        div(classes: 'col-headings', [
          div(classes: 'col-head source-head', [.text('TeX source')]),
          div(classes: 'col-head', [.text('KaTeX JS')]),
          div(classes: 'col-head', [.text('katex Dart SVG')]),
          div(classes: 'col-head', [.text('katex_flutter')]),
        ]),
        for (final ExampleGroup group in kGroups)
          .fragment([
            h2(
              classes: 'group-heading',
              styles: Styles(height: kHeadingHeight.px),
              [.text(group.title)],
            ),
            for (final Example ex in group.examples) ComparisonRow(ex),
          ]),
      ]),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
        css('.page').styles(
          maxWidth: 1600.px,
          padding: Padding.all(24.px),
          margin: Margin.symmetric(horizontal: Unit.auto),
        ),
        css('.site-header', [
          css('&').styles(margin: Margin.only(bottom: 24.px)),
          css('h1').styles(margin: Margin.zero, fontSize: 2.rem),
          css('.subtitle').styles(
            color: const Color('#444'),
            fontSize: 1.05.rem,
          ),
          css('.legend').styles(
            color: const Color('#555'),
            fontSize: 0.85.rem,
          ),
        ]),
        // Badges.
        css('.badge', [
          css('&').styles(
            display: Display.inlineBlock,
            padding: Padding.symmetric(horizontal: 6.px, vertical: 2.px),
            margin: Margin.symmetric(horizontal: 4.px),
            radius: BorderRadius.circular(4.px),
            fontSize: 0.7.rem,
            fontWeight: FontWeight.bold,
            textTransform: TextTransform.upperCase,
          ),
          css('&.mode').styles(
            color: const Color('#1a4fa0'),
            backgroundColor: const Color('#e0ecff'),
          ),
          css('&.approx').styles(
            cursor: Cursor.help,
            color: const Color('#9a5b00'),
            backgroundColor: const Color('#fff0d6'),
          ),
        ]),
        // The whole comparison region.
        css('.compare').styles(minWidth: Unit.zero),
        // Column heading strip above the list — FOUR columns aligned with the
        // per-row grid below (TeX | KaTeX JS | Dart SVG | katex_flutter).
        css('.col-headings').styles(
          display: Display.grid,
          padding: Padding.symmetric(vertical: 8.px),
          gridTemplate: GridTemplate(
            columns: GridTracks([
              GridTrack.repeat(
                const TrackRepeat(4),
                [GridTrack(TrackSize.fr(1))],
              ),
            ]),
          ),
          gap: Gap.all(8.px),
          fontWeight: FontWeight.bold,
        ),
        css('.col-head').styles(
          padding: Padding.symmetric(horizontal: 8.px, vertical: 4.px),
          radius: BorderRadius.circular(4.px),
          textAlign: TextAlign.center,
          fontSize: 0.85.rem,
          backgroundColor: const Color('#f3f3f3'),
        ),
        css('.group-heading').styles(
          display: Display.flex,
          margin: Margin.zero,
          border: Border.only(
            bottom: BorderSide(color: const Color('#222'), width: 2.px),
          ),
          alignItems: AlignItems.center,
          fontSize: 1.3.rem,
        ),
        // One comparison row — a 4-column grid aligned with `.col-headings`:
        // TeX source | KaTeX JS | katex Dart SVG | katex_flutter.
        css('.cmp-row', [
          css('&').styles(
            display: Display.grid,
            padding: Padding.symmetric(vertical: 8.px),
            border: Border.only(
              bottom: BorderSide(color: const Color('#eee'), width: 1.px),
            ),
            alignItems: AlignItems.center,
            gridTemplate: GridTemplate(
              columns: GridTracks([
                GridTrack.repeat(
                  const TrackRepeat(4),
                  [GridTrack(TrackSize.fr(1))],
                ),
              ]),
            ),
            gap: Gap.all(8.px),
          ),
          css('.cmp-source').styles(
            margin: Margin.zero,
            overflow: Overflow.hidden,
            fontSize: 0.85.rem,
          ),
          css('.cmp-source code').styles(
            padding: Padding.symmetric(horizontal: 5.px, vertical: 2.px),
            radius: BorderRadius.circular(4.px),
            color: const Color('#24292f'),
            fontFamily: const FontFamily.list([
              FontFamily('SFMono-Regular'),
              FontFamily('Menlo'),
              FontFamilies.monospace,
            ]),
            backgroundColor: const Color('#f6f8fa'),
          ),
          css('.cmp-cell').styles(
            display: Display.flex,
            minHeight: kCellHeight.px,
            padding: Padding.all(8.px),
            radius: BorderRadius.circular(4.px),
            overflow: Overflow.auto,
            justifyContent: JustifyContent.center,
            alignItems: AlignItems.center,
            backgroundColor: const Color('#fafafa'),
          ),
          // The Flutter host cell: give the embedded view explicit bounds so
          // the Flutter engine has a size to lay out into.
          css('.flutter-cell').styles(
            padding: Padding.zero,
            overflow: Overflow.hidden,
            backgroundColor: const Color('#fff'),
          ),
          css('.flutter-host').styles(
            width: 100.percent,
            height: kCellHeight.px,
          ),
        ]),
        css('.render-error').styles(
          color: const Color('#cc0000'),
          fontSize: 0.75.rem,
        ),
      ];
}

/// Fixed render-cell height (px). The Flutter host div uses this so the
/// embedded multi-view engine has explicit bounds.
const int kCellHeight = 96;
