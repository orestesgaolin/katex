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

## Licensing

Project code: MIT. Ported from KaTeX (MIT). Vendored fonts: SIL OFL. See `LICENSE`.
