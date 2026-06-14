/// Top-level parse entry point — a Dart port of KaTeX's `parseTree.ts`.
library;

import 'package:katex/src/ast/parse_node.dart';
import 'package:katex/src/parse/parser.dart';
import 'package:katex/src/parse/settings.dart';

/// Parses [tex] with [settings] and returns the parse-node AST.
///
/// Faithful port of KaTeX's `parseTree`. The `\tag`/`\df@tag` wrapping path is
/// not part of the MVP (no `tag` node yet); the cleanup of color/tag macros is
/// preserved so repeated calls don't leak state.
List<ParseNode> parseTree(String tex, Settings settings) {
  final parser = Parser(tex, settings);

  // Blank out any \df@tag to avoid spurious "Duplicate \tag" errors.
  parser.gullet.macros.current.remove(r'\df@tag');

  final tree = parser.parse();

  // Prevent a color definition from persisting between calls.
  parser.gullet.macros.current
    ..remove(r'\current@color')
    ..remove(r'\color');

  return tree;
}
