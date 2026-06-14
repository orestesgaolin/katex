# KaTeX renderer comparison site

A static [Jaspr](https://jaspr.site) site that renders every expression in the
comparison gallery **three ways, side by side**, so divergences (spacing,
delimiters, accents, fonts) are obvious at a glance:

1. **KaTeX JS** — the original `katex.min.js`, rendered in the browser. Ground truth.
2. **`katex` (pure Dart) → SVG** — `renderToSvg(tex)` output, inlined as `<svg>`.
3. **`katex_flutter`** — the `Math` widget, via an embedded Flutter-web app.

## Quick start

```sh
cd site
jaspr serve          # dev server with hot reload → http://localhost:8080
```

Then open <http://localhost:8080> in a browser. The KaTeX-JS column hydrates
client-side; the Dart-SVG column is pre-rendered; the Flutter column loads in an
iframe.

To produce the static site:

```sh
cd site
jaspr build          # → build/jaspr/  (index.html + assets, fully static)
```

> The Flutter web app is **not** built by `jaspr build` — build it separately
> (below) and copy its output into `web/flutter/` *before* running
> `jaspr serve`/`jaspr build`, so the iframe has something to load.

## Building the Flutter column

The third column is a small Flutter-web app at [`flutter_host/`](flutter_host)
that renders the whole gallery as a scrollable column of `Math` widgets (it
depends on `packages/katex_flutter` via path and bundles the KaTeX glyph fonts).

```sh
cd site/flutter_host
flutter pub get
flutter build web --base-href /flutter/      # served under /flutter/ in the site
cd ..
rm -rf web/flutter && cp -r flutter_host/build/web web/flutter
```

`web/flutter/` is then served by Jaspr as a static directory and embedded via a
single `<iframe src="flutter/index.html">`.

## How each column is produced

| Column | Package | Mechanism |
| --- | --- | --- |
| KaTeX JS | vendored `katex.min.js` | `@client` component (`lib/components/katex_js.dart`) calls `katex.render(tex, host, {displayMode, throwOnError:false})` on hydrate via `js_interop`. |
| katex Dart SVG | `package:katex` (path dep) | `lib/components/dart_svg.dart` calls `renderToSvg(tex)` **at build time** (static mode) and inlines the `<svg>` with `RawText`. No client JS. |
| katex_flutter | `package:katex_flutter` (via `flutter_host/`) | A single Flutter-web app rendering the whole gallery, embedded as one iframe. |

The example set lives in `lib/examples.dart` (grouped by category) and is
mirrored verbatim into `flutter_host/lib/examples.dart` so all three columns
share the same expressions in the same order. **If you edit one, copy it to the
other** (`cp lib/examples.dart flutter_host/lib/examples.dart`) and rebuild the
Flutter app.

### Vendored assets

`web/katex/` holds `katex.min.css`, `katex.min.js` and `fonts/`, copied
unmodified from `reference/node_modules/katex/dist`. The stylesheet is loaded
from `<head>` (see `lib/main.server.dart`); it supplies the `KaTeX_*` `@font-face`
families used by **both** the KaTeX-JS output and the inlined Dart SVGs.

> **SVG font note:** `renderToSvg` normally emits a self-contained SVG that
> re-embeds the entire KaTeX font set (~470 KB) per call. Inlining 50+ of those
> would make the page tens of MB. Because this page already loads
> `katex.min.css` (same `KaTeX_*` families), `dart_svg.dart` strips the
> per-SVG `<defs><style>@font-face…</style></defs>` block, shrinking each
> inlined SVG to <1 KB with identical rendering. This is a site-level
> optimisation only — `package:katex` itself is unchanged and still emits
> self-contained SVGs.

## Flutter embedding: chosen mechanism & trade-offs

**Chosen: one Flutter-web app for the whole gallery, embedded as a single
iframe**, laid out beside the JS/SVG list. The Flutter gallery mirrors the same
category headings and per-row heights (`kHeadingHeight` = 64 px,
`kRowHeight` = 120 px) and the same example order, so its rows line up with the
KaTeX-JS / Dart-SVG rows next to it.

Why this and not the alternatives:

- **One iframe = one Flutter engine for the entire page.** Reliable and
  comparatively light. The engine boots once and paints all rows.
- **One iframe per row (rejected):** each iframe is a *separate Flutter engine*
  (megabytes of runtime + a CanvasKit/WASM download each). With ~56 rows this is
  prohibitively heavy and flaky; would need aggressive lazy-loading to even
  start.
- **Flutter multi-view embedding into the Jaspr DOM (rejected for now):** the
  tightest integration (real per-cell Flutter views in the grid), but more
  fragile to wire up across the Jaspr/Flutter bootstrap boundary than a plain
  iframe. The iframe is the pragmatic, robust choice.

**Trade-off of the single iframe:** the Flutter column is isolated in its own
scrolling document, so it does not share the outer page's scroll. The row
heights are matched so corresponding rows align horizontally, but on very long
scrolls the two can drift; the iframe has its own scrollbar. This is the
deliberate cost of the reliable single-engine approach.

## Known approximations

Rows that hit a current `katex` MVP approximation (e.g. some stretchy
delimiters / `\oint` / `\overrightarrow` / `array` rules) are tagged with an
`approx` badge so an expected JS-vs-Dart difference is not mistaken for a bug.
Accents (`\hat`, `\vec`, `\widehat`, …) and `\sqrt[n]` were fixed and are **not**
marked approx — they should match KaTeX JS.

## Project layout

```
site/
  pubspec.yaml                 # jaspr; depends on ../packages/katex (path)
  analysis_options.yaml        # jaspr_lints (sort_children_last disabled — see file)
  web/
    katex/                     # vendored katex.min.css/js + fonts
    flutter/                   # `flutter build web` output (generated; see above)
  lib/
    main.server.dart           # Document(head: KaTeX css/js), static entrypoint
    main.client.dart           # ClientApp() — hydrates @client components
    app.dart                   # page layout + styles
    examples.dart              # the comparison example set (grouped by category)
    components/
      comparison_row.dart      # one example → TeX source + JS + SVG cells
      katex_js.dart            # @client KaTeX-JS interop component
      dart_svg.dart            # build-time renderToSvg + inline SVG
  flutter_host/                # Flutter-web app for the katex_flutter column
    lib/main.dart              # scrollable Math-widget gallery
    lib/examples.dart          # mirror of ../lib/examples.dart
```
