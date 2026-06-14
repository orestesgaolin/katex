/// The Flutter widget embedded in each comparison row's `katex_flutter` cell.
///
/// Rendered by `jaspr_flutter_embed` (one engine, one view per cell) — see
/// `lib/components/flutter_cell.dart`. Imported web-only via `@Import.onWeb`, so
/// this file (and its `package:flutter` imports) never compile on the server.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:katex/katex.dart';
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
    //
    // The math goes through [_OversampledMath], which paints the box tree at a
    // higher resolution and draws it back down to the 1× display size — see
    // that widget for why this is needed for the embedded CanvasKit column.
    final Widget math = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: _OversampledMath(
        tex: tex,
        displayMode: displayMode,
        fontSize: _kEmPx,
      ),
    );

    // Vertical centering + clip-free painting:
    //
    // The embedded `FlutterEmbedView` pins this Flutter view's physical render
    // size (and therefore its CanvasKit canvas) to `heightPx` (the math's full
    // height + depth + slack). The math must be centred within *that pinned
    // extent*. We must NOT centre within the ambient `MediaQuery`: in the
    // CanvasKit multi-view embed the MediaQuery / Scaffold-body height can lag
    // or exceed the pinned canvas height, and centring a fixed `SizedBox` inside
    // that wrong extent pushed the math down and clipped tall `\cfrac`
    // denominators at the bottom of the canvas.
    //
    // So we impose the height ourselves, independent of the incoming
    // constraints: a top-aligned `OverflowBox` (no max-height constraint) holds
    // a `SizedBox(height: heightPx)` that centres the math. Anchored to the top
    // of the view, the box coincides exactly with the pinned `heightPx` canvas —
    // the whole expression is painted and centred within it, never clipped.
    final Widget body = heightPx > 0
        ? Align(
            alignment: Alignment.topCenter,
            child: OverflowBox(
              minHeight: heightPx.toDouble(),
              maxHeight: heightPx.toDouble(),
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: heightPx.toDouble(),
                child: Center(child: math),
              ),
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

/// Renders [tex] at a high internal resolution and draws it back down to the
/// requested 1× display size, so the embedded CanvasKit column stays crisp.
///
/// ## Why this exists
/// The comparison site runs at `devicePixelRatio == 1`. The KaTeX-JS (DOM) and
/// Dart-SVG (vector `<svg>`) columns stay razor-sharp because the browser
/// rasterises them natively at the screen's true pixel density. The Flutter
/// column goes through CanvasKit/WebGL, which rasterises glyphs at
/// `fontSize × view-devicePixelRatio` (== 1 here) and then composites. At the
/// small KaTeX scale (~19 px/em) the hairline strokes of script-size glyphs
/// (e.g. the two primes of `f''`) come out as faint light-grey anti-aliasing —
/// so `f''` collapses to read as `f'`, and the whole column looks grey rather
/// than black. (Measured: the SVG column reaches pure black with ~30% more ink
/// pixels; the live CanvasKit column never gets below ~grey-28 and drops the
/// second prime.)
///
/// Flutter transforms (`FittedBox`/`Transform.scale`) do **not** help: CanvasKit
/// folds the transform into the effective rasterisation scale, so a 3×-font
/// glyph drawn under a ⅓ scale still rasterises at the same final pixel size.
///
/// The fix that *does* work is to rasterise into an offscreen [ui.Image] at
/// [oversample]× the device pixel ratio (a real, higher-resolution bitmap), then
/// draw that texture down to the display size with high-quality filtering. The
/// down-sampled high-res texture renders dark and crisp, matching the SVG
/// column. The image is rebuilt only when the inputs change.
class _OversampledMath extends StatefulWidget {
  const _OversampledMath({
    required this.tex,
    required this.displayMode,
    required this.fontSize,
  });

  final String tex;
  final bool displayMode;

  /// Logical pixels per em for the *displayed* (1×) size.
  final double fontSize;

  /// How many device pixels to render per logical pixel before down-sampling.
  ///
  /// 4× both darkens the strokes to solid black and preserves the ~1.6 px gap
  /// between the two script-size primes of `f''` (which a 1× CanvasKit raster
  /// smears into a single mark).
  static const double oversample = 4;

  @override
  State<_OversampledMath> createState() => _OversampledMathState();
}

class _OversampledMathState extends State<_OversampledMath> {
  ui.Image? _image;
  Size _displaySize = Size.zero;
  Object? _error;

  @override
  void initState() {
    super.initState();
    // `toImageSync` is synchronous, so the offscreen bitmap is ready before the
    // first build — update the fields directly here (a `setState` is illegal in
    // `initState`); later input changes go through `setState` via `_render`.
    _renderInto();
  }

  @override
  void didUpdateWidget(_OversampledMath old) {
    super.didUpdateWidget(old);
    if (old.tex != widget.tex ||
        old.displayMode != widget.displayMode ||
        old.fontSize != widget.fontSize) {
      _render();
    }
  }

  /// Re-rasterises and triggers a rebuild (for input changes after mount).
  void _render() => setState(_renderInto);

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  /// Rasterises the math into [_image] (updating fields in place — the caller
  /// wraps this in `setState` when a rebuild is needed).
  void _renderInto() {
    final BoxNode box;
    try {
      box = renderToBox(
        widget.tex,
        options: KatexOptions(displayMode: widget.displayMode),
      );
    } on Object catch (e) {
      _error = e;
      _image?.dispose();
      _image = null;
      return;
    }

    // 1× display extent (matches the JS/SVG columns).
    final display = boxSizePx(box, widget.fontSize);
    if (display.width <= 0 || display.height <= 0) {
      _error = null;
      _image?.dispose();
      _image = null;
      _displaySize = Size.zero;
      return;
    }

    // Paint the box tree at oversample× the scale into an offscreen picture,
    // then rasterise to a real high-resolution bitmap.
    final scale = _OversampledMath.oversample;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    KatexBoxPainter(
      box,
      fontSize: widget.fontSize * scale,
      color: const Color(0xFF000000),
    ).paint(canvas, boxSizePx(box, widget.fontSize * scale));
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      (display.width * scale).ceil(),
      (display.height * scale).ceil(),
    );
    picture.dispose();

    _error = null;
    _image?.dispose();
    _image = image;
    _displaySize = display;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Text(
        'error: $_error',
        style: const TextStyle(color: Color(0xFFCC0000), fontSize: 11),
      );
    }
    final image = _image;
    if (image == null) {
      // Until the offscreen raster is ready, fall back to a direct paint so the
      // cell is never blank (and the editor's live updates feel instant).
      return Math(
        widget.tex,
        displayMode: widget.displayMode,
        fontSize: widget.fontSize,
      );
    }
    return SizedBox(
      width: _displaySize.width,
      height: _displaySize.height,
      child: RawImage(
        image: image,
        width: _displaySize.width,
        height: _displaySize.height,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
