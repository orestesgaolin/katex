/// Array-family environments — a Dart port of the PARSER side of KaTeX's
/// `src/environments/array.ts` (`parseArray` + the environment handlers).
/// HTML/MathML builders are T-011 and omitted here.
library;

import 'package:katex/src/ast/parse_node.dart';
import 'package:katex/src/environments/environment_spec.dart';
import 'package:katex/src/parse/parse_error.dart';
import 'package:katex/src/parse/parser.dart';
import 'package:katex/src/parse/token.dart';

bool _registered = false;

/// Registers the MVP array-family environments exactly once.
void registerArrayEnvironments() {
  if (_registered) {
    return;
  }
  _registered = true;
  _registerArray();
  _registerSubarray();
  _registerMatrix();
  _registerCases();
  _registerAligned();
}

SymbolParseNode? _checkSymbolNode(ParseNode? node) =>
    node is SymbolParseNode ? node : null;

SymbolParseNode _assertSymbolNode(ParseNode node) {
  final sym = _checkSymbolNode(node);
  if (sym == null) {
    throw ParseError('Expected node of symbol group type, got ${node.type}');
  }
  return sym;
}

TextOrdNode _assertTextord(ParseNode node) =>
    assertNodeType(node, 'textord');

OrdGroupNode _assertOrdgroup(ParseNode node) =>
    assertNodeType(node, 'ordgroup');

StylingNode _assertStyling(ParseNode node) =>
    assertNodeType(node, 'styling');

/// Reads `\hline`/`\hdashline` markers (each entry tells if it is dashed).
List<bool> _getHLines(Parser parser) {
  final hlineInfo = <bool>[];
  parser.consumeSpaces();
  var nxt = parser.fetch().text;
  if (nxt == r'\relax') {
    parser
      ..consume()
      ..consumeSpaces();
    nxt = parser.fetch().text;
  }
  while (nxt == r'\hline' || nxt == r'\hdashline') {
    parser.consume();
    hlineInfo.add(nxt == r'\hdashline');
    parser.consumeSpaces();
    nxt = parser.fetch().text;
  }
  return hlineInfo;
}

/// Returns the auto-tag mode for an environment name.
bool? _getAutoTag(String name) {
  if (!name.contains('ed')) {
    return !name.contains('*');
  }
  return null;
}

/// Cell style based on whether the env name starts with 'd'.
StyleStr _dCellStyle(String envName) =>
    envName.startsWith('d') ? StyleStr.display : StyleStr.text;

/// Parse-array payload, mirroring KaTeX's options object to `parseArray`.
class _ArrayPayload {
  _ArrayPayload({
    this.hskipBeforeAndAfter,
    this.addJot,
    this.cols,
    this.arraystretch,
    this.colSeparationType,
    this.autoTag,
    this.emptySingleRow = false,
    this.maxNumCols,
    this.leqno,
  });

  bool? hskipBeforeAndAfter;
  bool? addJot;
  List<AlignSpec>? cols;
  double? arraystretch;
  ColSeparationType? colSeparationType;
  bool? autoTag;

  /// Whether the environment is a single-row environment (e.g. {equation}).
  /// Not used by the MVP environment set, but retained for the `parseArray`
  /// port; equation/CD environments are deferred.
  final bool singleRow = false;
  bool emptySingleRow;
  int? maxNumCols;
  bool? leqno;
}

