/// Delimiter sizing for `\left…\right`, `\frac`'s binom delimiters, and
/// `\bigl`/`\Big`/… — ported from KaTeX `src/delimiter.ts` and the
/// `functions/delimsizing.ts` / `functions/genfrac.ts` builders.
///
/// T-022: `small` (Main-Regular, restyled) and `large` (Size1–Size4) delimiters
/// are glyphs, exactly like KaTeX (and like the KaTeX oracle, which renders
/// `\left(\frac{a}{b}\right)` as a Size2 glyph). When a delimiter is taller
/// than the largest fixed glyph KaTeX *stacks* it as a single SVG path
/// (`makeStackedDelim` + `tallDelim`); this port now emits a real
/// [SvgPathNode] for those SVG-labeled stacked delimiters (parentheses,
/// brackets, floor/ceil, single/double vertical bars), sized per
/// `makeStackedDelim`'s math. Stacked delimiters that KaTeX assembles from
/// individual font glyphs (braces, groups, moustaches, arrows) still fall back
/// to the Size4 glyph — noted for a later slice.
library;

import 'dart:math' as math;

import 'package:katex_dart/src/ast/parse_node.dart' hide KernNode, RuleNode;
import 'package:katex_dart/src/box/box_node.dart';
import 'package:katex_dart/src/build/build_common.dart';
import 'package:katex_dart/src/build/build_expression.dart'
    show GroupBuilder, buildExpression, mclassName, withAtomClass;
import 'package:katex_dart/src/build/options.dart';
import 'package:katex_dart/src/build/style.dart';
import 'package:katex_dart/src/font/font_metrics.dart';
import 'package:katex_dart/src/svg/svg_geometry.g.dart' as geom;
import 'package:katex_dart/src/symbols/symbols.dart';

/// Registers the delimsizing builder (`\bigl`/`\Big`/…) into [registry].
void registerDelimiterBuilders(Map<String, GroupBuilder> registry) {
  registry['delimsizing'] = (node, options) {
    final group = node as DelimsizingNode;
    final mclass = mclassName(group.mclass);
    if (group.delim == '.') {
      return makeSpan(const [], classes: [mclass]);
    }
    return withAtomClass(
      makeSizedDelim(group.delim, group.size.value, options, group.mode),
      mclass,
      options: options,
    );
  };
  // 'leftright' is registered here too, since it depends on the delim makers.
  registry['leftright'] = (node, options) =>
      _buildLeftRight(node as LeftRightNode, options);
}

// Replacement of < / > with angle brackets in delimiters.
String _normalizeDelim(String delim) {
  if (delim == '<' || delim == r'\lt' || delim == '⟨') {
    return r'\langle';
  } else if (delim == '>' || delim == r'\gt' || delim == '⟩') {
    return r'\rangle';
  }
  return delim;
}

// Metrics of a delimiter glyph in a given metrics font.
CharacterMetrics _getMetrics(String symbol, String font, Mode mode) {
  final entry = Symbols.lookup(Mode.math, symbol);
  final replace = entry?.replace ?? symbol;
  final metrics = getCharacterMetrics(replace, font, mode);
  if (metrics == null) {
    throw StateError('Unsupported symbol $symbol and font size $font.');
  }
  return metrics;
}

/// A null (empty) delimiter — reserves no visible glyph. Port of KaTeX's
/// `makeNullDelimiter`.
BoxNode makeNullDelimiter(Options options) =>
    makeSpan(const [], classes: const ['nulldelimiter']);

// Small delimiter: Main-Regular restyled to a (base) style. We bake the style
// size scaling into the glyph by building it at the styled size.
BoxNode _makeSmallDelim(
  String delim,
  Style style,
  bool center,
  Options options,
  Mode mode,
) {
  final styled = options.havingBaseStyle(style);
  final glyph = makeSymbol(delim, 'Main-Regular', mode, options: styled);
  final span = makeSpan([if (glyph != null) glyph], options: styled);
  return center ? _centerSpan(span, options, style) : span;
}

