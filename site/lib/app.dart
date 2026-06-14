/// The comparison site root.
///
/// Layout: a header, a legend, then for every category a heading followed by the
/// comparison rows. Each row is a 4-column grid —
/// **TeX source | KaTeX JS | katex Dart SVG | katex_flutter** — so all four
/// renderers sit side by side for the same expression. The Flutter cell is a
/// per-row lazy `<iframe>` running its own single-view engine (see
/// `comparison_row.dart` / README for why per-row, not one multi-view engine).
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'components/comparison_row.dart';
import 'components/editor.dart';
import 'examples.dart';

/// Heading height (px).
const int kHeadingHeight = 48;

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
          .text(' Math widget (Flutter web, one engine per row).'),
        ]),
        div(classes: 'legend', [
          span(classes: 'badge mode', [.text('display')]),
          .text(' display-mode expression  '),
          span(classes: 'badge approx', [.text('approx')]),
          .text(' known MVP approximation — expected JS/Dart difference, not a bug.'),
        ]),
      ]),
      // SITE-2: live editor above the comparison table.
      const Editor(),
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
          maxWidth: 1500.px,
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
        css('.compare').styles(
          display: Display.flex,
          flexDirection: FlexDirection.column,
        ),
        // The shared 4-column grid: TeX source | JS | Dart SVG | Flutter.
        css('.col-headings').styles(
          display: Display.grid,
          padding: Padding.symmetric(vertical: 8.px),
          gridTemplate: GridTemplate(
            columns: GridTracks([
              GridTrack(TrackSize.fr(1.2)),
              GridTrack(TrackSize.fr(1)),
              GridTrack(TrackSize.fr(1)),
              GridTrack(TrackSize.fr(1)),
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
        // One comparison row: the 4-column grid.
        css('.cmp-row', [
          css('&').styles(
            display: Display.grid,
            padding: Padding.symmetric(vertical: 8.px),
            border: Border.only(
              bottom: BorderSide(color: const Color('#eee'), width: 1.px),
            ),
            gridTemplate: GridTemplate(
              columns: GridTracks([
                GridTrack(TrackSize.fr(1.2)),
                GridTrack(TrackSize.fr(1)),
                GridTrack(TrackSize.fr(1)),
                GridTrack(TrackSize.fr(1)),
              ]),
            ),
            gap: Gap.all(8.px),
            alignItems: AlignItems.stretch,
          ),
          // Column 1: TeX source.
          css('.cmp-source').styles(
            display: Display.flex,
            padding: Padding.symmetric(horizontal: 4.px),
            alignItems: AlignItems.center,
            flexWrap: FlexWrap.wrap,
            fontSize: 0.8.rem,
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
          // Columns 2-4: render cells.
          css('.cmp-cell').styles(
            display: Display.flex,
            minHeight: kRowMinHeight.px,
            padding: Padding.all(8.px),
            radius: BorderRadius.circular(4.px),
            overflow: Overflow.auto,
            justifyContent: JustifyContent.center,
            alignItems: AlignItems.center,
            backgroundColor: const Color('#fafafa'),
          ),
          // Flutter cell: override the .cmp-cell flex-centering (which collapses
          // the embed host to content height, leaving the flutter-view 0px tall)
          // with a block whose child fills the grid-stretched cell. The cell is
          // stretched to the row height (set by the JS/SVG cells), so a height:100%
          // chain down to the FlutterEmbedView host gives the view a real height.
          //
          // SITE-clip: the embedded Flutter view is sized to its DOM host's box,
          // and the math is vertically centred inside it. The row height is set
          // by the JS/SVG cells, so the host must be at least as tall as the
          // *full* Flutter math (height + DEPTH — descenders, fraction
          // denominators, `cases`). `overflow:visible` lets the view paint past
          // the (stretched) cell box if a row is slightly shorter than the math,
          // so nothing is clipped along the bottom. The flutter column now also
          // renders at the JS em-scale (see MathCell), so heights track closely.
          css('.flutter-cell', [
            css('&').styles(
              display: Display.block,
              minHeight: kRowMinHeight.px,
              padding: Padding.zero,
              overflow: Overflow.visible,
              position: const Position.relative(),
            ),
            // FlutterEmbedView wrapper (div) + the loading placeholder.
            css('& > *').styles(width: 100.percent, height: 100.percent),
            css('.flutter-loading').styles(minHeight: kRowMinHeight.px),
          ]),
        ]),
        css('.render-error').styles(
          color: const Color('#cc0000'),
          fontSize: 0.75.rem,
        ),
      ];
}
