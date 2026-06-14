/// The token produced by the lexer.
///
/// Port of KaTeX's `Token.ts`.
library;

import 'package:katex/src/parse/source_location.dart';

/// The resulting token returned from `Lexer.lex`.
///
/// It consists of the token [text] plus some position information ([loc]).
/// The position information is essentially a range in an input string, but
/// instead of referencing the bare input string, we refer to the lexer. That
/// way it is possible to attach extra metadata to the input string, like a file
/// name or similar.
///
/// The position information is optional, so it is OK to construct synthetic
/// tokens if appropriate. Not providing available position information may lead
/// to degraded error reporting, though.
class Token {
  /// Creates a token with the given [text] and optional source [loc].
  Token(this.text, [this.loc]);

  /// The text of this token.
  String text;

  /// The source location of this token, if known.
  SourceLocation? loc;

  /// Whether macro expansion should skip this token (used by `\noexpand`).
  bool? noexpand;

  /// Whether this token should be treated as `\relax` (used in `\noexpand`).
  bool? treatAsRelax;

  /// Given a pair of tokens (`this` and [endToken]), computes a [Token]
  /// encompassing the whole input range enclosed by these two.
  Token range(
    Token endToken, // last token of the range, inclusive
    String text, // the text of the newly constructed token
  ) {
    return Token(text, SourceLocation.range(loc, endToken.loc));
  }
}
