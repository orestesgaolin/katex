/// Registration of the MVP function set, porting the PARSER handlers from
/// KaTeX's `src/functions/*.ts` (`defineFunction` calls). HTML/MathML builders
/// are T-011 and intentionally omitted here.
library;

import 'package:katex/src/ast/parse_node.dart';
import 'package:katex/src/environments/array.dart' as array_env;
import 'package:katex/src/environments/environment_spec.dart';
import 'package:katex/src/functions/function_spec.dart';
import 'package:katex/src/parse/parse_error.dart';
import 'package:katex/src/symbols/symbols.dart';

bool _registered = false;

/// Registers the builtin functions and environments exactly once.
void ensureRegistered() {
  if (_registered) {
    return;
  }
  _registered = true;
  _registerGenfrac();
  _registerSqrt();
  _registerOp();
  _registerOperatorname();
  _registerDelimiters();
  _registerAccent();
  _registerAccentUnder();
  _registerFont();
  _registerColor();
  _registerSizing();
  _registerStyling();
  _registerOverlineUnderline();
  _registerText();
  _registerMclass();
  _registerKern();
  _registerRelax();
  _registerEnvironmentCommands();
  array_env.registerArrayEnvironments();
}

// ---------------------------------------------------------------------------
// Helpers shared by handlers
// ---------------------------------------------------------------------------

/// Asserts [node] is a [TextOrdNode] and returns it.
TextOrdNode _assertTextord(ParseNode node) {
  if (node is TextOrdNode) {
    return node;
  }
  throw ParseError('Expected node of type textord, but got ${node.type}');
}

SizeNode _assertSize(ParseNode node) {
  if (node is SizeNode) {
    return node;
  }
  throw ParseError('Expected node of type size, but got ${node.type}');
}

ColorTokenNode _assertColorToken(ParseNode node) {
  if (node is ColorTokenNode) {
    return node;
  }
  throw ParseError('Expected node of type color-token, but got ${node.type}');
}

/// Returns [node] if it is a symbol parse node, else `null`.
SymbolParseNode? _checkSymbolNode(ParseNode? node) =>
    node is SymbolParseNode ? node : null;

bool _isCharacterBox(ParseNode node) {
  // Mirrors KaTeX's utils.isCharacterBox for the MVP node set.
  final base = node is OrdGroupNode && node.body.isNotEmpty
      ? node.body[0]
      : node;
  return base is MathOrdNode ||
      base is TextOrdNode ||
      base is AtomNode ||
      base is SpacingNode;
}

// ---------------------------------------------------------------------------
// genfrac.ts
// ---------------------------------------------------------------------------

ParseNode _wrapWithStyle(GenfracNode frac, StyleStr? style) {
  if (style == null) {
    return frac;
  }
  return StylingNode(mode: frac.mode, style: style, body: <ParseNode>[frac]);
}

