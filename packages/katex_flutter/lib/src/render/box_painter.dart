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
///  * [SvgPathNode] → the SVG `d` path is parsed to a [Path] and filled via
///    [Canvas.drawPath], with the path's viewBox mapped onto the node's box
///    (honoring [SvgPreserveAspectRatio]); this draws `\sqrt` surds and stacked
///    stretchy delimiters.
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
        _paintSvgPath(canvas, node, x, baselineY, currentColor);
      case EncloseNode():
        _paintEnclose(canvas, node, x, baselineY, currentColor);
      case ImageNode():
        _paintImage(canvas, node, x, baselineY, currentColor);
    }
  }

  // --- Image (\includegraphics) ---------------------------------------------

  // Real async bitmap loading is OUT OF SCOPE for this backend: the box tree is
  // painted synchronously and has no image cache, so we cannot fetch the URL
  // here. Instead we reserve the correct space (the [ImageNode] already carries
  // the resolved em dimensions) and draw a thin placeholder outline so the
  // layout is faithful. A future ticket can add an async ImageProvider cache.
  void _paintImage(
    Canvas canvas,
    ImageNode node,
    double x,
    double baselineY,
    Color currentColor,
  ) {
    final left = x;
    // A natural-width image (width == 0) has no reserved horizontal advance in
    // the box tree; draw the placeholder at its (height) square so it is still
    // visible. KaTeX leaves such an image to its intrinsic bitmap width.
    final boxH = (node.height + node.depth) * fontSize;
    final w = node.width > 0 ? node.width * fontSize : boxH;
    final top = baselineY - node.height * fontSize;
    if (w <= 0 || boxH <= 0) {
      return;
    }
    canvas.drawRect(
      Rect.fromLTWH(left, top, w, boxH),
      Paint()
        ..color = currentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  // --- Enclose (frame / fill / strikes) -------------------------------------

  void _paintEnclose(
    Canvas canvas,
    EncloseNode node,
    double x,
    double baselineY,
    Color currentColor,
  ) {
    // The decorations span the child's box: box-x [x, x+width], box-y
    // [baselineY-height, baselineY+depth]. y grows downward.
    final left = x;
    final right = x + node.width * fontSize;
    final top = baselineY - node.height * fontSize;
    final bottom = baselineY + node.depth * fontSize;
    final hasBox = node.notations.contains(EncloseNotation.box);
    final hasActuarial = node.notations.contains(EncloseNotation.actuarial);

    // Background fill (behind the child).
    final bg = _parseColor(node.backgroundColor);
    if (bg != null) {
      canvas.drawRect(
        Rect.fromLTRB(left, top, right, bottom),
        Paint()
          ..color = bg
          ..style = PaintingStyle.fill,
      );
    }

    // Full frame (box): stroked rect inset by half the border width.
    if (hasBox && node.borderWidth != null) {
      final bw = node.borderWidth! * fontSize;
      final stroke = _parseColor(node.borderColor) ?? currentColor;
      canvas.drawRect(
        Rect.fromLTRB(
          left + bw / 2,
          top + bw / 2,
          right - bw / 2,
          bottom - bw / 2,
        ),
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = bw,
      );
    }

    // Actuarial angle: top border + right border.
    if (hasActuarial && node.borderWidth != null) {
      final bw = node.borderWidth! * fontSize;
      final stroke = _parseColor(node.borderColor) ?? currentColor;
      final paint = Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = bw;
      canvas
        ..drawLine(
          Offset(left, top + bw / 2),
          Offset(right, top + bw / 2),
          paint,
        )
        ..drawLine(
          Offset(right - bw / 2, top),
          Offset(right - bw / 2, bottom),
          paint,
        );
    }

    // Strikes.
    final strikeColor = _parseColor(node.strikeColor) ?? currentColor;
    const strokeWEm = 0.046;
    final strikePaint = Paint()
      ..color = strikeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWEm * fontSize;
    if (node.notations.contains(EncloseNotation.updiagonalstrike)) {
      canvas.drawLine(Offset(left, bottom), Offset(right, top), strikePaint);
    }
    if (node.notations.contains(EncloseNotation.downdiagonalstrike)) {
      canvas.drawLine(Offset(left, top), Offset(right, bottom), strikePaint);
    }
    if (node.notations.contains(EncloseNotation.horizontalstrike)) {
      final y = baselineY - 0.25 * fontSize;
      canvas.drawLine(
        Offset(left, y),
        Offset(right, y),
        Paint()
          ..color = strikeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.08 * fontSize,
      );
    }

    // \phase: the Steinmetz angle — a diagonal stroke down to the bottom-left
    // corner joined to a horizontal stroke along the bottom (mirrors the SVG
    // serializer and the shape KaTeX's `phasePath` SVG produces).
    if (node.notations.contains(EncloseNotation.phase) &&
        node.phaseLineWidth != null) {
      final lw = node.phaseLineWidth! * fontSize;
      final h = (node.height + node.depth) * fontSize;
      final phasePaint = Paint()
        ..color = strikeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = lw;
      canvas
        ..drawLine(
          Offset(left + h / 2, top + lw / 2),
          Offset(left + lw / 2, bottom - lw / 2),
          phasePaint,
        )
        ..drawLine(
          Offset(left, bottom - lw / 2),
          Offset(right, bottom - lw / 2),
          phasePaint,
        );
    }

    // The content on top.
    _paintNode(canvas, node.child, x, baselineY, currentColor);
  }

  // --- SvgPath (stretchy delimiters / sqrt surd) ----------------------------

  void _paintSvgPath(
    Canvas canvas,
    SvgPathNode node,
    double x,
    double baselineY,
    Color currentColor,
  ) {
    if (node.pathData.isEmpty || node.viewBoxWidth <= 0 ||
        node.viewBoxHeight <= 0) {
      return;
    }
    final path = parseSvgPath(node.pathData);

    // Destination rect (pixels): box-x [0,width] and box-y [-height,+depth]
    // relative to the baseline.
    final dstLeft = x;
    final dstTop = baselineY - node.height * fontSize;
    final dstW = node.width * fontSize;
    final dstH = (node.height + node.depth) * fontSize;
    if (dstW <= 0 || dstH <= 0) {
      return;
    }

    final sx = dstW / node.viewBoxWidth;
    final sy = dstH / node.viewBoxHeight;

    canvas
      ..save()
      // Clip to the box so the (slice) overflow of a 400em-wide surd viewBox is
      // cut to the box, exactly like the SVG renderer.
      ..clipRect(Rect.fromLTWH(dstLeft, dstTop, dstW, dstH))
      ..translate(dstLeft, dstTop);

    switch (node.preserveAspectRatio) {
      case SvgPreserveAspectRatio.none:
        // Non-uniform stretch to fill the box.
        canvas.scale(sx, sy);
      case SvgPreserveAspectRatio.xMinYMinSlice:
        // Uniform cover scale, top-left anchored (xMinYMin), overflow clipped.
        final s = sx > sy ? sx : sy;
        canvas.scale(s, s);
      case SvgPreserveAspectRatio.xMaxYMinSlice:
        // Uniform cover scale, top-RIGHT anchored (xMaxYMin), overflow clipped.
        // Shift so the scaled viewBox's right edge meets the box's right edge,
        // keeping the arrowhead at x≈viewBoxWidth visible; the long shaft tail
        // runs off the left and is cut by the clipRect above.
        final s = sx > sy ? sx : sy;
        final dx = dstW - node.viewBoxWidth * s;
        canvas
          ..translate(dx, 0)
          ..scale(s, s);
      case SvgPreserveAspectRatio.xMidYMinSlice:
        // Uniform cover scale, top-CENTER anchored (xMidYMin): used by the
        // center piece of stretchy braces so the central tooth stays centered.
        final s = sx > sy ? sx : sy;
        final dx = (dstW - node.viewBoxWidth * s) / 2;
        canvas
          ..translate(dx, 0)
          ..scale(s, s);
    }

    final paint = Paint()
      ..color = currentColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas
      ..drawPath(path, paint)
      ..restore();
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
    // A glyph paints at its box origin. `skew`/`italic` are metadata consumed
    // by builders (accent placement, supsub correction) and are baked into the
    // box tree — they must NOT offset the glyph here, or slanted glyphs
    // (math-italic `f`, skew 0.167em) get pushed into following content
    // (overlapping `f'` primes) and misaligned. Mirrors the SVG serializer.
    final dx = x;
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
    if (node.isDashed) {
      // Dashed line down the long axis (`:` / `\hdashline`). Stroke width = the
      // thin dimension; dash cadence ~3× the stroke (browser-default look).
      final w = right - left;
      final h = bottom - top;
      final isVertical = h >= w;
      final sw = isVertical ? w : h;
      final dash = sw * 3;
      final paint = Paint()
        ..color = currentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw;
      final double sx;
      final double sy;
      final double ex;
      final double ey;
      if (isVertical) {
        sx = ex = left + w / 2;
        sy = top;
        ey = bottom;
      } else {
        sy = ey = top + h / 2;
        sx = left;
        ex = right;
      }
      final total = isVertical ? (ey - sy) : (ex - sx);
      final dx = isVertical ? 0.0 : 1.0;
      final dy = isVertical ? 1.0 : 0.0;
      var pos = 0.0;
      while (pos < total) {
        final segEnd = (pos + dash).clamp(0.0, total);
        canvas.drawLine(
          Offset(sx + dx * pos, sy + dy * pos),
          Offset(sx + dx * segEnd, sy + dy * segEnd),
          paint,
        );
        pos += dash * 2; // dash + equal gap
      }
      return;
    }
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

/// Parses an SVG path `d` string into a [Path].
///
/// Supports the full SVG path command set that appears in KaTeX's
/// `svgGeometry` data: move (`M`/`m`), line (`L`/`l`, `H`/`h`, `V`/`v`), cubic
/// Bézier (`C`/`c`, `S`/`s`), quadratic Bézier (`Q`/`q`, `T`/`t`), elliptical
/// arc (`A`/`a`), and close (`Z`/`z`), in both absolute (uppercase) and
/// relative (lowercase) forms, including the SVG implicit-repeat rule (extra
/// coordinate sets after a command repeat it; extras after `M`/`m` are treated
/// as `L`/`l`). Numbers may be separated by whitespace and/or commas, may omit
/// the leading `0` (`.5`), and may pack a sign as a separator (`1-2`).
///
/// Exposed (non-private) so it can be unit-tested directly.
Path parseSvgPath(String d) {
  return _SvgPathParser(d).parse();
}

class _SvgPathParser {
  _SvgPathParser(this._d);

  final String _d;
  int _pos = 0;

  final Path _path = Path();

  // Current point.
  double _cx = 0;
  double _cy = 0;
  // Subpath start (for Z).
  double _sx = 0;
  double _sy = 0;
  // Last control point of the previous cubic/quadratic, for S/T smoothing.
  double? _lastCubicCx;
  double? _lastCubicCy;
  double? _lastQuadCx;
  double? _lastQuadCy;

  Path parse() {
    String? cmd;
    while (true) {
      _skipSep();
      if (_pos >= _d.length) {
        break;
      }
      final ch = _d[_pos];
      if (_isCommand(ch)) {
        cmd = ch;
        _pos++;
      } else if (cmd == null) {
        // Malformed: bail gracefully with whatever we have.
        break;
      }
      _runCommand(cmd);
      // After M/m the implicit repeat is L/l.
      if (cmd == 'M') {
        cmd = 'L';
      } else if (cmd == 'm') {
        cmd = 'l';
      }
    }
    return _path;
  }

  void _runCommand(String cmd) {
    switch (cmd) {
      case 'M':
        final x = _num();
        final y = _num();
        _cx = x;
        _cy = y;
        _path.moveTo(_cx, _cy);
        _sx = _cx;
        _sy = _cy;
        _resetSmooth();
      case 'm':
        final x = _num();
        final y = _num();
        _cx += x;
        _cy += y;
        _path.moveTo(_cx, _cy);
        _sx = _cx;
        _sy = _cy;
        _resetSmooth();
      case 'L':
        final x = _num();
        final y = _num();
        _cx = x;
        _cy = y;
        _path.lineTo(_cx, _cy);
        _resetSmooth();
      case 'l':
        _cx += _num();
        _cy += _num();
        _path.lineTo(_cx, _cy);
        _resetSmooth();
      case 'H':
        _cx = _num();
        _path.lineTo(_cx, _cy);
        _resetSmooth();
      case 'h':
        _cx += _num();
        _path.lineTo(_cx, _cy);
        _resetSmooth();
      case 'V':
        _cy = _num();
        _path.lineTo(_cx, _cy);
        _resetSmooth();
      case 'v':
        _cy += _num();
        _path.lineTo(_cx, _cy);
        _resetSmooth();
      case 'C':
        _cubic(_num(), _num(), _num(), _num(), _num(), _num());
      case 'c':
        _cubic(
          _cx + _num(),
          _cy + _num(),
          _cx + _num(),
          _cy + _num(),
          _cx + _num(),
          _cy + _num(),
        );
      case 'S':
        final c1 = _reflectedCubic();
        _cubic(c1.dx, c1.dy, _num(), _num(), _num(), _num());
      case 's':
        final c1 = _reflectedCubic();
        _cubic(
          c1.dx,
          c1.dy,
          _cx + _num(),
          _cy + _num(),
          _cx + _num(),
          _cy + _num(),
        );
      case 'Q':
        _quad(_num(), _num(), _num(), _num());
      case 'q':
        _quad(_cx + _num(), _cy + _num(), _cx + _num(), _cy + _num());
      case 'T':
        final c = _reflectedQuad();
        _quad(c.dx, c.dy, _num(), _num());
      case 't':
        final c = _reflectedQuad();
        _quad(c.dx, c.dy, _cx + _num(), _cy + _num());
      case 'A':
        _arc(_num(), _num(), _num(), _num(), _num(), _num(), _num());
      case 'a':
        _arc(
          _num(),
          _num(),
          _num(),
          _num(),
          _num(),
          _cx + _num(),
          _cy + _num(),
        );
      case 'Z':
      case 'z':
        _path.close();
        _cx = _sx;
        _cy = _sy;
        _resetSmooth();
      default:
        // Unknown command: skip one number to avoid an infinite loop.
        if (_hasNumber()) {
          _num();
        }
    }
  }

  void _cubic(
    double x1,
    double y1,
    double x2,
    double y2,
    double x,
    double y,
  ) {
    _path.cubicTo(x1, y1, x2, y2, x, y);
    _cx = x;
    _cy = y;
    _lastCubicCx = x2;
    _lastCubicCy = y2;
    _lastQuadCx = null;
    _lastQuadCy = null;
  }

  void _quad(double x1, double y1, double x, double y) {
    _path.quadraticBezierTo(x1, y1, x, y);
    _cx = x;
    _cy = y;
    _lastQuadCx = x1;
    _lastQuadCy = y1;
    _lastCubicCx = null;
    _lastCubicCy = null;
  }

  Offset _reflectedCubic() {
    if (_lastCubicCx != null) {
      return Offset(2 * _cx - _lastCubicCx!, 2 * _cy - _lastCubicCy!);
    }
    return Offset(_cx, _cy);
  }

  Offset _reflectedQuad() {
    if (_lastQuadCx != null) {
      return Offset(2 * _cx - _lastQuadCx!, 2 * _cy - _lastQuadCy!);
    }
    return Offset(_cx, _cy);
  }

  void _arc(
    double rx,
    double ry,
    double xAxisRotation,
    double largeArc,
    double sweep,
    double x,
    double y,
  ) {
    _path.arcToPoint(
      Offset(x, y),
      radius: Radius.elliptical(rx, ry),
      rotation: xAxisRotation,
      largeArc: largeArc != 0,
      clockwise: sweep != 0,
    );
    _cx = x;
    _cy = y;
    _resetSmooth();
  }

  void _resetSmooth() {
    _lastCubicCx = null;
    _lastCubicCy = null;
    _lastQuadCx = null;
    _lastQuadCy = null;
  }

  // --- Tokenizer ------------------------------------------------------------

  static bool _isCommand(String c) =>
      'MmLlHhVvCcSsQqTtAaZz'.contains(c);

  void _skipSep() {
    while (_pos < _d.length) {
      final c = _d.codeUnitAt(_pos);
      // space, tab, CR, LF, comma
      if (c == 0x20 || c == 0x09 || c == 0x0d || c == 0x0a || c == 0x2c) {
        _pos++;
      } else {
        break;
      }
    }
  }

  bool _hasNumber() {
    _skipSep();
    if (_pos >= _d.length) {
      return false;
    }
    final c = _d[_pos];
    return (c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39) ||
        c == '-' ||
        c == '+' ||
        c == '.';
  }

  double _num() {
    _skipSep();
    final start = _pos;
    var seenDot = false;
    var seenExp = false;
    if (_pos < _d.length && (_d[_pos] == '-' || _d[_pos] == '+')) {
      _pos++;
    }
    while (_pos < _d.length) {
      final c = _d[_pos];
      final code = c.codeUnitAt(0);
      if (code >= 0x30 && code <= 0x39) {
        _pos++;
      } else if (c == '.' && !seenDot && !seenExp) {
        seenDot = true;
        _pos++;
      } else if ((c == 'e' || c == 'E') && !seenExp) {
        seenExp = true;
        _pos++;
        if (_pos < _d.length && (_d[_pos] == '-' || _d[_pos] == '+')) {
          _pos++;
        }
      } else {
        break;
      }
    }
    if (_pos == start) {
      // No number where one was expected; consume one char to make progress.
      _pos++;
      return 0;
    }
    return double.tryParse(_d.substring(start, _pos)) ?? 0;
  }
}
