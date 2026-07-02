/// Builders for the functions ported in T-039:
/// `mathchoice`, `htmlmathml`, `html`, `href`, `vphantom`, `smash`, `lap`,
/// `horizBrace`, `xArrow`, `raisebox`, `vcenter`, `pmb`, `verb`.
///
/// Each ports the BOX-PRODUCING `htmlBuilder` of the corresponding KaTeX
/// `functions/*.ts` into the project's backend-agnostic [BoxNode] model. The
/// stretchy brace / arrow SVGs reuse the same [SvgPathNode] + `svgGeometry`
/// mechanism that accents already use (see `accent_builders.dart`).
library;

import 'package:katex_dart/src/ast/parse_node.dart' as ast;
import 'package:katex_dart/src/box/box_node.dart';
import 'package:katex_dart/src/build/build_common.dart';
import 'package:katex_dart/src/build/build_expression.dart';
import 'package:katex_dart/src/build/builders/units.dart';
import 'package:katex_dart/src/build/options.dart';
import 'package:katex_dart/src/build/style.dart';
import 'package:katex_dart/src/svg/svg_geometry.g.dart' as geom;

/// Registers the T-039 builders into [registry].
void registerExtraBuilders(Map<String, GroupBuilder> registry) {
  registry['mathchoice'] = (node, options) =>
      _buildMathChoice(node as ast.MathChoiceNode, options);
  registry['htmlmathml'] = (node, options) =>
      _buildHtmlMathml(node as ast.HtmlMathmlNode, options);
  registry['html'] = (node, options) =>
      _buildHtml(node as ast.HtmlNode, options);
  registry['href'] = (node, options) =>
      _buildHref(node as ast.HrefNode, options);
  registry['vphantom'] = (node, options) =>
      _buildVphantom(node as ast.VphantomNode, options);
  registry['smash'] = (node, options) =>
      _buildSmash(node as ast.SmashNode, options);
  registry['lap'] = (node, options) => _buildLap(node as ast.LapNode, options);
  registry['horizBrace'] = (node, options) =>
      _buildHorizBrace(node as ast.HorizBraceNode, options);
  registry['xArrow'] = (node, options) =>
      _buildXArrow(node as ast.XArrowNode, options);
  registry['raisebox'] = (node, options) =>
      _buildRaiseBox(node as ast.RaiseBoxNode, options);
  registry['vcenter'] = (node, options) =>
      _buildVcenter(node as ast.VcenterNode, options);
  registry['pmb'] = (node, options) => _buildPmb(node as ast.PmbNode, options);
  registry['verb'] = (node, options) =>
      _buildVerb(node as ast.VerbNode, options);
  registry['hbox'] = (node, options) =>
      _buildHbox(node as ast.HboxNode, options);
}

// ---- hbox -----------------------------------------------------------------

BoxNode _buildHbox(ast.HboxNode group, Options options) {
  final elements = buildExpression(
    group.body,
    options.withFont(''),
    isRealGroup: false,
  );
  return makeFragment(elements);
}

// ---- mathchoice -----------------------------------------------------------

List<ast.ParseNode> _chooseMathStyle(ast.MathChoiceNode group, Options opts) {
  switch (opts.style.size) {
    case 0: // Style.DISPLAY.size
      return group.display;
    case 1: // Style.TEXT.size
      return group.text;
    case 2: // Style.SCRIPT.size
      return group.script;
    case 3: // Style.SCRIPTSCRIPT.size
      return group.scriptscript;
    default:
      return group.text;
  }
}

BoxNode _buildMathChoice(ast.MathChoiceNode group, Options options) {
  final body = _chooseMathStyle(group, options);
  final elements = buildExpression(body, options, isRealGroup: false);
  return makeFragment(elements);
}

// ---- htmlmathml / html / href --------------------------------------------
// All three render only their HTML body in this backend (attributes/links are
// visual no-ops). `\html@mathml` discards the MathML arg by design.

BoxNode _buildHtmlMathml(ast.HtmlMathmlNode group, Options options) {
  final elements = buildExpression(group.html, options, isRealGroup: false);
  return makeFragment(elements);
}

BoxNode _buildHtml(ast.HtmlNode group, Options options) {
  final elements = buildExpression(group.body, options, isRealGroup: false);
  return makeFragment(elements);
}

