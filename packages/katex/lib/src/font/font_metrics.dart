/// Font metrics for KaTeX, ported from KaTeX `src/fontMetrics.ts`.
///
/// Provides:
///  * [FontMetrics] — the global per-style sigma/xi metrics (axis height,
///    quad, default rule thickness, etc.).
///  * [getGlobalMetrics] — selects the metrics for a given font size index.
///  * [getCharacterMetrics] — per-glyph metrics from the generated
///    `fontMetricsData` table, mirroring KaTeX's `extraCharacterMap` and
///    text-mode fallbacks.
library;

import 'package:katex/src/font/font_metrics_data.g.dart';
import 'package:katex/src/types.dart';
import 'package:meta/meta.dart';

export 'package:katex/src/types.dart' show Mode;

/// Per-glyph metrics: a character's bounding box and TeX corrections.
///
/// Mirrors KaTeX's `CharacterMetrics`. Values are in em (font design units
/// divided by units-per-em).
@immutable
class CharacterMetrics {
  const CharacterMetrics({
    required this.depth,
    required this.height,
    required this.italic,
    required this.skew,
    required this.width,
  });

  /// Distance below the baseline (positive = below).
  final double depth;

  /// Distance above the baseline.
  final double height;

  /// Italic correction.
  final double italic;

  /// Skew (kern toward the `\skewchar`), used for accent placement.
  final double skew;

  /// Advance width.
  final double width;

  @override
  bool operator ==(Object other) =>
      other is CharacterMetrics &&
      other.depth == depth &&
      other.height == height &&
      other.italic == italic &&
      other.skew == skew &&
      other.width == width;

  @override
  int get hashCode => Object.hash(depth, height, italic, skew, width);

  @override
  String toString() =>
      'CharacterMetrics(depth: $depth, height: $height, italic: $italic, '
      'skew: $skew, width: $width)';
}

/// In TeX there are three sets of dimensions, one each for textstyle
/// (size index 0), scriptstyle (index 1) and scriptscriptstyle (index 2).
/// These arrays hold the sigma/xi values in that order. See the long comment
/// in KaTeX's `fontMetrics.ts` for provenance.
const Map<String, List<double>> _sigmasAndXis = {
  'slant': [0.250, 0.250, 0.250], // sigma1
  'space': [0.000, 0.000, 0.000], // sigma2
  'stretch': [0.000, 0.000, 0.000], // sigma3
  'shrink': [0.000, 0.000, 0.000], // sigma4
  'xHeight': [0.431, 0.431, 0.431], // sigma5
  'quad': [1.000, 1.171, 1.472], // sigma6
  'extraSpace': [0.000, 0.000, 0.000], // sigma7
  'num1': [0.677, 0.732, 0.925], // sigma8
  'num2': [0.394, 0.384, 0.387], // sigma9
  'num3': [0.444, 0.471, 0.504], // sigma10
  'denom1': [0.686, 0.752, 1.025], // sigma11
  'denom2': [0.345, 0.344, 0.532], // sigma12
  'sup1': [0.413, 0.503, 0.504], // sigma13
  'sup2': [0.363, 0.431, 0.404], // sigma14
  'sup3': [0.289, 0.286, 0.294], // sigma15
  'sub1': [0.150, 0.143, 0.200], // sigma16
  'sub2': [0.247, 0.286, 0.400], // sigma17
  'supDrop': [0.386, 0.353, 0.494], // sigma18
  'subDrop': [0.050, 0.071, 0.100], // sigma19
  'delim1': [2.390, 1.700, 1.980], // sigma20
  'delim2': [1.010, 1.157, 1.420], // sigma21
  'axisHeight': [0.250, 0.250, 0.250], // sigma22
  // Extension-font (family 3) parameters, from cmex10.tfm.
  'defaultRuleThickness': [0.04, 0.049, 0.049], // xi8
  'bigOpSpacing1': [0.111, 0.111, 0.111], // xi9
  'bigOpSpacing2': [0.166, 0.166, 0.166], // xi10
  'bigOpSpacing3': [0.2, 0.2, 0.2], // xi11
  'bigOpSpacing4': [0.6, 0.611, 0.611], // xi12
  'bigOpSpacing5': [0.1, 0.143, 0.143], // xi13
  // The \sqrt rule width (height of the surd). Does not scale.
  'sqrtRuleThickness': [0.04, 0.04, 0.04],

  // How large a pt is, for metrics defined in terms of pts.
  'ptPerEm': [10.0, 10.0, 10.0],

  // Space between adjacent `|` columns in an array. 2.0 / ptPerEm.
  'doubleRuleSep': [0.2, 0.2, 0.2],

  // Width of separator lines in {array}. 0.4 / ptPerEm.
  'arrayRuleWidth': [0.04, 0.04, 0.04],

  // From LaTeX source2e.
  'fboxsep': [0.3, 0.3, 0.3], // 3 pt / ptPerEm
  'fboxrule': [0.04, 0.04, 0.04], // 0.4 pt / ptPerEm
};

