/// Storage for settings passed into KaTeX, with correct default handling.
///
/// Port of KaTeX's `Settings.ts`. The TypeScript schema/processor machinery is
/// largely a product of TS's type system; here defaults are applied directly in
/// the constructor and the same `processor` clamps are applied inline.
library;

import 'package:katex/src/parse/parse_error.dart';
import 'package:katex/src/parse/token.dart';

/// A user-supplied strict-mode callback.
///
/// Receives an [errorCode], a human-readable [errorMsg], and an optional
/// [token], and returns `true`/`false`/`"ignore"`/`"warn"`/`"error"` (as
/// [bool]/[String]) or `null`/`void` to mean "no further processing".
typedef StrictFunction =
    Object? Function(String errorCode, String errorMsg, Token? token);

/// A user-supplied trust callback. Receives the trust [context] and returns
/// whether the (potentially dangerous) input should be trusted.
typedef TrustFunction = bool? Function(Map<String, Object?> context);

/// Output markup language.
enum OutputFormat { htmlAndMathml, html, mathml }

/// The main settings object.
///
/// The most important option is [displayMode]: whether the expression should be
/// typeset as inline math (`false`, the default) or display math (`true`).
class Settings {
  /// Creates a settings object, applying KaTeX's defaults for any option not
  /// supplied. [strict] may be a [bool], one of `"ignore"`/`"warn"`/`"error"`,
  /// or a [StrictFunction]. [trust] may be a [bool] or a [TrustFunction].
  Settings({
    bool? displayMode,
    OutputFormat? output,
    bool? leqno,
    bool? fleqn,
    bool? throwOnError,
    String? errorColor,
    Map<String, Object?>? macros,
    double? minRuleThickness,
    bool? colorIsTextColor,
    Object? strict,
    Object? trust,
    double? maxSize,
    double? maxExpand,
    bool? globalGroup,
  }) : displayMode = displayMode ?? false,
       output = output ?? OutputFormat.htmlAndMathml,
       leqno = leqno ?? false,
       fleqn = fleqn ?? false,
       throwOnError = throwOnError ?? true,
       errorColor = errorColor ?? '#cc0000',
       macros = macros ?? <String, Object?>{},
       // processor: (t) => max(0, t)
       minRuleThickness = minRuleThickness == null
           ? 0
           : (minRuleThickness < 0 ? 0 : minRuleThickness),
       colorIsTextColor = colorIsTextColor ?? false,
       strict = strict ?? false,
       trust = trust ?? false,
       // default Infinity; processor: (s) => max(0, s)
       maxSize = maxSize == null
           ? double.infinity
           : (maxSize < 0 ? 0 : maxSize),
       // default 1000; processor: (n) => max(0, n)
       maxExpand = maxExpand == null ? 1000 : (maxExpand < 0 ? 0 : maxExpand),
       globalGroup = globalGroup ?? false;

  /// Whether the expression should be typeset as display math.
  final bool displayMode;

  /// Determines the markup language of the output.
  final OutputFormat output;

  /// Render display math in leqno style (left-justified tags).
  final bool leqno;

  /// Render display math flush left.
  final bool fleqn;

  /// Render errors instead of throwing a [ParseError] when encountering one.
  final bool throwOnError;

  /// The color (CSS string) used to render errors when [throwOnError] is false.
  final String errorColor;

  /// Custom macros.
  final Map<String, Object?> macros;

  /// Minimum thickness, in ems, for fraction lines, `\sqrt` top lines, etc.
  final double minRuleThickness;

  /// Makes `\color` behave like LaTeX's 2-argument `\textcolor`.
  final bool colorIsTextColor;

  /// Strict / LaTeX-faithfulness mode. One of [bool], `"ignore"`/`"warn"`/
  /// `"error"`, or a [StrictFunction].
  final Object strict;

  /// Trust the input, enabling all HTML features such as `\url`. Either a [bool]
  /// or a [TrustFunction].
  final Object trust;

  /// If finite, caps all user-specified sizes to this many ems.
  final double maxSize;

  /// Limit on the number of macro expansions (to prevent infinite loops).
  final double maxExpand;

  /// Whether definitions are global by default.
  final bool globalGroup;

