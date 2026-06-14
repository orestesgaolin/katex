/// The TeX expression parser — a Dart port of KaTeX's `Parser.ts`.
///
/// The parser drives a [MacroExpander] (its "gullet") to obtain fully-expanded
/// tokens, then assembles them into the parse-node AST (T-006). Function and
/// environment behavior lives in the registries under `lib/src/functions/` and
/// `lib/src/environments/`; this file is the grammar engine.
///
// The `optional` flag on the parse-group methods mirrors KaTeX's positional
// boolean API one-to-one, so it stays positional here.
// ignore_for_file: avoid_positional_boolean_parameters
library;

import 'package:katex/src/ast/parse_node.dart';
import 'package:katex/src/environments/environment_spec.dart';
import 'package:katex/src/functions/function_spec.dart';
import 'package:katex/src/functions/functions.dart' as fns;
import 'package:katex/src/parse/lexer.dart';
import 'package:katex/src/parse/macro_expander.dart';
import 'package:katex/src/parse/parse_error.dart';
import 'package:katex/src/parse/settings.dart';
import 'package:katex/src/parse/source_location.dart';
import 'package:katex/src/parse/token.dart';
import 'package:katex/src/symbols/symbols.dart';

/// Tokens that always terminate an expression. Mirrors KaTeX's
/// `Parser.endOfExpression`.
const Set<String> _endOfExpression = <String>{
  '}',
  r'\endgroup',
  r'\end',
  r'\right',
  '&',
};

/// Parses out a TeX expression from the input.
///
/// Faithful port of KaTeX's `Parser` class for the MVP grammar.
class Parser {
  /// Creates a parser over [input] with [settings].
  Parser(String input, this.settings)
    : mode = Mode.math,
      leftrightDepth = 0,
      nextToken = null {
    // Ensure the builtin functions/environments are registered.
    fns.ensureRegistered();
    gullet = MacroExpander(input, settings, mode)
      ..functionExists = functions.containsKey
      ..functionIsPrimitive = (name) => functions[name]?.primitive ?? false;
  }

  /// The current parsing mode (math or text).
  Mode mode;

  /// The gullet (macro expander) feeding fully-expanded tokens.
  late final MacroExpander gullet;

  /// The settings controlling parsing.
  final Settings settings;

  /// Depth of nested `\left`/`\right` (used for `\middle` errors).
  int leftrightDepth;

  /// The current lookahead token, or `null` if none is buffered.
  Token? nextToken;

  /// Checks the current lookahead token matches [text], throwing otherwise.
  void expect(String text, {bool consume = true}) {
    if (fetch().text != text) {
      throw ParseError("Expected '$text', got '${fetch().text}'", fetch());
    }
    if (consume) {
      this.consume();
    }
  }

  /// Discards the current lookahead token, considering it consumed.
  void consume() {
    nextToken = null;
  }

  /// Returns the current lookahead token, fetching a new one if needed.
  Token fetch() {
    return nextToken ??= gullet.expandNextToken();
  }

  /// Switches between text and math modes.
  void switchMode(Mode newMode) {
    mode = newMode;
    gullet.switchMode(newMode);
  }

  /// Main parsing entry point; parses an entire input.
  List<ParseNode> parse() {
    if (!settings.globalGroup) {
      gullet.beginGroup();
    }
    if (settings.colorIsTextColor) {
      gullet.macros.set(r'\color', r'\textcolor');
    }
    try {
      final parseResult = parseExpression(breakOnInfix: false);
      expect('EOF');
      if (!settings.globalGroup) {
        gullet.endGroup();
      }
      return parseResult;
    } finally {
      gullet.endGroups();
    }
  }

  /// Fully parses a separate sequence of [tokens] (reverse order) as a job.
  List<ParseNode> subparse(List<Token> tokens) {
    final oldToken = nextToken;
    consume();

    gullet
      ..pushToken(Token('}'))
      ..pushTokens(tokens);
    final parseResult = parseExpression(breakOnInfix: false);
    expect('}');

    nextToken = oldToken;
    return parseResult;
  }

