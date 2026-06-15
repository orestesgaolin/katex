/// Builder for `sqrt` (`\sqrt`, `\sqrt[n]{}`), ported from KaTeX
/// `functions/sqrt.ts` (htmlBuilder, TeXbook rule 11).
///
/// T-022: the surd is now real KaTeX stretchy SVG geometry — an [SvgPathNode]
/// whose `d` comes from `svg_geometry.g.dart`'s `sqrtPath` (`sqrtMain` /
/// `sqrtSize1..4` / `sqrtTall`), sized exactly per KaTeX's `delimiter.ts`
/// `makeSqrtImage`. The single SVG path draws BOTH the radical stroke and the
/// vinculum (the long horizontal bar that runs over the radicand), so there is
/// no separate rule for the overbar.
///
/// IMPORTANT (T-020/T-022): the surd image's *logical* height/depth follow
/// KaTeX's `texHeight` (a fixed 1.0/extraVinculum-adjusted value for the small
/// surd, `sizeToMaxHeight` for large, the requested height for tall), with
/// depth 0 — NOT the underlying glyph's font metrics. The radicand sits on the
/// baseline and the surd descends to the box depth; getting `texHeight` right
/// is what keeps the `\sqrt` baseline matching the KaTeX oracle (the 26/26
/// dimension gate). The SVG's `viewBoxHeight` carries the surd's full path
/// extent (with `vbPad` padding above the vinculum); `preserveAspectRatio`
/// `xMinYMin slice` maps it onto the box exactly like KaTeX.
library;

import 'dart:math' as math;

import 'package:katex/src/ast/parse_node.dart' hide KernNode, RuleNode;
import 'package:katex/src/box/box_node.dart';
import 'package:katex/src/build/build_common.dart';
import 'package:katex/src/build/build_expression.dart';
import 'package:katex/src/build/builders/delimiter_builders.dart'
    show sizeToMaxHeight;
import 'package:katex/src/build/options.dart';
import 'package:katex/src/build/style.dart';
import 'package:katex/src/svg/svg_geometry.g.dart' as geom;
import 'package:katex/src/types.dart';

/// Registers the sqrt builder into [registry].
void registerSqrtBuilder(Map<String, GroupBuilder> registry) {
  registry['sqrt'] = (node, options) => _buildSqrt(node as SqrtNode, options);
}

// The `\surd` delimiter sequence (KaTeX `stackLargeDelimiterSequence`): the
// Main glyph at three styles, then the four Size glyphs, then a stacked
// (tall) fallback. We model the three "small" entries as a single Main glyph
// because the style only affects the size multiplier (handled in
// `makeSqrtImage` below via `havingBaseSizing`).
enum _SurdKind { small, large, tall }

// KaTeX surd SVG padding above the vinculum, measured inside the viewBox
// (`vbPad`). KaTeX also tracks an `emPad` (0.08em) for the *rendered* span
// height; the box tree only needs the TeX-like `texHeight` (the padding is
// not part of vertical alignment), so emPad is not reproduced here.
const double _vbPad = 80;

