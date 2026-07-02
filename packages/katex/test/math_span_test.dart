import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katex/katex.dart';

void main() {
  testWidgets('mathSpan renders inline in Text.rich without error', (t) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: Text.rich(
      TextSpan(children: [
        const TextSpan(text: 'before '),
        mathSpan(r'\frac{a}{b}'),
        const TextSpan(text: ' after '),
        mathSpan('x^2'),
      ]),
    )))));
    expect(t.takeException(), isNull);
    expect(find.byType(RichText), findsWidgets);
  });
  testWidgets('mathSpan on invalid tex falls back, no throw', (t) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: Text.rich(
      TextSpan(children: [mathSpan(r'\frac{a}')]),
    ))));
    expect(t.takeException(), isNull);
  });
}
