/// Builder for the `cr` node (`\\` / `\cr` / `\newline`), porting the
/// BOX-PRODUCING `htmlBuilder` of
/// `reference/node_modules/katex/src/functions/cr.ts` (KaTeX 0.17.0).
///
/// KaTeX's top-level `htmlBuilder` makes a `makeSpan(["mspace"])` tagged with
/// the `newline` class (and a `margin-top` of the optional `\\[size]` skip),
/// relying on CSS `.newline { display: block }` to break the line. The box tree
/// has no CSS, so the actual line break is performed in `build_expression.dart`
/// (`buildHTML` splits the expression on `cr` nodes and stacks the lines in a
/// VList). This builder only produces the equivalent marker span, so a lone
/// `\\`/`\cr` inside a sub-group (where line-splitting does not apply) still
/// builds to a harmless zero-size `mspace`.
library;

import 'package:katex_dart/src/ast/parse_node.dart' as ast;
import 'package:katex_dart/src/box/box_node.dart';
import 'package:katex_dart/src/build/build_common.dart';
import 'package:katex_dart/src/build/build_expression.dart';
import 'package:katex_dart/src/build/options.dart';

/// Registers the cr builder into [registry].
void registerCrBuilder(Map<String, GroupBuilder> registry) {
  registry['cr'] = (node, options) => _buildCr(node as ast.CrNode, options);
}

BoxNode _buildCr(ast.CrNode group, Options options) {
  final classes = <String>['mspace'];
  if (group.newLine) {
    classes.add('newline');
  }
  return makeSpan(const <BoxNode>[], classes: classes, options: options);
}
