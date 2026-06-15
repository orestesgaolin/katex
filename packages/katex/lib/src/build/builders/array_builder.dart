/// Builder for `array` (matrix/pmatrix/bmatrix/aligned/cases/…), ported from
/// KaTeX `environments/array.ts` (htmlBuilder). Produces a column-major vlist
/// layout; the enclosing delimiters for pmatrix/bmatrix and the cases brace are
/// added by the parser as a wrapping `leftright` node, so this builder only
/// lays out the table body.
library;

import 'dart:math' as math;

import 'package:katex/src/ast/parse_node.dart' hide KernNode, RuleNode;
import 'package:katex/src/box/box_node.dart';
import 'package:katex/src/build/build_common.dart';
import 'package:katex/src/build/build_expression.dart';
import 'package:katex/src/build/builders/units.dart';
import 'package:katex/src/build/options.dart';
import 'package:katex/src/build/style.dart';

/// Registers the array builder into [registry].
void registerArrayBuilder(Map<String, GroupBuilder> registry) {
  registry['array'] = (node, options) =>
      _buildArray(node as ArrayNode, options);
}

class _Outrow {
  _Outrow(this.cells);
  final List<BoxNode?> cells;
  double height = 0;
  double depth = 0;
  double pos = 0;
}

/// A horizontal rule (`\hline`/`\hdashline`) at a given vertical [pos] (em from
/// the top of the array). [isDashed] selects `\hdashline`.
class _HLine {
  _HLine(this.pos, {required this.isDashed});
  final double pos;
  final bool isDashed;
}

