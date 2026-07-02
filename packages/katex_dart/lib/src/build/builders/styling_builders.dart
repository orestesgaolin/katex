/// Builders for the "wrapper"/presentation groups: `font`, `color`, `sizing`,
/// `styling`, `text`, `mclass`, `overline`, `underline`, `kern`, `phantom`,
/// `rule`. Ported from the corresponding KaTeX `functions/*.ts` htmlBuilders.
library;

import 'package:katex_dart/src/ast/parse_node.dart' as ast;
import 'package:katex_dart/src/box/box_node.dart';
import 'package:katex_dart/src/build/build_common.dart';
import 'package:katex_dart/src/build/build_expression.dart';
import 'package:katex_dart/src/build/builders/units.dart';
import 'package:katex_dart/src/build/options.dart';
import 'package:katex_dart/src/build/style.dart';

/// Registers the wrapper/presentation builders into [registry].
void registerStylingBuilders(Map<String, GroupBuilder> registry) {
  registry['font'] = (node, options) =>
      _buildFont(node as ast.FontNode, options);
  registry['color'] = (node, options) =>
      _buildColor(node as ast.ColorNode, options);
  registry['sizing'] = (node, options) =>
      _buildSizing(node as ast.SizingNode, options);
  registry['styling'] = (node, options) =>
      _buildStyling(node as ast.StylingNode, options);
  registry['text'] = (node, options) =>
      _buildText(node as ast.TextNode, options);
  registry['mclass'] = (node, options) =>
      _buildMclass(node as ast.MclassNode, options);
  registry['overline'] = (node, options) =>
      _buildOverline(node as ast.OverlineNode, options);
  registry['underline'] = (node, options) =>
      _buildUnderline(node as ast.UnderlineNode, options);
  registry['kern'] = (node, options) =>
      _buildKern(node as ast.KernNode, options);
  registry['phantom'] = (node, options) =>
      _buildPhantom(node as ast.PhantomNode, options);
  registry['rule'] = (node, options) =>
      _buildRule(node as ast.RuleNode, options);
}

// ---- font ----------------------------------------------------------------

BoxNode _buildFont(ast.FontNode group, Options options) {
  return buildGroup(group.body, options.withFont(group.font));
}

// ---- color ----------------------------------------------------------------

BoxNode _buildColor(ast.ColorNode group, Options options) {
  final elements = buildExpression(
    group.body,
    options.withColor(group.color),
    isRealGroup: false,
  );
  // \color wraps in a fragment so the inner elements keep interacting with
  // neighbours (matching KaTeX's makeFragment).
  return makeFragment(elements);
}

// ---- sizing ----------------------------------------------------------------

BoxNode _buildSizing(ast.SizingNode group, Options options) {
  final newOptions = options.havingSize(group.size);
  return _sizingGroup(group.body, newOptions, options);
}

BoxNode _sizingGroup(
  List<ast.ParseNode> value,
  Options options,
  Options baseOptions,
) {
  // KaTeX scales each inner node's height/depth by the size ratio. The box
  // tree is immutable, so we wrap the whole fragment; the dimensions of the
  // children already reflect `options`, so for a uniform size change this is
  // equivalent. (Nested size changes are a T-019 refinement.)
  final inner = buildExpression(value, options, isRealGroup: false);
  return makeFragment(inner);
}

// ---- styling ----------------------------------------------------------------

BoxNode _buildStyling(ast.StylingNode group, Options options) {
  final newStyle = Style.fromStr(group.style);
  var newOptions = options.havingStyle(newStyle);
  if (group.resetFont ?? false) {
    newOptions = newOptions.withFont('');
  }
  return _sizingGroup(group.body, newOptions, options);
}

// ---- text ----------------------------------------------------------------

const Map<String, String> _textFontFamilies = {
  r'\textrm': 'textrm',
  r'\textsf': 'textsf',
  r'\texttt': 'texttt',
  r'\textnormal': 'textrm',
};
const Map<String, String> _textFontWeights = {
  r'\textbf': 'textbf',
  r'\textmd': 'textmd',
};
const Map<String, String> _textFontShapes = {
  r'\textit': 'textit',
  r'\textup': 'textup',
};

