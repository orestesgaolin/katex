/// The backend-agnostic box tree — the project's PRIMARY public model.
///
/// This is a pure data model that mirrors KaTeX's box semantics (`domTree.ts`
/// + `buildCommon.ts`) but drops the DOM/CSS/HTML entirely. There is ZERO
/// dependency on `dart:ui`, Flutter, or any rendering backend: a [BoxNode] is
/// just data plus *computed* dimension accessors.
///
/// Every box carries three computed dimensions, all in **em units** (like
/// KaTeX), measured relative to the box's baseline:
///  * [BoxNode.height] — distance from the baseline up to the top.
///  * [BoxNode.depth]  — distance from the baseline down to the bottom.
///  * [BoxNode.width]  — horizontal advance.
///
/// Both the SVG serializer and the Flutter painter are pure consumers of this
/// tree; consumers never need to recompute dimensions.
library;

import 'dart:math' as math;

import 'package:katex/src/font/font_metrics.dart';
import 'package:katex/src/font/font_types.dart';
import 'package:meta/meta.dart';

/// Base class for every node in the box tree.
///
/// Sealed so that consumers (SVG serializer, Flutter painter) can exhaustively
/// switch over the concrete node types. Each subclass exposes its computed
/// [height], [depth], and [width] in em units.
sealed class BoxNode {
  const BoxNode();

  /// Distance from the baseline to the top of the box, in em.
  double get height;

  /// Distance from the baseline to the bottom of the box, in em.
  double get depth;

  /// Horizontal advance of the box, in em.
  double get width;

  /// The `w/h/d` dimension triple formatted for [toString] (no enclosing
  /// parentheses), shared by every box node's debug string.
  String get _dims =>
      'w: ${width.toStringAsFixed(4)}, '
      'h: ${height.toStringAsFixed(4)}, '
      'd: ${depth.toStringAsFixed(4)}';
}

/// Sum of the widths of [children] (horizontal advance of a row).
double _sumWidth(List<BoxNode> children) =>
    children.fold<double>(0, (sum, c) => sum + c.width);

/// Greatest height among [children] (0 when empty).
double _maxHeight(List<BoxNode> children) =>
    children.fold<double>(0, (m, c) => math.max(m, c.height));

/// Greatest depth among [children] (0 when empty).
double _maxDepth(List<BoxNode> children) =>
    children.fold<double>(0, (m, c) => math.max(m, c.depth));

/// A single character drawn from a KaTeX font.
///
/// Mirrors KaTeX's `SymbolNode`. The glyph's [height]/[depth]/[width] (and
/// [italic]/[skew]) come from [getCharacterMetrics] for the glyph's font, then
/// are scaled by the [size] multiplier (KaTeX applies this scale via
/// `font-size`/`maxFontSize`; in a logical box tree we bake it into the
/// dimensions directly).
///
/// Use the default constructor when you already hold a [CharacterMetrics]
/// (e.g. the builder looked it up), or [GlyphNode.fromCodepoint] to resolve
/// the metrics from the bundled font tables.
@immutable
class GlyphNode extends BoxNode {
  /// Creates a glyph with explicit, already-resolved [metrics].
  ///
  /// [italic] and [skew] default to the values carried by [metrics] but may be
  /// overridden (KaTeX zeroes italic in text mode and for `\mathit`, for
  /// example). All reported dimensions are scaled by [size].
  GlyphNode({
    required this.codepoint,
    required this.font,
    required CharacterMetrics metrics,
    this.size = 1.0,
    double? italic,
    double? skew,
  }) : _metrics = metrics,
       italic = italic ?? metrics.italic,
       skew = skew ?? metrics.skew;

  /// Resolves [CharacterMetrics] for [codepoint] in [font]/[mode] from the
  /// bundled font tables and builds a [GlyphNode].
  ///
  /// Returns `null` when no metrics are available for the glyph (mirroring
  /// KaTeX, which warns and produces a zero-size symbol — here we let the
  /// caller decide how to handle a missing glyph). Throws [ArgumentError] when
  /// [font] names an unknown font, matching [getCharacterMetrics].
  // Returns a nullable value, so it cannot be expressed as a constructor.
  // ignore: prefer_constructors_over_static_methods
  static GlyphNode? fromCodepoint({
    required int codepoint,
    required KatexFont font,
    Mode mode = Mode.math,
    double size = 1.0,
    double? italic,
    double? skew,
  }) {
    final metrics = getCharacterMetricsByCode(codepoint, font.fontName, mode);
    if (metrics == null) {
      return null;
    }
    return GlyphNode(
      codepoint: codepoint,
      font: font,
      metrics: metrics,
      size: size,
      italic: italic,
      skew: skew,
    );
  }

