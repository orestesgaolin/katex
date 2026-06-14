/// Serializes the backend-agnostic box tree ([BoxNode]) to a self-contained
/// SVG string.
///
/// This is the no-Flutter rendering path described in `PLAN.md` (milestone 4).
/// It is a *pure consumer* of the box tree produced by the builder (T-009/T-010)
/// — it does not parse or build anything itself. Feed it a [BoxNode] and it
/// walks the tree, emitting:
///  * [GlyphNode] → `<text>` placed on its baseline, with the KaTeX CSS
///    `font-family`, the scaled `font-size`, and italic/skew offsets applied.
///  * [RuleNode] → a filled `<rect>`.
///  * [HBox] → children laid out left-to-right (x advances by child width),
///    each wrapped in a `<g transform="translate(x,0)">`. [KernNode]s
///    advance x.
///  * [VList] → children placed at their resolved downward shifts
///    ([VList.positions]) via `<g transform="translate(0,dy)">`.
///  * [SpanNode] → a `<g>` applying `fill` (color) and laid out like an [HBox].
///  * [SvgPathNode] → emitted as a best-effort `<path>` stub (see notes); the
///    full stretchy geometry lands in M6.
///
/// ## Coordinate system
/// Box dimensions are in **em** (relative to the baseline). The serializer
/// converts em → SVG user units by multiplying by [defaultFontSize] (or the
/// caller-supplied `fontSize`): one em becomes `fontSize` user units. SVG's
/// y-axis points *down*, so a child placed `dy` em **below** the baseline moves
/// `+dy * fontSize` in SVG y.
///
/// The whole drawing is wrapped in one outer `<g>` that translates the origin
/// down to the root box's baseline: `translate(0, height * fontSize)`. Inside
/// that group, the baseline is `y = 0`, the top of the box is at
/// `y = -height * fontSize`, and the bottom (depth) is at
/// `y = +depth * fontSize`.
/// The root `<svg>` therefore gets:
///  * `width  = root.width  * fontSize`
///  * `height = (root.height + root.depth) * fontSize`
///  * `viewBox = "0 0 width height"`
/// so the entire box (everything above and below the baseline) is visible.
///
/// ## Self-containment
/// The fonts are embedded as base64 `data:` URIs inside `<defs><style>` via
/// `@font-face` rules, sourced from the generated [katexFontBase64] map. The
/// output renders in browsers / librsvg / resvg with no external assets.
library;

import 'package:katex/src/box/box_node.dart';
import 'package:katex/src/font/embedded_fonts.g.dart';
import 'package:katex/src/font/font_types.dart';

/// The default em → user-unit scale (SVG user units per em).
///
/// KaTeX lays everything out in em and renders at the surrounding CSS
/// font-size; there is no single "correct" pixel size. We pick **44**, a clean
/// value that yields legible standalone output (a 1-em-tall glyph is ~44 units)
/// and matches the size the reference oracle screenshots at. Callers can
/// override per-call via [serializeBox]'s `fontSize`.
const double defaultFontSize = 44;

/// Serializes [root] to a complete, self-contained SVG document string.
///
/// [fontSize] is the em → user-unit scale (see [defaultFontSize]); larger
/// values produce a physically larger drawing. The returned string is a
/// standalone `<svg>…</svg>` document with embedded `@font-face` fonts.
///
/// This is the MVP-facing entry point. The public `renderToSvg(tex)` (which
/// parses + builds + serializes) is wired up in T-011/T-013 and simply calls
/// this with the built box tree.
// TODO(team): T-011/T-013 — wire `renderToSvg(String tex, {KatexOptions})` in
// `lib/katex.dart` to build a BoxNode then call serializeBox().
String serializeBox(BoxNode root, {double fontSize = defaultFontSize}) {
  return _SvgSerializer(fontSize: fontSize).serialize(root);
}

class _SvgSerializer {
  _SvgSerializer({required this.fontSize});

  /// SVG user units per em.
  final double fontSize;

  final StringBuffer _buf = StringBuffer();

