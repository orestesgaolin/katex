import 'package:katex/src/symbols/spacing_data.g.dart';
import 'package:katex/src/symbols/symbols.dart';
import 'package:katex/src/symbols/unicode_symbols.dart';
import 'package:test/test.dart';

void main() {
  group('Symbols.lookup', () {
    test(r'Greek letter \alpha is a main-font mathord (U+03B1)', () {
      final sym = Symbols.lookup(Mode.math, r'\alpha');
      expect(sym, isNotNull);
      expect(sym!.font, Font.main);
      expect(sym.group, Group.mathord);
      expect(sym.replace, 'α');
    });

    test('binary operator + replaces with itself', () {
      final sym = Symbols.lookup(Mode.math, '+')!;
      expect(sym.font, Font.main);
      expect(sym.group, Group.bin);
      expect(sym.replace, '+');
    });

    test('relation = replaces with itself', () {
      final sym = Symbols.lookup(Mode.math, '=')!;
      expect(sym.group, Group.rel);
      expect(sym.replace, '=');
    });

    test(r'\cdot is a main-font bin (U+22C5)', () {
      final sym = Symbols.lookup(Mode.math, r'\cdot')!;
      expect(sym.font, Font.main);
      expect(sym.group, Group.bin);
      expect(sym.replace, '⋅');
    });

    test(r'\sum is a big operator (op group, U+2211)', () {
      final sym = Symbols.lookup(Mode.math, r'\sum')!;
      expect(sym.font, Font.main);
      expect(sym.group, Group.op);
      expect(sym.replace, '∑');
    });

    test('a letter is mathord in math, textord in text', () {
      final mathA = Symbols.lookup(Mode.math, 'A')!;
      expect(mathA.group, Group.mathord);
      expect(mathA.replace, 'A');

      final textA = Symbols.lookup(Mode.text, 'A')!;
      expect(textA.group, Group.textord);
      expect(textA.replace, 'A');
    });

    test('a digit is textord in both modes', () {
      expect(Symbols.lookup(Mode.math, '7')!.group, Group.textord);
      expect(Symbols.lookup(Mode.text, '7')!.group, Group.textord);
    });

    test(r'\hat is an accent token', () {
      final sym = Symbols.lookup(Mode.math, r'\hat')!;
      expect(sym.group, Group.accent);
      expect(sym.replace, '^');
    });

    test(r'\varnothing is an AMS-font textord (U+2205)', () {
      // defineSymbol(math, ams, textord, "∅", "\\varnothing")
      final sym = Symbols.lookup(Mode.math, r'\varnothing')!;
      expect(sym.font, Font.ams);
      expect(sym.group, Group.textord);
      expect(sym.replace, '∅');
    });

    test('"C" key keeps the last-write-wins plain-letter registration', () {
      // KaTeX registers "C" as an ams blackboard-bold textord, but the later
      // plain `letters` loop overwrites key "C" with a main mathord (the
      // blackboard glyph is keyed by its wide replacement char, not "C").
      final sym = Symbols.lookup(Mode.math, 'C')!;
      expect(sym.font, Font.main);
      expect(sym.group, Group.mathord);
      expect(sym.replace, 'C');
    });

    test(r'spacing command \nobreak has null replace', () {
      final sym = Symbols.lookup(Mode.math, r'\nobreak')!;
      expect(sym.group, Group.spacing);
      expect(sym.replace, '');
    });

    test('acceptUnicodeChar registers replacement-keyed alias', () {
      // \\equiv has acceptUnicodeChar, so U+2261 is also a key.
      final byName = Symbols.lookup(Mode.math, r'\equiv')!;
      final byChar = Symbols.lookup(Mode.math, '≡')!;
      expect(byChar, byName);
    });

    test('unknown symbol returns null', () {
      expect(Symbols.lookup(Mode.math, r'\thisIsNotASymbol'), isNull);
    });

    test('table sizes match KaTeX (1488 math, 750 text)', () {
      expect(Symbols.table[Mode.math]!.length, 1488);
      expect(Symbols.table[Mode.text]!.length, 750);
    });
  });

  group('spacing tables', () {
    test('mu constants', () {
      expect(thinspace.number, 3);
      expect(mediumspace.number, 4);
      expect(thickspace.number, 5);
    });

    test('mord -> mbin is medium space (4 mu)', () {
      // spacingData.ts: spacings.mord.mbin = mediumspace
      expect(spacings[MathClass.mord]![MathClass.mbin], mediumspace);
    });

    test('mord -> mrel is thick space (5 mu)', () {
      expect(spacings[MathClass.mord]![MathClass.mrel], thickspace);
    });

    test('mord -> mop is thin space (3 mu)', () {
      expect(spacings[MathClass.mord]![MathClass.mop], thinspace);
    });

    test('mopen has no spacing entries', () {
      expect(spacings[MathClass.mopen], isEmpty);
    });

    test('tight: mbin/mrel collapse to no spacing', () {
      // tightSpacings.mbin = {}, tightSpacings.mrel = {}
      expect(tightSpacings[MathClass.mbin], isEmpty);
      expect(tightSpacings[MathClass.mrel], isEmpty);
    });

    test('tight: mop -> mord stays thin space', () {
      expect(tightSpacings[MathClass.mop]![MathClass.mord], thinspace);
    });
  });

  group('unicodeAccents', () {
    test(r"combining acute maps to text \' and math \acute", () {
      final accent = unicodeAccents['\u{301}']!;
      expect(accent.text, r"\'");
      expect(accent.math, r'\acute');
    });

    test('combining cedilla has text only, no math', () {
      final accent = unicodeAccents['\u{327}']!;
      expect(accent.text, r'\c');
      expect(accent.math, isNull);
    });
  });
}
