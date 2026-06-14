# T-024 — Jaspr comparison site: KaTeX JS vs KaTeX Dart, side by side

**Milestone:** M7 (demo/docs site)  **Status:** todo  **Depends on:** T-012, T-017, T-002

## Goal
A new **static [Jaspr](https://jaspr.site) site** that renders, **side by side for each
example**, the three renderers so they can be visually compared at a glance:
1. **KaTeX JS** (the original, in-browser via `katex.min.js` + `katex.min.css`) — the ground truth.
2. **`katex` (pure Dart)** — the `renderToSvg` output, inlined as `<svg>`.
3. **`katex_flutter`** — the `Math` widget, via **Flutter web embedding** in the page.

Served/dev'd with **`jaspr serve`**; buildable as a static site (`jaspr build`).

## Why
Turns the verification story into something a human can eyeball: every expression shows
original KaTeX next to both Dart backends, making divergences (spacing, delimiters, accents,
fonts) obvious and giving the project a living demo/docs page.

## Suggested layout
```
site/                              # new Jaspr app (or packages/katex_site/)
  pubspec.yaml                     # jaspr; depends on ../packages/katex (path) for SVG
  jaspr.yaml / jaspr config        # static mode (SSG) where possible
  web/                             # katex.min.css + katex.min.js (vendored from reference/) ;
                                   #   Flutter web build output mounted here
  lib/
    main.dart                      # Jaspr entrypoint
    components/
      comparison_row.dart          # one example → 3 columns (JS | Dart SVG | Flutter)
      katex_js.dart                # JS-interop component calling katex.render(tex, el, opts)
      dart_svg.dart                # inlines renderToSvg(tex) output
      flutter_view.dart            # embeds the Flutter Math widget for this tex
    examples.dart                  # the comprehensive example set (see below)
  flutter_host/                    # small Flutter-web app exposing Math(tex) for embedding
```

## Comprehensive example set
Go well beyond the 26-entry gallery. Group by category with the TeX source shown under each
row. Reuse `reference/gallery.json` and extend it. Categories to cover:
- Fractions: `\frac`, `\dfrac`, `\tfrac`, `\cfrac`, `\binom`, nested fractions.
- Scripts: `x^2`, `x_i`, `x^2_i`, `{}^{n}C_k`, multi-level, primes.
- Roots: `\sqrt{x}`, `\sqrt[3]{x}`, nested radicals.
- Big operators: `\sum`/`\int`/`\prod`/`\bigcup`/`\oint` with/without limits, display vs inline.
- Delimiters: `\left(...\right)`, `\left[`, `\left\{`, `\langle`, `\lceil`, sized `\bigl`…`\Biggr`.
- Accents: `\hat`/`\bar`/`\vec`/`\tilde`/`\widehat`/`\widetilde`/`\overline`/`\underline`/`\overrightarrow`.
- Fonts: `\mathbf`/`\mathrm`/`\mathit`/`\mathbb`/`\mathcal`/`\mathfrak`/`\mathsf`/`\mathtt`/`\boldsymbol`.
- Colors/sizing/styling: `\color`/`\textcolor`, `\displaystyle`/`\scriptstyle`, size cmds.
- Text & spacing: `\text{…}`, `\,`/`\;`/`\quad`/`\qquad`.
- Environments: `matrix`/`pmatrix`/`bmatrix`/`Bmatrix`/`vmatrix`, `aligned`, `cases`, `array`.
- Real-world formulas: quadratic formula, Euler's identity, a Maxwell equation, a CDF, a sum
  identity, a continued fraction — the kind of thing seen in docs.
Both inline (`displayMode:false`) and display (`displayMode:true`) variants where relevant.
Mark/group expressions that hit known MVP approximations (stretchy delimiters/accents, T-019)
so the Dart vs JS difference is expected and labelled, not mistaken for a bug.

## Implementation notes
- **Jaspr skills**: use `/jaspr-fundamentals` (components), `/jaspr-js-interop` (KaTeX JS +
  Flutter embed bridge), `/jaspr-pre-rendering-and-hydration` (static mode: pre-render the
  Dart-SVG column at build time since `renderToSvg` is pure Dart and runs server-side/SSG;
  hydrate the JS + Flutter columns client-side), and `/jaspr-styling`.
- **KaTeX JS column**: vendor `katex.min.js` + `katex.min.css` (and fonts) from
  `reference/node_modules/katex/dist` into `web/`; call `katex.render(tex, host, {displayMode})`
  via JS interop on a `@client` component (or pre-render with the existing puppeteer harness as
  a fallback static image).
- **Dart SVG column**: call `package:katex`'s `renderToSvg(tex, options)` and inline the SVG.
  In static mode this can run at build time (no client JS needed) — cleanest path.
- **Flutter embedding**: build a minimal Flutter-web app (`flutter_host/`) that renders `Math`
  for a tex passed in (e.g. via URL query/`flutter.js` engine initializer or a JS-callable
  entrypoint), `flutter build web`, and embed it in the Jaspr page (iframe per row, or a single
  Flutter view driven by JS interop / Flutter's multi-view embedding). Document the chosen
  embedding mechanism and its trade-offs (iframe isolation vs single-engine multiview).
- Keep CSS so the three columns align on a shared baseline and are clearly labelled
  (JS / Dart-SVG / Flutter) with the TeX source.

## Acceptance criteria
- `cd site && jaspr serve` runs and serves the comparison page locally; `jaspr build` produces a
  static site.
- For a comprehensive example set (categories above; ≥ the 26 gallery entries, ideally more),
  each row shows all three renderers side by side with the TeX source.
- The KaTeX JS column renders via real KaTeX; the Dart-SVG column via `package:katex`; the
  Flutter column via the embedded `Math` widget — all visibly rendering (not blank/error).
- Known-approx expressions are labelled so expected JS-vs-Dart differences aren't read as bugs.
- A short `site/README.md` documents `jaspr serve`, the Flutter-web build step, and the
  embedding approach.
- No changes required to `packages/katex` / `packages/katex_flutter` public APIs (the site is a
  pure consumer); if a small export is genuinely needed, note it.
