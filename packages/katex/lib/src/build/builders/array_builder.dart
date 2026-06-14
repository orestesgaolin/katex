/// Builder for `array` (matrix/pmatrix/bmatrix/aligned/cases/…), ported from
/// KaTeX `environments/array.ts` (htmlBuilder). Produces a column-major vlist
/// layout; the enclosing delimiters for pmatrix/bmatrix and the cases brace are
/// added by the parser as a wrapping `leftright` node, so this builder only
/// lays out the table body.
library;

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

BoxNode _buildArray(ArrayNode group, Options options) {
  final nr = group.body.length;
  var nc = 0;
  final body = <_Outrow>[];

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
      if (depth < elt.depth) {
        depth = elt.depth;
      }
      if (height < elt.height) {
        height = elt.height;
      }
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

    // Skip/render separators (vertical rules) — for the MVP we add their
    // width but not the rule glyph (rare in the gallery).
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

  final tableBody = makeSpan(cols, classes: const ['mtable']);
  return withAtomClass(makeFragment([tableBody]), 'mord', options: options);
}
