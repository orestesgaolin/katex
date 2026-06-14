# Port KaTeX to Dart — standalone core + Flutter widget

> Adapted from the original monorepo plan (`quiet-baking-neumann`) to this **standalone
> repository**. The melos/monorepo wiring is replaced with a self-contained two-package
> layout driven by an orchestrator + implementation subagents + verification subagents,
> tracked by the local ticket board in `tickets/`.

## Context

We want LaTeX math rendering in Dart that works **without Flutter** (CLI/server/web/SSR)
*and* as a **Flutter widget**. The existing prior art, `flutter_math_fork`, ported the
KaTeX parser to Dart but bolted rendering directly onto Flutter `RenderObject`s — it
cannot render outside Flutter. That Flutter-free capability is exactly the gap this
project fills.

The approach: **fresh port from KaTeX JS** (MIT-licensed), producing a
**backend-agnostic box tree** as the core public API, with an **SVG serializer** for
no-Flutter rendering and a separate **Flutter widget** that paints the same box tree.
Ship a **Core MVP first**, then expand command coverage.

KaTeX's pipeline we are reproducing:
`Lexer → Parser (+ MacroExpander) → parse-node AST → build → box tree`.
KaTeX positions everything with a box model (every box has `height` above and `depth`
below the baseline, plus `width`); glyphs are drawn from bundled fonts (KaTeX_Main,
KaTeX_Math, KaTeX_AMS, …) using `fontMetricsData` (family → charcode →
`[depth, height, italic, skew, width]`, ~150–200 KB); fraction/sqrt bars are filled
rules; stretchy delimiters/accents use SVG path geometry. Fonts are SIL OFL, KaTeX code
is MIT — both permissive to vendor with attribution.

## Repository layout (standalone)

This repo hosts **two independent Dart packages** plus a Node reference oracle. They are
kept as separate packages (rather than a pub workspace) so each can be resolved and
tested independently — `katex` with the Dart SDK, `katex_flutter` with the Flutter SDK.

```
katex/                         # repo root
  PLAN.md                      # this file
  README.md
  LICENSE                      # MIT (project) — vendored asset licenses live beside assets
  tickets/                     # local ticketing system (see tickets/BOARD.md)
  reference/                   # KaTeX vendored via npm + Node/puppeteer oracle harness
    package.json
    pin.json                   # pinned KaTeX version for reproducibility
    gallery.json               # shared test gallery of expressions (source of truth)
    generate_fixtures.mjs      # emits reference PNGs + metrics JSON
    fixtures/                  # checked-in reference PNGs + metrics JSON
  packages/
    katex/                     # pure Dart, ZERO Flutter dependency
    katex_flutter/             # Flutter widget, depends on packages/katex via path
  .github/workflows/
    katex.yml                  # dart: pub get → analyze → test (packages/katex)
    katex_flutter.yml          # flutter: pub get → analyze → test (packages/katex_flutter)
```

---

## Package 1 — `packages/katex` (pure Dart, zero Flutter dependency)

```
packages/katex/
  pubspec.yaml                 # name: katex, sdk ^3.11, lints/very_good_analysis
  lib/katex.dart               # barrel + top-level API
  lib/src/
    parse/    Token, Lexer, MacroExpander, Parser, ParseError,
              SourceLocation, Namespace, Settings
    ast/      parse-node types (port of parseNode.ts)
    symbols/  symbols table, spacingData, unicode tables  (generated where possible)
    font/     fontMetricsData (generated Dart const map), FontMetrics accessor,
              font family/variant enums, font bytes for embedding (generated)
    build/    Options, Style (display/text/script/scriptscript),
              buildCommon, buildExpression, per-group builders (MVP function set)
    box/      backend-agnostic box tree node types  ← PRIMARY PUBLIC MODEL
    svg/      box tree → SVG serializer
  tool/       generators: fontMetricsData.js → Dart, symbols.ts → Dart
  assets/fonts/   vendored KaTeX *.ttf (SIL OFL) + OFL.txt attribution
  bin/katex.dart  small CLI: `dart run katex "\frac{a}{b}" > out.svg`
  test/
```

### Box tree (the core abstraction — `lib/src/box/`)

Backend-agnostic, no HTML/CSS, no Flutter. Each node carries computed
`height`/`depth`/`width`:
- `GlyphNode` — a character in a font family + variant at a size, with italic/skew.
- `HBox` — horizontal list, children advance by width (+ kerning/spacing).
- `VBox` / `VList` — children stacked at explicit vertical shifts.
- `RuleNode` — filled rectangle (fraction bars, sqrt lines, underline).
- `SpanNode` — wrapper carrying color / sizing / class metadata.
- `SvgPathNode` — for stretchy delimiters/accents (later milestone; stub in MVP).

This mirrors KaTeX's `domTree`/`buildCommon` box semantics but drops the DOM. Both the
SVG serializer and the Flutter painter are pure consumers of this tree.

### Top-level API (`lib/katex.dart`)
```dart
BoxNode renderToBox(String tex, {KatexOptions options});   // primary
String  renderToSvg(String tex, {KatexOptions options});   // built on renderToBox
```
`KatexOptions`: displayMode, fontSize, color, macros, strict/error behavior.

### SVG serializer (`lib/src/svg/`)
Walks the box tree → `<text>` for glyphs (font-family + glyph), `<rect>` for rules,
nested `<g transform>` for positioning. Self-containment: embed KaTeX fonts via
`@font-face` data-URI in `<defs><style>` (generated font-bytes const) so output renders
in browsers/librsvg/resvg with no external assets. (Glyph→path extraction is a later
enhancement for environments without font support.)