  String serialize(BoxNode root) {
    final widthU = root.width * fontSize;
    final heightU = root.height * fontSize;
    final depthU = root.depth * fontSize;
    // Total drawing height spans from the top of the box (height above the
    // baseline) to the bottom (depth below). Guard against degenerate zero.
    final totalHeightU = heightU + depthU;
    final svgWidth = widthU <= 0 ? 0.0 : widthU;
    final svgHeight = totalHeightU <= 0 ? 0.0 : totalHeightU;

    _buf
      ..write('<svg xmlns="http://www.w3.org/2000/svg" ')
      ..write('width="${_num(svgWidth)}" height="${_num(svgHeight)}" ')
      ..write('viewBox="0 0 ${_num(svgWidth)} ${_num(svgHeight)}">');

    _writeFontDefs();

    // Move the origin down to the root baseline so children can be placed in
    // baseline-relative em coordinates (y grows downward).
    _buf.write('<g transform="translate(0,${_num(heightU)})">');
    _writeNode(root);
    _buf
      ..write('</g>')
      ..write('</svg>');
    return _buf.toString();
  }

  // --- Node dispatch --------------------------------------------------------

  /// Emits [node] in the *current* coordinate frame, where `y = 0` is the
  /// node's baseline and one em equals [fontSize] user units.
  void _writeNode(BoxNode node) {
    switch (node) {
      case GlyphNode():
        _writeGlyph(node);
      case RuleNode():
        _writeRule(node);
      case KernNode():
        // A bare kern has no visual; it only advances x inside an HBox/Span,
        // which is handled by the horizontal layout. Nothing to emit.
        break;
      case HBox():
        _writeHorizontal(node.children);
      case SpanNode():
        _writeSpan(node);
      case VList():
        _writeVList(node);
      case SvgPathNode():
        _writeSvgPath(node);
    }
  }

  // --- Glyph ----------------------------------------------------------------

  void _writeGlyph(GlyphNode node) {
    final family = node.font.cssFamily;
    final size = fontSize * node.size;
    // A glyph renders at its box origin. `skew` and `italic` are metadata for
    // *builders* (accent placement, supsub italic correction) which bake any
    // resulting shift into the box tree — they must NOT offset the glyph here,
    // or slanted glyphs (e.g. math-italic `f`, skew 0.167em) get pushed into
    // following content (overlapping `f'` primes) and past the viewBox
    // (clipping).
    final style = _glyphStyle(node.font.variant);

    _buf
      ..write('<text x="0" y="0" ')
      ..write('font-family="$family" ')
      ..write('font-size="${_num(size)}"')
      ..write(style)
      ..write('>')
      ..write(_escapeText(node.text))
      ..write('</text>');
  }

  /// Inline `font-weight`/`font-style` hints matching the glyph's variant, so
  /// the renderer selects the right embedded `@font-face`.
  String _glyphStyle(KatexFontVariant variant) {
    switch (variant) {
      case KatexFontVariant.regular:
        return '';
      case KatexFontVariant.bold:
        return ' font-weight="bold"';
      case KatexFontVariant.italic:
        return ' font-style="italic"';
      case KatexFontVariant.boldItalic:
        return ' font-weight="bold" font-style="italic"';
    }
  }

  // --- Rule -----------------------------------------------------------------

  void _writeRule(RuleNode node) {
    final w = node.width * fontSize;
    final h = (node.height + node.depth) * fontSize;
    // The rule spans from `height` above the baseline to `depth` below it; its
    // top edge sits at y = -height.
    final y = -node.height * fontSize;
    _buf
      ..write('<rect x="0" y="${_num(y)}" ')
      ..write('width="${_num(w)}" height="${_num(h)}"/>');
  }

  // --- Horizontal layout (HBox + Span children) -----------------------------

  void _writeHorizontal(List<BoxNode> children) {
    var x = 0.0;
    for (final child in children) {
      if (child is KernNode) {
        x += child.width * fontSize;
        continue;
      }
      if (x == 0) {
        _writeNode(child);
      } else {
        _buf.write('<g transform="translate(${_num(x)},0)">');
        _writeNode(child);
        _buf.write('</g>');
      }
      x += child.width * fontSize;
    }
  }

  // --- Span -----------------------------------------------------------------

