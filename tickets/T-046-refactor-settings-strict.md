# T-046 — Deduplicate `Settings.reportNonstrict` / `useStrictBehavior`

**Milestone:** M9 (refactor/simplify)  **Status:** todo  **Depends on:** —

## Problem
`lib/src/parse/settings.dart` — `reportNonstrict` and `useStrictBehavior` share the entire
strict-resolution + branch ladder (resolve `StrictFunction`, then `false/'ignore'` /
`true/'error'` / `'warn'` / fallback), differing only in try/catch wrapping and throw-vs-return
at the `'error'` branch. The same warning `print(...)` text appears ~4 times.

## Change
Extract a shared `_resolveStrict(...)` returning the resolved mode (`'ignore'|'error'|'warn'`,
or a small enum), plus a single `_warn(code, msg)` for the duplicated warning output. Keep the
two public methods' observable behavior identical (one throws on `'error'`, the other returns a
bool; both warn on `'warn'`).

## Acceptance criteria
- Strict-mode resolution logic single-sourced; warning text single-sourced.
- Public signatures and observable behavior of `reportNonstrict`/`useStrictBehavior` unchanged.
- `dart analyze` clean; `dart test` 304 passing (parser/settings tests cover this).
