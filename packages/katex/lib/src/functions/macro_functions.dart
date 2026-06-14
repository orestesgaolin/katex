/// Macro definitions that KaTeX registers from `src/macros.ts`'s "macro tools"
/// section and from `functions/operatorname.ts`. These were not part of
/// T-038's `macros.ts` subset; they are registered here (into [builtinMacros])
/// alongside the function-table registration so the dependent macros light up.
///
/// Faithful port of the corresponding `defineMacro` calls in
/// `reference/node_modules/katex/src/macros.ts` (pinned KaTeX 0.17.0).
library;

import 'package:katex/src/parse/macro_expander.dart';
import 'package:katex/src/parse/macros.dart';
import 'package:katex/src/parse/parse_error.dart';
import 'package:katex/src/parse/token.dart';

bool _registered = false;

/// Registers the macro-tools / operatorname macros into [builtinMacros] exactly
/// once. Called from the function-registration path (`ensureRegistered`), which
/// always runs before a [MacroExpander] is constructed.
void ensureMacrosRegistered() {
  if (_registered) {
    return;
  }
  _registered = true;

  void defineMacro(String name, MacroDefinition body) {
    builtinMacros[name] = body;
  }

  // The concrete MacroContext is always a MacroExpander; cast to reach the
  // expansion primitives (`expandOnce`, `expandNextToken`, `pushToken`) that
  // the def-family macros need but which the MacroContext interface omits.
  MacroExpander exp(MacroContext c) => c as MacroExpander;

  // -------------------------------------------------------------------------
  // macro tools

  defineMacro(r'\noexpand', (MacroContext context) {
    // The expansion is the token itself; but that token is interpreted as if
    // its meaning were `\relax` if it is a control sequence that would
    // ordinarily be expanded by TeX's expansion rules.
    final t = context.popToken();
    if (context.isExpandable(t.text)) {
      t
        ..noexpand = true
        ..treatAsRelax = true;
    }
    return MacroExpansion(tokens: <Token>[t], numArgs: 0);
  });

  defineMacro(r'\expandafter', (MacroContext context) {
    // TeX first reads the token that comes immediately after \expandafter,
    // without expanding it; call this token t. Then TeX reads the token that
    // comes after t, replacing it by its expansion. Finally TeX puts t back in
    // front of that expansion.
    final t = context.popToken();
    exp(context).expandOnce(expandableOnly: true); // expand only expandable
    return MacroExpansion(tokens: <Token>[t], numArgs: 0);
  });

  // LaTeX's \@firstoftwo{#1}{#2} expands to #1, skipping #2.
  defineMacro(r'\@firstoftwo', (MacroContext context) {
    final args = context.consumeArgs(2);
    return MacroExpansion(tokens: args[0], numArgs: 0);
  });

  // LaTeX's \@secondoftwo{#1}{#2} expands to #2, skipping #1.
  defineMacro(r'\@secondoftwo', (MacroContext context) {
    final args = context.consumeArgs(2);
    return MacroExpansion(tokens: args[1], numArgs: 0);
  });

  // LaTeX's \@ifnextchar{#1}{#2}{#3} looks ahead to the next (unexpanded)
  // nonspace token; if it matches #1, expands to #2, else to #3.
  defineMacro(r'\@ifnextchar', (MacroContext context) {
    final args = context.consumeArgs(3); // symbol, if, else
    context.consumeSpaces();
    final nextToken = context.future();
    if (args[0].length == 1 && args[0][0].text == nextToken.text) {
      return MacroExpansion(tokens: args[1], numArgs: 0);
    } else {
      return MacroExpansion(tokens: args[2], numArgs: 0);
    }
  });

  // \def\@ifstar#1{\@ifnextchar *{\@firstoftwo{#1}}}
  defineMacro(r'\@ifstar', r'\@ifnextchar *{\@firstoftwo{#1}}');

  // \char makes a literal character (catcode 12). The forms (TeXbook p. 43):
  //   \char123 (decimal), \char'123 (octal), \char"123 (hex),
  //   \char`x / \char`\x (the character's code point).
  // These turn into a call to the function \@char.
  defineMacro(r'\char', (MacroContext context) {
    var token = context.popToken();
    int? base;
    var number = 0;
    if (token.text == "'") {
      base = 8;
      token = context.popToken();
    } else if (token.text == '"') {
      base = 16;
      token = context.popToken();
    } else if (token.text == '`') {
      token = context.popToken();
      if (token.text.startsWith(r'\')) {
        number = token.text.codeUnitAt(1);
      } else if (token.text == 'EOF') {
        throw ParseError(r'\char` missing argument');
      } else {
        number = token.text.codeUnitAt(0);
      }
    } else {
      base = 10;
    }
    if (base != null) {
      // Parse a number in the given base, starting with the first token.
      final first = _digitToNumber[token.text];
      if (first == null || first >= base) {
        throw ParseError('Invalid base-$base digit ${token.text}');
      }
      number = first;
      int? digit;
      while ((digit = _digitToNumber[context.future().text]) != null &&
          digit! < base) {
        number *= base;
        number += digit;
        context.popToken();
      }
    }
    return r'\@char{' '$number' '}';
  });

  // \newcommand / \renewcommand / \providecommand.
  defineMacro(
    r'\newcommand',
    (MacroContext context) => _newcommand(context, false, true, false),
  );
  defineMacro(
    r'\renewcommand',
    (MacroContext context) => _newcommand(context, true, false, false),
  );
  defineMacro(
    r'\providecommand',
    (MacroContext context) => _newcommand(context, true, true, true),
  );

  // terminal (console) tools — visual no-ops here; consume their arguments.
  defineMacro(r'\message', (MacroContext context) {
    context.consumeArgs(1);
    return '';
  });
  defineMacro(r'\errmessage', (MacroContext context) {
    context.consumeArgs(1);
    return '';
  });
  defineMacro(r'\show', (MacroContext context) {
    context.popToken();
    return '';
  });

  // phantom.ts — \hphantom is a macro.
  defineMacro(r'\hphantom', r'\smash{\phantom{#1}}');

  // -------------------------------------------------------------------------
  // operatorname.ts
  defineMacro(
    r'\operatorname',
    r'\@ifstar\operatornamewithlimits\operatorname@',
  );
}

// Lookup table for parsing numbers in base 8 through 16.
const Map<String, int> _digitToNumber = <String, int>{
  '0': 0, '1': 1, '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8,
  '9': 9, 'a': 10, 'A': 10, 'b': 11, 'B': 11, 'c': 12, 'C': 12, //
  'd': 13, 'D': 13, 'e': 14, 'E': 14, 'f': 15, 'F': 15,
};

// \newcommand{\macro}[args]{definition} etc.
String _newcommand(
  MacroContext context,
  bool existsOK,
  bool nonexistsOK,
  bool skipIfExists,
) {
  final exp = context as MacroExpander;
  var arg = exp.consumeArg().tokens;
  if (arg.length != 1) {
    throw ParseError(r"\newcommand's first argument must be a macro name");
  }
  final name = arg[0].text;

  final exists = context.isDefined(name);
  if (exists && !existsOK) {
    throw ParseError(
      r'\newcommand{' '$name' '} attempting to redefine $name; '
      r'use \renewcommand',
    );
  }
  if (!exists && !nonexistsOK) {
    throw ParseError(
      r'\renewcommand{' '$name' '} when command $name does not yet exist; '
      r'use \newcommand',
    );
  }

  var numArgs = 0;
  arg = exp.consumeArg().tokens;
  if (arg.length == 1 && arg[0].text == '[') {
    final argText = StringBuffer();
    var token = exp.expandNextToken();
    while (token.text != ']' && token.text != 'EOF') {
      argText.write(token.text);
      token = exp.expandNextToken();
    }
    final text = argText.toString();
    if (!RegExp(r'^\s*[0-9]+\s*$').hasMatch(text)) {
      throw ParseError('Invalid number of arguments: $text');
    }
    numArgs = int.parse(text.trim());
    arg = exp.consumeArg().tokens;
  }

  if (!(exists && skipIfExists)) {
    // Final arg is the expansion of the macro.
    context.macros.set(name, MacroExpansion(tokens: arg, numArgs: numArgs));
  }
  return '';
}
