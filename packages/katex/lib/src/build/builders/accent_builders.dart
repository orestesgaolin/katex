/// Builders for `accent` (`\hat`/`\bar`/`\vec`/`\tilde`/…) and `accentUnder`,
/// ported from KaTeX `functions/accent.ts` (htmlBuilder, TeXbook rule 12).
///
/// T-025: faithful port of KaTeX's accent placement.
///
///  * NON-STRETCHY accents (`\hat`, `\bar`, `\tilde`, `\acute`, `\grave`,
///    `\dot`, `\ddot`, `\check`, `\breve`, `\mathring`) render the accent
///    symbol glyph from the Main font — the `replace` char registered in
///    `symbols.g.dart` (e.g. `\hat`→U+005E `^`, `\bar`→U+02C9, `\tilde`→`~`) —
///    via [makeOrd]. The glyph's italic correction is zeroed.
///  * `\vec` is special: like KaTeX (post 0.9) it uses the static "vec" SVG
///    path (KaTeX `staticSvg`) rather than the combining-arrow glyph U+20D7,
///    which has no reliable standalone rendering.
///  * STRETCHY accents (`\widehat`, `\widetilde`, `\widecheck`,
///    `\overrightarrow`, `\overleftarrow`, `\overleftrightarrow`,
///    `\overrightharpoon`, …) render an [SvgPathNode] from `svgGeometry`
///    sized to the base width (KaTeX `stretchy.stretchySvg`).
///
/// Horizontal centering: KaTeX centers the accent over the base via the CSS
/// `.accent > .vlist-t { text-align: center; }` rule combined with a zero-width
/// `accent-body` shifted by `left = skew - width/2`. The box tree's [VList] is
/// LEFT-aligned (no text-align), so we bake the centering into the accent's
/// leading kern: `left = (base.width - accentWidth) / 2 + skew`. This is the
/// fix for the previous "mark drifts to the upper-left" bug.
library;

import 'dart:math' as math;

import 'package:katex/src/ast/parse_node.dart' hide KernNode, RuleNode;
import 'package:katex/src/box/box_node.dart';
import 'package:katex/src/build/build_common.dart';
import 'package:katex/src/build/build_expression.dart';
import 'package:katex/src/build/builders/supsub_builder.dart'
    show isCharacterBox;
import 'package:katex/src/build/options.dart';
import 'package:katex/src/svg/svg_geometry.g.dart' as geom;

/// Registers the accent / accentUnder builders into [registry].
void registerAccentBuilders(Map<String, GroupBuilder> registry) {
  registry['accent'] = (node, options) =>
      _buildAccent(node as AccentNode, options);
  registry['accentUnder'] = (node, options) =>
      _buildAccentUnder(node as AccentUnderNode, options);
}

GlyphNode? _baseSymbol(BoxNode node) {
  if (node is GlyphNode) {
    return node;
  }
  if (node is SpanNode && node.children.length == 1) {
    return _baseSymbol(node.children.first);
  }
  if (node is HBox && node.children.length == 1) {
    return _baseSymbol(node.children.first);
  }
  return null;
}

// KaTeX `buildCommon.svgData`: static SVG accents (path name, width, height).
// Only `vec` is needed for accents; the rest (oiint/oiiint) live elsewhere.
const Map<String, ({String path, double width, double height})> _svgData = {
  'vec': (path: 'vec', width: 0.471, height: 0.714),
};

/// Port of KaTeX `buildCommon.staticSvg`: a fixed-size inline SVG (used by
/// `\vec`). Returns an [SvgPathNode] whose box is exactly the glyph's natural
/// width/height (so a uniform `none` stretch is distortion-free).
SvgPathNode _staticSvg(String value) {
  final data = _svgData[value]!;
  return SvgPathNode(
    pathName: data.path,
    pathData: geom.svgPath[data.path] ?? '',
    viewBoxWidth: 1000 * data.width,
    viewBoxHeight: 1000 * data.height,
    width: data.width,
    height: data.height,
  );
}

// ---------------------------------------------------------------------------
// Stretchy accents — port of KaTeX `stretchy.stretchySvg` (the accent subset).
// ---------------------------------------------------------------------------

// `katexImagesData` subset for the over-accent / stretchy labels that the
// accent function registers: [paths, minWidth, viewBoxHeight, align?].
//
// `aligns` is the `preserveAspectRatio` x-anchor for each path, matching
// KaTeX's `stretchy.ts`. The KaTeX SVGs are 400em wide with the actual ink
// (arrowhead / brace corner) parked at one end; the anchor decides which end
// stays visible when the slice is clipped to the base width:
//   * 'xMaxYMin' — head at the RIGHT end (x≈400000), e.g. `rightarrow`.
//   * 'xMinYMin' — head at the LEFT end (x≈0), e.g. `leftarrow`.
// For single-path arrows KaTeX uses one `hide-tail` span; for paired arrows
// (e.g. \overleftrightarrow) it lays two half-width spans side by side, the
// left one `xMinYMin` (keeps the left head) and the right one `xMaxYMin`
// (keeps the right head).
const Map<
  String,
  ({
    List<String> paths,
    double minWidth,
    double viewBoxHeight,
    List<String> aligns,
  })