/// Global (per-style) font metrics: a named lookup of sigma/xi constants plus
/// the derived [cssEmPerMu]. Mirrors KaTeX's `FontMetrics` record.
@immutable
class FontMetrics {
  const FontMetrics._(this._values, this.cssEmPerMu);

  /// Builds the metrics for the given font [sizeIndex] (0 = text, 1 = script,
  /// 2 = scriptscript).
  factory FontMetrics._forSizeIndex(int sizeIndex) {
    final values = <String, double>{};
    for (final entry in _sigmasAndXis.entries) {
      values[entry.key] = entry.value[sizeIndex];
    }
    final cssEmPerMu = _sigmasAndXis['quad']![sizeIndex] / 18.0;
    return FontMetrics._(values, cssEmPerMu);
  }

  final Map<String, double> _values;

  /// CSS em per math unit (mu): `quad / 18`.
  final double cssEmPerMu;

  /// Looks up a named metric (e.g. `axisHeight`, `defaultRuleThickness`).
  double operator [](String key) {
    final v = _values[key];
    if (v == null) {
      throw ArgumentError.value(key, 'key', 'Unknown font metric');
    }
    return v;
  }

  // Convenience accessors for the most commonly used metrics.
  double get axisHeight => _values['axisHeight']!;
  double get quad => _values['quad']!;
  double get xHeight => _values['xHeight']!;
  double get defaultRuleThickness => _values['defaultRuleThickness']!;
  double get sqrtRuleThickness => _values['sqrtRuleThickness']!;
  double get bigOpSpacing1 => _values['bigOpSpacing1']!;
  double get bigOpSpacing2 => _values['bigOpSpacing2']!;
  double get bigOpSpacing3 => _values['bigOpSpacing3']!;
  double get bigOpSpacing4 => _values['bigOpSpacing4']!;
  double get bigOpSpacing5 => _values['bigOpSpacing5']!;
  double get ptPerEm => _values['ptPerEm']!;
}

final Map<int, FontMetrics> _fontMetricsBySizeIndex = {};

/// Returns the global font metrics for a TeX font [size] index, mirroring
/// KaTeX's `getGlobalMetrics`. Sizes >= 5 use textstyle, 3–4 use scriptstyle,
/// and below 3 use scriptscriptstyle.
FontMetrics getGlobalMetrics(num size) {
  final int sizeIndex;
  if (size >= 5) {
    sizeIndex = 0;
  } else if (size >= 3) {
    sizeIndex = 1;
  } else {
    sizeIndex = 2;
  }
  return _fontMetricsBySizeIndex.putIfAbsent(
    sizeIndex,
    () => FontMetrics._forSizeIndex(sizeIndex),
  );
}

