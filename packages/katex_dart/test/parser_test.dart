import 'dart:convert';
import 'dart:io';

import 'package:katex_dart/src/ast/parse_node.dart';
import 'package:katex_dart/src/parse/parse_tree.dart';
import 'package:katex_dart/src/parse/settings.dart';
import 'package:test/test.dart';

/// Parses [tex] in math (or display) mode with default settings.
List<ParseNode> parse(String tex, {bool displayMode = false}) => parseTree(tex, Settings(displayMode: displayMode));

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
    final gallery = (jsonDecode(File(galleryPath).readAsStringSync()) as List).cast<Map<String, dynamic>>();

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

  // Precomposed accented input (KaTeX `unicodeSymbols`).
  //
  // A literal "é" has no font metrics, so if it reaches the builder unchanged
  // it is dropped and the character silently disappears ("café" → "caf"). The
  // parser therefore rewrites it to its base letter + combining accent, which
  // the existing combining-mark path turns into an accent command.
  group('precomposed accents', () {
    /// The accent labels wrapping [tex]'s single parsed symbol, outermost last.
    List<String> accentLabels(String tex) {
      final body = (parse(tex).single as TextNode).body;
      final labels = <String>[];
      var node = body.single;
      while (node is AccentNode) {
        labels.add(node.label);
        node = node.base;
      }
      return labels;
    }

    String baseText(String tex) {
      var node = (parse(tex).single as TextNode).body.single;
      while (node is AccentNode) {
        node = node.base;
      }
      return (node as SymbolParseNode).text;
    }

    test('decomposes into base letter + text-mode accent command', () {
      expect(baseText(r'\text{é}'), 'e');
      expect(accentLabels(r'\text{é}'), [r"\'"]);

      expect(baseText(r'\text{â}'), 'a');
      expect(accentLabels(r'\text{â}'), [r'\^']);

      expect(baseText(r'\text{ä}'), 'a');
      expect(accentLabels(r'\text{ä}'), [r'\"']);

      expect(baseText(r'\text{ù}'), 'u');
      expect(accentLabels(r'\text{ù}'), [r'\`']);
    });

    test('cedilla and double acute resolve (were "Unknown accent")', () {
      // These two live in `unicodeAccents` but were missing from the parser's
      // own reduced copy of that table, so they threw.
      expect(baseText(r'\text{ç}'), 'c');
      expect(accentLabels(r'\text{ç}'), [r'\c']);

      expect(baseText(r'\text{ő}'), 'o');
      expect(accentLabels(r'\text{ő}'), [r'\H']);
    });

    test('text mode uses the text accent, not the math one', () {
      // The parser previously always chose the math command (`\acute`), which
      // in text mode rendered a literal backslash instead of an accent.
      expect(accentLabels(r'\text{é}'), [r"\'"]);
      // Math mode still prefers the math command.
      final mathBody = parse('é').single;
      expect((mathBody as AccentNode).label, r'\acute');
    });

    test('an accented i/j loses its dot, as with explicit accents', () {
      expect(baseText(r'\text{ï}'), 'ı');
    });

    test('precomposed and decomposed input agree', () {
      for (final pair in <(String, String)>[
        (r'\text{é}', '\\text{e\u0301}'),
        (r'\text{â}', '\\text{a\u0302}'),
        (r'\text{ç}', '\\text{c\u0327}'),
      ]) {
        expect(
          accentLabels(pair.$1),
          accentLabels(pair.$2),
          reason: '${pair.$1} vs ${pair.$2}',
        );
        expect(baseText(pair.$1), baseText(pair.$2));
      }
    });

    test('unaccented text is untouched', () {
      final body = (parse(r'\text{abc}').single as TextNode).body;
      expect(body, hasLength(3));
      expect(body.every((n) => n is! AccentNode), isTrue);
    });
  });

  group('error handling', () {
    test('undefined control sequence throws by default', () {
      expect(() => parse(r'\nonexistentcommand'), throwsA(isA<Object>()));
    });

    test('double superscript throws', () {
      expect(() => parse('x^2^3'), throwsA(isA<Object>()));
    });
  });
}
