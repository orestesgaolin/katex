/// Builders for `op` (`\sum`/`\int`/`\prod`/…) and `operatorname`, ported from
/// KaTeX `functions/op.ts`, `functions/operatorname.ts`, and the shared
/// `functions/utils/assembleSupSub.ts` (TeXbook rule 13).
library;

import 'dart:math' as math;

import 'package:katex/src/ast/parse_node.dart' hide KernNode, RuleNode;
import 'package:katex/src/box/box_node.dart';
import 'package:katex/src/build/build_common.dart';
import 'package:katex/src/build/build_expression.dart';
import 'package:katex/src/build/builders/supsub_builder.dart'
    show isCharacterBox;
import 'package:katex/src/build/options.dart';
import 'package:katex/src/build/style.dart';
import 'package:katex/src/types.dart';

/// Registers the op/operatorname builders into [registry].
void registerOpBuilders(Map<String, GroupBuilder> registry) {
  registry['op'] = (node, options) => _buildOp(node as OpNode, options);
  registry['operatorname'] = (node, options) =>
      _buildOperatorName(node as OperatorNameNode, options);
}

const Set<String> _noSuccessor = {r'\smallint'};

// The base box of an op, plus its slant (italic) and the requested base shift.
class _OpBase {
  _OpBase(this.box, this.slant, this.baseShift, this.italic);
  final BoxNode box;
  final double slant;
  final double baseShift;
  final double italic;
}

_OpBase _buildOpBase(OpNode group, Options options) {
  final style = options.style;
  var large = false;
  if (style.size == Style.DISPLAY.size &&
      group.symbol &&
      !_noSuccessor.contains(group.name)) {
    large = true;
  }

  BoxNode base;
  var italic = 0.0;
  if (group.symbol) {
    final fontName = large ? 'Size2-Regular' : 'Size1-Regular';
    final glyph = makeSymbol(
      group.name!,
      fontName,
      Mode.math,
      options: options,
    );
    base = glyph ?? makeSpan(const []);
    italic = glyph?.scaledItalic ?? 0.0;
  } else if (group.body != null) {
    final inner = buildExpression(group.body!, options, isRealGroup: true);
    base = makeSpan(inner, options: options);
  } else {
    // Text operator: build from the name's characters.
    final output = <BoxNode>[];
    final name = group.name!;
    for (var i = 1; i < name.length; i++) {
      final sym = mathsym(name[i], group.mode, options);
      if (sym != null) {
        output.add(sym);
      }
    }
    base = makeSpan(output, options: options);
  }

  var baseShift = 0.0;
  var slant = 0.0;
  if (group.symbol && !(group.suppressBaseShift ?? false)) {
    baseShift =
        (base.height - base.depth) / 2 - options.fontMetrics().axisHeight;
    slant = italic;
  }
  return _OpBase(base, slant, baseShift, italic);
}

BoxNode _buildOp(OpNode group, Options options) {
  final opBase = _buildOpBase(group, options);
  // No limits to attach (bare op): apply the base shift as a vertical shift.
  if (opBase.baseShift != 0) {
    final shifted = makeVList(
      positionType: VListPositionType.shift,
      positionData: opBase.baseShift,
      children: [VListChild.elem(opBase.box)],
    );
    return withAtomClass(shifted, 'mop', options: options);
  }
  return withAtomClass(opBase.box, 'mop', options: options);
}

/// Builds an `op` that is the base of a `supsub` with display limits.
/// Port of op.htmlBuilder's supsub path + assembleSupSub.
BoxNode buildOpSupSub(SupSubNode grp, Options options) {
  final group = grp.base! as OpNode;
  final opBase = _buildOpBase(group, options);
  return _assembleSupSub(
    opBase.box,
    grp.sup,
    grp.sub,
    options,
    options.style,
    opBase.slant,
    opBase.baseShift,
  );
}

BoxNode _buildOperatorName(OperatorNameNode group, Options options) {
  final base = _buildOperatorNameBase(group, options);
  return withAtomClass(base, 'mop', options: options);
}

BoxNode _buildOperatorNameBase(OperatorNameNode group, Options options) {
  if (group.body.isEmpty) {
    return makeSpan(const [], options: options);
  }
  // Map symbol children to textords (per amsopn).
  final body = group.body.map<ParseNode>((child) {
    if (child is SymbolParseNode) {
      return TextOrdNode(mode: child.mode, text: child.text);
    }
    return child;
  }).toList();
  final expression = buildExpression(
    body,
    options.withFont('mathrm'),
    isRealGroup: true,
  );
  return makeSpan(expression, options: options);
}

