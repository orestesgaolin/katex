# T-048 — Small mechanical simplifications batch

**Milestone:** M9 (refactor/simplify)  **Status:** todo  **Depends on:** —

## Items (all low-risk, no behavior change)
1. **Hoist inline regexes** recompiled per-call to file-level `final`/`static`:
   `parse/parser.dart` (color/size/url group parsers, `_validUnit`, symbol parser),
   `parse/macro_expander.dart` (`^[1-9]$` placeholder check),
   `functions/functions.dart` (`_nonStretchyAccentRegex`).
2. **`_nonStretchyAccentRegex` → `const Set<String> _nonStretchyAccents`** with `.contains`
   (also removes the duplicated accent-name list).
3. **Rule-thickness flooring** `v > min ? v : min` repeated in `build/build_common.dart`,
   `build/builders/array_builder.dart`, `build/builders/enclose_builder.dart` (2×) →
   one helper (e.g. `options.floorRuleThickness(double)` or a free `floorAt`).
4. **`toString` dim tail** `w/h/d toStringAsFixed(4)` repeated in ~7 box `toString()`s
   (`box/box_node.dart`) → one private `_dims` getter on `BoxNode`.
5. **`bin/katex.dart`** — four near-identical usage-error blocks → one local `usageError(msg)`.
6. **`svg/svg_serializer.dart`** — `_escapeAttr` delegates to `_escapeText` (+`&quot;`);
   add `_strokeOr(String?)` for the 3× `currentColor` fallback; hoist the double
   `_escapeAttr(node.src)` in `_writeImage` to a local.
7. **`parser.dart` SupSub ladder** — collapse the three-branch `SupSubNode` construction into
   one (`if (sup != null || sub != null) return SupSubNode(...); return base;`).

## Acceptance criteria
- Each item applied; no observable behavior change (regexes equivalent, numbers identical).
- `dart analyze` clean; `dart test` 304 passing; oracle gate 26/26; CLI smoke test still valid.