BoxNode _buildHref(ast.HrefNode group, Options options) {
  final elements = buildExpression(group.body, options, isRealGroup: false);
  return makeFragment(elements);
}

// ---- vphantom -------------------------------------------------------------
// KaTeX renders the phantom body (invisible ink), then makes it zero-width via
// an rlap. We keep the body's height/depth and cancel its advance width with a
// trailing negative kern.

BoxNode _buildVphantom(ast.VphantomNode group, Options options) {
  final inner = buildGroup(group.body, options.withPhantom());
  return withAtomClass(
    makeFragment([inner, KernNode(-inner.width)]),
    'mord',
    options: options,
  );
}

// ---- smash ----------------------------------------------------------------
// Faithful spacing (TeX treats \smash like an ord). NOTE: the box-node model
// cannot under-report a child's height/depth without a new field/subclass
// (forbidden by T-039), so the height/depth zeroing of \smash is not applied
// here — the content is rendered with its natural extent. The horizontal
// layout is unaffected; this is a documented dimension-accuracy limitation.

BoxNode _buildSmash(ast.SmashNode group, Options options) {
  final inner = buildGroup(group.body, options);
  return withAtomClass(makeFragment([inner]), 'mord', options: options);
}

// ---- lap ------------------------------------------------------------------
// \mathllap / \mathrlap / \mathclap: render the body but report zero width by
// cancelling the advance with a kern. `rlap` extends right (leading content,
// trailing -width kern); `llap` extends left (leading -width kern); `clap`
// centers (half kerns on both sides).

BoxNode _buildLap(ast.LapNode group, Options options) {
  final inner = buildGroup(group.body, options);
  final w = inner.width;
  final List<BoxNode> children;
  switch (group.alignment) {
    case 'rlap':
      children = [inner, KernNode(-w)];
    case 'llap':
      children = [KernNode(-w), inner];
    case 'clap':
    default:
      children = [KernNode(-w / 2), inner, KernNode(-w / 2)];
  }
  return withAtomClass(makeFragment(children), 'mord', options: options);
}

// ---- horizBrace -----------------------------------------------------------
// Stretchy brace via SVG, reusing the accent/arrow stretchy mechanism.
// KaTeX braces use a 3-path SVG (left corner, stretchy middle, right corner).

const Map<
  String,
  ({List<String> paths, double minWidth, double viewBoxHeight})
>
_braceData = {
  'overbrace': (
    paths: ['leftbrace', 'midbrace', 'rightbrace'],
    minWidth: 1.6,
    viewBoxHeight: 548,
  ),
  'underbrace': (
    paths: ['leftbraceunder', 'midbraceunder', 'rightbraceunder'],
    minWidth: 1.6,
    viewBoxHeight: 548,
  ),
  'overbracket': (
    paths: ['leftbracketover', 'rightbracketover'],
    minWidth: 1.6,
    viewBoxHeight: 440,
  ),
  'underbracket': (
    paths: ['leftbracketunder', 'rightbracketunder'],
    minWidth: 1.6,
    viewBoxHeight: 410,
  ),
};

// Builds the stretchy brace/bracket SVG spanning [baseWidth]. The corner pieces
// keep their ends (slice-anchored); the optional middle piece stretches.
BoxNode _braceSvg(String label, double baseWidth) {
  final data = _braceData[label] ?? _braceData['overbrace']!;
  final height = data.viewBoxHeight / 1000;
  final paths = data.paths;

  SvgPathNode piece(String name, double width, SvgPreserveAspectRatio par) =>
      SvgPathNode(
        pathName: name,
        pathData: geom.svgPath[name] ?? '',
        viewBoxWidth: 400000,
        viewBoxHeight: data.viewBoxHeight,
        width: width,
        height: height,
        preserveAspectRatio: par,
      );

  if (paths.length == 3) {
    // Three-piece brace (KaTeX stretchy.svgSpan, 3-child case): left corner |
    // center tooth | right corner, at CSS widths 25.1% / 50% / 25.1% with
    // aligns xMinYMin / xMidYMin / xMaxYMin (all "slice"). The center keeps the
    // brace's central tooth visible; using "none" would flatten the curve.
    final cornerWidth = baseWidth * 0.251;
    final centerWidth = baseWidth * 0.5;
    return HBox([
      piece(paths[0], cornerWidth, SvgPreserveAspectRatio.xMinYMinSlice),
      piece(paths[1], centerWidth, SvgPreserveAspectRatio.xMidYMinSlice),
      piece(paths[2], cornerWidth, SvgPreserveAspectRatio.xMaxYMinSlice),
    ]);
  }

  // Two-piece bracket.
  final half = baseWidth / 2;
  return HBox([
    piece(paths[0], half, SvgPreserveAspectRatio.xMinYMinSlice),
    piece(paths[1], half, SvgPreserveAspectRatio.xMaxYMinSlice),
  ]);
}

