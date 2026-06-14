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
    super.key,
  });

  final String tex;
  final bool displayMode;

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: Colors.transparent),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        // Horizontal scroll for wide math; vertical never scrolls/clips because
        // the host view is sized to the full math height + depth (see the
        // `.flutter-cell` / editor-cell CSS, which lets the cell grow to its
        // content rather than clamping it). Padding keeps descenders/denominators
        // off the clip edge.
        body: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            // Horizontal padding only — the host is sized to the math's full
            // height (see math_metrics.mathCellHeightPx), so vertical padding
            // would push the centred math past the view and clip it.
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
          ),
        ),
      ),
    );
  }
}
