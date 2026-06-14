/// The entrypoint for the **server** environment (build-time pre-rendering).
///
/// In static mode `main` runs at build time to emit the HTML. The Dart-SVG
/// column is fully produced here (pure-Dart `renderToSvg`); the KaTeX-JS
/// column is hydrated client-side and needs the vendored `katex.min.css` +
/// `katex.min.js` loaded from `<head>`.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';

import 'app.dart';
import 'main.server.options.dart';

void main() {
  Jaspr.initializeApp(options: defaultServerOptions);

  runApp(Document(
    title: 'KaTeX renderer comparison',
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
    body: const App(),
  ));
}
