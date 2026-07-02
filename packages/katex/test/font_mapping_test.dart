import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katex/katex.dart';
import 'package:katex_dart/src/font/font_types.dart';

void main() {
  group('textStyleFor', () {
    // When a `package` is supplied, the engine prefixes the resolved family
    // with `packages/<package>/`. We assert that prefixed form below; the raw
    // family selected by the mapping is the per-FILE family `KaTeX_<fontName>`.
    const prefix = 'packages/$katexFlutterPackage/';

    // Every variant maps to a unique per-file family with ALWAYS-normal
    // weight/style: KaTeX italic/bold fonts bake the style into the outlines
    // but are flagged "Regular", so requesting italic/bold would make Skia
    // synthesize a (wrong) double slant / faux bold. See textStyleFor.

    test('Main-Regular -> per-file family KaTeX_Main-Regular, w400/normal', () {
      const font = KatexFont(KatexFontFamily.main, KatexFontVariant.regular);
      final style = textStyleFor(font, 20);

      expect(style.fontFamily, '${prefix}KaTeX_Main-Regular');
      expect(style.fontWeight, FontWeight.w400);
      expect(style.fontStyle, FontStyle.normal);
      expect(style.fontSize, 20);
      expect(style.height, 1.0);
      expect(
        style,
        const TextStyle(
          fontFamily: 'KaTeX_Main-Regular',
          package: katexFlutterPackage,
          fontWeight: FontWeight.w400,
          fontStyle: FontStyle.normal,
          fontSize: 20,
          height: 1,
        ),
      );
    });

    test('Math-Italic -> KaTeX_Math-Italic, NORMAL style (no synthesis)', () {
      const font = KatexFont(KatexFontFamily.math, KatexFontVariant.italic);
      final style = textStyleFor(font, 16);

      expect(style.fontFamily, '${prefix}KaTeX_Math-Italic');
      // Critically NOT italic — the slant is in the outlines; requesting italic
      // would double-slant via synthetic oblique.
      expect(style.fontStyle, FontStyle.normal);
      expect(style.fontWeight, FontWeight.w400);
      expect(style.fontSize, 16);
    });

    test('Main-Bold -> KaTeX_Main-Bold, NORMAL weight (no faux bold)', () {
      const font = KatexFont(KatexFontFamily.main, KatexFontVariant.bold);
      final style = textStyleFor(font, 12);

      expect(style.fontFamily, '${prefix}KaTeX_Main-Bold');
      expect(style.fontWeight, FontWeight.w400);
      expect(style.fontStyle, FontStyle.normal);
    });

    test('Main-BoldItalic -> KaTeX_Main-BoldItalic, normal/normal', () {
      const font = KatexFont(KatexFontFamily.main, KatexFontVariant.boldItalic);
      final style = textStyleFor(font, 14);

      expect(style.fontFamily, '${prefix}KaTeX_Main-BoldItalic');
      expect(style.fontWeight, FontWeight.w400);
      expect(style.fontStyle, FontStyle.normal);
    });

    test('AMS-Regular -> KaTeX_AMS-Regular', () {
      const font = KatexFont(KatexFontFamily.ams, KatexFontVariant.regular);
      final style = textStyleFor(font, 18);

      expect(style.fontFamily, '${prefix}KaTeX_AMS-Regular');
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