/// Parses the body of an array-like environment into an [ArrayNode].
ArrayNode _parseArray(Parser parser, _ArrayPayload payload, StyleStr style) {
  parser.gullet.beginGroup();
  if (!payload.singleRow) {
    parser.gullet.macros.set(r'\cr', r'\\\relax');
  }

  var arraystretch = payload.arraystretch;
  if (arraystretch == null) {
    final stretch = parser.gullet.expandMacroAsText(r'\arraystretch');
    if (stretch == null) {
      arraystretch = 1;
    } else {
      final parsed = double.tryParse(stretch);
      if (parsed == null || parsed < 0) {
        throw ParseError('Invalid \\arraystretch: $stretch');
      }
      arraystretch = parsed;
    }
  }

  parser.gullet.beginGroup();

  var row = <ParseNode>[];
  final body = <List<ParseNode>>[row];
  final rowGaps = <Measurement?>[];
  final hLinesBeforeRow = <List<bool>>[];
  final autoTag = payload.autoTag;
  final tags = autoTag != null ? <Object>[] : null;

  void beginRow() {
    if (autoTag ?? false) {
      parser.gullet.macros.set(r'\@eqnsw', '1', global: true);
    }
  }

  void endRow() {
    if (tags != null) {
      if (parser.gullet.macros.get(r'\df@tag') != null) {
        tags.add(parser.subparse(<Token>[Token(r'\df@tag')]));
        parser.gullet.macros.set(r'\df@tag', null, global: true);
      } else {
        tags.add(
          (autoTag ?? false) && parser.gullet.macros.get(r'\@eqnsw') == '1',
        );
      }
    }
  }

  beginRow();
  hLinesBeforeRow.add(_getHLines(parser));

  while (true) {
    final cellBody = parser.parseExpression(
      breakOnInfix: false,
      breakOnTokenText: payload.singleRow ? r'\end' : r'\\',
    );
    parser.gullet
      ..endGroup()
      ..beginGroup();
    ParseNode cell = OrdGroupNode(mode: parser.mode, body: cellBody);
    cell = StylingNode(
      mode: parser.mode,
      style: style,
      resetFont: true,
      body: <ParseNode>[cell],
    );
    row.add(cell);

    final next = parser.fetch().text;
    if (next == '&') {
      if (payload.maxNumCols != null && row.length == payload.maxNumCols) {
        if (payload.singleRow || payload.colSeparationType != null) {
          throw ParseError('Too many tab characters: &');
        } else {
          parser.settings.reportNonstrict(
            'textEnv',
            'Too few columns specified in the {array} column argument.',
          );
        }
      }
      parser.consume();
    } else if (next == r'\end') {
      endRow();
      // Drop a trailing empty single-cell row (\crcr behavior).
      final last = row.length == 1 ? row[0] : null;
      if (row.length == 1 &&
          last is StylingNode &&
          last.body.length == 1 &&
          last.body[0] is OrdGroupNode &&
          (last.body[0] as OrdGroupNode).body.isEmpty &&
          (body.length > 1 || !payload.emptySingleRow)) {
        body.removeLast();
      }
      if (hLinesBeforeRow.length < body.length + 1) {
        hLinesBeforeRow.add(<bool>[]);
      }
      break;
    } else if (next == r'\\') {
      parser.consume();
      SizeNode? size;
      if (parser.gullet.future().text != ' ') {
        size = parser.parseSizeGroup(true);
      }
      rowGaps.add(size?.value);
      endRow();
      hLinesBeforeRow.add(_getHLines(parser));
      row = <ParseNode>[];
      body.add(row);
      beginRow();
    } else {
      throw ParseError(r'Expected & or \\ or \cr or \end');
    }
  }

  parser.gullet
    ..endGroup()
    ..endGroup();

  return ArrayNode(
    mode: parser.mode,
    body: body,
    rowGaps: rowGaps,
    hLinesBeforeRow: hLinesBeforeRow,
    arraystretch: arraystretch,
    addJot: payload.addJot,
    cols: payload.cols,
    hskipBeforeAndAfter: payload.hskipBeforeAndAfter,
    colSeparationType: payload.colSeparationType,
    tags: tags,
    leqno: payload.leqno,
  );
}

// ---------------------------------------------------------------------------
// {array} / {darray}
// ---------------------------------------------------------------------------

