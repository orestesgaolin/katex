# T-006 — parse-node AST types

**Milestone:** M2  **Status:** review  **Depends on:** T-001

## Goal
Port KaTeX's parse-node type system (`parseNode.js` / `parseNode.ts` flow types).

## Scope
- `lib/src/ast/parse_node.dart` — a sealed/abstract `ParseNode` hierarchy (or a tagged
  union with a `type` discriminator) covering the MVP node types: `ordgroup`, `mathord`,
  `textord`, `atom`, `supsub`, `genfrac`, `sqrt`, `op`, `operatorname`, `leftright`,
  `delimsizing`, `accent`, `text`, `font`, `color`, `sizing`, `styling`, `array`,
  `kern`/`spacing`, `rule`, `phantom`, `mclass`, `ordgroup`, primes.
- Each node carries `mode` + `loc` (SourceLocation) like KaTeX.
- A `ParseNodeType` enum/string discriminant matching KaTeX names exactly.

## Acceptance criteria
- `dart analyze` clean.
- Node set covers everything the MVP parser (T-008) and builders (T-011) need.
- Names match KaTeX `parseNode` type strings (so cross-referencing stays 1:1).