BoxNode _buildArray(ArrayNode group, Options options) {
  final nr = group.body.length;
  final hLinesBeforeRow = group.hLinesBeforeRow;
  var nc = 0;
  final body = <_Outrow>[];
  final hlines = <_HLine>[];

  // From LaTeX \showthe\arrayrulewidth (= 0.04 em), floored at the user's
  // minRuleThickness override. Mirrors KaTeX's `ruleThickness`.
  final arrayRuleWidth = options.fontMetrics()['arrayRuleWidth'];
  final ruleThickness = options.floorRuleThickness(arrayRuleWidth);

  final pt = 1 / options.fontMetrics().ptPerEm;
  var arraycolsep = 5 * pt;
  if (group.colSeparationType == ColSeparationType.small) {
    final localMultiplier = options.havingStyle(Style.SCRIPT).sizeMultiplier;
    arraycolsep = 0.2778 * (localMultiplier / options.sizeMultiplier);
  }

  final baselineskip = 12 * pt;
  final jot = 3 * pt;
  final arrayskip = group.arraystretch * baselineskip;
  final arstrutHeight = 0.7 * arrayskip;
  final arstrutDepth = 0.3 * arrayskip;

  var totalHeight = 0.0;

  // Records the position(s) of \hline(s) sitting in a gap between rows (or at
  // the top/bottom edge). KaTeX adds 0.25em between consecutive rules so a
  // \hline\hline draws as a visible double line. Mirrors `setHLinePos`.
  void setHLinePos(List<bool> hlinesInGap) {
    for (var i = 0; i < hlinesInGap.length; i++) {
      if (i > 0) {
        totalHeight += 0.25;
      }
      hlines.add(_HLine(totalHeight, isDashed: hlinesInGap[i]));
    }
  }

  // \hline(s) at the very top of the array.
  if (hLinesBeforeRow.isNotEmpty) {
    setHLinePos(hLinesBeforeRow[0]);
  }

  for (var r = 0; r < nr; r++) {
    final inrow = group.body[r];
    var height = arstrutHeight;
    var depth = arstrutDepth;
    if (nc < inrow.length) {
      nc = inrow.length;
    }
    final outrow = _Outrow(List<BoxNode?>.filled(inrow.length, null));
    for (var c = 0; c < inrow.length; c++) {
      final elt = buildGroup(inrow[c], options);
      depth = math.max(depth, elt.depth);
      height = math.max(height, elt.height);
      outrow.cells[c] = elt;
    }

    final rowGap = r < group.rowGaps.length ? group.rowGaps[r] : null;
    var gap = 0.0;
    if (rowGap != null) {
      gap = calculateSize(rowGap, options);
      if (gap > 0) {
        gap += arstrutDepth;
        if (depth < gap) {
          depth = gap;
        }
        gap = 0;
      }
    }
    if ((group.addJot ?? false) && r < nr - 1) {
      depth += jot;
    }

    outrow
      ..height = height
      ..depth = depth;
    totalHeight += height;
    outrow.pos = totalHeight;
    totalHeight += depth + gap;
    body.add(outrow);

    // \hline(s) following this row, if any.
    if (r + 1 < hLinesBeforeRow.length) {
      setHLinePos(hLinesBeforeRow[r + 1]);
    }
  }

  final offset = totalHeight / 2 + options.fontMetrics().axisHeight;
  final colDescriptions = group.cols ?? const <AlignSpec>[];
  final cols = <BoxNode>[];

  var c = 0;
  var colDescrNum = 0;
  while (c < nc || colDescrNum < colDescriptions.length) {
    var colDescr = colDescrNum < colDescriptions.length
        ? colDescriptions[colDescrNum]
        : null;

    // Column separators (`|`/`:`) → a vertical rule spanning the whole array.
    // KaTeX inserts a `doubleRuleSep` gap between consecutive separators (for
    // `||`/`::`), then draws each as a thin bordered box of height `totalHeight`
    // shifted so it covers the array; here we model that as a [RuleNode] of
    // `ruleThickness` width spanning the array's full height/depth. KaTeX gives
    // the box `margin: 0 -ruleThickness/2`, i.e. zero net horizontal advance and
    // a centered rule — we replicate that with half-width negative kerns either
    // side so neighbouring columns are not pushed apart.
    var firstSeparator = true;
    while (colDescr != null && colDescr.isSeparator) {
      if (!firstSeparator) {
        cols.add(
          makeSpan(
            [KernNode(options.fontMetrics()['doubleRuleSep'])],
            classes: const ['arraycolsep'],
          ),
        );
      }

      // The array box spans box-y from `-offset` (top) to
      // `totalHeight - offset` (bottom); a full-height separator therefore has
      // height `offset` and depth `totalHeight - offset`. `:` renders dashed in
      // KaTeX, but the box tree has no dash primitive, so it falls back solid.
      final separator = RuleNode(
        width: ruleThickness,
        height: offset,
        depth: totalHeight - offset,
      );
      cols.add(
        makeSpan(
          [
            KernNode(-ruleThickness / 2),
            separator,
            KernNode(-ruleThickness / 2),
          ],
          classes: const ['vertical-separator'],
        ),
      );

      firstSeparator = false;
      colDescrNum++;
      colDescr = colDescrNum < colDescriptions.length
          ? colDescriptions[colDescrNum]
          : null;
    }

    if (c >= nc) {
      break;
    }

    // Pre-gap.
    double sepwidth;
    if (c > 0 || (group.hskipBeforeAndAfter ?? false)) {
      sepwidth = colDescr?.pregap ?? arraycolsep;
      if (sepwidth != 0) {
        cols.add(
          makeSpan([KernNode(sepwidth)], classes: const ['arraycolsep']),
        );
      }
    }

    // Column vlist.
    final colElems = <VListChild>[];
    for (var r = 0; r < nr; r++) {
      final row = body[r];
      if (c >= row.cells.length) {
        continue;
      }
      final elem = row.cells[c];
      if (elem == null) {
        continue;
      }
      final shift = row.pos - offset;
      // Force the cell to the row's height/depth (KaTeX overrides
      // elem.height/depth). Model the strut as a zero-width rule alongside the
      // cell in an HBox: HBox takes max height/depth and sums widths (rule is
      // zero-width), so the cell keeps its advance but the row dimensions win.
      final strut = RuleNode(width: 0, height: row.height, depth: row.depth);
      final cell = HBox([strut, elem]);
      colElems.add(VListChild.elem(cell, shift: shift));
    }
    if (colElems.isNotEmpty) {
      final colVList = makeVList(
        positionType: VListPositionType.individualShift,
        children: colElems,
      );
      cols.add(
        makeSpan([colVList], classes: ['col-align-${colDescr?.align ?? 'c'}']),
      );
    }

    // Post-gap.
    if (c < nc - 1 || (group.hskipBeforeAndAfter ?? false)) {
      sepwidth = colDescr?.postgap ?? arraycolsep;
      if (sepwidth != 0) {
        cols.add(
          makeSpan([KernNode(sepwidth)], classes: const ['arraycolsep']),
        );
      }
    }

    c++;
    colDescrNum++;
  }

  BoxNode tableBody = makeSpan(cols, classes: const ['mtable']);

  // Draw \hline(s), if any. KaTeX wraps the table in a vlist and stacks a
  // full-width horizontal rule at each `hline.pos - offset` baseline shift.
  if (hlines.isNotEmpty) {
    final arrayWidth = tableBody.width;
    final vListElems = <VListChild>[VListChild.elem(tableBody)];
    for (final hline in hlines) {
      // A horizontal rule (`makeLineSpan`) of full array width, `ruleThickness`
      // tall, sitting at the gap position. `:`/\hdashline has no dash primitive
      // in the box tree, so it renders as a solid rule too.
      final rule = RuleNode(width: arrayWidth, height: ruleThickness);
      vListElems.add(VListChild.elem(rule, shift: hline.pos - offset));
    }
    tableBody = makeVList(
      positionType: VListPositionType.individualShift,
      children: vListElems,
    );
  }

  return withAtomClass(makeFragment([tableBody]), 'mord', options: options);
}
