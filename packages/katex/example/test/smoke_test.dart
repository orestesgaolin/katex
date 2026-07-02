// Smoke test for the example gallery app: it must pump the full gallery
// without throwing, and render a Math widget per entry.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katex/katex.dart';
import 'package:katex_example/main.dart';

void main() {
  testWidgets('gallery app pumps without throwing', (tester) async {
    await tester.pumpWidget(const KatexGalleryApp());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(GalleryPage), findsOneWidget);
    // At least the first (above-the-fold) gallery entries render a Math widget.
    expect(find.byType(Math), findsWidgets);
  });

  testWidgets('scrolling through the whole gallery never throws',
      (tester) async {
    await tester.pumpWidget(const KatexGalleryApp());
    await tester.pump();

    final listFinder = find.byType(Scrollable).first;
    for (var i = 0; i < kGallery.length; i++) {
      await tester.drag(listFinder, const Offset(0, -400));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'scroll step $i');
    }
  });
}
