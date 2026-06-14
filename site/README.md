# KaTeX renderer comparison site

A static [Jaspr](https://jaspr.site) site that renders every expression in the
comparison gallery **four columns per row, side by side**, so divergences
(spacing, delimiters, accents, fonts) are obvious at a glance. Each row is:

```
TeX source | KaTeX JS | katex Dart → SVG | katex_flutter
```

1. **TeX source** — the LaTeX input (with `display` / `approx` badges).
2. **KaTeX JS** — the original `katex.min.js`, rendered in the browser. Ground truth.
3. **`katex` (pure Dart) → SVG** — `renderToSvg(tex)` output, inlined as `<svg>`.
4. **`katex_flutter`** — the `Math` widget, rendered by its **own per-row
   single-view Flutter-web engine** in a lazy `<iframe>` (one expression per
   iframe — see below).

## Quick start

```sh
cd site/flutter_host && flutter build web --base-href /flutter/ && cd ..
rm -rf web/flutter && cp -r flutter_host/build/web web/flutter   # see "Building the Flutter column"
jaspr serve          # dev server with hot reload → http://localhost:8080
```

Then open <http://localhost:8080> **in a real browser**. The KaTeX-JS column
hydrates client-side; the Dart-SVG column is pre-rendered at build time; each
katex_flutter cell boots a Flutter engine on demand (lazy iframe).

> The Flutter engine needs a live browser with WebGL/CanvasKit. Open the
> **served** URL (`jaspr serve`, or any static server over `build/jaspr/`) — a
> bare `file://` open will not fully boot the engine.

To produce the static site:

```sh
cd site
jaspr build          # → build/jaspr/  (index.html + assets, fully static)
```

> The Flutter web app is **not** built by `jaspr build` — build it separately
> (below) and copy its output into `web/flutter/` *before* running
> `jaspr serve`/`jaspr build`, so the iframes have something to load.

## Building the Flutter column

The fourth column is a tiny **single-expression** Flutter-web app at
[`flutter_host/`](flutter_host) (it depends on `packages/katex_flutter` via path
and bundles the KaTeX glyph fonts). `flutter_host/lib/main.dart` reads `tex`,
`display` and `fontSize` from the page's query string and renders **one**
centered `Math` widget.

```sh
cd site/flutter_host
flutter pub get
flutter build web --base-href /flutter/      # served under /flutter/ in the site
cd ..
rm -rf web/flutter && cp -r flutter_host/build/web web/flutter
```

`web/flutter/` is then served by Jaspr as a static directory; each comparison
row embeds it as `<iframe src="flutter/index.html?tex=…&display=…&fontSize=22">`.

## How each column is produced

| Column | Package | Mechanism |
| --- | --- | --- |
| TeX source | — | Plain text + badges in `lib/components/comparison_row.dart`. |
| KaTeX JS | vendored `katex.min.js` | `@client` component (`lib/components/katex_js.dart`) calls `katex.render(tex, host, {displayMode, throwOnError:false})` on hydrate via `js_interop`. |
| katex Dart SVG | `package:katex` (path dep) | `lib/components/dart_svg.dart` calls `renderToSvg(tex)` **at build time** (static mode) and inlines the `<svg>` with `RawText`. No client JS. |
| katex_flutter | `package:katex_flutter` (via `flutter_host/`) | A per-row lazy `<iframe>` (`comparison_row.dart`) loads `flutter/index.html?tex=…`; `flutter_host` runs a single-view engine rendering that one expression. |

The example set lives in `lib/examples.dart` (grouped by category).

### Vendored assets

`web/katex/` holds `katex.min.css`, `katex.min.js` and `fonts/`, copied
unmodified from `reference/node_modules/katex/dist`. The stylesheet is loaded
from `<head>` (see `lib/main.server.dart`); it supplies the `KaTeX_*` `@font-face`
families used by **both** the KaTeX-JS output and the inlined Dart SVGs.

> **SVG font note:** `renderToSvg` normally emits a self-contained SVG that
> re-embeds the entire KaTeX font set (~470 KB) per call. Inlining 60+ of those
> would make the page tens of MB. Because this page already loads
> `katex.min.css` (same `KaTeX_*` families), `dart_svg.dart` strips the
> per-SVG `<defs><style>@font-face…</style></defs>` block, shrinking each
> inlined SVG to <1 KB with identical rendering. This is a site-level
> optimisation only — `package:katex` itself is unchanged.

## Flutter embedding: one single-view engine per row (lazy iframes)

Each katex_flutter cell is its **own** `<iframe>` running a **single-view**
Flutter engine (`runApp`) that renders just that row's expression
(`flutter/index.html?tex=…`). The iframe is absolutely positioned to fill its
grid cell, so it lines up with the TeX / JS / SVG cells **by construction** —
the iframe *is* the cell. Iframes use `loading="lazy"`, so only engines near the
viewport instantiate as you scroll.

### Why per-row single-view (not multi-view, not one big iframe)

Two earlier approaches each failed one requirement:

- **Multi-view** (one engine, one `View` per row, no iframe): CanvasKit in
  multi-view renders a class of math symbols as **missing-glyph boxes** even
  though the app font covers them — `\oint`/`\bigcup` (KaTeX_Size2), `\cdot`
  (U+22C5), and the angle/ceil/floor delimiters `⟨⟩⌈⌉⌊⌋`. The same expressions
  render correctly in a single-view engine. Preloading fonts, forcing CanvasKit,
  and `fontFamilyFallback` did not fix it.
- **One full-height iframe** rendering the whole gallery (single-view, glyphs
  OK): the iframe's internal layout drifts out of vertical alignment with the
  DOM list (two independent layout engines), so rows stop lining up partway down.

**Per-row single-view iframes** fix both: single-view → every glyph renders;
one iframe per grid cell → exact alignment, no height-matching needed. The cost
is many engines, bounded by `loading="lazy"` (only near-viewport rows boot).
Each iframe loads `flutter/index.html` (engine assets cached after the first),
which also gives it the correct `<base href="/flutter/">` so the bundled
`KaTeX_*` fonts load from `flutter/assets/`.

> **Needs a live browser** — the engines download CanvasKit/WASM and use WebGL,
> so the column only renders when the site is *served* and opened in a real
> browser. A `file://` open will not boot them.

## Known approximations

Rows that hit a current `katex` MVP approximation (e.g. some sized delimiters /
`\oint` / `\overrightarrow` / `array` rules) are tagged with an `approx` badge so
an expected JS-vs-Dart difference is not mistaken for a bug. Accents (`\hat`,
`\vec`, `\widehat`, …) and `\sqrt[n]` were fixed and are **not** marked approx —
they should match KaTeX JS.

## Project layout

```
site/
  pubspec.yaml                 # jaspr; depends on ../packages/katex (path)
  analysis_options.yaml        # jaspr_lints
  web/
    katex/                     # vendored katex.min.css/js + fonts
    flutter/                   # `flutter build web` output (generated; see above)
  lib/
    main.server.dart           # Document(head: KaTeX css/js)
    main.client.dart           # ClientApp() — hydrates @client components
    app.dart                   # page layout + styles (4-column grid)
    examples.dart              # the comparison example set (grouped by category)
    components/
      comparison_row.dart      # one example → TeX source + JS + SVG + Flutter-iframe cells
      katex_js.dart            # @client KaTeX-JS interop component
      dart_svg.dart            # build-time renderToSvg + inline SVG
  flutter_host/                # single-EXPRESSION Flutter-web app (reads ?tex= from the URL)
    lib/main.dart              # runApp — one centered Math widget for the query's tex
```
