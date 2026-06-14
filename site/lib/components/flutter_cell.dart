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

import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_flutter_embed/jaspr_flutter_embed.dart';

import 'math_cell_builder.dart';

@client
class FlutterCell extends StatefulComponent {
  const FlutterCell({
    required this.tex,
    required this.displayMode,
    required this.heightPx,
    super.key,
  });

  final String tex;
  final bool displayMode;

  /// The math's full height+depth in px (see `math_metrics.mathCellHeightPx`).
  /// Pins the embed view height AND is passed to [MathCell] as the explicit
  /// content height.
  final int heightPx;

  @override
  State<FlutterCell> createState() => _FlutterCellState();
}

class _FlutterCellState extends State<FlutterCell> {
  /// Whether the embedded Flutter view has been mounted yet.
  ///
  /// `jaspr_flutter_embed` measures the host element's height *once*, when the
  /// view is registered (in the embed's `initState` post-frame), and pins the
  /// view's physical render size to it forever. If the view mounts during the
  /// initial page paint — when the comparison row is still at its 72 px
  /// min-height because the sibling KaTeX-JS / SVG cells haven't rendered yet —
  /// the Flutter scene is pinned to 72 px and tall `\cfrac` chains are clipped.
  ///
  /// So we delay mounting the embed by a short interval, by which point the row
  /// (and therefore the embed host, pinned below to `height: heightPx`) has its
  /// final, full-math height — so the view's physical size is measured correctly
  /// and the whole expression is painted.
  bool _mounted = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Delay the embed mount until the row has settled (the sibling JS/SVG
      // cells have rendered and grown the grid row), so the embed measures the
      // host at its real, full-math height rather than the initial 72 px row
      // min-height.
      Timer(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        setState(() => _mounted = true);
      });
    }
  }

  @override
  Component build(BuildContext context) {
    // Outer div fills the grid-stretched cell and flex-centers the fixed-height
    // embed inside it, so the math lines up vertically with the JS/SVG columns
    // (the embedded view itself is pinned to the math's full height, below).
    return div(
      styles: Styles(
        height: 100.percent,
        display: Display.flex,
        alignItems: AlignItems.center,
        justifyContent: JustifyContent.center,
      ),
      [
        if (_mounted)
          // The view is PINNED to the math's full height (min == max) with an
          // explicit matching host `height`. That fixed, definite height is
          // what the embed measures for the view's physical render size — so
          // the whole expression (deep `\cfrac` denominators) is painted and
          // nothing is bottom-clipped. The surrounding flex container centers
          // this pinned box within the (taller) cell.
          FlutterEmbedView(
            constraints: ViewConstraints(
              minHeight: component.heightPx.toDouble(),
              maxHeight: component.heightPx.toDouble(),
            ),
            styles: Styles(height: component.heightPx.px, width: 100.percent),
            widget: mathCellWidget(
              component.tex,
              displayMode: component.displayMode,
              heightPx: component.heightPx,
            ),
            loader: div(classes: 'flutter-loading', const []),
          )
        else
          div(classes: 'flutter-loading', const []),
      ],
    );
  }
}
