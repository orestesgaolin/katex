# T-020 — Fix `\sqrt` surd vlist baseline/sizing

**Milestone:** M4  **Status:** review  **Depends on:** T-011, T-014

## Goal
Make `\sqrt` root dimensions match the KaTeX oracle. This is the only gallery entry
whose dimensions diverge (found by T-014's oracle dimension test).

## Symptom (from T-014)
For `sqrt-x` and `sqrt-index-3-x` (identical radicand → identical error):
- root height: ours **0.94028** vs oracle **0.80028** (+0.14em too tall)
- root depth:  ours **0.13972** vs oracle **0.23972** (−0.10em too shallow)
- total extent is close, but the **baseline is shifted up ~0.14em**.

## Likely cause
The `\sqrt` builder's vlist shift / sizing (the `makeSqrt` / `sqrtImage` analogue in
`lib/src/build/builders/sqrt_builder.dart`). The surd glyph + vinculum placement and the
resulting baseline offset don't follow KaTeX's stretchy-surd math. Compare against
`reference/node_modules/katex/src/functions/sqrt.ts` + `delimiter.ts` `sqrtImage` and the
TeXbook rule-11 clearance (`θ + φ/4`), and how KaTeX sets the overall vlist `depth`/
`height` and the baseline (the radicand sits on the baseline; the surd descends to depth).

## Acceptance criteria
- `dart test test/oracle_dimension_test.dart` passes `sqrt-x` and `sqrt-index-3-x` within
  the same tolerance as the rest of the gallery (relative ≤2% or absolute ≤0.01em), so the
  hard dimension gate becomes 26/26 (no more `_knownApprox` exclusions for sqrt).
- No regression on the other 24 entries or the full `dart test` suite.
- If full pixel-accurate stretchy surd is still out of scope, at least the root
  height/depth/baseline must match the oracle (the glyph may remain a fixed-size surd).
