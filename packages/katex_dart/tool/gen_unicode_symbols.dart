// Generator for `lib/src/symbols/unicode_symbols.g.dart`.
//
// Approach
// --------
// KaTeX's `unicodeSymbols` maps a PRECOMPOSED accented character (e.g. "é") to
// the equivalent base letter + combining accent sequence ("e" + U+0301), so the
// parser can rewrite it into an accent command it already knows how to build.
//
// KaTeX builds that map at module-load time by composing every
// `letter × accent` (and `letter × accent × accent`) pair and keeping the ones
// that NFC-normalize to a single code point. Dart's core libraries have no
// Unicode normalization, so this generator runs the same construction in Node
// (which ships full ICU) and emits the result as a Dart const table.
//
// Note this reads no KaTeX source — it only needs Node's `String.normalize`,
// so unlike the other generators it works without `npm install` in reference/.
//
// The accent set is exactly the key set of `unicodeAccents` in
// `lib/src/symbols/unicode_symbols.dart` (KaTeX `unicodeAccents.js`); keep the
// two in sync, since an accent missing here silently drops its precomposed
// characters.
//
// Run from the package root:
//   dart run tool/gen_unicode_symbols.dart
import 'dart:convert';
import 'dart:io';

const _outPath = 'lib/src/symbols/unicode_symbols.g.dart';

/// The combining marks KaTeX knows accent commands for — the key set of
/// `unicodeAccents`.
const List<String> _accents = [
  '́', // acute
  '̀', // grave
  '̈', // diaeresis
  '̃', // tilde
  '̄', // macron
  '̆', // breve
  '̌', // caron
  '̂', // circumflex
  '̇', // dot above
  '̊', // ring above
  '̋', // double acute
  '̧', // cedilla
];

Future<void> main() async {
  final script =
      '''
const accents = ${jsonEncode(_accents)};
const letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
const out = {};
for (const letter of letters) {
  for (const accent of accents) {
    const combined = letter + accent;
    const normalized = combined.normalize("NFC");
    if (normalized.length === 1) {
      out[normalized] = combined;
    }
    for (const accent2 of accents) {
      if (accent === accent2) continue;
      const combined2 = normalized + accent2;
      const normalized2 = combined2.normalize("NFC");
      if (normalized.length === 1 && normalized2.length === 1) {
        out[normalized2] = combined + accent2;
      }
    }
  }
}
process.stdout.write(JSON.stringify(out));
''';

  final result = await Process.run('node', [
    '--input-type=module',
    '-e',
    script,
  ], stdoutEncoding: utf8);
  if (result.exitCode != 0) {
    stderr.writeln('node failed (exit ${result.exitCode}):');
    stderr.writeln(result.stderr);
    exit(1);
  }

  final decoded = jsonDecode(result.stdout as String) as Map<String, dynamic>;

  final buffer = StringBuffer()
    ..writeln('// GENERATED FILE — DO NOT EDIT.')
    ..writeln('// Regenerate with: dart run tool/gen_unicode_symbols.dart')
    ..writeln('//')
    ..writeln('// Port of KaTeX `unicodeSymbols.js`: precomposed accented')
    ..writeln('// character -> base letter + combining accent(s), built by')
    ..writeln('// NFC-normalizing every letter x accent (x accent) combination.')
    ..writeln('library;')
    ..writeln()
    ..writeln('/// Precomposed accented characters mapped to their base letter')
    ..writeln('/// followed by combining accent mark(s).')
    ..writeln('///')
    ..writeln('/// The parser rewrites a matching character into this sequence')
    ..writeln('/// so the existing combining-mark path turns it into an accent')
    ..writeln('/// command. Mirrors KaTeX `unicodeSymbols`.')
    ..writeln('const Map<String, String> unicodeSymbols = {');

  // Sort by code point for deterministic, diffable output.
  final keys = decoded.keys.toList()
    ..sort((a, b) => a.runes.first.compareTo(b.runes.first));
  for (final key in keys) {
    final value = decoded[key] as String;
    buffer.writeln('  ${_escape(key)}: ${_escape(value)}, // $key');
  }
  buffer.writeln('};');

  File(_outPath).writeAsStringSync(buffer.toString());
  stdout.writeln('Wrote $_outPath (${keys.length} entries).');
}

/// Renders [s] as a pure-ASCII Dart string literal of `\u{...}` escapes, so the
/// generated file stays readable regardless of editor encoding.
String _escape(String s) {
  final b = StringBuffer("'");
  for (final rune in s.runes) {
    b.write('\\u{${rune.toRadixString(16)}}');
  }
  b.write("'");
  return b.toString();
}
