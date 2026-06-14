import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katex/katex.dart';
import 'package:katex_flutter/katex_flutter.dart';

void main() {
  testWidgets('renders valid inline TeX without error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Math(r'\frac{a}{b}')),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Math), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('renders valid TeX in display mode', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Math(r'\frac{a}{b}', displayMode: true)),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Math), findsOneWidget);
  });

  testWidgets('rendered CustomPaint has non-zero size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: Math(r'\frac{a}{b}')),
      ),
    );

    final size = tester.getSize(find.byType(Math));
    expect(size.width, greaterThan(0));
    expect(size.height, greaterThan(0));
  });

  testWidgets('honors explicit fontSize for sizing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: Math(r'\frac{a}{b}', fontSize: 40)),
      ),
    );

    final big = tester.getSize(find.byType(Math));

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: Math(r'\frac{a}{b}', fontSize: 20)),
      ),
    );

    final small = tester.getSize(find.byType(Math));
    expect(big.width, greaterThan(small.width));
    expect(big.height, greaterThan(small.height));
  });

  testWidgets('invokes onError builder for invalid TeX when not throwing',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Math(
          r'\frac{a}{',
          onError: (context, error) => const Text('error-fallback'),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('error-fallback'), findsOneWidget);
  });

  testWidgets('shows default fallback for invalid TeX without onError',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Math(r'\frac{a}{')),
    );

    expect(tester.takeException(), isNull);
    // Default fallback renders the raw source.
    expect(find.text(r'\frac{a}{'), findsOneWidget);
  });

  testWidgets('rethrows for invalid TeX when throwOnError is true',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Math(r'\frac{a}{', throwOnError: true)),
    );

    expect(tester.takeException(), isA<ParseError>());
  });
}