  /// The Unicode code point of the character.
  final int codepoint;

  /// The font (family + variant) the glyph is drawn from.
  final KatexFont font;

  /// The size multiplier applied to the raw font metrics (KaTeX's
  /// `sizeMultiplier`). Defaults to `1.0`.
  final double size;

  /// Italic correction, in em (already at the glyph's design size, *not*
  /// scaled by [size] — scaling is applied by the accessors).
  final double italic;

  /// Skew (used for accent placement), in em (unscaled, like [italic]).
  final double skew;

  final CharacterMetrics _metrics;

  /// The raw, unscaled per-glyph metrics.
  CharacterMetrics get metrics => _metrics;

  /// The character as a Dart string (the rendered text).
  String get text => String.fromCharCode(codepoint);

  @override
  double get height => _metrics.height * size;

  @override
  double get depth => _metrics.depth * size;

  @override
  double get width => _metrics.width * size;

  /// Italic correction scaled by [size].
  double get scaledItalic => italic * size;

  /// Skew scaled by [size].
  double get scaledSkew => skew * size;

  @override
  String toString() =>
      'GlyphNode(${font.fontName} '
      'U+${codepoint.toRadixString(16).toUpperCase().padLeft(4, '0')} '
      "'$text' size: $size)";
}

/// A horizontal list of boxes laid out left-to-right.
///
/// Mirrors KaTeX's horizontal span. Children advance by their [width] (with
/// [KernNode]s providing explicit gaps). The aggregate dimensions follow
/// KaTeX's `sizeElementFromChildren`:
///  * [width] is the sum of child widths.
///  * [height]/[depth] are the max over children (children share a baseline;
///    they are not stacked).
@immutable
class HBox extends BoxNode {
  /// Creates a horizontal box wrapping [children].
  const HBox(this.children);

  /// The boxes laid out left-to-right; may include [KernNode]s.
  final List<BoxNode> children;

  @override
  double get width => _sumWidth(children);

  @override
  double get height => _maxHeight(children);

  @override
  double get depth => _maxDepth(children);

  @override
  String toString() =>
      'HBox(${children.length} children, $_dims)';
}

/// A fixed-width horizontal gap (kerning/glue).
///
/// Mirrors KaTeX's `{type: "kern", size}` vlist entry and inline kerns. Has
/// only [width]; [height] and [depth] are zero.
@immutable
class KernNode extends BoxNode {
  /// Creates a kern of the given [width] (in em).
  const KernNode(this.width);

  @override
  final double width;

  @override
  double get height => 0;

  @override
  double get depth => 0;

  @override
  String toString() => 'KernNode(${width.toStringAsFixed(4)})';
}

/// How a [VList]'s children are vertically positioned.
///
/// Direct port of KaTeX `buildCommon.makeVList`'s `VListParam.positionType`.
enum VListPositionType {
  /// Each child carries its own downward [VListChild.shift]. Every child MUST
  /// be an element (carry an [VListChild.elem]); kerns are derived
  /// automatically between them.
  individualShift,

  /// `positionData` specifies the topmost point of the vlist (a height;
  /// positive moves up).
  top,

  /// `positionData` specifies the bottommost point of the vlist (a depth;
  /// positive moves down).
  bottom,

  /// The vlist baseline is `positionData` away from the baseline of the first
  /// child (which MUST be an element); positive moves downward.
  shift,

  /// The vlist baseline is aligned with the first child's baseline (which MUST
  /// be an element). Equivalent to [shift] with `positionData == 0`.
  firstBaseline,
}

/// A single entry in a [VList]: either a stacked element or a vertical kern.
///
/// Mirrors KaTeX's `VListChild` union (`VListElem` / `VListElemAndShift` /
/// `VListKern`). For [VListPositionType.individualShift] every entry must be an
/// element with a [shift]; for the other modes entries may be elements (with
/// no [shift]) or kerns.
@immutable
class VListChild {
  /// An element entry wrapping [elem]. For
  /// [VListPositionType.individualShift], [shift] is the downward shift of the
  /// element's baseline.
  const VListChild.elem(this.elem, {this.shift = 0}) : size = 0, isKern = false;

