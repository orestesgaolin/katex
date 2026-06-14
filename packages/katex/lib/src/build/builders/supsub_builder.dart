/// Builder for `supsub` (superscript/subscript), ported from KaTeX
/// `functions/supsub.ts` (the htmlBuilder) plus the sup/sub placement math
/// (TeXbook rules 18a-f). Delegates to op / accent builders when the base is a
/// big operator with limits or a character-box accent.
library;

import 'dart:math' as math;

import 'package:katex/src/ast/parse_node.dart' hide KernNode, RuleNode;
import 'package:katex/src/box/box_node.dart';
import 'package:katex/src/build/build_common.dart';
import 'package:katex/src/build/build_expression.dart';
import 'package:katex/src/build/builders/accent_builders.dart';
import 'package:katex/src/build/builders/op_builders.dart';
import 'package:katex/src/build/options.dart';
import 'package:katex/src/build/style.dart';

/// Registers the supsub builder into [registry].
void registerSupSubBuilder(Map<String, GroupBuilder> registry) {
  registry['supsub'] = (node, options) =>
      buildSupSub(node as SupSubNode, options);
}

// Mirrors KaTeX's utils.isCharacterBox for the MVP node set.
bool isCharacterBox(ParseNode? node) {
  if (node == null) {
    return false;
  }
  final base = node is OrdGroupNode && node.body.isNotEmpty
      ? node.body.first
      : node;
  return base is MathOrdNode ||
      base is TextOrdNode ||
      base is AtomNode ||
      base is SpacingNode;
}

/// Builds a [SupSubNode]. Public so op/accent delegation can be checked.
BoxNode buildSupSub(SupSubNode group, Options options) {
  // Delegate to the inner group when it should handle its own scripts.
  final base = group.base;
  if (base is OpNode) {
    final delegate =
        base.limits &&
        (options.style.size == Style.DISPLAY.size ||
            (base.alwaysHandleSupSub ?? false));
    if (delegate) {
      return buildOpSupSub(group, options);
    }
  } else if (base is OperatorNameNode) {
    final delegate =
        base.alwaysHandleSupSub &&
        (options.style.size == Style.DISPLAY.size || base.limits);
    if (delegate) {
      return buildOperatorNameSupSub(group, options);
    }
  } else if (base is AccentNode) {
    if (isCharacterBox(base.base)) {
      return buildAccentSupSub(group, options);
    }
  }

  final valueBase = group.base;
  final valueSup = group.sup;
  final valueSub = group.sub;
  final builtBase = buildGroup(valueBase, options);

  final metrics = options.fontMetrics();

  var supShift = 0.0;
  var subShift = 0.0;

  final isCharBox = valueBase != null && isCharacterBox(valueBase);

  BoxNode? supm;
  BoxNode? subm;

  if (valueSup != null) {
    final newOptions = options.havingStyle(options.style.sup());
    supm = buildGroup(valueSup, newOptions, options);
    if (!isCharBox) {
      supShift =
          builtBase.height -
          newOptions.fontMetrics()['supDrop'] *
              newOptions.sizeMultiplier /
              options.sizeMultiplier;
    }
  }

  if (valueSub != null) {
    final newOptions = options.havingStyle(options.style.sub());
    subm = buildGroup(valueSub, newOptions, options);
    if (!isCharBox) {
      subShift =
          builtBase.depth +
          newOptions.fontMetrics()['subDrop'] *
              newOptions.sizeMultiplier /
              options.sizeMultiplier;
    }
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

  // Subscripts shouldn't be shifted by the base's italic correction.
  var subMarginLeft = 0.0;
  if (subm != null && builtBase is GlyphNode) {
    subMarginLeft = -builtBase.scaledItalic;
  }

  final BoxNode supsub;
  if (supm != null && subm != null) {
    supShift = math.max(
      math.max(supShift, minSupShift),
      supm.depth + 0.25 * metrics.xHeight,
    );
    subShift = math.max(subShift, metrics['sub2']);

    final ruleWidth = metrics.defaultRuleThickness;
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
        VListChild.elem(_withLeftMargin(subm, subMarginLeft), shift: subShift),
        VListChild.elem(supm, shift: -supShift),
      ],
    );
  } else if (subm != null) {
    subShift = math.max(
      math.max(subShift, metrics['sub1']),
      subm.height - 0.8 * metrics.xHeight,
    );
    supsub = makeVList(
      positionType: VListPositionType.shift,
      positionData: subShift,
      children: [VListChild.elem(_withLeftMargin(subm, subMarginLeft))],
    );
  } else if (supm != null) {
    supShift = math.max(
      math.max(supShift, minSupShift),
      supm.depth + 0.25 * metrics.xHeight,
    );
    supsub = makeVList(
      positionType: VListPositionType.shift,
      positionData: -supShift,
      children: [VListChild.elem(supm)],
    );
  } else {
    throw StateError('supsub must have either sup or sub.');
  }

  final mclass = atomClassOf(builtBase) ?? 'mord';
  return withAtomClass(
    makeFragment([
      builtBase,
      makeSpan([supsub], classes: const ['msupsub']),
    ]),
    mclass,
    options: options,
  );
}

// A negative-/positive-width left margin is modelled as a leading kern.
BoxNode _withLeftMargin(BoxNode elem, double margin) {
  if (margin == 0) {
    return elem;
  }
  return makeFragment([KernNode(margin), elem]);
}
