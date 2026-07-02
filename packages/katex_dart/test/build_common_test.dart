import 'package:katex_dart/src/box/box_node.dart';
import 'package:katex_dart/src/build/build_common.dart';
import 'package:katex_dart/src/build/options.dart';
import 'package:katex_dart/src/build/style.dart';
import 'package:katex_dart/src/types.dart';
import 'package:test/test.dart';

void main() {
  group('Style', () {
    test('DISPLAY.sup() is SCRIPT', () {
      expect(Style.DISPLAY.sup(), same(Style.SCRIPT));
    });

    test('size multipliers match KaTeX', () {
      expect(Style.DISPLAY.sizeMultiplier, 1.0);
      expect(Style.TEXT.sizeMultiplier, 1.0);
      expect(Style.SCRIPT.sizeMultiplier, 0.7);
      expect(Style.SCRIPTSCRIPT.sizeMultiplier, 0.5);
    });

    test('transitions and flags', () {
      // sub of TEXT is the *cramped* script style (KaTeX `sub` table).
      expect(Style.TEXT.sub().size, 2);
      expect(Style.TEXT.sub().cramped, isTrue);
      expect(Style.DISPLAY.fracNum(), same(Style.TEXT));
      expect(Style.DISPLAY.fracDen().cramped, isTrue);
      expect(Style.DISPLAY.cramp().cramped, isTrue);
      // Cramping a cramped style is a no-op.
      expect(Style.DISPLAY.cramp().cramp(), same(Style.DISPLAY.cramp()));
      expect(Style.SCRIPT.text(), same(Style.TEXT));
      expect(Style.DISPLAY.isTight(), isFalse);
      expect(Style.SCRIPT.isTight(), isTrue);
      expect(Style.SCRIPTSCRIPT.isTight(), isTrue);
    });
  });

  group('Options', () {
    test('default construction', () {
      final options = Options.initial();
      expect(options.style, same(Style.DISPLAY));
      expect(options.size, Options.baseSize);
      expect(options.textSize, Options.baseSize);
      expect(options.sizeMultiplier, 1.0);
      expect(options.color, isNull);
      expect(options.phantom, isFalse);
      expect(options.getColor(), isNull);
    });

    test('havingStyle to SCRIPT updates size and multiplier', () {
      final base = Options.initial();
      final script = base.havingStyle(Style.SCRIPT);
      expect(script.style, same(Style.SCRIPT));
      // sizeAtStyle(textSize=6, SCRIPT) -> sizeStyleMap[5][1] == 3.
      expect(script.size, 3);
      // sizeMultipliers[3 - 1] == 0.7.
      expect(script.sizeMultiplier, 0.7);
      // havingStyle to the same style returns the same instance.
      expect(base.havingStyle(Style.DISPLAY), same(base));
    });

    test('havingSize sets size, textSize and multiplier', () {
      final base = Options.initial();
      final big = base.havingSize(8);
      expect(big.size, 8);
      expect(big.textSize, 8);
      expect(big.sizeMultiplier, 1.44);
      // havingSize uses style.text(); for DISPLAY that stays DISPLAY.
      expect(big.style, same(Style.DISPLAY));
    });

    test('withColor and withPhantom', () {
      final base = Options.initial();
      final red = base.withColor('#ff0000');
      expect(red.color, '#ff0000');
      expect(red.getColor(), '#ff0000');
      expect(base.color, isNull); // immutable

      final phantom = red.withPhantom();
      expect(phantom.getColor(), 'transparent');
    });

    test('withFont / withTextFontFamily clears the other', () {
      final base = Options.initial();
      final bf = base.withFont('mathbf');
      expect(bf.font, 'mathbf');
      final sf = bf.withTextFontFamily('textsf');
      expect(sf.fontFamily, 'textsf');
      expect(sf.font, ''); // cleared
    });
  });

  group('makeSymbol', () {
    test("'A' in Main-Regular has KaTeX metrics at sizeMultiplier 1.0", () {
      final glyph = makeSymbol('A', 'Main-Regular', Mode.math)!;
      expect(glyph.size, 1.0);
      expect(glyph.height, closeTo(0.68333, 1e-5));
      expect(glyph.width, closeTo(0.75, 1e-5));
      expect(glyph.depth, closeTo(0, 1e-9));
      expect(glyph.codepoint, 'A'.codeUnitAt(0));
    });

    test("'A' scales with the options size multiplier", () {
      final options = Options.initial().havingStyle(Style.SCRIPT);
      expect(options.sizeMultiplier, 0.7);
      final glyph =
          makeSymbol('A', 'Main-Regular', Mode.math, options: options)!;
      expect(glyph.size, 0.7);
      expect(glyph.height, closeTo(0.68333 * 0.7, 1e-5));
      expect(glyph.width, closeTo(0.75 * 0.7, 1e-5));
    });

    test('mathsym routes a relation through Main-Regular', () {
      // '=' is a Main-font relation.
      final eq = mathsym('=', Mode.math, Options.initial())!;
      expect(eq.font.fontName, 'Main-Regular');
    });
  });

  group('makeVList', () {
    test('2-element top-positioned stack matches hand-computed dims', () {
      // Two rules with explicit dimensions, stacked bottom-to-top with a kern.
      const lower = RuleNode(width: 0.5, height: 0.4, depth: 0.1);
      const upper = RuleNode(width: 0.5, height: 0.3);

      // positionType "top" with positionData = 1.0 (topmost point height).
      // getVListChildrenAndDepth: bottom = 1.0
      //   - (lower.h + lower.d = 0.5) - (kern 0.2) - (upper.h + upper.d = 0.3)
      //   = 1.0 - 0.5 - 0.2 - 0.3 = 0.0 -> depth start = 0.0.
      // layout (currPos starts at 0.0):
      //   lower: shift = -(0.0 + 0.1) = -0.1; currPos -> 0.0 + 0.5 = 0.5
      //   kern 0.2: currPos -> 0.7
      //   upper: shift = -(0.7 + 0.0) = -0.7; currPos -> 0.7 + 0.3 = 1.0
      //   minPos = 0.0, maxPos = 1.0
      // => height = maxPos = 1.0, depth = -minPos = 0.0, width = 0.5.
      final vlist = makeVList(
        positionType: VListPositionType.top,
        positionData: 1,
        children: const [
          VListChild.elem(lower),
          VListChild.kern(0.2),
          VListChild.elem(upper),
        ],
      );

      expect(vlist.height, closeTo(1.0, 1e-9));
      expect(vlist.depth, closeTo(0.0, 1e-9));
      expect(vlist.width, closeTo(0.5, 1e-9));
      expect(vlist.positions, hasLength(2));
      expect(vlist.positions[0].shift, closeTo(-0.1, 1e-9));
      expect(vlist.positions[1].shift, closeTo(-0.7, 1e-9));
    });
  });

  group('makeLineSpan', () {
    test('uses default rule thickness when none given', () {
      final options = Options.initial();
      final rule = makeLineSpan(options, width: 1);
      expect(
        rule.height,
        closeTo(options.fontMetrics().defaultRuleThickness, 1e-9),
      );
      expect(rule.width, 1.0);
    });

    test('honours minRuleThickness floor', () {
      final options = Options.initial(minRuleThickness: 0.1);
      final rule = makeLineSpan(options, thickness: 0.04, width: 1);
      expect(rule.height, closeTo(0.1, 1e-9));
    });
  });

  group('makeFragment / makeSpan', () {
    test('makeFragment sizes from children', () {
      final a = makeSymbol('A', 'Main-Regular', Mode.math)!;
      final frag = makeFragment([a, makeKern(0.2), a]);
      expect(frag.width, closeTo(a.width * 2 + 0.2, 1e-9));
      expect(frag.height, closeTo(a.height, 1e-9));
    });

    test('makeSpan carries color and size multiplier', () {
      final options = Options.initial().withColor('#00ff00');
      final a = makeSymbol('A', 'Main-Regular', Mode.math)!;
      final span = makeSpan([a], options: options, classes: ['mord']);
      expect(span.color, '#00ff00');
      expect(span.sizeMultiplier, 1.0);
      expect(span.classes, ['mord']);
    });
  });
}
