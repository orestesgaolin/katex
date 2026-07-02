/// Tokenizes KaTeX input.
///
/// Port of KaTeX's `Lexer.ts`. The lexer allows lexing from any starting point
/// so the parser can backtrack; its main exposed function is `lex`, which
/// returns a single token and advances the internal position.
library;

import 'package:katex_dart/src/parse/parse_error.dart';
import 'package:katex_dart/src/parse/settings.dart';
import 'package:katex_dart/src/parse/source_location.dart';
import 'package:katex_dart/src/parse/token.dart';

const String _spaceRegexString = '[ \r\n\t]';
const String _controlWordRegexString = r'\\[a-zA-Z@]+';
// "\\[^\uD800-\uDFFF]" — backslash followed by any non-surrogate code unit.
const String _controlSymbolRegexString = '\\\\[^\uD800-\uDFFF]';
const String _controlWordWhitespaceRegexString =
    '($_controlWordRegexString)$_spaceRegexString*';
const String _controlSpaceRegexString = '\\\\(\n|[ \r\t]+\n?)[ \r\t]*';
const String _combiningDiacriticalMarkString = '[\u0300-\u036f]';

/// Matches a run of combining diacritical marks at the end of a string.
final RegExp combiningDiacriticalMarksEndRegex = RegExp(
  '$_combiningDiacriticalMarkString+\$',
);

// See KaTeX's Lexer.ts for the full annotated derivation. Capturing groups:
//   [1] regular whitespace
//   [2] backslash followed by whitespace (control space)
//   [3] anything else, which may include:
//     [4] left character of \verb*
//     [5] left character of \verb
//     [6] backslash followed by word, excluding any trailing whitespace
const String _tokenRegexString =
    '($_spaceRegexString+)|' // whitespace
    '$_controlSpaceRegexString|' // \whitespace
    '([!-\\[\\]-\u2027\u202A-\uD7FF\uF900-\uFFFF]' // single codepoint
    '$_combiningDiacriticalMarkString*' // ...plus accents
    '|[\uD800-\uDBFF][\uDC00-\uDFFF]' // surrogate pair
    '$_combiningDiacriticalMarkString*' // ...plus accents
    r'|\\verb\*([\s\S]).*?\4' // \verb*
    r'|\\verb([^*a-zA-Z]).*?\5' // \verb unstarred
    '|$_controlWordWhitespaceRegexString' // \macroName + spaces
    '|$_controlSymbolRegexString)'; // \\, \', etc.

/// The Lexer class handles tokenizing the input.
///
/// Since the parser expects to be able to backtrack, the lexer allows lexing
/// from any given starting point (controlled by [tokenRegexLastIndex]).
class Lexer implements LexerInterface {
  /// Creates a lexer over [input] using the given [settings].
  Lexer(this.input, this.settings) : tokenRegex = RegExp(_tokenRegexString) {
    catcodes = {
      '%': 14, // comment character
      '~': 13, // active character
    };
  }

  @override
  final String input;

  /// Settings controlling strict-mode reporting, etc.
  final Settings settings;

  /// The compiled token regex. Dart's [RegExp] is stateless, so the current
  /// position is tracked separately by [tokenRegexLastIndex].
  final RegExp tokenRegex;

  /// The position (into [input]) at which the next [lex] call begins. Mirrors
  /// the JS `tokenRegex.lastIndex`.
  int tokenRegexLastIndex = 0;

  /// Category codes. The lexer only supports comment characters (14) for now.
  /// `MacroExpander` additionally distinguishes active characters (13).
  late Map<String, int> catcodes;

  /// Sets the category code for [char] to [code].
  void setCatcode(String char, int code) {
    catcodes[char] = code;
  }

  /// Lexes a single token, advancing the internal position.
  Token lex() {
    final pos = tokenRegexLastIndex;
    if (pos == input.length) {
      return Token('EOF', SourceLocation(this, pos, pos));
    }
    final match = tokenRegex.matchAsPrefix(input, pos);
    if (match == null) {
      throw ParseError(
        "Unexpected character: '${input[pos]}'",
        Token(input[pos], SourceLocation(this, pos, pos + 1)),
      );
    }
    // Advance past the matched text.
    tokenRegexLastIndex = match.end;

    final text =
        match.group(6) ??
        match.group(3) ??
        (match.group(2) != null ? r'\ ' : ' ');

    if (catcodes[text] == 14) {
      // comment character
      final nlIndex = input.indexOf('\n', tokenRegexLastIndex);
      if (nlIndex == -1) {
        tokenRegexLastIndex = input.length; // EOF
        settings.reportNonstrict(
          'commentAtEnd',
          '% comment has no terminating newline; LaTeX would '
              r'fail because of commenting the end of math mode (e.g. $)',
        );
      } else {
        tokenRegexLastIndex = nlIndex + 1;
      }
      return lex();
    }

    return Token(text, SourceLocation(this, pos, tokenRegexLastIndex));
  }
}
