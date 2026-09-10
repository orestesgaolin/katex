# T-051 — Automatic line breaking for long expressions

**Milestone:** M6 (coverage)  **Status:** done  **Depends on:** T-011, T-017
**Risk:** LOW — additive; the default (`maxWidth: infinity`) takes the pre-existing
fast path unchanged.

## Problem
A long expression rendered on one line overflows its parent, with no way to wrap it.
KaTeX has the same limitation *by design*: `buildHTML` does not wrap, it only emits
break **opportunities** — it splits the top-level expression into unbreakable `.base`
spans and lets the **browser** wrap between them via CSS inline-block flow. The box
tree has no CSS and no browser, so the second half of that job was simply missing.

The chunking metadata was already all there — `mbin`/`mrel`/`allowbreak`/`nobreak`/
`mspace` classes are carried on `SpanNode.classes` by the existing builders — and
`buildHTML` already stacked explicit `\\` breaks in a `VList`. Only the wrapping pass
and a width budget were absent.

## Change
- **`lib/src/build/line_breaker.dart`** (new):
  - `chunkAtBreakOpportunities` — a faithful port of KaTeX's `buildHTML` chunking loop:
    break only after a top-level `mbin`/`mrel`/`\allowbreak`; post-operator glue rides
    on the operator's chunk; a `\nobreak` (or `~`) in that glue suppresses the
    opportunity. TeXBook [p.173].
  - `packChunksIntoLines` — greedy first-fit packing to an em budget, i.e. what the
    browser would have done.
  - "Outer level" is free: this only ever sees the **top-level** box list, so an
    operator inside `{...}`, a fraction or `\left…\right` has already been folded into
    one box and is never a candidate.
- **`buildHTML`** takes `maxWidth` (em, default `infinity`). Explicit `\\` segments are
  split first, then each segment is wrapped; a `\\[size]` skip stays attached below the
  last line its segment produces. One resulting line ⇒ the bare `katex-html` span, so a
  budget nothing overflows is indistinguishable from no budget.
- **`KatexOptions.maxWidth`** (em) plumbed through `renderToBox`/`renderToSvg`.
- **`Math(softWrap: true)`** wraps to the incoming constraint via `LayoutBuilder`;
  `Math(maxWidth: px)` sets an explicit pixel budget and wins over `softWrap`. The px→em
  conversion subtracts the `kInkOverflowPadEm` pad on both sides so the painted canvas
  fits the budget, and a non-finite or degenerate (≤ 0) budget disables wrapping rather
  than emitting one chunk per line.

## Deliberate non-goals
- **No re-breaking of unbreakable runs.** A single `\frac` wider than the budget
  overflows rather than being cut — there is no legal break point inside it (TeX reports
  an overfull box in the same situation).
- **Greedy, not Knuth-Plass.** No badness minimisation across the paragraph; a browser
  is greedy here too, and matching it keeps us faithful to the KaTeX reference.
- **`AnimatedMath` and `mathSpan` are not covered.** `AnimatedMath` renders its box
  outside layout, and a `WidgetSpan` cannot break internally in a host paragraph.

## Acceptance criteria
- [x] Breaks only after a top-level `mbin`/`mrel`/`\allowbreak`; the operator ends the
      line and never starts the next one.
- [x] Never breaks inside `{...}`, a fraction, or `\left…\right`.
- [x] `\nobreak` suppresses the opportunity; `\allowbreak` creates one.
- [x] Composes with explicit `\\`, including the `\\[size]` skip.
- [x] `maxWidth: infinity` (the default) is byte-for-byte the old fast path.
- [x] `dart analyze --fatal-infos` clean; `dart test` **324 passing / 1 skipped**
      (303 before + 21 new); oracle dimension gate still **26/26**.
- [x] `flutter analyze` clean; `flutter test` 71 passing / 1 skipped + 10 new widget
      tests. The 26 gallery goldens fail identically before and after the change
      (verified against a stashed pristine tree: `aligned` 0.74%/536px, `cases`
      1.18%/850px) — the documented Windows anti-aliasing diffs, not a regression.
