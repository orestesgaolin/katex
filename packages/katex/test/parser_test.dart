import 'dart:convert';
import 'dart:io';

import 'package:katex/src/ast/parse_node.dart';
import 'package:katex/src/parse/parse_tree.dart';
import 'package:katex/src/parse/settings.dart';
import 'package:test/test.dart';

/// Parses [tex] in math (or display) mode with default settings.
List<ParseNode> parse(String tex, {bool displayMode = false}) =>
    parseTree(tex, Settings(displayMode: displayMode));

void main() {
  group('gallery', () {
    // Resolve gallery.json relative to the repo root regardless of cwd.
    final candidates = <String>[
      'reference/gallery.json',
      '../../reference/gallery.json',
    ];
    final galleryPath = candidates.firstWhere(
      (p) => File(p).existsSync(),
      orElse: () => candidates.last,
    );
    final gallery = (jsonDecode(File(galleryPath).readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

    // Expected root node types per gallery id (single root unless noted).
    const expectedRootType = <String, String>{
      'frac-a-b': 'genfrac',
      'sup-x-2': 'supsub',
      'sub-x-i': 'supsub',
      'supsub-x-2-i': 'supsub',
      'sqrt-x': 'sqrt',
      'sqrt-index-3-x': 'sqrt',
      'sum-limits': 'supsub',
      'int-limits': 'supsub',
      'prod': 'op',
      'left-right-frac': 'leftright',
      'accent-hat-x': 'accent',
      'accent-bar-x': 'accent',
      'accent-vec-x': 'accent',
      'accent-tilde-x': 'accent',
      'mathbf-x': 'font',
      'mathbb-r': 'font',
      'mathcal-l': 'font',
      'overline-x': 'overline',
      'underline-x': 'underline',
      'text-hi': 'text',
      'pmatrix': 'leftright',
      'bmatrix': 'leftright',
      'aligned': 'array',
    };

    for (final entry in gallery) {
      final id = entry['id'] as String;
      final tex = entry['tex'] as String;
      final displayMode = entry['displayMode'] as bool;
      test('parses "$id" without error', () {
        final tree = parse(tex, displayMode: displayMode);
        expect(tree, isNotEmpty, reason: tex);
        final expected = expectedRootType[id];
        if (expected != null) {
          expect(tree.first.type, expected, reason: '$id: $tex');
        }
      });
    }
  });

  group('AST shapes', () {
    test(r'\frac{a}{b} is a genfrac with ordgroup numer/denom', () {
      final tree = parse(r'\frac{a}{b}', displayMode: true);
      expect(tree, hasLength(1));
      final frac = tree.single;
      expect(frac, isA<GenfracNode>());
      frac as GenfracNode;
      expect(frac.hasBarLine, isTrue);
      expect(frac.continued, isFalse);
      expect(frac.numer, isA<OrdGroupNode>());
      expect(frac.denom, isA<OrdGroupNode>());
      expect((frac.numer as OrdGroupNode).body.single, isA<MathOrdNode>());
      expect(
        ((frac.numer as OrdGroupNode).body.single as MathOrdNode).text,
        'a',
      );
      expect(
        ((frac.denom as OrdGroupNode).body.single as MathOrdNode).text,
        'b',
      );
    });

    test('x^2_i is a supsub with sup and sub', () {
      final tree = parse('x^2_i');
      expect(tree, hasLength(1));
      final node = tree.single;
      expect(node, isA<SupSubNode>());
      node as SupSubNode;
      expect((node.base! as MathOrdNode).text, 'x');
      expect(node.sup, isNotNull);
      expect(node.sub, isNotNull);
      // 2 is a textord (digit); i is a mathord.
      expect((node.sup! as TextOrdNode).text, '2');
      expect((node.sub! as MathOrdNode).text, 'i');
    });

    test(r'\sqrt[3]{x} is a sqrt with an index', () {
      final tree = parse(r'\sqrt[3]{x}');
      expect(tree, hasLength(1));
      final sqrt = tree.single;
      expect(sqrt, isA<SqrtNode>());
      sqrt as SqrtNode;
      expect(sqrt.index, isNotNull);
      expect(sqrt.body, isA<OrdGroupNode>());
      expect((sqrt.index! as OrdGroupNode).body.single, isA<TextOrdNode>());
      expect(
        ((sqrt.index! as OrdGroupNode).body.single as TextOrdNode).text,
        '3',
      );
    });

    test(r'\sqrt{x} has no index', () {
      final tree = parse(r'\sqrt{x}');
      final sqrt = tree.single as SqrtNode;
      expect(sqrt.index, isNull);
    });

    test(r'\sum_{i=0}^n carries op base with limits via supsub', () {
      final tree = parse(r'\sum_{i=0}^n', displayMode: true);
      final node = tree.first;
      expect(node, isA<SupSubNode>());
      node as SupSubNode;
      expect(node.base, isA<OpNode>());
      final op = node.base! as OpNode;
      expect(op.name, r'\sum');
      expect(op.limits, isTrue);
      expect(op.symbol, isTrue);
      expect(node.sub, isNotNull);
      expect(node.sup, isNotNull);
    });

    test(r'\left(\frac{a}{b}\right) is a leftright wrapping a genfrac', () {
      final tree = parse(r'\left(\frac{a}{b}\right)', displayMode: true);
      expect(tree, hasLength(1));
      final lr = tree.single;
      expect(lr, isA<LeftRightNode>());
      lr as LeftRightNode;
      expect(lr.left, '(');
      expect(lr.right, ')');
      expect(lr.body.single, isA<GenfracNode>());
    });

    test('pmatrix is a leftright around an array of 2x2 cells', () {
      final tree = parse(
        r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}',
        displayMode: true,
      );
      final lr = tree.single as LeftRightNode;
      expect(lr.left, '(');
      expect(lr.right, ')');
      final array = lr.body.single as ArrayNode;
      expect(array.body, hasLength(2));
      expect(array.body[0], hasLength(2));
      expect(array.body[1], hasLength(2));
    });

    test('aligned is an array with two rows', () {
      final tree = parse(
        r'\begin{aligned} a &= b \\ c &= d \end{aligned}',
        displayMode: true,
      );
      final array = tree.single as ArrayNode;
      expect(array.body, hasLength(2));
      // Each row has two cells separated by &.
      expect(array.body[0], hasLength(2));
      expect(array.colSeparationType, ColSeparationType.align);
    });

    test('cases parses into a leftright with a brace', () {
      final tree = parse(
        r'f(x) = \begin{cases} 1 & x > 0 \\ 0 & x \le 0 \end{cases}',
        displayMode: true,
      );
      final lr = tree.last as LeftRightNode;
      expect(lr.left, r'\{');
      expect(lr.right, '.');
      final array = lr.body.single as ArrayNode;
      expect(array.body, hasLength(2));
    });
  });

  group('error handling', () {
    test('undefined control sequence throws by default', () {
      expect(
        () => parse(r'\nonexistentcommand'),
        throwsA(isA<Object>()),
      );
    });

    test('double superscript throws', () {
      expect(() => parse('x^2^3'), throwsA(isA<Object>()));
    });
  });
}
