# katex (Dart)

A fresh port of [KaTeX](https://katex.org) to Dart that renders LaTeX math **without
Flutter** (CLI / server / web / SSR) via a backend-agnostic **box tree** + SVG serializer,
and as a **Flutter widget** that paints the same box tree.

**🔎 Live demo:** <https://orestesgaolin.github.io/katex/> — every expression rendered three
ways side by side (KaTeX JS · katex Dart→SVG · katex_flutter), with a live editor.

> Status: **in active development.** See [`PLAN.md`](PLAN.md) for the architecture and
> [`tickets/BOARD.md`](tickets/BOARD.md) for live progress.
>
> **pub.dev note:** the names `katex` and `katex_flutter` are already taken on pub.dev, so
> these packages are currently unpublished (`publish_to: none`). Publishing would require a
> rename (e.g. `katex_dart`).

## Packages

| Package | Path | Description |
|---------|------|-------------|
| `katex` | [`packages/katex`](packages/katex) | Pure Dart, zero Flutter dep. Parser → box tree → SVG. |
| `katex_flutter` | [`packages/katex_flutter`](packages/katex_flutter) | Flutter widget painting the box tree. |

## Reference oracle

[`reference/`](reference) vendors a pinned KaTeX via npm and renders a shared test gallery
to **reference PNGs + metrics JSON**. Both Dart renderers are verified against these
original-KaTeX fixtures (numerically and visually).

## Quick start (once the core MVP lands)

```sh
cd packages/katex
dart pub get
dart run katex "\frac{a}{b}" > out.svg
```

## Comparison with other Flutter math libraries

Two established options take very different approaches from this one.

### vs `flutter_math` / `flutter_math_fork`

[`flutter_math`](https://github.com/simpleclub/flutter_math) (now unmaintained) and its active
community fork [`flutter_math_fork`](https://pub.dev/packages/flutter_math_fork) are the closest
analog: like this project, **their TeX parser is a Dart port of KaTeX's parser**. The two diverge in
*how they render*, which is the main reason this project exists.

| | flutter_math(_fork) | this project (`katex` + `katex_flutter`) |
|---|---|---|
| TeX parser | KaTeX parser ported to Dart | KaTeX parser freshly ported to Dart |
| Layout / rendering | KaTeX layout reimplemented directly on Flutter **`RenderObject`s** | KaTeX layout ported to a **backend-agnostic box tree**, then SVG *or* a Flutter painter |
| Runs without Flutter | No — Flutter-coupled | **Yes** — pure-Dart `katex` renders to **SVG** with zero Flutter dependency (CLI / server / web / SSR) |
| Output targets | Flutter widgets only | **SVG** (pure Dart) **and** a Flutter widget |
| Flutter web | tested on the legacy DomCanvas renderer; ["expected to break with CanvasKit"](https://github.com/simpleclub/flutter_math) | renders on **CanvasKit** (`TextPainter` + `Canvas`); the demo site embeds it via CanvasKit |
| Selection / copy / TeX round-trip | **Yes** (`SelectableMath`, experimental) | not yet |
| Coverage / maturity | **mature** — near-complete KaTeX coverage, years of development | **MVP** — broad but still growing (stretchy geometry, full macro set, more environments are incremental) |
| Verification | — | layout **verified against original KaTeX** — per-box dimensions vs a pinned-KaTeX oracle (26/26), plus visual diffs |
| Maintenance | original unmaintained; fork active | new / active |

### vs `flutter_tex`

[`flutter_tex`](https://pub.dev/packages/flutter_tex) is **MathJax-based** (not KaTeX) and takes a
fundamentally different architecture. It renders either through a **WebView** (`TeXView`, for rich
HTML/JS/document content) or, more recently, by turning MathJax output into SVG drawn with
`flutter_svg` (`Math2SVG`/`TeXWidget`). It supports a much **broader** input surface — LaTeX,
MathML, AsciiMath, chemistry, even HTML/JS — and is mature and well-maintained, but it **bundles the
MathJax engine/assets** (and a WebView platform for `TeXView`), so it is heavier and Flutter-bound.

This project is the opposite trade-off: a **native Dart port of KaTeX** — no JS engine, no WebView,
no bundled MathJax — with a small footprint, focused on the KaTeX command set, and, uniquely, a
**pure-Dart SVG path that runs without Flutter at all** (server / CLI / SSR), verified numerically
against KaTeX.

### Which to use?

- Rich documents, HTML/MathJax features, MathML/AsciiMath, or the widest notation coverage →
  **`flutter_tex`**.
- A mature, lightweight **KaTeX** Flutter widget with text selection → **`flutter_math_fork`**.
- LaTeX **without Flutter** (SVG on a server/CLI/SSR), or a fresh KaTeX port verified against KaTeX
  with a CanvasKit-friendly Flutter widget → **this project**. The backend-agnostic box tree is the
  core abstraction; SVG and Flutter are just two consumers of it.

## Licensing

Project code: MIT. Ported from KaTeX (MIT). Vendored fonts: SIL OFL. See `LICENSE`.
