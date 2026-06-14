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
4. **`katex_flutter`** — the `Math` widget, rendered **inline per row** by an
   embedded Flutter-web engine running in **multi-view** mode (one engine, one
   Flutter `View` per row — see below).

## Quick start

```sh
cd site/flutter_host && flutter build web --base-href /flutter/ && cd ..
rm -rf web/flutter && cp -r flutter_host/build/web web/flutter   # see "Building the Flutter column"
jaspr serve          # dev server with hot reload → http://localhost:8080
```

Then open <http://localhost:8080> **in a real browser**. The KaTeX-JS column
hydrates client-side; the Dart-SVG column is pre-rendered at build time; the
katex_flutter column boots a single CanvasKit/WASM Flutter engine and attaches
one Flutter view to each row's host `<div>`.

> The Flutter multi-view engine needs a live browser with WebGL/CanvasKit. Open
> the **served** URL (`jaspr serve`, or any static server over `build/jaspr/`) —
> a bare `file://` open will not fully boot the engine.

To produce the static site:

```sh
cd site
jaspr build          # → build/jaspr/  (index.html + assets, fully static)
```

> The Flutter web app is **not** built by `jaspr build` — build it separately
> (below) and copy its output into `web/flutter/` *before* running
> `jaspr serve`/`jaspr build`, so the engine has something to load.

## Building the Flutter column

The fourth column is a small Flutter-web app at [`flutter_host/`](flutter_host)
running in **multi-view** mode (it depends on `packages/katex_flutter` via path
and bundles the KaTeX glyph fonts).

```sh
cd site/flutter_host
flutter pub get
flutter build web --base-href /flutter/      # served under /flutter/ in the site
cd ..
rm -rf web/flutter && cp -r flutter_host/build/web web/flutter
```

`web/flutter/` is then served by Jaspr as a static directory; the site boots the
engine once via [`web/flutter_embed.js`](web/flutter_embed.js) and attaches one
view per row.

## How each column is produced

| Column | Package | Mechanism |
| --- | --- | --- |
| TeX source | — | Plain text + badges in `lib/components/comparison_row.dart`. |
| KaTeX JS | vendored `katex.min.js` | `@client` component (`lib/components/katex_js.dart`) calls `katex.render(tex, host, {displayMode, throwOnError:false})` on hydrate via `js_interop`. |
| katex Dart SVG | `package:katex` (path dep) | `lib/components/dart_svg.dart` calls `renderToSvg(tex)` **at build time** (static mode) and inlines the `<svg>` with `RawText`. No client JS. |
| katex_flutter | `package:katex_flutter` (via `flutter_host/`) | One Flutter-web engine in multi-view mode; an `@client` `FlutterView` component attaches one Flutter view per row via `window.__katexFlutter.add(...)`. |

The example set lives in `lib/examples.dart` (grouped by category). The Flutter
host no longer needs its own copy — each view's expression is passed at runtime
as `initialData` (see below), so there is a single source of truth.

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

## Flutter embedding: multi-view (one engine, one view per row)

The katex_flutter column uses **Flutter web multi-view embedding**: a *single*
Flutter engine boots once for the whole page, and the site attaches **one
Flutter `View` per comparison row** directly into that row's host `<div>` in the
Jaspr DOM. There are **no iframes**. This is what makes the Flutter cell a true
inline 4th column — it sits in the same CSS grid row as the TeX / JS / SVG cells
for the same expression.

### How the wiring fits together

1. **Dart side — `flutter_host/lib/main.dart`.** `main()` calls `runWidget(...)`
   (not `runApp`) with a multi-view root. The root listens to
   `PlatformDispatcher.onMetricsChanged` (fired when views are added/removed),
   maps every entry of `platformDispatcher.views` to a `View(view: ...)` widget,
   and renders them with `ViewCollection`. For each view it reads the per-view
   config via `dart:ui_web` `ui_web.views.getInitialData(viewId)` — a JS object
   `{tex, displayMode, fontSize}` — and renders `Math(tex, ...)` from
   `package:katex_flutter`, centered on white, with an `onError` fallback. Each
   view is sized by its host `<div>` (the Jaspr `.flutter-host` cell sets the
   bounds).

2. **JS bootstrap (once) — `web/flutter_embed.js`.** Loaded once from the
   document head (see `lib/main.server.dart`). It fetches the generated
   `flutter/flutter_bootstrap.js` (which defines the loader **and** sets
   `_flutter.buildConfig` — pinned to the SDK + this build's `engineRevision`),
   strips its trailing auto `_flutter.loader.load(...)` call so the engine does
   not boot in single-view mode, then drives the loader itself:

   ```js
   _flutter.loader.load({
     config: { entrypointBaseUrl: "flutter/", canvasKitBaseUrl: "flutter/canvaskit/" },
     onEntrypointLoaded: async (init) => {
       const appRunner = await init.initializeEngine({ multiViewEnabled: true });
       const app = await appRunner.runApp();
       window.__katexFlutter = {
         add: (hostEl, data) => app.addView({ hostElement: hostEl, initialData: data }), // -> viewId
         remove: (id) => app.removeView(id),
       };
     },
   });
   ```

   `add(hostElement, {tex, displayMode, fontSize})` returns a `Promise<viewId>`.
   Registrations made before the engine is ready are queued and flushed on
   ready. Fetching the generated bootstrap (rather than hardcoding buildConfig)
   keeps this robust across `flutter build web` rebuilds.

3. **Jaspr bridge — `lib/components/flutter_view.dart`.** A `@client` `FlutterView`
   component renders an empty fixed-size host `<div class="flutter-host">`. On
   hydrate (client only) it calls
   `window.__katexFlutter.add(hostDiv, {tex, displayMode, fontSize})` via
   `js_interop` (`package:universal_web`, guarded by `kIsWeb`), passing the row's
   tex/displayMode. It stores the returned `viewId` and calls `remove(viewId)` on
   dispose so hot-reload / re-hydration don't leak views.

### Trade-offs

- **One engine, many views** — far lighter than one iframe (engine) per row, and
  unlike a single shared iframe the Flutter cells live in the page's own DOM and
  scroll with it, so they stay aligned with the other three columns.
- **Needs a live browser** — the engine downloads CanvasKit/WASM and uses WebGL,
  so the column only renders when the site is *served* and opened in a real
  browser (verified headlessly via Chromium with software WebGL). A `file://`
  open will not boot it.
- **`engineRevision`** comes from the freshly-built `flutter_bootstrap.js`; just
  rebuild the Flutter app (above) whenever you bump the Flutter SDK.

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
    flutter_embed.js           # boots the Flutter engine (multi-view) + bridge
    flutter/                   # `flutter build web` output (generated; see above)
  lib/
    main.server.dart           # Document(head: KaTeX css/js + flutter_embed.js)
    main.client.dart           # ClientApp() — hydrates @client components
    app.dart                   # page layout + styles (4-column grid)
    examples.dart              # the comparison example set (grouped by category)
    components/
      comparison_row.dart      # one example → TeX source + JS + SVG + Flutter cells
      katex_js.dart            # @client KaTeX-JS interop component
      dart_svg.dart            # build-time renderToSvg + inline SVG
      flutter_view.dart        # @client component → addView() per row (multi-view)
  flutter_host/                # Flutter-web app for the katex_flutter column
    lib/main.dart              # multi-view root (runWidget + View per row)
```
