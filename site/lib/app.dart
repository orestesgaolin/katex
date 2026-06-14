/// The comparison site root.
///
/// Layout: a header, a legend, then for every category a heading followed by
/// the comparison rows. Each row shows the TeX source plus two live renders —
/// **KaTeX JS** (ground truth, hydrated client-side) and **katex Dart SVG**
/// (pre-rendered at build time). The third renderer, **katex_flutter**, is a
/// single full-height Flutter-web iframe pinned beside the list (one Flutter
/// engine for the whole page — see README for the trade-off), whose rows use
/// the same `kRowHeight` and ordering so they line up.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'components/comparison_row.dart';
import 'examples.dart';

/// Heading height (px) used in both the HTML list and the Flutter gallery so
/// the two stay vertically aligned.
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
          .text(' Math widget (Flutter web).'),
        ]),
        div(classes: 'legend', [
          span(classes: 'badge mode', [.text('display')]),
          .text(' display-mode expression  '),
          span(classes: 'badge approx', [.text('approx')]),
          .text(' known MVP approximation — expected JS/Dart difference, not a bug.'),
        ]),
      ]),
      div(classes: 'compare', [
        // Left: the JS + Dart-SVG comparison list.
        div(classes: 'list-col', [
          div(classes: 'col-headings', [
            div(classes: 'col-head source-head', [.text('TeX source')]),
            div(classes: 'col-head', [.text('KaTeX JS')]),
            div(classes: 'col-head', [.text('katex Dart SVG')]),
          ]),
          for (final ExampleGroup group in kGroups)
            .fragment([
              h2(
                classes: 'group-heading',
                styles: Styles(height: kHeadingHeight.px),
                [.text(group.title)],
              ),
              for (final Example ex in group.examples)
                div(
                  styles: Styles(minHeight: kRowHeight.px),
                  [ComparisonRow(ex)],
                ),
            ]),
        ]),
        // Right: a single Flutter-web engine rendering the whole gallery.
        div(classes: 'flutter-col', [
          div(classes: 'col-head flutter-head', [.text('katex_flutter')]),
          iframe(
            const [],
            src: 'flutter/index.html',
            loading: MediaLoading.lazy,
            classes: 'flutter-frame',
            attributes: const {'title': 'katex_flutter gallery'},
          ),
        ]),
      ]),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
        css('.page').styles(
          maxWidth: 1400.px,
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
        // Two-panel compare layout: list + sticky flutter frame.
        css('.compare').styles(
          display: Display.flex,
          flexDirection: FlexDirection.row,
          alignItems: AlignItems.start,
          gap: Gap.all(16.px),
        ),
        css('.list-col').styles(
          minWidth: Unit.zero,
          flex: const Flex(grow: 1, shrink: 1, basis: Unit.zero),
        ),
        css('.flutter-col', [
          css('&').styles(
            position: Position.sticky(top: 8.px),
            width: 340.px,
            flex: const Flex(grow: 0, shrink: 0),
          ),
          css('.flutter-frame').styles(
            width: 100.percent,
            height: 80.vh,
            border: Border.all(color: const Color('#ddd'), width: 1.px),
            radius: BorderRadius.circular(6.px),
            backgroundColor: const Color('#fff'),
          ),
        ]),
        // Column heading strip above the list.
        css('.col-headings').styles(
          display: Display.grid,
          padding: Padding.symmetric(vertical: 8.px),
          gridTemplate: GridTemplate(
            columns: GridTracks([
              GridTrack.repeat(
                const TrackRepeat(3),
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
        css('.flutter-head').styles(margin: Margin.only(bottom: 8.px)),
        css('.group-heading').styles(
          display: Display.flex,
          margin: Margin.zero,
          border: Border.only(
            bottom: BorderSide(color: const Color('#222'), width: 2.px),
          ),
          alignItems: AlignItems.center,
          fontSize: 1.3.rem,
        ),
        // One comparison row.
        css('.cmp-row', [
          css('&').styles(
            padding: Padding.symmetric(vertical: 8.px),
            border: Border.only(
              bottom: BorderSide(color: const Color('#eee'), width: 1.px),
            ),
          ),
          css('.cmp-source').styles(
            margin: Margin.only(bottom: 6.px),
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
          css('.cmp-cells').styles(
            display: Display.grid,
            gridTemplate: GridTemplate(
              columns: GridTracks([
                GridTrack.repeat(
                  const TrackRepeat(2),
                  [GridTrack(TrackSize.fr(1))],
                ),
              ]),
            ),
            gap: Gap.all(8.px),
          ),
          css('.cmp-cell').styles(
            display: Display.flex,
            minHeight: 56.px,
            padding: Padding.all(8.px),
            radius: BorderRadius.circular(4.px),
            overflow: Overflow.auto,
            justifyContent: JustifyContent.center,
            alignItems: AlignItems.center,
            backgroundColor: const Color('#fafafa'),
          ),
        ]),
        css('.render-error').styles(
          color: const Color('#cc0000'),
          fontSize: 0.75.rem,
        ),
        // Stack columns on narrow screens.
        css.media(MediaQuery.screen(maxWidth: 900.px), [
          css('.compare').styles(flexDirection: FlexDirection.column),
          css('.flutter-col').styles(
            position: Position.static,
            width: 100.percent,
          ),
        ]),
      ];
}
