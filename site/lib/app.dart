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
import 'components/site_nav.dart';
import 'examples.dart';

/// Heading height (px).
const int kHeadingHeight = 48;

/// The comparison page (`/`) — the original three-way comparison table plus the
/// live editor. Now fronted by the shared [SiteNav]. Kept named `App` so the
/// existing `@css` styles and entrypoints continue to apply.
class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'page', [
      const SiteNav(active: SiteRoute.comparison),
      header(classes: 'site-header', [
        div(classes: 'header-top', [
          h1([.text('KaTeX renderer comparison')]),
          a(
            classes: 'gh-link',
            [.text('GitHub ↗')],
            href: 'https://github.com/orestesgaolin/katex',
            attributes: const {'target': '_blank', 'rel': 'noopener noreferrer'},
          ),
        ]),
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
      section(classes: 'intro', [
        p([
          strong([.text('katex')]),
          .text(' is a fresh Dart port of '),
          a(
            [.text('KaTeX')],
            href: 'https://katex.org',
            attributes: const {'target': '_blank', 'rel': 'noopener'},
          ),
          .text('. It parses LaTeX math into a backend-agnostic '),
          strong([.text('box tree')]),
          .text(', then renders that one tree two ways: to '),
          strong([.text('SVG with no Flutter dependency')]),
          .text(' (CLI / server / web / SSR) and as a '),
          strong([.text('Flutter widget')]),
          .text('. This page renders every example three ways — original '
              'KaTeX (JS), our Dart → SVG, and the Flutter widget — side by '
              'side, so divergences are obvious at a glance.'),
        ]),
        p([
          .text('How it differs from existing packages: tools like '),
          em([.text('flutter_math_fork')]),
          .text(' bolt rendering directly onto Flutter render objects and '
              "can't run outside Flutter. "),
          strong([.text('katex')]),
          .text(' instead keeps a shared, backend-agnostic box tree as its '
              'core, so the exact same layout drives both the no-Flutter SVG '
              'output and the Flutter widget — and box dimensions are verified '
              'against original KaTeX.'),
        ]),
        p([
          .text('That portable core is reused elsewhere: '),
          strong([.text('mermaid dart')]),
          .text(', a pure-Dart port of mermaid.js, renders the TeX math labels '
              'in its diagrams with '),
          strong([.text('katex')]),
          .text('.'),
        ]),
        p(classes: 'intro-links', [
          a(
            [.text('See the mermaid dart comparison →')],
            href: 'https://orestesgaolin.github.io/mermaid/',
            attributes: const {'target': '_blank', 'rel': 'noopener noreferrer'},
          ),
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
      footer(classes: 'foot', [
        p([
          .text('Each row renders the same TeX three ways — KaTeX JS '
              '(ground truth), katex Dart → SVG, and katex_flutter — so any '
              'divergence is visible at a glance.'),
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
          // Title row: heading on the left, GitHub pill on the right.
          css('.header-top').styles(
            display: Display.flex,
            flexWrap: FlexWrap.wrap,
            gap: Gap.all(12.px),
            alignItems: AlignItems.baseline,
            justifyContent: JustifyContent.spaceBetween,
          ),
          css('h1').styles(
            margin: Margin.only(bottom: 4.px),
            color: const Color('#1a4fa0'),
            fontSize: 2.4.rem,
          ),
          css('.subtitle').styles(
            margin: Margin.only(top: 4.px, bottom: .zero),
            color: const Color('#555566'),
            fontSize: 1.05.rem,
          ),
          css('.legend').styles(
            margin: Margin.only(top: 10.px),
            color: const Color('#555'),
            fontSize: 0.85.rem,
          ),
        ]),
        // GitHub pill in the header (shared shape with the mermaid site).
        css('.gh-link', [
          css('&').styles(
            padding: Padding.symmetric(horizontal: 14.px, vertical: 6.px),
            radius: BorderRadius.circular(16.px),
            border: Border.all(color: const Color('#b9ccef'), width: 1.px),
            color: const Color('#1a4fa0'),
            backgroundColor: const Color('#ffffff'),
            textDecoration: const TextDecoration(line: TextDecorationLine.none),
            fontSize: 0.95.rem,
            fontWeight: FontWeight.w600,
            whiteSpace: WhiteSpace.noWrap,
          ),
          css('&:hover').styles(backgroundColor: const Color('#eef3ff')),
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
        // "Report issue" link — small/subtle, used in comparison rows and the
        // live editor.
        css('.issue-link', [
          css('&').styles(
            margin: Margin.symmetric(horizontal: 4.px),
            color: const Color('#999'),
            textDecoration: const TextDecoration(line: TextDecorationLine.none),
            fontSize: 0.7.rem,
          ),
          css('&:hover').styles(
            color: const Color('#cc0000'),
            textDecoration: const TextDecoration(
              line: TextDecorationLine.underline,
            ),
          ),
        ]),
        // Intro / "what is this" section above the editor.
        css('.intro', [
          css('&').styles(
            maxWidth: 880.px,
            margin: Margin.only(bottom: 24.px),
          ),
          css('p').styles(
            margin: Margin.only(bottom: 10.px),
            color: const Color('#444'),
            fontSize: 1.rem,
            lineHeight: 1.6.em,
          ),
          css('a').styles(color: const Color('#1a4fa0')),
          css('.intro-links').styles(margin: Margin.only(top: 8.px)),
          // Primary call-to-action button (accent-filled).
          css('.intro-links a', [
            css('&').styles(
              display: Display.inlineBlock,
              padding: Padding.symmetric(horizontal: 16.px, vertical: 8.px),
              radius: BorderRadius.circular(8.px),
              color: const Color('#ffffff'),
              backgroundColor: const Color('#1a4fa0'),
              fontSize: 0.95.rem,
              fontWeight: FontWeight.w600,
              textDecoration: const TextDecoration(line: TextDecorationLine.none),
            ),
            css('&:hover').styles(backgroundColor: const Color('#143d7d')),
          ]),
        ]),
        // Footer (shared shape with the mermaid site).
        css('.foot').styles(
          margin: Margin.only(top: 32.px),
          padding: Padding.only(top: 16.px),
          border: Border.only(
            top: BorderSide(color: const Color('#e2e2e2'), width: 1.px),
          ),
          color: const Color('#777788'),
          fontSize: 0.9.rem,
        ),
      ];
}
