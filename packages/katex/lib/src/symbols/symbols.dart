import 'package:katex/src/symbols/symbols.g.dart';
import 'package:katex/src/types.dart';
import 'package:meta/meta.dart';

export 'package:katex/src/types.dart' show Mode;

/// The symbol font a glyph is drawn from, mirroring KaTeX's `SymbolFont`.
enum Font {
  /// The normal KaTeX font (`KaTeX_Main`/`KaTeX_Math`).
  main,

  /// The AMS fonts (`KaTeX_AMS`).
  ams,
}

/// The parse-node atom group of a symbol, mirroring KaTeX's `Group`.
///
/// KaTeX uses string constants where some carry a `-token` suffix
/// (`accent-token`, `op-token`); those are spelled [accent] and [op] here.
/// See https://github.com/KaTeX/KaTeX/wiki/Examining-TeX#group-types.
enum Group {
  /// Binary operator, e.g. `+`, `\times`.
  bin,

  /// Relation, e.g. `=`, `\leq`.
  rel,

  /// Opening delimiter, e.g. `(`, `\langle`.
  open,

  /// Closing delimiter, e.g. `)`, `\rangle`.
  close,

  /// Punctuation, e.g. `,`, `;`.
  punct,

  /// Big operator, e.g. `\sum`, `\int` (KaTeX `op-token`).
  op,

  /// Inner atom, e.g. `\ldots`.
  inner,

  /// Ordinary math symbol, e.g. a Latin letter or `\alpha`.
  mathord,

  /// Ordinary text/upright symbol, e.g. a digit or `\Gamma`.
  textord,

  /// Combining accent, e.g. `\hat`, `\bar` (KaTeX `accent-token`).
  accent,

  /// Horizontal spacing command, e.g. `\,`, `\nobreakspace`.
  spacing,
}

/// Per-symbol metadata, mirroring KaTeX's `{font, group, replace}` record.
@immutable
class SymbolData {
  /// Creates symbol metadata.
  const SymbolData(this.font, this.group, this.replace);

  /// The font this symbol is drawn from.
  final Font font;

  /// The atom group this symbol parses to.
  final Group group;

  /// The character this symbol is replaced with when rendered, or `null`
  /// when there is no replacement (e.g. `\nobreak`, `\allowbreak`).
  final String? replace;

  @override
  bool operator ==(Object other) =>
      other is SymbolData &&
      other.font == font &&
      other.group == group &&
      other.replace == replace;

  @override
  int get hashCode => Object.hash(font, group, replace);

  @override
  String toString() {
    final r = replace == null ? 'null' : "'$replace'";
    return 'SymbolData($font, $group, $r)';
  }
}

/// A math class used for inter-atom spacing, mirroring KaTeX's `MathClass`
/// (`mord`, `mop`, `mbin`, `mrel`, `mopen`, `mclose`, `mpunct`, `minner`).
///
/// These are the keys of the spacing tables in `spacing_data.g.dart`. They are
/// distinct from [Group]: a parsed atom's [Group] is mapped to a [MathClass]
/// by the builder before spacing lookup.
enum MathClass {
  /// Ordinary atom.
  mord,

  /// Big operator atom.
  mop,

  /// Binary operator atom.
  mbin,

  /// Relation atom.
  mrel,

  /// Opening delimiter atom.
  mopen,

  /// Closing delimiter atom.
  mclose,

  /// Punctuation atom.
  mpunct,

  /// Inner atom.
  minner,
}

/// An inter-atom spacing measured in math units (`mu`), where 18 mu = 1 em.
///
/// Mirrors KaTeX's `Measurement` restricted to the `mu` unit used by the
/// spacing tables.
@immutable
class Mu {
  /// Creates a spacing of [number] math units.
  const Mu(this.number);

  /// The size in math units (`mu`).
  final double number;

  /// The unit, always `'mu'` for spacing data.
  String get unit => 'mu';

  @override
  bool operator ==(Object other) => other is Mu && other.number == number;

  @override
  int get hashCode => number.hashCode;

  @override
  String toString() => '${number}mu';
}

/// Lookup API over the generated KaTeX symbol table.
///
/// Mirrors KaTeX's `symbols[mode][name]` map. Use [lookup] to resolve a
/// symbol name (either a control sequence like `\\alpha` or a literal
/// character like `+`) for a given [Mode].
abstract final class Symbols {
  /// The full generated table, keyed by [Mode] then by symbol name.
  static const Map<Mode, Map<String, SymbolData>> table = symbolsTable;

  /// Returns the [SymbolData] for [name] in [mode], or `null` if [name] is
  /// not a known symbol in that mode.
  static SymbolData? lookup(Mode mode, String name) => table[mode]?[name];
}
