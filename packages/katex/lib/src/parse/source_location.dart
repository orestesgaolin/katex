/// Lexing/parsing positional information for error reporting.
///
/// Port of KaTeX's `SourceLocation.ts`.
library;

/// Interface required to break the circular dependency between `Token`,
/// `Lexer`, and `ParseError`.
///
/// Mirrors KaTeX's `LexerInterface`: anything that can act as the origin of a
/// [SourceLocation] must expose the original [input] string (and, in KaTeX, the
/// compiled token regex — kept here only as a marker for identity comparison).
abstract class LexerInterface {
  /// The full input string being lexed.
  String get input;
}

/// Lexing or parsing positional information for error reporting.
///
/// This object is immutable. Offsets index into the [lexer]'s input.
class SourceLocation {
  /// Creates a source location spanning `[start, end)` within [lexer]'s input.
  const SourceLocation(this.lexer, this.start, this.end);

  /// Lexer holding the input string.
  final LexerInterface lexer;

  /// Start offset, zero-based inclusive.
  final int start;

  /// End offset, zero-based exclusive.
  final int end;

  /// Merges two `SourceLocation`s from location providers, given they are
  /// provided in order of appearance.
  ///
  /// - Returns the first one's location if only the [second] is `null`.
  /// - Returns a merged range of the first and the last if both are provided
  ///   and their lexers match.
  /// - Otherwise, returns `null`.
  static SourceLocation? range(SourceLocation? first, SourceLocation? second) {
    if (second == null) {
      return first;
    } else if (first == null || !identical(first.lexer, second.lexer)) {
      return null;
    } else {
      return SourceLocation(first.lexer, first.start, second.end);
    }
  }
}
