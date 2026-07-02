/// Glyph and box constructors, ported from KaTeX `src/buildCommon.ts`.
///
/// These are the building blocks the per-group builders use to assemble the
/// box tree. Unlike KaTeX — which emits DOM spans — this port emits the
/// project's backend-agnostic [BoxNode] types from
/// `package:katex_dart/src/box/box_node.dart`:
///
///  * [makeSymbol] / [mathsym] / [makeOrd] → [GlyphNode] (or [HBox] for
///    ligature deconstruction).
///  * [makeGlyph] → [GlyphNode].
///  * [makeSpan] → [SpanNode].
///  * [makeFragment] → [HBox].
///  * [makeVList] → [VList] (reusing the box tree's existing VList positioning;
///    KaTeX's strut/`pstrut` machinery is a DOM detail and is not reproduced).
///  * [makeLineSpan] → [RuleNode].
///
/// Font selection mirrors KaTeX's `fontMap` and `retrieveTextFontName`,
/// translating TeX font commands (`mathbf`, `mathrm`, `mathbb`, …) to a
/// [KatexFont] (family + variant).
library;

import 'package:katex_dart/src/box/box_node.dart';
import 'package:katex_dart/src/build/options.dart';
import 'package:katex_dart/src/font/font_metrics.dart';
import 'package:katex_dart/src/font/font_types.dart';
import 'package:katex_dart/src/symbols/symbols.dart';

/// The result of [lookupSymbol]: the (possibly replaced) [value] and its
/// per-glyph [metrics] (`null` if the font has no metrics for it).
class SymbolLookup {
  /// Creates a lookup result.
  const SymbolLookup(this.value, this.metrics);

  /// The character to render, after applying any symbol-table replacement.
  final String value;

  /// The per-glyph metrics, or `null` if unavailable.
  final CharacterMetrics? metrics;
}

/// Looks up [value] in the symbol table for [mode] (applying any `replace`
/// substitution) and then resolves its metrics in [fontName].
///
/// Faithful port of KaTeX's `lookupSymbol`.
SymbolLookup lookupSymbol(String value, String fontName, Mode mode) {
  final entry = Symbols.lookup(mode, value);
  final resolved = entry?.replace ?? value;
  return SymbolLookup(resolved, getCharacterMetrics(resolved, fontName, mode));
}

/// Builds a [GlyphNode] for [value] in the font named [fontName] (e.g.
/// `Main-Regular`) for the given [mode], after symbol-table translation.
///
/// Faithful port of KaTeX's `makeSymbol`. Italic correction is zeroed in text
/// mode and for `\mathit` (matching KaTeX). When [options] is supplied the
/// glyph is scaled by `options.sizeMultiplier`; without metrics, KaTeX produces
/// a zero-size symbol — here we return `null` so the caller can decide.
GlyphNode? makeSymbol(
  String value,
  String fontName,
  Mode mode, {
  Options? options,
}) {
  final lookup = lookupSymbol(value, fontName, mode);
  final metrics = lookup.metrics;
  final resolved = lookup.value;

  if (metrics == null) {
    return null;
  }

  var italic = metrics.italic;
  if (mode == Mode.text || (options != null && options.font == 'mathit')) {
    italic = 0;
  }

  final font = _fontFromName(fontName);
  final size = options?.sizeMultiplier ?? 1.0;

  return GlyphNode(
    codepoint: resolved.codeUnitAt(0),
    font: font,
    metrics: metrics,
    size: size,
    italic: italic,
  );
}

/// Makes a symbol in `Main-Regular` or `AMS-Regular`, used for rel, bin, open,
/// close, inner, and punct. Faithful port of KaTeX's `mathsym`.
GlyphNode? mathsym(String value, Mode mode, Options options) {
  // Special-case for boldsymbol with bold +/-, and for the `\` textord which
  // is not in the text symbol table.
  if (options.font == 'boldsymbol' &&
      lookupSymbol(value, 'Main-Bold', mode).metrics != null) {
    return makeSymbol(value, 'Main-Bold', mode, options: options);
  }
  final entry = Symbols.lookup(mode, value);
  if (value == r'\' || entry?.font == Font.main) {
    return makeSymbol(value, 'Main-Regular', mode, options: options);
  }
  return makeSymbol(value, 'AMS-Regular', mode, options: options);
}

