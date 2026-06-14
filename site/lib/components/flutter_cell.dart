/// Column 4 — the `katex_flutter` render, embedded via `jaspr_flutter_embed`.
///
/// A `@client` island: the server renders a host placeholder, then on the client
/// `FlutterEmbedView` mounts the [MathCell] Flutter widget into it. All cells
/// share **one** Flutter engine (one view per cell) — far lighter than one
/// CanvasKit engine per `<iframe>` (68 of which exhaust the browser's
/// WebGL-context limit and blank cells on interaction).
///
/// The widget is built via a web-only conditional import (`math_cell_builder`)
/// so the server prerender never touches `package:flutter`.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_flutter_embed/jaspr_flutter_embed.dart';

import 'math_cell_builder.dart';

@client
class FlutterCell extends StatelessComponent {
  const FlutterCell({
    required this.tex,
    required this.displayMode,
    super.key,
  });

  final String tex;
  final bool displayMode;

  @override
  Component build(BuildContext context) {
    return FlutterEmbedView(
      widget: mathCellWidget(tex, displayMode: displayMode),
      loader: div(classes: 'flutter-loading', const []),
    );
  }
}