  void _writeSpan(SpanNode node) {
    final hasColor = node.color != null && node.color!.isNotEmpty;
    final classes = node.classes.isEmpty
        ? ''
        : ' class="${_escapeAttr(node.classes.join(' '))}"';
    if (hasColor || classes.isNotEmpty) {
      _buf.write('<g');
      if (hasColor) {
        _buf.write(' fill="${_escapeAttr(node.color!)}"');
      }
      _buf
        ..write(classes)
        ..write('>');
      _writeHorizontal(node.children);
      _buf.write('</g>');
    } else {
      _writeHorizontal(node.children);
    }
  }

  // --- VList ----------------------------------------------------------------

  void _writeVList(VList node) {
    for (final pos in node.positions) {
      // `shift` is the downward offset of the element's baseline from the
      // vlist baseline (positive = down) → directly a +y translate in SVG.
      final dy = pos.shift * fontSize;
      if (dy == 0) {
        _writeNode(pos.box);
      } else {
        _buf.write('<g transform="translate(0,${_num(dy)})">');
        _writeNode(pos.box);
        _buf.write('</g>');
      }
    }
  }

  // --- SvgPath (stretchy delimiters / sqrt surd) ----------------------------

  void _writeSvgPath(SvgPathNode node) {
    final path = node.pathData;
    if (path.isEmpty) {
      // No geometry resolved (unknown name): emit a harmless comment so the
      // output stays well-formed.
      _buf.write(
        '<!-- SvgPathNode "${_escapeText(node.pathName)}" (no path) -->',
      );
      return;
    }
    // The node's ink spans box-y [-height, +depth] (top to bottom) and box-x
    // [0, width]. We emit a nested <svg> whose viewBox is the path's units; the
    // SVG renderer maps it onto the box via preserveAspectRatio (matching how
    // KaTeX nests <svg> for stretchy geometry).
    final w = node.width * fontSize;
    final h = (node.height + node.depth) * fontSize;
    final y = -node.height * fontSize;
    final par = switch (node.preserveAspectRatio) {
      SvgPreserveAspectRatio.none => 'none',
      // KaTeX uses "xMinYMin slice" for the surd: uniform cover, top-left
      // anchored, overflow clipped to the box.
      SvgPreserveAspectRatio.xMinYMinSlice => 'xMinYMin slice',
    };
    _buf
      ..write('<svg x="0" y="${_num(y)}" ')
      ..write('width="${_num(w)}" height="${_num(h)}" ')
      ..write('viewBox="${_escapeAttr(node.viewBox)}" ')
      ..write('preserveAspectRatio="$par">')
      ..write('<path d="${_escapeAttr(path)}"/>')
      ..write('</svg>');
  }

  // --- Font @font-face defs -------------------------------------------------

  void _writeFontDefs() {
    _buf.write('<defs><style>');
    for (final entry in katexFontBase64.entries) {
      final key = entry.key; // e.g. "Main-BoldItalic"
      final base64 = entry.value;
      final dash = key.indexOf('-');
      if (dash < 0) {
        continue;
      }
      final family = key.substring(0, dash); // "Main"
      final variant = key.substring(dash + 1); // "BoldItalic"
      final cssFamily = 'KaTeX_$family';
      final weight = variant.contains('Bold') ? '700' : '400';
      final style = variant.contains('Italic') ? 'italic' : 'normal';

      _buf
        ..write('@font-face{')
        ..write("font-family:'$cssFamily';")
        ..write('font-weight:$weight;')
        ..write('font-style:$style;')
        ..write(
          'src:url(data:font/truetype;charset=utf-8;base64,$base64) '
          "format('truetype');",
        )
        ..write('}');
    }
    _buf.write('</style></defs>');
  }

  // --- Helpers --------------------------------------------------------------

  /// Formats a number compactly: integers without a trailing `.0`, otherwise a
  /// fixed (5 dp) representation with trailing zeros trimmed.
  String _num(double v) {
    if (v == 0) {
      return '0';
    }
    if (v == v.roundToDouble()) {
      return v.toStringAsFixed(0);
    }
    var s = v.toStringAsFixed(5);
    // Trim trailing zeros (and a dangling dot) for compactness.
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  String _escapeText(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  String _escapeAttr(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
