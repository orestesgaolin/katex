/// Parser handler for `\\` and `\cr`, ported from
/// `reference/node_modules/katex/src/functions/cr.ts` (pinned KaTeX 0.17.0).
///
/// `\\` / `\cr` produce a [CrNode] carrying an optional size argument (`\\[1em]`)
/// and a `newLine` flag. Inside array/matrix/aligned environments the
/// environment parser consumes `\\` as a row-break *token* (the parser checks
/// `breakOnTokenText`/`endOfExpression` before parsing it as a function), so the
/// handler here is only reached at the **top level**. The `\newline` macro
/// (`parse/macros.dart`) expands to `\\\relax`.
///
/// Top-level line breaking is handled in `build/build_expression.dart`
/// (`buildHTML` splits on `cr` nodes and stacks the lines in a VList); the
/// box-producing builder here emits a marker span so single-line (no-`cr`)
/// expressions are unaffected.
library;

import 'package:katex_dart/src/ast/parse_node.dart';
import 'package:katex_dart/src/functions/function_spec.dart';

/// Registers the `\\` / `\cr` function handlers.
///
/// KaTeX's `cr.ts` registers only `\\`; we also register `\cr` so it is
/// *defined* (not "Undefined control sequence") and renders at the top level.
/// Inside array/matrix environments `\cr` is shadowed by a local macro
/// (`\\\relax`, set by the array handler) and never reaches this function.
void registerCr() {
  defineFunction(
    <String>[r'\\', r'\cr'],
    FunctionSpec(
      type: 'cr',
      numArgs: 0,
      allowedInText: true,
      handler: (context, args, optArgs) {
        final parser = context.parser;
        final size = parser.gullet.future().text == '['
            ? parser.parseSizeGroup(true)
            : null;
        final newLine =
            !parser.settings.displayMode ||
            !parser.settings.useStrictBehavior(
              'newLineInDisplayMode',
              r'In LaTeX, \\ or \newline does nothing in display mode',
            );
        return CrNode(
          mode: parser.mode,
          newLine: newLine,
          size: size?.value,
        );
      },
    ),
  );
}
