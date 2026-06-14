/// Builder for `\includegraphics`, porting the BOX-PRODUCING `htmlBuilder` of
/// `reference/node_modules/katex/src/functions/includegraphics.ts` (KaTeX
/// 0.17.0).
///
/// KaTeX resolves the requested height (default `0.9em`), derives a depth from
/// `totalheight` when given, and a width from `width` (natural / unconstrained
/// otherwise), then emits an `Img` of that CSS size. We mirror the geometry
/// into an [ImageNode]; the two backends draw it (SVG `<image>` / Flutter
/// placeholder outline).
library;

import 'package:katex/src/ast/parse_node.dart' as ast;
import 'package:katex/src/box/box_node.dart';
import 'package:katex/src/build/build_expression.dart';
import 'package:katex/src/build/builders/units.dart' show calculateSize;
import 'package:katex/src/build/options.dart';

/// Registers the includegraphics builder into [registry].
void registerIncludegraphicsBuilder(Map<String, GroupBuilder> registry) {
  registry['includegraphics'] = (node, options) =>
      _buildIncludegraphics(node as ast.IncludegraphicsParseNode, options);
}

BoxNode _buildIncludegraphics(
  ast.IncludegraphicsParseNode group,
  Options options,
) {
  final height = calculateSize(group.height, options);
  var depth = 0.0;
  if (group.totalheight.number > 0) {
    depth = calculateSize(group.totalheight, options) - height;
  }

  var width = 0.0;
  if (group.width.number > 0) {
    width = calculateSize(group.width, options);
  }

  return ImageNode(
    src: group.src,
    alt: group.alt,
    width: width,
    height: height,
    depth: depth > 0 ? depth : 0,
  );
}
