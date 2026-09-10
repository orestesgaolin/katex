/// Unicode accent / symbol helper tables ported from KaTeX.
///
/// This is the MVP subset. It ports `unicodeAccents.js` in full (a small,
/// static table mapping combining-accent code points to their LaTeX accent
/// commands in text and math mode).
///
/// KaTeX's `unicodeSymbols` map (precomposed accented letters →
/// decomposed `letter + combining accent` sequences) lives in the generated
/// `unicode_symbols.g.dart` beside this file. Dart's core libraries provide no
/// NFC normalization, so `tool/gen_unicode_symbols.dart` runs KaTeX's own
/// construction — NFC-normalizing every `letter × accent` (and
/// `letter × accent × accent`) combination, keeping those that collapse to a
/// single code point — in Node, and emits the result as a const table.
///
/// The accent set used to build that table is exactly the key set of
/// [unicodeAccents] below; keep the two in sync, because an accent missing
/// from this map silently drops every precomposed character built on it.
library;

import 'package:meta/meta.dart';

/// The LaTeX accent commands a Unicode combining accent maps to.
///
/// Mirrors KaTeX's `unicodeAccents` value type `{text, math?}`.
@immutable
class UnicodeAccent {
  /// Creates an accent mapping.
  const UnicodeAccent(this.text, [this.math]);

  /// The text-mode accent command (e.g. `\\'`).
  final String text;

  /// The math-mode accent command (e.g. `\\acute`), or `null` if the accent
  /// has no math-mode equivalent.
  final String? math;

  @override
  bool operator ==(Object other) => other is UnicodeAccent && other.text == text && other.math == math;

  @override
  int get hashCode => Object.hash(text, math);
}

/// Mapping of Unicode combining-accent code points to their LaTeX equivalents
/// in text and (where available) math mode.
///
/// Ported verbatim from KaTeX `unicodeAccents.js`. Keys are combining
/// diacritical marks (U+0300..U+0327), written as escapes to keep this file
/// pure-ASCII.
const Map<String, UnicodeAccent> unicodeAccents = {
  '\u{301}': UnicodeAccent(r"\'", r'\acute'), // combining acute
  '\u{300}': UnicodeAccent(r'\`', r'\grave'), // combining grave
  '\u{308}': UnicodeAccent(r'\"', r'\ddot'), // combining diaeresis
  '\u{303}': UnicodeAccent(r'\~', r'\tilde'), // combining tilde
  '\u{304}': UnicodeAccent(r'\=', r'\bar'), // combining macron
  '\u{306}': UnicodeAccent(r'\u', r'\breve'), // combining breve
  '\u{30c}': UnicodeAccent(r'\v', r'\check'), // combining caron
  '\u{302}': UnicodeAccent(r'\^', r'\hat'), // combining circumflex
  '\u{307}': UnicodeAccent(r'\.', r'\dot'), // combining dot above
  '\u{30a}': UnicodeAccent(r'\r', r'\mathring'), // combining ring above
  '\u{30b}': UnicodeAccent(r'\H'), // combining double acute
  '\u{327}': UnicodeAccent(r'\c'), // combining cedilla
};
