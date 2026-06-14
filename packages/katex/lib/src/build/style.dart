/// TeX math styles, ported from KaTeX `src/Style.ts`.
///
/// Provides a [Style] class holding a unique `id`, a `size` (shared between the
/// cramped and uncramped variants), and a `cramped` flag, plus the four
/// exported singletons `Style.DISPLAY`, `Style.TEXT`, `Style.SCRIPT`, and
/// `Style.SCRIPTSCRIPT` and the transitions between them (`sup`, `sub`,
/// `fracNum`, `fracDen`, `cramp`, `text`).
///
/// As in KaTeX, no new styles can be constructed by consumers: the eight style
/// instances are fixed and reused.
library;

import 'package:meta/meta.dart';

// IDs of the different styles (matching KaTeX's D, Dc, T, Tc, S, Sc, SS, SSc).
const int _d = 0;
const int _dc = 1;
const int _t = 2;
const int _tc = 3;
const int _s = 4;
const int _sc = 5;
const int _ss = 6;
const int _ssc = 7;

/// A TeX math style (display / text / script / scriptscript, cramped or not).
///
/// Faithful port of KaTeX's `Style`. Holds a unique [id], a [size] (`0` for
/// display, `1` for text, `2` for script, `3` for scriptscript — shared by the
/// cramped and uncramped variants) and a [cramped] flag. Instances are not
/// publicly constructible; use the [DISPLAY]/[TEXT]/[SCRIPT]/[SCRIPTSCRIPT]
/// singletons and the transition methods.
@immutable
class Style {
  const Style._(this.id, this.size, {required this.cramped});

  /// The unique id of this style (0–7).
  final int id;

  /// The size of this style: 0 = display, 1 = text, 2 = script,
  /// 3 = scriptscript. The same for cramped and uncramped variants.
  final int size;

  /// Whether this is a cramped style (cramping a cramped style is a no-op).
  final bool cramped;

  /// Displaystyle (`\displaystyle`).
  // ignore: constant_identifier_names
  static const Style DISPLAY = Style._(_d, 0, cramped: false);

  /// Textstyle (`\textstyle`).
  // ignore: constant_identifier_names
  static const Style TEXT = Style._(_t, 1, cramped: false);

  /// Scriptstyle (`\scriptstyle`).
  // ignore: constant_identifier_names
  static const Style SCRIPT = Style._(_s, 2, cramped: false);

  /// Scriptscriptstyle (`\scriptscriptstyle`).
  // ignore: constant_identifier_names
  static const Style SCRIPTSCRIPT = Style._(_ss, 3, cramped: false);

  /// The style of a superscript given a base in this style.
  Style sup() => _styles[_sup[id]];

  /// The style of a subscript given a base in this style.
  Style sub() => _styles[_sub[id]];

  /// The style of a fraction numerator given the fraction in this style.
  Style fracNum() => _styles[_fracNum[id]];

  /// The style of a fraction denominator given the fraction in this style.
  Style fracDen() => _styles[_fracDen[id]];

  /// The cramped version of this style (cramping a cramped style is a no-op).
  Style cramp() => _styles[_cramp[id]];

  /// The text or display version of this style.
  Style text() => _styles[_text[id]];

  /// Returns true if this style is tightly spaced (script/scriptscript).
  bool isTight() => size >= 2;

  /// The font-size multiplier KaTeX uses for this style relative to the base
  /// text size: display/text = `1.0`, script = `0.7`, scriptscript = `0.5`.
  double get sizeMultiplier => _sizeMultipliers[size];

  @override
  String toString() {
    const names = ['DISPLAY', 'TEXT', 'SCRIPT', 'SCRIPTSCRIPT'];
    return 'Style(${names[size]}${cramped ? ', cramped' : ''})';
  }
}

// The eight style instances, indexed by id. The uncramped ones alias the
// public singletons; the cramped variants are defined here.
const Style _styles1 = Style._(_dc, 0, cramped: true);
const Style _styles3 = Style._(_tc, 1, cramped: true);
const Style _styles5 = Style._(_sc, 2, cramped: true);
const Style _styles7 = Style._(_ssc, 3, cramped: true);

const List<Style> _styles = [
  Style.DISPLAY,
  _styles1,
  Style.TEXT,
  _styles3,
  Style.SCRIPT,
  _styles5,
  Style.SCRIPTSCRIPT,
  _styles7,
];

// Style-size multipliers, indexed by Style.size (0..3). KaTeX bakes these into
// the per-glyph font-size; display & text share 1.0.
const List<double> _sizeMultipliers = [1.0, 1.0, 0.7, 0.5];

// Lookup tables for switching from one style to another (verbatim from KaTeX).
const List<int> _sup = [_s, _sc, _s, _sc, _ss, _ssc, _ss, _ssc];
const List<int> _sub = [_sc, _sc, _sc, _sc, _ssc, _ssc, _ssc, _ssc];
const List<int> _fracNum = [_t, _tc, _s, _sc, _ss, _ssc, _ss, _ssc];
const List<int> _fracDen = [_tc, _tc, _sc, _sc, _ssc, _ssc, _ssc, _ssc];
const List<int> _cramp = [_dc, _dc, _tc, _tc, _sc, _sc, _ssc, _ssc];
const List<int> _text = [_d, _dc, _t, _tc, _t, _tc, _t, _tc];
