/// The "gullet" where macros are expanded until only non-macro tokens remain.
///
/// Port of KaTeX's `MacroExpander.ts`. Sits between the [Lexer] and the Parser:
/// it owns the lexer plus a pushback token stack and a [Namespace] of macro
/// definitions, exposing the same surface the KaTeX Parser drives.
library;

import 'package:katex/src/parse/lexer.dart';
import 'package:katex/src/parse/macros.dart';
import 'package:katex/src/parse/namespace.dart';
import 'package:katex/src/parse/parse_error.dart';
import 'package:katex/src/parse/settings.dart';
import 'package:katex/src/parse/source_location.dart';
import 'package:katex/src/parse/token.dart';
import 'package:katex/src/symbols/symbols.dart';

/// Commands that act like macros but aren't defined as a macro, function, or
/// symbol. Used in [MacroExpander.isDefined].
///
/// Mirrors KaTeX's `implicitCommands`.
const Set<String> implicitCommands = <String>{
  '^', // Parser
  '_', // Parser
  r'\limits', // Parser
  r'\nolimits', // Parser
};

/// The result of consuming a macro argument: the resulting [tokens] plus the
/// [start] and [end] tokens of the consumed range.
///
/// Mirrors KaTeX's `MacroArg`.
class MacroArg {
  /// Creates a macro-argument result.
  const MacroArg({
    required this.tokens,
    required this.start,
    required this.end,
  });

  /// The argument tokens, in reverse (stack) order.
  final List<Token> tokens;

  /// The first token of the consumed range.
  final Token start;

  /// The last token of the consumed range.
  final Token end;
}

/// Expands macros from an input string until only non-macro tokens remain.
class MacroExpander implements MacroContext {
  /// Creates a macro expander over [input], using [settings], in [mode].
  MacroExpander(String input, this.settings, this._mode) : expansionCount = 0 {
    feed(input);
    // Make a new global namespace: builtins from [builtinMacros], plus any
    // user macros from settings.
    macros = Namespace<MacroDefinition>(
      builtinMacros,
      _settingsMacros(settings),
    );
    stack = <Token>[];
  }

  /// Settings controlling expansion limits, strict mode, etc.
  final Settings settings;

  /// Running count of expansions, checked against [Settings.maxExpand].
  int expansionCount;

  /// The lexer feeding tokens. Reset by [feed].
  late Lexer lexer;

  /// The macro namespace (builtins + user/global macros).
  late Namespace<MacroDefinition> macros;

  /// The pushback token stack. Contains tokens in REVERSE order (top = last).
  late List<Token> stack;

  Mode _mode;

  @override
  Mode get mode => _mode;

  /// Optional hook used by [isDefined]/[isExpandable] to consult the function
  /// table once the Parser/functions layer (T-008) is wired in.
  ///
  /// Until then it is `null` and only macros, symbols, and implicit commands
  /// are considered. The Parser may set this so undefined-control-sequence
  /// detection matches KaTeX exactly.
  bool Function(String name)? functionExists;

  /// Whether the named function is a "primitive" (non-expandable) function.
  /// Companion to [functionExists]; see its docs. Defaults to treating unknown
  /// names as non-primitive.
  bool Function(String name)? functionIsPrimitive;

  /// Feed a new input string to the same expander (keeping existing macros).
  void feed(String input) {
    lexer = Lexer(input, settings);
  }

  /// Switches between text and math modes.
  ///
  /// Faithful port of KaTeX's `switchMode`; the [mode] setter is the idiomatic
  /// Dart equivalent and is used where the Parser restores saved state.
  // ignore: use_setters_to_change_properties
  void switchMode(Mode newMode) {
    _mode = newMode;
  }

  /// Set the current mode directly (used by the Parser when restoring state).
  set mode(Mode newMode) {
    _mode = newMode;
  }

  /// Start a new group nesting within all namespaces.
  void beginGroup() {
    macros.beginGroup();
  }

  /// End current group nesting within all namespaces.
  void endGroup() {
    macros.endGroup();
  }

  /// Ends all currently nested groups, restoring values before they began.
  void endGroups() {
    macros.endGroups();
  }

  @override
  Token future() {
    if (stack.isEmpty) {
      pushToken(lexer.lex());
    }
    return stack[stack.length - 1];
  }

  @override
  Token popToken() {
    future(); // ensure non-empty stack
    return stack.removeLast();
  }

  /// Add a given [token] to the token stack. Can be used to put back a token
  /// returned from one of the other methods.
  void pushToken(Token token) {
    stack.add(token);
  }

  /// Append a list of [tokens] to the token stack.
  void pushTokens(List<Token> tokens) {
    stack.addAll(tokens);
  }

  /// Find a macro argument without expanding tokens and append the resulting
  /// tokens to the token stack. Uses a [Token] as a container for the result.
  Token? scanArgument({required bool isOptional}) {
    Token start;
    Token end;
    List<Token> tokens;
    if (isOptional) {
      consumeSpaces(); // \@ifnextchar gobbles any space following it
      if (future().text != '[') {
        return null;
      }
      start = popToken(); // don't include [ in tokens
      final arg = consumeArg(<String>[']']);
      tokens = arg.tokens;
      end = arg.end;
    } else {
      final arg = consumeArg();
      tokens = arg.tokens;
      start = arg.start;
      end = arg.end;
    }

    // indicate the end of an argument
    pushToken(Token('EOF', end.loc));

    pushTokens(tokens);
    return Token('', SourceLocation.range(start.loc, end.loc));
  }

