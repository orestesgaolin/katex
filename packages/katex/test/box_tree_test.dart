import 'package:katex/src/box/box_node.dart';
import 'package:katex/src/font/font_metrics.dart';
import 'package:katex/src/font/font_types.dart';
import 'package:test/test.dart';

void main() {
  // A small tolerance for floating-point comparisons of em dimensions.
  const tol = 1e-9;

  group('GlyphNode', () {
    test('derives dimensions from explicit metrics scaled by size', () {
      const metrics = CharacterMetrics(
        depth: 0.2,
        height: 0.7,
        italic: 0.05,
        skew: 0,
        width: 0.5,
      );
      final glyph = GlyphNode(
        codepoint: 0x41, // 'A'
        font: const KatexFont(KatexFontFamily.math, KatexFontVariant.italic),
        metrics: metrics,
        size: 2,
      );

      expect(glyph.height, closeTo(1.4, tol));
      expect(glyph.depth, closeTo(0.4, tol));
      expect(glyph.width, closeTo(1.0, tol));
      expect(glyph.scaledItalic, closeTo(0.1, tol));
      expect(glyph.text, 'A');
    });

    test('fromCodepoint resolves metrics from the bundled font tables', () {
      // 'A' (0x41) exists in Main-Regular; confirm dimensions match the table.
      final expected = getCharacterMetrics('A', 'Main-Regular', Mode.math);
      expect(expected, isNotNull);

      final glyph = GlyphNode.fromCodepoint(
        codepoint: 0x41,
        font: const KatexFont(KatexFontFamily.main, KatexFontVariant.regular),
      );
      expect(glyph, isNotNull);
      expect(glyph!.height, closeTo(expected!.height, tol));
      expect(glyph.depth, closeTo(expected.depth, tol));
      expect(glyph.width, closeTo(expected.width, tol));
    });
  });

  group('HBox', () {
    test('width sums children; height/depth are max over children', () {
      final a = GlyphNode(
        codepoint: 0x41,
        font: const KatexFont(KatexFontFamily.main, KatexFontVariant.regular),
        metrics: const CharacterMetrics(
          depth: 0,
          height: 0.7,
          italic: 0,
          skew: 0,
          width: 0.5,
        ),
      );
      final b = GlyphNode(
        codepoint: 0x67, // 'g' — has depth (descender)
        font: const KatexFont(KatexFontFamily.main, KatexFontVariant.regular),
        metrics: const CharacterMetrics(
          depth: 0.2,
          height: 0.45,
          italic: 0,
          skew: 0,
          width: 0.4,
        ),
      );

      final box = HBox([a, b]);

      expect(box.width, closeTo(0.9, tol)); // 0.5 + 0.4
      expect(box.height, closeTo(0.7, tol)); // max(0.7, 0.45)
      expect(box.depth, closeTo(0.2, tol)); // max(0.0, 0.2)
    });

    test('KernNode contributes only width', () {
      const kern = KernNode(0.25);
      expect(kern.width, closeTo(0.25, tol));
      expect(kern.height, 0);
      expect(kern.depth, 0);

      final a = GlyphNode(
        codepoint: 0x41,
        font: const KatexFont(KatexFontFamily.main, KatexFontVariant.regular),
        metrics: const CharacterMetrics(
          depth: 0,
          height: 0.7,
          italic: 0,
          skew: 0,
          width: 0.5,
        ),
      );
      final box = HBox([a, kern, a]);
      expect(box.width, closeTo(1.25, tol)); // 0.5 + 0.25 + 0.5
      expect(box.height, closeTo(0.7, tol));
      expect(box.depth, closeTo(0.0, tol));
    });
  });

  group('VList', () {
    GlyphNode glyph({
      required double height,
      required double depth,
      required double width,
    }) =>
        GlyphNode(
          codepoint: 0x41,
          font:
              const KatexFont(KatexFontFamily.main, KatexFontVariant.regular),
          metrics: CharacterMetrics(
            depth: depth,
            height: height,
            italic: 0,
            skew: 0,
            width: width,
          ),
        );

    test('individualShift positions and dimensions match makeVList math', () {
      final e0 = glyph(height: 0.7, depth: 0.2, width: 0.5);
      final e1 = glyph(height: 0.4, depth: 0.1, width: 0.3);

      final vlist = VList(
        positionType: VListPositionType.individualShift,
        children: [
          VListChild.elem(e0),
          VListChild.elem(e1, shift: -0.5),
        ],
      );

      // Hand-computed via the makeVList port (see box_node.dart):
      //   depth = -minPos = 0.2, height = maxPos = 0.9, width = max widths.
      expect(vlist.height, closeTo(0.9, tol));
      expect(vlist.depth, closeTo(0.2, tol));
      expect(vlist.width, closeTo(0.5, tol));

      // For individualShift the resolved downward shifts equal the inputs.
      expect(vlist.positions.length, 2);
      expect(vlist.positions[0].shift, closeTo(0.0, tol));
      expect(vlist.positions[1].shift, closeTo(-0.5, tol));
    });

    test('top mode: height equals positionData; kerns affect depth', () {
      final e0 = glyph(height: 0.5, depth: 0.1, width: 0.4);
      final e1 = glyph(height: 0.3, depth: 0, width: 0.6);

      final vlist = VList(
        positionType: VListPositionType.top,
        positionData: 0.5,
        children: [
          VListChild.elem(e0),
          const VListChild.kern(0.2),
          VListChild.elem(e1),
        ],
      );

      // Hand-computed: depth = 0.6, height = 0.5 (== top positionData).
      expect(vlist.height, closeTo(0.5, tol));
      expect(vlist.depth, closeTo(0.6, tol));
      expect(vlist.width, closeTo(0.6, tol));
      expect(vlist.positions[0].shift, closeTo(0.5, tol));
      expect(vlist.positions[1].shift, closeTo(-0.2, tol));
    });

    test('firstBaseline aligns baseline with first child', () {
      final e0 = glyph(height: 0.6, depth: 0.15, width: 0.4);

      final vlist = VList(
        positionType: VListPositionType.firstBaseline,
        children: [VListChild.elem(e0)],
      );

      // Single child: baseline aligned, so height = h0, depth = d0, shift = 0.
      expect(vlist.height, closeTo(0.6, tol));
      expect(vlist.depth, closeTo(0.15, tol));
      expect(vlist.positions.single.shift, closeTo(0.0, tol));
    });
  });

  group('RuleNode', () {
    test('reports its explicit dimensions', () {
      const rule = RuleNode(width: 1.5, height: 0.04, depth: 0.01);
      expect(rule.width, 1.5);
      expect(rule.height, 0.04);
      expect(rule.depth, 0.01);
    });
  });

  group('SpanNode', () {
    test('encompasses children and carries metadata', () {
      final a = GlyphNode(
        codepoint: 0x41,
        font: const KatexFont(KatexFontFamily.main, KatexFontVariant.regular),
        metrics: const CharacterMetrics(
          depth: 0.1,
          height: 0.7,
          italic: 0,
          skew: 0,
          width: 0.5,
        ),
      );
      final span = SpanNode(
        [a, a],
        color: '#ff0000',
        classes: const ['mord'],
      );
      expect(span.width, closeTo(1.0, tol));
      expect(span.height, closeTo(0.7, tol));
      expect(span.depth, closeTo(0.1, tol));
      expect(span.color, '#ff0000');
      expect(span.classes, ['mord']);
    });
  });

  group('SvgPathNode', () {
    test('carries resolved geometry + explicit dims; derives viewBox', () {
      const node = SvgPathNode(
        pathName: 'sqrtMain',
        pathData: 'M0 0 H400000 z',
        viewBoxWidth: 400000,
        viewBoxHeight: 1080,
        width: 1,
        height: 1.2,
        depth: 0.2,
        preserveAspectRatio: SvgPreserveAspectRatio.xMinYMinSlice,
      );
      expect(node.pathName, 'sqrtMain');
      expect(node.pathData, 'M0 0 H400000 z');
      expect(node.width, 1.0);
      expect(node.height, 1.2);
      expect(node.depth, 0.2);
      expect(node.viewBox, '0 0 400000 1080');
      expect(node.preserveAspectRatio, SvgPreserveAspectRatio.xMinYMinSlice);
    });
  });

  test('BoxNode subtypes are exhaustively switchable (sealed)', () {
    final nodes = <BoxNode>[
      const KernNode(0.1),
      const RuleNode(width: 1, height: 0.1),
      const SvgPathNode(
        pathName: 'x',
        pathData: 'M0 0z',
        viewBoxWidth: 100,
        viewBoxHeight: 100,
        width: 1,
        height: 1,
      ),
    ];
    for (final node in nodes) {
      final label = switch (node) {
        GlyphNode() => 'glyph',
        HBox() => 'hbox',
        KernNode() => 'kern',
        VList() => 'vlist',
        RuleNode() => 'rule',
        SpanNode() => 'span',
        SvgPathNode() => 'svg',
      };
      expect(label, isNotEmpty);
    }
  });
}
