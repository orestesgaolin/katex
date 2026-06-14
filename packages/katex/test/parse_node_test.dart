// Constructs a few parse nodes and asserts their KaTeX `type` discriminant,
// mode, and children — mirroring shapes the MVP parser/builders will produce.
import 'package:katex/src/ast/parse_node.dart';
import 'package:katex/src/symbols/symbols.dart' show Group, MathClass;
import 'package:katex/src/types.dart';
import 'package:test/test.dart';

void main() {
  group('SymbolParseNode', () {
    test('mathord carries text/mode and exact type', () {
      const node = MathOrdNode(mode: Mode.math, text: 'x');
      expect(node.type, 'mathord');
      expect(node.mode, Mode.math);
      expect(node.text, 'x');
      expect(node.loc, isNull);
      expect(node, isA<SymbolParseNode>());
      expect(node, isA<ParseNode>());
    });

    test('atom carries family', () {
      const node = AtomNode(mode: Mode.math, text: '+', family: Group.bin);
      expect(node.type, 'atom');
      expect(node.family, Group.bin);
    });

    test('token type strings match KaTeX exactly', () {
      expect(
        const AccentTokenNode(mode: Mode.math, text: '^').type,
        'accent-token',
      );
      expect(const OpTokenNode(mode: Mode.math, text: '∑').type, 'op-token');
      expect(const SpacingNode(mode: Mode.math, text: ' ').type, 'spacing');
      expect(const TextOrdNode(mode: Mode.text, text: '5').type, 'textord');
    });
  });

  group('ordgroup wrapping mathords', () {
    const group = OrdGroupNode(
      mode: Mode.math,
      body: [
        MathOrdNode(mode: Mode.math, text: 'a'),
        MathOrdNode(mode: Mode.math, text: 'b'),
      ],
    );

    test('type and mode', () {
      expect(group.type, 'ordgroup');
      expect(group.mode, Mode.math);
    });

    test('children', () {
      expect(group.body, hasLength(2));
      expect(group.body.every((n) => n.type == 'mathord'), isTrue);
      expect((group.body.first as MathOrdNode).text, 'a');
    });
  });

  group('supsub', () {
    const node = SupSubNode(
      mode: Mode.math,
      base: MathOrdNode(mode: Mode.math, text: 'x'),
      sup: MathOrdNode(mode: Mode.math, text: '2'),
    );

    test('type/mode and children', () {
      expect(node.type, 'supsub');
      expect(node.mode, Mode.math);
      expect((node.base! as MathOrdNode).text, 'x');
      expect((node.sup! as MathOrdNode).text, '2');
      expect(node.sub, isNull);
    });
  });

  group('genfrac', () {
    const node = GenfracNode(
      mode: Mode.math,
      numer: MathOrdNode(mode: Mode.math, text: 'a'),
      denom: MathOrdNode(mode: Mode.math, text: 'b'),
      hasBarLine: true,
      continued: false,
    );

    test('type/mode and numer/denom', () {
      expect(node.type, 'genfrac');
      expect(node.mode, Mode.math);
      expect(node.hasBarLine, isTrue);
      expect((node.numer as MathOrdNode).text, 'a');
      expect((node.denom as MathOrdNode).text, 'b');
      expect(node.leftDelim, isNull);
    });
  });

  group('mclass and Measurement reuse', () {
    test('mclass uses the shared MathClass enum', () {
      const node = MclassNode(
        mode: Mode.math,
        mclass: MathClass.mbin,
        body: [MathOrdNode(mode: Mode.math, text: '+')],
        isCharacterBox: true,
      );
      expect(node.type, 'mclass');
      expect(node.mclass, MathClass.mbin);
    });

    test('Measurement equality', () {
      expect(const Measurement(1, 'em'), const Measurement(1, 'em'));
      expect(
        const Measurement(1, 'em') == const Measurement(2, 'em'),
        isFalse,
      );
    });
  });

  test('exhaustive switch on sealed hierarchy compiles', () {
    const ParseNode node = SqrtNode(
      mode: Mode.math,
      body: MathOrdNode(mode: Mode.math, text: 'x'),
    );
    final label = switch (node) {
      SqrtNode() => 'sqrt',
      SymbolParseNode() => 'symbol',
      OrdGroupNode() => 'ordgroup',
      SupSubNode() => 'supsub',
      GenfracNode() => 'genfrac',
      _ => 'other',
    };
    expect(label, 'sqrt');
  });
}
