# T-032 — `.gitignore` was ignoring `lib/src/build/` source (never committed)

**Milestone:** M1 (fix)  **Status:** done  **Depends on:** —

## Problem (found during T-031)
`.gitignore` had a bare `build/` rule (intended for Dart/Flutter build **output**). Git treats
that as "any directory named `build` at any depth" — so it also ignored the package **source**
directory `packages/katex/lib/src/build/`. Result: **16 core source files were never committed**
(`build_common.dart`, `build_expression.dart`, `katex_options.dart`, and every builder:
`genfrac`, `op`, `sqrt`, `accent`, `supsub`, `delimiter`, `styling`, `symbol`, `array`, `units`,
`builders.dart`). A fresh clone would not compile — the whole AST→box-tree builder layer was
missing from git history.

## Fix
`.gitignore`:
```
build/
!**/lib/src/build/
```
The negation re-includes any `lib/src/build/` source dir while build OUTPUT dirs
(`packages/*/build/`, `site/build/`, etc.) stay ignored. Verified with `git check-ignore`:
`lib/src/build/build_common.dart` is no longer ignored; `packages/katex/build/...` still is.

## Acceptance
- `git check-ignore packages/katex/lib/src/build/build_common.dart` → not ignored.
- `git check-ignore packages/katex/build/x` → still ignored.
- The 16 source files are added to git (first time) in the same commit as the T-031 fixes.
- No other `.dart` source is wrongly ignored.