### Generators (`tool/`)
Dart scripts that read the vendored KaTeX source (`reference/node_modules/katex/...`:
`fontMetricsData.js`, `src/symbols.js`, `src/spacingData.js`) and emit Dart const tables,
so the data stays faithful and regenerable rather than hand-copied.

### MVP command coverage (milestone 1 grammar target)
- **Parsing**: groups `{}`, superscript `^`, subscript `_`, primes, basic macros.
- **Symbols**: letters, digits, Greek, common operators/relations/binops, punctuation.
- **Functions**: `\frac`/`\dfrac`/`\tfrac`, `\sqrt`(+index), big ops `\sum`/`\int`/`\prod`
  with limits, `\left…\right` delimiters, `\text`, accents
  `\hat`/`\bar`/`\vec`/`\tilde`, font cmds `\mathbf`/`\mathrm`/`\mathit`/`\mathbb`/`\mathcal`,
  `\overline`/`\underline`, `\color`/`\textcolor`, size/style commands, basic spacing.
- **Environments**: `matrix`/`pmatrix`/`bmatrix`, `aligned`, `cases`.
- Everything funnels through the box tree so SVG + Flutter both work from day one.

---

## Package 2 — `packages/katex_flutter` (Flutter widget)

```
packages/katex_flutter/
  lib/katex_flutter.dart       # exports Math / SelectableMath-style widget
  lib/src/
    math_widget.dart           # public Math(tex) widget
    render/                    # CustomPainter (or RenderObject) walking BoxNode
    font_mapping.dart          # box font family/variant + style size → TextStyle
  pubspec.yaml                 # depends: katex (path: ../katex); flutter fonts: KaTeX_*
  example/                     # runnable Flutter demo gallery
  test/                        # widget + golden image tests
```
- Depends on `katex`; re-bundles the KaTeX `.ttf` files as **package fonts** (declared
  under `flutter: fonts:` in pubspec) so the painter can draw glyphs via `TextPainter`.
- Painter consumes `BoxNode`: `GlyphNode`→`TextPainter`, `RuleNode`→`canvas.drawRect`,
  `HBox`/`VBox`→positioned child painting. No re-parsing — pure tree consumption.

---

## Verification — golden tests against original KaTeX

The ground truth is **original KaTeX's own rendered output**, not hand-authored
expectations. The Node oracle in `reference/` drives this.

**Reference oracle (`reference/`)** — Node + KaTeX + headless browser (puppeteer) over a
shared, version-pinned **test gallery** (`gallery.json`) of expressions. For each it
emits, into `reference/fixtures/`:
- a **reference PNG** (KaTeX rendered in-browser, screenshot at fixed size/DPR), and
- a **metrics JSON** (KaTeX's internal height/depth/width for the root + key sub-boxes).
KaTeX version is pinned (`reference/pin.json`); regenerating is a single command.

**Core (`packages/katex`)**
- Unit tests on Lexer/Parser asserting AST shape — port KaTeX's own parser test cases.
- Box-dimension tests: our box tree's height/depth/width must match the **metrics JSON**
  within tolerance (catches layout math errors precisely, font-free).
- **SVG golden-vs-KaTeX**: rasterize our SVG (resvg/librsvg or headless browser) → PNG,
  pixel-diff against the KaTeX **reference PNG** for the same expression within a small
  per-pixel tolerance; fail on diff over threshold. Diff images written for inspection.
- CLI smoke test: `dart run katex "\frac{a}{b}"` emits valid SVG.

**Flutter (`packages/katex_flutter`)**
- `flutter_test` golden tests (`matchesGoldenFile`) for the gallery, **with the KaTeX
  reference PNGs as the golden files** so the widget is held to original-KaTeX output,
  within tolerance.
- Runnable `example/` app rendering the gallery for manual review.

Both renderers are measured against the *same* KaTeX-produced fixtures — numerically
(metrics JSON) and visually (reference PNGs).

---

## Milestones

1. **Skeleton + data + oracle**: both package skeletons, CI wiring, generators producing
   `fontMetricsData`/symbols Dart, vendored fonts + attribution, and the KaTeX reference
   harness producing reference PNGs + metrics JSON for the test gallery.
2. **Parser**: Lexer → Parser → AST with MVP grammar; parser tests passing.
3. **Builder + box tree**: parse-node → box tree for MVP commands; dimension tests.
4. **SVG serializer**: box tree → self-contained SVG; gallery snapshots + CLI.
5. **Flutter widget**: painter consuming box tree; golden tests + example app.
6. **Expand**: grow command/environment coverage toward full KaTeX, stretchy
   delimiters/accents via `SvgPathNode`, MathML output (optional, future).

## Orchestration model (how this plan is executed)

- **Orchestrator (superagent)** — owns `PLAN.md` and the `tickets/` board, scaffolds the
  repo, dispatches subagents, integrates their output, and keeps tickets current.
- **Implementation subagents** — each picks up one ticket, implements it against the plan
  and the acceptance criteria in the ticket, and reports back.
- **Verification subagents** — independent agents that run analyze/tests/oracle diffs and
  confirm acceptance criteria are actually met (not just claimed) before a ticket is
  marked `done`. A ticket only moves to `done` after verification passes.

See `tickets/BOARD.md` for current status.

## Risks / notes
- **Scope**: full KaTeX is ~600–800 commands; MVP proves the pipeline, expansion is
  incremental and additive (new builders, no architecture change).
- **Font self-containment** in SVG: data-URI `@font-face` is the MVP path; glyph→path
  extraction is the fallback for non-browser rasterizers (future).
- **Flutter + Dart split**: kept as two independently-resolved packages to avoid mixed
  SDK workspace-resolution issues; `katex_flutter` depends on `katex` via path.
- **Licensing**: KaTeX code MIT, fonts SIL OFL — vendor with attribution files.
