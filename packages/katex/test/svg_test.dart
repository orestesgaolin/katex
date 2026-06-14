import 'package:katex/katex.dart' show renderToSvg;
import 'package:katex/src/box/box_node.dart';
import 'package:katex/src/font/font_metrics.dart';
import 'package:katex/src/font/font_types.dart';
import 'package:katex/src/svg/svg_serializer.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

/// Builds a [GlyphNode] with explicit metrics so the test does not depend on
/// the generated metric tables.
GlyphNode glyph(
  String char, {
  KatexFont font = const KatexFont(
    KatexFontFamily.math,
    KatexFontVariant.italic,
  ),
  double width = 0.5,
  double height = 0.7,
  double depth = 0,
  double italic = 0,
  double skew = 0,
  double size = 1.0,
}) {
  return GlyphNode(
    codepoint: char.codeUnitAt(0),
    font: font,
    metrics: CharacterMetrics(
      depth: depth,
      height: height,
      italic: italic,
      skew: skew,
      width: width,
    ),
    size: size,
  );
}

/// Mirrors the serializer's compact number formatting (integers drop `.0`,
/// otherwise up to 5 dp with trailing zeros trimmed).
String _compact(double v) {
  if (v == 0) return '0';
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  var s = v.toStringAsFixed(5).replaceFirst(RegExp(r'0+$'), '');
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}