/// Makes a glyph directly (without symbol-table translation) from a [KatexFont]
/// and a character [value]. Faithful port of KaTeX's `makeGlyph`-style path.
///
/// Returns `null` when the font has no metrics for [value].
GlyphNode? makeGlyph(
  String value,
  KatexFont font,
  Mode mode, {
  Options? options,
}) => makeSymbol(value, font.fontName, mode, options: options);

/// The font name and CSS-style class chosen for a `\boldsymbol` character.
class _BoldSymbol {
  const _BoldSymbol(this.fontName, this.fontClass);
  final String fontName;
  final String fontClass;
}

/// Faithful port of KaTeX's `boldSymbol`: choose `Math-BoldItalic`/`boldsymbol`
/// when available, else fall back to `Main-Bold`/`mathbf`.
_BoldSymbol _boldSymbol(String value, Mode mode, bool isTextord) {
  if (!isTextord &&
      lookupSymbol(value, 'Math-BoldItalic', mode).metrics != null) {
    return const _BoldSymbol('Math-BoldItalic', 'boldsymbol');
  }
  return const _BoldSymbol('Main-Bold', 'mathbf');
}

/// Makes either a mathord or textord in the correct font and color.
///
/// Faithful port of KaTeX's `makeOrd` for the MVP path: it honours the active
/// math [Options.font] / text family / weight / shape, with the default-font
/// fallbacks (`Math-Italic` for mathord, `Main-Regular` for textord, and
/// `AMS-Regular` for ams textords). Wide (surrogate-pair) characters are not
/// yet supported and fall through to the default-font path.
///
/// [isTextord] selects the textord vs mathord behaviour. Returns an [HBox] only
/// when deconstructing a monospace ligature; otherwise a [GlyphNode] (or `null`
/// if no metrics are available anywhere — should not happen for valid input).
BoxNode? makeOrd(
  String text,
  Mode mode,
  Options options, {
  required bool isTextord,
}) {
  final font = options.font;
  final fontFamily = options.fontFamily;
  final fontWeight = options.fontWeight;
  final fontShape = options.fontShape;

  // Math mode or old font (i.e. \rm).
  final useFont = mode == Mode.math || (mode == Mode.text && font.isNotEmpty);
  final fontOrFamily = useFont ? font : fontFamily;

  if (fontOrFamily.isNotEmpty) {
    final String fontName;
    if (fontOrFamily == 'boldsymbol') {
      fontName = _boldSymbol(text, mode, isTextord).fontName;
    } else if (useFont) {
      fontName = _fontMap[font]!.fontName;
    } else {
      fontName = _retrieveTextFontName(fontFamily, fontWeight, fontShape);
    }

    if (lookupSymbol(text, fontName, mode).metrics != null) {
      return makeSymbol(text, fontName, mode, options: options);
    } else if (ligatures.contains(text) && fontName.startsWith('Typewriter')) {
      // Deconstruct ligatures in monospace fonts (\texttt, \tt).
      final parts = <BoxNode>[];
      for (var i = 0; i < text.length; i++) {
        final part = makeSymbol(text[i], fontName, mode, options: options);
        if (part != null) {
          parts.add(part);
        }
      }
      return makeFragment(parts);
    }
  }

  // Default font for mathords and textords.
  if (!isTextord) {
    return makeSymbol(text, 'Math-Italic', mode, options: options);
  }

  final symFont = Symbols.lookup(mode, text)?.font;
  if (symFont == Font.ams) {
    final fontName = _retrieveTextFontName('amsrm', fontWeight, fontShape);
    return makeSymbol(text, fontName, mode, options: options);
  }
  final fontName = _retrieveTextFontName('textrm', fontWeight, fontShape);
  return makeSymbol(text, fontName, mode, options: options);
}

/// Monospace ligatures that must be deconstructed in `\texttt`/`\tt`.
/// Ported from KaTeX `symbols.ts`'s `ligatures` set.
const Set<String> ligatures = {'--', '---', '``', "''"};