// Large delimiter: one of the Size1–Size4 glyphs, always textstyle.
BoxNode _makeLargeDelim(
  String delim,
  int size,
  bool center,
  Options options,
  Mode mode,
) {
  final styled = options.havingBaseStyle(Style.TEXT);
  final glyph = makeSymbol(delim, 'Size$size-Regular', mode, options: styled);
  final span = makeSpan(
    [if (glyph != null) glyph],
    classes: ['delimsizing', 'size$size'],
    options: styled,
  );
  return center ? _centerSpan(span, options, Style.TEXT) : span;
}

// SVG-labeled stacked delimiters: maps a delimiter to its KaTeX `tallDelim`
// label, the section glyphs (top/repeat/bottom, and middle), the font, and the
// path viewBox width. Mirrors the relevant branches of `makeStackedDelim`.
class _Stacked {
  const _Stacked({
    required this.svgLabel,
    required this.viewBoxWidth,
    required this.top,
    required this.repeat,
    required this.bottom,
    required this.font,
  });
  final String svgLabel;
  final double viewBoxWidth;
  final String top;
  final String repeat;
  final String bottom;
  final String font;

  /// The optional middle section (braces). All SVG-labeled delimiters here are
  /// middle-less, so this is always `null` — kept to mirror `makeStackedDelim`.
  String? get middle => null;
}

// Only the delimiters KaTeX renders as a single SVG (`svgLabel.length > 0`).
// Braces / groups / moustaches / arrows use glyph stacking in KaTeX and are not
// covered here (they fall back to the Size4 glyph).
_Stacked? _stackedFor(String delim) {
  switch (delim) {
    case '(':
    case r'\lparen':
      return const _Stacked(
        svgLabel: 'lparen',
        viewBoxWidth: 875,
        top: '⎛',
        repeat: '⎜',
        bottom: '⎝',
        font: 'Size4-Regular',
      );
    case ')':
    case r'\rparen':
      return const _Stacked(
        svgLabel: 'rparen',
        viewBoxWidth: 875,
        top: '⎞',
        repeat: '⎟',
        bottom: '⎠',
        font: 'Size4-Regular',
      );
    case '[':
    case r'\lbrack':
      return const _Stacked(
        svgLabel: 'lbrack',
        viewBoxWidth: 667,
        top: '⎡',
        repeat: '⎢',
        bottom: '⎣',
        font: 'Size4-Regular',
      );
    case ']':
    case r'\rbrack':
      return const _Stacked(
        svgLabel: 'rbrack',
        viewBoxWidth: 667,
        top: '⎤',
        repeat: '⎥',
        bottom: '⎦',
        font: 'Size4-Regular',
      );
    case r'\lfloor':
    case '⌊':
      return const _Stacked(
        svgLabel: 'lfloor',
        viewBoxWidth: 667,
        top: '⎢',
        repeat: '⎢',
        bottom: '⎣',
        font: 'Size4-Regular',
      );
    case r'\lceil':
    case '⌈':
      return const _Stacked(
        svgLabel: 'lceil',
        viewBoxWidth: 667,
        top: '⎡',
        repeat: '⎢',
        bottom: '⎢',
        font: 'Size4-Regular',
      );
    case r'\rfloor':
    case '⌋':
      return const _Stacked(
        svgLabel: 'rfloor',
        viewBoxWidth: 667,
        top: '⎥',
        repeat: '⎥',
        bottom: '⎦',
        font: 'Size4-Regular',
      );
    case r'\rceil':
    case '⌉':
      return const _Stacked(
        svgLabel: 'rceil',
        viewBoxWidth: 667,
        top: '⎤',
        repeat: '⎥',
        bottom: '⎥',
        font: 'Size4-Regular',
      );
    case '|':
    case r'\lvert':
    case r'\rvert':
    case r'\vert':
      return const _Stacked(
        svgLabel: 'vert',
        viewBoxWidth: 333,
        top: '|',
        repeat: '∣',
        bottom: '|',
        font: 'Size1-Regular',
      );
    case r'\|':
    case r'\lVert':
    case r'\rVert':
    case r'\Vert':
      return const _Stacked(
        svgLabel: 'doublevert',
        viewBoxWidth: 556,
        top: r'\|',
        repeat: '∥',
        bottom: r'\|',
        font: 'Size1-Regular',
      );
    default:
      return null;
  }
}

