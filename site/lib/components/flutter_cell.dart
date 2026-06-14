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
    required this.heightPx,
    super.key,
  });

  final String tex;
  final bool displayMode;

  /// Fixed view height (px) = the math's full height+depth (see
  /// `math_metrics.mathCellHeightPx`).
  final int heightPx;

  @override
  Component build(BuildContext context) {
    // An UNCONSTRAINED embedded multi-view takes a bogus default size and
    // renders its scene into a 0x0 glass-pane (→ clipped). Pinning the view
    // height via ViewConstraints makes the engine size the view + scene
    // deterministically to the math; width is left unconstrained so the host
    // column width applies (MathCell scrolls horizontally for wide math).
    return FlutterEmbedView(
      constraints: ViewConstraints(
        minHeight: heightPx.toDouble(),
        maxHeight: heightPx.toDouble(),
      ),
      widget: mathCellWidget(tex, displayMode: displayMode),
      loader: div(classes: 'flutter-loading', const []),
    );
  }
}
