import 'package:katex/src/parse/macro_expander.dart';
import 'package:katex/src/parse/macros.dart';
import 'package:katex/src/parse/namespace.dart';
import 'package:katex/src/parse/parse_error.dart';
import 'package:katex/src/parse/settings.dart';
import 'package:katex/src/types.dart';
import 'package:test/test.dart';

/// Builds a [MacroExpander] over [input] in math mode with default settings.
MacroExpander expander(String input, [Settings? settings]) =>
    MacroExpander(input, settings ?? Settings(), Mode.math);

/// Fully expands [input] and returns the resulting (forward-order) token texts,
/// stopping at EOF.
List<String> expandAll(String input, [Settings? settings]) {
  final mex = expander(input, settings);
  final texts = <String>[];
  for (;;) {
    final token = mex.expandNextToken();
    if (token.text == 'EOF') {
      break;
    }
    texts.add(token.text);
  }
  return texts;
}

void main() {
  group('Namespace', () {
    test('get/set/has with builtins and current', () {
      final ns = Namespace<String>({'a': 'A'}, {'b': 'B'});
      expect(ns.has('a'), isTrue);
      expect(ns.has('b'), isTrue);
      expect(ns.has('c'), isFalse);
      expect(ns.get('a'), 'A');
      expect(ns.get('b'), 'B');
      expect(ns.get('c'), isNull);
    });

    test('begin/endGroup restores prior values and deletions', () {
      final ns = Namespace<String>({}, {'x': 'orig'})
        ..beginGroup()
        ..set('x', 'inner')
        ..set('y', 'new');
      expect(ns.get('x'), 'inner');
      expect(ns.get('y'), 'new');
      ns.endGroup();
      // x restored to its pre-group value; y (no prior value) removed.
      expect(ns.get('x'), 'orig');
      expect(ns.has('y'), isFalse);
    });

    test('global set survives endGroup', () {
      final ns = Namespace<String>({}, {})
        ..beginGroup()
        ..set('g', 'global', global: true)
        ..endGroup();
      expect(ns.get('g'), 'global');
    });

    test('endGroup on global namespace throws', () {
      final ns = Namespace<String>({}, {});
      expect(ns.endGroup, throwsA(isA<ParseError>()));
    });
  });

  group('MacroExpander.consumeSpaces', () {
    test('skips leading spaces, leaving the next token', () {
      final mex = expander('   x')..consumeSpaces();
      expect(mex.future().text, 'x');
    });
  });

  group('MacroExpander.consumeArg / consumeArgs', () {
    test('undelimited arg grabs a single token', () {
      final mex = expander('ab');
      final arg = mex.consumeArg();
      expect(arg.tokens.map((t) => t.text).toList(), <String>['a']);
      // 'b' remains.
      expect(mex.popToken().text, 'b');
    });

    test('grabs a {...} group, stripping the outer braces', () {
      final mex = expander('{abc}rest');
      final arg = mex.consumeArg();
      // tokens are returned in reverse (stack) order.
      expect(
        arg.tokens.map((t) => t.text).toList(),
        <String>['c', 'b', 'a'],
      );
      expect(mex.popToken().text, 'r');
    });

    test('consumeArgs grabs multiple {...} groups in order', () {
      final mex = expander('{a}{bc}');
      final args = mex.consumeArgs(2);
      expect(args.length, 2);
      // First arg.
      expect(args[0].map((t) => t.text).toList(), <String>['a']);
      // Second arg, reverse order.
      expect(args[1].map((t) => t.text).toList(), <String>['c', 'b']);
    });

    test('unbalanced } in an argument throws', () {
      final mex = expander('}');
      expect(mex.consumeArg, throwsA(isA<ParseError>()));
    });
  });

  group('MacroExpander builtin macros', () {
    test(r'\cdots expands to \@cdots when not before a right delimiter', () {
      // \cdots is a function-valued macro that inspects the following token.
      expect(expandAll(r'\cdots'), <String>[r'\@cdots']);
    });

    test(r'\cdots adds a thin space before a right delimiter', () {
      // \cdots -> \@cdots\, before ')'. The trailing \, is itself a macro and
      // is recursively expanded by expandNextToken; we only assert that the
      // expansion begins with \@cdots and still ends at the ')'.
      final tokens = expandAll(r'\cdots)');
      expect(tokens.first, r'\@cdots');
      expect(tokens.last, ')');
      // Without the delimiter, no trailing space is produced.
      expect(expandAll(r'\cdots'), <String>[r'\@cdots']);
    });

    test(r'\dotsb is an alias that expands through \cdots', () {
      // \dotsb -> \cdots -> \@cdots
      expect(expandAll(r'\dotsb'), <String>[r'\@cdots']);
    });

    test(r'~ expands to \nobreakspace', () {
      // '~' is an active character (catcode 13) and so expands.
      expect(expandAll('~'), <String>[r'\nobreakspace']);
    });

    test(r'\TeX expands to its textrm body', () {
      final tokens = expandAll(r'\TeX');
      // Faithful prefix of KaTeX's \TeX expansion.
      expect(
        tokens.take(4).toList(),
        <String>[r'\textrm', '{', r'\html@mathml', '{'],
      );
    });
  });

  group('MacroExpander.expandOnce', () {
    test('returns false for a non-macro token, leaving it on the stack', () {
      final mex = expander('x');
      expect(mex.expandOnce(), isFalse);
      expect(mex.popToken().text, 'x');
    });

    test('returns the token count for a macro expansion', () {
      final mex = expander(r'\dotsb');
      final result = mex.expandOnce();
      // \dotsb -> "\cdots" -> a single token.
      expect(result, 1);
      expect(mex.future().text, r'\cdots');
    });
  });

  group('MacroExpander argument substitution', () {
    test('user macro with #1 substitutes its argument', () {
      final settings = Settings(macros: <String, Object?>{r'\foo': '#1#1'});
      // \foo{x} -> xx
      expect(expandAll(r'\foo{x}', settings), <String>['x', 'x']);
    });
  });

  group('MacroExpander.isDefined / isExpandable', () {
    test('builtin macro is defined and expandable', () {
      final mex = expander('');
      expect(mex.isDefined(r'\cdots'), isTrue);
      expect(mex.isExpandable(r'\cdots'), isTrue);
    });

    test('a known symbol is defined but not expandable', () {
      final mex = expander('');
      // \alpha is a symbol (from T-006), not a macro.
      expect(mex.isDefined(r'\alpha'), isTrue);
      expect(mex.isExpandable(r'\alpha'), isFalse);
    });

    test('implicit command is defined', () {
      final mex = expander('');
      expect(mex.isDefined('^'), isTrue);
      expect(mex.isDefined('_'), isTrue);
    });

    test('an unknown control sequence is not defined', () {
      final mex = expander('');
      expect(mex.isDefined(r'\thisisnotreal'), isFalse);
    });
  });

  group('MacroExpander.maxExpand', () {
    test('throws on runaway expansion', () {
      final settings = Settings(
        macros: <String, Object?>{r'\loop': r'\loop'},
        maxExpand: 10,
      );
      final mex = MacroExpander(r'\loop', settings, Mode.math);
      expect(mex.expandNextToken, throwsA(isA<ParseError>()));
    });
  });

  group('MacroDefinition types', () {
    test('builtinMacros contains the MVP aliases', () {
      expect(builtinMacros.containsKey(r'\cdots'), isTrue);
      expect(builtinMacros.containsKey(r'\bmod'), isTrue);
      expect(builtinMacros.containsKey(r'\TeX'), isTrue);
      // \dfrac/\tfrac/\binom are KaTeX *functions*, not macros (handled by the
      // Parser in T-008), so they are intentionally absent here.
      expect(builtinMacros.containsKey(r'\dfrac'), isFalse);
      expect(builtinMacros.containsKey(r'\binom'), isFalse);
    });
  });
}