>
_katexImagesData = {
  'overrightarrow': (
    paths: ['rightarrow'],
    minWidth: 0.888,
    viewBoxHeight: 522,
    aligns: ['xMaxYMin'],
  ),
  'overleftarrow': (
    paths: ['leftarrow'],
    minWidth: 0.888,
    viewBoxHeight: 522,
    aligns: ['xMinYMin'],
  ),
  'Overrightarrow': (
    paths: ['doublerightarrow'],
    minWidth: 0.888,
    viewBoxHeight: 560,
    aligns: ['xMaxYMin'],
  ),
  'overleftharpoon': (
    paths: ['leftharpoon'],
    minWidth: 0.888,
    viewBoxHeight: 522,
    aligns: ['xMinYMin'],
  ),
  'overrightharpoon': (
    paths: ['rightharpoon'],
    minWidth: 0.888,
    viewBoxHeight: 522,
    aligns: ['xMaxYMin'],
  ),
  'overleftrightarrow': (
    paths: ['leftarrow', 'rightarrow'],
    minWidth: 0.888,
    viewBoxHeight: 522,
    aligns: ['xMinYMin', 'xMaxYMin'],
  ),
  'overgroup': (
    paths: ['leftgroup', 'rightgroup'],
    minWidth: 0.888,
    viewBoxHeight: 342,
    aligns: ['xMinYMin', 'xMaxYMin'],
  ),
  'overlinesegment': (
    paths: ['leftlinesegment', 'rightlinesegment'],
    minWidth: 0.888,
    viewBoxHeight: 522,
    aligns: ['xMinYMin', 'xMaxYMin'],
  ),
  // Under-accents (accentunder.ts) reuse the same paths as their over-twins;
  // KaTeX's katexImagesData lists them separately. The CSS flips them
  // vertically for the under variants, but the path geometry is identical.
  'underrightarrow': (
    paths: ['rightarrow'],
    minWidth: 0.888,
    viewBoxHeight: 522,
    aligns: ['xMaxYMin'],
  ),
  'underleftarrow': (
    paths: ['leftarrow'],
    minWidth: 0.888,
    viewBoxHeight: 522,
    aligns: ['xMinYMin'],
  ),
  'underleftrightarrow': (
    paths: ['leftarrow', 'rightarrow'],
    minWidth: 0.888,
    viewBoxHeight: 522,
    aligns: ['xMinYMin', 'xMaxYMin'],
  ),
  'undergroup': (
    paths: ['leftgroupunder', 'rightgroupunder'],
    minWidth: 0.888,
    viewBoxHeight: 342,
    aligns: ['xMinYMin', 'xMaxYMin'],
  ),
  'underlinesegment': (
    paths: ['leftlinesegment', 'rightlinesegment'],
    minWidth: 0.888,
    viewBoxHeight: 522,
    aligns: ['xMinYMin', 'xMaxYMin'],
  ),
};

/// Maps a KaTeX `preserveAspectRatio` x-anchor name to our slice enum. The
/// stretchy arrow SVGs always anchor the top (`YMin`); only the x-anchor
/// varies (left head vs. right head).
SvgPreserveAspectRatio _sliceForAlign(String align) =>
    align.startsWith('xMax')
    ? SvgPreserveAspectRatio.xMaxYMinSlice
    : SvgPreserveAspectRatio.xMinYMinSlice;

const Set<String> _wideAccentLabels = {
  'widehat',
  'widecheck',
  'widetilde',
  'utilde',
};

/// Number of "characters" in the base, used to pick the wide-accent image.
int _baseNumChars(ParseNode base) {
  if (base is OrdGroupNode) {
    return base.body.length;
  }
  return 1;
}