Options _optionsWithFont(ast.TextNode group, Options options) {
  final font = group.font;
  if (font == null) {
    return options;
  } else if (_textFontFamilies.containsKey(font)) {
    return options.withTextFontFamily(_textFontFamilies[font]!);
  } else if (_textFontWeights.containsKey(font)) {
    return options.withTextFontWeight(_textFontWeights[font]!);
  } else if (font == r'\emph') {
    return options.fontShape == 'textit'
        ? options.withTextFontShape('textup')
        : options.withTextFontShape('textit');
  } else if (_textFontShapes.containsKey(font)) {
    return options.withTextFontShape(_textFontShapes[font]!);
  }
  return options;
}

BoxNode _buildText(ast.TextNode group, Options options) {
  final newOptions = _optionsWithFont(group, options);
  final inner = buildExpression(group.body, newOptions, isRealGroup: true);
  return withAtomClass(
    makeSpan(inner, classes: const ['text'], options: newOptions),
    'mord',
    options: newOptions,
  );
}

// ---- mclass ----------------------------------------------------------------

BoxNode _buildMclass(ast.MclassNode group, Options options) {
  final elements = buildExpression(group.body, options, isRealGroup: true);
  return withAtomClass(
    makeFragment(elements),
    mclassName(group.mclass),
    options: options,
  );
}

// ---- overline / underline ---------------------------------------------------

BoxNode _buildOverline(ast.OverlineNode group, Options options) {
  final innerGroup = buildGroup(group.body, options.havingCrampedStyle());
  final defaultRuleThickness = options.fontMetrics().defaultRuleThickness;
  final line = RuleNode(width: innerGroup.width, height: defaultRuleThickness);
  final vlist = makeVList(
    positionType: VListPositionType.firstBaseline,
    children: [
      VListChild.elem(innerGroup),
      VListChild.kern(3 * defaultRuleThickness),
      VListChild.elem(line),
      VListChild.kern(defaultRuleThickness),
    ],
  );
  return withAtomClass(
    makeSpan([vlist], classes: const ['overline']),
    'mord',
    options: options,
  );
}

BoxNode _buildUnderline(ast.UnderlineNode group, Options options) {
  final innerGroup = buildGroup(group.body, options);
  final defaultRuleThickness = options.fontMetrics().defaultRuleThickness;
  final line = RuleNode(width: innerGroup.width, height: defaultRuleThickness);
  final vlist = makeVList(
    positionType: VListPositionType.top,
    positionData: innerGroup.height,
    children: [
      VListChild.kern(defaultRuleThickness),
      VListChild.elem(line),
      VListChild.kern(3 * defaultRuleThickness),
      VListChild.elem(innerGroup),
    ],
  );
  return withAtomClass(
    makeSpan([vlist], classes: const ['underline']),
    'mord',
    options: options,
  );
}

// ---- kern ----------------------------------------------------------------

BoxNode _buildKern(ast.KernNode group, Options options) {
  final size = calculateSize(group.dimension, options);
  return makeSpan(
    [KernNode(size)],
    classes: const ['mspace'],
    options: options,
  );
}

// ---- phantom ----------------------------------------------------------------

BoxNode _buildPhantom(ast.PhantomNode group, Options options) {
  final elements = buildExpression(
    group.body,
    options.withPhantom(),
    isRealGroup: false,
  );
  return makeFragment(elements);
}

// ---- rule ----------------------------------------------------------------

BoxNode _buildRule(ast.RuleNode group, Options options) {
  final width = calculateSize(group.width, options);
  final height = calculateSize(group.height, options);
  final shift = group.shift == null
      ? 0.0
      : calculateSize(group.shift!, options);
  return withAtomClass(
    RuleNode(width: width, height: height - shift, depth: shift),
    'mord',
    options: options,
  );
}