void _registerGenfrac() {
  defineFunction(
    <String>[
      r'\cfrac',
      r'\dfrac',
      r'\frac',
      r'\tfrac',
      r'\dbinom',
      r'\binom',
      r'\tbinom',
      r'\\atopfrac',
      r'\\bracefrac',
      r'\\brackfrac',
    ],
    FunctionSpec(
      type: 'genfrac',
      numArgs: 2,
      allowedInArgument: true,
      handler: (context, args, optArgs) {
        final numer = args[0];
        final denom = args[1];
        final funcName = context.funcName;
        bool hasBarLine;
        String? leftDelim;
        String? rightDelim;
        switch (funcName) {
          case r'\cfrac':
          case r'\dfrac':
          case r'\frac':
          case r'\tfrac':
            hasBarLine = true;
          case r'\\atopfrac':
            hasBarLine = false;
          case r'\dbinom':
          case r'\binom':
          case r'\tbinom':
            hasBarLine = false;
            leftDelim = '(';
            rightDelim = ')';
          case r'\\bracefrac':
            hasBarLine = false;
            leftDelim = r'\{';
            rightDelim = r'\}';
          case r'\\brackfrac':
            hasBarLine = false;
            leftDelim = '[';
            rightDelim = ']';
          default:
            throw ParseError('Unrecognized genfrac command');
        }
        final continued = funcName == r'\cfrac';
        StyleStr? style;
        if (continued || funcName.startsWith(r'\d')) {
          style = StyleStr.display;
        } else if (funcName.startsWith(r'\t')) {
          style = StyleStr.text;
        }
        return _wrapWithStyle(
          GenfracNode(
            mode: context.parser.mode,
            numer: numer,
            denom: denom,
            continued: continued,
            hasBarLine: hasBarLine,
            leftDelim: leftDelim,
            rightDelim: rightDelim,
          ),
          style,
        );
      },
    ),
  );

  // Infix fractions (\over, \atop, \choose, \brace, \brack).
  defineFunction(
    <String>[r'\over', r'\choose', r'\atop', r'\brace', r'\brack'],
    FunctionSpec(
      type: 'infix',
      numArgs: 0,
      infix: true,
      handler: (context, args, optArgs) {
        final String replaceWith;
        switch (context.funcName) {
          case r'\over':
            replaceWith = r'\frac';
          case r'\choose':
            replaceWith = r'\binom';
          case r'\atop':
            replaceWith = r'\\atopfrac';
          case r'\brace':
            replaceWith = r'\\bracefrac';
          case r'\brack':
            replaceWith = r'\\brackfrac';
          default:
            throw ParseError('Unrecognized infix genfrac command');
        }
        return InfixNode(
          mode: context.parser.mode,
          replaceWith: replaceWith,
          token: context.token?.text,
        );
      },
    ),
  );

  const stylArray = <StyleStr>[
    StyleStr.display,
    StyleStr.text,
    StyleStr.script,
    StyleStr.scriptscript,
  ];

  String? delimFromValue(String delimString) {
    if (delimString.isNotEmpty) {
      return delimString == '.' ? null : delimString;
    }
    return null;
  }

  defineFunction(
    <String>[r'\genfrac'],
    FunctionSpec(
      type: 'genfrac',
      numArgs: 6,
      allowedInArgument: true,
      argTypes: const <ArgType?>[
        ArgType.math,
        ArgType.math,
        ArgType.size,
        ArgType.text,
        ArgType.math,
        ArgType.math,
      ],
      handler: (context, args, optArgs) {
        final numer = args[4];
        final denom = args[5];
        final leftNode = normalizeArgument(args[0]);
        final leftDelim = leftNode is AtomNode && leftNode.family == Group.open
            ? delimFromValue(leftNode.text)
            : null;
        final rightNode = normalizeArgument(args[1]);
        final rightDelim =
            rightNode is AtomNode && rightNode.family == Group.close
            ? delimFromValue(rightNode.text)
            : null;
        final barNode = _assertSize(args[2]);
        bool hasBarLine;
        Measurement? barSize;
        if (barNode.isBlank) {
          hasBarLine = true;
        } else {
          barSize = barNode.value;
          hasBarLine = barSize.number > 0;
        }
        StyleStr? size;
        final styl = args[3];
        if (styl is OrdGroupNode) {
          if (styl.body.isNotEmpty) {
            final textOrd = _assertTextord(styl.body[0]);
            size = stylArray[int.parse(textOrd.text)];
          }
        } else {
          final textOrd = _assertTextord(styl);
          size = stylArray[int.parse(textOrd.text)];
        }
        return _wrapWithStyle(
          GenfracNode(
            mode: context.parser.mode,
            numer: numer,
            denom: denom,
            continued: false,
            hasBarLine: hasBarLine,
            barSize: barSize,
            leftDelim: leftDelim,
            rightDelim: rightDelim,
          ),
          size,
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// sqrt.ts
// ---------------------------------------------------------------------------

void _registerSqrt() {
  defineFunction(
    <String>[r'\sqrt'],
    FunctionSpec(
      type: 'sqrt',
      numArgs: 1,
      numOptionalArgs: 1,
      handler: (context, args, optArgs) {
        final index = optArgs[0];
        final body = args[0];
        return SqrtNode(mode: context.parser.mode, body: body, index: index);
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// op.ts + operatorname.ts
// ---------------------------------------------------------------------------

const Map<String, String> _singleCharBigOps = <String, String>{
  '∏': r'\prod',
  '∐': r'\coprod',
  '∑': r'\sum',
  '⋀': r'\bigwedge',
  '⋁': r'\bigvee',
  '⋂': r'\bigcap',
  '⋃': r'\bigcup',
  '⨀': r'\bigodot',
  '⨁': r'\bigoplus',
  '⨂': r'\bigotimes',
  '⨄': r'\biguplus',
  '⨆': r'\bigsqcup',
};

const Map<String, String> _singleCharIntegrals = <String, String>{
  '∫': r'\int',
  '∬': r'\iint',
  '∭': r'\iiint',
  '∮': r'\oint',
  '∯': r'\oiint',
  '∰': r'\oiiint',
};

void _registerOp() {
  // Big symbol operators with limits.
  defineFunction(
    <String>[
      r'\coprod',
      r'\bigvee',
      r'\bigwedge',
      r'\biguplus',
      r'\bigcap',
      r'\bigcup',
      r'\intop',
      r'\prod',
      r'\sum',
      r'\bigotimes',
      r'\bigoplus',
      r'\bigodot',
      r'\bigsqcup',
      r'\smallint',
      '∏',
      '∐',
      '∑',
      '⋀',
      '⋁',
      '⋂',
      '⋃',
      '⨀',
      '⨁',
      '⨂',
      '⨄',
      '⨆',
    ],
    FunctionSpec(
      type: 'op',
      numArgs: 0,
      handler: (context, args, optArgs) {
        var fName = context.funcName;
        if (fName.length == 1) {
          fName = _singleCharBigOps[fName]!;
        }
        return OpNode(
          mode: context.parser.mode,
          limits: true,
          parentIsSupSub: false,
          symbol: true,
          name: fName,
        );
      },
    ),
  );

  // \mathop.
  defineFunction(
    <String>[r'\mathop'],
    FunctionSpec(
      type: 'op',
      numArgs: 1,
      primitive: true,
      handler: (context, args, optArgs) {
        return OpNode(
          mode: context.parser.mode,
          limits: false,
          parentIsSupSub: false,
          symbol: false,
          body: ordargument(args[0]),
        );
      },
    ),
  );

  // No limits, not symbols (\sin, \cos, …).
  defineFunction(
    <String>[
      r'\arcsin',
      r'\arccos',
      r'\arctan',
      r'\arctg',
      r'\arcctg',
      r'\arg',
      r'\ch',
      r'\cos',
      r'\cosec',
      r'\cosh',
      r'\cot',
      r'\cotg',
      r'\coth',
      r'\csc',
      r'\ctg',
      r'\cth',
      r'\deg',
      r'\dim',
      r'\exp',
      r'\hom',
      r'\ker',
      r'\lg',
      r'\ln',
      r'\log',
      r'\sec',
      r'\sin',
      r'\sinh',
      r'\sh',
      r'\tan',
      r'\tanh',
      r'\tg',
      r'\th',
    ],
    FunctionSpec(
      type: 'op',
      numArgs: 0,
      handler: (context, args, optArgs) {
        return OpNode(
          mode: context.parser.mode,
          limits: false,
          parentIsSupSub: false,
          symbol: false,
          name: context.funcName,
        );
      },
    ),
  );

  // Limits, not symbols (\lim, \max, …).
  defineFunction(
    <String>[
      r'\det',
      r'\gcd',
      r'\inf',
      r'\lim',
      r'\max',
      r'\min',
      r'\Pr',
      r'\sup',
    ],
    FunctionSpec(
      type: 'op',
      numArgs: 0,
      handler: (context, args, optArgs) {
        return OpNode(
          mode: context.parser.mode,
          limits: true,
          parentIsSupSub: false,
          symbol: false,
          name: context.funcName,
        );
      },
    ),
  );

  // No limits, symbols (\int, \oint, …).
  defineFunction(
    <String>[
      r'\int',
      r'\iint',
      r'\iiint',
      r'\oint',
      r'\oiint',
      r'\oiiint',
      '∫',
      '∬',
      '∭',
      '∮',
      '∯',
      '∰',
    ],
    FunctionSpec(
      type: 'op',
      numArgs: 0,
      allowedInArgument: true,
      handler: (context, args, optArgs) {
        var fName = context.funcName;
        if (fName.length == 1) {
          fName = _singleCharIntegrals[fName]!;
        }
        return OpNode(
          mode: context.parser.mode,
          limits: false,
          parentIsSupSub: false,
          symbol: true,
          name: fName,
        );
      },
    ),
  );
}

void _registerOperatorname() {
  defineFunction(
    <String>[r'\operatorname@', r'\operatornamewithlimits'],
    FunctionSpec(
      type: 'operatorname',
      numArgs: 1,
      handler: (context, args, optArgs) {
        return OperatorNameNode(
          mode: context.parser.mode,
          body: ordargument(args[0]),
          alwaysHandleSupSub: context.funcName == r'\operatornamewithlimits',
          limits: false,
          parentIsSupSub: false,
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// delimsizing.ts (\left/\right, \bigl etc.)
// ---------------------------------------------------------------------------

const Set<String> _delimiters = <String>{
  '(',
  r'\lparen',
  ')',
  r'\rparen',
  '[',
  r'\lbrack',
  ']',
  r'\rbrack',
  r'\{',
  r'\lbrace',
  r'\}',
  r'\rbrace',
  r'\lfloor',
  r'\rfloor',
  '⌊',
  '⌋',
  r'\lceil',
  r'\rceil',
  '⌈',
  '⌉',
  '<',
  '>',
  r'\langle',
  '⟨',
  r'\rangle',
  '⟩',
  r'\lt',
  r'\gt',
  r'\lvert',
  r'\rvert',
  r'\lVert',
  r'\rVert',
  r'\lgroup',
  r'\rgroup',
  '⟮',
  '⟯',
  r'\lmoustache',
  r'\rmoustache',
  '⎰',
  '⎱',
  '/',
  r'\backslash',
  '|',
  r'\vert',
  r'\|',
  r'\Vert',
  r'\uparrow',
  r'\Uparrow',
  r'\downarrow',
  r'\Downarrow',
  r'\updownarrow',
  r'\Updownarrow',
  '.',
};

SymbolParseNode _checkDelimiter(ParseNode delim, FunctionContext context) {
  final symDelim = _checkSymbolNode(delim);
  if (symDelim != null && _delimiters.contains(symDelim.text)) {
    return symDelim;
  } else if (symDelim != null) {
    throw ParseError(
      "Invalid delimiter '${symDelim.text}' after '${context.funcName}'",
      context.token,
    );
  } else {
    throw ParseError("Invalid delimiter type '${delim.type}'", context.token);
  }
}

const Map<String, ({MathClass mclass, DelimiterSize size})> _delimiterSizes =
    <String, ({MathClass mclass, DelimiterSize size})>{
      r'\bigl': (mclass: MathClass.mopen, size: DelimiterSize.size1),
      r'\Bigl': (mclass: MathClass.mopen, size: DelimiterSize.size2),
      r'\biggl': (mclass: MathClass.mopen, size: DelimiterSize.size3),
      r'\Biggl': (mclass: MathClass.mopen, size: DelimiterSize.size4),
      r'\bigr': (mclass: MathClass.mclose, size: DelimiterSize.size1),
      r'\Bigr': (mclass: MathClass.mclose, size: DelimiterSize.size2),
      r'\biggr': (mclass: MathClass.mclose, size: DelimiterSize.size3),
      r'\Biggr': (mclass: MathClass.mclose, size: DelimiterSize.size4),
      r'\bigm': (mclass: MathClass.mrel, size: DelimiterSize.size1),
      r'\Bigm': (mclass: MathClass.mrel, size: DelimiterSize.size2),
      r'\biggm': (mclass: MathClass.mrel, size: DelimiterSize.size3),
      r'\Biggm': (mclass: MathClass.mrel, size: DelimiterSize.size4),
      r'\big': (mclass: MathClass.mord, size: DelimiterSize.size1),
      r'\Big': (mclass: MathClass.mord, size: DelimiterSize.size2),
      r'\bigg': (mclass: MathClass.mord, size: DelimiterSize.size3),
      r'\Bigg': (mclass: MathClass.mord, size: DelimiterSize.size4),
    };

void _registerDelimiters() {
  defineFunction(
    _delimiterSizes.keys.toList(),
    FunctionSpec(
      type: 'delimsizing',
      numArgs: 1,
      argTypes: const <ArgType?>[ArgType.primitive],
      handler: (context, args, optArgs) {
        final delim = _checkDelimiter(args[0], context);
        final info = _delimiterSizes[context.funcName]!;
        return DelimsizingNode(
          mode: context.parser.mode,
          size: info.size,
          mclass: info.mclass,
          delim: delim.text,
        );
      },
    ),
  );

  // \right — produces a transient leftright-right consumed by \left.
  defineFunction(
    <String>[r'\right'],
    FunctionSpec(
      type: 'leftright-right',
      numArgs: 1,
      primitive: true,
      handler: (context, args, optArgs) {
        final color = context.parser.gullet.macros.get(r'\current@color');
        if (color != null && color is! String) {
          throw ParseError(r'\current@color set to non-string in \right');
        }
        return LeftRightRightNode(
          mode: context.parser.mode,
          delim: _checkDelimiter(args[0], context).text,
          color: color is String ? color : null,
        );
      },
    ),
  );

  // \left — parses the implicit body up to \right.
  defineFunction(
    <String>[r'\left'],
    FunctionSpec(
      type: 'leftright',
      numArgs: 1,
      primitive: true,
      handler: (context, args, optArgs) {
        final delim = _checkDelimiter(args[0], context);
        final parser = context.parser;
        parser.leftrightDepth++;
        final body = parser.parseExpression(breakOnInfix: false);
        parser.leftrightDepth--;
        parser.expect(r'\right', consume: false);
        final right = parser.parseFunction(null, null);
        if (right is! LeftRightRightNode) {
          throw ParseError(r'Expected \right after \left body');
        }
        return LeftRightNode(
          mode: parser.mode,
          body: body,
          left: delim.text,
          right: right.delim,
          rightColor: right.color,
        );
      },
    ),
  );

  // \middle.
  defineFunction(
    <String>[r'\middle'],
    FunctionSpec(
      type: 'middle',
      numArgs: 1,
      primitive: true,
      handler: (context, args, optArgs) {
        final delim = _checkDelimiter(args[0], context);
        if (context.parser.leftrightDepth == 0) {
          throw ParseError(r'\middle without preceding \left', context.token);
        }
        return MiddleNode(mode: context.parser.mode, delim: delim.text);
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// accent.ts
// ---------------------------------------------------------------------------

final RegExp _nonStretchyAccentRegex = RegExp(
  <String>[
    r'\\acute',
    r'\\grave',
    r'\\ddot',
    r'\\tilde',
    r'\\bar',
    r'\\breve',
    r'\\check',
    r'\\hat',
    r'\\vec',
    r'\\dot',
    r'\\mathring',
  ].join('|'),
);

void _registerAccent() {
  // Math accents.
  defineFunction(
    <String>[
      r'\acute',
      r'\grave',
      r'\ddot',
      r'\tilde',
      r'\bar',
      r'\breve',
      r'\check',
      r'\hat',
      r'\vec',
      r'\dot',
      r'\mathring',
      r'\widecheck',
      r'\widehat',
      r'\widetilde',
      r'\overrightarrow',
      r'\overleftarrow',
      r'\Overrightarrow',
      r'\overleftrightarrow',
      r'\overgroup',
      r'\overlinesegment',
      r'\overleftharpoon',
      r'\overrightharpoon',
    ],
    FunctionSpec(
      type: 'accent',
      numArgs: 1,
      handler: (context, args, optArgs) {
        final base = normalizeArgument(args[0]);
        final isStretchy = !_nonStretchyAccentRegex.hasMatch(context.funcName);
        final isShifty =
            !isStretchy ||
            context.funcName == r'\widehat' ||
            context.funcName == r'\widetilde' ||
            context.funcName == r'\widecheck';
        return AccentNode(
          mode: context.parser.mode,
          label: context.funcName,
          isStretchy: isStretchy,
          isShifty: isShifty,
          base: base,
        );
      },
    ),
  );

  // Text-mode accents.
  defineFunction(
    <String>[
      r"\'",
      r'\`',
      r'\^',
      r'\~',
      r'\=',
      r'\u',
      r'\.',
      r'\"',
      r'\c',
      r'\r',
      r'\H',
      r'\v',
      r'\textcircled',
    ],
    FunctionSpec(
      type: 'accent',
      numArgs: 1,
      allowedInText: true,
      argTypes: const <ArgType?>[ArgType.primitive],
      handler: (context, args, optArgs) {
        final base = args[0];
        var mode = context.parser.mode;
        if (mode == Mode.math) {
          context.parser.settings.reportNonstrict(
            'mathVsTextAccents',
            "LaTeX's accent ${context.funcName} works only in text mode",
          );
          mode = Mode.text;
        }
        return AccentNode(
          mode: mode,
          label: context.funcName,
          isStretchy: false,
          isShifty: true,
          base: base,
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// accentunder.ts
// ---------------------------------------------------------------------------

void _registerAccentUnder() {
  defineFunction(
    <String>[
      r'\underleftarrow',
      r'\underrightarrow',
      r'\underleftrightarrow',
      r'\undergroup',
      r'\underlinesegment',
      r'\utilde',
    ],
    FunctionSpec(
      type: 'accentUnder',
      numArgs: 1,
      handler: (context, args, optArgs) {
        return AccentUnderNode(
          mode: context.parser.mode,
          label: context.funcName,
          base: args[0],
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// font.ts
// ---------------------------------------------------------------------------

const Map<String, String> _fontAliases = <String, String>{
  r'\Bbb': r'\mathbb',
  r'\bold': r'\mathbf',
  r'\frak': r'\mathfrak',
};

void _registerFont() {
  defineFunction(
    <String>[
      r'\mathrm',
      r'\mathit',
      r'\mathbf',
      r'\mathnormal',
      r'\mathsfit',
      r'\mathbb',
      r'\mathcal',
      r'\mathfrak',
      r'\mathscr',
      r'\mathsf',
      r'\mathtt',
      r'\Bbb',
      r'\bold',
      r'\frak',
    ],
    FunctionSpec(
      type: 'font',
      numArgs: 1,
      allowedInArgument: true,
      handler: (context, args, optArgs) {
        final body = normalizeArgument(args[0]);
        final func = _fontAliases[context.funcName] ?? context.funcName;
        return FontNode(
          mode: context.parser.mode,
          font: func.substring(1),
          body: body,
        );
      },
    ),
  );

  // \boldsymbol / \bm — produces an mclass wrapping a boldsymbol font.
  defineFunction(
    <String>[r'\boldsymbol', r'\bm'],
    FunctionSpec(
      type: 'mclass',
      numArgs: 1,
      handler: (context, args, optArgs) {
        final body = args[0];
        return MclassNode(
          mode: context.parser.mode,
          mclass: _binrelClass(body),
          body: <ParseNode>[
            FontNode(mode: context.parser.mode, font: 'boldsymbol', body: body),
          ],
          isCharacterBox: _isCharacterBox(body),
        );
      },
    ),
  );

  // Old font-changing commands (\rm, \bf, …).
  defineFunction(
    <String>[r'\rm', r'\sf', r'\tt', r'\bf', r'\it', r'\cal'],
    FunctionSpec(
      type: 'font',
      numArgs: 0,
      allowedInText: true,
      handler: (context, args, optArgs) {
        final parser = context.parser;
        final mode = parser.mode;
        final body = parser.parseExpression(
          breakOnInfix: true,
          breakOnTokenText: context.breakOnTokenText,
        );
        return FontNode(
          mode: mode,
          font: 'math${context.funcName.substring(1)}',
          body: OrdGroupNode(mode: parser.mode, body: body),
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// color.ts
// ---------------------------------------------------------------------------

void _registerColor() {
  defineFunction(
    <String>[r'\textcolor'],
    FunctionSpec(
      type: 'color',
      numArgs: 2,
      allowedInText: true,
      argTypes: const <ArgType?>[ArgType.color, null],
      handler: (context, args, optArgs) {
        final color = _assertColorToken(args[0]).color;
        final body = args[1];
        return ColorNode(
          mode: context.parser.mode,
          color: color,
          body: ordargument(body),
        );
      },
    ),
  );

  defineFunction(
    <String>[r'\color'],
    FunctionSpec(
      type: 'color',
      numArgs: 1,
      allowedInText: true,
      argTypes: const <ArgType?>[ArgType.color],
      handler: (context, args, optArgs) {
        final color = _assertColorToken(args[0]).color;
        context.parser.gullet.macros.set(r'\current@color', color);
        final body = context.parser.parseExpression(
          breakOnInfix: true,
          breakOnTokenText: context.breakOnTokenText,
        );
        return ColorNode(mode: context.parser.mode, color: color, body: body);
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// sizing.ts
// ---------------------------------------------------------------------------

const List<String> _sizeFuncs = <String>[
  r'\tiny',
  r'\sixptsize',
  r'\scriptsize',
  r'\footnotesize',
  r'\small',
  r'\normalsize',
  r'\large',
  r'\Large',
  r'\LARGE',
  r'\huge',
  r'\Huge',
];

void _registerSizing() {
  defineFunction(
    _sizeFuncs,
    FunctionSpec(
      type: 'sizing',
      numArgs: 0,
      allowedInText: true,
      handler: (context, args, optArgs) {
        final body = context.parser.parseExpression(
          breakOnInfix: false,
          breakOnTokenText: context.breakOnTokenText,
        );
        return SizingNode(
          mode: context.parser.mode,
          size: _sizeFuncs.indexOf(context.funcName) + 1,
          body: body,
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// styling.ts
// ---------------------------------------------------------------------------

const Map<String, StyleStr> _styleMap = <String, StyleStr>{
  'display': StyleStr.display,
  'text': StyleStr.text,
  'script': StyleStr.script,
  'scriptscript': StyleStr.scriptscript,
};

void _registerStyling() {
  defineFunction(
    <String>[
      r'\displaystyle',
      r'\textstyle',
      r'\scriptstyle',
      r'\scriptscriptstyle',
    ],
    FunctionSpec(
      type: 'styling',
      numArgs: 0,
      allowedInText: true,
      primitive: true,
      handler: (context, args, optArgs) {
        final body = context.parser.parseExpression(
          breakOnInfix: true,
          breakOnTokenText: context.breakOnTokenText,
        );
        final funcName = context.funcName;
        final styleName = funcName.substring(1, funcName.length - 5);
        final style = _styleMap[styleName];
        if (style == null) {
          throw ParseError('Unknown style: $styleName');
        }
        return StylingNode(mode: context.parser.mode, style: style, body: body);
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// overline.ts / underline.ts
// ---------------------------------------------------------------------------

void _registerOverlineUnderline() {
  defineFunction(
    <String>[r'\overline'],
    FunctionSpec(
      type: 'overline',
      numArgs: 1,
      handler: (context, args, optArgs) =>
          OverlineNode(mode: context.parser.mode, body: args[0]),
    ),
  );

  defineFunction(
    <String>[r'\underline'],
    FunctionSpec(
      type: 'underline',
      numArgs: 1,
      allowedInText: true,
      handler: (context, args, optArgs) =>
          UnderlineNode(mode: context.parser.mode, body: args[0]),
    ),
  );
}

// ---------------------------------------------------------------------------
// text.ts
// ---------------------------------------------------------------------------

void _registerText() {
  defineFunction(
    <String>[
      r'\text',
      r'\textrm',
      r'\textsf',
      r'\texttt',
      r'\textnormal',
      r'\textbf',
      r'\textmd',
      r'\textit',
      r'\textup',
      r'\emph',
    ],
    FunctionSpec(
      type: 'text',
      numArgs: 1,
      argTypes: const <ArgType?>[ArgType.text],
      allowedInArgument: true,
      allowedInText: true,
      handler: (context, args, optArgs) {
        return TextNode(
          mode: context.parser.mode,
          body: ordargument(args[0]),
          font: context.funcName,
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// mclass.ts
// ---------------------------------------------------------------------------

MathClass _binrelClass(ParseNode arg) {
  final atom = arg is OrdGroupNode && arg.body.isNotEmpty ? arg.body[0] : arg;
  if (atom is AtomNode &&
      (atom.family == Group.bin || atom.family == Group.rel)) {
    return atom.family == Group.bin ? MathClass.mbin : MathClass.mrel;
  }
  return MathClass.mord;
}

const Map<String, MathClass> _mclassNames = <String, MathClass>{
  r'\mathord': MathClass.mord,
  r'\mathbin': MathClass.mbin,
  r'\mathrel': MathClass.mrel,
  r'\mathopen': MathClass.mopen,
  r'\mathclose': MathClass.mclose,
  r'\mathpunct': MathClass.mpunct,
  r'\mathinner': MathClass.minner,
};

void _registerMclass() {
  defineFunction(
    _mclassNames.keys.toList(),
    FunctionSpec(
      type: 'mclass',
      numArgs: 1,
      primitive: true,
      handler: (context, args, optArgs) {
        final body = args[0];
        return MclassNode(
          mode: context.parser.mode,
          mclass: _mclassNames[context.funcName]!,
          body: ordargument(body),
          isCharacterBox: _isCharacterBox(body),
        );
      },
    ),
  );

  // \@binrel.
  defineFunction(
    <String>[r'\@binrel'],
    FunctionSpec(
      type: 'mclass',
      numArgs: 2,
      handler: (context, args, optArgs) {
        return MclassNode(
          mode: context.parser.mode,
          mclass: _binrelClass(args[0]),
          body: ordargument(args[1]),
          isCharacterBox: _isCharacterBox(args[1]),
        );
      },
    ),
  );

  // \stackrel / \overset / \underset.
  defineFunction(
    <String>[r'\stackrel', r'\overset', r'\underset'],
    FunctionSpec(
      type: 'mclass',
      numArgs: 2,
      handler: (context, args, optArgs) {
        final baseArg = args[1];
        final shiftedArg = args[0];
        final funcName = context.funcName;
        final mclass = funcName != r'\stackrel'
            ? _binrelClass(baseArg)
            : MathClass.mrel;
        final baseOp = OpNode(
          mode: baseArg.mode,
          limits: true,
          alwaysHandleSupSub: true,
          parentIsSupSub: false,
          symbol: false,
          suppressBaseShift: funcName != r'\stackrel',
          body: ordargument(baseArg),
        );
        final supsub = funcName == r'\underset'
            ? SupSubNode(mode: shiftedArg.mode, base: baseOp, sub: shiftedArg)
            : SupSubNode(mode: shiftedArg.mode, base: baseOp, sup: shiftedArg);
        return MclassNode(
          mode: context.parser.mode,
          mclass: mclass,
          body: <ParseNode>[supsub],
          isCharacterBox: _isCharacterBox(supsub),
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// kern.ts — horizontal spacing commands (\kern, \mkern, \hskip, \mskip)
// ---------------------------------------------------------------------------

void _registerKern() {
  defineFunction(
    <String>[r'\kern', r'\mkern', r'\hskip', r'\mskip'],
    FunctionSpec(
      type: 'kern',
      numArgs: 1,
      argTypes: const <ArgType?>[ArgType.size],
      primitive: true,
      allowedInText: true,
      handler: (context, args, optArgs) {
        final parser = context.parser;
        final funcName = context.funcName;
        final size = _assertSize(args[0]);
        if (parser.settings.strict != false) {
          // \mkern, \mskip are the "math" variants (second char is 'm').
          final mathFunction = funcName[1] == 'm';
          final muUnit = size.value.unit == 'mu';
          if (mathFunction) {
            if (!muUnit) {
              parser.settings.reportNonstrict(
                'mathVsTextUnits',
                "LaTeX's $funcName supports only mu units, "
                'not ${size.value.unit} units',
              );
            }
            if (parser.mode != Mode.math) {
              parser.settings.reportNonstrict(
                'mathVsTextUnits',
                "LaTeX's $funcName works only in math mode",
              );
            }
          } else {
            if (muUnit) {
              parser.settings.reportNonstrict(
                'mathVsTextUnits',
                "LaTeX's $funcName doesn't support mu units",
              );
            }
          }
        }
        return KernNode(mode: parser.mode, dimension: size.value);
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// relax.ts
// ---------------------------------------------------------------------------

void _registerRelax() {
  defineFunction(
    <String>[r'\relax'],
    FunctionSpec(
      type: 'internal',
      numArgs: 0,
      allowedInText: true,
      allowedInArgument: true,
      handler: (context, args, optArgs) =>
          InternalNode(mode: context.parser.mode),
    ),
  );
}

// ---------------------------------------------------------------------------
// environment.ts (\begin / \end)
// ---------------------------------------------------------------------------

void _registerEnvironmentCommands() {
  defineFunction(
    <String>[r'\begin', r'\end'],
    FunctionSpec(
      type: 'environment',
      numArgs: 1,
      argTypes: const <ArgType?>[ArgType.text],
      handler: (context, args, optArgs) {
        final parser = context.parser;
        final nameGroup = args[0];
        if (nameGroup is! OrdGroupNode) {
          throw ParseError('Invalid environment name');
        }
        final envNameBuf = StringBuffer();
        for (final node in nameGroup.body) {
          envNameBuf.write(_assertTextord(node).text);
        }
        final envName = envNameBuf.toString();

        if (context.funcName == r'\begin') {
          final env = environments[envName];
          if (env == null) {
            throw ParseError('No such environment: $envName');
          }
          final parsed = parser.parseEnvironmentArguments(
            '\\begin{$envName}',
            env,
          );
          final envContext = EnvContext(
            mode: parser.mode,
            envName: envName,
            parser: parser,
          );
          final result = env.handler(envContext, parsed.args, parsed.optArgs);
          parser.expect(r'\end', consume: false);
          final end = parser.parseFunction(null, null);
          if (end is! EnvironmentNode) {
            throw ParseError(r'Expected \end after environment body');
          }
          if (end.name != envName) {
            throw ParseError(
              'Mismatch: \\begin{$envName} matched by \\end{${end.name}}',
            );
          }
          return result;
        }

        return EnvironmentNode(mode: parser.mode, name: envName);
      },
    ),
  );
}