/// Port of KaTeX `stretchy.stretchySvg` for the accent path. Returns a
/// [BoxNode] whose logical width is [baseWidth] and whose height matches
/// KaTeX's chosen image height. Single-path arrows return one [SvgPathNode];
/// paired arrows (`\overleftrightarrow`, `\overgroup`, `\overlinesegment`)
/// return an [HBox] of two half-width sliced nodes so BOTH heads/corners show.
BoxNode _stretchySvg(String fullLabel, ParseNode base, double baseWidth) {
  final label = fullLabel.substring(1); // strip leading backslash

  if (_wideAccentLabels.contains(label)) {
    // Wide accents: choose a taller image when there are more characters.
    final numChars = _baseNumChars(base);
    final double viewBoxWidth;
    final double viewBoxHeight;
    final double height;
    final String pathName;

    if (numChars > 5) {
      if (label == 'widehat' || label == 'widecheck') {
        viewBoxHeight = 420;
        viewBoxWidth = 2364;
        height = 0.42;
        pathName = '${label}4';
      } else {
        viewBoxHeight = 312;
        viewBoxWidth = 2340;
        height = 0.34;
        pathName = 'tilde4';
      }
    } else {
      const imgIndexByChars = [1, 1, 2, 2, 3, 3];
      final imgIndex = imgIndexByChars[numChars];
      if (label == 'widehat' || label == 'widecheck') {
        viewBoxWidth = const <double>[0, 1062, 2364, 2364, 2364][imgIndex];
        viewBoxHeight = const <double>[0, 239, 300, 360, 420][imgIndex];
        height = const <double>[0, 0.24, 0.3, 0.3, 0.36, 0.42][imgIndex];
        pathName = '$label$imgIndex';
      } else {
        viewBoxWidth = const <double>[0, 600, 1033, 2339, 2340][imgIndex];
        viewBoxHeight = const <double>[0, 260, 286, 306, 312][imgIndex];
        height = const <double>[0, 0.26, 0.286, 0.3, 0.306, 0.34][imgIndex];
        pathName = 'tilde$imgIndex';
      }
    }
    return SvgPathNode(
      pathName: pathName,
      pathData: geom.svgPath[pathName] ?? '',
      viewBoxWidth: viewBoxWidth,
      viewBoxHeight: viewBoxHeight,
      width: baseWidth,
      height: height,
      // KaTeX renders the wide-accent SVG at width:100% with
      // preserveAspectRatio:"none" — a non-uniform stretch to the base width
      // (SvgPreserveAspectRatio.none is the SvgPathNode default).
    );
  }

  // Arrow / harpoon / group over-accents: a single (or paired) long SVG that
  // KaTeX renders 400em wide with `slice` so the arrowheads stay undistorted
  // and the shaft is clipped to the base width.
  final data = _katexImagesData[label];
  if (data == null) {
    // Unknown stretchy accent: emit an empty-path node so output stays
    // well-formed (the serializer/painter no-op on empty path data).
    return SvgPathNode(
      pathName: label,
      pathData: '',
      viewBoxWidth: 400000,
      viewBoxHeight: 522,
      width: baseWidth,
      height: 0.522,
    );
  }
  final height = data.viewBoxHeight / 1000;

  if (data.paths.length == 1) {
    // Single arrow / harpoon: one 400em-wide path, sliced so the (undistorted)
    // arrowhead stays visible. `xMaxYMin` for right-pointing heads (head at
    // x≈400000), `xMinYMin` for left-pointing heads (head at x≈0).
    final pathName = data.paths.first;
    return SvgPathNode(
      pathName: pathName,
      pathData: geom.svgPath[pathName] ?? '',
      viewBoxWidth: 400000,
      viewBoxHeight: data.viewBoxHeight,
      width: baseWidth,
      height: height,
      preserveAspectRatio: _sliceForAlign(data.aligns.first),
    );
  }

  // Paired arrows / groups (e.g. \overleftrightarrow): KaTeX lays two
  // half-width spans side by side. The left half is anchored `xMinYMin` (keeps
  // the left head, parked at x≈0) and the right half `xMaxYMin` (keeps the
  // right head, parked at x≈400000). Each half is its own 400em-wide sliced
  // SVG clipped to its half of the base width, so both heads/corners render.
  final halfWidth = baseWidth / 2;
  final left = SvgPathNode(
    pathName: data.paths[0],
    pathData: geom.svgPath[data.paths[0]] ?? '',
    viewBoxWidth: 400000,
    viewBoxHeight: data.viewBoxHeight,
    width: halfWidth,
    height: height,
    preserveAspectRatio: _sliceForAlign(data.aligns[0]),
  );
  final right = SvgPathNode(
    pathName: data.paths[1],
    pathData: geom.svgPath[data.paths[1]] ?? '',
    viewBoxWidth: 400000,
    viewBoxHeight: data.viewBoxHeight,
    width: halfWidth,
    height: height,
    preserveAspectRatio: _sliceForAlign(data.aligns[1]),
  );
  // HBox width = sum of the two halves (= baseWidth), height = max child
  // height (= the shared arrow height), depth = 0.
  return HBox([left, right]);
}

