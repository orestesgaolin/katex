# T-026 — Fix `\sqrt[n]` index placement

**Milestone:** M6 (correctness)  **Status:** review  **Depends on:** T-011, T-020, T-022

## Problem (side-by-side confirmed)
`\sqrt[3]{x}`: KaTeX tucks the index "3" into the radical's top-left notch (small, low, close
to the surd kink). Ours floats the "3" too far LEFT and too HIGH — detached, more like a loose
superscript. The root box dimensions match the oracle (T-020), but the index *position within*
is wrong.

## Root cause to investigate
`lib/src/build/builders/sqrt_builder.dart` vs KaTeX `src/functions/sqrt.ts`: KaTeX positions the
index with a specific shift — `\sqrt`'s index is raised by `0.6 * (vlistHeight - vlistDepth)`
and kerned so it sits in the surd's crook (negative horizontal kern of `-10/18 em` then the
index, then the surd). Reproduce KaTeX's `\rootBox` placement (the `0.6` factor + the negative
kern before the surd) so the index nests into the radical.

## Acceptance criteria
- Side-by-side (KaTeX JS vs our `renderToSvg`) for `\sqrt[3]{x}` is a close visual match — the
  index sits in the radical notch, not floating left. Attach before/after proof.
- Oracle dimension gate stays 26/26.
- Flutter painter renders it correctly. Full suites green.
