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
            child: Math(
              tex,
              displayMode: displayMode,
              fontSize: 22,
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