  /// Parses an expression: a list of atoms.
  List<ParseNode> parseExpression({
    required bool breakOnInfix,
    String? breakOnTokenText,
  }) {
    final body = <ParseNode>[];
    while (true) {
      if (mode == Mode.math) {
        consumeSpaces();
      }
      final lex = fetch();
      if (_endOfExpression.contains(lex.text)) {
        break;
      }
      if (breakOnTokenText != null && lex.text == breakOnTokenText) {
        break;
      }
      if (breakOnInfix &&
          functions[lex.text] != null &&
          functions[lex.text]!.infix) {
        break;
      }
      final atom = parseAtom(breakOnTokenText);
      if (atom == null) {
        break;
      } else if (atom is InternalNode) {
        continue;
      }
      body.add(atom);
    }
    if (mode == Mode.text) {
      _formLigatures(body);
    }
    return handleInfixNodes(body);
  }

  /// Rewrites infix operators (`\over` etc.) into their function equivalents.
  List<ParseNode> handleInfixNodes(List<ParseNode> body) {
    var overIndex = -1;
    String? funcName;

    for (var i = 0; i < body.length; i++) {
      final node = body[i];
      if (node is InfixNode) {
        if (overIndex != -1) {
          throw ParseError('only one infix operator per group');
        }
        overIndex = i;
        funcName = node.replaceWith;
      }
    }

    if (overIndex != -1 && funcName != null) {
      ParseNode numerNode;
      ParseNode denomNode;

      final numerBody = body.sublist(0, overIndex);
      final denomBody = body.sublist(overIndex + 1);

      if (numerBody.length == 1 && numerBody[0] is OrdGroupNode) {
        numerNode = numerBody[0];
      } else {
        numerNode = OrdGroupNode(mode: mode, body: numerBody);
      }

      if (denomBody.length == 1 && denomBody[0] is OrdGroupNode) {
        denomNode = denomBody[0];
      } else {
        denomNode = OrdGroupNode(mode: mode, body: denomBody);
      }

      final ParseNode node;
      if (funcName == r'\\abovefrac') {
        node = callFunction(funcName, <ParseNode>[
          numerNode,
          body[overIndex],
          denomNode,
        ], <ParseNode?>[]);
      } else {
        node = callFunction(funcName, <ParseNode>[
          numerNode,
          denomNode,
        ], <ParseNode?>[]);
      }
      return <ParseNode>[node];
    }
    return body;
  }

  /// Handles a subscript or superscript argument with nice errors.
  ParseNode handleSupSubscript(String name) {
    final symbolToken = fetch();
    final symbol = symbolToken.text;
    consume();
    consumeSpaces();

    ParseNode? group;
    do {
      group = parseGroup(name);
    } while (group is InternalNode);

    if (group == null) {
      throw ParseError("Expected group after '$symbol'", symbolToken);
    }
    return group;
  }

  /// Converts unsupported command text into a colored text node.
  ColorNode formatUnsupportedCmd(String text) {
    final textordArray = <ParseNode>[
      for (var i = 0; i < text.length; i++)
        TextOrdNode(mode: Mode.text, text: text[i]),
    ];
    final textNode = TextNode(mode: mode, body: textordArray);
    return ColorNode(
      mode: mode,
      color: settings.errorColor,
      body: <ParseNode>[textNode],
    );
  }

  /// Parses a group with optional super/subscripts.
  ParseNode? parseAtom(String? breakOnTokenText) {
    final base = parseGroup('atom', breakOnTokenText);

    if (base is InternalNode) {
      return base;
    }
    if (mode == Mode.text) {
      return base;
    }

    ParseNode? superscript;
    ParseNode? subscript;
    while (true) {
      consumeSpaces();
      final lex = fetch();

      if (lex.text == r'\limits' || lex.text == r'\nolimits') {
        if (base is OpNode) {
          // OpNode is immutable; replace it with an updated copy below by
          // mutating via reconstruction. Mirror KaTeX semantics by tracking
          // the override.
          _applyLimits(base, lex.text == r'\limits');
        } else if (base is OperatorNameNode) {
          if (base.alwaysHandleSupSub) {
            _applyLimits(base, lex.text == r'\limits');
          }
        } else {
          throw ParseError('Limit controls must follow a math operator', lex);
        }
        consume();
      } else if (lex.text == '^') {
        if (superscript != null) {
          throw ParseError('Double superscript', lex);
        }
        superscript = handleSupSubscript('superscript');
      } else if (lex.text == '_') {
        if (subscript != null) {
          throw ParseError('Double subscript', lex);
        }
        subscript = handleSupSubscript('subscript');
      } else if (lex.text == "'") {
        if (superscript != null) {
          throw ParseError('Double superscript', lex);
        }
        final prime = TextOrdNode(mode: mode, text: r'\prime');
        final primes = <ParseNode>[prime];
        consume();
        while (fetch().text == "'") {
          primes.add(prime);
          consume();
        }
        if (fetch().text == '^') {
          primes.add(handleSupSubscript('superscript'));
        }
        superscript = OrdGroupNode(mode: mode, body: primes);
      } else {
        break;
      }
    }

    final resolvedBase = _resolvedLimitsBase(base);
    if (superscript != null && subscript != null) {
      return SupSubNode(
        mode: mode,
        base: resolvedBase,
        sup: superscript,
        sub: subscript,
      );
    } else if (superscript != null) {
      return SupSubNode(mode: mode, base: resolvedBase, sup: superscript);
    } else if (subscript != null) {
      return SupSubNode(mode: mode, base: resolvedBase, sub: subscript);
    } else {
      return resolvedBase;
    }
  }

