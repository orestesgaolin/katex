/// A Flutter [CustomPainter] that paints the backend-agnostic box tree
/// ([BoxNode]) produced by the pure-Dart `katex` package onto a [Canvas].
///
/// This is the Flutter rendering path described in `PLAN.md` (milestone 5). It
/// is a *pure consumer* of the box tree (T-009/T-010) — it never parses or
/// builds anything. It mirrors the SVG serializer (T-012) so the two backends
/// agree on layout:
///  * [GlyphNode] → a [TextPainter] placed on its baseline (with skew applied
///    as a horizontal nudge, like the serializer).
///  * [RuleNode] → a filled [Canvas.drawRect].
///  * [HBox] / [SpanNode] children → laid out left-to-right (x advances by
///    child width); [KernNode]s just advance x.
///  * [VList] → children placed at their resolved downward shifts
///    ([VList.positions]) — exactly the convention the serializer uses.
///  * [SpanNode] → applies its color to descendants.
///  * [SvgPathNode] → MVP stub: nothing is drawn (stretchy geometry lands in
///    M6).
///
/// ## Coordinate system
/// Box dimensions are in **em** (relative to the baseline). The painter
/// converts em → logical pixels by multiplying by `fontSize` (pixels per em).
/// The painter's origin is the top-left of the root box; the root baseline is
/// at `y = root.height * fontSize`. Flutter's y-axis (like SVG's) points
/// *down*, so a child placed `dy` em **below** the baseline moves
/// `+dy * fontSize` in y. The painter walks the tree carrying a current
/// `(x, baselineY)` in pixels.
library;

import 'package:flutter/widgets.dart';
import 'package:katex/katex.dart';
import 'package:katex_flutter/src/font_mapping.dart';

/// The intrinsic pixel size of [root] painted at [fontSize] pixels per em.
///
/// Width is `root.width * fontSize`; height spans from the top of the box
/// (height above the baseline) to the bottom (depth below):
/// `(root.height + root.depth) * fontSize`. The widget layer (T-017) uses this
/// to size itself.
Size boxSizePx(BoxNode root, double fontSize) {
  final w = root.width * fontSize;
  final h = (root.height + root.depth) * fontSize;
  return Size(w < 0 ? 0 : w, h < 0 ? 0 : h);
}

/// Paints a [BoxNode] tree onto a [Canvas].
///
/// Pass the root [BoxNode], a [fontSize] (logical pixels per em — e.g. 20–44),
/// and an optional base [color] used where no enclosing [SpanNode] sets one.
class KatexBoxPainter extends CustomPainter {
  /// Creates a painter for [root].
  KatexBoxPainter(
    this.root, {
    required this.fontSize,
    this.color = const Color(0xFF000000),
  });

  /// The root of the box tree to paint.
  final BoxNode root;

  /// Logical pixels per em.
  final double fontSize;

  /// The base color used when no enclosing [SpanNode] sets a color.
  final Color color;

  // Cache of laid-out TextPainters keyed by (text, family, variant, size, rgb)
  // so repeated glyphs (and repaints with the same content) reuse layout work.
  final Map<_GlyphKey, TextPainter> _glyphCache = {};

  @override
  void paint(Canvas canvas, Size size) {
    final baselineY = root.height * fontSize;
    _paintNode(canvas, root, 0, baselineY, color);
  }

  /// Paints [node] with its baseline at [baselineY] (px from the top) and its
  /// left edge at [x] (px), inheriting [currentColor].
  void _paintNode(
    Canvas canvas,
    BoxNode node,
    double x,
    double baselineY,
    Color currentColor,
  ) {
    switch (node) {
      case GlyphNode():
        _paintGlyph(canvas, node, x, baselineY, currentColor);
      case RuleNode():
        _paintRule(canvas, node, x, baselineY, currentColor);
      case KernNode():
        // A bare kern has no visual; it only advances x inside an
        // HBox/Span, which the horizontal layout handles.
        break;
      case HBox():
        _paintHorizontal(canvas, node.children, x, baselineY, currentColor);
      case SpanNode():
        _paintSpan(canvas, node, x, baselineY, currentColor);
      case VList():
        _paintVList(canvas, node, x, baselineY, currentColor);
      case SvgPathNode():
        // MVP stub: stretchy delimiter/accent geometry lands in M6.
        break;
    }
  }

  // --- Glyph ----------------------------------------------------------------

  void _paintGlyph(
    Canvas canvas,
    GlyphNode node,
    double x,
    double baselineY,
    Color currentColor,
  ) {
    final tp = _textPainterFor(node, currentColor);
    // KaTeX applies skew as a leftward/rightward nudge of the glyph (used for
    // accent placement); mirror the serializer by offsetting x by skew.
    final dx = x + node.scaledSkew * fontSize;
    // TextPainter paints from the top-left; shift up by the distance from the
    // text's top to its alphabetic baseline so the glyph baseline lands on
    // baselineY.
    final ascent = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final dy = baselineY - ascent;
    tp.paint(canvas, Offset(dx, dy));
  }