/// Builds an `operatorname` that is the base of a `supsub`. Port of
/// operatorname.htmlBuilder's supsub path.
BoxNode buildOperatorNameSupSub(SupSubNode grp, Options options) {
  final group = grp.base! as OperatorNameNode;
  final base = _buildOperatorNameBase(group, options);
  return _assembleSupSub(base, grp.sup, grp.sub, options, options.style, 0, 0);
}

// Port of assembleSupSub: stack base with limits above/below.
BoxNode _assembleSupSub(
  BoxNode baseRaw,
  ParseNode? supGroup,
  ParseNode? subGroup,
  Options options,
  Style style,
  double slant,
  double baseShift,
) {
  final base = makeSpan([baseRaw]);
  final fm = options.fontMetrics();

  BoxNode? supElem;
  double supKern = 0;
  if (supGroup != null) {
    supElem = buildGroup(supGroup, options.havingStyle(style.sup()), options);
    supKern = math.max(fm.bigOpSpacing1, fm.bigOpSpacing3 - supElem.depth);
  }

  BoxNode? subElem;
  double subKern = 0;
  if (subGroup != null) {
    subElem = buildGroup(subGroup, options.havingStyle(style.sub()), options);
    subKern = math.max(fm.bigOpSpacing2, fm.bigOpSpacing4 - subElem.height);
  }

  // KaTeX centers the base, sup, and sub within the limits column (CSS
  // `.op-limits > .vlist-t { text-align: center }`). The slant margin is part
  // of each limit's layout box, so we fold it in first (via _withLeftMargin)
  // and then pad each row symmetrically to the column width.
  final subRow = subElem == null ? null : _withLeftMargin(subElem, -slant);
  final supRow = supElem == null ? null : _withLeftMargin(supElem, slant);
  var colWidth = base.width;
  if (subRow != null && subRow.width > colWidth) {
    colWidth = subRow.width;
  }
  if (supRow != null && supRow.width > colWidth) {
    colWidth = supRow.width;
  }
  final baseC = centerInWidth(base, colWidth);
  final subC = subRow == null ? null : centerInWidth(subRow, colWidth);
  final supC = supRow == null ? null : centerInWidth(supRow, colWidth);

  final BoxNode finalGroup;
  if (supC != null && subC != null) {
    final bottom =
        fm.bigOpSpacing5 +
        subElem!.height +
        subElem.depth +
        subKern +
        base.depth +
        baseShift;
    finalGroup = makeVList(
      positionType: VListPositionType.bottom,
      positionData: bottom,
      children: [
        VListChild.kern(fm.bigOpSpacing5),
        VListChild.elem(subC),
        VListChild.kern(subKern),
        VListChild.elem(baseC),
        VListChild.kern(supKern),
        VListChild.elem(supC),
        VListChild.kern(fm.bigOpSpacing5),
      ],
    );
  } else if (subC != null) {
    final top = base.height - baseShift;
    finalGroup = makeVList(
      positionType: VListPositionType.top,
      positionData: top,
      children: [
        VListChild.kern(fm.bigOpSpacing5),
        VListChild.elem(subC),
        VListChild.kern(subKern),
        VListChild.elem(baseC),
      ],
    );
  } else if (supC != null) {
    final bottom = base.depth + baseShift;
    finalGroup = makeVList(
      positionType: VListPositionType.bottom,
      positionData: bottom,
      children: [
        VListChild.elem(baseC),
        VListChild.kern(supKern),
        VListChild.elem(supC),
        VListChild.kern(fm.bigOpSpacing5),
      ],
    );
  } else {
    return withAtomClass(base, 'mop', options: options);
  }

  final parts = <BoxNode>[];
  final subIsSingleChar = subGroup != null && isCharacterBox(subGroup);
  if (subElem != null && slant != 0 && !subIsSingleChar) {
    parts.add(makeSpan([KernNode(slant)], classes: const ['mspace']));
  }
  parts.add(finalGroup);

  return withAtomClass(makeFragment(parts), 'mop', options: options);
}

BoxNode _withLeftMargin(BoxNode elem, double margin) {
  if (margin == 0) {
    return elem;
  }
  return makeFragment([KernNode(margin), elem]);
}