  /// A vertical kern (gap) of the given [size] (in em).
  const VListChild.kern(this.size) : elem = null, shift = 0, isKern = true;

  /// The wrapped element, or `null` for a kern entry.
  final BoxNode? elem;

  /// The downward baseline shift (only meaningful in
  /// [VListPositionType.individualShift]).
  final double shift;

  /// The kern size (only meaningful when [isKern] is true).
  final double size;

  /// Whether this is a kern entry (vs. an element entry).
  final bool isKern;

  @override
  String toString() => isKern
      ? 'VListChild.kern(${size.toStringAsFixed(4)})'
      : 'VListChild.elem($elem, shift: ${shift.toStringAsFixed(4)})';
}

/// A resolved position of an element within a laid-out [VList].
///
/// [box] is the element, and [shift] is the downward offset of the element's
/// baseline from the vlist's own baseline (positive = down). This is the
/// product of the [VList] positioning math, exposed for consumers that paint
/// the children.
@immutable
class VListPosition {
  /// Creates a positioned element.
  const VListPosition(this.box, this.shift);

  /// The positioned element.
  final BoxNode box;

  /// Downward offset of [box]'s baseline from the vlist baseline (em).
  final double shift;

  @override
  String toString() =>
      'VListPosition($box, shift: ${shift.toStringAsFixed(4)})';
}

/// A vertical list: boxes stacked along the vertical axis at explicit shifts.
///
/// This is a faithful port of KaTeX `buildCommon.makeVList`. The first child in
/// [children] is conceptually at the bottom and the last at the top. The
/// constructor runs KaTeX's positioning math for the chosen
/// [VListPositionType] and exposes:
///  * the resulting [height]/[depth]/[width];
///  * [positions] — each element with its resolved downward shift (see
///    [VListPosition.shift]) so painters/serializers can place them.
///
/// Builders use this for fractions, square roots, accents, big-op limits, etc.
@immutable
class VList extends BoxNode {
  /// Builds a vertical list from [children] using [positionType].
  ///
  /// [positionData] is required (and only used) for
  /// [VListPositionType.top]/[VListPositionType.bottom]/[VListPositionType.shift].
  factory VList({
    required VListPositionType positionType,
    required List<VListChild> children,
    double positionData = 0,
  }) {
    final resolved = _resolveChildrenAndDepth(
      positionType,
      children,
      positionData,
    );
    return _layout(resolved.children, resolved.depth);
  }

  const VList._({
    required this.children,
    required double height,
    required double depth,
    required double width,
    required this.positions,
  }) : _height = height,
       _depth = depth,
       _width = width;

  /// The (input) children, in bottom-to-top order.
  final List<VListChild> children;

  /// The resolved element positions (element + downward baseline shift).
  final List<VListPosition> positions;

  final double _height;
  final double _depth;
  final double _width;

  @override
  double get height => _height;

  @override
  double get depth => _depth;

  @override
  double get width => _width;

  // Port of KaTeX `getVListChildrenAndDepth`: inserts derived kerns for
  // `individualShift` and computes the overall starting depth.
  static ({List<VListChild> children, double depth}) _resolveChildrenAndDepth(
    VListPositionType positionType,
    List<VListChild> children,
    double positionData,
  ) {
    if (positionType == VListPositionType.individualShift) {
      final old = children;
      assert(
        old.isNotEmpty && old.every((c) => !c.isKern),
        'individualShift requires non-empty, all-elem children',
      );
      final result = <VListChild>[old.first];

      final depth = -old.first.shift - old.first.elem!.depth;
      var currPos = depth;
      for (var i = 1; i < old.length; i++) {
        final diff = -old[i].shift - currPos - old[i].elem!.depth;
        final size = diff - (old[i - 1].elem!.height + old[i - 1].elem!.depth);
        currPos = currPos + diff;
        result
          ..add(VListChild.kern(size))
          ..add(old[i]);
      }
      return (children: result, depth: depth);
    }

    double depth;
    switch (positionType) {
      case VListPositionType.top:
        var bottom = positionData;
        for (final child in children) {
          bottom -= child.isKern
              ? child.size
              : child.elem!.height + child.elem!.depth;
        }
        depth = bottom;
      case VListPositionType.bottom:
        depth = -positionData;
      case VListPositionType.shift:
        final first = children.first;
        assert(!first.isKern, 'First child must be an elem.');
        depth = -first.elem!.depth - positionData;
      case VListPositionType.firstBaseline:
        final first = children.first;
        assert(!first.isKern, 'First child must be an elem.');
        depth = -first.elem!.depth;
      case VListPositionType.individualShift:
        // Handled above.
        throw StateError('unreachable');
    }
    return (children: children, depth: depth);
  }

