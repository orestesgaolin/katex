/// Shared sizing for the `katex_flutter` cells.
///
/// The embedded Flutter view is sized to its DOM host's box (which a
/// `height:100%` chain resolves against the grid-stretched cell). CanvasKit
/// clips painting to that surface, so if the host is shorter than the rendered
/// math the bottom (descenders / fraction denominators) is cut off — DOM
/// `overflow:visible` does NOT help, because the clip is inside the view canvas.
///
/// Fix: floor each Flutter cell's height to the math's FULL pixel height
/// (height + depth) via [mathCellHeightPx]. That grows the grid row, so the
/// stretched cell — and the view — is tall enough to paint the whole expression.
library;

import 'package:katex/katex.dart';

/// Logical px per em — must match `MathCell._kEmPx` (the KaTeX-JS scale,
/// `1.21em × 16px` browser default).
const double kMathEmPx = 1.21 * 16;

/// Minimum cell height (px). Keep in sync with `comparison_row.kRowMinHeight`.
const int kMathCellMinHeight = 72;

/// The full pixel height a Flutter `Math` render of [tex] needs (height + depth
/// at [kMathEmPx]), floored to [kMathCellMinHeight], plus a few px of slack for
/// anti-aliasing / centering. Falls back to the floor on a parse error.
int mathCellHeightPx(String tex, {required bool displayMode}) {
  try {
    final box = renderToBox(tex, options: KatexOptions(displayMode: displayMode));
    final px = ((box.height + box.depth) * kMathEmPx).ceil() + 12;
    return px < kMathCellMinHeight ? kMathCellMinHeight : px;
  } on Object catch (_) {
    return kMathCellMinHeight;
  }
}