/// Makes a [SpanNode] wrapping [children], applying the [options]'s color and
/// `sizeMultiplier`. Faithful port of KaTeX's `makeSpan` (the box-tree analogue
/// — dimensions are computed by [SpanNode] itself from its children).
SpanNode makeSpan(
  List<BoxNode> children, {
  List<String> classes = const [],
  Options? options,
}) {
  return SpanNode(
    children,
    color: options?.getColor(),
    classes: classes,
    sizeMultiplier: options?.sizeMultiplier ?? 1.0,
  );
}

/// Makes a horizontal grouping of [children] with no presentation metadata.
/// Faithful port of KaTeX's `makeFragment` (→ [HBox]; dimensions computed by
/// [HBox] itself).
HBox makeFragment(List<BoxNode> children) => HBox(children);

/// Wraps [elem] with optional leading ([left]) and trailing ([right]) kern
/// margins, modelling KaTeX's `marginLeft`/`marginRight`. Returns [elem]
/// unchanged when both margins are zero (no wrapper box is introduced).
BoxNode withMargins(BoxNode elem, {double left = 0, double right = 0}) {
  if (left == 0 && right == 0) {
    return elem;
  }
  return makeFragment([
    if (left != 0) KernNode(left),
    elem,
    if (right != 0) KernNode(right),
  ]);
}

/// Makes a horizontal line (fraction bar / underline / overline rule) of the
/// given [thickness] (defaulting to the font's default rule thickness, floored
/// at `options.minRuleThickness`). Faithful port of KaTeX's `makeLineSpan`
/// (→ [RuleNode] spanning the full available width; here width is `0` and the
/// caller stretches it, matching KaTeX's CSS-driven full-width rule).
RuleNode makeLineSpan(Options options, {double? thickness, double width = 0}) {
  final requested = thickness ?? options.fontMetrics().defaultRuleThickness;
  // KaTeX: max(thickness || defaultRuleThickness, minRuleThickness).
  final height = options.floorRuleThickness(requested);
  return RuleNode(width: width, height: height);
}

/// How a vlist is positioned. Re-exported alias of the box tree's enum so
/// callers can `import build_common.dart` alone. Mirrors KaTeX's
/// `VListParam.positionType`.
typedef VListPositionTypeAlias = VListPositionType;

/// Makes a [VList] by stacking [children] using [positionType]. This delegates
/// directly to the box tree's [VList], which already implements KaTeX's
/// `getVListChildrenAndDepth` + layout math (kern derivation for
/// `individualShift`, depth/height from minPos/maxPos). We do NOT reimplement
/// the positioning here — KaTeX's `pstrut`/strut/two-row machinery is a DOM
/// rendering detail with no effect on the logical height/depth.
VList makeVList({
  required VListPositionType positionType,
  required List<VListChild> children,
  double positionData = 0,
}) => VList(
  positionType: positionType,
  children: children,
  positionData: positionData,
);

/// A horizontal kern (inter-glyph spacing). Faithful port of KaTeX's kern
/// helper (→ [KernNode]).
KernNode makeKern(double size) => KernNode(size);

/// Horizontally centers [box] within [targetWidth] by wrapping it in an [HBox]
/// padded with equal leading/trailing kerns.
///
/// KaTeX centers fraction numerators/denominators and big-operator limits via
/// CSS (`text-align: center` on the full-width vlist column). The box tree has
/// no CSS, so the equivalent is to pad each narrower row to the column width
/// with symmetric kerns; the resulting [HBox] keeps the same total width
/// ([targetWidth]) so the surrounding [VList] width is unchanged. A box that is
/// already at least [targetWidth] wide is returned unchanged.
BoxNode centerInWidth(BoxNode box, double targetWidth) {
  final pad = (targetWidth - box.width) / 2;
  if (pad <= 0) {
    return box;
  }
  return HBox([KernNode(pad), box, KernNode(pad)]);
}

// ---------------------------------------------------------------------------
// Font selection
// ---------------------------------------------------------------------------

/// A TeX font command's MathML variant + the metrics font name.
class FontMapEntry {
  const FontMapEntry(this.variant, this.fontName);

  /// The MathML `mathvariant` value (e.g. `bold`, `italic`).
  final String variant;

  /// The metrics font name (e.g. `Main-Bold`).
  final String fontName;
}

