/// The keystone of the build phase: a Dart port of KaTeX's `buildHTML.ts`
/// box-producing path (`buildExpression`, `buildGroup`, `buildHTML`).
///
/// This turns the parse-node AST (T-006/T-008) into the project's
/// backend-agnostic box tree ([BoxNode], T-009), using the `buildCommon`
/// helpers (T-010). Unlike KaTeX it emits no DOM: a built group is a [BoxNode],
/// and an atom's math class (`mord`/`mop`/`mbin`/…) is carried on the node via
/// [atomClassOf]/[withAtomClass] — a [SpanNode] whose first [SpanNode.classes]
/// entry is the mclass name (mirroring KaTeX's convention that `classes[0]` is
/// the atom class). This is the minimum metadata needed to reproduce KaTeX's
/// inter-atom spacing and bin-cancellation rules.
///
/// Per-group builders live in `builders/` and register themselves into
/// [groupBuilders] (keyed by the KaTeX node `type` string), mirroring KaTeX's
/// `_htmlGroupBuilders`.
library;

import 'package:katex/src/ast/parse_node.dart' hide KernNode, RuleNode;
import 'package:katex/src/box/box_node.dart';
import 'package:katex/src/build/build_common.dart';
import 'package:katex/src/build/builders/builders.dart' as builders;
import 'package:katex/src/build/builders/units.dart' show calculateSize;
import 'package:katex/src/build/options.dart';
import 'package:katex/src/build/style.dart';
import 'package:katex/src/parse/parse_error.dart';
import 'package:katex/src/symbols/spacing_data.g.dart';
import 'package:katex/src/symbols/symbols.dart';

/// Builds a single parse [node] into a [BoxNode] under [options].
typedef GroupBuilder = BoxNode Function(ParseNode node, Options options);

/// The registry of per-group builders, keyed by KaTeX node `type` string.
///
/// Mirrors KaTeX's `_htmlGroupBuilders`. Populated lazily by
/// [ensureBuildersRegistered] the first time a build runs.
final Map<String, GroupBuilder> groupBuilders = <String, GroupBuilder>{};

bool _registered = false;

/// Registers all MVP per-group builders into [groupBuilders] exactly once.
void ensureBuildersRegistered() {
  if (_registered) {
    return;
  }
  _registered = true;
  builders.registerAll(groupBuilders);
}

// ---------------------------------------------------------------------------
// Atom-class tagging
//
// KaTeX stores an atom's math class as the first element of a DOM node's
// `classes` array. We reproduce this by wrapping a built node in a SpanNode
// whose `classes[0]` is the mclass name. `atomClassOf` reads it back, and the
// "mspace"/"mtight"/"newline" markers used by the spacing/break logic are also
// carried as classes.
// ---------------------------------------------------------------------------

const Set<String> _atomClassNames = {
  'mord',
  'mop',
  'mbin',
  'mrel',
  'mopen',
  'mclose',
  'mpunct',
  'minner',
};

/// Wraps [node] so its atom math class is [mclass] (carried as `classes[0]`),
/// optionally adding [extraClasses] (e.g. `mtight`, `mspace`). Mirrors KaTeX's
/// `makeSpan([mclass, ...], [node])`.
SpanNode withAtomClass(
  BoxNode node,
  String mclass, {
  List<String> extraClasses = const [],
  Options? options,
}) {
  return makeSpan([node], classes: [mclass, ...extraClasses], options: options);
}

/// Returns the atom math class carried on [node]'s `classes[0]`, or `null` if
/// it is not a recognised atom class. Port of KaTeX's `getTypeOfDomTree`
/// (without the `side` traversal, which the MVP does not need for spacing).
String? atomClassOf(BoxNode? node) {
  if (node is! SpanNode || node.classes.isEmpty) {
    return null;
  }
  final first = node.classes.first;
  return _atomClassNames.contains(first) ? first : null;
}

bool _hasClass(BoxNode node, String cls) =>
    node is SpanNode && node.classes.contains(cls);

// Maps a symbol [Group] / explicit [MathClass] to the mclass class name.
const Map<Group, String> _groupToMclass = {
  Group.bin: 'mbin',
  Group.rel: 'mrel',
  Group.open: 'mopen',
  Group.close: 'mclose',
  Group.punct: 'mpunct',
  Group.inner: 'minner',
  Group.op: 'mop',
  Group.mathord: 'mord',
  Group.textord: 'mord',
};

/// The mclass class name for an atom [family] (used by symbol builders).
String mclassForFamily(Group family) => _groupToMclass[family] ?? 'mord';

/// The mclass class name for an explicit [MathClass] (used by mclass/delim).
String mclassName(MathClass mclass) => 'm${mclass.name.substring(1)}';

// ---------------------------------------------------------------------------
// buildGroup / buildExpression
// ---------------------------------------------------------------------------

// Binary atoms change into ordinary atoms depending on their surroundings.
// (TeXbook pg. 442-446, rules 5 and 6.)
const Set<String> _binLeftCanceller = {
  'leftmost',
  'mbin',
  'mopen',
  'mrel',
  'mop',
  'mpunct',
};
const Set<String> _binRightCanceller = {
  'rightmost',
  'mrel',
  'mclose',
  'mpunct',
};

