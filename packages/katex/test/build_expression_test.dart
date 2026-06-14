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
    case EncloseNode(:final child):
      out.addAll(_flatten(child));
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

  // T-036 (RC-array) — `\hline` horizontal rules and `|`/`:` column separators.
  //
  // KaTeX `environments/array.ts` (htmlBuilder) draws:
  //   * `\hline`/`\hdashline` between rows → a full-array-width rule
  //     (`arrayRuleWidth` thick) stacked in the array vlist at the boundary.
  //   * column `|`/`:` separators → a thin vertical rule (`arrayRuleWidth`
  //     wide) spanning the array height, with `doubleRuleSep` between `||`.
  // Before this ticket the Dart builder emitted neither (only zero-width row
  // struts), so an `array` with rules rendered as bare entries. These tests
  // assert the rules now exist as visible (non-zero-extent) RuleNodes.
  group('array rules (T-036)', () {
    const display = KatexOptions(displayMode: true);

    // The visible rules are the only RuleNodes with BOTH a positive width and a
    // positive height — the per-row layout struts are zero-width.
    List<RuleNode> visibleRules(BoxNode root) => _flatten(root)
        .whereType<RuleNode>()
        .where((r) => r.width > 0 && (r.height + r.depth) > 0)
        .toList();

    // From LaTeX \showthe\arrayrulewidth — KaTeX's `fontMetrics.arrayRuleWidth`
    // is 0.04 em across all styles, and minRuleThickness defaults to 0.
    const arrayRuleWidth = 0.04;

    test('plain array (no colspec rules) emits no visible rules', () {
      final root = renderToBox(
        r'\begin{array}{cc} a&b \\ c&d \end{array}',
        options: display,
      );
      expect(visibleRules(root), isEmpty);
    });

    test(r'\hline + | draw one horizontal rule and one vertical rule', () {
      final root = renderToBox(
        r'\begin{array}{c|c} a & b \\ \hline c & d \end{array}',
        options: display,
      );
      final rules = visibleRules(root);
      // Vertical separator: width == arrayRuleWidth, tall.
      final verticals = rules
          .where((r) => (r.width - arrayRuleWidth).abs() < 1e-9)
          .toList();
      // Horizontal hline: height == arrayRuleWidth, wide.
      final horizontals = rules
          .where((r) => (r.height - arrayRuleWidth).abs() < 1e-9)
          .toList();
      expect(verticals, hasLength(1), reason: 'one | separator');
      expect(horizontals, hasLength(1), reason: r'one \hline');
      // The vertical separator spans (roughly) the whole array height; the
      // hline is much wider than it is tall.
      expect(verticals.single.height + verticals.single.depth, greaterThan(1));
      expect(horizontals.single.width, greaterThan(1));
    });

    test(r'\begin{array}{|c|c|} grid draws 3 verticals and 3 hlines', () {
      final root = renderToBox(
        r'\begin{array}{|c|c|} \hline a&b \\ \hline c&d \\ \hline \end{array}',
        options: display,
      );
      final rules = visibleRules(root);
      final verticals = rules
          .where((r) => (r.width - arrayRuleWidth).abs() < 1e-9)
          .length;
      final horizontals = rules
          .where((r) => (r.height - arrayRuleWidth).abs() < 1e-9)
          .length;
      expect(verticals, 3, reason: 'three | separators');
      expect(horizontals, 3, reason: r'three \hline rows');
    });

    test('hlines sit at distinct vertical positions', () {
      final root = renderToBox(
        r'\begin{array}{|c|c|} \hline a&b \\ \hline c&d \\ \hline \end{array}',
        options: display,
      );
      // The hline rules live in the outer vlist that wraps the table body;
      // their baseline shifts must be distinct (top / middle / bottom).
      final vlists = _flatten(root).whereType<VList>();
      final shifts = <double>[];
      for (final v in vlists) {
        for (final p in v.positions) {
          if (p.box is RuleNode && (p.box as RuleNode).width > 1) {
            shifts.add(p.shift);
          }
        }
      }
      expect(shifts, hasLength(3));
      expect(shifts.toSet(), hasLength(3), reason: 'all hline shifts distinct');
    });

    test('pmatrix/cases/aligned remain rule-free (no regression)', () {
      for (final tex in [
        r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}',
        r'f(x) = \begin{cases} 1 & x > 0 \\ 0 & x \le 0 \end{cases}',
        r'\begin{aligned} a &= b \\ c &= d \end{aligned}',
      ]) {
        final root = renderToBox(tex, options: display);
        expect(
          visibleRules(root),
          isEmpty,
          reason: 'no array rules expected in $tex',
        );
      }
    });
  });

  // T-033 (RC-3) — `\sqrt[n]{x}` root-index placement.
  //
  // KaTeX `functions/sqrt.ts` positions the optional index ("\rootBox") with:
  //   * a vertical raise  `toShift = 0.6 * (body.height - body.depth)` applied
  //     as the index VList's downward shift `-toShift` (so the VList depth is
  //     exactly `-toShift`);
  //   * fixed horizontal kerns from the `.sqrt > .root` CSS margins, themselves
  //     transcribed from the TeX `\r@@t` definition: `margin-left: 5mu`,
  //     `margin-right: -10mu`, with `1mu = 1/18 em`.
  // These numbers are independent of the index width, so they must be identical
  // for 1-, 2-, and 3-digit indices; only the index VList's own width grows.
  //
  // The values below were captured from ORIGINAL KaTeX's `__renderToDomTree`
  // (full float precision): for `\sqrt[3]{x}` the `.root` VList is
  // height=0.6585560000000001, depth=-0.3363360000000001, and the surd `body`
  // VList is height=0.8002800000000001, depth=0.23972 — giving
  // toShift = 0.6 * (0.8002800000000001 - 0.23972) = 0.3363360000000001.
  group(r'root index (\sqrt[n]{x}) placement', () {
    const muToEm = 1.0 / 18.0;
    const expectedLeftKern = 5 * muToEm; // \mkern 5mu
    const expectedRightKern = -10 * muToEm; // \mkern -10mu
    // toShift for \sqrt{x}: body.height 0.8002800000000001, depth 0.23972.
    const expectedToShift = 0.6 * (0.8002800000000001 - 0.23972);

    // The scriptscript single-digit glyph width (KaTeX `mord.mtight`); the
    // index is an ordgroup so an n-digit index is n times this wide.
    const digitWidth = 0.25;

    // Locates the `.root` wrapper span and the surd `.sqrt` span's two VLists:
    // the index VList (inside `.root`) and the surd body VList (the sibling).
    (SpanNode rootWrap, VList indexVList) findRoot(BoxNode root) {
      final wrap = _flatten(root)
          .whereType<SpanNode>()
          .firstWhere((s) => s.classes.contains('root'));
      final vlist = _flatten(wrap).whereType<VList>().first;
      return (wrap, vlist);
    }

    test(r'no index: \sqrt{x} emits no .root wrapper (no regression)', () {
      final nodes = _flatten(renderToBox(r'\sqrt{x}'));
      expect(
        nodes.whereType<SpanNode>().where((s) => s.classes.contains('root')),
        isEmpty,
        reason: r'plain \sqrt{x} must not introduce a root-index wrapper',
      );
    });

    for (final (label, tex, digits) in [
      ('1-digit', r'\sqrt[3]{x}', 1),
      ('2-digit', r'\sqrt[10]{x}', 2),
      ('3-digit', r'\sqrt[123]{x}', 3),
    ]) {
      test('$label index: vertical raise matches KaTeX exactly', () {
        final root = renderToBox(tex);
        final (_, indexVList) = findRoot(root);
        // KaTeX shifts the index VList down by -toShift, so its depth is
        // exactly -toShift (the VList has a single zero-depth child).
        expect(
          indexVList.depth,
          closeTo(-expectedToShift, 1e-12),
          reason: 'index raise must be 0.6*(body.height-body.depth)',
        );
        // The raise is width-independent: identical for every digit count.
        expect(indexVList.depth, closeTo(-0.3363360000000001, 1e-12));
      });

      test('$label index: horizontal kerns are 5mu / -10mu', () {
        final root = renderToBox(tex);
        final (wrap, _) = findRoot(root);
        // The .sqrt span holds: [Kern(5mu), root, Kern(-10mu), body]. Find the
        // kerns flanking the `.root` wrapper.
        final sqrtSpan = _flatten(root)
            .whereType<SpanNode>()
            .firstWhere((s) => s.classes.contains('sqrt'));
        final kids = sqrtSpan.children;
        final wrapIndex = kids.indexOf(wrap);
        expect(wrapIndex, greaterThan(0), reason: 'root has a leading kern');
        final left = kids[wrapIndex - 1];
        final right = kids[wrapIndex + 1];
        expect(left, isA<KernNode>());
        expect(right, isA<KernNode>());
        expect(
          (left as KernNode).width,
          closeTo(expectedLeftKern, 1e-12),
          reason: r'left margin must be \mkern 5mu = 5/18 em',
        );
        expect(
          (right as KernNode).width,
          closeTo(expectedRightKern, 1e-12),
          reason: r'right margin must be \mkern -10mu = -10/18 em',
        );
      });

      test('$label index: VList width scales with digit count', () {
        final root = renderToBox(tex);
        final (_, indexVList) = findRoot(root);
        expect(
          indexVList.width,
          closeTo(digits * digitWidth, 1e-9),
          reason: 'an $digits-digit index is $digits x the digit width',
        );
      });
    }
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

    test(r'\overrightarrow{AB} uses the right-anchored rightarrow SVG', () {
      // T-036 (RC-arrow): the rightarrow's head sits at the RIGHT end of the
      // 400em path, so it must be sliced with `xMaxYMin` (top-RIGHT anchored)
      // or the head is clipped off the right (the bug = `xMinYMin`).
      final nodes = _flatten(renderToBox(r'\overrightarrow{AB}'));
      final arrow = nodes.whereType<SvgPathNode>().where(
        (s) => s.pathName == 'rightarrow',
      );
      expect(arrow, isNotEmpty, reason: 'stretchy arrow uses rightarrow path');
      expect(
        arrow.first.preserveAspectRatio,
        SvgPreserveAspectRatio.xMaxYMinSlice,
        reason: 'right-arrows are 400em-wide & right-anchored (head stays)',
      );
    });

    test(r'\overleftarrow{AB} uses the left-anchored leftarrow SVG', () {
      // The leftarrow's head sits at the LEFT end of the 400em path, so it is
      // sliced with `xMinYMin` (top-left anchored) to keep the head visible.
      final nodes = _flatten(renderToBox(r'\overleftarrow{AB}'));
      final arrow = nodes.whereType<SvgPathNode>().where(
        (s) => s.pathName == 'leftarrow',
      );
      expect(arrow, isNotEmpty, reason: 'stretchy arrow uses leftarrow path');
      expect(
        arrow.first.preserveAspectRatio,
        SvgPreserveAspectRatio.xMinYMinSlice,
        reason: 'left-arrows are 400em-wide & left-anchored (head stays)',
      );
    });

    test(r'\overleftrightarrow{AB} draws both halves with both heads', () {
      // Paired arrows render two half-width sliced SVGs: a left half
      // (leftarrow, left-anchored, keeps the left head) and a right half
      // (rightarrow, right-anchored, keeps the right head).
      final nodes = _flatten(renderToBox(r'\overleftrightarrow{AB}'));
      final svgs = nodes.whereType<SvgPathNode>().toList();
      final leftHalf = svgs.where((s) => s.pathName == 'leftarrow');
      final rightHalf = svgs.where((s) => s.pathName == 'rightarrow');
      expect(leftHalf, isNotEmpty, reason: 'left half uses leftarrow path');
      expect(rightHalf, isNotEmpty, reason: 'right half uses rightarrow path');
      expect(
        leftHalf.first.preserveAspectRatio,
        SvgPreserveAspectRatio.xMinYMinSlice,
        reason: 'left head anchored at the left edge',
      );
      expect(
        rightHalf.first.preserveAspectRatio,
        SvgPreserveAspectRatio.xMaxYMinSlice,
        reason: 'right head anchored at the right edge',
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

  // ---------------------------------------------------------------------------
  // Big-operator scripts: limits (\sum/\prod/\bigcup) stack above/below in
  // displaystyle, while nolimits integral-class ops (\int/\oint/\iint) put
  // their scripts to the side (sup up-right, sub down-right), with the slanted
  // glyph's italic correction folded into the subscript's left margin so the
  // lower bound tucks under the sign instead of overlapping it.
  //
  // Mirrors KaTeX op.ts / supsub.ts: `\int` is `limits: false`, so its scripts
  // render as ordinary sup/sub even in displaystyle.
  // ---------------------------------------------------------------------------
  group('big-operator scripts (limits vs nolimits)', () {
    // Finds the .msupsub span (the side sup/sub column) if present.
    SpanNode? findMsupsub(BoxNode root) {
      for (final n in _flatten(root)) {
        if (n is SpanNode && n.classes.contains('msupsub')) {
          return n;
        }
      }
      return null;
    }

    // Collects the leaf GlyphNodes' code points in left-to-right order.
    List<int> glyphs(BoxNode root) => _flatten(root)
        .whereType<GlyphNode>()
        .map((g) => g.codepoint)
        .toList();

    test(r'\int_0^1 uses the side supsub layout (msupsub), not stacked limits',
        () {
      final root = renderToBox(
        r'\int_0^1',
        options: const KatexOptions(displayMode: true),
      );
      // Side layout: there must be a .msupsub span holding the scripts.
      expect(findMsupsub(root), isNotNull,
          reason: r'\int scripts must render to the side (nolimits)');
      // The integral sign (U+222B) must be present as a bare glyph and the
      // bounds 0/1 sit beside it.
      expect(glyphs(root), contains(0x222b),
          reason: 'integral sign glyph should be rendered');
    });

    test(r'\int_0^1 subscript carries a negative italic-correction left kern',
        () {
      final root = renderToBox(
        r'\int_0^1',
        options: const KatexOptions(displayMode: true),
      );
      final msupsub = findMsupsub(root)!;
      // Inside the msupsub vlist, the subscript row is an HBox whose first
      // child is a negative KernNode (= -italic of the integral sign). The
      // superscript row has no such leading negative kern. This is what tucks
      // the lower bound under the slanted sign.
      final negKerns = _flatten(msupsub)
          .whereType<KernNode>()
          .where((k) => k.width < -1e-6)
          .toList();
      expect(negKerns, isNotEmpty,
          reason: 'subscript must be pulled left by the integral italic '
              'correction (KaTeX marginLeft = -base.italic)');
    });

    test(r'\int_0^1 side scripts carry the scriptspace (0.05em) right kern',
        () {
      // KaTeX appends `marginRight = 0.5pt / ptPerEm / multiplier` (= 0.05em at
      // 10 ptPerEm, displaystyle) to *every* side-script row — both in the
      // generic supsub builder and the op nolimits DOM. Without it the bounds
      // sit a hair too tight and the operator's advance is narrower than
      // KaTeX's, throwing off the bound/sign offset. Each of the two script
      // rows (sup `1`, sub `0`) must therefore carry a +0.05em trailing kern.
      final root = renderToBox(
        r'\int_0^1',
        options: const KatexOptions(displayMode: true),
      );
      final msupsub = findMsupsub(root)!;
      final scriptspaceKerns = _flatten(msupsub)
          .whereType<KernNode>()
          .where((k) => (k.width - 0.05).abs() < 1e-6)
          .toList();
      expect(scriptspaceKerns, hasLength(2),
          reason: 'both the sup and sub rows trail a 0.05em scriptspace kern '
              '(KaTeX marginRight)');
    });

    test(r'\oint_C places the single subscript to the side', () {
      final root = renderToBox(
        r'\oint_C',
        options: const KatexOptions(displayMode: true),
      );
      expect(findMsupsub(root), isNotNull,
          reason: r'\oint is nolimits: subscript goes to the side');
    });

    test(r'\sum_{i=0}^n keeps limits: scripts stack, no msupsub', () {
      final root = renderToBox(
        r'\sum_{i=0}^n',
        options: const KatexOptions(displayMode: true),
      );
      // Limits layout stacks via the op-limits VList; it must NOT route
      // through the side .msupsub column.
      expect(findMsupsub(root), isNull,
          reason: r'\sum in displaystyle stacks limits, not side scripts');
      // The script column is taller than the bare operator: depth (i=0 below)
      // and height (n above) both extend past the glyph.
      final bare = renderToBox(
        r'\sum',
        options: const KatexOptions(displayMode: true),
      );
      expect(root.height, greaterThan(bare.height + 1e-6),
          reason: r'upper limit n raises the height above the bare \sum');
      expect(root.depth, greaterThan(bare.depth + 1e-6),
          reason: r'lower limit i=0 extends the depth below the bare \sum');
    });

    test(r'\prod_{i=1}^n and \bigcup_{i=1}^n keep limits (no side column)', () {
      // Isolated big-op scripts (no trailing `A_i`, whose own subscript would
      // legitimately introduce a separate msupsub) must stack as limits.
      for (final tex in [r'\prod_{i=1}^n', r'\bigcup_{i=1}^n']) {
        final root = renderToBox(
          tex,
          options: const KatexOptions(displayMode: true),
        );
        expect(findMsupsub(root), isNull,
            reason: '$tex must stack limits above/below, not to the side');
      }
    });

    test(r'\int_0^1 in inline (non-display) mode also uses side scripts', () {
      final root = renderToBox(r'\int_0^1');
      expect(findMsupsub(root), isNotNull,
          reason: r'\int is nolimits in every style');
    });
  });

  // T-033 (RC-1) — supsub horizontal placement: scriptspace + base italic
  // correction. KaTeX renders the base symbol with `margin-right: italic`,
  // every script row with `margin-right: 0.5pt/ptPerEm/multiplier`
  // (scriptspace), and a subscript with a compensating `margin-left: -italic`
  // so only the superscript is offset by the slanted base. The box tree models
  // those margins as kerns; these tests pin the exact em values.
  group('supsub italic correction + scriptspace (RC-1)', () {
    // Finds the msupsub span anywhere in the built tree.
    SpanNode msupsubOf(BoxNode root) => _flatten(root)
        .whereType<SpanNode>()
        .firstWhere((s) => s.classes.contains('msupsub'));

    // The HBox holding the base + (optional italic kern) + msupsub span.
    HBox supsubHBoxOf(BoxNode root) =>
        _flatten(root).whereType<HBox>().firstWhere(
          (h) => h.children.any(
            (c) => c is SpanNode && c.classes.contains('msupsub'),
          ),
        );

    test('scriptspace (0.05em) trails the superscript row', () {
      // x has italic 0, so the only horizontal kern in the sup row is the
      // 0.5pt / 10ptPerEm / 1.0 = 0.05em scriptspace.
      final msupsub = msupsubOf(renderToBox('x^2'));
      final kerns = _flatten(msupsub).whereType<KernNode>().toList();
      expect(kerns, isNotEmpty, reason: 'sup row carries a scriptspace kern');
      expect(
        kerns.any((k) => (k.width - 0.05).abs() < 1e-6),
        isTrue,
        reason: 'scriptspace must be exactly 0.05em (0.5pt / 10ptPerEm)',
      );
    });

    test('zero-italic base (x) gets no italic kern before the scripts', () {
      // Math-Italic x has italic 0, so no kern is inserted between base and
      // msupsub: the HBox is [base-span, msupsub-span].
      final hbox = supsubHBoxOf(renderToBox('x^2'));
      expect(
        hbox.children.whereType<KernNode>(),
        isEmpty,
        reason: 'x (italic 0) needs no base-italic kern',
      );
    });

    test('slanted base (V) shifts the superscript by its italic (0.2222em)',
        () {
      // Math-Italic V has italic 0.22222. A bare base-italic kern of that size
      // must sit between the base span and the msupsub span.
      final hbox = supsubHBoxOf(renderToBox('V^2'));
      final baseKern = hbox.children.whereType<KernNode>().toList();
      expect(baseKern, hasLength(1), reason: 'one base-italic kern for V');
      expect(
        baseKern.single.width,
        closeTo(0.22222, 1e-4),
        reason: 'base-italic kern equals V italic correction',
      );
    });

    test('subscript cancels the base italic via a negative left kern', () {
      // For V^2_i the base-italic kern (+0.2222) pushes the msupsub right; the
      // subscript row must carry a compensating -0.2222 leading kern so the
      // subscript sits under the base, while the superscript stays offset.
      final root = renderToBox('V^2_i');
      final hbox = supsubHBoxOf(root);
      final baseKern = hbox.children.whereType<KernNode>().single;
      expect(baseKern.width, closeTo(0.22222, 1e-4));

      final msupsub = msupsubOf(root);
      final negKerns = _flatten(msupsub)
          .whereType<KernNode>()
          .where((k) => k.width < 0)
          .toList();
      expect(negKerns, hasLength(1), reason: 'subscript has one negative kern');
      expect(
        negKerns.single.width,
        closeTo(-0.22222, 1e-4),
        reason: 'subscript marginLeft cancels the base italic',
      );
    });

    test('base italic does not change root height/depth (RC-1 is horizontal)',
        () {
      // The fix is purely horizontal: V^2 vertical metrics are unaffected.
      final root = renderToBox('V^2');
      expect(root.height, greaterThan(0));
      expect(root.depth, closeTo(0, 1e-9));
    });
  });

  // T-034 (RC-c) — genfrac nested-fraction depth + `\cfrac` strut.
  //
  // The bug: `\cfrac` was missing the `\strut` that KaTeX inserts into the
  // numerator (genfrac.ts: numerm.height = max(numerm.height, 8.5/ptPerEm),
  // numerm.depth = max(numerm.depth, 3.5/ptPerEm)). Without it, `\cfrac` chains
  // were too short and a `\sqrt{\cfrac{…}}` radicand was undersized.
  //
  // The reference numbers below are ORIGINAL KaTeX
  // `__renderToDomTree(...).{height, depth}` in displayMode (full precision),
  // captured from the pinned KaTeX in reference/. Plain `\frac` is included as
  // a no-regression guard.
  group('genfrac nested-fraction depth (T-034 RC-c)', () {
    const disp = KatexOptions(displayMode: true);

    void expectRoot(String tex, double h, double d) {
      final box = renderToBox(tex, options: disp);
      expect(box.height, closeTo(h, 5e-4), reason: 'height of $tex');
      expect(box.depth, closeTo(d, 5e-4), reason: 'depth of $tex');
    }

    test(r'plain \frac{a}{b} is unchanged (no regression)', () {
      expectRoot(r'\frac{a}{b}', 1.10756, 0.68600);
    });

    test(r'\frac with nested-fraction denominator', () {
      // The denominator is a tall sub-fraction; the clearance-adjusted denom
      // shift must NOT double-count its extent.
      expectRoot(r'\frac{a}{\frac{b}{c}}', 1.10756, 1.11511);
    });

    test(r'\frac with nested-fraction numerator', () {
      expectRoot(r'\frac{\frac{a}{b}}{c}', 1.43039, 0.68600);
    });

    test(r'\cfrac inserts the numerator strut', () {
      // `\cfrac{1}{1+x}` must be strictly taller than `\frac{1}{1+x}` because
      // the strut floors the numerator height at 8.5/ptPerEm = 0.85.
      final cfrac = renderToBox(r'\cfrac{1}{1+x}', options: disp);
      final frac = renderToBox(r'\frac{1}{1+x}', options: disp);
      expect(cfrac.height, greaterThan(frac.height));
      expect(cfrac.height, closeTo(1.59000, 5e-4));
      expect(cfrac.depth, closeTo(0.76933, 5e-4));
    });

    test(r'\cfrac chain matches KaTeX', () {
      expectRoot(r'\cfrac{1}{1+\cfrac{1}{1+x}}', 1.59000, 2.24933);
    });

    test(r'\sqrt{\cfrac{…}} radicand is correctly sized', () {
      expectRoot(
        r'\sqrt{\cfrac{\infty111}{1111+\cfrac{111111111}{111+x}}}',
        1.81775,
        2.24933,
      );
    });
  });
}
