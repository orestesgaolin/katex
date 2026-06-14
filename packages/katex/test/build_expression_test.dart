import 'package:katex/katex.dart';
import 'package:test/test.dart';

// The shared test gallery (reference/gallery.json), inlined as
// (id, tex, displayMode) tuples so the test does not depend on a file path.
const List<(String, String, bool)> gallery = [
  ('frac-a-b', r'\frac{a}{b}', true),
  ('sup-x-2', 'x^2', false),
  ('sub-x-i', 'x_i', false),
  ('supsub-x-2-i', 'x^2_i', false),
  ('sqrt-x', r'\sqrt{x}', false),
  ('sqrt-index-3-x', r'\sqrt[3]{x}', false),
  ('sum-limits', r'\sum_{i=0}^n i', true),
  ('int-limits', r'\int_0^1', true),
  ('prod', r'\prod', true),
  ('left-right-frac', r'\left(\frac{a}{b}\right)', true),
  ('accent-hat-x', r'\hat{x}', false),
  ('accent-bar-x', r'\bar{x}', false),
  ('accent-vec-x', r'\vec{x}', false),
  ('accent-tilde-x', r'\tilde{x}', false),
  ('mathbf-x', r'\mathbf{x}', false),
  ('mathbb-r', r'\mathbb{R}', false),
  ('mathcal-l', r'\mathcal{L}', false),
  ('overline-x', r'\overline{x}', false),
  ('underline-x', r'\underline{x}', false),
  ('greek-alpha-beta', r'\alpha+\beta', false),
  ('cdot-a-b', r'a \cdot b', false),
  ('text-hi', r'\text{hi}', false),
  ('pmatrix', r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}', true),
  ('bmatrix', r'\begin{bmatrix} a & b \\ c & d \end{bmatrix}', true),
  ('aligned', r'\begin{aligned} a &= b \\ c &= d \end{aligned}', true),
  ('cases', r'f(x) = \begin{cases} 1 & x > 0 \\ 0 & x \le 0 \end{cases}', true),
];

// Recursively collects every node in the box tree, depth-first.
List<BoxNode> _flatten(BoxNode node) {
  final out = <BoxNode>[node];
  switch (node) {
    case HBox(:final children):
      for (final c in children) {
        out.addAll(_flatten(c));
      }
    case SpanNode(:final children):
      for (final c in children) {
        out.addAll(_flatten(c));
      }
    case VList(:final positions):
      for (final p in positions) {
        out.addAll(_flatten(p.box));
      }
    case GlyphNode():
    case KernNode():
    case RuleNode():
    case SvgPathNode():
      break;
  }
  return out;
}

bool _isFinitePositive(double v) => v.isFinite && v > 0;

void main() {
  group('renderToBox builds every gallery expression', () {
    for (final entry in gallery) {
      final (id, tex, displayMode) = entry;
      test('$id: $tex', () {
        late final BoxNode root;
        expect(
          () => root = renderToBox(
            tex,
            options: KatexOptions(displayMode: displayMode),
          ),
          returnsNormally,
          reason: 'renderToBox should not throw for $tex',
        );

        expect(
          _isFinitePositive(root.width),
          isTrue,
          reason:
              'root width should be finite and positive for $tex '
              '(was ${root.width})',
        );
        // Height + depth is the total vertical extent; require it positive.
        final extent = root.height + root.depth;
        expect(
          extent.isFinite && extent > 0,
          isTrue,
          reason:
              'root height+depth should be finite and positive for $tex '
              '(was $extent)',
        );
      });
    }
  });

  group('structural assertions', () {
    test(r'\frac{a}{b} contains a VList with a fraction-bar RuleNode', () {
      final root = renderToBox(
        r'\frac{a}{b}',
        options: const KatexOptions(displayMode: true),
      );
      final nodes = _flatten(root);
      final vlists = nodes.whereType<VList>().toList();
      expect(vlists, isNotEmpty, reason: 'fraction should produce a VList');
      // At least one VList must contain a RuleNode (the fraction bar) among
      // its positioned children.
      final hasBar = vlists.any(
        (v) => v.positions.any((p) => p.box is RuleNode),
      );
      expect(
        hasBar,
        isTrue,
        reason: 'fraction VList should contain a bar rule',
      );
    });

    test('x^2 is taller than bare x (supsub raises the height)', () {
      final bare = renderToBox('x');
      final sup = renderToBox('x^2');
      expect(
        sup.height,
        greaterThan(bare.height),
        reason: 'x^2 should be taller than x',
      );
    });

    test(r'\sqrt{x} produces a node tagged "sqrt"', () {
      final root = renderToBox(r'\sqrt{x}');
      final nodes = _flatten(root);
      final hasSqrt = nodes.any(
        (n) => n is SpanNode && n.classes.contains('sqrt'),
      );
      expect(hasSqrt, isTrue);
    });

    test('renderToSvg returns a non-empty SVG document', () {
      final svg = renderToSvg(
        r'\frac{a}{b}',
        options: const KatexOptions(displayMode: true),
      );
      expect(svg, contains('<svg'));
      expect(svg.length, greaterThan(0));
    });
  });
}
