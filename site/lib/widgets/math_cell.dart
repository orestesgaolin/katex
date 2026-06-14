/// The Flutter widget embedded in each comparison row's `katex_flutter` cell.
///
/// Rendered by `jaspr_flutter_embed` (one engine, one view per cell) — see
/// `lib/components/flutter_cell.dart`. Imported web-only via `@Import.onWeb`, so
/// this file (and its `package:flutter` imports) never compile on the server.
library;

import 'package:flutter/material.dart';
import 'package:katex_flutter/katex_flutter.dart';

class MathCell extends StatelessWidget {
  const MathCell({
    required this.tex,
    required this.displayMode,
    required this.heightPx,
    super.key,
  });

  final String tex;
  final bool displayMode;

  /// The math's full pixel height (height + depth + slack) — see
  /// `math_metrics.mathCellHeightPx`. The widget lays out an explicit
  /// `SizedBox` of this height so the painted CanvasKit scene is tall enough to
  /// show the whole expression (deep `\cfrac` denominators included) instead of
  /// being clamped to the embed host's 72 px min-height.
  ///
  /// `0` (the default) means "size to the math's intrinsic extent" — used by
  /// callers (e.g. the live editor) that pin the view height themselves.
  final int heightPx;

  /// Logical px per em, matched to the KaTeX-JS column.
  ///
  /// KaTeX JS renders math at `1.21em × page-font-size`; the page font-size is
  /// the browser default 16 px, so one em of math is `1.21 × 16 = 19.36 px`
  /// (see `.katex{font:normal 1.21em …}` in `katex.min.css`). `Math.fontSize`
  /// is exactly logical-px-per-em, so this makes the Flutter column render at
  /// the same scale as the JS and Dart-SVG (T-033) columns.
  static const double _kEmPx = 1.21 * 16;

  @override
  Widget build(BuildContext context) {
    // Wide math scrolls horizontally; only horizontal padding is used so
    // vertical padding never eats into the centered math.
    final Widget math = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Math(
        tex,
        displayMode: displayMode,
        fontSize: _kEmPx,
        onError: (BuildContext context, Object error) => Text(
          'error: $error',
          style: const TextStyle(color: Color(0xFFCC0000), fontSize: 11),
        ),
      ),
    );

    // Vertical centering + clip-free painting:
    //
    // When [heightPx] is given (the comparison rows), the embedded view is
    // pinned by `FlutterCell` to exactly this height (the math's full height +
    // depth). We lay the math out in an explicit-height `SizedBox(heightPx)` so
    // the content matches the view exactly (the whole expression — deep `\cfrac`
    // denominators included — is painted, not clipped), and `Center` it so it
    // sits centered within that box.
    //
    // When [heightPx] is 0 (e.g. the live editor, which pins the view height
    // itself), fall back to the math's intrinsic extent.
    final Widget body = heightPx > 0
        ? Center(
            child: SizedBox(
              height: heightPx.toDouble(),
              child: Center(child: math),
            ),
          )
        : Center(child: math);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: Colors.transparent),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: body,
      ),
    );
  }
}
