/// Builders for the symbol/ordgroup parse nodes: `ordgroup`, `mathord`,
/// `textord`, `atom`, `spacing`. Ports of KaTeX `functions/ordgroup.ts`,
/// `functions/symbolsOrd.ts`, `functions/symbolsOp.ts`,
/// `functions/symbolsSpacing.ts`.
library;

import 'package:katex/src/ast/parse_node.dart';
import 'package:katex/src/box/box_node.dart';
import 'package:katex/src/build/build_common.dart';
import 'package:katex/src/build/build_expression.dart';
import 'package:katex/src/build/options.dart';
import 'package:katex/src/parse/parse_error.dart';
import 'package:katex/src/symbols/symbols.dart';
import 'package:katex/src/types.dart';

/// Registers the symbol/ordgroup builders into [registry].
void registerSymbolBuilders(Map<String, GroupBuilder> registry) {
  registry['ordgroup'] = (node, options) =>
      _buildOrdgroup(node as OrdGroupNode, options);
  registry['mathord'] = (node, options) =>
      _buildOrd(node, options, isTextord: false);
  registry['textord'] = (node, options) =>
      _buildOrd(node, options, isTextord: true);
  registry['atom'] = (node, options) => _buildAtom(node as AtomNode, options);
  registry['spacing'] = (node, options) =>
      _buildSpacing(node as SpacingNode, options);
}

// A "tight" expression is script/scriptscript style; KaTeX marks such nodes
// `mtight` so spacing uses the tight table.
List<String> _maybeTight(Options options) =>
    options.style.isTight() ? const ['mtight'] : const [];

BoxNode _buildOrdgroup(OrdGroupNode group, Options options) {
  if (group.semisimple ?? false) {
    return makeFragment(
      buildExpression(group.body, options, isRealGroup: false),
    );
  }
  return withAtomClass(
    makeFragment(buildExpression(group.body, options, isRealGroup: true)),
    'mord',
    extraClasses: _maybeTight(options),
    options: options,
  );
}

BoxNode _buildOrd(ParseNode node, Options options, {required bool isTextord}) {
  final text = (node as SymbolParseNode).text;
  final ord = makeOrd(text, node.mode, options, isTextord: isTextord);
  final body = ord ?? makeSpan(const []);
  return withAtomClass(
    body,
    'mord',
    extraClasses: _maybeTight(options),
    options: options,
  );
}

BoxNode _buildAtom(AtomNode group, Options options) {
  final sym = mathsym(group.text, group.mode, options);
  final body = sym ?? makeSpan(const []);
  return withAtomClass(
    body,
    mclassForFamily(group.family),
    extraClasses: _maybeTight(options),
    options: options,
  );
}

// Spacing functions that behave like a real (rendered) space character.
const Map<String, String> _regularSpace = {
  ' ': '',
  r'\ ': '',
  '~': 'nobreak',
  r'\space': '',
  r'\nobreakspace': 'nobreak',
};

const Map<String, String> _cssSpace = {
  r'\nobreak': 'nobreak',
  r'\allowbreak': 'allowbreak',
};

BoxNode _buildSpacing(SpacingNode group, Options options) {
  if (_regularSpace.containsKey(group.text)) {
    final className = _regularSpace[group.text]!;
    final extra = className.isEmpty ? const <String>[] : [className];
    if (group.mode == Mode.text) {
      final ord = makeOrd(group.text, group.mode, options, isTextord: true);
      return withAtomClass(
        ord ?? makeSpan(const []),
        'mord',
        extraClasses: extra,
        options: options,
      );
    }
    final sym = mathsym(group.text, group.mode, options);
    return makeSpan(
      [if (sym != null) sym],
      classes: ['mspace', ...extra],
      options: options,
    );
  } else if (_cssSpace.containsKey(group.text)) {
    return makeSpan(
      const [],
      classes: ['mspace', _cssSpace[group.text]!],
      options: options,
    );
  } else {
    throw ParseError('Unknown type of space "${group.text}"');
  }
}
