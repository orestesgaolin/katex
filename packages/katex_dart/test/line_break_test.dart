import 'package:katex_dart/katex_dart.dart';
import 'package:test/test.dart';

// A long expression whose top level is nothing but ords, binary operators and
// relations — i.e. full of break opportunities.
const String longSum = 'a + b + c + d + e + f + g + h = i + j + k + l + m';

/// The rendered lines of [box].
///
/// An unwrapped result is a single `katex-html` span; a wrapped one is a
/// `katex-html` span wrapping a [VList] whose children are the lines. This
/// normalises both to a list.
List<BoxNode> linesOf(BoxNode box) {
  if (box is SpanNode && box.children.length == 1) {
    final child = box.children.first;
    if (child is VList) {
      return [for (final p in child.positions) p.box];
    }
  }
  return [box];
}

BoxNode render(String tex, {double maxWidth = double.infinity}) =>
    renderToBox(tex, options: KatexOptions(maxWidth: maxWidth));

/// The atom class of the last non-space box on [line], or `null`.
String? lastAtomClassOf(BoxNode line) {
  final children = (line as SpanNode).children;
  for (var i = children.length - 1; i >= 0; i--) {
    final node = children[i];
    if (node is! SpanNode || node.classes.isEmpty) {
      continue;
    }
    if (node.classes.contains('mspace')) {
      continue;
    }
    return node.classes.first;
  }
  return null;
}