  TextPainter _textPainterFor(GlyphNode node, Color currentColor) {
    final key = _GlyphKey(
      text: node.text,
      family: node.font.cssFamily,
      variant: node.font.variant,
      sizePx: node.size * fontSize,
      colorValue: currentColor.toARGB32(),
    );
    final cached = _glyphCache[key];
    if (cached != null) {
      return cached;
    }
    final style = textStyleFor(
      node.font,
      node.size * fontSize,
      color: currentColor,
    );
    final tp = TextPainter(
      text: TextSpan(text: node.text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    _glyphCache[key] = tp;
    return tp;
  }

  // --- Rule -----------------------------------------------------------------

  void _paintRule(
    Canvas canvas,
    RuleNode node,
    double x,
    double baselineY,
    Color currentColor,
  ) {
    final top = baselineY - node.height * fontSize;
    final bottom = baselineY + node.depth * fontSize;
    final left = x;
    final right = x + node.width * fontSize;
    final paint = Paint()
      ..color = currentColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), paint);
  }

  // --- Horizontal layout (HBox + Span children) -----------------------------

  void _paintHorizontal(
    Canvas canvas,
    List<BoxNode> children,
    double x,
    double baselineY,
    Color currentColor,
  ) {
    var cursor = x;
    for (final child in children) {
      if (child is KernNode) {
        cursor += child.width * fontSize;
        continue;
      }
      _paintNode(canvas, child, cursor, baselineY, currentColor);
      cursor += child.width * fontSize;
    }
  }

  // --- Span -----------------------------------------------------------------

  void _paintSpan(
    Canvas canvas,
    SpanNode node,
    double x,
    double baselineY,
    Color currentColor,
  ) {
    final spanColor = _parseColor(node.color) ?? currentColor;
    _paintHorizontal(canvas, node.children, x, baselineY, spanColor);
  }

  // --- VList ----------------------------------------------------------------

  void _paintVList(
    Canvas canvas,
    VList node,
    double x,
    double baselineY,
    Color currentColor,
  ) {
    for (final pos in node.positions) {
      // `shift` is the downward offset of the element's baseline from the
      // vlist baseline (positive = down) → directly a +y in pixels. This
      // mirrors the SVG serializer exactly.
      final childBaselineY = baselineY + pos.shift * fontSize;
      _paintNode(canvas, pos.box, x, childBaselineY, currentColor);
    }
  }

  // --- Color parsing --------------------------------------------------------

  /// Parses a CSS-ish color string ([str]) into a [Color], or `null` when it is
  /// absent/unparseable (so the caller falls back to the inherited color).
  ///
  /// Supports `#rgb`, `#rrggbb`, `#rrggbbaa`, and a small set of named colors.
  /// MVP: anything else returns `null`.
  static Color? _parseColor(String? str) {
    if (str == null) {
      return null;
    }
    final s = str.trim();
    if (s.isEmpty) {
      return null;
    }
    if (s.startsWith('#')) {
      return _parseHex(s.substring(1));
    }
    return _namedColors[s.toLowerCase()];
  }

  static Color? _parseHex(String hex) {
    int? parse(String h) => int.tryParse(h, radix: 16);
    switch (hex.length) {
      case 3:
        // #rgb → #rrggbb
        final r = parse(hex[0]);
        final g = parse(hex[1]);
        final b = parse(hex[2]);
        if (r == null || g == null || b == null) {
          return null;
        }
        return Color.fromARGB(0xFF, r * 17, g * 17, b * 17);
      case 6:
        final v = parse(hex);
        if (v == null) {
          return null;
        }
        return Color(0xFF000000 | v);
      case 8:
        final v = parse(hex);
        if (v == null) {
          return null;
        }
        // CSS #rrggbbaa → ARGB.
        final rgb = v >> 8;
        final a = v & 0xFF;
        return Color((a << 24) | rgb);
      default:
        return null;
    }
  }

  static const Map<String, Color> _namedColors = {
    'black': Color(0xFF000000),
    'white': Color(0xFFFFFFFF),
    'red': Color(0xFFFF0000),
    'green': Color(0xFF008000),
    'blue': Color(0xFF0000FF),
    'yellow': Color(0xFFFFFF00),
    'cyan': Color(0xFF00FFFF),
    'magenta': Color(0xFFFF00FF),
    'gray': Color(0xFF808080),
    'grey': Color(0xFF808080),
    'orange': Color(0xFFFFA500),
    'purple': Color(0xFF800080),
    'pink': Color(0xFFFFC0CB),
    'brown': Color(0xFFA52A2A),
  };

  @override
  bool shouldRepaint(covariant KatexBoxPainter oldDelegate) {
    return !identical(oldDelegate.root, root) ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.color != color;
  }
}

/// Cache key for a laid-out glyph [TextPainter].
@immutable
class _GlyphKey {
  const _GlyphKey({
    required this.text,
    required this.family,
    required this.variant,
    required this.sizePx,
    required this.colorValue,
  });

  final String text;
  final String family;
  final KatexFontVariant variant;
  final double sizePx;
  final int colorValue;

  @override
  bool operator ==(Object other) =>
      other is _GlyphKey &&
      other.text == text &&
      other.family == family &&
      other.variant == variant &&
      other.sizePx == sizePx &&
      other.colorValue == colorValue;

  @override
  int get hashCode => Object.hash(text, family, variant, sizePx, colorValue);
}
