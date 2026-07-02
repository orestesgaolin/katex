/// Public, user-facing options for the top-level `renderToBox`/`renderToSvg`
/// API, plus the mapping to the internal [Settings] (T-005) and [Options]
/// (T-010).
///
/// This is a small, deliberately-minimal surface (mirroring the subset of
/// KaTeX's settings that the MVP supports): display vs. inline mode, a base
/// font size, an optional color, user macros, and error/strict behaviour.
/// Everything else uses KaTeX's defaults.
library;

import 'package:katex_dart/src/build/options.dart';
import 'package:katex_dart/src/build/style.dart';
import 'package:katex_dart/src/parse/parse_error.dart' show ParseError;
import 'package:katex_dart/src/parse/settings.dart';

/// User-facing options for rendering a TeX string.
///
/// Pass an instance to `renderToBox`/`renderToSvg`. All fields are optional;
/// the defaults match KaTeX (inline mode, no color, throw on error).
class KatexOptions {
  /// Creates render options.
  const KatexOptions({
    this.displayMode = false,
    this.fontSize = 1.0,
    this.color,
    this.macros,
    this.throwOnError = true,
    this.strict = false,
    this.minRuleThickness = 0.0,
    this.maxSize = double.infinity,
  });

  /// Whether to typeset as display math (`true`) or inline math (`false`,
  /// the default), mirroring KaTeX's `displayMode`.
  final bool displayMode;

  /// A scale applied to the whole expression (1.0 = normal size). This does
  /// not change the internal em layout; it is carried for the serializer/
  /// painter to scale by. Defaults to `1.0`.
  final double fontSize;

  /// An optional base color (CSS color string) applied to the whole
  /// expression, or `null` to inherit.
  final String? color;

  /// Custom macro definitions passed through to the parser, or `null`.
  final Map<String, Object?>? macros;

  /// Whether to throw a [ParseError] on invalid input (`true`, the default),
  /// mirroring KaTeX's `throwOnError`.
  final bool throwOnError;

  /// Strict / LaTeX-faithfulness mode, mirroring KaTeX's `strict`. One of a
  /// [bool], or one of `"ignore"`/`"warn"`/`"error"`.
  final Object strict;

  /// Minimum rule (bar) thickness in em, mirroring KaTeX's `minRuleThickness`.
  final double minRuleThickness;

  /// Cap on user-specified sizes in em, mirroring KaTeX's `maxSize`.
  final double maxSize;

  /// Maps these options to the internal parser [Settings].
  Settings toSettings() => Settings(
    displayMode: displayMode,
    throwOnError: throwOnError,
    macros: macros,
    strict: strict,
    minRuleThickness: minRuleThickness,
    maxSize: maxSize,
  );

  /// Builds the initial build-time [Options] for these render options,
  /// mirroring KaTeX's `buildTree`: displaystyle in [displayMode], else
  /// textstyle, with the configured color, max-size and min-rule-thickness.
  Options toOptions() {
    final settings = toSettings();
    var options = Options.initial(
      style: displayMode ? Style.DISPLAY : Style.TEXT,
      maxSize: settings.maxSize,
      minRuleThickness: settings.minRuleThickness,
    );
    if (color != null) {
      options = options.withColor(color!);
    }
    return options;
  }
}
