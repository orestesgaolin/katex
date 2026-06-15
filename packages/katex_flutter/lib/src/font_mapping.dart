/// Maps a box-tree [KatexFont] (family + variant) and a pixel size to a Flutter
/// [TextStyle] that selects the matching bundled KaTeX font.
///
/// This is pure mapping logic — no canvas, no widget — so it can be unit-tested
/// without a real rendering surface. The painter (T-016) uses [textStyleFor] to
/// build the [TextStyle] handed to a `TextPainter` for each `GlyphNode`.
library;

import 'package:flutter/painting.dart';
// The box tree's font model. `KatexFont`/`KatexFontVariant` are referenced by
// the public box tree (GlyphNode) but not re-exported from the katex barrel,
// so import the source library directly.
// ignore: implementation_imports
import 'package:katex/src/font/font_types.dart';

/// The name of this package, used so Flutter resolves the bundled fonts
/// declared under `flutter: fonts:` in this package's `pubspec.yaml`.
const String katexFlutterPackage = 'katex_flutter';

/// Builds a [TextStyle] for [font] at [fontSizePx] logical pixels.
///
/// - `fontFamily` is `KaTeX_<fontName>` (e.g. `KaTeX_Math-Italic`) — one unique
///   family per font FILE, matching the per-file families declared in
///   `pubspec.yaml`.
/// - `fontWeight`/`fontStyle` are ALWAYS normal. KaTeX's italic/bold fonts bake
///   the slant/weight into the glyph outlines but leave the file internally
///   "Regular" (italicAngle 0, no italic/bold bits). Requesting
///   `FontStyle.italic` / `FontWeight.w700` would make Skia synthesize oblique
///   / bold ON TOP of the already-styled outlines — a visible double slant
///   versus the SVG/KaTeX. Selecting the exact file by family avoids synthesis.
/// - `package` is set so the bundled (package) font is resolved.
/// - `height` is `1.0` so the line height does not add extra leading; the box
///   tree already carries explicit height/depth.
TextStyle textStyleFor(
  KatexFont font,
  double fontSizePx, {
  Color? color,
}) {
  return TextStyle(
    fontFamily: 'KaTeX_${font.fontName}',
    package: katexFlutterPackage,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.normal,
    fontSize: fontSizePx,
    height: 1,
    color: color,
  );
}