  // Port of the layout half of KaTeX `makeVList`: walks the (already
  // kern-resolved) children, accumulating positions and tracking minPos/maxPos.
  // KaTeX sets `height = maxPos`, `depth = -minPos`.
  // ignore: prefer_constructors_over_static_methods
  static VList _layout(List<VListChild> children, double depth) {
    final positions = <VListPosition>[];
    var minPos = depth;
    var maxPos = depth;
    var currPos = depth;
    var maxWidth = 0.0;

    for (final child in children) {
      if (child.isKern) {
        currPos += child.size;
      } else {
        final elem = child.elem!;
        // childWrap.style.top = -pstrutSize - currPos - elem.depth; the element
        // baseline sits `currPos + elem.depth` above the vlist bottom, i.e. its
        // downward shift from the vlist baseline is `-(currPos + elem.depth)`.
        positions.add(VListPosition(elem, -(currPos + elem.depth)));
        if (elem.width > maxWidth) {
          maxWidth = elem.width;
        }
        currPos += elem.height + elem.depth;
      }
      if (currPos < minPos) {
        minPos = currPos;
      }
      if (currPos > maxPos) {
        maxPos = currPos;
      }
    }

    return VList._(
      children: children,
      height: maxPos,
      depth: -minPos,
      width: maxWidth,
      positions: positions,
    );
  }

  @override
  String toString() =>
      'VList(${children.length} children, $_dims)';
}

/// A filled rectangle: fraction bars, sqrt lines, underlines, etc.
///
/// Mirrors KaTeX's rule. The dimensions are explicit and reported as-is.
@immutable
class RuleNode extends BoxNode {
  /// Creates a rule of the given explicit [width]/[height]/[depth] (em).
  const RuleNode({required this.width, required this.height, this.depth = 0});

  @override
  final double width;

  @override
  final double height;

  @override
  final double depth;

  @override
  String toString() =>
      'RuleNode($_dims)';
}

/// A notation drawn by an [EncloseNode] (KaTeX `<menclose>` notations).
///
/// Direct port of the notations KaTeX's `enclose.ts` produces:
///  * [box] — a frame on all four sides (`\fbox`, `\boxed`, `\fcolorbox`).
///  * [updiagonalstrike] — bottom-left → top-right line (`\cancel`).
///  * [downdiagonalstrike] — top-left → bottom-right line (`\bcancel`).
///  * [horizontalstrike] — a strike-through at the x-height (`\sout`).
///  * [actuarial] — a top + right border (`\angl`).
///  * [phase] — a Steinmetz phasor angle (`\phase`): a diagonal `\` stroke down
///    the left side joined to a horizontal `_` stroke along the bottom.
///
/// `\xcancel` carries both [updiagonalstrike] and [downdiagonalstrike].
enum EncloseNotation {
  /// A frame on all four sides.
  box,

  /// A diagonal line from bottom-left to top-right.
  updiagonalstrike,

  /// A diagonal line from top-left to bottom-right.
  downdiagonalstrike,

  /// A horizontal strike-through line.
  horizontalstrike,

  /// A top + right border (actuarial angle).
  actuarial,

  /// A Steinmetz phasor angle (`\phase`): a diagonal stroke joined to a
  /// horizontal stroke along the bottom, drawn at the box's lower-left.
  phase,
}

/// A box that draws a background fill, a colored border, and/or strike lines
/// around/over its [child].
///
/// This is the box-tree analogue of KaTeX's `<menclose>` (`enclose.ts`):
/// `\fbox`, `\boxed`, `\colorbox`, `\fcolorbox`, `\cancel`, `\bcancel`,
/// `\xcancel`, `\sout`, `\angl`. The [child] is the (already padded) inner box;
/// its dimensions are the node's dimensions (KaTeX bakes the `\fboxsep` padding
/// and the cancel vertical padding into the inner box, so the enclose node does
/// not change them). Both backends (the SVG serializer and the Flutter painter)
/// draw the decorations relative to the child's box, then paint the child.
///
/// Coordinate note: like every other node, the box spans box-y `[-height,
/// +depth]` (top to bottom) and box-x `[0, width]`. A box/actuarial border
/// is [borderWidth] em thick (drawn inside the box, like CSS `box-sizing:
/// border-box`); the strikes run corner-to-corner of the box (the horizontal
/// strike runs across the x-height line).
@immutable
class EncloseNode extends BoxNode {
  /// Creates an enclose node decorating [child].
  const EncloseNode({
    required this.child,
    required this.notations,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.strikeColor,
    this.phaseLineWidth,
  });

