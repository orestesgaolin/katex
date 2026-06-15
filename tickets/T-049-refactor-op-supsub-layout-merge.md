# T-049 — Merge duplicated op / supsub side-script layout

**Milestone:** M9 (refactor/simplify)  **Status:** todo  **Depends on:** —
**Risk:** HIGH — needs careful before/after verification (deferred from the M9 wave).

## Problem
`_buildOpSideSupSub` in `lib/src/build/builders/op_builders.dart` (~142-274) is a
near-verbatim copy of the generic side-script path in `buildSupSub`
(`lib/src/build/builders/supsub_builder.dart` ~39-219): same `minSupShift` switch, same
sup/sub shift formulas, same rule-18e clamp + psi correction, same three-branch VList
(both / sub-only / sup-only), same `marginRight = (0.5/ptPerEm)/sizeMultiplier`, same
`subMarginLeft = -italic`. ~120 lines duplicated.

## Why it was deferred
The ONLY real difference is how the base symbol + italic correction is obtained:
- op path: the op base carries `opBase.italic` directly.
- supsub path: unwraps the built base via `_baseSymbol` to recover the glyph + `scaledItalic`.
Getting this distinction wrong silently mis-places integral bounds / sub-/superscripts,
which the oracle dimension gate may not fully catch — so it needs visual + numeric checks.

## Change
Extract one shared helper, e.g.
`buildSideSupSub({required BoxNode base, BoxNode? sup, BoxNode? sub, required double baseItalic, required bool isCharBox, required Options options})`
(in `build_common.dart` or a new shared file). Have both callers compute their base +
italic, then delegate. Remove the duplicated body from `_buildOpSideSupSub`.

## Acceptance criteria
- Single shared side-script layout helper; `_buildOpSideSupSub`'s duplicated body removed.
- Emitted box trees byte-identical for both paths (verify with a spread of cases:
  `x^2_3`, `\int_0^1`, `\oint`, `\sum` nolimits in textstyle, slanted-base sub tuck).
- `dart analyze` clean; `dart test` 304 passing; oracle dimension gate 26/26; golden mean
  diff unchanged (0.1559); `katex_flutter` 62 tests still green.
