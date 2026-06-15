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
import 'package:katex/src/build/builders/extra_builders.dart';
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
    // Limits ops (\sum, \prod, …) stack scripts above/below in displaystyle.
    // Symbol ops also delegate when they DON'T take limits (\int, \oint, …):
    // op_builders renders their scripts to the side with the glyph's italic
    // correction folded into the subscript, which the generic supsub path
    // can't do since our op base is a span (not a bare SymbolNode). Non-symbol
    // nolimits ops (\sin, \log, …) stay on the generic path — they have no
    // italic correction, so the two paths are equivalent for them.
    final delegate =
        (base.limits &&
            (options.style.size == Style.DISPLAY.size ||
                (base.alwaysHandleSupSub ?? false))) ||
        (!base.limits && base.symbol);
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
  } else if (base is HorizBraceNode) {
    // \overbrace{…}^{note} / \underbrace{…}_{note}: the brace handles its own
    // script, stacking the note centered above/below (KaTeX treats it as an op
    // with \limits). The generic path would float the note to the upper-right.
    return buildHorizBraceSupSub(group, options);
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

  // scriptspace is a font-size-independent size, so scale it appropriately for
  // use as the marginRight (KaTeX: `makeEm((0.5 / ptPerEm) / multiplier)`). It
  // is appended as a trailing kern to every script row, matching KaTeX's
  // `marginRight` on each vlist child.
  final marginRight = (0.5 / metrics.ptPerEm) / options.sizeMultiplier;

  // KaTeX's `base instanceof SymbolNode` check: in this port a single-symbol
  // base is a `mord` span wrapping one GlyphNode (our ord builders tag the
  // glyph with an atom class via a span rather than mutating the glyph), so we
  // unwrap to recover the underlying symbol and its italic correction.
  final baseSymbol = _baseSymbol(builtBase);

  // Subscripts shouldn't be shifted by the base's italic correction. Account
  // for that by shifting the subscript back the appropriate amount (KaTeX's
  // `marginLeft = -italic` on the subscript row). We only do this when the base
  // is a single symbol (KaTeX: `base instanceof SymbolNode`).
  var subMarginLeft = 0.0;
  if (subm != null && baseSymbol != null) {
    subMarginLeft = -baseSymbol.scaledItalic;
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
        VListChild.elem(
          withMargins(subm, left: subMarginLeft, right: marginRight),
          shift: subShift,
        ),
        VListChild.elem(
          withMargins(supm, right: marginRight),
          shift: -supShift,
        ),
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
      children: [
        VListChild.elem(
          withMargins(subm, left: subMarginLeft, right: marginRight),
        ),
      ],
    );
  } else if (supm != null) {
    supShift = math.max(
      math.max(supShift, minSupShift),
      supm.depth + 0.25 * metrics.xHeight,
    );
    supsub = makeVList(
      positionType: VListPositionType.shift,
      positionData: -supShift,
      children: [VListChild.elem(withMargins(supm, right: marginRight))],
    );
  } else {
    throw StateError('supsub must have either sup or sub.');
  }

  // The base's italic correction sits between the base and the scripts. In
  // KaTeX a single-symbol base carries it as a CSS `margin-right`, which pushes
  // the whole msupsub span right by `italic`; the subscript then cancels it via
  // its own negative `marginLeft` (see `subMarginLeft`) so only the superscript
  // is offset. The box tree's GlyphNode.width excludes italic, so we reproduce
  // the margin-right as an explicit kern between the base and the msupsub span.
  final baseItalic = baseSymbol?.scaledItalic ?? 0.0;

  final mclass = atomClassOf(builtBase) ?? 'mord';
  return withAtomClass(
    makeFragment([
      builtBase,
      if (baseItalic != 0) KernNode(baseItalic),
      makeSpan([supsub], classes: const ['msupsub']),
    ]),
    mclass,
    options: options,
  );
}

// Recovers the single underlying [GlyphNode] of a built base, or `null` if the
// base is not a lone symbol. Mirrors KaTeX's `base instanceof SymbolNode`:
// here the ord builders wrap the glyph in a `mord` span (to carry the atom
// class), so a single-symbol base is a SpanNode whose only non-kern child is a
// GlyphNode. (A multi-glyph base — e.g. a braced group — yields `null`, exactly
// like KaTeX, where such a base is an Anchor/Span rather than a SymbolNode.)
GlyphNode? _baseSymbol(BoxNode base) {
  if (base is GlyphNode) {
    return base;
  }
  if (base is SpanNode) {
    GlyphNode? found;
    for (final child in base.children) {
      if (child is KernNode) {
        continue;
      }
      if (child is GlyphNode && found == null) {
        found = child;
      } else {
        return null; // more than one glyph, or a non-glyph child.
      }
    }
    return found;
  }
  return null;
}

// Wraps [elem] with optional leading ([left]) and trailing ([right]) kerns,
// modelling KaTeX's `marginLeft`/`marginRight` on a vlist child. A negative
// left margin (the base-italic cancellation for subscripts) is a leading kern.
