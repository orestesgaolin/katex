/// Builtin macro definitions and the macro-definition type system.
///
/// Port of KaTeX's `defineMacro.ts` (the type/interface machinery) plus the
/// MVP subset of `macros.ts` (the builtin macro table).
///
/// Faithfulness notes:
/// - This is a deliberately small subset scoped to the MVP gallery. The full
///   KaTeX macro set (hundreds of entries) is deferred to T-019.
/// - `\dfrac`, `\tfrac`, `\binom`, `\dbinom`, `\tbinom` are intentionally
///   absent here: in KaTeX they are *functions* (`functions/genfrac.ts`), not
///   macros, so they are resolved by the Parser (T-008), not by macro
///   expansion. Only `\cdots`/`\dotsb`/`\dotsm` and friends are true macros.
library;

import 'package:katex/src/parse/token.dart';
import 'package:katex/src/symbols/symbols.dart';

/// Context provided to macros defined by functions. Implemented by
/// `MacroExpander`.
///
/// Mirrors KaTeX's `MacroContextInterface`. Only the members needed by the MVP
/// builtin macros (and the Parser surface) are declared here.
abstract class MacroContext {
  /// The current TeX [Mode] (math or text).
  Mode get mode;

  /// Returns the topmost token on the stack, without expanding it. Similar in
  /// behavior to TeX's `\futurelet`.
  Token future();

  /// Remove and return the next unexpanded token.
  Token popToken();

  /// Consume all following space tokens, without expansion.
  void consumeSpaces();

  /// Expand the next token only once (if possible), and return the resulting
  /// top token on the stack (without removing anything from the stack).
  /// Similar in behavior to TeX's `\expandafter\futurelet`.
  Token expandAfterFuture();

  /// Determine whether [name] is currently "defined".
  bool isDefined(String name);

  /// Determine whether [name] is expandable.
  bool isExpandable(String name);
}

/// A fully-resolved macro expansion: macro [tokens] (in reverse order) plus a
/// macro argument count.
///
/// Mirrors KaTeX's `MacroExpansion`.
class MacroExpansion {
  /// Creates a macro expansion.
  const MacroExpansion({
    required this.tokens,
    required this.numArgs,
    this.delimiters,
    this.unexpandable = false,
  });

  /// The macro body tokens, in reverse order (to fit stack push/pop).
  final List<Token> tokens;

  /// The number of arguments this macro takes.
  final int numArgs;

  /// Optional delimiter token texts; `delimiters[i]` delimits argument `i`,
  /// with `delimiters[0]` being the prefix before the first argument.
  final List<List<String>>? delimiters;

  /// Whether this macro is unexpandable (used by `\let`).
  final bool unexpandable;
}

/// A macro definition.
///
/// Mirrors KaTeX's `MacroDefinition`, a union of:
/// - a [String] body (which is lexed into tokens on expansion),
/// - a [MacroExpansion], or
/// - a [MacroFunction] computing one of the above from a [MacroContext].
///
/// In Dart there is no untagged union, so a definition is stored as one of
/// [String], [MacroExpansion], or [MacroFunction].
typedef MacroDefinition = Object;

/// A function-valued macro definition, returning either a [String] or a
/// [MacroExpansion].
typedef MacroFunction = Object Function(MacroContext context);

/// The builtin macro table for the MVP.
///
/// Keyed by control sequence (e.g. `\\cdots`). Values are [MacroDefinition]s.
/// This corresponds to KaTeX's global `_macros` map, restricted to the MVP set.
final Map<String, MacroDefinition> builtinMacros = _defineBuiltinMacros();

