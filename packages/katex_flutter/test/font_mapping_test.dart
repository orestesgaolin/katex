import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katex/src/font/font_types.dart';
import 'package:katex_flutter/katex_flutter.dart';

void main() {
  group('textStyleFor', () {
    // When a `package` is supplied, the engine prefixes the resolved family
    // with `packages/<package>/`. We assert that prefixed form below; the raw
    // family selected by the mapping is `KaTeX_<Family>`.
    const prefix = 'packages/$katexFlutterPackage/';

    test('Main-Regular maps to KaTeX_Main, w400, normal', () {
      const font = KatexFont(KatexFontFamily.main, KatexFontVariant.regular);
      final style = textStyleFor(font, 20);

      expect(style.fontFamily, '${prefix}KaTeX_Main');
      expect(style.fontWeight, FontWeight.w400);
      expect(style.fontStyle, FontStyle.normal);
      expect(style.fontSize, 20);
      expect(style.height, 1.0);
      // TextStyle does not expose `package` as a getter; it is folded into the
      // resolved family. Assert equality against a style built with the package
      // to confirm the package argument is wired through.
      expect(
        style,
        const TextStyle(
          fontFamily: 'KaTeX_Main',
          package: katexFlutterPackage,
          fontWeight: FontWeight.w400,
          fontStyle: FontStyle.normal,
          fontSize: 20,
          height: 1,
        ),
      );
    });

    test('Math-Italic maps to KaTeX_Math, italic, w400', () {
      const font = KatexFont(KatexFontFamily.math, KatexFontVariant.italic);
      final style = textStyleFor(font, 16);

      expect(style.fontFamily, '${prefix}KaTeX_Math');
      expect(style.fontStyle, FontStyle.italic);
      expect(style.fontWeight, FontWeight.w400);
      expect(style.fontSize, 16);
    });

    test('Main-Bold maps to w700, normal', () {
      const font = KatexFont(KatexFontFamily.main, KatexFontVariant.bold);
      final style = textStyleFor(font, 12);

      expect(style.fontFamily, '${prefix}KaTeX_Main');
      expect(style.fontWeight, FontWeight.w700);
      expect(style.fontStyle, FontStyle.normal);
    });

    test('Main-BoldItalic maps to w700 + italic', () {
      const font = KatexFont(KatexFontFamily.main, KatexFontVariant.boldItalic);
      final style = textStyleFor(font, 14);

      expect(style.fontWeight, FontWeight.w700);
      expect(style.fontStyle, FontStyle.italic);
    });

    test('AMS-Regular maps to KaTeX_AMS', () {
      const font = KatexFont(KatexFontFamily.ams, KatexFontVariant.regular);
      final style = textStyleFor(font, 18);

      expect(style.fontFamily, '${prefix}KaTeX_AMS');
      expect(style.fontWeight, FontWeight.w400);
    });

    test('color is forwarded when provided', () {
      const font = KatexFont(KatexFontFamily.main, KatexFontVariant.regular);
      final style = textStyleFor(font, 10, color: const Color(0xFF112233));

      expect(style.color, const Color(0xFF112233));
    });

    test('color is null when omitted', () {
      const font = KatexFont(KatexFontFamily.main, KatexFontVariant.regular);
      final style = textStyleFor(font, 10);

      expect(style.color, isNull);
    });
  });
}