void main() {
  group('serializeBox', () {
    test('single glyph: valid XML with a <text> and a viewBox', () {
      final node = glyph('a');
      final svg = serializeBox(node);

      // Parses as valid XML.
      final doc = XmlDocument.parse(svg);
      final root = doc.rootElement;
      expect(root.name.local, 'svg');

      // Exactly one <text> with the math italic family.
      final texts = doc.findAllElements('text').toList();
      expect(texts, hasLength(1));
      expect(texts.first.getAttribute('font-family'), 'KaTeX_Math');
      expect(texts.first.getAttribute('font-style'), 'italic');
      expect(texts.first.innerText, 'a');

      // viewBox reflects width * fontSize and (height+depth) * fontSize.
      // Numbers are emitted compactly (integers drop a trailing `.0`).
      // 0.5 * 44 = 22, 0.7 * 44 = 30.8.
      final vb = root.getAttribute('viewBox');
      expect(vb, '0 0 22 30.8');
      expect(root.getAttribute('width'), '22');
      expect(root.getAttribute('height'), '30.8');
    });

    test('embeds all 12 fonts as @font-face data-URIs', () {
      final svg = serializeBox(glyph('x'));
      XmlDocument.parse(svg); // well-formed

      expect('@font-face'.allMatches(svg).length, 12);
      expect(svg, contains('data:font/truetype;charset=utf-8;base64,'));
      expect(svg, contains("font-family:'KaTeX_Main'"));
      expect(svg, contains("font-family:'KaTeX_Math'"));
      // Bold variant → weight 700; italic variant → style italic.
      expect(svg, contains('font-weight:700'));
      expect(svg, contains('font-style:italic'));
    });

    test('HBox of two glyphs advances x for the second child', () {
      final node = HBox([
        glyph('a'),
        glyph('b', width: 0.6),
      ]);
      final svg = serializeBox(node);
      final doc = XmlDocument.parse(svg);

      final texts = doc.findAllElements('text').toList();
      expect(texts, hasLength(2));

      // The second glyph is wrapped in a translate group at x = 0.5*44 = 22.
      expect(svg, contains('translate(22,0)'));

      // Root width is the sum of child widths: (0.5 + 0.6) * 44 = 48.4.
      expect(doc.rootElement.getAttribute('width'), '48.4');
    });

    test('KernNode advances x without emitting a node', () {
      final node = HBox([
        glyph('a'),
        const KernNode(0.25),
        glyph('b'),
      ]);
      final svg = serializeBox(node);
      final doc = XmlDocument.parse(svg);

      expect(doc.findAllElements('text').toList(), hasLength(2));
      // Second glyph placed after glyph (0.5) + kern (0.25) = 0.75 em → 33.
      expect(svg, contains('translate(33,0)'));
    });

    test('VList with a rule between two HBoxes (fraction-like)', () {
      // Numerator above baseline, rule on the axis, denominator below.
      final numerator = HBox([glyph('a')]);
      final denominator = HBox([glyph('b')]);
      const rule = RuleNode(width: 0.5, height: 0.04);

      final vlist = VList(
        positionType: VListPositionType.individualShift,
        children: [
          VListChild.elem(numerator, shift: -0.5),
          const VListChild.elem(rule),
          VListChild.elem(denominator, shift: 0.7),
        ],
      );

      final svg = serializeBox(vlist);
      final doc = XmlDocument.parse(svg);

      // The fraction bar is a <rect>.
      final rects = doc.findAllElements('rect').toList();
      expect(rects, hasLength(1));
      expect(rects.first.getAttribute('width'), '22'); // 0.5 * 44

      // Two glyphs (numerator + denominator).
      expect(doc.findAllElements('text').toList(), hasLength(2));

      // viewBox height spans the whole vlist (height + depth). The serializer
      // formats it compactly via the same rounding rule used for the rect.
      final expectedH = (vlist.height + vlist.depth) * defaultFontSize;
      expect(
        doc.rootElement.getAttribute('height'),
        _compact(expectedH),
      );
    });

    test('SpanNode applies color as fill', () {
      final node = SpanNode(
        [glyph('a')],
        color: '#ff0000',
      );
      final svg = serializeBox(node);
      final doc = XmlDocument.parse(svg);

      // A <g fill="#ff0000"> wraps the child text.
      final colored = doc
          .findAllElements('g')
          .where((g) => g.getAttribute('fill') == '#ff0000')
          .toList();
      expect(colored, hasLength(1));
      expect(colored.first.findAllElements('text').toList(), hasLength(1));
    });

    test('XML special characters in glyphs are escaped', () {
      final node = HBox([
        glyph('<'),
        glyph('&'),
        glyph('>'),
      ]);
      final svg = serializeBox(node);

      // Parses despite the raw <, &, > characters.
      final doc = XmlDocument.parse(svg);
      final texts =
          doc.findAllElements('text').map((t) => t.innerText).toList();
      expect(texts, containsAll(<String>['<', '&', '>']));
      expect(svg, contains('&lt;'));
      expect(svg, contains('&amp;'));
      expect(svg, contains('&gt;'));
    });

    test('custom fontSize scales the drawing', () {
      final node = glyph('a');
      final svg = serializeBox(node, fontSize: 100);
      final doc = XmlDocument.parse(svg);
      expect(doc.rootElement.getAttribute('width'), '50'); // 0.5 * 100
      expect(
        doc.findAllElements('text').first.getAttribute('font-size'),
        '100',
      );
    });

    test('SvgPathNode with geometry emits a scaled, sliced <path>', () {
      const node = SvgPathNode(
        pathName: 'sqrtMain',
        pathData: 'M95,702 H400000 z',
        viewBoxWidth: 400000,
        viewBoxHeight: 1080,
        width: 1,
        height: 1,
        preserveAspectRatio: SvgPreserveAspectRatio.xMinYMinSlice,
      );
      final svg = serializeBox(node);
      final doc = XmlDocument.parse(svg);
      final path = doc.findAllElements('path').single;
      expect(path.getAttribute('d'), 'M95,702 H400000 z');
      // Nested <svg> carries the viewBox + slice mapping.
      final inner = doc.findAllElements('svg').firstWhere(
        (e) => e.getAttribute('preserveAspectRatio') != null,
      );
      expect(inner.getAttribute('viewBox'), '0 0 400000 1080');
      expect(inner.getAttribute('preserveAspectRatio'), 'xMinYMin slice');
    });

    test('SvgPathNode with empty geometry stays well-formed', () {
      const node = SvgPathNode(
        pathName: 'unknown',
        pathData: '',
        viewBoxWidth: 100,
        viewBoxHeight: 100,
        width: 1,
        height: 1,
      );
      final svg = serializeBox(node);
      XmlDocument.parse(svg);
      expect(svg, contains('SvgPathNode'));
    });

    test(r'renderToSvg(\sqrt{x}) emits a surd <path>; valid XML', () {
      final svg = renderToSvg(r'\sqrt{x}');
      final doc = XmlDocument.parse(svg);
      expect(doc.findAllElements('path'), isNotEmpty);
    });
  });
}
