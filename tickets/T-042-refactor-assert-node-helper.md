# T-042 — Unify duplicated `_assert*Node` type-guards into one generic helper

**Milestone:** M9 (refactor/simplify)  **Status:** todo  **Depends on:** —

## Problem
The pattern `if (node is X) return node; throw ParseError('Expected node of type X, but got ${node.type}')`
is copy-pasted across at least four files:
- `lib/src/functions/functions.dart` (`_assertTextord`, `_assertSize`, `_assertColorToken`, `_assertRaw`, `_assertUrl`)
- `lib/src/functions/enclose.dart` (`_assertColorToken` — dup)
- `lib/src/functions/includegraphics.dart` (`_assertRaw` — dup)
- `lib/src/environments/array.dart` (`_assertSymbolNode`, `_assertTextord`, `_assertOrdgroup`, `_assertStyling`)

## Change
Add one generic helper `T assertNodeType<T extends ParseNode>(ParseNode node, String label)`
(in a shared spot — `function_spec.dart` or a small parse-node helper file), returning
`node is T ? node : throw ParseError('Expected node of type $label, but got ${node.type}')`.
Replace every per-type/per-file copy with a call to it. Preserve the slightly different
"symbol group type" wording for the array symbol assert by passing it as the `label`.

## Acceptance criteria
- All duplicated `_assert*` helpers removed; single generic helper used at every call site.
- Error messages for each call site preserve the same node-type label as before.
- `dart analyze` clean; full `dart test` still 304 passing (no regressions, goldens 26/26).