// Faithful port of KaTeX `makeStackedDelim` for the SVG-labeled case. Builds a
// single [SvgPathNode] (via `tallDelim`) sized to at least [heightTotal],
// centered on the axis. Returns `null` for delimiters KaTeX stacks from glyphs
// (caller falls back to the Size4 glyph).
BoxNode? _makeStackedDelim(
  String delim,
  double heightTotal, {
  required bool center,
  required Options options,
  required Mode mode,
}) {
  final spec = _stackedFor(delim);
  if (spec == null) {
    return null;
  }

  final topMetrics = _getMetrics(spec.top, spec.font, mode);
  final topHeightTotal = topMetrics.height + topMetrics.depth;
  final repeatMetrics = _getMetrics(spec.repeat, spec.font, mode);
  final repeatHeightTotal = repeatMetrics.height + repeatMetrics.depth;
  final bottomMetrics = _getMetrics(spec.bottom, spec.font, mode);
  final bottomHeightTotal = bottomMetrics.height + bottomMetrics.depth;
  var middleHeightTotal = 0.0;
  var middleFactor = 1;
  if (spec.middle != null) {
    final mm = _getMetrics(spec.middle!, spec.font, mode);
    middleHeightTotal = mm.height + mm.depth;
    middleFactor = 2;
  }

  final minHeight = topHeightTotal + bottomHeightTotal + middleHeightTotal;
  final repeatCount = math.max(
    0,
    ((heightTotal - minHeight) / (middleFactor * repeatHeightTotal)).ceil(),
  );
  final realHeightTotal =
      minHeight + repeatCount * middleFactor * repeatHeightTotal;

  var axisHeight = options.fontMetrics().axisHeight;
  if (center) {
    axisHeight *= options.sizeMultiplier;
  }
  final depth = realHeightTotal / 2 - axisHeight;

  final midHeight = realHeightTotal - topHeightTotal - bottomHeightTotal;
  final viewBoxHeight = (realHeightTotal * 1000).roundToDouble();
  final pathStr = geom.tallDelim(spec.svgLabel, (midHeight * 1000).round());

  // The SVG wrapper reports height = realHeightTotal (its full extent) and
  // depth 0, exactly KaTeX's `wrapper.height = viewBoxHeight/1000`. The outer
  // bottom-positioned vlist (positionData = depth) then yields the
  // axis-centered height/depth: height = realHeightTotal - depth, depth = depth.
  final svg = SvgPathNode(
    pathName: spec.svgLabel,
    pathData: pathStr,
    viewBoxWidth: spec.viewBoxWidth,
    viewBoxHeight: viewBoxHeight,
    width: spec.viewBoxWidth / 1000,
    height: realHeightTotal,
  );

  return makeVList(
    positionType: VListPositionType.bottom,
    positionData: depth,
    children: [VListChild.elem(svg)],
  );
}

// Center a delimiter span on the math axis (KaTeX's centerSpan). Since the box
// tree carries no mutable style, we wrap in a single-element vlist shifted so
// the glyph centers on the axis.
BoxNode _centerSpan(BoxNode span, Options options, Style style) {
  final newOptions = options.havingBaseStyle(style);
  final shift =
      (1 - options.sizeMultiplier / newOptions.sizeMultiplier) *
      options.fontMetrics().axisHeight;
  if (shift == 0) {
    return span;
  }
  // Shift the element down by `shift` (positive shift moves down in KaTeX's
  // style.top), which reduces height and increases depth.
  return makeVList(
    positionType: VListPositionType.shift,
    positionData: shift,
    children: [VListChild.elem(span)],
  );
}

// Sequences (verbatim from KaTeX).
enum _DelimKind { small, large, stack }

class _Delim {
  const _Delim(this.kind, {this.style, this.size});
  final _DelimKind kind;
  final Style? style;
  final int? size;
}