BoxNode _buildHorizBrace(ast.HorizBraceNode group, Options options) =>
    _horizBrace(group, options, null);

/// Builds a `\overbrace{…}^{label}` / `\underbrace{…}_{label}`: the brace with
/// its note stacked (and centered) above/below. Port of horizBrace.ts's supsub
/// path — KaTeX treats the brace like an op with `\limits`, so the label is the
/// sup (over) or sub (under) rendered in script style and centered over the
/// brace (the equation, not the note, controls the brace width).
BoxNode buildHorizBraceSupSub(ast.SupSubNode grp, Options options) {
  final group = grp.base! as ast.HorizBraceNode;
  final label = group.isOver
      ? buildGroup(grp.sup, options.havingStyle(options.style.sup()), options)
      : buildGroup(grp.sub, options.havingStyle(options.style.sub()), options);
  return _horizBrace(group, options, label);
}

BoxNode _horizBrace(
  ast.HorizBraceNode group,
  Options options,
  BoxNode? label,
) {
  final body = buildGroup(group.base, options.havingBaseStyle(Style.DISPLAY));
  final braceBody = _braceSvg(group.label.substring(1), body.width);
  final braceClass = group.isOver ? 'mover' : 'munder';

  // First vlist: the braced content + the brace itself.
  final VList vlist;
  if (group.isOver) {
    vlist = makeVList(
      positionType: VListPositionType.firstBaseline,
      children: [
        VListChild.elem(body),
        const VListChild.kern(0.1),
        VListChild.elem(braceBody),
      ],
    );
  } else {
    vlist = makeVList(
      positionType: VListPositionType.bottom,
      positionData: body.depth + 0.1 + braceBody.height,
      children: [
        VListChild.elem(braceBody),
        const VListChild.kern(0.1),
        VListChild.elem(body),
      ],
    );
  }

  if (label == null) {
    return withAtomClass(
      makeSpan([vlist], classes: [braceClass]),
      'minner',
      options: options,
    );
  }

  // Stack the note above/below the brace in a second vlist. KaTeX centers the
  // children via CSS; our VLists are left-aligned, so we bake the centering as
  // a leading kern (like the accent builder), centering the narrower child
  // against the wider so the equation — not the note — controls the width.
  final vSpan = makeSpan([vlist], classes: ['minner', braceClass]);
  final totalWidth = vSpan.width > label.width ? vSpan.width : label.width;
  BoxNode centered(BoxNode b) => b.width >= totalWidth
      ? b
      : makeFragment([KernNode((totalWidth - b.width) / 2), b]);

  final VList outer;
  if (group.isOver) {
    outer = makeVList(
      positionType: VListPositionType.firstBaseline,
      children: [
        VListChild.elem(centered(vSpan)),
        const VListChild.kern(0.2),
        VListChild.elem(centered(label)),
      ],
    );
  } else {
    outer = makeVList(
      positionType: VListPositionType.bottom,
      positionData: vSpan.depth + 0.2 + label.height + label.depth,
      children: [
        VListChild.elem(centered(label)),
        const VListChild.kern(0.2),
        VListChild.elem(centered(vSpan)),
      ],
    );
  }

  return withAtomClass(
    makeSpan([outer], classes: [braceClass]),
    'minner',
    options: options,
  );
}

// ---- xArrow ---------------------------------------------------------------
// Stretchy extensible arrows with optional text above/below. Reuses the
// arrow SVG path data (the same `svgGeometry` paths the accents use).

const Map<
  String,
  ({List<String> paths, double minWidth, double viewBoxHeight})
