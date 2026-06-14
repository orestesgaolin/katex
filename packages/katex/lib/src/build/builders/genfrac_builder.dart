/// Builder for `genfrac` (`\frac`/`\dfrac`/`\tfrac`/`\binom`/`\atop`/…), ported
/// from KaTeX `functions/genfrac.ts` (htmlBuilder, TeXbook rules 15a-e).
library;

import 'package:katex/src/ast/parse_node.dart' hide KernNode, RuleNode;
import 'package:katex/src/box/box_node.dart';
import 'package:katex/src/build/build_common.dart';
import 'package:katex/src/build/build_expression.dart';
import 'package:katex/src/build/builders/delimiter_builders.dart';
import 'package:katex/src/build/builders/units.dart';
import 'package:katex/src/build/options.dart';
import 'package:katex/src/build/style.dart';

/// Registers the genfrac builder into [registry].
void registerGenfracBuilder(Map<String, GroupBuilder> registry) {
  registry['genfrac'] = (node, options) =>
      _buildGenfrac(node as GenfracNode, options);
}

BoxNode _buildGenfrac(GenfracNode group, Options options) {
  final style = options.style;
  final nstyle = style.fracNum();
  final dstyle = style.fracDen();

  var newOptions = options.havingStyle(nstyle);
  final numerm = buildGroup(group.numer, newOptions, options);

  newOptions = options.havingStyle(dstyle);
  final denomm = buildGroup(group.denom, newOptions, options);

  RuleNode? rule;
  double ruleWidth;
  double ruleSpacing;
  if (group.hasBarLine) {
    if (group.barSize != null) {
      final rw = calculateSize(group.barSize!, options);
      rule = makeLineSpan(options, thickness: rw);
    } else {
      rule = makeLineSpan(options);
    }
    ruleWidth = rule.height;
    ruleSpacing = rule.height;
  } else {
    rule = null;
    ruleWidth = 0;
    ruleSpacing = options.fontMetrics().defaultRuleThickness;
  }

  // Rule 15b.
  double numShift;
  double clearance;
  double denomShift;
  if (style.size == Style.DISPLAY.size) {
    numShift = options.fontMetrics()['num1'];
    clearance = ruleWidth > 0 ? 3 * ruleSpacing : 7 * ruleSpacing;
    denomShift = options.fontMetrics()['denom1'];
  } else {
    if (ruleWidth > 0) {
      numShift = options.fontMetrics()['num2'];
      clearance = ruleSpacing;
    } else {
      numShift = options.fontMetrics()['num3'];
      clearance = 3 * ruleSpacing;
    }
    denomShift = options.fontMetrics()['denom2'];
  }

  // KaTeX centers the numerator and denominator within the fraction column
  // (CSS `.mfrac > span > span { text-align: center }`). The box tree has no
  // CSS, so we pad the narrower row(s) symmetrically to the column width.
  final colWidth = numerm.width > denomm.width ? numerm.width : denomm.width;
  final numerc = centerInWidth(numerm, colWidth);
  final denomc = centerInWidth(denomm, colWidth);

  final BoxNode frac;
  if (rule == null) {
    // Rule 15c.
    final candidateClearance =
        (numShift - numerm.depth) - (denomm.height - denomShift);
    if (candidateClearance < clearance) {
      numShift += 0.5 * (clearance - candidateClearance);
      denomShift += 0.5 * (clearance - candidateClearance);
    }
    frac = makeVList(
      positionType: VListPositionType.individualShift,
      children: [
        VListChild.elem(denomc, shift: denomShift),
        VListChild.elem(numerc, shift: -numShift),
      ],
    );
  } else {
    // Rule 15d.
    final axisHeight = options.fontMetrics().axisHeight;
    if ((numShift - numerm.depth) - (axisHeight + 0.5 * ruleWidth) <
        clearance) {
      numShift +=
          clearance -
          ((numShift - numerm.depth) - (axisHeight + 0.5 * ruleWidth));
    }
    if ((axisHeight - 0.5 * ruleWidth) - (denomm.height - denomShift) <
        clearance) {
      denomShift +=
          clearance -
          ((axisHeight - 0.5 * ruleWidth) - (denomm.height - denomShift));
    }
    final midShift = -(axisHeight - 0.5 * ruleWidth);
    // The rule has zero width from makeLineSpan; stretch it to the wider of
    // numerator/denominator so the bar spans the fraction.
    final bar = RuleNode(width: colWidth, height: ruleWidth);
    frac = makeVList(
      positionType: VListPositionType.individualShift,
      children: [
        VListChild.elem(denomc, shift: denomShift),
        VListChild.elem(bar, shift: midShift),
        VListChild.elem(numerc, shift: -numShift),
      ],
    );
  }

  // Rule 15e: delimiter size.
  final double delimSize;
  if (style.size == Style.DISPLAY.size) {
    delimSize = options.fontMetrics()['delim1'];
  } else if (style.size == Style.SCRIPTSCRIPT.size) {
    delimSize = options.havingStyle(Style.SCRIPT).fontMetrics()['delim2'];
  } else {
    delimSize = options.fontMetrics()['delim2'];
  }

  final BoxNode leftDelim;
  if (group.leftDelim == null) {
    leftDelim = makeNullDelimiter(options);
  } else {
    leftDelim = makeCustomSizedDelim(
      group.leftDelim!,
      delimSize,
      center: true,
      options: options.havingStyle(style),
      mode: group.mode,
    );
  }

  final BoxNode rightDelim;
  if (group.continued) {
    rightDelim = makeSpan(const []);
  } else if (group.rightDelim == null) {
    rightDelim = makeNullDelimiter(options);
  } else {
    rightDelim = makeCustomSizedDelim(
      group.rightDelim!,
      delimSize,
      center: true,
      options: options.havingStyle(style),
      mode: group.mode,
    );
  }

  return withAtomClass(
    makeFragment([
      leftDelim,
      makeSpan([frac], classes: const ['mfrac']),
      rightDelim,
    ]),
    'mord',
    options: options,
  );
}
