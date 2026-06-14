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
/// - `fontFamily` is [KatexFont.cssFamily] (e.g. `KaTeX_Main`), matching the
///   family names declared in `pubspec.yaml`.
/// - `fontWeight` is [FontWeight.w700] for bold variants, else
///   [FontWeight.w400].
/// - `fontStyle` is [FontStyle.italic] for italic variants, else
///   [FontStyle.normal].
/// - `package` is set so the bundled (package) font is resolved.
/// - `height` is `1.0` so the line height does not add extra leading; the box
///   tree already carries explicit height/depth.
TextStyle textStyleFor(
  KatexFont font,
  double fontSizePx, {
  Color? color,
}) {
  final variant = font.variant;
  final isBold =
      variant == KatexFontVariant.bold ||
      variant == KatexFontVariant.boldItalic;
  final isItalic =
      variant == KatexFontVariant.italic ||
      variant == KatexFontVariant.boldItalic;

  return TextStyle(
    fontFamily: font.cssFamily,
    package: katexFlutterPackage,
    fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
    fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
    fontSize: fontSizePx,
    height: 1,
    color: color,
  );
}