  // KaTeX mutates op/operatorname nodes in place to record \limits. Our AST
  // nodes are immutable, so we stash the override keyed by identity and apply
  // it when the base is consumed by parseAtom.
  final Map<ParseNode, bool> _limitsOverride = <ParseNode, bool>{};

  void _applyLimits(ParseNode base, bool limits) {
    _limitsOverride[base] = limits;
  }

  ParseNode? _resolvedLimitsBase(ParseNode? base) {
    if (base == null) {
      return null;
    }
    final override = _limitsOverride.remove(base);
    if (override == null) {
      return base;
    }
    if (base is OpNode) {
      return OpNode(
        mode: base.mode,
        limits: override,
        parentIsSupSub: base.parentIsSupSub,
        symbol: base.symbol,
        loc: base.loc,
        name: base.name,
        body: base.body,
        alwaysHandleSupSub: true,
        suppressBaseShift: base.suppressBaseShift,
      );
    } else if (base is OperatorNameNode) {
      return OperatorNameNode(
        mode: base.mode,
        body: base.body,
        alwaysHandleSupSub: base.alwaysHandleSupSub,
        limits: override,
        parentIsSupSub: base.parentIsSupSub,
        loc: base.loc,
      );
    }
    return base;
  }

  /// Parses an entire function, including its base and arguments.
  ParseNode? parseFunction(String? breakOnTokenText, String? name) {
    final token = fetch();
    final func = token.text;
    final funcData = functions[func];
    if (funcData == null) {
      return null;
    }
    consume();

    if (name != null && name != 'atom' && !funcData.allowedInArgument) {
      throw ParseError(
        "Got function '$func' with no arguments as $name",
        token,
      );
    } else if (mode == Mode.text && !funcData.allowedInText) {
      throw ParseError("Can't use function '$func' in text mode", token);
    } else if (mode == Mode.math && !funcData.allowedInMath) {
      throw ParseError("Can't use function '$func' in math mode", token);
    }

    final parsed = parseArguments(
      func,
      numArgs: funcData.numArgs,
      numOptionalArgs: funcData.numOptionalArgs,
      argTypes: funcData.argTypes,
      isPrimitive: funcData.primitive,
      nodeType: funcData.type,
    );
    return callFunction(
      func,
      parsed.args,
      parsed.optArgs,
      token: token,
      breakOnTokenText: breakOnTokenText,
    );
  }

  /// Calls a function handler with a suitable context.
  ParseNode callFunction(
    String name,
    List<ParseNode> args,
    List<ParseNode?> optArgs, {
    Token? token,
    String? breakOnTokenText,
  }) {
    final context = FunctionContext(
      funcName: name,
      parser: this,
      token: token,
      breakOnTokenText: breakOnTokenText,
    );
    final func = functions[name];
    if (func != null && func.handler != null) {
      return func.handler!(context, args, optArgs);
    }
    throw ParseError('No function handler for $name');
  }

