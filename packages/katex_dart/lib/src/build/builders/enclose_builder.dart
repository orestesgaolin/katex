/// Builder for the `enclose` group, porting the BOX-PRODUCING `htmlBuilder` of
/// `reference/node_modules/katex/src/functions/enclose.ts` (KaTeX 0.17.0):
/// `\fbox`, `\boxed`, `\colorbox`, `\fcolorbox`, `\cancel`, `\bcancel`,
/// `\xcancel`, `\sout`, `\angl`, `\phase`.
///
/// KaTeX renders these by padding the inner box (`\fboxsep` horizontally +
/// vertically for boxes, `0.2em` for cancel, `0.03889em`/`4×ruleThickness` for
/// angl), then overlaying a frame (CSS border) and/or a strike SVG. We mirror
/// the geometry into one [EncloseNode]: its child is the padded inner box (so
/// the node's height/depth/width already include the padding, like KaTeX's
/// vlist), and the node carries the notations + colors the two backends draw.
///
/// `\phase` (the Steinmetz phasor angle) reserves a left pad of
/// `angleHeight / 2 + lineWeight` (KaTeX `enclose.ts`, `notation === "phase"`)
/// and draws an angle (`\` + `_`) at the box's lower-left via
/// [EncloseNotation.phase]; the backends draw it geometrically (matching the
/// shape KaTeX's `phasePath` SVG produces).
library;

import 'package:katex_dart/src/ast/parse_node.dart' as ast;
import 'package:katex_dart/src/box/box_node.dart';
import 'package:katex_dart/src/build/build_common.dart';
import 'package:katex_dart/src/build/build_expression.dart';
import 'package:katex_dart/src/build/builders/supsub_builder.dart' show isCharacterBox;
import 'package:katex_dart/src/build/builders/units.dart' show calculateSize;
import 'package:katex_dart/src/build/options.dart';

/// Registers the enclose builder into [registry].
void registerEncloseBuilder(Map<String, GroupBuilder> registry) {
  registry['enclose'] = (node, options) =>
      _buildEnclose(node as ast.EncloseParseNode, options);
}

// Wraps [inner] with [leftPad]/[rightPad] em of horizontal padding and
// [topPad]/[bottomPad] em of vertical padding (so the result's
// height/depth/width grow by the pads). Mirrors KaTeX's
// `boxpad`/`cancel-pad`/`anglpad` CSS padding plus `stretchyEnclose`'s
// topPad/bottomPad, which together set the inner box's extent before the
// frame/strike is overlaid. `\phase` pads only the left (`paddingLeft`).
BoxNode _pad(
  BoxNode inner,
  double leftPad,
  double rightPad,
  double topPad,
  double bottomPad,
) {
  final horizontal = (leftPad == 0 && rightPad == 0)
      ? inner
      : HBox(<BoxNode>[KernNode(leftPad), inner, KernNode(rightPad)]);
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

  // \phase — the Steinmetz phasor angle (KaTeX enclose.ts, `notation ===
  // "phase"`). It pads the body left by `angleHeight/2 + lineWeight`, reserves
  // `angleHeight` of vertical extent below the baseline, then draws an angle.
  if (label == 'phase') {
    return _buildPhase(inner, options);
  }

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
    ruleThickness = options.floorRuleThickness(metrics.fboxrule);
    topPad = metrics.fboxsep + (label == 'colorbox' ? 0 : ruleThickness);
    bottomPad = topPad;
  } else if (label == 'angl') {
    ruleThickness = options.floorRuleThickness(metrics.defaultRuleThickness);
    topPad = 4 * ruleThickness; // gap = 3 × line, plus the line itself.
    final remaining = 0.25 - inner.depth;
    bottomPad = remaining > 0 ? remaining : 0;
  } else {
    topPad = isSingleChar ? 0.2 : 0;
    bottomPad = topPad;
  }

  final child = _pad(inner, hpad, hpad, topPad, bottomPad);

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

// \phase — port of enclose.ts `notation === "phase"`. KaTeX reserves a left pad
// (so the angle has room), grows the body's depth so the angle clears the body,
// and draws a Steinmetz angle (`\` joined to `_`) at the lower-left.
BoxNode _buildPhase(BoxNode inner, Options options) {
  // Steinmetz dimensions (KaTeX): line weight 0.6pt, clearance 0.35ex.
  final lineWeight = calculateSize(const ast.Measurement(0.6, 'pt'), options);
  final clearance = calculateSize(const ast.Measurement(0.35, 'ex'), options);

  // The angle reaches from the top of the body down to below its depth, with a
  // clearance gap. `imgShift` is how far the angle's baseline sits below the
  // body's baseline (KaTeX: inner.depth + lineWeight + clearance).
  final angleHeight = inner.height + inner.depth + lineWeight + clearance;
  final leftPad = angleHeight / 2 + lineWeight;
  final imgShift = inner.depth + lineWeight + clearance;

  // Pad the body on the left only (KaTeX: inner.style.paddingLeft), and grow
  // the depth so the angle fits below the body. A zero-width strut at the new
  // bottom extends the depth without moving the baseline.
  final padded = HBox(<BoxNode>[
    KernNode(leftPad),
    makeVList(
      positionType: VListPositionType.individualShift,
      children: <VListChild>[
        VListChild.elem(inner),
        VListChild.elem(RuleNode(width: 0, height: 0, depth: imgShift)),
      ],
    ),
  ]);

  final enclose = EncloseNode(
    child: padded,
    notations: const <EncloseNotation>[EncloseNotation.phase],
    strikeColor: options.getColor(),
    phaseLineWidth: lineWeight,
  );

  return withAtomClass(makeSpan(<BoxNode>[enclose]), 'mord', options: options);
}
