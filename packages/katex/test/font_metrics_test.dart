// Spot-checks that getCharacterMetrics returns the exact KaTeX values for a
// few glyphs (compared against reference/node_modules/katex/src/fontMetricsData.js).
import 'package:katex/src/font/font_metrics.dart';
import 'package:katex/src/font/font_types.dart';
import 'package:test/test.dart';

void main() {
  group('getCharacterMetrics', () {
    test("'A' in Main-Regular matches KaTeX", () {
      final m = getCharacterMetrics('A', 'Main-Regular', Mode.math);
      expect(m, isNotNull);
      expect(m!.depth, 0.0);
      expect(m.height, 0.68333);
      expect(m.italic, 0.0);
      expect(m.skew, 0.0);
      expect(m.width, 0.75);
    });

    test("'x' in Math-Italic matches KaTeX (has skew)", () {
      final m = getCharacterMetrics('x', 'Math-Italic', Mode.math);
      expect(m, isNotNull);
      expect(m!.height, 0.43056);
      expect(m.skew, 0.02778);
      expect(m.width, 0.57153);
    });

    test('unknown font throws', () {
      expect(
        () => getCharacterMetrics('A', 'No-Such-Font', Mode.math),
        throwsArgumentError,
      );
    });

    test('codepoint overload agrees with string overload', () {
      final a = getCharacterMetrics('A', 'Main-Regular', Mode.math);
      final b = getCharacterMetricsByCode(65, 'Main-Regular', Mode.math);
      expect(b, a);
    });
  });

  group('global metrics', () {
    test('axisHeight and rule thickness for textstyle', () {
      final fm = getGlobalMetrics(6); // size >= 5 => textstyle
      expect(fm.axisHeight, 0.25);
      expect(fm.defaultRuleThickness, 0.04);
      expect(fm.quad, 1.0);
    });

    test('scriptscript style uses smaller quad', () {
      final fm = getGlobalMetrics(1); // < 3 => scriptscript
      expect(fm.quad, 1.472);
    });
  });

  group('KatexFont naming', () {
    test('fontName / cssFamily / fontFileName', () {
      const f = KatexFont(KatexFontFamily.math, KatexFontVariant.italic);
      expect(f.fontName, 'Math-Italic');
      expect(f.cssFamily, 'KaTeX_Math');
      expect(f.fontFileName, 'KaTeX_Math-Italic.ttf');
    });
  });
}
