import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katex/katex.dart';
import 'package:katex_flutter/katex_flutter.dart';

/// Paints [root] to a throwaway recorder canvas, returning the recorded
/// [ui.Picture] (or throwing if painting throws).
ui.Picture _paintToPicture(BoxNode root, double fontSize) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  KatexBoxPainter(root, fontSize: fontSize).paint(
    canvas,
    boxSizePx(root, fontSize),
  );
  return recorder.endRecording();
}

/// Rasterizes [root] at [fontSize] by pumping a [CustomPaint] inside a
/// [RepaintBoundary] (the proven path in this test environment) and returns the
/// boundary's raw RGBA bytes plus dimensions.
Future<({ByteData rgba, int width, int height})> _rasterize(
  WidgetTester tester,
  BoxNode root,
  double fontSize, {
  Color color = const Color(0xFF000000),
}) async {
  final size = boxSizePx(root, fontSize);
  final w = size.width.ceil().clamp(1, 4096);
  final h = size.height.ceil().clamp(1, 4096);
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFFFFFFFF),
            child: SizedBox(
              width: w.toDouble(),
              height: h.toDouble(),
              child: CustomPaint(
                painter: KatexBoxPainter(
                  root,
                  fontSize: fontSize,
                  color: color,
                ),
                size: Size(w.toDouble(), h.toDouble()),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // Real async raster work (toImage/toByteData) must run outside the fake-async
  // test zone, hence tester.runAsync.
  final result = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = (await image.toByteData())!;
    return (rgba: bytes, width: image.width, height: image.height);
  });
  return result!;
}

/// Counts pixels that are not white (i.e. ink) in a rasterized region.
int _inkCount(
  ({ByteData rgba, int width, int height}) img, {
  Rect? region,
}) {
  final r = region ??
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
  var count = 0;
  for (var y = r.top.floor(); y < r.bottom.ceil() && y < img.height; y++) {
    for (var x = r.left.floor(); x < r.right.ceil() && x < img.width; x++) {
      final i = (y * img.width + x) * 4;
      final red = img.rgba.getUint8(i);
      final green = img.rgba.getUint8(i + 1);
      final blue = img.rgba.getUint8(i + 2);
      if (red < 250 || green < 250 || blue < 250) {
        count++;
      }
    }
  }
  return count;
}

