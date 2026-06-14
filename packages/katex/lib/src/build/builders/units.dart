/// Unit conversion for builders, ported from KaTeX `src/units.ts`
/// ([calculateSize] → em). Lives under `builders/` to keep the T-011 surface
/// self-contained; promote to `build/units.dart` if other layers need it.
library;

import 'package:katex/src/ast/parse_node.dart' show Measurement;
import 'package:katex/src/build/options.dart';
import 'package:katex/src/parse/parse_error.dart';

// TeX points per absolute unit (verbatim from KaTeX's `ptPerUnit`).
const Map<String, double> _ptPerUnit = {
  'pt': 1,
  'mm': 7227 / 2540,
  'cm': 7227 / 254,
  'in': 72.27,
  'bp': 803 / 800,
  'pc': 12,
  'dd': 1238 / 1157,
  'cc': 14856 / 1157,
  'nd': 685 / 642,
  'nc': 1370 / 107,
  'sp': 1 / 65536,
  'px': 803 / 800,
};

/// Converts a [Measurement] to a CSS em value under [options]. Faithful port
/// of KaTeX's `calculateSize`.
double calculateSize(Measurement sizeValue, Options options) {
  final double scale;
  final unit = sizeValue.unit;
  if (_ptPerUnit.containsKey(unit)) {
    scale =
        _ptPerUnit[unit]! /
        options.fontMetrics().ptPerEm /
        options.sizeMultiplier;
  } else if (unit == 'mu') {
    scale = options.fontMetrics().cssEmPerMu;
  } else {
    final unitOptions = options.style.isTight()
        ? options.havingStyle(options.style.text())
        : options;
    final double baseScale;
    if (unit == 'ex') {
      baseScale = unitOptions.fontMetrics().xHeight;
    } else if (unit == 'em') {
      baseScale = unitOptions.fontMetrics().quad;
    } else {
      throw ParseError("Invalid unit: '$unit'");
    }
    scale = unitOptions != options
        ? baseScale * unitOptions.sizeMultiplier / options.sizeMultiplier
        : baseScale;
  }
  return sizeValue.number * scale;
}
