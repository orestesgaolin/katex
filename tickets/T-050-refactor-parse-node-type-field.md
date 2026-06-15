# T-050 — Migrate parse-node `type` string to a single source of truth

**Milestone:** M9 (refactor/simplify)  **Status:** todo  **Depends on:** —
**Risk:** MEDIUM/HIGH — wide blast radius (~50 classes + builder/function dispatch).

## Problem
Every parse-node subclass in `lib/src/ast/parse_node.dart` (~50 of them) hand-writes
`@override String get type => '<literal>';`. The SAME literal is duplicated again in
`lib/src/functions/functions.dart` as `FunctionSpec(type: '<literal>')` and in the
environment specs — two (sometimes three) independent sources of truth per node type
(e.g. `'genfrac'`, `'op'`, `'array'`).

## Why it was deferred
`type` strings are the dispatch key for the builder registry and function/env specs.
Changing how they're produced touches the AST, every builder's registry key, and the
function/environment registration tables at once. A single mismatched string silently
drops a node to the fallback path. Needs a careful, mechanical, well-tested pass.

## Change (pick one, evaluate during the ticket)
- **(a)** Move `type` into the `ParseNode` base constructor as a `final String type`
  field, set by each subclass via `super(type: 'genfrac')`; delete the ~50 getter
  overrides.
- **(b)** Define the type strings once as named constants and reference them from BOTH the
  node and its `FunctionSpec`/`EnvSpec`, removing the duplicate-literal source of truth.
Prefer whichever keeps the sealed-subclass `switch` exhaustiveness the builders rely on.

## Acceptance criteria
- Each node `type` string defined in exactly one place; no duplicated literals between
  nodes and their `FunctionSpec`/`EnvSpec`.
- No change to any emitted `type` value (registry dispatch unchanged).
- `dart analyze` clean; `dart test` 304 passing; oracle gate 26/26; golden diff unchanged;
  `katex_flutter` 62 tests green.
