# T-044 — Add `copyWith` to ArrayNode/OpNode; kill field-by-field reconstruction

**Milestone:** M9 (refactor/simplify)  **Status:** todo  **Depends on:** —

## Problem
Nodes are rebuilt field-by-field to change one or two fields:
- `lib/src/environments/array.dart` (matrix & aligned paths) each reconstruct a fresh
  `ArrayNode` copying ~11 fields, changing only `cols`/`colSeparationType`.
- `lib/src/parse/parser.dart` (`_resolvedLimitsBase`) re-specifies ~9 fields of
  `OpNode`/`OperatorNameNode` to flip `limits`/`alwaysHandleSupSub`.

## Change
Add `copyWith({...})` to `ArrayNode` (and `OpNode`/`OperatorNameNode` as needed) in
`lib/src/ast/parse_node.dart`, covering every field with a nullable override that defaults
to the current value. Replace the manual reconstructions with `res.copyWith(...)`.

## Acceptance criteria
- `copyWith` covers all fields (verify each manual reconstruction maps 1:1 — no field dropped
  or defaulted differently).
- Manual field-by-field rebuilds removed at the named call sites.
- `dart analyze` clean; `dart test` 304 passing; oracle gate 26/26.