  /// The inner box (already padded by the builder).
  final BoxNode child;

  /// The decorations to draw (see [EncloseNotation]).
  final List<EncloseNotation> notations;

  /// CSS color string for the background fill, or `null` for none.
  final String? backgroundColor;

  /// CSS color string for the [EncloseNotation.box]/[EncloseNotation.actuarial]
  /// border, or `null` to use the inherited (current) color.
  final String? borderColor;

  /// Border thickness in em (KaTeX `\fboxrule` / `defaultRuleThickness`), or
  /// `null` when there is no border.
  final double? borderWidth;

  /// CSS color string for the strike lines, or `null` to use the inherited
  /// (current) color. KaTeX draws cancel/sout strikes in the current color.
  final String? strikeColor;

  /// Stroke width (em) of the [EncloseNotation.phase] angle, or `null` when
  /// there is no phase angle. KaTeX's Steinmetz angle is drawn at `0.6pt`.
  final double? phaseLineWidth;

  @override
  double get width => child.width;

  @override
  double get height => child.height;

  @override
  double get depth => child.depth;

  @override
  String toString() =>
      'EncloseNode($notations'
      '${backgroundColor != null ? ', bg: $backgroundColor' : ''}'
      '${borderColor != null ? ', border: $borderColor' : ''}'
      '${borderWidth != null ? ', bw: ${borderWidth!.toStringAsFixed(4)}' : ''}'
      ', $_dims)';
}

/// An external raster/vector image (`\includegraphics`).
///
/// Mirrors KaTeX's `Img` DOM node. Carries the resolved [src] URL, [alt] text,
/// and a placed box size in **em** ([width]/[height]/[depth]). The SVG
/// serializer emits an `<image>` of that size pointing at [src]; the Flutter
/// painter draws a placeholder outline of the same dimensions (real async image
/// loading is out of scope — see [ImageNode] usage in the painter).
@immutable
class ImageNode extends BoxNode {
  /// Creates an image node sized [width] × ([height] + [depth]) em.
  const ImageNode({
    required this.src,
    required this.alt,
    required this.width,
    required this.height,
    this.depth = 0,
  });

  /// The image source URL/path (emitted as the `<image>` href).
  final String src;

  /// The alternative text.
  final String alt;

  @override
  final double width;

  @override
  final double height;

  @override
  final double depth;

  @override
  String toString() =>
      'ImageNode($src, $_dims)';
}

/// A wrapper node carrying presentation metadata (color, classes, sizing).
///
/// Mirrors KaTeX's `Span`: it groups [children] and may apply a [color],
/// CSS-like [classes], and a [sizeMultiplier]. Its dimensions encompass the
/// children exactly like an [HBox] (max height/depth, summed width), so a
/// builder can use a [SpanNode] as a colored/classed horizontal group.
@immutable
class SpanNode extends BoxNode {
  /// Creates a span wrapping [children].
  const SpanNode(
    this.children, {
    this.color,
    this.classes = const [],
    this.sizeMultiplier = 1.0,
  });

  /// The wrapped children, laid out horizontally like an [HBox].
  final List<BoxNode> children;

  /// An optional color applied to the subtree (CSS color string, e.g.
  /// `#ff0000`). `null` means inherit.
  final String? color;

  /// CSS-like class names carried for the consumer (e.g. sizing/font hints).
  final List<String> classes;

  /// A size multiplier applied to the group (KaTeX sizing), default `1.0`.
  final double sizeMultiplier;

  @override
  double get width => _sumWidth(children);

  @override
  double get height => _maxHeight(children);

  @override
  double get depth => _maxDepth(children);

  @override
  String toString() =>
      'SpanNode(${children.length} children'
      '${color != null ? ', color: $color' : ''}'
      '${classes.isNotEmpty ? ', classes: $classes' : ''}, '
      '$_dims)';
}