/// Builds a single [group] into a [BoxNode] under [options], dispatching on the
/// node `type` via [groupBuilders]. Port of KaTeX's `buildGroup` (the size/
/// style reconciliation between parent and child via [baseOptions] is applied,
/// scaling the result's dimensions when the size changed).
BoxNode buildGroup(ParseNode? group, Options options, [Options? baseOptions]) {
  ensureBuildersRegistered();
  if (group == null) {
    return makeSpan(const []);
  }

  final builder = groupBuilders[group.type];
  if (builder == null) {
    throw ParseError("Got group of unknown type: '${group.type}'");
  }

  // NOTE: KaTeX reconciles a parent/child size difference here by wrapping the
  // result and scaling its height/depth by the size ratio. The box tree's
  // BoxNode hierarchy is sealed, so we cannot introduce a scaling wrapper from
  // this library; for the MVP set the relevant builders already build their
  // children at the parent size (sizing/styling handle their own scaling via
  // makeVList dimension adjustment), so this reconciliation is a no-op here.
  // Tracked for the dimension-accuracy pass (T-014/T-019).
  return builder(group, options);
}

/// Builds an [expression] (a list of parse nodes) into a list of [BoxNode]s,
/// inserting inter-atom spacing and performing bin cancellation when
/// [isRealGroup] is true. Port of KaTeX's `buildExpression`.
///
/// [isRealGroup] is `true` for a real group (braces, root) and `false` for a
/// partial group (e.g. `\color`), in which case the parent handles spacing.
/// `surrounding` gives the atom classes that will sit to the left and right.
List<BoxNode> buildExpression(
  List<ParseNode> expression,
  Options options, {
  required bool isRealGroup,
  bool isRoot = false,
  String? surroundingLeft,
  String? surroundingRight,
}) {
  ensureBuildersRegistered();

  final groups = <BoxNode>[];
  for (final node in expression) {
    groups.add(buildGroup(node, options));
  }

  if (!isRealGroup) {
    return groups;
  }

  var glueOptions = options;
  if (expression.length == 1) {
    final node = expression.first;
    if (node is SizingNode) {
      glueOptions = options.havingSize(node.size);
    } else if (node is StylingNode) {
      glueOptions = options.havingStyle(Style.fromStr(node.style));
    }
  }

  // Dummy boundary atoms for spacing at the edges.
  final dummyPrev = withAtomClass(
    makeSpan(const []),
    surroundingLeft ?? 'leftmost',
  );
  final dummyNext = withAtomClass(
    makeSpan(const []),
    surroundingRight ?? 'rightmost',
  );

  // Bin cancellation pass.
  _traverseNonSpace(groups, dummyPrev, dummyNext, isRoot, (node, prev) {
    final prevType = prev is SpanNode && prev.classes.isNotEmpty
        ? prev.classes.first
        : null;
    final type = node is SpanNode && node.classes.isNotEmpty
        ? node.classes.first
        : null;
    if (prevType == 'mbin' && _binRightCanceller.contains(type)) {
      _reclass(prev, 'mord');
    } else if (type == 'mbin' && _binLeftCanceller.contains(prevType)) {
      _reclass(node, 'mord');
    }
    return null;
  });

  // Spacing-insertion pass.
  _traverseNonSpace(groups, dummyPrev, dummyNext, isRoot, (node, prev) {
    final prevType = atomClassOf(prev);
    final type = atomClassOf(node);
    if (prevType == null || type == null) {
      return null;
    }
    final left = _mathClassByName(prevType);
    final right = _mathClassByName(type);
    if (left == null || right == null) {
      return null;
    }
    final tight = _hasClass(node, 'mtight');
    final table = tight ? tightSpacings : spacings;
    final space = table[left]?[right];
    if (space != null) {
      return _makeGlue(space, glueOptions);
    }
    return null;
  });

  return groups;
}

/// Builds the whole parse [tree] into a single root [BoxNode], mirroring
/// KaTeX's `buildHTML` (the box-producing parts; the line-breaking strut/tag
/// machinery is a DOM detail and is collapsed into one horizontal grouping).
///
/// Top-level `\\` / `\cr` / `\newline` line breaks (`cr` parse nodes with
/// `newLine`) split the expression into lines that are stacked left-aligned in
/// a [VList]. An expression with NO such break is built exactly as a single
/// `katex-html` span (byte-for-byte unchanged), so single-line layout — and the
/// oracle dimension gate — is unaffected.
BoxNode buildHTML(List<ParseNode> tree, Options options) {
  // Fast path: no top-level line break. Identical to the original buildHTML.
  if (!_hasTopLevelNewLine(tree)) {
    final expression = buildExpression(
      tree,
      options,
      isRealGroup: true,
      isRoot: true,
    );
    return makeSpan(
      expression,
      classes: const ['katex-html'],
      options: options,
    );
  }
  return _buildHTMLWithLineBreaks(tree, options);
}

