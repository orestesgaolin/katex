# katex (Dart)

A fresh port of [KaTeX](https://katex.org) to Dart that renders LaTeX math **without
Flutter** (CLI / server / web / SSR) via a backend-agnostic **box tree** + SVG serializer,
and as a **Flutter widget** that paints the same box tree.

> Status: **in active development.** See [`PLAN.md`](PLAN.md) for the architecture and
> [`tickets/BOARD.md`](tickets/BOARD.md) for live progress.

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