  /// Report nonstrict (non-LaTeX-compatible) input.
  ///
  /// Can safely not be called if [strict] is `false`.
  void reportNonstrict(String errorCode, String errorMsg, [Token? token]) {
    var strict = this.strict;
    if (strict is StrictFunction) {
      // Allow the return value to be bool or String (or null, meaning no
      // further processing).
      strict = strict(errorCode, errorMsg, token) ?? false;
    }
    if (strict == false || strict == 'ignore') {
      return;
    } else if (strict == true || strict == 'error') {
      throw ParseError(
        "LaTeX-incompatible input and strict mode is set to 'error': "
        '$errorMsg [$errorCode]',
        token,
      );
    } else if (strict == 'warn') {
      // KaTeX logs strict-mode warnings to the console; print is the
      // closest pure-Dart equivalent.
      // ignore: avoid_print
      print(
        "LaTeX-incompatible input and strict mode is set to 'warn': "
        '$errorMsg [$errorCode]',
      );
    } else {
      // won't happen in type-safe code
      // KaTeX logs strict-mode warnings to the console; print is the
      // closest pure-Dart equivalent.
      // ignore: avoid_print
      print(
        'LaTeX-incompatible input and strict mode is set to '
        "unrecognized '$strict': $errorMsg [$errorCode]",
      );
    }
  }

  /// Check whether to apply strict (LaTeX-adhering) behavior for unusual input.
  ///
  /// Unlike [reportNonstrict], will not throw; `"error"` translates to a return
  /// value of `true`, while `"ignore"` translates to `false`. `"warn"` prints a
  /// warning and returns `false`.
  bool useStrictBehavior(String errorCode, String errorMsg, [Token? token]) {
    var strict = this.strict;
    if (strict is StrictFunction) {
      // Catch any exceptions thrown by the function, treating them like
      // "error".
      try {
        strict = strict(errorCode, errorMsg, token) ?? false;
      } on Object {
        strict = 'error';
      }
    }
    if (strict == false || strict == 'ignore') {
      return false;
    } else if (strict == true || strict == 'error') {
      return true;
    } else if (strict == 'warn') {
      // KaTeX logs strict-mode warnings to the console; print is the
      // closest pure-Dart equivalent.
      // ignore: avoid_print
      print(
        "LaTeX-incompatible input and strict mode is set to 'warn': "
        '$errorMsg [$errorCode]',
      );
      return false;
    } else {
      // won't happen in type-safe code
      // KaTeX logs strict-mode warnings to the console; print is the
      // closest pure-Dart equivalent.
      // ignore: avoid_print
      print(
        'LaTeX-incompatible input and strict mode is set to '
        "unrecognized '$strict': $errorMsg [$errorCode]",
      );
      return false;
    }
  }

  /// Check whether to trust potentially dangerous input, returning `true`
  /// (trusted) or `false` (untrusted).
  ///
  /// [context] should have a `command` field; if it has a `url` field, a
  /// `protocol` field is added by this method (mutating [context]).
  bool isTrusted(Map<String, Object?> context) {
    final url = context['url'];
    if (url is String && url.isNotEmpty && context['protocol'] == null) {
      final protocol = protocolFromUrl(url);
      if (protocol == null) {
        return false;
      }
      context['protocol'] = protocol;
    }
    final trust = this.trust;
    final result = trust is TrustFunction ? trust(context) : trust;
    return result == true;
  }
}

/// Return the protocol of a [url], or `"_relative"` if the URL does not specify
/// a protocol (and thus is relative), or `null` if the URL has an invalid
/// protocol (so should be outright rejected).
///
/// Port of KaTeX's `protocolFromUrl` (from `utils.ts`).
String? protocolFromUrl(String url) {
  final protocol = RegExp(
    r'^[\x00-\x20]*([^\\/#?]*?)(:|&#0*58|&#x0*3a|&colon)',
    caseSensitive: false,
  ).firstMatch(url);
  if (protocol == null) {
    return '_relative';
  }
  // Reject weird colons.
  if (protocol.group(2) != ':') {
    return null;
  }
  // Reject invalid characters in scheme (RFC 3986 section 3.1).
  if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+\-.]*$').hasMatch(protocol.group(1)!)) {
    return null;
  }
  return protocol.group(1)!.toLowerCase();
}