/// Maps TeX font commands to their MathML variant + metrics font name.
/// Faithful port of KaTeX's `fontMap`.
const Map<String, FontMapEntry> _fontMap = {
  // styles
  'mathbf': FontMapEntry('bold', 'Main-Bold'),
  'mathrm': FontMapEntry('normal', 'Main-Regular'),
  'textit': FontMapEntry('italic', 'Main-Italic'),
  'mathit': FontMapEntry('italic', 'Main-Italic'),
  'mathnormal': FontMapEntry('italic', 'Math-Italic'),
  'mathsfit': FontMapEntry('sans-serif-italic', 'SansSerif-Italic'),
  // families
  'mathbb': FontMapEntry('double-struck', 'AMS-Regular'),
  'mathcal': FontMapEntry('script', 'Caligraphic-Regular'),
  'mathfrak': FontMapEntry('fraktur', 'Fraktur-Regular'),
  'mathscr': FontMapEntry('script', 'Script-Regular'),
  'mathsf': FontMapEntry('sans-serif', 'SansSerif-Regular'),
  'mathtt': FontMapEntry('monospace', 'Typewriter-Regular'),
};

/// The public font map (TeX font command → variant + metrics font name).
Map<String, FontMapEntry> get fontMap => _fontMap;

/// Computes the metrics font name for a text font family/weight/shape combo.
/// Faithful port of KaTeX's `retrieveTextFontName`.
String _retrieveTextFontName(
  String fontFamily,
  String fontWeight,
  String fontShape,
) {
  final String baseFontName;
  switch (fontFamily) {
    case 'amsrm':
      baseFontName = 'AMS';
    case 'textrm':
      baseFontName = 'Main';
    case 'textsf':
      baseFontName = 'SansSerif';
    case 'texttt':
      baseFontName = 'Typewriter';
    default:
      baseFontName = fontFamily; // use fonts added by a plugin
  }

  final String fontStylesName;
  if (fontWeight == 'textbf' && fontShape == 'textit') {
    fontStylesName = 'BoldItalic';
  } else if (fontWeight == 'textbf') {
    fontStylesName = 'Bold';
  } else if (fontShape == 'textit') {
    fontStylesName = 'Italic';
  } else {
    fontStylesName = 'Regular';
  }

  return '$baseFontName-$fontStylesName';
}

/// The public text-font-name resolver (family/weight/shape → metrics name).
String retrieveTextFontName(
  String fontFamily,
  String fontWeight,
  String fontShape,
) => _retrieveTextFontName(fontFamily, fontWeight, fontShape);

const Map<String, KatexFontFamily> _familyByToken = {
  'Main': KatexFontFamily.main,
  'Math': KatexFontFamily.math,
  'AMS': KatexFontFamily.ams,
  'Size1': KatexFontFamily.size1,
  'Size2': KatexFontFamily.size2,
  'Size3': KatexFontFamily.size3,
  'Size4': KatexFontFamily.size4,
  'Caligraphic': KatexFontFamily.caligraphic,
  'Fraktur': KatexFontFamily.fraktur,
  'SansSerif': KatexFontFamily.sansSerif,
  'Script': KatexFontFamily.script,
  'Typewriter': KatexFontFamily.typewriter,
};

const Map<String, KatexFontVariant> _variantByToken = {
  'Regular': KatexFontVariant.regular,
  'Bold': KatexFontVariant.bold,
  'Italic': KatexFontVariant.italic,
  'BoldItalic': KatexFontVariant.boldItalic,
};

/// Parses a metrics font name (e.g. `Main-Regular`, `Math-Italic`) into a
/// [KatexFont]. Throws [ArgumentError] for an unrecognised name.
KatexFont _fontFromName(String fontName) {
  final dash = fontName.indexOf('-');
  if (dash <= 0) {
    throw ArgumentError.value(fontName, 'fontName', 'Malformed font name');
  }
  final family = _familyByToken[fontName.substring(0, dash)];
  final variant = _variantByToken[fontName.substring(dash + 1)];
  if (family == null || variant == null) {
    throw ArgumentError.value(fontName, 'fontName', 'Unknown font name');
  }
  return KatexFont(family, variant);
}

/// Parses a metrics font name into a [KatexFont] (public form of the internal
/// resolver, useful for builders that hold a metrics name).
KatexFont fontFromName(String fontName) => _fontFromName(fontName);
