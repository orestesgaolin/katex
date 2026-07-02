/// A pure-Dart port of KaTeX.
///
/// Parses LaTeX math into a backend-agnostic box tree ([BoxNode]) and
/// serializes it to SVG. No Flutter dependency.
///
/// See `PLAN.md` and `tickets/BOARD.md` at the repo root for status.
library;

import 'package:katex_dart/src/box/box_node.dart';
import 'package:katex_dart/src/build/build_expression.dart';
import 'package:katex_dart/src/build/katex_options.dart';
import 'package:katex_dart/src/parse/parse_tree.dart';
import 'package:katex_dart/src/svg/svg_serializer.dart';

// ---------------------------------------------------------------------------
// Public exports — the box tree model, render options, and parse errors.
// ---------------------------------------------------------------------------

export 'package:katex_dart/src/box/box_node.dart';
export 'package:katex_dart/src/build/katex_options.dart' show KatexOptions;
// Font identity + per-glyph metrics types are part of the public box-tree model
// (GlyphNode carries a KatexFont / CharacterMetrics); export them so consumers
// like katex can read them without reaching into src/.
export 'package:katex_dart/src/font/font_metrics.dart' show CharacterMetrics, Mode;
export 'package:katex_dart/src/font/font_types.dart'
    show KatexFont, KatexFontFamily, KatexFontVariant;
export 'package:katex_dart/src/parse/parse_error.dart' show ParseError;
// Glyph outline paths (font units, y-up) keyed by font name → codepoint, plus
// the units-per-em they're authored at. Part of the public model so backends
// that render glyphs as filled paths (e.g. the SVG serializer, or an external
// consumer that paints outlines) don't need to reach into src/.
export 'package:katex_dart/src/svg/glyph_paths.g.dart'
    show katexGlyphPaths, katexGlyphUnitsPerEm;

/// Renders [tex] to a [BoxNode] tree — the primary public API.
///
/// Runs the full pipeline: lex + macro-expand + parse (via `parseTree`, T-008)
/// → build the box tree (`buildHTML`/`buildExpression`, this ticket). The
/// returned node is the root of the box tree; its `height`/`depth`/`width` (in
/// em) describe the rendered extent.
BoxNode renderToBox(String tex, {KatexOptions? options}) {
  final opts = options ?? const KatexOptions();
  final settings = opts.toSettings();
  final tree = parseTree(tex, settings);
  return buildHTML(tree, opts.toOptions());
}

/// Renders [tex] to a self-contained SVG string, built on [renderToBox] and the
/// box-tree SVG serializer (T-012).
///
/// [KatexOptions.fontSize] scales the em → user-unit mapping (1.0 maps to the
/// serializer's default font size).
String renderToSvg(String tex, {KatexOptions? options}) {
  final opts = options ?? const KatexOptions();
  final box = renderToBox(tex, options: opts);
  return serializeBox(box, fontSize: defaultFontSize * opts.fontSize);
}
