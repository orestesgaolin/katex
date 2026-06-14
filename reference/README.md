# Reference oracle (`reference/`)

This directory is the **ground-truth oracle** for the "Port KaTeX to Dart" project. It
renders a shared test gallery with the **original, version-pinned KaTeX** (JavaScript)
and emits the fixtures every Dart test is measured against — both numerically
(box-tree metrics) and visually (reference PNGs).

The KaTeX version is pinned in [`pin.json`](./pin.json) (currently **0.17.0**) and is the
single source of truth all fixtures are generated from.

## Layout

```
reference/
  package.json            # deps: katex (pinned), puppeteer, pngjs, pixelmatch
  pin.json                # the resolved KaTeX version
  gallery.json            # the shared test gallery: [{ id, tex, displayMode }]
  generate_fixtures.mjs   # the harness — produces the fixtures below
  fixtures/
    png/<id>.png          # KaTeX rendered in a headless browser, screenshotted
    metrics/<id>.json     # KaTeX's internal box-tree height/depth/width per node
```

## Regenerating the fixtures

```sh
cd reference
npm install            # installs the pinned KaTeX + puppeteer (downloads Chromium)
node generate_fixtures.mjs
```

This writes one PNG (`fixtures/png/<id>.png`) and one metrics file
(`fixtures/metrics/<id>.json`) for every entry in `gallery.json`.

The output is **deterministic**: running the script twice produces byte-identical
metrics JSON *and* byte-identical PNGs (verified in CI / by hand via
`shasum fixtures/metrics/*.json` before and after a second run).

## The gallery (`gallery.json`)

An array of `{ id, tex, displayMode }`. `id` is a stable kebab/snake identifier used as
the fixture filename; `tex` is the LaTeX source; `displayMode` selects KaTeX display vs
inline mode. It covers the MVP grammar: fractions, super/subscripts, roots (with index),
big operators with limits (`\sum`/`\int`/`\prod`), `\left…\right`, accents
(`\hat`/`\bar`/`\vec`/`\tilde`), font commands (`\mathbf`/`\mathbb`/`\mathcal`),
`\overline`/`\underline`, Greek, `\cdot`, `\text`, and the `pmatrix`/`bmatrix`/`aligned`/
`cases` environments.

## What the fixtures are

### `fixtures/png/<id>.png` — visual ground truth

KaTeX's `renderToString(tex, { displayMode, throwOnError: true })` markup, dropped into a
minimal HTML page, rendered in **headless Chromium (puppeteer)** at a fixed
`devicePixelRatio` of **2**, and screenshotted at the `.katex` element's bounding box.
KaTeX's CSS is **inlined** into the page (see note below) and its `@font-face` rules are
rewritten to load the bundled fonts from `node_modules/katex/dist/fonts/` directly — so
rendering is offline and uses the exact KaTeX fonts, not a browser fallback.

These PNGs are the golden images for the SVG pixel-diff tests (`packages/katex`) and the
Flutter `matchesGoldenFile` tests (`packages/katex_flutter`).

### `fixtures/metrics/<id>.json` — numeric ground truth

Each file contains:

- `id`, `tex`, `displayMode`, `katexVersion` — provenance.
- `root` — the root box's `type`, `classes`, and `height`/`depth`/`width` (em units).
- `boxes` — a flattened walk of KaTeX's internal **visual** box tree. Each entry has a
  `path` (a stable structural path like
  `root/0:katex/1:katex-html/0:base/1:mord/1:mfrac/…`), the node `type`
  (`Span`/`SymbolNode`/…), its `classes`, and `height`/`depth`/`width` in em units.
- `boxCount` — number of boxes recorded.
- `pixelBox` — the rendered `.katex` element's pixel `width`/`height` (complementary
  signal; see fallback note).
- `dpr` — the devicePixelRatio used for the screenshot (2).

The Dart box tree's computed `height`/`depth`/`width` must match the em-unit values in
`boxes`/`root` within tolerance — this catches layout-math errors precisely and
font-independently.

## How metrics are extracted

KaTeX exposes an internal `katex.__renderToDomTree(tex, settings)` that returns a tree of
`domTree` nodes (`Span`, `SymbolNode`, …), each carrying `.height` / `.depth` / `.width`
in **em units** — the very numbers KaTeX uses to lay out boxes. This is the **primary**
metrics source. The harness:

- walks **only** the visual `.katex-html` subtree and skips the parallel
  `.katex-mathml` (accessibility MathML) subtree, which carries no usable layout metrics;
- records `width` as `null` where KaTeX leaves it `undefined` (KaTeX advances most
  horizontal lists via CSS rather than explicit widths, so `width` is only present on a
  subset of nodes such as `SymbolNode` glyphs);
- rounds em metrics to 5 decimals and pixel metrics to 3 decimals, and recursively sorts
  all JSON keys, so output is byte-stable across runs.

**Fallback (documented):** if `__renderToDomTree` were ever unavailable in the installed
KaTeX, the harness still emits a metrics file marked `fallback: true` containing the live
DOM `pixelBox` (from `getBoundingClientRect()` on `.katex`) as the degraded signal. With
KaTeX 0.17.0 the primary path is used (`fallback: false`) and `pixelBox` is included
alongside it as a sanity cross-check.

### Implementation note: CSS is inlined, not linked

The page inlines KaTeX's CSS into a `<style>` tag rather than referencing it via
`<link href="file://…/katex.min.css">`. In headless Chromium a `file://` stylesheet link
reports as loaded but its rules silently fail to apply — which left the `.katex-mathml`
hide rule inactive and leaked the invisible MathML text into the screenshots. Inlining
the CSS applies all rules reliably and keeps font loading offline.