void _registerArray() {
  defineEnvironment(
    <String>['array', 'darray'],
    EnvSpec(
      type: 'array',
      numArgs: 1,
      handler: (context, args, optArgs) {
        final symNode = _checkSymbolNode(args[0]);
        final colalign = symNode != null
            ? <ParseNode>[args[0]]
            : _assertOrdgroup(args[0]).body;
        final cols = colalign.map((nde) {
          final node = _assertSymbolNode(nde);
          final ca = node.text;
          if ('lcr'.contains(ca)) {
            return AlignSpec.align(ca);
          } else if (ca == '|') {
            return const AlignSpec.separator('|');
          } else if (ca == ':') {
            return const AlignSpec.separator(':');
          }
          throw ParseError('Unknown column alignment: $ca');
        }).toList();
        return _parseArray(
          context.parser,
          _ArrayPayload(
            cols: cols,
            hskipBeforeAndAfter: true,
            maxNumCols: cols.length,
          ),
          _dCellStyle(context.envName),
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// subarray (used by \substack)
// ---------------------------------------------------------------------------

void _registerSubarray() {
  defineEnvironment(
    <String>['subarray'],
    EnvSpec(
      type: 'array',
      numArgs: 1,
      handler: (context, args, optArgs) {
        // Parsing of {subarray} is similar to {array}.
        final symNode = _checkSymbolNode(args[0]);
        final colalign = symNode != null
            ? <ParseNode>[args[0]]
            : _assertOrdgroup(args[0]).body;
        final cols = colalign.map((nde) {
          final node = _assertSymbolNode(nde);
          final ca = node.text;
          // {subarray} only recognizes "l" & "c".
          if ('lc'.contains(ca)) {
            return AlignSpec.align(ca);
          }
          throw ParseError('Unknown column alignment: $ca');
        }).toList();
        if (cols.length > 1) {
          throw ParseError('{subarray} can contain only one column');
        }
        final res = _parseArray(
          context.parser,
          _ArrayPayload(
            cols: cols,
            hskipBeforeAndAfter: false,
            arraystretch: 0.5,
            maxNumCols: cols.length,
          ),
          StyleStr.script,
        );
        if (res.body.isNotEmpty && res.body[0].length > 1) {
          throw ParseError('{subarray} can contain only one column');
        }
        return res;
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// matrix family
// ---------------------------------------------------------------------------

const Map<String, List<String>?> _matrixDelimiters = <String, List<String>?>{
  'matrix': null,
  'pmatrix': <String>['(', ')'],
  'bmatrix': <String>['[', ']'],
  'Bmatrix': <String>[r'\{', r'\}'],
  'vmatrix': <String>['|', '|'],
  'Vmatrix': <String>[r'\Vert', r'\Vert'],
};

void _registerMatrix() {
  defineEnvironment(
    <String>[
      'matrix',
      'pmatrix',
      'bmatrix',
      'Bmatrix',
      'vmatrix',
      'Vmatrix',
      'matrix*',
      'pmatrix*',
      'bmatrix*',
      'Bmatrix*',
      'vmatrix*',
      'Vmatrix*',
    ],
    EnvSpec(
      type: 'array',
      numArgs: 0,
      handler: (context, args, optArgs) {
        final parser = context.parser;
        final baseName = context.envName.replaceAll('*', '');
        final delimiters = _matrixDelimiters[baseName];
        var colAlign = 'c';
        final payload = _ArrayPayload(
          hskipBeforeAndAfter: false,
          cols: <AlignSpec>[AlignSpec.align(colAlign)],
        );
        if (context.envName.endsWith('*')) {
          parser.consumeSpaces();
          if (parser.fetch().text == '[') {
            parser
              ..consume()
              ..consumeSpaces();
            colAlign = parser.fetch().text;
            if (!'lcr'.contains(colAlign)) {
              throw ParseError('Expected l or c or r');
            }
            parser
              ..consume()
              ..consumeSpaces()
              ..expect(']')
              ..consume();
            payload.cols = <AlignSpec>[AlignSpec.align(colAlign)];
          }
        }
        final res = _parseArray(parser, payload, _dCellStyle(context.envName));
        final numCols = res.body.fold<int>(
          0,
          (max, row) => row.length > max ? row.length : max,
        );
        final resWithCols = res.copyWith(
          cols: List<AlignSpec>.generate(
            numCols,
            (_) => AlignSpec.align(colAlign),
          ),
        );
        if (delimiters == null) {
          return resWithCols;
        }
        return LeftRightNode(
          mode: context.mode,
          body: <ParseNode>[resWithCols],
          left: delimiters[0],
          right: delimiters[1],
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// {cases} family
// ---------------------------------------------------------------------------

void _registerCases() {
  defineEnvironment(
    <String>['cases', 'dcases', 'rcases', 'drcases'],
    EnvSpec(
      type: 'array',
      numArgs: 0,
      handler: (context, args, optArgs) {
        final payload = _ArrayPayload(
          arraystretch: 1.2,
          cols: <AlignSpec>[
            const AlignSpec.align('l', pregap: 0, postgap: 1),
            const AlignSpec.align('l', pregap: 0, postgap: 0),
          ],
        );
        final res = _parseArray(
          context.parser,
          payload,
          _dCellStyle(context.envName),
        );
        return LeftRightNode(
          mode: context.mode,
          body: <ParseNode>[res],
          left: context.envName.contains('r') ? '.' : r'\{',
          right: context.envName.contains('r') ? r'\}' : '.',
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// align / aligned / split family
// ---------------------------------------------------------------------------

void _validateAmsEnvironmentContext(EnvContext context) {
  if (!context.parser.settings.displayMode) {
    throw ParseError('{${context.envName}} can be used only in display mode.');
  }
}

ArrayNode _alignedHandler(EnvContext context, List<ParseNode> args) {
  if (!context.envName.contains('ed')) {
    _validateAmsEnvironmentContext(context);
  }
  final cols = <AlignSpec>[];
  final isSplit = context.envName == 'split';
  final res = _parseArray(
    context.parser,
    _ArrayPayload(
      cols: cols,
      addJot: true,
      autoTag: isSplit ? null : _getAutoTag(context.envName),
      emptySingleRow: true,
      colSeparationType: context.envName.contains('at')
          ? ColSeparationType.alignat
          : null,
      maxNumCols: isSplit ? 2 : null,
      leqno: context.parser.settings.leqno,
    ),
    StyleStr.display,
  );

  var numMaths = 0;
  var numCols = 0;
  final emptyGroup = OrdGroupNode(mode: context.mode, body: <ParseNode>[]);
  final arg0 = args.isNotEmpty ? args[0] : null;
  if (arg0 is OrdGroupNode) {
    final txt = StringBuffer();
    for (final node in arg0.body) {
      txt.write(_assertTextord(node).text);
    }
    numMaths = int.parse(txt.toString());
    numCols = numMaths * 2;
  }
  final isAligned = numCols == 0;
  for (final row in res.body) {
    for (var i = 1; i < row.length; i += 2) {
      final styling = _assertStyling(row[i]);
      final ordgroup = _assertOrdgroup(styling.body[0]);
      ordgroup.body.insert(0, emptyGroup);
    }
    if (!isAligned) {
      final curMaths = row.length / 2;
      if (numMaths < curMaths) {
        throw ParseError(
          'Too many math in a row: expected $numMaths, but got $curMaths',
        );
      }
    } else if (numCols < row.length) {
      numCols = row.length;
    }
  }

  for (var i = 0; i < numCols; ++i) {
    var align = 'r';
    var pregap = 0.0;
    if (i.isOdd) {
      align = 'l';
    } else if (i > 0 && isAligned) {
      pregap = 1;
    }
    final spec = AlignSpec.align(align, pregap: pregap, postgap: 0);
    if (i < cols.length) {
      cols[i] = spec;
    } else {
      cols.add(spec);
    }
  }

  return res.copyWith(
    cols: cols,
    colSeparationType: isAligned
        ? ColSeparationType.align
        : ColSeparationType.alignat,
  );
}

void _registerAligned() {
  defineEnvironment(
    <String>['align', 'align*', 'aligned', 'split'],
    EnvSpec(
      type: 'array',
      numArgs: 0,
      handler: (context, args, optArgs) => _alignedHandler(context, args),
    ),
  );

  defineEnvironment(
    <String>['alignat', 'alignat*', 'alignedat'],
    EnvSpec(
      type: 'array',
      numArgs: 1,
      handler: (context, args, optArgs) => _alignedHandler(context, args),
    ),
  );
}
