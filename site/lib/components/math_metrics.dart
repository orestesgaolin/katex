/// Shared sizing for the `katex_flutter` cells.
///
/// The embedded Flutter view paints into a CanvasKit surface whose height is
/// driven by the *content* Flutter lays out, anchored at the top of the view.
/// `jaspr_flutter_embed` does NOT reliably grow that surface to a fixed
/// `ViewConstraints` `maxHeight`; instead the painted scene was clamped to the
/// host's initial min-height (`kRowMinHeight`, 72 px) — so tall `\cfrac` chains
/// were cut off at the bottom and the math sat at the top of the row.
///
/// Fix: drive sizing from the WIDGET side. [MathCell] is handed [mathCellHeightPx]
/// and lays out an explicit `SizedBox(height: …)` that centers the math, so the
/// CanvasKit scene is painted at the FULL math height (no bottom clip) and the
/// math is vertically centered inside it. The same value is used as the embed
/// view's `minHeight` so the grid row is never shorter than the math.
library;

import 'package:katex/katex.dart';

/// Logical px per em — must match `MathCell._kEmPx` (the KaTeX-JS scale,
/// `1.21em × 16px` browser default).
const double kMathEmPx = 1.21 * 16;

/// Minimum cell height (px). Keep in sync with `comparison_row.kRowMinHeight`.
const int kMathCellMinHeight = 72;

/// The full pixel height a Flutter `Math` render of [tex] needs (height + depth
/// at [kMathEmPx]), floored to [kMathCellMinHeight], plus a few px of slack for
/// anti-aliasing ink overflow / centering. Falls back to the floor on a parse
/// error.
///
/// This is used two ways (see [MathCell] / `FlutterCell`):
///  * as the embed view's `minHeight` (so the grid row grows tall enough), and
///  * as the explicit content height [MathCell] lays the centered math out in,
///    which is what actually sizes the painted CanvasKit scene.
int mathCellHeightPx(String tex, {required bool displayMode}) {
  try {
    final box = renderToBox(tex, options: KatexOptions(displayMode: displayMode));
    // +12 px of slack: a little extra above/below for glyph ink that paints
    // marginally past the (height + depth) box and to keep the math off the
    // clip edge when centered.
    final px = ((box.height + box.depth) * kMathEmPx).ceil() + 12;
    return px < kMathCellMinHeight ? kMathCellMinHeight : px;
  } on Object catch (_) {
    return kMathCellMinHeight;
  }
}