  @override
  void consumeSpaces() {
    for (;;) {
      final token = future();
      if (token.text == ' ') {
        stack.removeLast();
      } else {
        break;
      }
    }
  }

  /// Consume an argument from the token stream, and return the resulting tokens
  /// plus start/end token.
  ///
  /// When [delims] is non-empty, the argument is delimited (ends when the
  /// delimiter sequence is matched at the right nesting depth); otherwise it is
  /// the next nonblank token (or `{...}` group).
  MacroArg consumeArg([List<String>? delims]) {
    final tokens = <Token>[];
    final isDelimited = delims != null && delims.isNotEmpty;
    if (!isDelimited) {
      // Ignore spaces between arguments (TeX doesn't use single spaces as
      // undelimited arguments).
      consumeSpaces();
    }
    final start = future();
    Token tok;
    var depth = 0;
    var match = 0;
    do {
      tok = popToken();
      tokens.add(tok);
      if (tok.text == '{') {
        ++depth;
      } else if (tok.text == '}') {
        --depth;
        if (depth == -1) {
          throw ParseError('Extra }', tok);
        }
      } else if (tok.text == 'EOF') {
        throw ParseError(
          'Unexpected end of input in a macro argument, expected '
          "'${isDelimited ? delims[match] : '}'}'",
          tok,
        );
      }
      if (isDelimited) {
        if ((depth == 0 || (depth == 1 && delims[match] == '{')) &&
            tok.text == delims[match]) {
          ++match;
          if (match == delims.length) {
            // don't include delims in tokens
            tokens.removeRange(tokens.length - match, tokens.length);
            break;
          }
        } else {
          match = 0;
        }
      }
    } while (depth != 0 || isDelimited);
    // If the argument has the form `{<nested tokens>}`, the outermost braces
    // enclosing the argument are removed.
    if (start.text == '{' && tokens.isNotEmpty && tokens.last.text == '}') {
      tokens
        ..removeLast()
        ..removeAt(0);
    }
    // Reverse to fit in with stack order.
    final reversed = tokens.reversed.toList();
    return MacroArg(tokens: reversed, start: start, end: tok);
  }

  /// Consume [numArgs] (optionally delimited) arguments and return them.
  ///
  /// Mirrors KaTeX's `consumeArgs`.
  List<List<Token>> consumeArgs(int numArgs, [List<List<String>>? delimiters]) {
    if (delimiters != null) {
      if (delimiters.length != numArgs + 1) {
        throw ParseError(
          "The length of delimiters doesn't match the number of args!",
        );
      }
      final delims = delimiters[0];
      for (var i = 0; i < delims.length; i++) {
        final tok = popToken();
        if (delims[i] != tok.text) {
          throw ParseError(
            "Use of the macro doesn't match its definition",
            tok,
          );
        }
      }
    }

    final args = <List<Token>>[];
    for (var i = 0; i < numArgs; i++) {
      args.add(consumeArg(delimiters?[i + 1]).tokens);
    }
    return args;
  }

  /// Increment [expansionCount] by [amount], throwing if it exceeds maxExpand.
  void countExpansion(int amount) {
    expansionCount += amount;
    if (expansionCount > settings.maxExpand) {
      throw ParseError(
        'Too many expansions: infinite loop or need to increase maxExpand '
        'setting',
      );
    }
  }

  /// Expand the next token only once if possible.
  ///
  /// If the token is expanded, the resulting tokens are pushed onto the stack
  /// in reverse order and the number of such tokens is returned (zero or
  /// positive). If not, the return value is `false` and the next token remains
  /// on top of the stack.
  ///
  /// If [expandableOnly] is true, only expandable tokens are expanded and an
  /// undefined control sequence results in an error.
  Object expandOnce({bool expandableOnly = false}) {
    final topToken = popToken();
    final name = topToken.text;
    final expansion = (topToken.noexpand ?? false) ? null : _getExpansion(name);
    if (expansion == null || (expandableOnly && expansion.unexpandable)) {
      if (expandableOnly &&
          expansion == null &&
          name.isNotEmpty &&
          name[0] == r'\' &&
          !isDefined(name)) {
        throw ParseError('Undefined control sequence: $name');
      }
      pushToken(topToken);
      return false;
    }
    countExpansion(1);
    var tokens = expansion.tokens;
    final args = consumeArgs(expansion.numArgs, expansion.delimiters);
    if (expansion.numArgs > 0) {
      // paste arguments in place of the placeholders
      tokens = tokens.toList(); // shallow copy
      for (var i = tokens.length - 1; i >= 0; --i) {
        var tok = tokens[i];
        if (tok.text == '#') {
          if (i == 0) {
            throw ParseError(
              'Incomplete placeholder at end of macro body',
              tok,
            );
          }
          tok = tokens[--i]; // next token on stack
          if (tok.text == '#') {
            // ## → #
            tokens.removeAt(i + 1); // drop first #
          } else if (RegExp(r'^[1-9]$').hasMatch(tok.text)) {
            // replace the placeholder with the indicated argument
            final arg = args[int.parse(tok.text) - 1];
            tokens.replaceRange(i, i + 2, arg);
          } else {
            throw ParseError('Not a valid argument number', tok);
          }
        }
      }
    }
    // Concatenate expansion onto top of stack.
    pushTokens(tokens);
    return tokens.length;
  }

