/// The entrypoint for the **server** environment (build-time pre-rendering).
///
/// In static mode `main` runs at build time to emit the HTML. The Dart-SVG
/// column is fully produced here (pure-Dart `renderToSvg`); the KaTeX-JS
/// column is hydrated client-side and needs the vendored `katex.min.css` +
/// `katex.min.js` loaded from `<head>`.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_router/jaspr_router.dart';

import 'app.dart';
import 'components/supported_page.dart';
import 'main.server.options.dart';

/// The base href the static site is served under.
///
/// Defaults to `/` for local `jaspr serve` (served at the domain root). The
/// GitHub Pages build overrides it via `jaspr build --dart-define=BASE_HREF=/katex/`
/// so every relative asset URL (client JS/CSS, vendored KaTeX, and the embedded
/// Flutter engine + canvaskit + fonts, which all resolve against `document.baseURI`)
/// loads correctly under the `orestesgaolin.github.io/katex/` sub-path.
const String _baseHref = String.fromEnvironment('BASE_HREF', defaultValue: '/');

void main() {
  Jaspr.initializeApp(options: defaultServerOptions);

  runApp(Document(
    title: 'KaTeX renderer comparison',
    base: _baseHref,
    head: [
      // Vendored KaTeX stylesheet (fonts referenced relatively from web/katex).
      link(rel: 'stylesheet', href: 'katex/katex.min.css'),
      // Vendored KaTeX JS — exposes the global `katex` object used by the
      // KatexJs client component on hydrate. `defer` keeps it non-blocking.
      script(src: 'katex/katex.min.js', defer: true),
      // Flutter engine bootstrap (defines window._flutter). jaspr_flutter_embed
      // does NOT auto-inject this — it must be included explicitly, or every
      // FlutterEmbedView throws "Unexpected null value" (flutter!.loader! is
      // null) and the katex_flutter column stays blank.
      script(src: 'flutter_bootstrap.js', async: true),
    ],
    styles: [
      css('html, body').styles(
        width: 100.percent,
        minHeight: 100.vh,
        padding: .zero,
        margin: .zero,
        color: const Color('#1a1a1a'),
        fontFamily: const FontFamily.list([
          FontFamily('-apple-system'),
          FontFamily('Segoe UI'),
          FontFamily('Roboto'),
          FontFamilies.sansSerif,
        ]),
      ),
    ],
    // The site is a static multi-page build. Wrapping the body in a [Router]
    // makes `jaspr build` (generate mode) register and emit one HTML file per
    // route — `/index.html` (comparison) and `/supported/index.html` (catalog)
    // — each pre-rendering the page that matches its URL. Navigation between
    // them is plain full-page `<a>` links (see SiteNav), which keeps the home
    // page's `@client` KaTeX-JS islands and per-row embedded Flutter engines
    // booting freshly per load. The `<base href>`, KaTeX css/js and
    // flutter_bootstrap.js above stay in `<head>` for BOTH routes.
    body: Router(routes: [
      Route(path: '/', title: 'KaTeX renderer comparison', builder: (context, state) => const App()),
      Route(
        path: '/supported',
        title: 'Supported functions · KaTeX comparison',
        builder: (context, state) => const SupportedPage(),
      ),
    ]),
  ));
}