void main() {
  group('no width budget', () {
    test('leaves a long expression on one line (KaTeX default)', () {
      final box = render(longSum);
      expect(linesOf(box), hasLength(1));
      expect(box.width, greaterThan(10));
    });

    test('a budget nothing overflows is identical to no budget', () {
      final unwrapped = render(longSum);
      final wrapped = render(longSum, maxWidth: 1000);
      expect(linesOf(wrapped), hasLength(1));
      expect(wrapped.width, closeTo(unwrapped.width, 1e-9));
      expect(wrapped.height, closeTo(unwrapped.height, 1e-9));
      expect(wrapped.depth, closeTo(unwrapped.depth, 1e-9));
    });
  });

  group('automatic wrapping', () {
    test('splits a long expression into several lines', () {
      final box = render(longSum, maxWidth: 6);
      final lines = linesOf(box);
      expect(lines.length, greaterThan(1));
    });

    test('no line exceeds the budget when breaks are available', () {
      for (final maxWidth in [4.0, 6.0, 8.0, 12.0]) {
        final lines = linesOf(render(longSum, maxWidth: maxWidth));
        for (final line in lines) {
          expect(
            line.width,
            lessThanOrEqualTo(maxWidth + 1e-9),
            reason: 'line overflows a $maxWidth em budget',
          );
        }
      }
    });

    test('a narrower budget never yields fewer lines', () {
      var previous = 0;
      for (final maxWidth in [20.0, 12.0, 8.0, 6.0, 4.0]) {
        final count = linesOf(render(longSum, maxWidth: maxWidth)).length;
        expect(count, greaterThanOrEqualTo(previous));
        previous = count;
      }
    });

    test('the whole expression survives: total width is conserved', () {
      final oneLine = render(longSum);
      final lines = linesOf(render(longSum, maxWidth: 6));
      final total = lines.fold<double>(0, (sum, line) => sum + line.width);
      // Every box is still there, just redistributed across lines.
      expect(total, closeTo(oneLine.width, 1e-6));
    });

    test('the wrapped root is taller than the single line', () {
      final oneLine = render(longSum);
      final wrapped = render(longSum, maxWidth: 6);
      expect(
        wrapped.height + wrapped.depth,
        greaterThan(oneLine.height + oneLine.depth),
      );
    });
  });

  group('break placement (TeXBook p.173)', () {
    test('breaks AFTER the operator — it ends the line, never starts it', () {
      final lines = linesOf(render(longSum, maxWidth: 6));
      expect(lines.length, greaterThan(1));
      for (final line in lines.take(lines.length - 1)) {
        expect(
          lastAtomClassOf(line),
          anyOf('mbin', 'mrel'),
          reason: 'a broken line must end on the operator it broke after',
        );
      }
    });

    test('breaks at a relation as well as a binary operator', () {
      // Only one opportunity in the whole expression: the `=`.
      const tex = r'\frac{abc}{def} = \frac{ghi}{jkl}';
      final budget = render(tex).width * 0.6;
      final lines = linesOf(render(tex, maxWidth: budget));
      expect(lines, hasLength(2));
      expect(lastAtomClassOf(lines.first), 'mrel');
    });

    test('never breaks inside a braced group', () {
      // The group is one box: no top-level opportunity exists inside it.
      final lines = linesOf(render('{a + b + c + d + e + f + g}', maxWidth: 2));
      expect(lines, hasLength(1));
    });

    test('never breaks inside a fraction', () {
      final lines = linesOf(
        render(r'\frac{a + b + c + d + e}{f + g + h + i + j}', maxWidth: 2),
      );
      expect(lines, hasLength(1));
    });

    test('never breaks inside \\left…\\right', () {
      final lines = linesOf(
        render(r'\left( a + b + c + d + e + f \right)', maxWidth: 2),
      );
      expect(lines, hasLength(1));
    });

    test('an unbreakable run overflows rather than being cut', () {
      final box = render(r'\frac{abcdefgh}{ijklmnop}', maxWidth: 0.5);
      final lines = linesOf(box);
      expect(lines, hasLength(1));
      expect(lines.first.width, greaterThan(0.5));
    });
  });

  group('break control', () {
    test(r'\allowbreak opens an opportunity between ordinary atoms', () {
      const tex = r'abcdefgh\allowbreak ijklmnop';
      expect(linesOf(render(tex, maxWidth: 4)).length, greaterThan(1));
      // Without the marker the same run is unbreakable.
      expect(linesOf(render('abcdefghijklmnop', maxWidth: 4)), hasLength(1));
    });

    test(r'\nobreak suppresses the opportunity after an operator', () {
      final withBreak = linesOf(render('a + b', maxWidth: 1.5));
      final suppressed = linesOf(render(r'a +\nobreak b', maxWidth: 1.5));
      expect(withBreak.length, greaterThan(1));
      expect(suppressed, hasLength(1));
    });

    test('post-operator glue rides on the operator, not the next line', () {
      // Each line's leading box must be a real atom, never inter-atom glue.
      final lines = linesOf(render(longSum, maxWidth: 6));
      for (final line in lines) {
        final first = (line as SpanNode).children.first;
        expect(
          first is SpanNode && first.classes.contains('mspace'),
          isFalse,
          reason: 'a wrapped line must not start with post-operator glue',
        );
      }
    });
  });

  group('interaction with explicit breaks', () {
    test(r'\\ still breaks when a budget is set', () {
      final lines = linesOf(render(r'a + b \\ c + d', maxWidth: 1000));
      expect(lines, hasLength(2));
    });

    test('explicit and automatic breaks compose', () {
      final explicitOnly = linesOf(render('$longSum \\\\ $longSum'));
      expect(explicitOnly, hasLength(2));
      final both = linesOf(render('$longSum \\\\ $longSum', maxWidth: 6));
      // Each half now wraps further, and both halves wrap the same way.
      expect(both.length, greaterThan(2));
      expect(both.length.isEven, isTrue);
    });

    test(r'\\[1em] keeps its extra skip when the segment also wraps', () {
      final tight = render('$longSum \\\\ $longSum', maxWidth: 6);
      final loose = render('$longSum \\\\[2em] $longSum', maxWidth: 6);
      expect(linesOf(loose), hasLength(linesOf(tight).length));
      expect(loose.height + loose.depth, greaterThan(tight.height + tight.depth));
    });
  });

  group('display mode', () {
    test('wraps in display mode too', () {
      final lines = linesOf(
        renderToBox(
          longSum,
          options: const KatexOptions(displayMode: true, maxWidth: 6),
        ),
      );
      expect(lines.length, greaterThan(1));
    });
  });

  group('SVG output', () {
    test('a wrapped expression serializes to a taller, narrower SVG', () {
      final wide = renderToSvg(longSum);
      final narrow = renderToSvg(
        longSum,
        options: const KatexOptions(maxWidth: 6),
      );
      expect(narrow, contains('<svg'));
      expect(_svgWidth(narrow), lessThan(_svgWidth(wide)));
      expect(_svgHeight(narrow), greaterThan(_svgHeight(wide)));
    });
  });
}

double _svgWidth(String svg) => _svgAttr(svg, 'width');
double _svgHeight(String svg) => _svgAttr(svg, 'height');

double _svgAttr(String svg, String name) {
  final match = RegExp('$name="([0-9.]+)').firstMatch(svg);
  expect(match, isNotNull, reason: 'SVG root should carry a $name');
  return double.parse(match!.group(1)!);
}