// Faithful port of KaTeX `delimiter.makeSqrtImage`. Returns the surd as a real
// [SvgPathNode] (stretchy geometry from `sqrt_geometry.g.dart`) plus the
// `ruleWidth` (vinculum thickness) and `advanceWidth` (horizontal space the
// surd occupies before the radicand).
//
// CRITICAL: the node's logical `height`/`depth` follow KaTeX's `texHeight`
// (a fixed value), NOT a glyph's font metrics. KaTeX overrides `span.height` to
// `texHeight` with depth 0; the radicand's baseline (and hence the whole
// `\sqrt`'s baseline) depends on that `texHeight`. This keeps the 26/26 oracle
// dimension gate.
//
// [contentWidth] is the radicand width; the surd path is made that-much-plus-
// advanceWidth wide so its long vinculum runs over the whole radicand (KaTeX's
// 400em-wide, top-left-anchored, sliced SVG).
({
  SvgPathNode span,
  double height,
  double ruleWidth,
  double advanceWidth,
})
_makeSurd(double height, double contentWidth, Options options) {
  // Remove the effect of size changes (e.g. \Huge) — KaTeX scales up rather
  // than picking a taller surd. We keep the style (e.g. \scriptstyle).
  final newOptions = options.havingBaseSizing();
  final baseMultiplier = newOptions.sizeMultiplier;

  // Pick the surd from the sequence by comparing scaled total heights.
  // `traverseSequence` compares `height * newOptions.sizeMultiplier` against
  // the glyph total height+depth at each step.
  final scaledTarget = height * baseMultiplier;
  var kind = _SurdKind.tall;
  var largeSize = 4;

  // The "small" Main glyph total height.
  final mainGlyph =
      makeSymbol(r'\surd', 'Main-Regular', Mode.math, options: newOptions);
  if (mainGlyph != null &&
      (mainGlyph.height + mainGlyph.depth) > scaledTarget) {
    kind = _SurdKind.small;
  } else {
    var matched = false;
    for (var size = 1; size <= 4; size++) {
      final g = makeSymbol(
        r'\surd',
        'Size$size-Regular',
        Mode.math,
        options: newOptions,
      );
      if (g != null && (g.height + g.depth) > scaledTarget) {
        kind = _SurdKind.large;
        largeSize = size;
        matched = true;
        break;
      }
    }
    if (!matched) {
      kind = _SurdKind.tall;
    }
  }

  var sizeMultiplier = baseMultiplier;

  // The standard sqrt SVGs each have a 0.04em-thick vinculum. If
  // minRuleThickness is larger we add extraVinculum (in ems).
  final extraVinculum = math.max(
    0,
    options.minRuleThickness - options.fontMetrics().sqrtRuleThickness,
  ).toDouble();

  // texHeight/advanceWidth/viewBoxHeight/sqrtName follow makeSqrtImage.
  final double texHeight;
  final double advanceWidth;
  final double viewBoxHeight;
  final String sqrtName;
  switch (kind) {
    case _SurdKind.small:
      sqrtName = 'sqrtMain';
      viewBoxHeight = 1000 + 1000 * extraVinculum + _vbPad;
      if (height < 1.0) {
        sizeMultiplier = 1.0; // mimic a \textfont radical
      } else if (height < 1.4) {
        sizeMultiplier = 0.7; // mimic a \scriptfont radical
      }
      texHeight = (1.0 + extraVinculum) / sizeMultiplier;
      advanceWidth = 0.833 / sizeMultiplier; // from the font.
    case _SurdKind.large:
      sqrtName = 'sqrtSize$largeSize';
      final maxH = sizeToMaxHeight[largeSize];
      viewBoxHeight = (1000 + _vbPad) * maxH;
      texHeight = (maxH + extraVinculum) / sizeMultiplier;
      advanceWidth = 1.0 / sizeMultiplier; // 1.0 from the font.
    case _SurdKind.tall:
      sqrtName = 'sqrtTall';
      texHeight = height + extraVinculum;
      viewBoxHeight = (1000 * height + extraVinculum).floorToDouble() + _vbPad;
      advanceWidth = 1.056;
  }

  final ruleWidth =
      (options.fontMetrics().sqrtRuleThickness + extraVinculum) *
      sizeMultiplier;

  final pathData = geom.sqrtPath(sqrtName, extraVinculum, viewBoxHeight);

  // KaTeX's surd SVG is `width:"400em"`, `viewBox:"0 0 400000 viewBoxHeight"`,
  // `preserveAspectRatio:"xMinYMin slice"`, left-aligned over the radicand. In
  // the tight box tree we give the node the actual width it occupies — the
  // surd advance plus the radicand width — so the long vinculum (which lives at
  // viewBox x≈834..400000) covers the whole radicand. `slice` keeps the
  // diagonal stroke at the left undistorted; the unused right of the 400000-
  // wide viewBox is clipped to the box.
  final boxWidth = advanceWidth + contentWidth;
  final span = SvgPathNode(
    pathName: sqrtName,
    pathData: pathData,
    viewBoxWidth: 400000,
    viewBoxHeight: viewBoxHeight,
    width: boxWidth,
    height: texHeight,
    preserveAspectRatio: SvgPreserveAspectRatio.xMinYMinSlice,
  );

  return (
    span: span,
    height: texHeight,
    ruleWidth: ruleWidth,
    advanceWidth: advanceWidth,
  );
}

