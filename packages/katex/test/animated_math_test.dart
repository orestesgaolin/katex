import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katex/katex.dart';
import 'package:katex_dart/katex_dart.dart';

/// Rasterizes [tex] painted with [mode] frozen at reveal progress [t], and
/// returns the raw RGBA bytes + dimensions (white background).
Future<({ByteData rgba, int width, int height})> _rasterizeReveal(
  WidgetTester tester,
  String tex, {
  required MathAnimationMode mode,
  required double t,
  double fontSize = 40,
}) async {
  final root = renderToBox(tex);
  final size = boxSizePxPadded(root, fontSize);
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
                  inkPadEm: kInkOverflowPadEm,
                  animationMode: mode,
                  progress: AlwaysStoppedAnimation<double>(t),
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
  final result = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = (await image.toByteData())!;
    return (rgba: bytes, width: image.width, height: image.height);
  });
  return result!;
}

/// Counts non-white (ink) pixels in [region] of a rasterized image.
int _inkCount(
  ({ByteData rgba, int width, int height}) img, {
  required Rect region,
}) {
  var count = 0;
  for (var y = region.top.floor(); y < region.bottom.ceil() && y < img.height;
      y++) {
    for (var x = region.left.floor(); x < region.right.ceil() && x < img.width;
        x++) {
      final i = (y * img.width + x) * 4;
      if (img.rgba.getUint8(i) < 250 ||
          img.rgba.getUint8(i + 1) < 250 ||
          img.rgba.getUint8(i + 2) < 250) {
        count++;
      }
    }
  }
  return count;
}

void main() {
  testWidgets('renders and runs a left-to-right reveal without error',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: AnimatedMath(r'\frac{a}{b}'))),
    );

    // Mid-animation: still painting, no exceptions.
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.byType(AnimatedMath), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    // Let the animation finish.
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports every animation mode', (tester) async {
    for (final mode in MathAnimationMode.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: AnimatedMath('E = mc^2', mode: mode)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: 'mode=$mode mid-anim');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'mode=$mode settled');
    }
  });

  testWidgets('sizes itself to the formula (non-zero)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: AnimatedMath(r'\sqrt{x}'))),
    );
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byType(AnimatedMath));
    expect(size.width, greaterThan(0));
    expect(size.height, greaterThan(0));
  });

  testWidgets('fires onCompleted when the reveal finishes', (tester) async {
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: AnimatedMath(
            'a + b',
            duration: const Duration(milliseconds: 200),
            onCompleted: () => completed++,
          ),
        ),
      ),
    );

    expect(completed, 0);
    await tester.pumpAndSettle();
    expect(completed, 1);
  });

  testWidgets('replays when tex changes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: AnimatedMath(
            'a',
            duration: Duration(milliseconds: 200),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Change the content: a new reveal should run and settle cleanly.
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: AnimatedMath(
            'b',
            duration: Duration(milliseconds: 200),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('can be driven by an external controller', (tester) async {
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 300),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: AnimatedMath('x^2', controller: controller),
        ),
      ),
    );

    // External controller starts at 0 and does not auto-play.
    expect(controller.value, 0);
    unawaited(controller.forward());
    await tester.pumpAndSettle();
    expect(controller.value, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to raw tex on invalid input', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: AnimatedMath(r'\frac{a}{'))),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text(r'\frac{a}{'), findsOneWidget);
  });

  testWidgets('rethrows invalid tex when throwOnError is true', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: AnimatedMath(r'\frac{a}{', throwOnError: true)),
      ),
    );
    expect(tester.takeException(), isA<ParseError>());
  });

  group('step pacing (stepDuration)', () {
    testWidgets('reveals one element per step, sized to element count',
        (tester) async {
      // 'a + b' → glyphs a, +, b = 3 revealable leaves.
      const tex = 'a + b';
      final n = countRevealableLeaves(renderToBox(tex));
      expect(n, 3);

      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: AnimatedMath(
              tex,
              stepDuration: Duration(seconds: 1),
            ),
          ),
        ),
      );

      // Total reveal should span N steps (3s here): not settled before then…
      await tester.pump(const Duration(milliseconds: 2500));
      expect(
        tester.hasRunningAnimations,
        isTrue,
        reason: 'a 3-element, 1s/step reveal should still be running at 2.5s',
      );
      // …and finished by N steps (+ a little slack).
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('step pacing settles cleanly for every directional mode',
        (tester) async {
      for (final mode in [
        MathAnimationMode.leftToRight,
        MathAnimationMode.rightToLeft,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: AnimatedMath(
                'x + y + z',
                mode: mode,
                stepDuration: const Duration(milliseconds: 200),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'mode=$mode');
      }
    });
  });

  group('per-element directional reveal (ink at mid-progress)', () {
    // A wide row of distinct glyphs so left/right halves hold separate ink.
    const tex = 'a + b + c + d + e + f';

    Rect leftHalf(({ByteData rgba, int width, int height}) img) =>
        Rect.fromLTWH(0, 0, img.width / 2, img.height.toDouble());
    Rect rightHalf(({ByteData rgba, int width, int height}) img) =>
        Rect.fromLTWH(img.width / 2, 0, img.width / 2, img.height.toDouble());

    testWidgets('leftToRight reveals the left side first', (tester) async {
      final img = await _rasterizeReveal(
        tester,
        tex,
        mode: MathAnimationMode.leftToRight,
        t: 0.5,
      );
      final left = _inkCount(img, region: leftHalf(img));
      final right = _inkCount(img, region: rightHalf(img));
      expect(
        left,
        greaterThan(right),
        reason: 'at t=0.5 the left half should carry more ink than the right',
      );
    });

    testWidgets('rightToLeft reveals the right side first', (tester) async {
      final img = await _rasterizeReveal(
        tester,
        tex,
        mode: MathAnimationMode.rightToLeft,
        t: 0.5,
      );
      final left = _inkCount(img, region: leftHalf(img));
      final right = _inkCount(img, region: rightHalf(img));
      expect(
        right,
        greaterThan(left),
        reason: 'at t=0.5 the right half should carry more ink than the left',
      );
    });

    testWidgets('fully revealed at t=1 matches a static render',
        (tester) async {
      final animated = await _rasterizeReveal(
        tester,
        tex,
        mode: MathAnimationMode.leftToRight,
        t: 1,
      );
      final fullRegion = Rect.fromLTWH(
        0,
        0,
        animated.width.toDouble(),
        animated.height.toDouble(),
      );
      final animatedInk = _inkCount(animated, region: fullRegion);

      final still = await _rasterizeReveal(
        tester,
        tex,
        mode: MathAnimationMode.none,
        t: 1,
      );
      final stillInk = _inkCount(still, region: fullRegion);

      // The t=1 fast path paints the tree directly, so ink should match the
      // non-animated render closely (allow a tiny rasterization tolerance).
      expect((animatedInk - stillInk).abs(), lessThan(stillInk * 0.02 + 4));
    });
  });
}
