/// Shaping and measurement for complex-script text runs (Arabic, Hebrew, …).
///
/// The pure-Dart core cannot measure these: it lays out from static KaTeX font
/// metric tables, and the KaTeX fonts have no coverage for these scripts. So it
/// falls back to `defaultTextRunMeasurer`, a rough estimate, and the space
/// reserved around the run is only approximate.
///
/// Flutter can do better. [flutterTextRunMeasurer] measures the run with the
/// same `TextPainter` configuration [buildTextRunPainter] later paints it with,
/// so the reserved box matches the ink exactly. The `Math` widget installs it
/// via `KatexOptions.measureTextRun`.
library;

import 'package:flutter/widgets.dart';
import 'package:katex_dart/katex_dart.dart';

/// The em size measurements are taken at.
///
/// Measuring at a realistic pixel size rather than 1.0 keeps the result clear
/// of font hinting and rounding artefacts at tiny sizes; the metrics are scaled
/// back to em by dividing by this.
const double _measureFontSizePx = 100;

/// Font families to try for complex-script runs, most preferred first.
///
/// Empty by default, which leaves the family unset so the platform's own font
/// fallback picks something covering the script — the right behavior on a real
/// device, where the system ships Arabic and Hebrew faces.
///
/// Set this when that is not good enough: to pin a specific typeface, to bundle
/// a font with the app for consistent rendering across platforms, or to make
/// runs render under `flutter_test`, which has no system fallback at all and
/// otherwise draws tofu.
///
/// ```dart
/// katexTextRunFontFamilies = ['Noto Naskh Arabic', 'Amiri'];
/// ```
List<String> katexTextRunFontFamilies = <String>[];

/// Builds the `TextPainter` used to shape [text] at [fontSizePx].
///
/// The family comes from [katexTextRunFontFamilies]; when that is empty no
/// family is named at all, because the bundled KaTeX faces have no glyphs for
/// these scripts and naming one would only produce tofu. Either way the run
/// will not match the surrounding KaTeX typeface — that is the accepted cost of
/// rendering the text at all.
TextPainter buildTextRunPainter(
  String text,
  double fontSizePx, {
  Color color = const Color(0xFF000000),
  bool rtl = false,
}) {
  final families = katexTextRunFontFamilies;
  return TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSizePx,
        color: color,
        height: 1,
        fontFamily: families.isEmpty ? null : families.first,
        fontFamilyFallback: families.length > 1 ? families.sublist(1) : null,
      ),
    ),
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    textAlign: TextAlign.left,
  )..layout();
}

/// Measures [text] by shaping it exactly as it will be painted.
///
/// Height and depth come from the laid-out line's ascent/descent, so a run with
/// descenders reserves the space it needs.
TextRunMetrics flutterTextRunMeasurer(String text) {
  final rtl = text.runes.any(isRtl);
  final tp = buildTextRunPainter(text, _measureFontSizePx, rtl: rtl);
  final ascent = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  return TextRunMetrics(
    width: tp.width / _measureFontSizePx,
    height: ascent / _measureFontSizePx,
    depth: (tp.height - ascent) / _measureFontSizePx,
  );
}
