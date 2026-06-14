/// Build-time options, ported from KaTeX `src/Options.ts`.
///
/// An `Options` object carries the current `Style`, color, size, text size,
/// phantom flag, and font selection (math `font`, text `fontFamily`,
/// `fontWeight`, `fontShape`) while the builder recurses over the parse tree.
///
/// [Options] is immutable: to obtain a variant, call one of the `having*` /
/// `with*` methods, which return a new [Options] (or `this` when nothing
/// changes, matching KaTeX).
library;

import 'package:katex/src/build/style.dart';
import 'package:katex/src/font/font_metrics.dart';
import 'package:meta/meta.dart';

// Each element contains [textsize, scriptsize, scriptscriptsize]. The size
// mappings are taken from TeX with \normalsize = 10pt. Verbatim from KaTeX.
const List<List<int>> _sizeStyleMap = [
  [1, 1, 1], // size1: [5, 5, 5]              \tiny
  [2, 1, 1], // size2: [6, 5, 5]
  [3, 1, 1], // size3: [7, 5, 5]              \scriptsize
  [4, 2, 1], // size4: [8, 6, 5]              \footnotesize
  [5, 2, 1], // size5: [9, 6, 5]              \small
  [6, 3, 1], // size6: [10, 7, 5]             \normalsize
  [7, 4, 2], // size7: [12, 8, 6]             \large
  [8, 6, 3], // size8: [14.4, 10, 7]          \Large
  [9, 7, 6], // size9: [17.28, 12, 10]        \LARGE
  [10, 8, 7], // size10: [20.74, 14.4, 12]     \huge
  [11, 10, 9], // size11: [24.88, 20.74, 17.28] \HUGE
];

// Font-size multipliers, indexed by (size - 1). Verbatim from KaTeX.
const List<double> _sizeMultipliers = [
  0.5,
  0.6,
  0.7,
  0.8,
  0.9,
  1.0,
  1.2,
  1.44,
  1.728,
  2.074,
  2.488,
];

int _sizeAtStyle(int size, Style style) =>
    style.size < 2 ? size : _sizeStyleMap[size - 1][style.size - 1];

/// The main build options class, holding the current [style], color, size, and
/// font selection. A faithful port of KaTeX's `Options`.
///
/// Options should not be mutated; use the `having*` / `with*` methods to derive
/// a new instance.
@immutable
class Options {
  /// Creates options. Most callers should use [Options.initial] for a sensible
  /// default and then derive variants with the `having*`/`with*` methods.
  ///
  /// [size] defaults to [baseSize] (`6`, i.e. `\normalsize`). [textSize]
  /// defaults to [size]. The string font fields default to the empty string
  /// (KaTeX's "no font selected").
  Options({
    required this.style,
    this.color,
    int? size,
    int? textSize,
    this.phantom = false,
    this.font = '',
    this.fontFamily = '',
    this.fontWeight = '',
    this.fontShape = '',
    this.maxSize = double.infinity,
    this.minRuleThickness = 0,
  }) : size = size ?? baseSize,
       textSize = textSize ?? size ?? baseSize,
       sizeMultiplier = _sizeMultipliers[(size ?? baseSize) - 1];

  /// Convenience constructor for the default options: displaystyle at the base
  /// size, no color or font selection.
  factory Options.initial({
    Style style = Style.DISPLAY,
    double maxSize = double.infinity,
    double minRuleThickness = 0,
  }) => Options(
    style: style,
    maxSize: maxSize,
    minRuleThickness: minRuleThickness,
  );

  /// The base size index (KaTeX's `BASESIZE`), `\normalsize`.
  static const int baseSize = 6;

  /// The current math style.
  final Style style;

  /// The current color (CSS color string), or `null` to inherit.
  final String? color;

  /// The current size index (1–11).
  final int size;

  /// The text size index this size derives from (used by [havingStyle]).
  final int textSize;

  /// Whether content is rendered as a phantom (transparent).
  final bool phantom;

  /// The active math font command (e.g. `mathbf`, `mathit`), or `''`.
  final String font;

  /// The active text font family (e.g. `textrm`, `textsf`), or `''`.
  final String fontFamily;