Map<String, MacroDefinition> _defineBuiltinMacros() {
  final macros = <String, MacroDefinition>{};

  void defineMacro(String name, MacroDefinition body) {
    macros[name] = body;
  }

  //////////////////////////////////////////////////////////////////////
  // Grouping helpers

  // \def\bgroup{{} etc.
  defineMacro(r'\bgroup', '{');
  defineMacro(r'\egroup', '}');

  // Symbols from latin-1 / TeX punctuation
  defineMacro('~', r'\nobreakspace');
  defineMacro(r'\lq', '`');
  defineMacro(r'\rq', "'");

  //////////////////////////////////////////////////////////////////////
  // amsmath.sty — ellipses

  // The set of tokens after which `\cdots`/`\dotsc`/`\dotso` add a thin space.
  const spaceAfterDots = <String>{
    // \rightdelim@ checks for the following:
    ')',
    ']',
    r'\rbrack',
    r'\}',
    r'\rbrace',
    r'\rangle',
    r'\rceil',
    r'\rfloor',
    r'\rgroup',
    r'\rmoustache',
    r'\right',
    r'\bigr',
    r'\biggr',
    r'\Bigr',
    r'\Biggr',
    // \extra@ also tests for the following:
    r'$',
    // \extrap@ checks for the following:
    ';',
    '.',
    ',',
  };

  // \dotsByToken maps a following control sequence to the kind of dots to use.
  const dotsByToken = <String, String>{
    ',': r'\dotsc',
    r'\not': r'\dotsb',
    // amsmath relations
    '+': r'\dotsb',
    '=': r'\dotsb',
    '<': r'\dotsb',
    '>': r'\dotsb',
    '-': r'\dotsb',
    '*': r'\dotsb',
    ':': r'\dotsb',
    // arrows etc. (subset) map to \dotsb in amsmath; full set deferred.
    r'\to': r'\dotsb',
    r'\DOTSB': r'\dotsb',
    r'\dotsb': r'\dotsb',
    r'\dotsm': r'\dotsb',
    // integrals
    r'\int': r'\dotsi',
    r'\oint': r'\dotsi',
    r'\iint': r'\dotsi',
    r'\iiint': r'\dotsi',
    r'\iiiint': r'\dotsi',
    r'\idotsint': r'\dotsi',
    // Symbols whose definition starts with \DOTSX:
    r'\DOTSX': r'\dotsx',
  };

  const dotsbGroups = <Group>{Group.bin, Group.rel};

  // \dots — choose the kind of ellipsis based on the following token.
  defineMacro(r'\dots', (MacroContext context) {
    // TODO(T-019): text-mode \dots should expand to \textellipsis.
    var thedots = r'\dotso';
    final next = context.expandAfterFuture().text;
    if (dotsByToken.containsKey(next)) {
      thedots = dotsByToken[next]!;
    } else if (next.length >= 4 && next.substring(0, 4) == r'\not') {
      thedots = r'\dotsb';
    } else {
      final sym = Symbols.lookup(Mode.math, next);
      if (sym != null && dotsbGroups.contains(sym.group)) {
        thedots = r'\dotsb';
      }
    }
    return thedots;
  });

  defineMacro(r'\dotso', (MacroContext context) {
    final next = context.future().text;
    if (spaceAfterDots.contains(next)) {
      return r'\ldots\,';
    } else {
      return r'\ldots';
    }
  });

  defineMacro(r'\dotsc', (MacroContext context) {
    final next = context.future().text;
    // \dotsc uses \extra@ but not \extrap@, specially checking for ';' and '.',
    // but not for ','.
    if (spaceAfterDots.contains(next) && next != ',') {
      return r'\ldots\,';
    } else {
      return r'\ldots';
    }
  });

  defineMacro(r'\cdots', (MacroContext context) {
    final next = context.future().text;
    if (spaceAfterDots.contains(next)) {
      return r'\@cdots\,';
    } else {
      return r'\@cdots';
    }
  });

  defineMacro(r'\dotsb', r'\cdots');
  defineMacro(r'\dotsm', r'\cdots');
  defineMacro(r'\dotsi', r'\!\cdots');
  defineMacro(r'\dotsx', r'\ldots\,');

  // \let\DOTSI\relax etc.
  defineMacro(r'\DOTSI', r'\relax');
  defineMacro(r'\DOTSB', r'\relax');
  defineMacro(r'\DOTSX', r'\relax');

  //////////////////////////////////////////////////////////////////////
  // amsmath.sty — spacing

  // \tmspace, used by the spacing macros below.
  defineMacro(r'\tmspace', r'\TextOrMath{\kern#1#3}{\mskip#1#2}\relax');
  defineMacro(r'\,', r'\tmspace+{3mu}{.1667em}');
  defineMacro(r'\thinspace', r'\,');
  defineMacro(r'\>', r'\mskip{4mu}');
  defineMacro(r'\:', r'\tmspace+{4mu}{.2222em}');
  defineMacro(r'\medspace', r'\:');
  defineMacro(r'\;', r'\tmspace+{5mu}{.2777em}');
  defineMacro(r'\thickspace', r'\;');
  defineMacro(r'\!', r'\tmspace-{3mu}{.1667em}');
  defineMacro(r'\negthinspace', r'\!');
  defineMacro(r'\negmedspace', r'\tmspace-{4mu}{.2222em}');
  defineMacro(r'\negthickspace', r'\tmspace-{5mu}{.277em}');
  defineMacro(r'\enspace', r'\kern.5em ');
  defineMacro(r'\enskip', r'\hskip.5em\relax');
  defineMacro(r'\quad', r'\hskip1em\relax');
  defineMacro(r'\qquad', r'\hskip2em\relax');

  //////////////////////////////////////////////////////////////////////
  // amsopn.sty — \bmod and friends

  defineMacro(
    r'\bmod',
    r'\mathchoice{\mskip1mu}{\mskip1mu}{\mskip5mu}{\mskip5mu}\mathbin{\rm mod}\mathchoice{\mskip1mu}{\mskip1mu}{\mskip5mu}{\mskip5mu}',
  );
  defineMacro(
    r'\pod',
    r'\allowbreak\mathchoice{\mkern18mu}{\mkern8mu}{\mkern8mu}{\mkern8mu}(#1)',
  );
  defineMacro(r'\pmod', r'\pod{{\rm mod}\mkern6mu#1}');
  defineMacro(
    r'\mod',
    r'\allowbreak\mathchoice{\mkern18mu}{\mkern12mu}{\mkern12mu}{\mkern12mu}{\rm mod}\,\,#1',
  );

  //////////////////////////////////////////////////////////////////////
  // Logos

  // \TeX — see KaTeX macros.ts (omits \@ which KaTeX doesn't support).
  defineMacro(
    r'\TeX',
    r'\textrm{\html@mathml{T\kern-.1667em\raisebox{-.5ex}{E}\kern-.125emX}{TeX}}',
  );

  // \LaTeX / \KaTeX use a precomputed \raisebox for the "A"; KaTeX derives it
  // from font metrics (Main-Regular T height − 0.7 × A height). We inline the
  // computed value KaTeX produces to avoid a font-metrics dependency here.
  const latexRaiseA = '0.21073em';
  defineMacro(
    r'\LaTeX',
    r'\textrm{\html@mathml{L\kern-.36em\raisebox{'
        '$latexRaiseA'
        r'}{\scriptstyle A}\kern-.15em\TeX}{LaTeX}}',
  );
  defineMacro(
    r'\KaTeX',
    r'\textrm{\html@mathml{K\kern-.17em\raisebox{'
        '$latexRaiseA'
        r'}{\scriptstyle A}\kern-.15em\TeX}{KaTeX}}',
  );

  //////////////////////////////////////////////////////////////////////
  // Misc simple aliases used by the MVP gallery

  defineMacro(r'\newline', r'\\\relax');
  defineMacro(r'\empty', r'\emptyset');
  defineMacro(r'\sdot', r'\cdot');
  defineMacro(r'\ne', r'\neq');
  defineMacro(r'\iff', r'\DOTSB\;\Longleftrightarrow\;');
  defineMacro(r'\implies', r'\DOTSB\;\Longrightarrow\;');
  defineMacro(r'\impliedby', r'\DOTSB\;\Longleftarrow\;');

  return macros;
}
