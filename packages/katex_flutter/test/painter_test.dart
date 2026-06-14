import 'dart:ui' as ui;

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
