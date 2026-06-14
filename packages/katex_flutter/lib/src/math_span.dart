/// Inline LaTeX math for Flutter rich text.
///
/// [mathSpan] returns an [InlineSpan] you drop into a `Text.rich` / `RichText`
/// alongside ordinary [TextSpan]s, so math sits **inline** in a paragraph and
/// is **baseline-aligned** with the surrounding text (the math baseline lands
/// on the text baseline, like inline `$...$` in LaTeX).
///
/// ```dart
/// Text.rich(TextSpan(children: [
///   const TextSpan(text: 'The quadratic formula '),
///   mathSpan(r'x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}', fontSize: 16),
///   const TextSpan(text: ' solves '),
///   mathSpan(r'ax^2 + bx + c = 0', fontSize: 16),
///   const TextSpan(text: '.'),
/// ]));
/// ```
///
/// It paints the same box tree as the `Math` widget (via `KatexBoxPainter`);
/// the only addition is that the inline render reports its alphabetic baseline
/// so `WidgetSpan(alignment: PlaceholderAlignment.baseline)` sits it on the
/// line.
library;

import 'package:flutter/widgets.dart';
import 'package:katex/katex.dart';
import 'package:katex_flutter/src/render/box_painter.dart';

/// An inline math [InlineSpan] for use inside `Text.rich` / `RichText`.
///
/// [fontSize] is the px-per-em of the math; match it to the surrounding text's
/// `fontSize` so the math scales with the paragraph. [color] defaults to the
/// ambient text color (via `DefaultTextStyle`) when null.
///
/// On a parse error: if [onError] is given its result is returned; otherwise
/// the raw [tex] is returned as a red [TextSpan] (the paragraph never throws).
InlineSpan mathSpan(
  String tex, {
  bool displayMode = false,
  double fontSize = 16,
  Color? color,
  InlineSpan Function(Object error)? onError,
}) {
  final BoxNode box;
  try {
    box = renderToBox(tex, options: KatexOptions(displayMode: displayMode));
  } on Object catch (e) {
    if (onError != null) return onError(e);
    return TextSpan(
      text: tex,
      style: const TextStyle(color: Color(0xFFCC0000)),
    );
  }
  return WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: _InlineMath(box: box, fontSize: fontSize, color: color),
  );
}

/// A leaf render widget that paints a [BoxNode] and reports its alphabetic
/// baseline, so it can be baseline-aligned inside a [WidgetSpan].
class _InlineMath extends LeafRenderObjectWidget {
  const _InlineMath({
    required this.box,
    required this.fontSize,
    required this.color,
  });

  final BoxNode box;
  final double fontSize;
  final Color? color;

  Color _resolve(BuildContext context) =>
      color ??
      DefaultTextStyle.of(context).style.color ??
      const Color(0xFF000000);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderInlineMath(box, fontSize, _resolve(context));

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderInlineMath renderObject,
  ) {
    renderObject
      ..box = box
      ..fontSize = fontSize
      ..color = _resolve(context);
  }
}

class _RenderInlineMath extends RenderBox {
  _RenderInlineMath(this._box, this._fontSize, this._color);

  BoxNode _box;
  BoxNode get box => _box;
  set box(BoxNode v) {
    if (identical(v, _box)) return;
    _box = v;
    markNeedsLayout();
  }

  double _fontSize;
  double get fontSize => _fontSize;
  set fontSize(double v) {
    if (v == _fontSize) return;
    _fontSize = v;
    markNeedsLayout();
  }

  Color _color;
  Color get color => _color;
  set color(Color v) {
    if (v == _color) return;
    _color = v;
    markNeedsPaint();
  }

  Size _measure() => boxSizePx(_box, _fontSize);

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(_measure());

  @override
  void performLayout() {
    size = constraints.constrain(_measure());
  }

  // The math baseline sits `height * fontSize` below the top of the box (depth
  // is the part below the baseline). This lets inline math rest on the
  // surrounding text's baseline.
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      _box.height * _fontSize;

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas
      ..save()
      ..translate(offset.dx, offset.dy);
    KatexBoxPainter(_box, fontSize: _fontSize, color: _color)
        .paint(context.canvas, size);
    context.canvas.restore();
  }
}
