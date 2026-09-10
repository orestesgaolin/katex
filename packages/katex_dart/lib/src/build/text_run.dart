/// Support for rendering complex scripts (Arabic, Hebrew, …) inside `\text{}`
/// as whole shaped runs instead of individual glyphs.
///
/// ## Why this exists
/// KaTeX's own fonts cover Latin, Greek, Cyrillic and a handful of symbol
/// ranges. For anything else `getCharacterMetrics` returns null, and since the
/// builder cannot place a glyph it has no metrics for, those characters were
/// dropped outright — "مرة" rendered as nothing at all.
///
/// Simply supplying fallback metrics does not fix it. Arabic is cursive: each
/// letter takes a different form depending on its neighbours, and the script
/// runs right to left. Emitting one box per character at a precomputed x —
/// which is the entire box-tree model — yields isolated letterforms in visual
/// left-to-right order, which is unreadable. The text has to reach the backend
/// as ONE string so the platform's text engine can shape and reorder it.
///
/// ## What this is not
/// This is a pragmatic fallback, not real complex-script typesetting. The run
/// is handed to the platform with whatever font it picks, so it will not match
/// the KaTeX fonts, and upstream KaTeX has no equivalent (it leaks the
/// character into the DOM and lets the browser cope). Metrics are only as good
/// as the measurer supplied; without one they are estimated and the
/// surrounding layout is approximate. See [defaultTextRunMeasurer].
library;

import 'dart:math' as math;

import 'package:katex_dart/src/font/font_metrics.dart';
import 'package:meta/meta.dart';

/// Measured dimensions of a text run, in em (before the size multiplier).
@immutable
class TextRunMetrics {
  /// Creates metrics for a text run.
  const TextRunMetrics({
    required this.width,
    required this.height,
    required this.depth,
  });

  /// Horizontal advance, in em.
  final double width;

  /// Extent above the baseline, in em.
  final double height;

  /// Extent below the baseline, in em.
  final double depth;

  @override
  String toString() =>
      'TextRunMetrics(w: ${width.toStringAsFixed(4)}, '
      'h: ${height.toStringAsFixed(4)}, d: ${depth.toStringAsFixed(4)})';
}

/// Measures [text] for layout, in em.
///
/// A backend that can shape and measure text (the Flutter painter, via
/// `TextPainter`) should supply one of these through
/// `KatexOptions.measureTextRun`, so the reserved space matches what is
/// actually drawn. Pure-Dart callers get [defaultTextRunMeasurer].
typedef TextRunMeasurer = TextRunMetrics Function(String text);

/// The fallback measurer: a rough estimate from the KaTeX Main font.
///
/// It takes the ascent/descent of `M` and assumes a fixed average advance per
/// character. That is necessarily wrong for a proportional script — it cannot
/// know the font the backend will pick — so a run measured this way reserves
/// approximately, not exactly, the right space. The estimate errs slightly
/// wide, because leaving a small gap after the run reads far better than
/// letting the next atom overlap it.
TextRunMetrics defaultTextRunMeasurer(String text) {
  const averageAdvanceEm = 0.6;
  final m = getCharacterMetrics('M', 'Main-Regular', Mode.text);
  return TextRunMetrics(
    width: text.runes.length * averageAdvanceEm,
    height: m?.height ?? 0.7,
    // Many scripts descend below the baseline; reserve a little even though
    // `M` does not.
    depth: math.max(m?.depth ?? 0, 0.2),
  );
}

/// Unicode blocks that must be shaped as a whole run rather than per glyph.
///
/// These are scripts that are cursive, right-to-left, or both, and that the
/// KaTeX fonts do not cover. Ranges are `[start, end]` inclusive, flattened.
const List<int> _complexScriptBlocks = [
  0x0590, 0x05ff, // Hebrew
  0x0600, 0x06ff, // Arabic
  0x0700, 0x074f, // Syriac
  0x0750, 0x077f, // Arabic Supplement
  0x0780, 0x07bf, // Thaana
  0x07c0, 0x07ff, // NKo
  0x0800, 0x083f, // Samaritan
  0x0840, 0x085f, // Mandaic
  0x08a0, 0x08ff, // Arabic Extended-A
  0xfb1d, 0xfdff, // Hebrew/Arabic presentation forms A
  0xfe70, 0xfeff, // Arabic presentation forms B
];

/// Whether [codepoint] belongs to a script that needs whole-run shaping.
bool isComplexScript(int codepoint) {
  for (var i = 0; i < _complexScriptBlocks.length; i += 2) {
    if (codepoint >= _complexScriptBlocks[i] &&
        codepoint <= _complexScriptBlocks[i + 1]) {
      return true;
    }
  }
  return false;
}

/// Whether [codepoint] is right-to-left, so a run containing it should be laid
/// out RTL. Covers the Hebrew and Arabic-family blocks above.
bool isRtl(int codepoint) =>
    (codepoint >= 0x0590 && codepoint <= 0x08ff) ||
    (codepoint >= 0xfb1d && codepoint <= 0xfdff) ||
    (codepoint >= 0xfe70 && codepoint <= 0xfeff);