/// Rough approximations mapping characters we lack metrics for onto similar
/// glyphs we do have. Ported verbatim from KaTeX's `extraCharacterMap`.
const Map<String, String> _extraCharacterMap = {
  // Latin-1
  'Å': 'A',
  'Ð': 'D',
  'Þ': 'o',
  'å': 'a',
  'ð': 'd',
  'þ': 'o',
  // Cyrillic
  'А': 'A',
  'Б': 'B',
  'В': 'B',
  'Г': 'F',
  'Д': 'A',
  'Е': 'E',
  'Ж': 'K',
  'З': '3',
  'И': 'N',
  'Й': 'N',
  'К': 'K',
  'Л': 'N',
  'М': 'M',
  'Н': 'H',
  'О': 'O',
  'П': 'N',
  'Р': 'P',
  'С': 'C',
  'Т': 'T',
  'У': 'y',
  'Ф': 'O',
  'Х': 'X',
  'Ц': 'U',
  'Ч': 'h',
  'Ш': 'W',
  'Щ': 'W',
  'Ъ': 'B',
  'Ы': 'X',
  'Ь': 'B',
  'Э': '3',
  'Ю': 'X',
  'Я': 'R',
  'а': 'a',
  'б': 'b',
  'в': 'a',
  'г': 'r',
  'д': 'y',
  'е': 'e',
  'ж': 'm',
  'з': 'e',
  'и': 'n',
  'й': 'n',
  'к': 'n',
  'л': 'n',
  'м': 'm',
  'н': 'n',
  'о': 'o',
  'п': 'n',
  'р': 'p',
  'с': 'c',
  'т': 'o',
  'у': 'y',
  'ф': 'b',
  'х': 'x',
  'ц': 'n',
  'ч': 'n',
  'ш': 'w',
  'щ': 'w',
  'ъ': 'a',
  'ы': 'm',
  'ь': 'a',
  'э': 'e',
  'ю': 'm',
  'я': 'r',
};

/// Flattened [start, end] inclusive codepoint blocks for scripts KaTeX
/// supports in `\text{}`. Ported from KaTeX's `unicodeScripts.ts`.
const List<int> _supportedBlocks = [
  0x0100, 0x024f, // Latin Extended-A / B
  0x0300, 0x036f, // Combining Diacritical marks
  0x0400, 0x04ff, // Cyrillic
  0x0530, 0x058f, // Armenian
  0x0900, 0x109f, // Brahmic scripts
  0x10a0, 0x10ff, // Georgian
  0x3000, 0x30ff, // CJK symbols, Hiragana, Katakana
  0x4e00, 0x9faf, // CJK ideograms
  0xff00, 0xff60, // Fullwidth punctuation
  0xac00, 0xd7af, // Hangul
];

/// Returns true if [codepoint] falls within a supported `\text{}` script
/// block. Mirrors KaTeX's `supportedCodepoint`.
bool supportedCodepoint(int codepoint) {
  for (var i = 0; i < _supportedBlocks.length; i += 2) {
    if (codepoint >= _supportedBlocks[i] &&
        codepoint <= _supportedBlocks[i + 1]) {
      return true;
    }
  }
  return false;
}

/// Looks up per-glyph metrics for [character] (a full string; the first
/// code unit is used, matching KaTeX's `charCodeAt(0)`) in the font named
/// [font] (e.g. `Main-Regular`), in the given [mode].
///
/// Returns `null` when no metrics are available. Throws [ArgumentError] when
/// [font] is unknown, matching KaTeX's behaviour of throwing for an unknown
/// font name.
CharacterMetrics? getCharacterMetrics(
  String character,
  String font,
  Mode mode,
) {
  final familyMap = fontMetricsData[font];
  if (familyMap == null) {
    throw ArgumentError.value(font, 'font', 'Font metrics not found for font');
  }

  var ch = character.codeUnitAt(0);
  var metrics = familyMap[ch];

  final firstChar = character.isNotEmpty ? character[0] : '';
  if (metrics == null && _extraCharacterMap.containsKey(firstChar)) {
    ch = _extraCharacterMap[firstChar]!.codeUnitAt(0);
    metrics = familyMap[ch];
  }

  if (metrics == null && mode == Mode.text) {
    // We don't typically have metrics for Asian scripts but support them in
    // text mode; fall back to 'M' (charcode 77) for supported codepoints,
    // which is close enough since we (currently) only care about height.
    if (supportedCodepoint(ch)) {
      metrics = familyMap[77];
    }
  }

  if (metrics != null) {
    return CharacterMetrics(
      depth: metrics[0],
      height: metrics[1],
      italic: metrics[2],
      skew: metrics[3],
      width: metrics[4],
    );
  }
  return null;
}

/// Convenience overload taking a raw [codepoint] instead of a string. Note
/// this skips the [_extraCharacterMap] fallback (which keys on the source
/// character), matching the limited information available from a bare code.
CharacterMetrics? getCharacterMetricsByCode(
  int codepoint,
  String font,
  Mode mode,
) => getCharacterMetrics(String.fromCharCode(codepoint), font, mode);