  /// Parses the arguments of a function or environment.
  ({List<ParseNode> args, List<ParseNode?> optArgs}) parseArguments(
    String func, {
    required int numArgs,
    required int numOptionalArgs,
    required List<ArgType?>? argTypes,
    bool isPrimitive = false,
    String? nodeType,
  }) {
    final totalArgs = numArgs + numOptionalArgs;
    if (totalArgs == 0) {
      return (args: <ParseNode>[], optArgs: <ParseNode?>[]);
    }

    final args = <ParseNode>[];
    final optArgs = <ParseNode?>[];

    for (var i = 0; i < totalArgs; i++) {
      var argType = (argTypes != null && i < argTypes.length)
          ? argTypes[i]
          : null;
      final isOptional = i < numOptionalArgs;

      if ((isPrimitive && argType == null) ||
          // \sqrt expands into primitive if optional argument doesn't exist
          (nodeType == 'sqrt' && i == 1 && optArgs[0] == null)) {
        argType = ArgType.primitive;
      }

      final arg = parseGroupOfType("argument to '$func'", argType, isOptional);
      if (isOptional) {
        optArgs.add(arg);
      } else if (arg != null) {
        args.add(arg);
      } else {
        throw ParseError('Null argument, please report this as a bug');
      }
    }

    return (args: args, optArgs: optArgs);
  }

  /// Parses a group when the mode may be changing.
  ParseNode? parseGroupOfType(String name, ArgType? type, bool optional) {
    switch (type) {
      case ArgType.color:
        return parseColorGroup(optional);
      case ArgType.size:
        return parseSizeGroup(optional);
      case ArgType.url:
        throw ParseError(r'\url is not supported in the MVP parser');
      case ArgType.math:
        return parseArgumentGroup(optional, Mode.math);
      case ArgType.text:
        return parseArgumentGroup(optional, Mode.text);
      case ArgType.hbox:
        final group = parseArgumentGroup(optional, Mode.text);
        return group != null
            ? StylingNode(
                mode: group.mode,
                style: StyleStr.text,
                body: <ParseNode>[group],
                resetFont: true,
              )
            : null;
      case ArgType.raw:
        final token = parseStringGroup(optional);
        return token != null
            ? RawNode(mode: Mode.text, string: token.text)
            : null;
      case ArgType.primitive:
        if (optional) {
          throw ParseError('A primitive argument cannot be optional');
        }
        final group = parseGroup(name);
        if (group == null) {
          throw ParseError('Expected group as $name', fetch());
        }
        return group;
      case null:
        return parseArgumentGroup(optional, null);
    }
  }

  /// Discards any space tokens, fetching the next non-space token.
  void consumeSpaces() {
    while (fetch().text == ' ') {
      consume();
    }
  }

  /// Parses a brace-enclosed group as a single string token.
  Token? parseStringGroup(bool optional) {
    final argToken = gullet.scanArgument(isOptional: optional);
    if (argToken == null) {
      return null;
    }
    final str = StringBuffer();
    Token nextToken;
    while ((nextToken = fetch()).text != 'EOF') {
      str.write(nextToken.text);
      consume();
    }
    consume(); // consume the end of the argument
    argToken.text = str.toString();
    return argToken;
  }

  /// Parses a regex-delimited group (used for unbraced size arguments).
  Token parseRegexGroup(RegExp regex, String modeName) {
    final firstToken = fetch();
    var lastToken = firstToken;
    final str = StringBuffer();
    Token nextToken;
    while ((nextToken = fetch()).text != 'EOF' &&
        regex.hasMatch(str.toString() + nextToken.text)) {
      lastToken = nextToken;
      str.write(lastToken.text);
      consume();
    }
    if (str.isEmpty) {
      throw ParseError("Invalid $modeName: '${firstToken.text}'", firstToken);
    }
    return firstToken.range(lastToken, str.toString());
  }

  /// Parses a color description argument.
  ColorTokenNode? parseColorGroup(bool optional) {
    final res = parseStringGroup(optional);
    if (res == null) {
      return null;
    }
    final match = RegExp(
      r'^(#[a-f0-9]{3,4}|#[a-f0-9]{6}|#[a-f0-9]{8}|[a-f0-9]{6}|[a-z]+)$',
      caseSensitive: false,
    ).firstMatch(res.text);
    if (match == null) {
      throw ParseError("Invalid color: '${res.text}'", res);
    }
    var color = match.group(0)!;
    if (RegExp(r'^[0-9a-f]{6}$', caseSensitive: false).hasMatch(color)) {
      color = '#$color';
    }
    return ColorTokenNode(mode: mode, color: color);
  }