>
_arrowData = {
  'xleftarrow': (paths: ['leftarrow'], minWidth: 1.469, viewBoxHeight: 522),
  'xrightarrow': (paths: ['rightarrow'], minWidth: 1.469, viewBoxHeight: 522),
  'xLeftarrow': (
    paths: ['doubleleftarrow'],
    minWidth: 1.526,
    viewBoxHeight: 560,
  ),
  'xRightarrow': (
    paths: ['doublerightarrow'],
    minWidth: 1.526,
    viewBoxHeight: 560,
  ),
  'xleftharpoonup': (
    paths: ['leftharpoon'],
    minWidth: 0.888,
    viewBoxHeight: 522,
  ),
  'xleftharpoondown': (
    paths: ['leftharpoondown'],
    minWidth: 0.888,
    viewBoxHeight: 522,
  ),
  'xrightharpoonup': (
    paths: ['rightharpoon'],
    minWidth: 0.888,
    viewBoxHeight: 522,
  ),
  'xrightharpoondown': (
    paths: ['rightharpoondown'],
    minWidth: 0.888,
    viewBoxHeight: 522,
  ),
  'xlongequal': (paths: ['longequal'], minWidth: 0.888, viewBoxHeight: 334),
  'xtwoheadleftarrow': (
    paths: ['twoheadleftarrow'],
    minWidth: 0.888,
    viewBoxHeight: 334,
  ),
  'xtwoheadrightarrow': (
    paths: ['twoheadrightarrow'],
    minWidth: 0.888,
    viewBoxHeight: 334,
  ),
  'xleftrightarrow': (
    paths: ['leftarrow', 'rightarrow'],
    minWidth: 1.75,
    viewBoxHeight: 522,
  ),
  'xLeftrightarrow': (
    paths: ['doubleleftarrow', 'doublerightarrow'],
    minWidth: 1.75,
    viewBoxHeight: 560,
  ),
  'xrightleftharpoons': (
    paths: ['leftharpoondownplus', 'rightharpoonplus'],
    minWidth: 1.75,
    viewBoxHeight: 716,
  ),
  'xleftrightharpoons': (
    paths: ['leftharpoonplus', 'rightharpoondownplus'],
    minWidth: 1.75,
    viewBoxHeight: 716,
  ),
  'xhookleftarrow': (
    paths: ['leftarrow', 'righthook'],
    minWidth: 1.08,
    viewBoxHeight: 522,
  ),
  'xhookrightarrow': (
    paths: ['lefthook', 'rightarrow'],
    minWidth: 1.08,
    viewBoxHeight: 522,
  ),
  'xmapsto': (
    paths: ['leftmapsto', 'rightarrow'],
    minWidth: 1.5,
    viewBoxHeight: 522,
  ),
  'xtofrom': (
    paths: ['leftToFrom', 'rightToFrom'],
    minWidth: 1.75,
    viewBoxHeight: 528,
  ),
  'xrightleftarrows': (
    paths: ['baraboveleftarrow', 'rightarrowabovebar'],
    minWidth: 1.75,
    viewBoxHeight: 901,
  ),
  'xrightequilibrium': (
    paths: ['baraboveshortleftharpoon', 'rightharpoonaboveshortbar'],
    minWidth: 1.75,
    viewBoxHeight: 716,
  ),
  'xleftequilibrium': (
    paths: ['shortbaraboveleftharpoon', 'shortrightharpoonabovebar'],
    minWidth: 1.75,
    viewBoxHeight: 716,
  ),
};

({BoxNode body, double height}) _arrowSvg(String label, double width) {
  final data = _arrowData[label] ?? _arrowData['xrightarrow']!;
  final height = data.viewBoxHeight / 1000;
  final paths = data.paths;

  SvgPathNode piece(String name, double w, SvgPreserveAspectRatio par) =>
      SvgPathNode(
        pathName: name,
        pathData: geom.svgPath[name] ?? '',
        viewBoxWidth: 400000,
        viewBoxHeight: data.viewBoxHeight,
        width: w,
        height: height,
        preserveAspectRatio: par,
      );

  if (paths.length == 1) {
    // Single arrow: keep the head (right arrows anchor right; left, left).
    final head = label.toLowerCase().contains('right')
        ? SvgPreserveAspectRatio.xMaxYMinSlice
        : SvgPreserveAspectRatio.xMinYMinSlice;
    return (body: piece(paths.first, width, head), height: height);
  }
  final half = width / 2;
  return (
    body: HBox([
      piece(paths[0], half, SvgPreserveAspectRatio.xMinYMinSlice),
      piece(paths[1], half, SvgPreserveAspectRatio.xMaxYMinSlice),
    ]),
    height: height,
  );
}

