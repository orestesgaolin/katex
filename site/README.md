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
4. **`katex_flutter`** — the `Math` widget, embedded with **`jaspr_flutter_embed`**
   (one shared Flutter engine, one embedded view per cell).

## Quick start

```sh
cd site
flutter pub get
jaspr serve          # dev server → http://localhost:8080
```

Open <http://localhost:8080> **in a real browser**. The KaTeX-JS column hydrates
client-side; the Dart-SVG column is pre-rendered at build time; the
katex_flutter column boots one Flutter engine (CanvasKit/WASM) and mounts a view
per cell.

> The Flutter engine needs a live browser with WebGL/CanvasKit, so the
> katex_flutter column only renders when the site is *served* and opened in a
> real browser — a headless screenshot or `file://` open will not boot it.

Static build:

```sh
cd site
jaspr build          # → build/jaspr/  (includes the compiled Flutter engine)
```

`jaspr build` / `jaspr serve` compile the embedded Flutter automatically (via
`jaspr: flutter: embedded`) — there is **no** separate `flutter build web` step.

## How each column is produced

| Column | Package | Mechanism |
| --- | --- | --- |
| TeX source | — | Plain text + badges in `lib/components/comparison_row.dart`. |
| KaTeX JS | vendored `katex.min.js` | `@client` component (`lib/components/katex_js.dart`) calls `katex.render(tex, host, {displayMode, throwOnError:false})` on hydrate via `js_interop`. |
| katex Dart SVG | `package:katex` (path dep) | `lib/components/dart_svg.dart` calls `renderToSvg(tex)` **at build time** (static mode) and inlines the `<svg>` with `RawText`. No client JS. |
| katex_flutter | `package:katex_flutter` + `jaspr_flutter_embed` | `@client` `FlutterCell` (`lib/components/flutter_cell.dart`) renders `FlutterEmbedView(widget: MathCell(tex, …))`. One shared engine, one view per cell. |

The example set lives in `lib/examples.dart` (grouped by category).

## Flutter embedding: one shared engine via jaspr_flutter_embed

The site uses `jaspr_flutter_embed` (`jaspr: flutter: embedded` in `pubspec.yaml`,
plus `web/flutter_bootstrap.js` with the `{{flutter_js}}` / `{{flutter_build_config}}`
templates). Each row's 4th cell is an `@client` `FlutterCell` that renders a
`FlutterEmbedView` hosting the `MathCell` Flutter widget
(`lib/widgets/math_cell.dart`). All cells share **one** Flutter engine — Jaspr
adds a view per `FlutterEmbedView`.

`MathCell` (and its `package:flutter` imports) is pulled in **web-only** through a
conditional import (`lib/components/math_cell_builder.dart` →
`_web.dart` / `_io.dart`), so the static server prerender never touches Flutter.

### Why one shared engine (not iframes, not a tall gallery iframe)

Earlier iterations:

- **One CanvasKit engine per row, via `<iframe>`**: rendered every glyph and
  aligned per-row, but ~68 engines exhaust the browser's WebGL-context limit —
  cells blank out ("disappear") on click/scroll as contexts get evicted.
- **One full-height gallery iframe**: stable, but its internal layout drifts out
  of vertical alignment with the DOM list.

`jaspr_flutter_embed` uses a **single** engine with one embedded view per cell:
no WebGL-context exhaustion (no disappear-on-click), and each view is its own
grid cell so it lines up by construction.

> Note: the embed uses Flutter web multi-view under the hood. A previous
> *hand-rolled* multi-view attempt showed missing-glyph boxes for some
> KaTeX_Size symbols (`\oint`, `\bigcup`, angle/ceil/floor delimiters); that was
> traced to a hand-rolled bootstrap that didn't load `FontManifest`. This path
> uses the standard `{{flutter_build_config}}` bootstrap (correct font loading) —
> verify the glyph-heavy rows (Delimiters, Big operators) render in a real
> browser.

## Known approximations

Rows that hit a current `katex` MVP approximation (e.g. some sized delimiters /
`\oint` / `\overrightarrow` / `array` rules) are tagged with an `approx` badge so
an expected JS-vs-Dart difference is not mistaken for a bug. Accents (`\hat`,
`\vec`, `\widehat`, …) and `\sqrt[n]` are fixed and **not** marked approx.

## Project layout

```
site/
  pubspec.yaml                 # jaspr (flutter: embedded); deps: katex, katex_flutter, jaspr_flutter_embed
  web/
    katex/                     # vendored katex.min.css/js + fonts (for the JS + SVG columns)
    flutter_bootstrap.js       # {{flutter_js}} {{flutter_build_config}}
  lib/
    main.server.dart           # Document(head: KaTeX css/js)
    main.client.dart           # ClientApp() — hydrates @client components
    app.dart                   # page layout + styles (4-column grid)
    examples.dart              # the comparison example set (grouped by category)
    widgets/
      math_cell.dart           # the embedded Flutter widget (web-only): Math(tex)
    components/
      comparison_row.dart      # one example → TeX source + JS + SVG + Flutter cells
      katex_js.dart            # @client KaTeX-JS interop component
      dart_svg.dart            # build-time renderToSvg + inline SVG
      flutter_cell.dart        # @client FlutterEmbedView host
      math_cell_builder*.dart  # web/io conditional builder for MathCell
```
