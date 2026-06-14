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
4. **`katex_flutter`** — the `Math` widget, rendered by a **single** Flutter-web
   engine embedded as one **full-height inline column** (an `<iframe>` that
   stretches to the list's height and scrolls with the page, mirroring the row
   heights so the cells line up — see below).

## Quick start

```sh
cd site/flutter_host && flutter build web --base-href /flutter/ && cd ..
rm -rf web/flutter && cp -r flutter_host/build/web web/flutter   # see "Building the Flutter column"
jaspr serve          # dev server with hot reload → http://localhost:8080
```

Then open <http://localhost:8080> **in a real browser**. The KaTeX-JS column
hydrates client-side; the Dart-SVG column is pre-rendered at build time; the
katex_flutter column is a single CanvasKit/WASM Flutter engine (one `<iframe>`)
rendering the whole gallery.

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
> `jaspr serve`/`jaspr build`, so the engine has something to load.

## Building the Flutter column

The fourth column is a small single-view Flutter-web app at
[`flutter_host/`](flutter_host) (it depends on `packages/katex_flutter` via path
and bundles the KaTeX glyph fonts). It renders the whole gallery as a column of
`Math` widgets whose row/heading heights mirror the HTML list.

```sh
cd site/flutter_host
flutter pub get
flutter build web --base-href /flutter/      # served under /flutter/ in the site
cd ..
rm -rf web/flutter && cp -r flutter_host/build/web web/flutter
```

`web/flutter/` is then served by Jaspr as a static directory and embedded as a
single `<iframe src="flutter/index.html">` (see `lib/app.dart`).

## How each column is produced

| Column | Package | Mechanism |
| --- | --- | --- |
| TeX source | — | Plain text + badges in `lib/components/comparison_row.dart`. |
| KaTeX JS | vendored `katex.min.js` | `@client` component (`lib/components/katex_js.dart`) calls `katex.render(tex, host, {displayMode, throwOnError:false})` on hydrate via `js_interop`. |
| katex Dart SVG | `package:katex` (path dep) | `lib/components/dart_svg.dart` calls `renderToSvg(tex)` **at build time** (static mode) and inlines the `<svg>` with `RawText`. No client JS. |
| katex_flutter | `package:katex_flutter` (via `flutter_host/`) | One single-view Flutter-web engine renders the whole gallery; embedded as a single full-height `<iframe>` in column 4 (`lib/app.dart`). |

The example set lives in `lib/examples.dart` (grouped by category); the Flutter
host keeps a matching copy in `flutter_host/lib/examples.dart` so both render the
same expressions in the same order (and the rows line up).

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

## Flutter embedding: one single-view engine, full-height inline column

The katex_flutter column is a **single-view** Flutter-web app (`runApp`) that
renders the whole gallery as a column of `Math` widgets, embedded as **one
`<iframe>`** that stretches to the full height of the comparison list (CSS
`align-items: stretch` + the iframe filling the column). Because the iframe is
as tall as the list and its rows use the same heights in the same order, it
scrolls with the page and lines up row-for-row with the TeX / JS / SVG cells —
an inline column, not a separate scroll box.

### Why single-view (not multi-view)

An earlier version used Flutter **multi-view** embedding (one engine, one
`View` per row, no iframe). It turned out CanvasKit in multi-view renders a
class of math symbols as **missing-glyph boxes** even though the app font covers
them — e.g. `\oint`/`\bigcup` (KaTeX_Size2), `\cdot` (U+22C5), and the angle /
ceil / floor delimiters (`⟨⟩⌈⌉⌊⌋`). The *same* expressions render correctly in a
single-view engine (and in the Dart-SVG column). Preloading fonts, forcing the
CanvasKit renderer, and adding `fontFamilyFallback` did not fix the multi-view
case; switching to one single-view engine did. (Per-row iframes — one engine
each — would also render correctly but 50+ engines is far too heavy; one
single-view engine for the whole gallery is the light, correct middle ground.)

- **Needs a live browser** — the engine downloads CanvasKit/WASM and uses WebGL,
  so the column only renders when the site is *served* and opened in a real
  browser (verified headlessly via Chromium with software WebGL). A `file://`
  open will not boot it.
- **Alignment** is by construction (matched `kHeadingHeight` / `kRowHeight` and
  example order in `flutter_host/lib/main.dart` ↔ `lib/app.dart`); very tall
  display rows can drift slightly since heights are `min-height`.

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
  analysis_options.yaml        # jaspr_lints
  web/
    katex/                     # vendored katex.min.css/js + fonts
    flutter/                   # `flutter build web` output (generated; see above)
  lib/
    main.server.dart           # Document(head: KaTeX css/js)
    main.client.dart           # ClientApp() — hydrates @client components
    app.dart                   # page layout + styles (list grid + flutter iframe column)
    examples.dart              # the comparison example set (grouped by category)
    components/
      comparison_row.dart      # one example → TeX source + JS + SVG cells
      katex_js.dart            # @client KaTeX-JS interop component
      dart_svg.dart            # build-time renderToSvg + inline SVG
  flutter_host/                # single-view Flutter-web app for the katex_flutter column
    lib/main.dart              # runApp — whole gallery as a column of Math widgets
    lib/examples.dart          # matching example set (same order as lib/examples.dart)
```