const Set<String> _stackNeverDelimiters = {
  '<',
  '>',
  r'\langle',
  r'\rangle',
  '/',
  r'\backslash',
  r'\lt',
  r'\gt',
};

// Delimiters that come in the large (Size1-4) fonts.
const Set<String> _stackLargeDelimiters = {
  '(',
  r'\lparen',
  ')',
  r'\rparen',
  '[',
  r'\lbrack',
  ']',
  r'\rbrack',
  r'\{',
  r'\lbrace',
  r'\}',
  r'\rbrace',
  r'\lfloor',
  r'\rfloor',
  '⌊',
  '⌋',
  r'\lceil',
  r'\rceil',
  '⌈',
  '⌉',
  r'\surd',
};

final List<_Delim> _stackNeverSeq = [
  const _Delim(_DelimKind.small, style: Style.SCRIPTSCRIPT),
  const _Delim(_DelimKind.small, style: Style.SCRIPT),
  const _Delim(_DelimKind.small, style: Style.TEXT),
  const _Delim(_DelimKind.large, size: 1),
  const _Delim(_DelimKind.large, size: 2),
  const _Delim(_DelimKind.large, size: 3),
  const _Delim(_DelimKind.large, size: 4),
];

final List<_Delim> _stackAlwaysSeq = [
  const _Delim(_DelimKind.small, style: Style.SCRIPTSCRIPT),
  const _Delim(_DelimKind.small, style: Style.SCRIPT),
  const _Delim(_DelimKind.small, style: Style.TEXT),
  const _Delim(_DelimKind.stack),
];

final List<_Delim> _stackLargeSeq = [
  const _Delim(_DelimKind.small, style: Style.SCRIPTSCRIPT),
  const _Delim(_DelimKind.small, style: Style.SCRIPT),
  const _Delim(_DelimKind.small, style: Style.TEXT),
  const _Delim(_DelimKind.large, size: 1),
  const _Delim(_DelimKind.large, size: 2),
  const _Delim(_DelimKind.large, size: 3),
  const _Delim(_DelimKind.large, size: 4),
  const _Delim(_DelimKind.stack),
];

String _delimTypeToFont(_Delim t) {
  switch (t.kind) {
    case _DelimKind.small:
      return 'Main-Regular';
    case _DelimKind.large:
      return 'Size${t.size}-Regular';
    case _DelimKind.stack:
      return 'Size4-Regular';
  }
}

_Delim _traverseSequence(
  String delim,
  double height,
  List<_Delim> sequence,
  Options options,
) {
  final start = math.min(2, 3 - options.style.size);
  for (var i = start; i < sequence.length; i++) {
    final delimType = sequence[i];
    if (delimType.kind == _DelimKind.stack) {
      break;
    }
    final metrics = _getMetrics(delim, _delimTypeToFont(delimType), Mode.math);
    var heightDepth = metrics.height + metrics.depth;
    if (delimType.kind == _DelimKind.small) {
      final newOptions = options.havingBaseStyle(delimType.style);
      heightDepth *= newOptions.sizeMultiplier;
    }
    if (heightDepth > height) {
      return delimType;
    }
  }
  return sequence.last;
}

/// Builds a delimiter of a given total `height` (+depth) for `delim`. Port of
/// KaTeX's `makeCustomSizedDelim`; the `stack` outcome is approximated by the
/// Size4 large glyph (see file-level note).
BoxNode makeCustomSizedDelim(
  String delimRaw,
  double height, {
  required bool center,
  required Options options,
  required Mode mode,
}) {
  final delim = _normalizeDelim(delimRaw);

  final List<_Delim> sequence;
  if (_stackNeverDelimiters.contains(delim)) {
    sequence = _stackNeverSeq;
  } else if (_stackLargeDelimiters.contains(delim)) {
    sequence = _stackLargeSeq;
  } else {
    sequence = _stackAlwaysSeq;
  }

  final delimType = _traverseSequence(delim, height, sequence, options);

  switch (delimType.kind) {
    case _DelimKind.small:
      return _makeSmallDelim(delim, delimType.style!, center, options, mode);
    case _DelimKind.large:
      return _makeLargeDelim(delim, delimType.size!, center, options, mode);
    case _DelimKind.stack:
      // Real stacked SVG geometry for SVG-labeled delimiters (parens, brackets,
      // floor/ceil, vert/doublevert). Other stacked delimiters (braces, groups,
      // moustaches, arrows) still fall back to the Size4 glyph.
      return _makeStackedDelim(
            delim,
            height,
            center: center,
            options: options,
            mode: mode,
          ) ??
          _makeLargeDelim(delim, 4, center, options, mode);
  }
}