  /// The active text font weight (e.g. `textbf`), or `''`.
  final String fontWeight;

  /// The active text font shape (e.g. `textit`), or `''`.
  final String fontShape;

  /// The font-size multiplier for the current [size] (KaTeX `sizeMultiplier`).
  final double sizeMultiplier;

  /// The maximum allowed size for user-sizable content.
  final double maxSize;

  /// The minimum rule (bar) thickness.
  final double minRuleThickness;

  /// Returns a new options object with the same properties as `this`, with the
  /// given non-null overrides applied. Mirrors KaTeX's `extend`.
  ///
  /// Pass [resetColor]`: true` to clear [color] back to `null` (since `null`
  /// otherwise means "leave unchanged" here).
  Options extend({
    Style? style,
    String? color,
    bool resetColor = false,
    int? size,
    int? textSize,
    bool? phantom,
    String? font,
    String? fontFamily,
    String? fontWeight,
    String? fontShape,
    double? maxSize,
    double? minRuleThickness,
  }) {
    return Options(
      style: style ?? this.style,
      color: resetColor ? null : (color ?? this.color),
      size: size ?? this.size,
      textSize: textSize ?? this.textSize,
      phantom: phantom ?? this.phantom,
      font: font ?? this.font,
      fontFamily: fontFamily ?? this.fontFamily,
      fontWeight: fontWeight ?? this.fontWeight,
      fontShape: fontShape ?? this.fontShape,
      maxSize: maxSize ?? this.maxSize,
      minRuleThickness: minRuleThickness ?? this.minRuleThickness,
    );
  }

  /// Returns options with the given [style]. Returns `this` if unchanged.
  Options havingStyle(Style style) {
    if (this.style == style) {
      return this;
    }
    return extend(style: style, size: _sizeAtStyle(textSize, style));
  }

  /// Returns options with a cramped version of the current style.
  Options havingCrampedStyle() => havingStyle(style.cramp());

  /// Returns options with the given [size] in at least textstyle. Returns
  /// `this` if appropriate.
  Options havingSize(int size) {
    if (this.size == size && textSize == size) {
      return this;
    }
    return extend(style: style.text(), size: size, textSize: size);
  }

  /// Like `havingSize(baseSize).havingStyle(style)`. Returns `this` if
  /// appropriate.
  Options havingBaseStyle(Style? style) {
    final s = style ?? this.style.text();
    final wantSize = _sizeAtStyle(baseSize, s);
    if (size == wantSize && textSize == baseSize && this.style == s) {
      return this;
    }
    return extend(style: s, size: wantSize);
  }

  /// Removes the effect of sizing changes (e.g. `\Huge`) while keeping the
  /// current style (e.g. `\scriptstyle`).
  Options havingBaseSizing() {
    final int size;
    switch (style.id) {
      case 4:
      case 5:
        size = 3; // normalsize in scriptstyle
      case 6:
      case 7:
        size = 1; // normalsize in scriptscriptstyle
      default:
        size = 6; // normalsize in textstyle or displaystyle
    }
    return extend(style: style.text(), size: size);
  }

  /// Returns options with the given [color].
  Options withColor(String color) => extend(color: color);

  /// Returns options with `phantom` set to true.
  Options withPhantom() => extend(phantom: true);

  /// Returns options with the given math [font].
  Options withFont(String font) => extend(font: font);

  /// Returns options with the given text [fontFamily] (clears [font]).
  Options withTextFontFamily(String fontFamily) =>
      extend(fontFamily: fontFamily, font: '');

  /// Returns options with the given text [fontWeight] (clears [font]).
  Options withTextFontWeight(String fontWeight) =>
      extend(fontWeight: fontWeight, font: '');

  /// Returns options with the given text [fontShape] (clears [font]).
  Options withTextFontShape(String fontShape) =>
      extend(fontShape: fontShape, font: '');

  /// The global font metrics for the current [size] (KaTeX `fontMetrics`).
  FontMetrics fontMetrics() => getGlobalMetrics(size);

  /// The effective CSS color: `transparent` when [phantom], else [color].
  String? getColor() => phantom ? 'transparent' : color;
}
