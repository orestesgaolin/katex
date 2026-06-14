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

/// Builds an `op` that is the base of a `supsub`.
///
/// Port of op.htmlBuilder's supsub path. KaTeX has two flags per operator:
/// whether it produces *limits* (scripts stacked above/below) and whether it is
/// a growing symbol. `\sum`/`\prod`/`\bigcup`/… default to `limits: true`, so in
/// displaystyle their scripts stack via [_assembleSupSub] (TeXbook rule 13).
/// `\int`/`\oint`/`\iint`/… default to `limits: false` (*nolimits*): their
/// scripts go to the side as ordinary sup/sub, even in displaystyle — see
/// [_buildOpSideSupSub]. The slanted integral sign needs its italic correction
/// folded into the subscript so the sub tucks down-right under the slant rather
/// than overlapping it.
BoxNode buildOpSupSub(SupSubNode grp, Options options) {
  final group = grp.base! as OpNode;
  final opBase = _buildOpBase(group, options);

  // Mirror supsub.js's htmlBuilderDelegate: limits ops stack above/below when
  // in displaystyle or when they always handle their own scripts; otherwise
  // the scripts render to the side (the nolimits / integral case).
  final useLimits =
      group.limits &&
      (options.style.size == Style.DISPLAY.size ||
          (group.alwaysHandleSupSub ?? false));

  if (useLimits) {
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

  return _buildOpSideSupSub(grp, opBase, options);
}

// Port of supsub.js's generic htmlBuilder (TeXbook rules 18a-f), specialised
// for an op base. Used for nolimits ops (\int, \oint, \iint, …): the scripts
// sit to the upper-/lower-right of the operator. Because our `op` base is a
// span wrapping the glyph (rather than KaTeX's bare SymbolNode), the generic
// supsub builder can't see the glyph's italic correction; we apply it here as
// the subscript's left margin (KaTeX's `marginLeft = -base.italic`) so the
// subscript tucks under the slanted integral sign instead of overlapping it.
BoxNode _buildOpSideSupSub(
  SupSubNode grp,
  _OpBase opBase,
  Options options,
) {
  final metrics = options.fontMetrics();
  // The op base carries its own vertical centering (baseShift) inside its box,
  // so we treat it as the supsub base directly.
  final base = opBase.box;

  var supShift = 0.0;
  var subShift = 0.0;

  BoxNode? supm;
  BoxNode? subm;

  if (grp.sup != null) {
    final newOptions = options.havingStyle(options.style.sup());
    supm = buildGroup(grp.sup, newOptions, options);
    // Rule 18a: the op base is never a character box.
    supShift =
        base.height -
        newOptions.fontMetrics()['supDrop'] *
            newOptions.sizeMultiplier /
            options.sizeMultiplier;
  }

  if (grp.sub != null) {
    final newOptions = options.havingStyle(options.style.sub());
    subm = buildGroup(grp.sub, newOptions, options);
    subShift =
        base.depth +
        newOptions.fontMetrics()['subDrop'] *
            newOptions.sizeMultiplier /
            options.sizeMultiplier;
  }

  // Rule 18c: minimum sup shift.
  final double minSupShift;
  if (options.style == Style.DISPLAY) {
    minSupShift = metrics['sup1'];
  } else if (options.style.cramped) {
    minSupShift = metrics['sup3'];
  } else {
    minSupShift = metrics['sup2'];
  }

  // Subscripts shouldn't be shifted by the operator's italic correction.
  // Account for that by pulling the subscript back by the glyph's italic
  // (KaTeX's `marginLeft = -base.italic`); this is what tucks the lower bound
  // down-right of the slanted integral sign instead of out past it.
  final subMarginLeft = subm == null ? 0.0 : -opBase.italic;

  // scriptspace: KaTeX appends `marginRight = makeEm((0.5 / ptPerEm) / mult)`
  // to *every* script row (generic supsub builder + the op nolimits DOM). It
  // is a small font-size-independent gap after each bound; without it the
  // scripts sit a hair too tight and the overall advance is narrower than
  // KaTeX's, throwing off the bound/sign offset. Mirror the generic path.
  final marginRight = (0.5 / metrics.ptPerEm) / options.sizeMultiplier;

  final BoxNode supsub;
  if (supm != null && subm != null) {
    supShift = math.max(
      math.max(supShift, minSupShift),
      supm.depth + 0.25 * metrics.xHeight,
    );
    subShift = math.max(subShift, metrics['sub2']);

    final ruleWidth = metrics.defaultRuleThickness;
    // Rule 18e.
    final maxWidth = 4 * ruleWidth;
    if ((supShift - supm.depth) - (subm.height - subShift) < maxWidth) {
      subShift = maxWidth - (supShift - supm.depth) + subm.height;
      final psi = 0.8 * metrics.xHeight - (supShift - supm.depth);
      if (psi > 0) {
        supShift += psi;
        subShift -= psi;
      }
    }

    supsub = makeVList(
      positionType: VListPositionType.individualShift,
      children: [
        VListChild.elem(
          _withSideMargins(subm, left: subMarginLeft, right: marginRight),
          shift: subShift,
        ),
        VListChild.elem(
          _withSideMargins(supm, right: marginRight),
          shift: -supShift,
        ),
      ],
    );
  } else if (subm != null) {
    // Rule 18b.
    subShift = math.max(
      math.max(subShift, metrics['sub1']),
      subm.height - 0.8 * metrics.xHeight,
    );
    supsub = makeVList(
      positionType: VListPositionType.shift,
      positionData: subShift,
      children: [
        VListChild.elem(
          _withSideMargins(subm, left: subMarginLeft, right: marginRight),
        ),
      ],
    );
  } else if (supm != null) {
    // Rule 18c, d.
    supShift = math.max(
      math.max(supShift, minSupShift),
      supm.depth + 0.25 * metrics.xHeight,
    );
    supsub = makeVList(
      positionType: VListPositionType.shift,
      positionData: -supShift,
      children: [VListChild.elem(_withSideMargins(supm, right: marginRight))],
    );
  } else {
    // No scripts: just the bare op.
    return withAtomClass(base, 'mop', options: options);
  }

  return withAtomClass(
    makeFragment([
      base,
      makeSpan([supsub], classes: const ['msupsub']),
    ]),
    'mop',
    options: options,
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

// Wraps [elem] with optional leading ([left]) and trailing ([right]) kerns,
// modelling KaTeX's `marginLeft`/`marginRight` on a side-script vlist child:
// `left` is the negative base-italic cancellation for the subscript, `right`
// is the scriptspace gap appended to every script row.
BoxNode _withSideMargins(BoxNode elem, {double left = 0, double right = 0}) {
  if (left == 0 && right == 0) {
    return elem;
  }
  return makeFragment([
    if (left != 0) KernNode(left),
    elem,
    if (right != 0) KernNode(right),
  ]);
}