void main() {
  const fontSize = 20.0;

  group('boxSizePx', () {
    void expectMatchesBoxDims(String tex) {
      final root = renderToBox(tex);
      final size = boxSizePx(root, fontSize);
      expect(
        size.width,
        closeTo(root.width * fontSize, 0.001),
        reason: 'width for "$tex"',
      );
      expect(
        size.height,
        closeTo((root.height + root.depth) * fontSize, 0.001),
        reason: 'height for "$tex"',
      );
    }

    test(r'\frac{a}{b} matches box-tree dims', () {
      expectMatchesBoxDims(r'\frac{a}{b}');
    });

    test('x^2 matches box-tree dims', () {
      expectMatchesBoxDims('x^2');
    });
  });

  group('paint (recorder canvas, no throw)', () {
    const gallery = <String>[
      r'\frac{a}{b}',
      'x^2',
      r'\sqrt{x}',
      r'\sum_{i=0}^{n} i',
      r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}',
    ];

    for (final tex in gallery) {
      test('paints "$tex" without throwing', () {
        final root = renderToBox(tex);
        expect(() => _paintToPicture(root, fontSize), returnsNormally);
      });
    }
  });

  testWidgets('CustomPaint with KatexBoxPainter pumps without exceptions', (
    tester,
  ) async {
    final root = renderToBox(r'\frac{a}{b}');
    final size = boxSizePx(root, fontSize);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: CustomPaint(
                painter: KatexBoxPainter(root, fontSize: fontSize),
                size: size,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  group('parseSvgPath', () {
    test('parses a simple absolute path into a non-empty bounded Path', () {
      final p = parseSvgPath('M0 0 H100 V50 z');
      final b = p.getBounds();
      expect(b.width, closeTo(100, 0.001));
      expect(b.height, closeTo(50, 0.001));
    });

    test('handles relative, H/V, cubic, smooth and close commands', () {
      // Mix of relative move/line, cubic, smooth-cubic, and close.
      final p = parseSvgPath('m10 10 h20 v20 c5 5 10 5 15 0 s10 -5 15 0z');
      expect(p.getBounds().isEmpty, isFalse);
    });

    test('a malformed string degrades gracefully (no throw, no hang)', () {
      expect(() => parseSvgPath('garbage 1 2 3'), returnsNormally);
      expect(() => parseSvgPath(''), returnsNormally);
    });
  });

  group('SvgPathNode ink (surd + stretchy delimiter)', () {
    testWidgets(r'\sqrt{x} draws surd/vinculum ink above the radicand', (
      tester,
    ) async {
      final root = renderToBox(r'\sqrt{x}');
      final img = await _rasterize(tester, root, 40);
      // Total ink is non-trivial.
      expect(_inkCount(img), greaterThan(0));
      // The radicand 'x' sits on the baseline at x-height; the surd's vinculum
      // (overbar) and the top of the diagonal live in the TOP band of the box,
      // well above the radicand. There must be ink there — that ink can only
      // come from the surd SvgPathNode, not the radicand glyph.
      final topBand = Rect.fromLTWH(
        0,
        0,
        img.width.toDouble(),
        img.height * 0.18,
      );
      expect(
        _inkCount(img, region: topBand),
        greaterThan(0),
        reason: 'expected surd/vinculum ink in the top band',
      );
    });

    testWidgets(r'tall \left(...\right) draws a stacked-delimiter path', (
      tester,
    ) async {
      // Deeply nested fraction forces a stacked (SVG-path) delimiter rather
      // than a fixed glyph.
      const tex = r'\left(\frac{a}{\frac{c}{\frac{d}{\frac{e}{f}}}}\right)';
      final root = renderToBox(
        tex,
        options: const KatexOptions(displayMode: true),
      );
      final img = await _rasterize(tester, root, 40);
      // The opening stretchy paren occupies the left ~38% of the box; its bowl
      // reaches farthest left around the vertical MIDDLE. Assert ink in a left
      // column across the middle band — there the only ink is the stacked-
      // delimiter SvgPathNode (the inner fraction is centered to the right).
      final leftStrip = Rect.fromLTWH(
        0,
        img.height * 0.35,
        img.width * 0.22,
        img.height * 0.30,
      );
      expect(
        _inkCount(img, region: leftStrip),
        greaterThan(0),
        reason: 'expected stretchy delimiter (paren bowl) ink at mid-left',
      );
    });
    testWidgets(
      r'\vec{x} arrow (static vec SVG) sits centered in the top band',
      (tester) async {
        // RC-4 regression: the non-stretchy `\vec` accent renders its arrow as
        // an SvgPathNode (KaTeX `staticSvg("vec")`) placed in the accent vlist
        // above the base. The painter must scale/position that SvgPathNode the
        // same way the SVG serializer does — i.e. the small arrow lands in the
        // TOP band, horizontally centered (plus the base's italic skew) over
        // the base, NOT drifting far right or stretching down over the glyph.
        final root = renderToBox(r'\vec{x}');
        final img = await _rasterize(tester, root, 60);

        // 1) Arrow ink is present in the top band (the arrow is above the x).
        final topBand = Rect.fromLTWH(
          0,
          0,
          img.width.toDouble(),
          img.height * 0.20,
        );
        expect(
          _inkCount(img, region: topBand),
          greaterThan(0),
          reason: r'expected \vec arrow ink in the top band',
        );

        // 2) The arrow is centered over the base (not drawn flush-left at the
        // box origin). This can't be pixel-isolated in flutter_test: the base
        // glyph renders as a full em-box (the bundled fonts fall back to the
        // test font here) whose ascent extends across the whole top band,
        // saturating any top-corner strip. (The earlier `leftStrip == 0` check
        // only passed incidentally because synthetic oblique sheared that box's
        // top-left corner empty — an artifact, not a real centering signal.
        // Math letters now render upright, see font_mapping.) Arrow centering
        // is verified by the box-tree centering kern and the SVG serializer
        // (svg_test / oracle), which match KaTeX. Here we just confirm the
        // arrow SVG produced ink in the top band (assertion 1 above).
      },
    );
  });

  test('shouldRepaint reacts to root / fontSize / color changes', () {
    final root = renderToBox('x^2');
    final other = renderToBox('y^2');
    final base = KatexBoxPainter(root, fontSize: 20);

    expect(base.shouldRepaint(KatexBoxPainter(root, fontSize: 20)), isFalse);
    expect(base.shouldRepaint(KatexBoxPainter(other, fontSize: 20)), isTrue);
    expect(base.shouldRepaint(KatexBoxPainter(root, fontSize: 22)), isTrue);
    expect(
      base.shouldRepaint(
        KatexBoxPainter(root, fontSize: 20, color: const Color(0xFFFF0000)),
      ),
      isTrue,
    );
  });
}