/// Sizes per `\bigl`/`\Bigl`/`\biggl`/`\Biggl`. Port of `sizeToMaxHeight`.
const List<double> sizeToMaxHeight = [0, 1.2, 1.8, 2.4, 3.0];

/// Builds a manually-sized delimiter (`\bigl` etc.). Port of `makeSizedDelim`.
BoxNode makeSizedDelim(String delimRaw, int size, Options options, Mode mode) {
  final delim = _normalizeDelim(delimRaw);
  if (_stackLargeDelimiters.contains(delim) ||
      _stackNeverDelimiters.contains(delim)) {
    return _makeLargeDelim(delim, size, false, options, mode);
  }
  // stackAlways delimiters: real stacked SVG geometry where available, else the
  // Size4 glyph fallback.
  return _makeStackedDelim(
        delim,
        sizeToMaxHeight[size],
        center: false,
        options: options,
        mode: mode,
      ) ??
      _makeLargeDelim(delim, 4, false, options, mode);
}

/// Builds a `\left`/`\right` delimiter sized to [height]/[depth] of the body.
/// Port of KaTeX's `makeLeftRightDelim`.
BoxNode makeLeftRightDelim(
  String delim,
  double height,
  double depth,
  Options options,
  Mode mode,
) {
  final axisHeight = options.fontMetrics().axisHeight * options.sizeMultiplier;
  const delimiterFactor = 901;
  final delimiterExtend = 5.0 / options.fontMetrics().ptPerEm;
  final maxDistFromAxis = math.max(height - axisHeight, depth + axisHeight);
  final totalHeight = math.max(
    maxDistFromAxis / 500 * delimiterFactor,
    2 * maxDistFromAxis - delimiterExtend,
  );
  return makeCustomSizedDelim(
    delim,
    totalHeight,
    center: true,
    options: options,
    mode: mode,
  );
}

// ---------------------------------------------------------------------------
// leftright
// ---------------------------------------------------------------------------

BoxNode _buildLeftRight(LeftRightNode group, Options options) {
  final inner = buildExpression(
    group.body,
    options,
    isRealGroup: true,
    surroundingLeft: 'mopen',
    surroundingRight: 'mclose',
  );

  var innerHeight = inner.fold<double>(0, (m, n) => math.max(m, n.height));
  var innerDepth = inner.fold<double>(0, (m, n) => math.max(m, n.depth));
  innerHeight *= options.sizeMultiplier;
  innerDepth *= options.sizeMultiplier;

  final BoxNode leftDelim;
  if (group.left == '.') {
    leftDelim = makeNullDelimiter(options);
  } else {
    leftDelim = makeLeftRightDelim(
      group.left,
      innerHeight,
      innerDepth,
      options,
      group.mode,
    );
  }

  final BoxNode rightDelim;
  if (group.right == '.') {
    rightDelim = makeNullDelimiter(options);
  } else {
    final rightOptions = group.rightColor != null
        ? options.withColor(group.rightColor!)
        : options;
    rightDelim = makeLeftRightDelim(
      group.right,
      innerHeight,
      innerDepth,
      rightOptions,
      group.mode,
    );
  }

  return withAtomClass(
    makeFragment([
      withAtomClass(leftDelim, 'mopen', options: options),
      ...inner,
      withAtomClass(rightDelim, 'mclose', options: options),
    ]),
    'minner',
    options: options,
  );
}

// buildExpression is needed here; import lazily to avoid a cycle in docs.
