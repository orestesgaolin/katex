/// Shared header navigation linking the two site pages.
///
/// Rendered at the top of both routes (`/` comparison and `/supported`
/// catalog). Uses **base-relative** hrefs (`''` for home, `supported` for the
/// catalog) so they resolve against the page's `<base href>` and keep working
/// when the site is deployed under the `/katex/` sub-path on GitHub Pages.
///
/// These are plain full-page `<a>` links (not client-side SPA navigation): the
/// site is a static multi-page build where each route is its own pre-rendered
/// HTML file, and the home route hosts `@client` KaTeX-JS islands plus embedded
/// Flutter engines that must boot fresh per page load.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Identifies which route is currently active, to highlight its nav link.
enum SiteRoute { comparison, supported }

/// The shared top navigation bar.
class SiteNav extends StatelessComponent {
  const SiteNav({required this.active, super.key});

  /// The currently-active route (its link is marked `aria-current`).
  final SiteRoute active;

  @override
  Component build(BuildContext context) {
    return nav(classes: 'site-nav', [
      a(
        // `.` resolves against the page's <base href> to the site root (`/` or
        // `/katex/`), so the home link works from `/supported/` and under the
        // Pages sub-path. (An empty href would point at the current document.)
        href: '.',
        classes: active == SiteRoute.comparison ? 'nav-link active' : 'nav-link',
        attributes: active == SiteRoute.comparison ? const {'aria-current': 'page'} : const {},
        [.text('Comparison')],
      ),
      a(
        href: 'supported',
        classes: active == SiteRoute.supported ? 'nav-link active' : 'nav-link',
        attributes: active == SiteRoute.supported ? const {'aria-current': 'page'} : const {},
        [.text('Supported functions')],
      ),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
        css('.site-nav', [
          css('&').styles(
            display: Display.flex,
            padding: Padding.symmetric(vertical: 12.px),
            margin: Margin.only(bottom: 8.px),
            border: Border.only(
              bottom: BorderSide(color: const Color('#e2e2e2'), width: 1.px),
            ),
            gap: Gap.all(8.px),
            alignItems: AlignItems.center,
          ),
          css('.nav-link', [
            css('&').styles(
              padding: Padding.symmetric(horizontal: 12.px, vertical: 6.px),
              radius: BorderRadius.circular(6.px),
              color: const Color('#1a4fa0'),
              textDecoration: const TextDecoration(line: TextDecorationLine.none),
              fontSize: 0.95.rem,
              fontWeight: FontWeight.w500,
            ),
            css('&:hover').styles(backgroundColor: const Color('#eef3ff')),
            css('&.active').styles(
              color: const Color('#fff'),
              backgroundColor: const Color('#1a4fa0'),
            ),
          ]),
        ]),
      ];
}
