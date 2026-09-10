/// Automatic line breaking for long expressions.
///
/// KaTeX itself never wraps a formula: `buildHTML` splits the top-level
/// expression into unbreakable `.base` chunks and lets the **browser** wrap
/// between them (each chunk is an inline-block, so CSS line-breaking does the
/// rest). The box tree has no CSS and no browser, so the second half of that
/// job lives here: [chunkAtBreakOpportunities] reproduces KaTeX's chunking
/// exactly, and [packChunksIntoLines] performs the greedy first-fit packing a
/// browser would.
///
/// The break rule is TeX's, quoted in KaTeX's own source from the TeXBook
/// [p.173]:
///
/// > A formula will be broken only after a relation symbol like `=` or `<` or
/// > `\rightarrow`, or after a binary operation symbol like `+` or `-` or
/// > `\times`, where the relation or binary operation is on the "outer level"
/// > of the formula (i.e., not enclosed in `{...}` and not part of an `\over`
/// > construction).
///
/// "Outer level" falls out for free: this operates on the **top-level** box
/// list only, so an `mbin`/`mrel` nested inside a group, a fraction, or a
/// `\left…\right` pair is never even seen — it has been folded into a single
/// box by the time it gets here.
library;

import 'package:katex_dart/src/box/box_node.dart';

/// Atom classes that open a break opportunity *after* them, plus the explicit
/// `\allowbreak` marker. Port of the `hasClass` test in KaTeX's `buildHTML`.
const Set<String> _breakAfterClasses = {'mbin', 'mrel', 'allowbreak'};

/// Splits [expression] — a built **top-level** box list — into unbreakable
/// chunks, breaking only after a top-level `mbin`/`mrel`/`\allowbreak`.
///
/// Post-operator glue rides along on the operator's chunk (so a line never
/// starts with the inter-atom space that belongs to the operator ending the
/// previous line), and a `\nobreak`/`~` anywhere in that glue suppresses the
/// opportunity entirely — both faithful to KaTeX's loop.
///
/// Every returned chunk is non-empty, and concatenating them reproduces
/// [expression] exactly; a list with no break opportunity yields a single
/// chunk.
List<List<BoxNode>> chunkAtBreakOpportunities(List<BoxNode> expression) {
  final chunks = <List<BoxNode>>[];
  var parts = <BoxNode>[];

  for (var i = 0; i < expression.length; i++) {
    parts.add(expression[i]);

    if (!_hasAnyClass(expression[i], _breakAfterClasses)) {
      continue;
    }

    // Keep any post-operator glue on the same line as the operator, watching
    // for a \nobreak along the way.
    var nobreak = false;
    while (i < expression.length - 1 &&
        _hasClass(expression[i + 1], 'mspace') &&
        !_hasClass(expression[i + 1], 'newline')) {
      i++;
      parts.add(expression[i]);
      if (_hasClass(expression[i], 'nobreak')) {
        nobreak = true;
      }
    }

    if (!nobreak) {
      chunks.add(parts);
      parts = <BoxNode>[];
    }
  }

  if (parts.isNotEmpty) {
    chunks.add(parts);
  }
  return chunks;
}

/// Greedy first-fit packing of [chunks] into lines no wider than [maxWidth]
/// (in **em**) — the same algorithm a browser applies to inline-blocks.
///
/// A chunk that is wider than [maxWidth] on its own still gets a line to
/// itself and overflows it: there is no break opportunity inside a chunk, so
/// overflowing is the only option (TeX behaves the same way, reporting an
/// overfull box). Returns at least one line; concatenating the lines
/// reproduces the input order exactly.
List<List<BoxNode>> packChunksIntoLines(
  List<List<BoxNode>> chunks,
  double maxWidth,
) {
  final lines = <List<BoxNode>>[];
  var current = <BoxNode>[];
  var currentWidth = 0.0;

  for (final chunk in chunks) {
    final chunkWidth = _widthOf(chunk);
    // Never break before the first chunk of a line — that would emit an empty
    // line and make no progress. The epsilon keeps a chunk that fits exactly
    // from being pushed down by floating-point noise in the em accumulation.
    if (current.isNotEmpty && currentWidth + chunkWidth > maxWidth + _epsilon) {
      lines.add(current);
      current = <BoxNode>[];
      currentWidth = 0;
    }
    current.addAll(chunk);
    currentWidth += chunkWidth;
  }

  if (current.isNotEmpty || lines.isEmpty) {
    lines.add(current);
  }
  return lines;
}

const double _epsilon = 1e-9;

double _widthOf(List<BoxNode> nodes) {
  var total = 0.0;
  for (final node in nodes) {
    total += node.width;
  }
  return total;
}

bool _hasClass(BoxNode node, String className) =>
    node is SpanNode && node.classes.contains(className);

bool _hasAnyClass(BoxNode node, Set<String> classNames) {
  if (node is! SpanNode) {
    return false;
  }
  for (final className in node.classes) {
    if (classNames.contains(className)) {
      return true;
    }
  }
  return false;
}