// Whether [tree] contains a top-level `cr` node that produces a line break.
bool _hasTopLevelNewLine(List<ParseNode> tree) {
  for (final node in tree) {
    if (node is CrNode && node.newLine) {
      return true;
    }
  }
  return false;
}

// Splits [tree] on top-level `cr` line breaks and stacks each line, left
// aligned, in a VList. Port of the layout KaTeX gets from CSS
// `.newline { display: block }`: each line sits on its own baseline, separated
// by the line's depth + next line's height plus the optional `\\[size]` skip.
BoxNode _buildHTMLWithLineBreaks(List<ParseNode> tree, Options options) {
  // Split into segments, recording the extra skip carried by each break.
  final segments = <List<ParseNode>>[<ParseNode>[]];
  final extraSkips = <double>[]; // skip BELOW segment i (from the break after).
  for (final node in tree) {
    if (node is CrNode && node.newLine) {
      final size = node.size;
      extraSkips.add(size == null ? 0 : calculateSize(size, options));
      segments.add(<ParseNode>[]);
    } else {
      segments.last.add(node);
    }
  }

  // Build each line as a left-aligned span.
  final lines = <BoxNode>[];
  for (final segment in segments) {
    final expression = buildExpression(
      segment,
      options,
      isRealGroup: true,
      isRoot: true,
    );
    lines.add(
      makeSpan(expression, classes: const ['katex-html'], options: options),
    );
  }

  // Stack the lines in a VList. The first line keeps its own baseline; each
  // subsequent line's baseline is shifted down by (prevDepth + thisHeight) plus
  // the break's optional skip — the box-tree analogue of CSS block flow.
  final children = <VListChild>[VListChild.elem(lines.first)];
  var shift = 0.0;
  for (var i = 1; i < lines.length; i++) {
    final prev = lines[i - 1];
    final line = lines[i];
    final extra = (i - 1) < extraSkips.length ? extraSkips[i - 1] : 0.0;
    shift += prev.depth + line.height + extra;
    children.add(VListChild.elem(line, shift: shift));
  }

  final vlist = makeVList(
    positionType: VListPositionType.individualShift,
    children: children,
  );
  return makeSpan([vlist], classes: const ['katex-html'], options: options);
}

// ---------------------------------------------------------------------------
// Traversal (bin cancellation + spacing), port of `traverseNonSpaceNodes`.
// ---------------------------------------------------------------------------

void _traverseNonSpace(
  List<BoxNode> nodes,
  BoxNode dummyPrev,
  BoxNode? next,
  bool isRoot,
  BoxNode? Function(BoxNode node, BoxNode prev) callback,
) {
  if (next != null) {
    nodes.add(next);
  }
  var prev = dummyPrev;
  var i = 0;
  while (i < nodes.length) {
    final node = nodes[i];

    // Recurse into partial groups (fragments / colored groups). We model a
    // partial group as an HBox or as a SpanNode carrying the "enclosing"
    // marker; for the MVP, an HBox with no atom class behaves as a fragment.
    final partial = _checkPartialGroup(node);
    if (partial != null) {
      _traverseNonSpace(partial, prev, null, isRoot, callback);
      // After recursion, treat the last child as prev for subsequent nodes
      // if it carries a class; KaTeX keeps prev across the recursion, so we
      // do too by leaving `prev` unchanged (the recursion mutated `prev`'s
      // role via callbacks inserting into `partial`). Advance.
      i++;
      continue;
    }

    final nonspace = !_hasClass(node, 'mspace');
    if (nonspace) {
      final result = callback(node, prev);
      if (result != null) {
        nodes.insert(i, result);
        i++;
      }
    }
    if (nonspace) {
      prev = node;
    }
    i++;
  }

  if (next != null) {
    nodes.remove(next);
  }
}

// A partial group does not affect spacing around it; we recurse into its
// children. For the MVP these are HBoxes/SpanNodes that are NOT atoms (no
// recognised mclass) — i.e. fragments produced by \color, sizing, etc.
List<BoxNode>? _checkPartialGroup(BoxNode node) {
  if (node is HBox) {
    return node.children;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const Map<String, MathClass> _mathClassByNameMap = {
  'mord': MathClass.mord,
  'mop': MathClass.mop,
  'mbin': MathClass.mbin,
  'mrel': MathClass.mrel,
  'mopen': MathClass.mopen,
  'mclose': MathClass.mclose,
  'mpunct': MathClass.mpunct,
  'minner': MathClass.minner,
};

MathClass? _mathClassByName(String name) => _mathClassByNameMap[name];

// Re-tag a span's classes[0] in place. SpanNode is immutable, so we mutate the
// backing list (which it exposes directly).
void _reclass(BoxNode node, String mclass) {
  if (node is SpanNode && node.classes.isNotEmpty) {
    node.classes[0] = mclass;
  }
}

// Make a glue (horizontal space) box from a mu measurement, scaled to em for
// the current style. Port of KaTeX's `makeGlue` for the spacing-table case.
BoxNode _makeGlue(Mu space, Options options) {
  final em = space.number * options.fontMetrics().cssEmPerMu;
  return makeSpan([KernNode(em)], classes: const ['mspace'], options: options);
}

/// Maps a parse-node [StyleStr] to a build [Style].
