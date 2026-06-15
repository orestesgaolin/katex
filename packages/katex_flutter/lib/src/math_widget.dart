/// The public [Math] widget — the user-facing entry point for rendering LaTeX
/// math in Flutter (T-017, milestone 5).
///
/// [Math] is a thin, declarative wrapper over the pure-Dart pipeline: it calls
/// `renderToBox` (from `package:katex/katex.dart`) **once per build** to parse
/// and build the backend-agnostic box tree, then paints that tree with the
/// T-016 [KatexBoxPainter] inside a correctly-sized [CustomPaint]. There is no
/// re-parsing during paint — the widget is a pure consumer of the box tree, in
/// keeping with `PLAN.md`.
library;

import 'package:flutter/widgets.dart';
import 'package:katex/katex.dart';
import 'package:katex_flutter/src/render/box_painter.dart';

/// The default base font size, in logical pixels per em, used when the caller
/// does not pass [Math.fontSize].
///
/// KaTeX's box tree is laid out in **em** units; the painter multiplies those
/// by a pixels-per-em value to get logical pixels. 20.0 px/em is a readable
/// default roughly matching a typical body text size.
const double kDefaultMathFontSize = 20;

/// A widget that renders a LaTeX math [tex] string.
///
/// Example:
/// ```dart
/// Math(r'\frac{a}{b}')
/// Math(r'\sum_{i=0}^{n} i', displayMode: true, fontSize: 28, color: Colors.indigo)
/// ```
///
/// ## Sizing & `fontSize` semantics
/// [fontSize] is the **base size in logical pixels per em** that the box tree
/// is scaled by (it is *not* multiplied by [KatexOptions.fontSize] — this
/// widget owns the px-per-em mapping directly). When omitted it defaults to
/// [kDefaultMathFontSize] (20.0). The widget sizes itself to the intrinsic
/// extent of the rendered box (`boxSizePx`), so it lays out correctly inside
/// rows, columns, wraps, etc.
///
/// ## Error handling
/// [renderToBox] may throw a [ParseError] on invalid input. Behaviour:
///  * If [throwOnError] is `true`, the error propagates out of [build] (the
///    caller is responsible for catching it).
///  * Otherwise, if [onError] is provided, its result is rendered in place of
///    the math.
///  * Otherwise (the default), a non-fatal fallback is shown: the raw [tex] in
///    KaTeX's error red (`#cc0000`). The widget tree never crashes.
class Math extends StatelessWidget {
  /// Creates a [Math] widget for the LaTeX source [tex].
  const Math(
    this.tex, {
    super.key,
    this.displayMode = false,
    this.fontSize,
    this.color,
    this.onError,
    this.throwOnError = false,
  });

  /// The LaTeX math source to render (e.g. `r'\frac{a}{b}'`).
  final String tex;

  /// Whether to typeset as display math (`true`) or inline math (`false`, the
  /// default), mirroring KaTeX's `displayMode`.
  final bool displayMode;

  /// Base size in **logical pixels per em**. Defaults to
  /// [kDefaultMathFontSize] when `null`.
  final double? fontSize;

  /// The base text color. When `null`, the ambient [DefaultTextStyle] color is
  /// used (falling back to opaque black). Colors set *inside* the expression
  /// (e.g. `\textcolor`) still override this for their sub-trees.
  final Color? color;

  /// Builder invoked to render a fallback when parsing/building throws and
  /// [throwOnError] is `false`. When `null`, a default red-[tex] fallback is
  /// shown instead.
  final Widget Function(BuildContext context, Object error)? onError;

  /// Whether to rethrow a parse/build error out of [build] (`false` by
  /// default). When `false`, errors are handled via [onError] or the default
  /// fallback and never crash the widget tree.
  final bool throwOnError;

  /// KaTeX's error color (`#cc0000`), used for the default fallback rendering.
  static const Color _errorColor = Color(0xFFCC0000);

  @override
  Widget build(BuildContext context) {
    final baseColor = color ??
        DefaultTextStyle.of(context).style.color ??
        const Color(0xFF000000);
    final fontSizePx = fontSize ?? kDefaultMathFontSize;

    final BoxNode box;
    try {
      box = renderToBox(
        tex,
        options: KatexOptions(
          displayMode: displayMode,
          color: _toCssColor(color),
          throwOnError: throwOnError,
        ),
      );
    } on ParseError catch (error) {
      if (throwOnError) {
        rethrow;
      }
      return _buildError(context, error);
    } on Object catch (error) {
      if (throwOnError) {
        rethrow;
      }
      return _buildError(context, error);
    }

    // Size to the box PLUS an ink-overflow pad on every side, and paint with
    // the matching origin offset, so glyph/SVG ink that overflows the metric
    // box (bold-glyph overshoot, brace SVG, deep \cfrac denominators) is not
    // clipped by a parent. Mirrors the SVG serializer's content pad.
    final size = boxSizePxPadded(box, fontSizePx);
    return SizedBox.fromSize(
      size: size,
      child: CustomPaint(
        size: size,
        painter: KatexBoxPainter(
          box,
          fontSize: fontSizePx,
          color: baseColor,
          inkPadEm: kInkOverflowPadEm,
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    if (onError != null) {
      return onError!(context, error);
    }
    return Text(
      tex,
      style: const TextStyle(color: _errorColor),
    );
  }

  /// Converts a Flutter [Color] to the `#rrggbb` CSS string [KatexOptions]
  /// expects, or `null` when no color is set (so the box tree inherits the
  /// painter's base color instead).
  static String? _toCssColor(Color? color) {
    if (color == null) {
      return null;
    }
    final argb = color.toARGB32();
    final rgb = argb & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }
}
