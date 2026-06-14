/// Builder for the `enclose` group, porting the BOX-PRODUCING `htmlBuilder` of
/// `reference/node_modules/katex/src/functions/enclose.ts` (KaTeX 0.17.0):
/// `\fbox`, `\boxed`, `\colorbox`, `\fcolorbox`, `\cancel`, `\bcancel`,
/// `\xcancel`, `\sout`, `\angl`.
///
/// KaTeX renders these by padding the inner box (`\fboxsep` horizontally +
/// vertically for boxes, `0.2em` for cancel, `0.03889em`/`4×ruleThickness` for
/// angl), then overlaying a frame (CSS border) and/or a strike SVG. We mirror
/// the geometry into one [EncloseNode]: its child is the padded inner box (so
/// the node's height/depth/width already include the padding, like KaTeX's
/// vlist), and the node carries the notations + colors the two backends draw.
/// `\phase` is intentionally not ported (out of scope).
library;

import 'package:katex/src/ast/parse_node.dart' as ast;
import 'package:katex/src/box/box_node.dart';
import 'package:katex/src/build/build_common.dart';
import 'package:katex/src/build/build_expression.dart';
import 'package:katex/src/build/builders/supsub_builder.dart' show isCharacterBox;
import 'package:katex/src/build/options.dart';

/// Registers the enclose builder into [registry].
void registerEncloseBuilder(Map<String, GroupBuilder> registry) {
  registry['enclose'] = (node, options) =>
      _buildEnclose(node as ast.EncloseParseNode, options);
}

// Wraps [inner] with [hpad] em of horizontal padding on each side and [topPad]/
// [bottomPad] em of vertical padding (so the result's height/depth/width grow by
// the pads). Mirrors KaTeX's `boxpad`/`cancel-pad`/`anglpad` CSS padding plus
// `stretchyEnclose`'s topPad/bottomPad, which together set the inner box's
// extent before the frame/strike is overlaid.
BoxNode _pad(
  BoxNode inner,
  double hpad,
  double topPad,
  double bottomPad,
) {
  final horizontal = hpad == 0
      ? inner
      : HBox(<BoxNode>[KernNode(hpad), inner, KernNode(hpad)]);
  if (topPad == 0 && bottomPad == 0) {
    return horizontal;
  }
  // Grow the box's height by [topPad] and depth by [bottomPad] without moving
  // the baseline. A zero-width [RuleNode] draws nothing, so we use two as
  // invisible struts at the inner baseline: one extends the height, the other
  // the depth. (KaTeX achieves the same extent via stretchyEnclose's
  // totalHeight and the wrapping vlist.)
  return makeVList(
    positionType: VListPositionType.individualShift,
    children: <VListChild>[
      VListChild.elem(horizontal),
      VListChild.elem(
        RuleNode(width: 0, height: horizontal.height + topPad),
      ),
      VListChild.elem(
        RuleNode(width: 0, height: 0, depth: horizontal.depth + bottomPad),
      ),
    ],
  );
}

BoxNode _buildEnclose(ast.EncloseParseNode group, Options options) {
  final inner = buildGroup(group.body, options);
  final label = group.label.substring(1); // strip the leading backslash
  final isSingleChar = isCharacterBox(group.body);
  final metrics = options.fontMetrics();

  // Horizontal padding (KaTeX: boxpad / cancel-pad / anglpad).
  final double hpad;
  if (label.contains('cancel')) {
    hpad = isSingleChar ? 0 : 0.2;
  } else if (label == 'angl') {
    hpad = 0.03889;
  } else {
    hpad = 0.3; // \fboxsep
  }

  // Vertical padding + border thickness (port of enclose.ts).
  double topPad;
  double bottomPad;
  var ruleThickness = 0.0;
  if (label.contains('box')) {
    ruleThickness = metrics.fboxrule > options.minRuleThickness
        ? metrics.fboxrule
        : options.minRuleThickness;
    topPad = metrics.fboxsep + (label == 'colorbox' ? 0 : ruleThickness);
    bottomPad = topPad;
  } else if (label == 'angl') {
    ruleThickness = metrics.defaultRuleThickness > options.minRuleThickness
        ? metrics.defaultRuleThickness
        : options.minRuleThickness;
    topPad = 4 * ruleThickness; // gap = 3 × line, plus the line itself.
    final remaining = 0.25 - inner.depth;
    bottomPad = remaining > 0 ? remaining : 0;
  } else {
    topPad = isSingleChar ? 0.2 : 0;
    bottomPad = topPad;
  }

  final child = _pad(inner, hpad, topPad, bottomPad);

  // Notations + colors per command.
  final notations = <EncloseNotation>[];
  final backgroundColor = group.backgroundColor;
  String? borderColor;
  double? borderWidth;
  String? strikeColor;

  switch (label) {
    case 'cancel':
      notations.add(EncloseNotation.updiagonalstrike);
      strikeColor = options.getColor();
    case 'bcancel':
      notations.add(EncloseNotation.downdiagonalstrike);
      strikeColor = options.getColor();
    case 'xcancel':
      notations
        ..add(EncloseNotation.updiagonalstrike)
        ..add(EncloseNotation.downdiagonalstrike);
      strikeColor = options.getColor();
    case 'sout':
      notations.add(EncloseNotation.horizontalstrike);
      strikeColor = options.getColor();
    case 'fbox':
      notations.add(EncloseNotation.box);
      borderWidth = ruleThickness;
      // KaTeX uses the current color for \fbox/\boxed borders.
      borderColor = options.getColor();
    case 'fcolorbox':
      notations.add(EncloseNotation.box);
      borderWidth = ruleThickness;
      borderColor = group.borderColor;
    case 'colorbox':
      // Background fill only; no border.
      break;
    case 'angl':
      notations.add(EncloseNotation.actuarial);
      borderWidth = ruleThickness;
      borderColor = options.getColor();
    default:
      break;
  }

  final enclose = EncloseNode(
    child: child,
    notations: notations,
    backgroundColor: backgroundColor,
    borderColor: borderColor,
    borderWidth: borderWidth,
    strikeColor: strikeColor,
  );

  return withAtomClass(makeSpan(<BoxNode>[enclose]), 'mord', options: options);
}
