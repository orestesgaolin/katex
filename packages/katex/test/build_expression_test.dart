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

  // T-025 — accent rendering: glyph selection + centering + stretchy SVG.
  group('accent rendering', () {
    test(r'\hat{x} uses the Main-font circumflex glyph (U+005E)', () {
      final nodes = _flatten(renderToBox(r'\hat{x}'));
      // The accent glyph is the symbol-table `replace` for \hat: `^` (U+005E),
      // NOT a combining diacritic. Its italic correction is zeroed.
      final caret = nodes.whereType<GlyphNode>().where(
        (g) => g.codepoint == 0x5e,
      );
      expect(caret, isNotEmpty, reason: r'\hat should render `^` from Main');
      expect(caret.first.italic, 0, reason: 'accent italic is zeroed');
    });

    test(r'\hat{x} centers the accent over the base', () {
      final root = renderToBox(r'\hat{x}');
      // Find the accent VList and the leading centering kern before the `^`.
      final vlists = _flatten(root).whereType<VList>();
      KernNode? leadKern;
      for (final v in vlists) {
        for (final p in v.positions) {
          final box = p.box;
          if (box is HBox &&
              box.children.length == 2 &&
              box.children.first is KernNode &&
              box.children.last is GlyphNode &&
              (box.children.last as GlyphNode).codepoint == 0x5e) {
            leadKern = box.children.first as KernNode;
          }
        }
      }
      expect(leadKern, isNotNull, reason: 'accent-body has a leading kern');
      // left = (base.width - accentWidth) / 2 + skew. For \hat{x}:
      // base x width 0.57153, accent `^` width 0.5, plus x's italic skew.
      // The previous bug used `skew - width/2` ≈ -0.25 (drifting upper-left);
      // the fix adds the base-width centering term, giving a POSITIVE kern at
      // least as large as the pure centering offset.
      const centering = (0.57153 - 0.5) / 2; // ≈ 0.0358
      expect(
        leadKern!.width,
        greaterThanOrEqualTo(centering - 1e-9),
        reason: 'centering kern must include the base-centering term',
      );
    });

    test(r'\vec{x} renders the static "vec" SVG arrow (not a combining glyph)',
        () {
      final nodes = _flatten(renderToBox(r'\vec{x}'));
      final vec = nodes.whereType<SvgPathNode>().where(
        (s) => s.pathName == 'vec',
      );
      expect(vec, isNotEmpty, reason: r'\vec should use the vec SVG path');
      expect(vec.first.pathData, isNotEmpty, reason: 'vec path data resolved');
      // No combining-arrow glyph (U+20D7) should be emitted.
      final combining = nodes.whereType<GlyphNode>().where(
        (g) => g.codepoint == 0x20d7,
      );
      expect(combining, isEmpty, reason: 'no missing combining U+20D7 glyph');
    });

    test(r'\widehat{abc} uses a stretchy widehat SVG sized to the base', () {
      final root = renderToBox(r'\widehat{abc}');
      final nodes = _flatten(root);
      final wide = nodes.whereType<SvgPathNode>().where(
        (s) => s.pathName.startsWith('widehat'),
      );
      expect(wide, isNotEmpty, reason: r'\widehat should use a widehat SVG');
      // 3 characters → widehat2.
      expect(wide.first.pathName, 'widehat2');
      expect(wide.first.pathData, isNotEmpty);
      // The accent stretches to the base width.
      expect(wide.first.width, closeTo(root.width, 1e-9));
    });

    test(r'\overrightarrow{AB} uses the sliced rightarrow SVG', () {
      final nodes = _flatten(renderToBox(r'\overrightarrow{AB}'));
      final arrow = nodes.whereType<SvgPathNode>().where(
        (s) => s.pathName == 'rightarrow',
      );
      expect(arrow, isNotEmpty, reason: 'stretchy arrow uses rightarrow path');
      expect(
        arrow.first.preserveAspectRatio,
        SvgPreserveAspectRatio.xMinYMinSlice,
        reason: 'arrows are 400em-wide & sliced like KaTeX',
      );
    });

    // T-031 (RC-D): stretchy accents must sit ABOVE the base, not over it.
    // KaTeX's stretchy `makeVList` is `[body, accentSvg]` with NO clearance
    // kern (accent.ts). In a `firstBaseline` vlist the accent SVG (depth 0)
    // therefore lands with its baseline exactly at `body.height` above the
    // main baseline — clear of the letters. A regression that re-introduces a
    // `-clearance` kern pulls the accent down onto the base (the bug); guard
    // against it by checking the accent's vlist shift.
    for (final tex in [
      r'\widehat{xyz}',
      r'\widetilde{xyz}',
      r'\overrightarrow{AB}',
    ]) {
      test('$tex places the stretchy accent above the base (no overlap)', () {
        final root = renderToBox(tex);
        // Find the accent VList: the one whose positions include the stretchy
        // SvgPathNode (directly, since the stretchy vlist has no inner kern).
        VList? accentVList;
        VListPosition? bodyPos;
        VListPosition? accentPos;
        for (final v in _flatten(root).whereType<VList>()) {
          for (final p in v.positions) {
            if (p.box is SvgPathNode) {
              accentVList = v;
              accentPos = p;
            }
          }
          if (accentVList == v) {
            // The other (elem) position in this vlist is the base body.
            bodyPos = v.positions.firstWhere((p) => p.box is! SvgPathNode);
          }
        }
        expect(accentVList, isNotNull, reason: 'stretchy accent uses a VList');
        final body = bodyPos!.box;
        final accentShift = accentPos!.shift;
        // Body baseline sits at shift 0; the accent must be RAISED (negative
        // downward shift) by the full base height, placing its baseline (the
        // accent has depth 0) at the top of the base — not over it.
        expect(
          accentShift,
          lessThan(bodyPos.shift - 1e-9),
          reason: 'accent must be raised above the body baseline',
        );
        expect(
          accentShift,
          closeTo(bodyPos.shift - body.height, 1e-6),
          reason: 'accent baseline sits exactly at body.height (no clearance '
              'kern dragging it onto the base)',
        );
        // The accent ink occupies [shift - height, shift]; its lowest point
        // must not dip below the top of the base (shift 0 == base baseline,
        // base top at -body.height). With shift == -body.height and depth 0,
        // the accent bottom is exactly at the base top.
        final accentBottom = accentShift; // depth 0
        final baseTop = bodyPos.shift - body.height;
        expect(
          accentBottom,
          closeTo(baseTop, 1e-6),
          reason: 'accent bottom rests at the base top, not inside it',
        );
      });
    }
  });
}
