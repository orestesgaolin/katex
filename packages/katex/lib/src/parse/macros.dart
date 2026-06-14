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

import 'package:katex/src/parse/namespace.dart';
import 'package:katex/src/parse/parse_error.dart';
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

  /// Consume [numArgs] (optionally delimited) arguments and return their token
  /// lists. Mirrors KaTeX's `consumeArgs`.
  List<List<Token>> consumeArgs(int numArgs, [List<List<String>>? delimiters]);

  /// Consume a single (optionally delimited) argument and return its tokens (in
  /// reverse/stack order). Mirrors KaTeX's `consumeArg().tokens`.
  List<Token> consumeArgTokens([List<String>? delims]);

  /// Fully expand the given [tokens] (in reverse order) and return the result
  /// in forward order. Mirrors KaTeX's `expandTokens`.
  List<Token> expandTokens(List<Token> tokens);

  /// The macro namespace (builtins + user/global macros). Exposed so macros
  /// like `\bra@ket`/`\bra@set` can temporarily rebind `|` and `\|`.
  Namespace<MacroDefinition> get macros;

  /// Start a new group nesting within the macro namespace.
  void beginGroup();

  /// End current group nesting within the macro namespace.
  void endGroup();
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

  // LaTeX's \TextOrMath{#1}{#2} expands to #1 in text mode, #2 in math mode.
  // A function-style macro: it consumes 2 args and pushes back the text or
  // math one depending on the expander's current mode.
  defineMacro(r'\TextOrMath', (MacroContext context) {
    final args = context.consumeArgs(2);
    if (context.mode == Mode.text) {
      return MacroExpansion(tokens: args[0], numArgs: 0);
    } else {
      return MacroExpansion(tokens: args[1], numArgs: 0);
    }
  });

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
  // Symbols from latex.ltx (continued)
  // \def \aa {\r a} \def \AA {\r A}
  defineMacro(r'\aa', r'\r a');
  defineMacro(r'\AA', r'\r A');

  // Copyright (C) and registered (R) symbols. Use raw symbol in MathML.
  defineMacro(r'\textcopyright', r'\html@mathml{\textcircled{c}}{\char`©}');
  defineMacro(
    r'\copyright',
    r'\TextOrMath{\textcopyright}{\text{\textcopyright}}',
  );
  defineMacro(
    r'\textregistered',
    r'\html@mathml{\textcircled{\scriptsize R}}{\char`®}',
  );

  // Characters omitted from Unicode range 1D400–1D7FF
  defineMacro('ℬ', r'\mathscr{B}'); // script
  defineMacro('ℰ', r'\mathscr{E}');
  defineMacro('ℱ', r'\mathscr{F}');
  defineMacro('ℋ', r'\mathscr{H}');
  defineMacro('ℐ', r'\mathscr{I}');
  defineMacro('ℒ', r'\mathscr{L}');
  defineMacro('ℳ', r'\mathscr{M}');
  defineMacro('ℛ', r'\mathscr{R}');
  defineMacro('ℭ', r'\mathfrak{C}'); // Fraktur
  defineMacro('ℌ', r'\mathfrak{H}');
  defineMacro('ℨ', r'\mathfrak{Z}');

  // Define \Bbbk with a macro that works in both HTML and MathML.
  defineMacro(r'\Bbbk', r'\Bbb{k}');

  // \llap and \rlap render their contents in text mode
  defineMacro(r'\llap', r'\mathllap{\textrm{#1}}');
  defineMacro(r'\rlap', r'\mathrlap{\textrm{#1}}');
  defineMacro(r'\clap', r'\mathclap{\textrm{#1}}');

  // \mathstrut from the TeXbook, p 360
  defineMacro(r'\mathstrut', r'\vphantom{(}');

  // \underbar from TeXbook p 353
  defineMacro(r'\underbar', r'\underline{\text{#1}}');

  // \not is defined by base/fontmath.ltx via
  // \DeclareMathSymbol{\not}{\mathrel}{symbols}{"36}
  // It's thus treated like a \mathrel, but defined by a symbol that has zero
  // width but extends to the right.  We use \rlap to get that spacing.
  // For MathML we write U+0338 here. buildMathML.js will then do the overlay.
  defineMacro(
    r'\not',
    r'\html@mathml{\mathrel{\mathrlap\@not}\nobreak}{\char"338}',
  );

  // Negated symbols from base/fontmath.ltx:
  // \def\neq{\not=} \let\ne=\neq
  defineMacro(r'\neq', r'\html@mathml{\mathrel{\not=}}{\mathrel{\char`≠}}');
  defineMacro(r'\ne', r'\neq');
  defineMacro('≠', r'\neq');
  defineMacro(
    r'\notin',
    r'\html@mathml{\mathrel{{\in}\mathllap{/\mskip1mu}}}'
        r'{\mathrel{\char`∉}}',
  );
  defineMacro('∉', r'\notin');

  // Unicode stacked relations
  defineMacro(
    '≘',
    r'\html@mathml{'
        r'\mathrel{=\kern{-1em}\raisebox{0.4em}{$\scriptsize\frown$}}'
        r'}{\mathrel{\char`≘}}',
  );
  defineMacro(
    '≙',
    r'\html@mathml{\stackrel{\tiny\wedge}{=}}{\mathrel{\char`≘}}',
  );
  defineMacro(
    '≚',
    r'\html@mathml{\stackrel{\tiny\vee}{=}}{\mathrel{\char`≚}}',
  );
  defineMacro(
    '≛',
    r'\html@mathml{\stackrel{\scriptsize\star}{=}}'
        r'{\mathrel{\char`≛}}',
  );
  defineMacro(
    '≝',
    r'\html@mathml{\stackrel{\tiny\mathrm{def}}{=}}'
        r'{\mathrel{\char`≝}}',
  );
  defineMacro(
    '≞',
    r'\html@mathml{\stackrel{\tiny\mathrm{m}}{=}}'
        r'{\mathrel{\char`≞}}',
  );
  defineMacro(
    '≟',
    r'\html@mathml{\stackrel{\tiny?}{=}}{\mathrel{\char`≟}}',
  );

  // Misc Unicode
  defineMacro('⟂', r'\perp');
  defineMacro('‼', r'\mathclose{!\mkern-0.8mu!}');
  defineMacro('∌', r'\notni');
  defineMacro('⌜', r'\ulcorner');
  defineMacro('⌝', r'\urcorner');
  defineMacro('⌞', r'\llcorner');
  defineMacro('⌟', r'\lrcorner');
  defineMacro('©', r'\copyright');
  defineMacro('®', r'\textregistered');

  // The KaTeX fonts have corners at codepoints that don't match Unicode.
  // For MathML purposes, use the Unicode code point.
  defineMacro(r'\ulcorner', r'\html@mathml{\@ulcorner}{\mathop{\char"231c}}');
  defineMacro(r'\urcorner', r'\html@mathml{\@urcorner}{\mathop{\char"231d}}');
  defineMacro(r'\llcorner', r'\html@mathml{\@llcorner}{\mathop{\char"231e}}');
  defineMacro(r'\lrcorner', r'\html@mathml{\@lrcorner}{\mathop{\char"231f}}');

  //////////////////////////////////////////////////////////////////////
  // LaTeX_2ε

  // \vdots{\vbox{...}} — we'll call \varvdots, which gets a glyph from
  // symbols.js. The zero-width rule gets us an equivalent vertical 6pt kern.
  defineMacro(r'\vdots', r'{\varvdots\rule{0pt}{15pt}}');
  defineMacro('⋮', r'\vdots');

  //////////////////////////////////////////////////////////////////////
  // amsmath.sty (continued)

  // Italic Greek capital letters. AMS defines these with \DeclareMathSymbol,
  // but they are equivalent to \mathit{\Letter}.
  defineMacro(r'\varGamma', r'\mathit{\Gamma}');
  defineMacro(r'\varDelta', r'\mathit{\Delta}');
  defineMacro(r'\varTheta', r'\mathit{\Theta}');
  defineMacro(r'\varLambda', r'\mathit{\Lambda}');
  defineMacro(r'\varXi', r'\mathit{\Xi}');
  defineMacro(r'\varPi', r'\mathit{\Pi}');
  defineMacro(r'\varSigma', r'\mathit{\Sigma}');
  defineMacro(r'\varUpsilon', r'\mathit{\Upsilon}');
  defineMacro(r'\varPhi', r'\mathit{\Phi}');
  defineMacro(r'\varPsi', r'\mathit{\Psi}');
  defineMacro(r'\varOmega', r'\mathit{\Omega}');

  // \newcommand{\substack}[1]{\subarray{c}#1\endsubarray}
  defineMacro(r'\substack', r'\begin{subarray}{c}#1\end{subarray}');

  // \renewcommand{\colon}{...}
  defineMacro(
    r'\colon',
    r'\nobreak\mskip2mu\mathpunct{}'
        r'\mathchoice{\mkern-3mu}{\mkern-3mu}{}{}{:}\mskip6mu\relax',
  );

  // \newcommand{\boxed}[1]{\fbox{\m@th$\displaystyle#1$}}
  defineMacro(r'\boxed', r'\fbox{$\displaystyle{#1}$}');

  // \def\iff{\DOTSB\;\Longleftrightarrow\;} etc.
  defineMacro(r'\iff', r'\DOTSB\;\Longleftrightarrow\;');
  defineMacro(r'\implies', r'\DOTSB\;\Longrightarrow\;');
  defineMacro(r'\impliedby', r'\DOTSB\;\Longleftarrow\;');

  // \def\dddot#1{...} — we use \overset which avoids the \mathop vertical
  // shift.
  defineMacro(
    r'\dddot',
    r'{\overset{\raisebox{-0.1ex}{\normalsize ...}}{#1}}',
  );
  defineMacro(
    r'\ddddot',
    r'{\overset{\raisebox{-0.1ex}{\normalsize ....}}{#1}}',
  );

  // \tag@in@display form of \tag
  defineMacro(r'\tag', r'\@ifstar\tag@literal\tag@paren');
  defineMacro(r'\tag@paren', r'\tag@literal{({#1})}');
  defineMacro(r'\tag@literal', (MacroContext context) {
    if (context.macros.get(r'\df@tag') != null) {
      throw ParseError(r'Multiple \tag');
    }
    return r'\gdef\df@tag{\text{#1}}';
  });

  //////////////////////////////////////////////////////////////////////
  // LaTeX source2e

  // \DeclareRobustCommand\newline{\@normalcr\relax}
  defineMacro(r'\newline', r'\\\relax');

  // \DeclareRobustCommand\hspace{\@ifstar\@hspacer\@hspace}
  defineMacro(r'\hspace', r'\@ifstar\@hspacer\@hspace');
  defineMacro(r'\@hspace', r'\hskip #1\relax');
  defineMacro(r'\@hspacer', r'\rule{0pt}{0pt}\hskip #1\relax');

  //////////////////////////////////////////////////////////////////////
  // mathtools.sty

  // \providecommand\ordinarycolon{:}
  defineMacro(r'\ordinarycolon', ':');
  // \def\vcentcolon{\mathrel{\mathop\ordinarycolon}}
  // TODO(edemaine): Not yet centered. Fix via \raisebox or #726
  defineMacro(r'\vcentcolon', r'\mathrel{\mathop\ordinarycolon}');
  // \providecommand*\dblcolon{\vcentcolon\mathrel{\mkern-.9mu}\vcentcolon}
  defineMacro(
    r'\dblcolon',
    r'\html@mathml{'
        r'\mathrel{\vcentcolon\mathrel{\mkern-.9mu}\vcentcolon}}'
        r'{\mathop{\char"2237}}',
  );
  // \providecommand*\coloneqq{\vcentcolon\mathrel{\mkern-1.2mu}=}
  defineMacro(
    r'\coloneqq',
    r'\html@mathml{'
        r'\mathrel{\vcentcolon\mathrel{\mkern-1.2mu}=}}'
        r'{\mathop{\char"2254}}',
  ); // ≔
  // \providecommand*\Coloneqq{\dblcolon\mathrel{\mkern-1.2mu}=}
  defineMacro(
    r'\Coloneqq',
    r'\html@mathml{'
        r'\mathrel{\dblcolon\mathrel{\mkern-1.2mu}=}}'
        r'{\mathop{\char"2237\char"3d}}',
  );
  // \providecommand*\coloneq{\vcentcolon\mathrel{\mkern-1.2mu}\mathrel{-}}
  defineMacro(
    r'\coloneq',
    r'\html@mathml{'
        r'\mathrel{\vcentcolon\mathrel{\mkern-1.2mu}\mathrel{-}}}'
        r'{\mathop{\char"3a\char"2212}}',
  );
  // \providecommand*\Coloneq{\dblcolon\mathrel{\mkern-1.2mu}\mathrel{-}}
  defineMacro(
    r'\Coloneq',
    r'\html@mathml{'
        r'\mathrel{\dblcolon\mathrel{\mkern-1.2mu}\mathrel{-}}}'
        r'{\mathop{\char"2237\char"2212}}',
  );
  // \providecommand*\eqqcolon{=\mathrel{\mkern-1.2mu}\vcentcolon}
  defineMacro(
    r'\eqqcolon',
    r'\html@mathml{'
        r'\mathrel{=\mathrel{\mkern-1.2mu}\vcentcolon}}'
        r'{\mathop{\char"2255}}',
  ); // ≕
  // \providecommand*\Eqqcolon{=\mathrel{\mkern-1.2mu}\dblcolon}
  defineMacro(
    r'\Eqqcolon',
    r'\html@mathml{'
        r'\mathrel{=\mathrel{\mkern-1.2mu}\dblcolon}}'
        r'{\mathop{\char"3d\char"2237}}',
  );
  // \providecommand*\eqcolon{\mathrel{-}\mathrel{\mkern-1.2mu}\vcentcolon}
  defineMacro(
    r'\eqcolon',
    r'\html@mathml{'
        r'\mathrel{\mathrel{-}\mathrel{\mkern-1.2mu}\vcentcolon}}'
        r'{\mathop{\char"2239}}',
  );
  // \providecommand*\Eqcolon{\mathrel{-}\mathrel{\mkern-1.2mu}\dblcolon}
  defineMacro(
    r'\Eqcolon',
    r'\html@mathml{'
        r'\mathrel{\mathrel{-}\mathrel{\mkern-1.2mu}\dblcolon}}'
        r'{\mathop{\char"2212\char"2237}}',
  );
  // \providecommand*\colonapprox{\vcentcolon\mathrel{\mkern-1.2mu}\approx}
  defineMacro(
    r'\colonapprox',
    r'\html@mathml{'
        r'\mathrel{\vcentcolon\mathrel{\mkern-1.2mu}\approx}}'
        r'{\mathop{\char"3a\char"2248}}',
  );
  // \providecommand*\Colonapprox{\dblcolon\mathrel{\mkern-1.2mu}\approx}
  defineMacro(
    r'\Colonapprox',
    r'\html@mathml{'
        r'\mathrel{\dblcolon\mathrel{\mkern-1.2mu}\approx}}'
        r'{\mathop{\char"2237\char"2248}}',
  );
  // \providecommand*\colonsim{\vcentcolon\mathrel{\mkern-1.2mu}\sim}
  defineMacro(
    r'\colonsim',
    r'\html@mathml{'
        r'\mathrel{\vcentcolon\mathrel{\mkern-1.2mu}\sim}}'
        r'{\mathop{\char"3a\char"223c}}',
  );
  // \providecommand*\Colonsim{\dblcolon\mathrel{\mkern-1.2mu}\sim}
  defineMacro(
    r'\Colonsim',
    r'\html@mathml{'
        r'\mathrel{\dblcolon\mathrel{\mkern-1.2mu}\sim}}'
        r'{\mathop{\char"2237\char"223c}}',
  );

  // Some Unicode characters are implemented with macros to mathtools functions.
  defineMacro('∷', r'\dblcolon'); // ::
  defineMacro('∹', r'\eqcolon'); // -:
  defineMacro('≔', r'\coloneqq'); // :=
  defineMacro('≕', r'\eqqcolon'); // =:
  defineMacro('⩴', r'\Coloneqq'); // ::=

  //////////////////////////////////////////////////////////////////////
  // colonequals.sty

  // Alternate names for mathtools's macros:
  defineMacro(r'\ratio', r'\vcentcolon');
  defineMacro(r'\coloncolon', r'\dblcolon');
  defineMacro(r'\colonequals', r'\coloneqq');
  defineMacro(r'\coloncolonequals', r'\Coloneqq');
  defineMacro(r'\equalscolon', r'\eqqcolon');
  defineMacro(r'\equalscoloncolon', r'\Eqqcolon');
  defineMacro(r'\colonminus', r'\coloneq');
  defineMacro(r'\coloncolonminus', r'\Coloneq');
  defineMacro(r'\minuscolon', r'\eqcolon');
  defineMacro(r'\minuscoloncolon', r'\Eqcolon');
  // \colonapprox name is same in mathtools and colonequals.
  defineMacro(r'\coloncolonapprox', r'\Colonapprox');
  // \colonsim name is same in mathtools and colonequals.
  defineMacro(r'\coloncolonsim', r'\Colonsim');

  // Additional macros, implemented by analogy with mathtools definitions:
  defineMacro(r'\simcolon', r'\mathrel{\sim\mathrel{\mkern-1.2mu}\vcentcolon}');
  defineMacro(
    r'\simcoloncolon',
    r'\mathrel{\sim\mathrel{\mkern-1.2mu}\dblcolon}',
  );
  defineMacro(
    r'\approxcolon',
    r'\mathrel{\approx\mathrel{\mkern-1.2mu}\vcentcolon}',
  );
  defineMacro(
    r'\approxcoloncolon',
    r'\mathrel{\approx\mathrel{\mkern-1.2mu}\dblcolon}',
  );

  // Present in newtxmath, pxfonts and txfonts
  defineMacro(r'\notni', r'\html@mathml{\not\ni}{\mathrel{\char`∌}}');
  defineMacro(r'\limsup', r'\DOTSB\operatorname*{lim\,sup}');
  defineMacro(r'\liminf', r'\DOTSB\operatorname*{lim\,inf}');

  //////////////////////////////////////////////////////////////////////
  // From amsopn.sty
  defineMacro(r'\injlim', r'\DOTSB\operatorname*{inj\,lim}');
  defineMacro(r'\projlim', r'\DOTSB\operatorname*{proj\,lim}');
  defineMacro(r'\varlimsup', r'\DOTSB\operatorname*{\overline{lim}}');
  defineMacro(r'\varliminf', r'\DOTSB\operatorname*{\underline{lim}}');
  defineMacro(r'\varinjlim', r'\DOTSB\operatorname*{\underrightarrow{lim}}');
  defineMacro(r'\varprojlim', r'\DOTSB\operatorname*{\underleftarrow{lim}}');

  //////////////////////////////////////////////////////////////////////
  // MathML alternates for KaTeX glyphs in the Unicode private area
  defineMacro(r'\gvertneqq', r'\html@mathml{\@gvertneqq}{≩}');
  defineMacro(r'\lvertneqq', r'\html@mathml{\@lvertneqq}{≨}');
  defineMacro(r'\ngeqq', r'\html@mathml{\@ngeqq}{≱}');
  defineMacro(r'\ngeqslant', r'\html@mathml{\@ngeqslant}{≱}');
  defineMacro(r'\nleqq', r'\html@mathml{\@nleqq}{≰}');
  defineMacro(r'\nleqslant', r'\html@mathml{\@nleqslant}{≰}');
  defineMacro(r'\nshortmid', r'\html@mathml{\@nshortmid}{∤}');
  defineMacro(r'\nshortparallel', r'\html@mathml{\@nshortparallel}{∦}');
  defineMacro(r'\nsubseteqq', r'\html@mathml{\@nsubseteqq}{⊈}');
  defineMacro(r'\nsupseteqq', r'\html@mathml{\@nsupseteqq}{⊉}');
  defineMacro(r'\varsubsetneq', r'\html@mathml{\@varsubsetneq}{⊊}');
  defineMacro(r'\varsubsetneqq', r'\html@mathml{\@varsubsetneqq}{⫋}');
  defineMacro(r'\varsupsetneq', r'\html@mathml{\@varsupsetneq}{⊋}');
  defineMacro(r'\varsupsetneqq', r'\html@mathml{\@varsupsetneqq}{⫌}');
  defineMacro(r'\imath', r'\html@mathml{\@imath}{ı}');
  defineMacro(r'\jmath', r'\html@mathml{\@jmath}{ȷ}');

  //////////////////////////////////////////////////////////////////////
  // stmaryrd and semantic

  // The stmaryrd and semantic packages render the next four items by calling a
  // glyph. Those glyphs do not exist in the KaTeX fonts. Hence the macros.
  defineMacro(
    r'\llbracket',
    r'\html@mathml{'
        r'\mathopen{[\mkern-3.2mu[}}'
        r'{\mathopen{\char`⟦}}',
  );
  defineMacro(
    r'\rrbracket',
    r'\html@mathml{'
        r'\mathclose{]\mkern-3.2mu]}}'
        r'{\mathclose{\char`⟧}}',
  );

  defineMacro('⟦', r'\llbracket'); // blackboard bold [
  defineMacro('⟧', r'\rrbracket'); // blackboard bold ]

  defineMacro(
    r'\lBrace',
    r'\html@mathml{'
        r'\mathopen{\{\mkern-3.2mu[}}'
        r'{\mathopen{\char`⦃}}',
  );
  defineMacro(
    r'\rBrace',
    r'\html@mathml{'
        r'\mathclose{]\mkern-3.2mu\}}}'
        r'{\mathclose{\char`⦄}}',
  );

  defineMacro('⦃', r'\lBrace'); // blackboard bold {
  defineMacro('⦄', r'\rBrace'); // blackboard bold }

  // TODO(T-038): Create variable sized versions of the last two items. I
  // believe that will require new font glyphs.

  // The stmaryrd function `\minuso` provides a "Plimsoll" symbol that
  // superimposes the characters \circ and \mathminus. Used in chemistry.
  defineMacro(
    r'\minuso',
    r'\mathbin{\html@mathml{'
        r'{\mathrlap{\mathchoice{\kern{0.145em}}{\kern{0.145em}}'
        r'{\kern{0.1015em}}{\kern{0.0725em}}\circ}{-}}}'
        r'{\char`⦵}}',
  );
  defineMacro('⦵', r'\minuso');

  //////////////////////////////////////////////////////////////////////
  // texvc.sty

  // The texvc package contains macros available in mediawiki pages.
  // We omit the functions deprecated at
  // https://en.wikipedia.org/wiki/Help:Displaying_a_formula#Deprecated_syntax
  // We also omit texvc's \O, which conflicts with \text{\O}
  defineMacro(r'\darr', r'\downarrow');
  defineMacro(r'\dArr', r'\Downarrow');
  defineMacro(r'\Darr', r'\Downarrow');
  defineMacro(r'\lang', r'\langle');
  defineMacro(r'\rang', r'\rangle');
  defineMacro(r'\uarr', r'\uparrow');
  defineMacro(r'\uArr', r'\Uparrow');
  defineMacro(r'\Uarr', r'\Uparrow');
  defineMacro(r'\N', r'\mathbb{N}');
  defineMacro(r'\R', r'\mathbb{R}');
  defineMacro(r'\Z', r'\mathbb{Z}');
  defineMacro(r'\alef', r'\aleph');
  defineMacro(r'\alefsym', r'\aleph');
  defineMacro(r'\Alpha', r'\mathrm{A}');
  defineMacro(r'\Beta', r'\mathrm{B}');
  defineMacro(r'\bull', r'\bullet');
  defineMacro(r'\Chi', r'\mathrm{X}');
  defineMacro(r'\clubs', r'\clubsuit');
  defineMacro(r'\cnums', r'\mathbb{C}');
  defineMacro(r'\Complex', r'\mathbb{C}');
  defineMacro(r'\Dagger', r'\ddagger');
  defineMacro(r'\diamonds', r'\diamondsuit');
  defineMacro(r'\empty', r'\emptyset');
  defineMacro(r'\Epsilon', r'\mathrm{E}');
  defineMacro(r'\Eta', r'\mathrm{H}');
  defineMacro(r'\exist', r'\exists');
  defineMacro(r'\harr', r'\leftrightarrow');
  defineMacro(r'\hArr', r'\Leftrightarrow');
  defineMacro(r'\Harr', r'\Leftrightarrow');
  defineMacro(r'\hearts', r'\heartsuit');
  defineMacro(r'\image', r'\Im');
  defineMacro(r'\infin', r'\infty');
  defineMacro(r'\Iota', r'\mathrm{I}');
  defineMacro(r'\isin', r'\in');
  defineMacro(r'\Kappa', r'\mathrm{K}');
  defineMacro(r'\larr', r'\leftarrow');
  defineMacro(r'\lArr', r'\Leftarrow');
  defineMacro(r'\Larr', r'\Leftarrow');
  defineMacro(r'\lrarr', r'\leftrightarrow');
  defineMacro(r'\lrArr', r'\Leftrightarrow');
  defineMacro(r'\Lrarr', r'\Leftrightarrow');
  defineMacro(r'\Mu', r'\mathrm{M}');
  defineMacro(r'\natnums', r'\mathbb{N}');
  defineMacro(r'\Nu', r'\mathrm{N}');
  defineMacro(r'\Omicron', r'\mathrm{O}');
  defineMacro(r'\plusmn', r'\pm');
  defineMacro(r'\rarr', r'\rightarrow');
  defineMacro(r'\rArr', r'\Rightarrow');
  defineMacro(r'\Rarr', r'\Rightarrow');
  defineMacro(r'\real', r'\Re');
  defineMacro(r'\reals', r'\mathbb{R}');
  defineMacro(r'\Reals', r'\mathbb{R}');
  defineMacro(r'\Rho', r'\mathrm{P}');
  defineMacro(r'\sdot', r'\cdot');
  defineMacro(r'\sect', r'\S');
  defineMacro(r'\spades', r'\spadesuit');
  defineMacro(r'\sub', r'\subset');
  defineMacro(r'\sube', r'\subseteq');
  defineMacro(r'\supe', r'\supseteq');
  defineMacro(r'\Tau', r'\mathrm{T}');
  defineMacro(r'\thetasym', r'\vartheta');
  // TODO(T-038): defineMacro(r'\varcoppa', r'\mbox{\coppa}');
  defineMacro(r'\weierp', r'\wp');
  defineMacro(r'\Zeta', r'\mathrm{Z}');

  //////////////////////////////////////////////////////////////////////
  // statmath.sty
  // https://ctan.math.illinois.edu/macros/latex/contrib/statmath/statmath.pdf
  defineMacro(r'\argmin', r'\DOTSB\operatorname*{arg\,min}');
  defineMacro(r'\argmax', r'\DOTSB\operatorname*{arg\,max}');
  defineMacro(r'\plim', r'\DOTSB\mathop{\operatorname{plim}}\limits');

  //////////////////////////////////////////////////////////////////////
  // braket.sty
  // http://ctan.math.washington.edu/tex-archive/macros/latex/contrib/braket/braket.pdf
  defineMacro(r'\bra', r'\mathinner{\langle{#1}|}');
  defineMacro(r'\ket', r'\mathinner{|{#1}\rangle}');
  defineMacro(r'\braket', r'\mathinner{\langle{#1}\rangle}');
  defineMacro(r'\Bra', r'\left\langle#1\right|');
  defineMacro(r'\Ket', r'\left|#1\right\rangle');

  MacroFunction braketHelper({required bool one}) {
    return (MacroContext context) {
      final left = context.consumeArgTokens();
      final middle = context.consumeArgTokens();
      final middleDouble = context.consumeArgTokens();
      final right = context.consumeArgTokens();
      final oldMiddle = context.macros.get('|');
      final oldMiddleDouble = context.macros.get(r'\|');
      context.beginGroup();

      MacroFunction midMacro({required bool isDouble}) {
        return (MacroContext context) {
          if (one) {
            // Only modify the first instance of | or \|
            context.macros.set('|', oldMiddle);
            if (middleDouble.isNotEmpty) {
              context.macros.set(r'\|', oldMiddleDouble);
            }
          }
          var doubled = isDouble;
          if (!isDouble && middleDouble.isNotEmpty) {
            // Mimic \@ifnextchar
            final nextToken = context.future();
            if (nextToken.text == '|') {
              context.popToken();
              doubled = true;
            }
          }
          return MacroExpansion(
            tokens: doubled ? middleDouble : middle,
            numArgs: 0,
          );
        };
      }

      context.macros.set('|', midMacro(isDouble: false));
      if (middleDouble.isNotEmpty) {
        context.macros.set(r'\|', midMacro(isDouble: true));
      }
      final arg = context.consumeArgTokens();
      final expanded = context.expandTokens(<Token>[
        ...right, ...arg, ...left, // reversed
      ]);
      context.endGroup();
      return MacroExpansion(
        tokens: expanded.reversed.toList(),
        numArgs: 0,
      );
    };
  }

  defineMacro(r'\bra@ket', braketHelper(one: false));
  defineMacro(r'\bra@set', braketHelper(one: true));
  defineMacro(
    r'\Braket',
    r'\bra@ket{\left\langle}'
        r'{\,\middle\vert\,}{\,\middle\vert\,}{\right\rangle}',
  );
  defineMacro(
    r'\Set',
    r'\bra@set{\left\{\:}'
        r'{\;\middle\vert\;}{\;\middle\Vert\;}{\:\right\}}',
  );
  defineMacro(r'\set', r'\bra@set{\{\,}{\mid}{}{\,\}}');
  // has no support for special || or \|

  //////////////////////////////////////////////////////////////////////
  // actuarialangle.dtx
  defineMacro(r'\angln', r'{\angl n}');

  // Custom Khan Academy colors, should be moved to an optional package
  defineMacro(r'\blue', r'\textcolor{##6495ed}{#1}');
  defineMacro(r'\orange', r'\textcolor{##ffa500}{#1}');
  defineMacro(r'\pink', r'\textcolor{##ff00af}{#1}');
  defineMacro(r'\red', r'\textcolor{##df0030}{#1}');
  defineMacro(r'\green', r'\textcolor{##28ae7b}{#1}');
  defineMacro(r'\gray', r'\textcolor{gray}{#1}');
  defineMacro(r'\purple', r'\textcolor{##9d38bd}{#1}');
  defineMacro(r'\blueA', r'\textcolor{##ccfaff}{#1}');
  defineMacro(r'\blueB', r'\textcolor{##80f6ff}{#1}');
  defineMacro(r'\blueC', r'\textcolor{##63d9ea}{#1}');
  defineMacro(r'\blueD', r'\textcolor{##11accd}{#1}');
  defineMacro(r'\blueE', r'\textcolor{##0c7f99}{#1}');
  defineMacro(r'\tealA', r'\textcolor{##94fff5}{#1}');
  defineMacro(r'\tealB', r'\textcolor{##26edd5}{#1}');
  defineMacro(r'\tealC', r'\textcolor{##01d1c1}{#1}');
  defineMacro(r'\tealD', r'\textcolor{##01a995}{#1}');
  defineMacro(r'\tealE', r'\textcolor{##208170}{#1}');
  defineMacro(r'\greenA', r'\textcolor{##b6ffb0}{#1}');
  defineMacro(r'\greenB', r'\textcolor{##8af281}{#1}');
  defineMacro(r'\greenC', r'\textcolor{##74cf70}{#1}');
  defineMacro(r'\greenD', r'\textcolor{##1fab54}{#1}');
  defineMacro(r'\greenE', r'\textcolor{##0d923f}{#1}');
  defineMacro(r'\goldA', r'\textcolor{##ffd0a9}{#1}');
  defineMacro(r'\goldB', r'\textcolor{##ffbb71}{#1}');
  defineMacro(r'\goldC', r'\textcolor{##ff9c39}{#1}');
  defineMacro(r'\goldD', r'\textcolor{##e07d10}{#1}');
  defineMacro(r'\goldE', r'\textcolor{##a75a05}{#1}');
  defineMacro(r'\redA', r'\textcolor{##fca9a9}{#1}');
  defineMacro(r'\redB', r'\textcolor{##ff8482}{#1}');
  defineMacro(r'\redC', r'\textcolor{##f9685d}{#1}');
  defineMacro(r'\redD', r'\textcolor{##e84d39}{#1}');
  defineMacro(r'\redE', r'\textcolor{##bc2612}{#1}');
  defineMacro(r'\maroonA', r'\textcolor{##ffbde0}{#1}');
  defineMacro(r'\maroonB', r'\textcolor{##ff92c6}{#1}');
  defineMacro(r'\maroonC', r'\textcolor{##ed5fa6}{#1}');
  defineMacro(r'\maroonD', r'\textcolor{##ca337c}{#1}');
  defineMacro(r'\maroonE', r'\textcolor{##9e034e}{#1}');
  defineMacro(r'\purpleA', r'\textcolor{##ddd7ff}{#1}');
  defineMacro(r'\purpleB', r'\textcolor{##c6b9fc}{#1}');
  defineMacro(r'\purpleC', r'\textcolor{##aa87ff}{#1}');
  defineMacro(r'\purpleD', r'\textcolor{##7854ab}{#1}');
  defineMacro(r'\purpleE', r'\textcolor{##543b78}{#1}');
  defineMacro(r'\mintA', r'\textcolor{##f5f9e8}{#1}');
  defineMacro(r'\mintB', r'\textcolor{##edf2df}{#1}');
  defineMacro(r'\mintC', r'\textcolor{##e0e5cc}{#1}');
  defineMacro(r'\grayA', r'\textcolor{##f6f7f7}{#1}');
  defineMacro(r'\grayB', r'\textcolor{##f0f1f2}{#1}');
  defineMacro(r'\grayC', r'\textcolor{##e3e5e6}{#1}');
  defineMacro(r'\grayD', r'\textcolor{##d6d8da}{#1}');
  defineMacro(r'\grayE', r'\textcolor{##babec2}{#1}');
  defineMacro(r'\grayF', r'\textcolor{##888d93}{#1}');
  defineMacro(r'\grayG', r'\textcolor{##626569}{#1}');
  defineMacro(r'\grayH', r'\textcolor{##3b3e40}{#1}');
  defineMacro(r'\grayI', r'\textcolor{##21242c}{#1}');
  defineMacro(r'\kaBlue', r'\textcolor{##314453}{#1}');
  defineMacro(r'\kaGreen', r'\textcolor{##71B307}{#1}');

  return macros;
}
