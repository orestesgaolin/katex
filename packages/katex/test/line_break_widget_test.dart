import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katex/katex.dart';

// Long enough that it cannot fit a phone-width column at the default 20 px/em,
// and made entirely of top-level break opportunities.
const String longTex = 'a + b + c + d + e + f + g + h = i + j + k + l + m + n';

// Pumps [child] under a loose `maxWidth: width` constraint — the shape a real
// column/card imposes, and one the child may under-fill. (A tight
// `SizedBox(width:)` would clamp the result and hide whether the math actually
// fit or merely got cut off at the parent's edge.)
Future<Size> pumpInWidth(
  WidgetTester tester,
  Widget child, {
  required double width,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: child,
        ),
      ),
    ),
  );
  return tester.getSize(find.byType(Math));
}

// The horizontally-unbounded, single-line size of [child] — a horizontal
// scroll view or an unconstrained Row. Vertical constraints stay loose so the
// measured height is the math's own, not the viewport's.
Future<Size> pumpUnbounded(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: UnconstrainedBox(
          constrainedAxis: Axis.vertical,
          child: child,
        ),
      ),
    ),
  );
  return tester.getSize(find.byType(Math));
}

void main() {
  testWidgets('does not wrap by default — one long line', (tester) async {
    final unbounded = await pumpUnbounded(tester, const Math(longTex));
    final constrained = await pumpInWidth(
      tester,
      const Math(longTex),
      width: 200,
    );

    expect(tester.takeException(), isNull);
    // Same height as with all the room in the world: it never broke, it just
    // ran past its 200px parent. That is KaTeX's own behaviour.
    expect(constrained.height, unbounded.height);
    expect(unbounded.width, greaterThan(200));
  });

  testWidgets('softWrap fits the incoming constraint', (tester) async {
    final unwrapped = await pumpInWidth(
      tester,
      const Math(longTex),
      width: 200,
    );
    final wrapped = await pumpInWidth(
      tester,
      const Math(longTex, softWrap: true),
      width: 200,
    );

    expect(tester.takeException(), isNull);
    expect(wrapped.width, lessThanOrEqualTo(200));
    expect(wrapped.height, greaterThan(unwrapped.height));
  });

  testWidgets('a narrower constraint yields a taller widget', (tester) async {
    final wide = await pumpInWidth(
      tester,
      const Math(longTex, softWrap: true),
      width: 400,
    );
    final narrow = await pumpInWidth(
      tester,
      const Math(longTex, softWrap: true),
      width: 150,
    );

    expect(narrow.width, lessThanOrEqualTo(150));
    expect(narrow.height, greaterThan(wide.height));
  });

  testWidgets('explicit maxWidth wraps without a bounded parent', (tester) async {
    // A horizontally-unbounded parent: softWrap alone would have nothing to
    // wrap to, but an explicit pixel budget still applies.
    final size = await pumpUnbounded(tester, const Math(longTex, maxWidth: 200));

    expect(tester.takeException(), isNull);
    expect(size.width, lessThanOrEqualTo(200));
  });

  testWidgets('maxWidth takes precedence over the constraint', (tester) async {
    final size = await pumpInWidth(
      tester,
      const Math(longTex, softWrap: true, maxWidth: 150),
      width: 600,
    );

    expect(size.width, lessThanOrEqualTo(150));
  });

  testWidgets('softWrap under unbounded width stays on one line', (tester) async {
    final wrapped = await pumpUnbounded(
      tester,
      const Math(longTex, softWrap: true),
    );
    final unwrapped = await pumpUnbounded(tester, const Math(longTex));

    expect(tester.takeException(), isNull);
    expect(wrapped, unwrapped);
  });

  testWidgets('wrapping scales with fontSize', (tester) async {
    final small = await pumpInWidth(
      tester,
      const Math(longTex, softWrap: true, fontSize: 12),
      width: 200,
    );
    final large = await pumpInWidth(
      tester,
      const Math(longTex, softWrap: true, fontSize: 30),
      width: 200,
    );

    // Bigger glyphs, same budget → more lines, so more height.
    expect(small.width, lessThanOrEqualTo(200));
    expect(large.width, lessThanOrEqualTo(200));
    expect(large.height, greaterThan(small.height));
  });

  testWidgets('a short expression is unaffected by softWrap', (tester) async {
    final plain = await pumpInWidth(
      tester,
      const Math(r'\frac{a}{b}'),
      width: 300,
    );
    final wrapped = await pumpInWidth(
      tester,
      const Math(r'\frac{a}{b}', softWrap: true),
      width: 300,
    );

    expect(wrapped, plain);
  });

  testWidgets('an unbreakable expression still overflows', (tester) async {
    // Nothing inside a fraction is a legal break point, so a squeeze has to
    // overflow rather than cut: the height must stay that of a single line.
    const frac = Math(
      r'\frac{abcdefghijklmnop}{qrstuvwxyzabcdefg}',
      softWrap: true,
    );
    final unbounded = await pumpUnbounded(tester, frac);
    final squeezed = await pumpInWidth(tester, frac, width: 60);

    expect(tester.takeException(), isNull);
    expect(unbounded.width, greaterThan(60));
    expect(squeezed.height, unbounded.height);
  });

  testWidgets('a degenerate (zero) constraint does not explode', (tester) async {
    await pumpInWidth(tester, const Math(longTex, softWrap: true), width: 0);

    expect(tester.takeException(), isNull);
  });
}