/// How an [SvgPathNode]'s viewBox maps onto its box (KaTeX's SVG
/// `preserveAspectRatio`).
///
/// KaTeX uses two behaviors that matter for stretchy geometry:
///  * [none] — non-uniform stretch: the viewBox is scaled independently in x
///    and y to exactly fill the box (used by stacked delimiters, whose
///    `viewBoxWidth`/`viewBoxHeight` are the real path extents).
///  * [xMinYMinSlice] — uniform scale to *cover* the box, anchored top-left,
///    overflow clipped (used by the `\sqrt` surd, whose viewBox is
///    `0 0 400000 viewBoxHeight`: the path is drawn 400em wide and the box only
///    shows the left `advanceWidth` of it — the long vinculum runs off-box and
///    is clipped, exactly KaTeX's `width:"400em"` + `slice`). Also used for the
///    left half of stretchy arrows / left-pointing arrows (`\overleftarrow`),
///    whose arrowhead sits at the *left* end of the 400em path, so anchoring
///    the left edge keeps the head visible while the shaft tail runs off-box.
///  * [xMaxYMinSlice] — uniform scale to *cover* the box, anchored
///    top-**right**, overflow clipped. Used for right-pointing stretchy
///    arrows (`\overrightarrow`), whose arrowhead sits at the *right* end
///    (x≈400000) of the 400em path: anchoring the right edge keeps the head
///    visible at the box right while the shaft tail runs off the *left*.
///    Mirrors KaTeX's `preserveAspectRatio:"xMaxYMin slice"`.
enum SvgPreserveAspectRatio {
  /// Non-uniform stretch to fill the box exactly.
  none,

  /// Uniform scale to cover the box, top-left anchored, overflow clipped.
  xMinYMinSlice,

  /// Uniform scale to cover the box, top-right anchored, overflow clipped.
  xMaxYMinSlice,

  /// Uniform scale to cover the box, top-center anchored, overflow clipped.
  /// Used by the center piece of stretchy braces (`\overbrace`/`\underbrace`).
  xMidYMinSlice,
}

/// A stretchy SVG path: the real geometry for `\sqrt` surds and stacked
/// `\left…\right` / `\bigl…` delimiters.
///
/// Mirrors KaTeX's `PathNode` wrapped in an `SvgNode`/`SvgSpan`. The builder
/// resolves the actual `d` string (from `svg_geometry.g.dart`) and the SVG's
/// `viewBox`; the node also carries the placed box dimensions in **em**
/// ([width]/[height]/[depth]) and a [preserveAspectRatio] hint so the SVG
/// serializer and the Flutter painter agree on how to scale the viewBox onto
/// the box. Backend-agnostic: it holds only data, no `dart:ui`.
///
/// Coordinate note: SVG path y grows *down* from the viewBox top. The box's
/// ink spans from `-height` (top, above baseline) to `+depth` (bottom). The
/// consumer maps viewBox-y `[0, viewBoxHeight]` onto box-y `[-height, +depth]`.
@immutable
class SvgPathNode extends BoxNode {
  /// Creates an SVG path slot with resolved geometry.
  const SvgPathNode({
    required this.pathName,
    required this.pathData,
    required this.viewBoxWidth,
    required this.viewBoxHeight,
    required this.width,
    required this.height,
    this.depth = 0,
    this.preserveAspectRatio = SvgPreserveAspectRatio.none,
  });

  /// The KaTeX path name (e.g. `sqrtMain`, `lparen`) — diagnostic / class hint.
  final String pathName;

  /// The resolved SVG path `d` attribute (the actual geometry to draw).
  final String pathData;

  /// The viewBox width in path units (KaTeX's 1000:1 viewBox scale).
  final double viewBoxWidth;

  /// The viewBox height in path units (KaTeX's 1000:1 viewBox scale).
  final double viewBoxHeight;

  /// How the viewBox maps onto the box (see [SvgPreserveAspectRatio]).
  final SvgPreserveAspectRatio preserveAspectRatio;

  @override
  final double width;

  @override
  final double height;

  @override
  final double depth;

  /// The viewBox as the SVG `viewBox` attribute string (`0 0 w h`).
  String get viewBox => '0 0 ${_n(viewBoxWidth)} ${_n(viewBoxHeight)}';

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  String toString() =>
      'SvgPathNode($pathName, '
      'vb: ${_n(viewBoxWidth)}x${_n(viewBoxHeight)}, '
      '$_dims)';
}
