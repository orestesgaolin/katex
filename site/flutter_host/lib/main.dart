/// Flutter-web host for ONE comparison cell (T-024 / T-029).
///
/// Each comparison row in the Jaspr site embeds this app in its own
/// `<iframe src="flutter/index.html?tex=...&display=...&fontSize=...">`. The app
/// reads those query parameters and renders a SINGLE centered `Math` widget for
/// that expression.
///
/// Why one expression per iframe (single-view), not one multi-view engine for
/// the whole page:
///  * CanvasKit **multi-view** drops a class of math glyphs (KaTeX_Size symbols
///    like `\oint`/`\bigcup`, `\cdot` U+22C5, the angle/ceil/floor delimiters)
///    as missing-glyph boxes — a per-view font-atlas bug. A single-view engine
///    renders every glyph correctly.
///  * One full-height iframe rendering the whole gallery drifts out of vertical
///    alignment with the DOM list (independent layout engines). A per-row iframe
///    IS its grid cell, so it lines up by construction.
/// Lazy-loaded (`loading="lazy"`) so only near-viewport engines instantiate.
library;

import 'package:flutter/material.dart';
import 'package:katex_flutter/katex_flutter.dart';

void main() {
  final params = Uri.base.queryParameters;
  final tex = params['tex'] ?? '';
  final displayMode = params['display'] == 'true' || params['display'] == '1';
  final fontSize = double.tryParse(params['fontSize'] ?? '') ?? 22.0;
  runApp(CellApp(tex: tex, displayMode: displayMode, fontSize: fontSize));
}

class CellApp extends StatelessWidget {
  const CellApp({
    required this.tex,
    required this.displayMode,
    required this.fontSize,
    super.key,
  });

  final String tex;
  final bool displayMode;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: Colors.transparent),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: tex.isEmpty
                ? const SizedBox.shrink()
                : Math(
                    tex,
                    displayMode: displayMode,
                    fontSize: fontSize,
                    onError: (BuildContext context, Object error) => Text(
                      'error: $error',
                      style: const TextStyle(
                        color: Color(0xFFCC0000),
                        fontSize: 11,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