  /// Parses a size specification (magnitude + unit).
  SizeNode? parseSizeGroup(bool optional) {
    Token? res;
    var isBlank = false;
    gullet.consumeSpaces();
    if (!optional && gullet.future().text != '{') {
      res = parseRegexGroup(
        RegExp(r'^[-+]? *(?:$|\d+|\d+\.\d*|\.\d*) *[a-z]{0,2} *$'),
        'size',
      );
    } else {
      res = parseStringGroup(optional);
    }
    if (res == null) {
      return null;
    }
    if (!optional && res.text.isEmpty) {
      res.text = '0pt';
      isBlank = true;
    }
    final match = RegExp(
      r'([-+]?) *(\d+(?:\.\d*)?|\.\d+) *([a-z]{2})',
    ).firstMatch(res.text);
    if (match == null) {
      throw ParseError("Invalid size: '${res.text}'", res);
    }
    final number = double.parse('${match.group(1)}${match.group(2)}');
    final unit = match.group(3)!;
    if (!_validUnit(unit)) {
      throw ParseError("Invalid unit: '$unit'", res);
    }
    return SizeNode(
      mode: mode,
      value: Measurement(number, unit),
      isBlank: isBlank,
    );
  }

  /// Parses an argument in the (optionally switched) [argMode].
  OrdGroupNode? parseArgumentGroup(bool optional, Mode? argMode) {
    final argToken = gullet.scanArgument(isOptional: optional);
    if (argToken == null) {
      return null;
    }
    final outerMode = mode;
    if (argMode != null) {
      switchMode(argMode);
    }

    gullet.beginGroup();
    final expression = parseExpression(
      breakOnInfix: false,
      breakOnTokenText: 'EOF',
    );
    expect('EOF');
    gullet.endGroup();
    final result = OrdGroupNode(
      mode: mode,
      loc: argToken.loc,
      body: expression,
    );

    if (argMode != null) {
      switchMode(outerMode);
    }
    return result;
  }

  /// Parses an ordinary group: a single nucleus, a braced expression, or an
  /// implicit group (a function invocation).
  ParseNode? parseGroup(String name, [String? breakOnTokenText]) {
    final firstToken = fetch();
    final text = firstToken.text;

    ParseNode? result;
    if (text == '{' || text == r'\begingroup') {
      consume();
      final groupEnd = text == '{' ? '}' : r'\endgroup';

      gullet.beginGroup();
      final expression = parseExpression(
        breakOnInfix: false,
        breakOnTokenText: groupEnd,
      );
      final lastToken = fetch();
      expect(groupEnd);
      gullet.endGroup();
      result = OrdGroupNode(
        mode: mode,
        loc: SourceLocation.range(firstToken.loc, lastToken.loc),
        body: expression,
        semisimple: text == r'\begingroup' ? true : null,
      );
    } else {
      result = parseFunction(breakOnTokenText, name) ?? parseSymbol();
      if (result == null &&
          text.isNotEmpty &&
          text[0] == r'\' &&
          !implicitCommands.contains(text)) {
        if (settings.throwOnError) {
          throw ParseError('Undefined control sequence: $text', firstToken);
        }
        result = formatUnsupportedCmd(text);
        consume();
      }
    }
    return result;
  }

  /// Forms text-mode ligatures (`--`, `---`, ``` `` ```, `''`) in place.
  void _formLigatures(List<ParseNode> group) {
    var n = group.length - 1;
    for (var i = 0; i < n; ++i) {
      final a = group[i];
      if (a is! TextOrdNode) {
        continue;
      }
      final v = a.text;
      final next = group[i + 1];
      if (next is! TextOrdNode) {
        continue;
      }
      if (v == '-' && next.text == '-') {
        final afterNext = i + 2 < group.length ? group[i + 2] : null;
        if (i + 1 < n && afterNext is TextOrdNode && afterNext.text == '-') {
          group.replaceRange(i, i + 3, <ParseNode>[
            TextOrdNode(
              mode: Mode.text,
              text: '---',
              loc: SourceLocation.range(a.loc, afterNext.loc),
            ),
          ]);
          n -= 2;
        } else {
          group.replaceRange(i, i + 2, <ParseNode>[
            TextOrdNode(
              mode: Mode.text,
              text: '--',
              loc: SourceLocation.range(a.loc, next.loc),
            ),
          ]);
          n -= 1;
        }
      }
      if ((v == "'" || v == '`') && next.text == v) {
        group.replaceRange(i, i + 2, <ParseNode>[
          TextOrdNode(
            mode: Mode.text,
            text: v + v,
            loc: SourceLocation.range(a.loc, next.loc),
          ),
        ]);
        n -= 1;
      }
    }
  }