  /// Expand the next token only once (if possible), and return the resulting
  /// top token on the stack. Equivalent to [expandOnce] followed by [future].
  @override
  Token expandAfterFuture() {
    expandOnce();
    return future();
  }

  /// Recursively expand the first token, then return the first non-expandable
  /// token.
  Token expandNextToken() {
    for (;;) {
      if (expandOnce() == false) {
        // fully expanded
        final token = stack.removeLast();
        // the token after \noexpand is interpreted as if its meaning were
        // `\relax`.
        if (token.treatAsRelax ?? false) {
          token.text = r'\relax';
        }
        return token;
      }
    }
  }

  /// Fully expand the given macro [name] and return the resulting tokens, or
  /// `null` if no such macro is defined.
  List<Token>? expandMacro(String name) {
    return macros.has(name) ? expandTokens(<Token>[Token(name)]) : null;
  }

  /// Fully expand the given [tokens] (in reverse order) and return the
  /// resulting tokens in forward order.
  List<Token> expandTokens(List<Token> tokens) {
    final output = <Token>[];
    final oldStackLength = stack.length;
    pushTokens(tokens);
    while (stack.length > oldStackLength) {
      // Expand only expandable tokens.
      if (expandOnce(expandableOnly: true) == false) {
        // fully expanded
        final token = stack.removeLast();
        if (token.treatAsRelax ?? false) {
          // the expansion of \noexpand is the token itself
          token
            ..noexpand = false
            ..treatAsRelax = false;
        }
        output.add(token);
      }
    }
    // Count all of these tokens as additional expansions, to prevent
    // exponential blowup from linearly many \edef's.
    countExpansion(output.length);
    return output;
  }

  /// Fully expand the given macro [name] and return the result as a string, or
  /// `null` if no such macro is defined.
  String? expandMacroAsText(String name) {
    final tokens = expandMacro(name);
    if (tokens != null) {
      return tokens.map((token) => token.text).join();
    }
    return null;
  }

  /// Returns the expanded macro as a reversed list of tokens plus a macro
  /// argument count, or `null` if no such macro.
  MacroExpansion? _getExpansion(String name) {
    final definition = macros.get(name);

    if (definition == null) {
      return null;
    }
    // If a single character has an associated catcode other than 13 (active
    // character), then don't expand it.
    if (name.length == 1) {
      final catcode = lexer.catcodes[name];
      if (catcode != null && catcode != 13) {
        return null;
      }
    }
    final expansion = definition is MacroFunction
        ? definition(this)
        : definition;
    if (expansion is String) {
      var numArgs = 0;
      if (expansion.contains('#')) {
        final stripped = expansion.replaceAll('##', '');
        while (stripped.contains('#${numArgs + 1}')) {
          ++numArgs;
        }
      }
      final bodyLexer = Lexer(expansion, settings);
      final tokens = <Token>[];
      var tok = bodyLexer.lex();
      while (tok.text != 'EOF') {
        tokens.add(tok);
        tok = bodyLexer.lex();
      }
      // Reverse to fit in with stack using push and pop.
      final reversed = tokens.reversed.toList();
      return MacroExpansion(tokens: reversed, numArgs: numArgs);
    }
    if (expansion is MacroExpansion) {
      return expansion;
    }
    // A function may itself return a string (handled above) or a
    // MacroExpansion; any other type is a programming error.
    throw ParseError('Invalid macro definition for $name');
  }

  @override
  bool isDefined(String name) {
    return macros.has(name) ||
        (functionExists?.call(name) ?? false) ||
        Symbols.lookup(Mode.math, name) != null ||
        Symbols.lookup(Mode.text, name) != null ||
        implicitCommands.contains(name);
  }

  @override
  bool isExpandable(String name) {
    final macro = macros.get(name);
    if (macro != null) {
      return macro is String ||
          macro is MacroFunction ||
          (macro is MacroExpansion && !macro.unexpandable);
    }
    // Falls back to the function table (T-008): a function is expandable iff it
    // exists and is not a primitive.
    return (functionExists?.call(name) ?? false) &&
        !(functionIsPrimitive?.call(name) ?? false);
  }
}

/// Build the initial global macro map from user-supplied [Settings.macros],
/// keeping only entries whose values are valid [MacroDefinition]s.
Map<String, MacroDefinition> _settingsMacros(Settings settings) {
  final result = <String, MacroDefinition>{};
  settings.macros.forEach((key, value) {
    if (value is String || value is MacroExpansion || value is MacroFunction) {
      result[key] = value!;
    }
  });
  return result;
}
