/// The main error thrown by KaTeX functions when something has gone wrong.
///
/// Port of KaTeX's `ParseError.ts`.
library;

import 'package:katex_dart/src/parse/token.dart';

/// The error thrown by KaTeX functions when parsing/lexing fails.
///
/// This is used to distinguish internal errors from errors in the expression
/// that the user provided. If possible, a caller should provide a [Token] (or,
/// in the full parser, a parse node) with information about where in the source
/// string the problem occurred.
class ParseError implements Exception {
  /// Creates a parse error with the given [message] and optional [token]
  /// carrying source position information.
  factory ParseError(String message, [Token? token]) {
    var error = 'KaTeX parse error: $message';
    int? start;
    int? end;

    final loc = token?.loc;
    if (loc != null && loc.start <= loc.end) {
      // If we have the input and a position, make the error a bit fancier.
      final input = loc.lexer.input;

      start = loc.start;
      end = loc.end;
      if (start == input.length) {
        error += ' at end of input: ';
      } else {
        error += ' at position ${start + 1}: ';
      }

      // Underline token in question using combining underscores.
      const combiningLowLine = '̲';
      final underlined = input
          .substring(start, end)
          .split('')
          .map((c) => '$c$combiningLowLine')
          .join();

      // Extract some context from the input and add it to the error.
      final String left;
      if (start > 15) {
        left = '…${input.substring(start - 15, start)}';
      } else {
        left = input.substring(0, start);
      }
      final String right;
      if (end + 15 < input.length) {
        right = '${input.substring(end, end + 15)}…';
      } else {
        right = input.substring(end);
      }
      error += '$left$underlined$right';
    }

    return ParseError._(
      message: error,
      rawMessage: message,
      position: start,
      length: (start != null && end != null) ? end - start : null,
    );
  }

  ParseError._({
    required this.message,
    required this.rawMessage,
    this.position,
    this.length,
  });

  /// The full, contextualized error message (prefixed with
  /// `"KaTeX parse error: "` and, when available, source context).
  final String message;

  /// The underlying error message without any context added.
  final String rawMessage;

  /// Error start position based on the passed-in [Token], if any.
  final int? position;

  /// Length of affected text based on the passed-in [Token], if any.
  final int? length;

  @override
  String toString() => message;
}