BoxNode _buildSqrt(SqrtNode group, Options options) {
  var innerHeight = 0.0;
  final inner = buildGroup(group.body, options.havingCrampedStyle());
  innerHeight = inner.height;
  if (innerHeight == 0) {
    innerHeight = options.fontMetrics().xHeight;
  }
  final innerDepth = inner.depth;

  final metrics = options.fontMetrics();
  final theta = metrics.defaultRuleThickness;
  var phi = theta;
  if (options.style.id < Style.TEXT.id) {
    phi = metrics.xHeight;
  }

  var lineClearance = theta + phi / 4;
  final minDelimiterHeight = innerHeight + innerDepth + lineClearance + theta;

  final surd = _makeSurd(minDelimiterHeight, inner.width, options);
  final img = surd.span;
  // KaTeX `img.height` is the surd's `texHeight`, not the glyph font height.
  final imgHeight = surd.height;
  final ruleWidth = surd.ruleWidth;
  final advanceWidth = surd.advanceWidth;

  final delimDepth = imgHeight - ruleWidth;
  if (delimDepth > innerHeight + innerDepth + lineClearance) {
    lineClearance = (lineClearance + delimDepth - innerHeight - innerDepth) / 2;
  }

  final imgShift = imgHeight - innerHeight - lineClearance - ruleWidth;

  // Overlay the surd image and the radicand. Faithful to KaTeX's
  //   [inner (paddingLeft advanceWidth), kern(-(inner.height + imgShift)),
  //    img, kern(ruleWidth)]
  // The surd SVG (`img`) draws both the radical stroke and the vinculum over
  // the radicand, so there is no separate overbar rule. The trailing
  // `kern(ruleWidth)` adds the vinculum thickness to the vlist height (the
  // top band that the SVG paints).
  final body = makeVList(
    positionType: VListPositionType.firstBaseline,
    children: [
      VListChild.elem(makeFragment([KernNode(advanceWidth), inner])),
      VListChild.kern(-(innerHeight + imgShift)),
      VListChild.elem(img),
      VListChild.kern(ruleWidth),
    ],
  );

  if (group.index == null) {
    return withAtomClass(
      makeSpan([body], classes: const ['sqrt']),
      'mord',
      options: options,
    );
  }

  // Optional root index, always in scriptscript style.
  final newOptions = options.havingStyle(Style.SCRIPTSCRIPT);
  final rootm = buildGroup(group.index, newOptions, options);

  // The amount the index is shifted up by. Taken from the TeX source, in the
  // definition of `\r@@t` (KaTeX `sqrt.ts`).
  final toShift = 0.6 * (body.height - body.depth);

  // Build a VList with the index ("superscript") shifted up correctly.
  final rootVList = makeVList(
    positionType: VListPositionType.shift,
    positionData: -toShift,
    children: [VListChild.elem(rootm)],
  );
  final rootWrap = makeSpan([rootVList], classes: const ['root']);

  // KaTeX wraps the index in a `.root` span whose CSS supplies the horizontal
  // kerning from `\r@@t`'s `\mkern 5mu` / `\mkern -10mu`:
  //   .sqrt > .root { margin-left: 5/18 em; margin-right: -10/18 em; }
  // 1 mu = 1/18 em. The box tree has no CSS margins, so we reproduce them as
  // explicit horizontal kerns: a +5mu kern before the index nudges it right,
  // and a -10mu kern after it pulls the surd left so the index nests into the
  // radical's top-left notch (instead of floating detached to the left).
  const muToEm = 1.0 / 18.0;
  const rootMarginLeft = 5 * muToEm; // \mkern 5mu
  const rootMarginRight = -10 * muToEm; // \mkern -10mu

  return withAtomClass(
    makeSpan([
      const KernNode(rootMarginLeft),
      rootWrap,
      const KernNode(rootMarginRight),
      body,
    ], classes: const ['sqrt']),
    'mord',
    options: options,
  );
}