BoxNode _buildXArrow(ast.XArrowNode group, Options options) {
  final style = options.style;

  final upperGroup = buildGroup(group.body, options.havingStyle(style.sup()));

  BoxNode? lowerGroup;
  if (group.below != null) {
    lowerGroup = buildGroup(group.below, options.havingStyle(style.sub()));
  }

  // The arrow width follows the wider of the two labels, with a per-arrow
  // minimum. Use the upper/lower label widths plus padding (KaTeX uses the
  // x-arrow-pad CSS; ~0.5em on each side approximates it).
  final data =
      _arrowData[group.label.substring(1)] ?? _arrowData['xrightarrow']!;
  final labelWidth = lowerGroup == null
      ? upperGroup.width
      : (upperGroup.width > lowerGroup.width
            ? upperGroup.width
            : lowerGroup.width);
  final arrowWidth = (labelWidth + 0.667 > data.minWidth)
      ? labelWidth + 0.667
      : data.minWidth;

  final svg = _arrowSvg(group.label.substring(1), arrowWidth);
  final arrowBody = svg.body;

  final axisHeight = options.fontMetrics().axisHeight;
  final arrowShift = -axisHeight + 0.5 * svg.height;
  var upperShift = -axisHeight - 0.5 * svg.height - 0.111; // 0.111em = 2mu
  if (upperGroup.depth > 0.25 || group.label == r'\xleftequilibrium') {
    upperShift -= upperGroup.depth;
  }

  final VList vlist;
  if (lowerGroup != null) {
    final lowerShift =
        -axisHeight + lowerGroup.height + 0.5 * svg.height + 0.111;
    vlist = makeVList(
      positionType: VListPositionType.individualShift,
      children: [
        VListChild.elem(upperGroup, shift: upperShift),
        VListChild.elem(arrowBody, shift: arrowShift),
        VListChild.elem(lowerGroup, shift: lowerShift),
      ],
    );
  } else {
    vlist = makeVList(
      positionType: VListPositionType.individualShift,
      children: [
        VListChild.elem(upperGroup, shift: upperShift),
        VListChild.elem(arrowBody, shift: arrowShift),
      ],
    );
  }

  return withAtomClass(
    makeSpan([vlist], classes: const ['x-arrow']),
    'mrel',
    options: options,
  );
}

// ---- raisebox -------------------------------------------------------------

BoxNode _buildRaiseBox(ast.RaiseBoxNode group, Options options) {
  final body = buildGroup(group.body, options);
  final dy = calculateSize(group.dy, options);
  return makeVList(
    positionType: VListPositionType.shift,
    positionData: -dy,
    children: [VListChild.elem(body)],
  );
}

// ---- vcenter --------------------------------------------------------------

BoxNode _buildVcenter(ast.VcenterNode group, Options options) {
  final body = buildGroup(group.body, options);
  final axisHeight = options.fontMetrics().axisHeight;
  final dy = 0.5 * ((body.height - axisHeight) - (body.depth + axisHeight));
  return makeVList(
    positionType: VListPositionType.shift,
    positionData: dy,
    children: [VListChild.elem(body)],
  );
}

// ---- pmb ------------------------------------------------------------------
// Poor-man's bold. KaTeX simulates bold with a CSS text-shadow; the box model
// has no shadow, so we render the body with its derived math class (the visual
// bolding is a documented backend limitation, but spacing/extent are correct).

BoxNode _buildPmb(ast.PmbNode group, Options options) {
  final elements = buildExpression(group.body, options, isRealGroup: true);
  return withAtomClass(
    makeFragment(elements),
    mclassName(group.mclass),
    options: options,
  );
}

// ---- verb -----------------------------------------------------------------

BoxNode _buildVerb(ast.VerbNode group, Options options) {
  final text = group.body.replaceAll(' ', group.star ? '␣' : ' ');
  final newOptions = options.havingStyle(options.style.text());
  final body = <BoxNode>[];
  for (var i = 0; i < text.length; i++) {
    var c = text[i];
    if (c == '~') {
      c = ' ';
    }
    final glyph = makeSymbol(
      c,
      'Typewriter-Regular',
      group.mode,
      options: newOptions,
    );
    if (glyph != null) {
      body.add(glyph);
    }
  }
  return withAtomClass(
    makeSpan(body, classes: const ['text'], options: newOptions),
    'mord',
    options: newOptions,
  );
}
