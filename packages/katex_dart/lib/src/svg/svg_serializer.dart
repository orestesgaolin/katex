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

import 'package:katex_dart/src/box/box_node.dart';
import 'package:katex_dart/src/font/embedded_fonts.g.dart';
import 'package:katex_dart/src/font/font_types.dart';
import 'package:katex_dart/src/svg/glyph_paths.g.dart';

/// The default em → user-unit scale (SVG user units per em).
///
/// KaTeX lays everything out in em and renders at the surrounding CSS
/// font-size; there is no single "correct" pixel size. We pick **44**, a clean
/// value that yields legible standalone output (a 1-em-tall glyph is ~44 units)
/// and matches the size the reference oracle screenshots at. Callers can
/// override per-call via [serializeBox]'s `fontSize`.
const double defaultFontSize = 44;

/// Padding added around the content box, in **em**, so the SVG viewBox does not
/// clip glyph ink that overshoots the metric box.
///
/// The box-tree dimensions (the `height`/`depth`/`width` of [BoxNode]) are the
/// *metric* box (the values KaTeX lays out with). Real glyph ink extends past
/// it: ascenders/diacritics rise above the reported height, descenders drop
/// below the depth, and a slanted last glyph (math-italic) or a glyph with
/// negative left bearing pokes out the sides. With the viewBox set to exactly
/// the metric box, that overshoot is clipped (RC-E: `\mathcal{ABCL}`, `\mathsf`,
/// `\scriptstyle`, `\cfrac`). We add a small symmetric margin so the drawn
/// content is fully enclosed. The pad is symmetric (added equally on all four
/// sides), so the content's top-left only shifts by [_contentPadEm] — small
/// enough not to disturb the lenient top-left-composited SVG golden test.
const double _contentPadEm = 0.08;

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
    // A symmetric margin so glyph ink that overshoots the metric box
    // (ascenders, descenders, italic / negative-bearing overhang on edge
    // glyphs) is not clipped by the viewBox. See [_contentPadEm].
    final pad = _contentPadEm * fontSize;
    // Total drawing height spans from the top of the box (height above the
    // baseline) to the bottom (depth below), plus the pad on each side. Guard
    // against degenerate zero.
    final totalHeightU = heightU + depthU;
    final contentW = widthU <= 0 ? 0.0 : widthU;
    final contentH = totalHeightU <= 0 ? 0.0 : totalHeightU;
    final svgWidth = contentW + 2 * pad;
    final svgHeight = contentH + 2 * pad;

    _buf
      ..write('<svg xmlns="http://www.w3.org/2000/svg" ')
      ..write('xmlns:xlink="http://www.w3.org/1999/xlink" ')
      ..write('width="${_num(svgWidth)}" height="${_num(svgHeight)}" ')
      ..write('viewBox="0 0 ${_num(svgWidth)} ${_num(svgHeight)}">');

    _writeFontDefs();

    // Move the origin down to the root baseline (and right/down by the pad) so
    // children can be placed in baseline-relative em coordinates (y grows
    // downward) with the margin all around.
    _buf.write(
      '<g transform="translate(${_num(pad)},${_num(heightU + pad)})">',
    );
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
      case EncloseNode():
        _writeEnclose(node);
      case ImageNode():
        _writeImage(node);
    }
  }

  // --- Image (\includegraphics) ---------------------------------------------

  void _writeImage(ImageNode node) {
    // The image's box spans box-y [-height, +depth] (top to bottom) and box-x
    // [0, width]; y grows downward in SVG. A natural-width image (width == 0,
    // KaTeX's "no width given") gets no explicit width attribute so the browser
    // uses the bitmap's intrinsic aspect ratio at the requested height.
    final h = (node.height + node.depth) * fontSize;
    final y = -node.height * fontSize;
    _buf
      ..write('<image x="0" y="${_num(y)}" ')
      ..write('height="${_num(h)}" ');
    if (node.width > 0) {
      _buf.write('width="${_num(node.width * fontSize)}" ');
    }
    final href = _escapeAttr(node.src);
    _buf
      ..write('preserveAspectRatio="none" ')
      ..write('xlink:href="$href" ')
      ..write('href="$href"')
      ..write(node.alt.isEmpty ? '' : ' aria-label="${_escapeAttr(node.alt)}"')
      ..write('/>');
  }

  // --- Enclose (frame / fill / strikes) -------------------------------------

  void _writeEnclose(EncloseNode node) {
    // The decorations span the child's box: box-x [0, width], box-y
    // [-height, +depth] (top to bottom). y grows downward in SVG.
    final w = node.width * fontSize;
    final top = -node.height * fontSize;
    final h = (node.height + node.depth) * fontSize;
    final hasBox = node.notations.contains(EncloseNotation.box);
    final hasActuarial = node.notations.contains(EncloseNotation.actuarial);

    // Background fill (drawn behind the child). KaTeX paints the fill, then the
    // border, then the content on top.
    if (node.backgroundColor != null && node.backgroundColor!.isNotEmpty) {
      _buf
        ..write('<rect x="0" y="${_num(top)}" ')
        ..write('width="${_num(w)}" height="${_num(h)}" ')
        ..write('fill="${_escapeAttr(node.backgroundColor!)}"/>');
    }

    // Full frame (box). Drawn as a stroked rect inset by half the border width
    // so the stroke sits inside the box (CSS border-box semantics).
    if (hasBox && node.borderWidth != null) {
      final bw = node.borderWidth! * fontSize;
      _buf
        ..write('<rect ')
        ..write('x="${_num(bw / 2)}" y="${_num(top + bw / 2)}" ')
        ..write('width="${_num(w - bw)}" height="${_num(h - bw)}" ')
        ..write('fill="none" ')
        ..write('stroke="${_strokeOr(node.borderColor)}" ')
        ..write('stroke-width="${_num(bw)}"/>');
    }

    // Actuarial angle: a top border + a right border.
    if (hasActuarial && node.borderWidth != null) {
      final bw = node.borderWidth! * fontSize;
      final stroke = _strokeOr(node.borderColor);
      // Top edge.
      _line(0, top + bw / 2, w, top + bw / 2, bw, stroke);
      // Right edge.
      _line(w - bw / 2, top, w - bw / 2, top + h, bw, stroke);
    }

    // Strikes.
    final strike = _strokeOr(node.strikeColor);
    const strokeW = 0.046; // em (KaTeX cancel stroke-width).
    final sw = strokeW * fontSize;
    if (node.notations.contains(EncloseNotation.updiagonalstrike)) {
      // bottom-left → top-right.
      _line(0, top + h, w, top, sw, strike);
    }
    if (node.notations.contains(EncloseNotation.downdiagonalstrike)) {
      // top-left → bottom-right.
      _line(0, top, w, top + h, sw, strike);
    }
    if (node.notations.contains(EncloseNotation.horizontalstrike)) {
      // \sout: a line across the x-height (~0.5 xHeight above the baseline).
      final y = -0.25 * fontSize;
      _line(0, y, w, y, 0.08 * fontSize, strike);
    }

    // \phase: the Steinmetz angle — a diagonal stroke from the top down to the
    // bottom-left corner joined to a horizontal stroke along the bottom. KaTeX
    // draws this as the filled `phasePath` SVG; geometrically it is this angle.
    if (node.notations.contains(EncloseNotation.phase) &&
        node.phaseLineWidth != null) {
      final lw = node.phaseLineWidth! * fontSize;
      // Apex near the top-left; diagonal down to the bottom-left corner.
      _line(h / 2, top + lw / 2, lw / 2, top + h - lw / 2, lw, strike);
      // Horizontal stroke along the bottom.
      _line(0, top + h - lw / 2, w, top + h - lw / 2, lw, strike);
    }

    // The content on top.
    _writeNode(node.child);
  }

  void _line(
    double x1,
    double y1,
    double x2,
    double y2,
    double strokeWidth,
    String stroke,
  ) {
    _buf
      ..write('<line x1="${_num(x1)}" y1="${_num(y1)}" ')
      ..write('x2="${_num(x2)}" y2="${_num(y2)}" ')
      ..write('stroke="$stroke" stroke-width="${_num(strokeWidth)}"/>');
  }

  // --- Glyph ----------------------------------------------------------------

  void _writeGlyph(GlyphNode node) {
    final size = fontSize * node.size;

    // Prefer a real glyph OUTLINE (<path>) over <text>: Chrome's SVG <text>
    // renderer mangles some complex KaTeX glyphs (e.g. the Size2 integral
    // renders as a degenerate triangle) even though the same font is fine in
    // HTML/Flutter. Path outlines are font-engine-independent and exact.
    //
    // Outlines are in font units (y-up); scale by size/unitsPerEm and flip Y
    // so the glyph baseline lands on y=0 at the box origin (like <text y="0">).
    final glyphPath = katexGlyphPaths[node.font.fontName]?[node.codepoint];
    if (glyphPath != null) {
      final s = size / katexGlyphUnitsPerEm;
      _buf
        ..write('<path transform="matrix(${_num(s)},0,0,${_num(-s)},0,0)" ')
        ..write('d="${_escapeAttr(glyphPath)}"/>');
      return;
    }

    // Fallback: <text> with the embedded font (rare — glyph not in the
    // extracted outline set). `skew`/`italic` are builder metadata, not applied
    // here (they are baked into the box tree).
    final family = node.font.cssFamily;
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
    if (node.isDashed) {
      // A dashed line down the rule's long axis (KaTeX renders `:`/`\hdashline`
      // as a CSS `dashed` border). Stroke width = the thin dimension; the dash
      // cadence is ~3× the stroke, matching the browser default look.
      final isVertical = h >= w;
      final sw = isVertical ? w : h;
      final dash = _num(sw * 3);
      final String x1;
      final String y1;
      final String x2;
      final String y2;
      if (isVertical) {
        x1 = x2 = _num(w / 2);
        y1 = _num(y);
        y2 = _num(y + h);
      } else {
        y1 = y2 = _num(y + h / 2);
        x1 = '0';
        x2 = _num(w);
      }
      _buf
        ..write('<line x1="$x1" y1="$y1" x2="$x2" y2="$y2" ')
        ..write('stroke="currentColor" stroke-width="${_num(sw)}" ')
        ..write('stroke-dasharray="$dash,$dash"/>');
      return;
    }
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
      // KaTeX uses "xMinYMin slice" for the surd and left-pointing arrows:
      // uniform cover, top-left anchored, overflow clipped to the box.
      SvgPreserveAspectRatio.xMinYMinSlice => 'xMinYMin slice',
      // "xMaxYMin slice" for right-pointing arrows: uniform cover, top-RIGHT
      // anchored so the arrowhead at x≈400000 stays visible at the box's right
      // edge; the long shaft tail runs off the left and is clipped.
      SvgPreserveAspectRatio.xMaxYMinSlice => 'xMaxYMin slice',
      // "xMidYMin slice" for the center piece of a stretchy brace: uniform
      // cover, top-center anchored so the brace's central tooth stays centered.
      SvgPreserveAspectRatio.xMidYMinSlice => 'xMidYMin slice',
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

  String _escapeAttr(String s) => _escapeText(s).replaceAll('"', '&quot;');

  /// The escaped stroke color for [color], or `currentColor` when it is null
  /// or empty (matching CSS's inherited-color default for enclose strokes).
  String _strokeOr(String? color) => (color != null && color.isNotEmpty)
      ? _escapeAttr(color)
      : 'currentColor';
}
