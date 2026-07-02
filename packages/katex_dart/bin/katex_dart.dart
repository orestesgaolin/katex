// CLI entry point — renders TeX to SVG (ticket T-013).
//
// Usage:
//   dart run katex_dart "\frac{a}{b}" [--display|-d] [--output|-o FILE]
//                                     [--font-size N] [--color C] [--help|-h]
//
// Reads the single positional TeX argument, renders it via [renderToSvg], and
// prints the SVG to stdout (or writes it to the `--output` file). On a parse or
// render error it prints a readable message to stderr and exits non-zero.
import 'dart:io';

import 'package:args/args.dart';
import 'package:katex_dart/katex_dart.dart';

const String _usageHeader =
    'katex_dart — render LaTeX math to SVG.\n\n'
    r'Usage: dart run katex_dart "\frac{a}{b}" [options]'
    '\n';

void main(List<String> args) {
  final parser = ArgParser()
    ..addFlag(
      'display',
      abbr: 'd',
      negatable: false,
      help: 'Render in display (block) mode instead of inline.',
    )
    ..addOption(
      'output',
      abbr: 'o',
      valueHelp: 'FILE',
      help: 'Write the SVG to FILE instead of stdout.',
    )
    ..addOption(
      'font-size',
      valueHelp: 'N',
      help: 'Font-size scale applied to the expression (1.0 = normal).',
    )
    ..addOption(
      'color',
      valueHelp: 'C',
      help: 'Base text color (any CSS color string).',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    );

  // Prints `katex: <message>` to stderr and sets [exitCode]; the caller then
  // returns. (A helper can't return from `main`.)
  void fail(String message, int code) {
    stderr.writeln('katex: $message');
    exitCode = code;
  }

  // As [fail], but follows the message with the full usage text (EX_USAGE).
  void usageError(String message) {
    stderr
      ..writeln('katex: $message')
      ..writeln()
      ..writeln(_usageHeader)
      ..writeln(parser.usage);
    exitCode = 64; // EX_USAGE
  }

  ArgResults results;
  try {
    results = parser.parse(args);
  } on FormatException catch (e) {
    usageError(e.message);
    return;
  }

  if (results.flag('help')) {
    stdout
      ..writeln(_usageHeader)
      ..writeln(parser.usage);
    return;
  }

  final rest = results.rest;
  if (rest.isEmpty) {
    usageError('missing TeX expression argument.');
    return;
  }
  if (rest.length > 1) {
    fail(
      'expected a single TeX expression, got ${rest.length} positional '
      'arguments. Quote the expression as one argument.',
      64, // EX_USAGE
    );
    return;
  }

  final tex = rest.single;

  // Parse the numeric --font-size, if provided.
  var fontSize = 1.0;
  final fontSizeArg = results.option('font-size');
  if (fontSizeArg != null) {
    final parsed = double.tryParse(fontSizeArg);
    if (parsed == null || parsed <= 0 || !parsed.isFinite) {
      fail(
        'invalid --font-size "$fontSizeArg" (expected a positive number).',
        64, // EX_USAGE
      );
      return;
    }
    fontSize = parsed;
  }

  final options = KatexOptions(
    displayMode: results.flag('display'),
    fontSize: fontSize,
    color: results.option('color'),
  );

  String svg;
  try {
    svg = renderToSvg(tex, options: options);
  } on ParseError catch (e) {
    fail(e.message, 65); // EX_DATAERR
    return;
  } on Object catch (e) {
    fail('failed to render expression: $e', 70); // EX_SOFTWARE
    return;
  }

  final outputPath = results.option('output');
  if (outputPath != null) {
    try {
      File(outputPath).writeAsStringSync(svg);
    } on FileSystemException catch (e) {
      // EX_CANTCREAT
      fail('could not write to "$outputPath": ${e.message}', 73);
      return;
    }
  } else {
    stdout.writeln(svg);
  }
}