BoxNode _buildAccent(AccentNode group, Options options) {
  final base = group.base;
  final body = buildGroup(base, options.havingCrampedStyle());

  final isStretchy = group.isStretchy ?? false;
  final mustShift = (group.isShifty ?? false) && isCharacterBox(base);
  var skew = 0.0;
  if (mustShift) {
    skew = _baseSymbol(body)?.scaledSkew ?? 0.0;
  }

  // Clearance between body and accent (rule 12): min of body height & xHeight.
  final clearance = math.min(body.height, options.fontMetrics().xHeight);

  if (!isStretchy) {
    final BoxNode accent;
    final double accentWidth;

    if (group.label == r'\vec') {
      // KaTeX uses the static "vec" SVG (not the combining glyph U+20D7).
      final svg = _staticSvg('vec');
      accent = svg;
      accentWidth = svg.width;
    } else {
      // The accent symbol glyph from the Main font (symbol-table `replace`).
      final glyph = makeOrd(group.label, group.mode, options, isTextord: true);
      if (glyph is GlyphNode) {
        // Remove italic correction (KaTeX zeroes it — it only shifts the
        // accent to a place we don't want).
        accent = GlyphNode(
          codepoint: glyph.codepoint,
          font: glyph.font,
          metrics: glyph.metrics,
          size: glyph.size,
          italic: 0,
          skew: glyph.skew,
        );
        accentWidth = glyph.width;
      } else {
        accent = glyph ?? makeSpan(const []);
        accentWidth = accent.width;
      }
    }

    // Center the accent over the base, then shift by the base's italic skew.
    // KaTeX achieves the centering via CSS `text-align: center` on the vlist;
    // the box tree's VList is left-aligned, so we bake the centering offset
    // into the leading kern: (base.width - accentWidth) / 2 + skew.
    final left = (body.width - accentWidth) / 2 + skew;
    final accentBody = makeFragment([KernNode(left), accent]);

    final vlist = makeVList(
      positionType: VListPositionType.firstBaseline,
      children: [
        VListChild.elem(body),
        VListChild.kern(-clearance),
        VListChild.elem(accentBody),
      ],
    );

    return withAtomClass(
      makeSpan([vlist], classes: const ['accent']),
      'mord',
      options: options,
    );
  }

  // Stretchy accent: the SVG spans the full base width and sits directly above
  // the base. Unlike the non-stretchy path, KaTeX's stretchy `makeVList` has NO
  // clearance kern — the children are just `[body, accentSvg]` (accent.ts). The
  // accent SVG has height = its image height and depth = 0, so in a
  // `firstBaseline` vlist its baseline lands exactly at `body.height` above the
  // main baseline, placing the whole accent above the base. Adding a
  // `-clearance` kern (as the non-stretchy path does) would instead pull the
  // accent down onto the base, drawing it over/through the letters.
  final accentBody = _stretchySvg(group.label, group.base, body.width);

  final vlist = makeVList(
    positionType: VListPositionType.firstBaseline,
    children: [
      VListChild.elem(body),
      VListChild.elem(accentBody),
    ],
  );

  return withAtomClass(
    makeSpan([vlist], classes: const ['accent']),
    'mord',
    options: options,
  );
}

/// Builds an `accent` that is the base of a `supsub` (character-box base).
/// Port of accent.htmlBuilder's supsub path: render the supsub on the inner
/// base, then replace its base with the accented base.
BoxNode buildAccentSupSub(SupSubNode grp, Options options) {
  final accentGroup = grp.base! as AccentNode;
  // Build the accent over the character base.
  final accented = _buildAccent(accentGroup, options);
  // Re-run supsub with the accent's inner base as the supsub base, then
  // overlay. For the MVP we attach scripts to the whole accented box, which
  // keeps dimensions correct (the script-position-independent-of-accent
  // nicety is a refinement for T-019).
  final innerSupSub = SupSubNode(
    mode: grp.mode,
    base: accentGroup.base,
    sup: grp.sup,
    sub: grp.sub,
  );
  // Build using the generic supsub path on the bare base, then wrap.
  final built = buildGroup(innerSupSub, options);
  // Use the accented box's height to keep vertical extent.
  return withAtomClass(
    makeFragment([accented, built]),
    'mord',
    options: options,
  );
}

BoxNode _buildAccentUnder(AccentUnderNode group, Options options) {
  // Port of accentunder.ts htmlBuilder: under-accents use the same stretchy
  // SVG as over-accents (NOT a font glyph), placed BELOW the base via a
  // `top` vlist. \utilde gets a small 0.12em kern between base and tilde.
  final body = buildGroup(group.base, options);
  final accentBody = _stretchySvg(group.label, group.base, body.width);
  final kern = group.label == r'\utilde' ? 0.12 : 0.0;

  final vlist = makeVList(
    positionType: VListPositionType.top,
    positionData: body.height,
    children: [
      VListChild.elem(accentBody),
      VListChild.kern(kern),
      VListChild.elem(body),
    ],
  );
  return withAtomClass(
    makeSpan([vlist], classes: const ['accentunder']),
    'mord',
    options: options,
  );
}