  /// Parses a single symbol out of the token stream.
  ParseNode? parseSymbol() {
    final nucleus = fetch();
    var text = nucleus.text;

    if (RegExp(r'^\\verb[^a-zA-Z]').hasMatch(text)) {
      throw ParseError(r'\verb is not supported in the MVP parser');
    }

    // Strip off any combining characters.
    final match = combiningDiacriticalMarksEndRegex.firstMatch(text);
    if (match != null) {
      text = text.substring(0, match.start);
      if (text == 'i') {
        text = 'ı'; // dotless i
      } else if (text == 'j') {
        text = 'ȷ'; // dotless j
      }
    }

    ParseNode symbol;
    final data = Symbols.lookup(mode, text);
    if (data != null) {
      final group = data.group;
      final loc = SourceLocation.range(nucleus.loc, nucleus.loc);
      symbol = _symbolNode(group, text, loc);
    } else if (text.isNotEmpty && text.codeUnitAt(0) >= 0x80) {
      // Non-ASCII: render as text-mode textord (KaTeX behavior).
      symbol = TextOrdNode(
        mode: Mode.text,
        text: text,
        loc: SourceLocation.range(nucleus.loc, nucleus.loc),
      );
    } else {
      return null; // EOF, ^, _, {, }, etc.
    }
    consume();

    // Transform trailing combining characters into accents.
    if (match != null) {
      final marks = match.group(0)!;
      for (var i = 0; i < marks.length; i++) {
        final accent = marks[i];
        final command = _unicodeAccentCommands[accent];
        if (command == null) {
          throw ParseError("Unknown accent ' $accent'", nucleus);
        }
        symbol = AccentNode(
          mode: mode,
          loc: SourceLocation.range(nucleus.loc, nucleus.loc),
          label: command,
          isStretchy: false,
          isShifty: true,
          base: symbol,
        );
      }
    }
    return symbol;
  }

  SymbolParseNode _symbolNode(Group group, String text, SourceLocation? loc) {
    switch (group) {
      case Group.bin:
      case Group.rel:
      case Group.open:
      case Group.close:
      case Group.punct:
      case Group.inner:
        return AtomNode(mode: mode, text: text, family: group, loc: loc);
      case Group.mathord:
        return MathOrdNode(mode: mode, text: text, loc: loc);
      case Group.textord:
        return TextOrdNode(mode: mode, text: text, loc: loc);
      case Group.spacing:
        return SpacingNode(mode: mode, text: text, loc: loc);
      case Group.accent:
        return AccentTokenNode(mode: mode, text: text, loc: loc);
      case Group.op:
        return OpTokenNode(mode: mode, text: text, loc: loc);
    }
  }

  // ----- environment helpers (used by functions/environment registration) ---

  /// Parses the body of an environment via its [spec], returning the args.
  ({List<ParseNode> args, List<ParseNode?> optArgs}) parseEnvironmentArguments(
    String func,
    EnvSpec spec,
  ) {
    return parseArguments(
      func,
      numArgs: spec.numArgs,
      numOptionalArgs: spec.numOptionalArgs,
      argTypes: spec.argTypes,
    );
  }
}

bool _validUnit(String unit) {
  const valid = <String>{
    'pt',
    'mm',
    'cm',
    'in',
    'bp',
    'pc',
    'dd',
    'cc',
    'nd',
    'nc',
    'sp',
    'px',
    'ex',
    'em',
    'mu',
  };
  return valid.contains(unit);
}

// Minimal map of combining diacritical marks to accent commands, mirroring
// the MVP subset of KaTeX's `unicodeAccents`.
const Map<String, String> _unicodeAccentCommands = <String, String>{
  '́': r'\acute',
  '̀': r'\grave',
  '̈': r'\ddot',
  '̃': r'\tilde',
  '̄': r'\bar',
  '̆': r'\breve',
  '̌': r'\check',
  '̂': r'\hat',
  '̇': r'\dot',
  '̊': r'\mathring',
};
