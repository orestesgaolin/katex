/// Parse-node AST types — a Dart port of KaTeX's `src/types/nodes.ts`
/// discriminated union (`AnyParseNode`).
///
/// Each KaTeX node `type` string becomes one subclass of the [ParseNode]
/// sealed hierarchy. The `type` getter returns the *exact* KaTeX type string
/// (e.g. `ordgroup`, `mathord`, `supsub`, `genfrac`) so cross-referencing the
/// upstream source stays 1:1 and so future builders can `switch` on it (or,
/// preferably, pattern-match on the sealed subclass for exhaustiveness).
///
/// Scope is the MVP grammar (see `PLAN.md` milestone 1): fractions, sup/sub,
/// sqrt, big operators, left-right delimiters, accents, text/font/color/
/// sizing/styling, arrays, atoms/ords/ordgroups, mclass, kern/spacing, rule,
/// phantom and the symbol-token node types. A handful of non-MVP node types
/// from KaTeX are intentionally omitted; add them as coverage grows (the
/// sealed hierarchy makes that purely additive).
library;

import 'package:katex_dart/src/parse/parse_error.dart';
import 'package:katex_dart/src/parse/source_location.dart';
import 'package:katex_dart/src/symbols/symbols.dart' show Group, MathClass;
import 'package:katex_dart/src/types.dart' show Mode;
import 'package:meta/meta.dart';

/// A measurement with a magnitude and a unit, mirroring KaTeX's
/// `Measurement` (`{number, unit}`), e.g. `{number: 1, unit: "em"}`.
///
/// Defined here (rather than imported) because the AST is the first layer to
/// need the general form; the `symbols/` layer only needed the `mu`-restricted
/// variant. Units/build layers may later promote this to a shared location.
@immutable
class Measurement {
  /// Creates a measurement of [number] in [unit].
  const Measurement(this.number, this.unit);

  /// The magnitude.
  final double number;

  /// The unit string, e.g. `em`, `ex`, `pt`, `mu`.
  final String unit;

  @override
  bool operator ==(Object other) =>
      other is Measurement && other.number == number && other.unit == unit;

  @override
  int get hashCode => Object.hash(number, unit);

  @override
  String toString() => '$number$unit';
}

/// The relative size of a manually-sized delimiter, mirroring KaTeX's
/// `DelimiterSize` (`1 | 2 | 3 | 4`, as in `\bigl`/`\Bigl`/`\biggl`/`\Biggl`).
enum DelimiterSize {
  /// `\big`-class.
  size1(1),

  /// `\Big`-class.
  size2(2),

  /// `\bigg`-class.
  size3(3),

  /// `\Bigg`-class.
  size4(4);

  const DelimiterSize(this.value);

  /// The numeric size (1–4) as used by KaTeX.
  final int value;
}

/// A LaTeX display style, mirroring KaTeX's `StyleStr`.
enum StyleStr {
  /// Display style (`\displaystyle`).
  display,

  /// Text style (`\textstyle`).
  text,

  /// Script style (`\scriptstyle`).
  script,

  /// Scriptscript style (`\scriptscriptstyle`).
  scriptscript,
}

/// Base of the parse-node AST, mirroring KaTeX's `AnyParseNode` union.
///
/// Every node carries a TeX [mode] and an optional source [loc]ation. Use the
/// sealed subclass list for exhaustive `switch`es in builders; the [type]
/// string is the upstream KaTeX discriminant, kept for 1:1 cross-referencing.
sealed class ParseNode {
  const ParseNode({required this.mode, this.loc});

  /// The TeX mode this node was parsed in.
  final Mode mode;

  /// Source location for error reporting, or `null` if unavailable.
  final SourceLocation? loc;

  /// The KaTeX node `type` string (e.g. `ordgroup`, `supsub`, `genfrac`).
  String get type;
}

/// Returns [node] cast to `T`, or throws a [ParseError] naming the expected
/// [label] and the actual node `type`. Shared by the parser/function builders
/// in place of one hand-written `_assert*` guard per node type.
T assertNodeType<T extends ParseNode>(ParseNode node, String label) {
  if (node is T) {
    return node;
  }
  throw ParseError('Expected node of type $label, but got ${node.type}');
}

/// Marker for the symbol-token parse nodes that correspond to KaTeX symbol
/// `Group`s (`atom`, `accent-token`, `mathord`, `op-token`, `spacing`,
/// `textord`). Mirrors KaTeX's `SymbolParseNode`. All carry a [text].
sealed class SymbolParseNode extends ParseNode {
  const SymbolParseNode({required super.mode, required this.text, super.loc});

  /// The literal text/character of the symbol.
  final String text;
}

// ===========================================================================
// Symbol nodes (SymbolParseNode)
// ===========================================================================

/// `atom` — a symbol with an explicit atom [family] (bin/rel/open/close/
/// punct/inner). Mirrors KaTeX `AtomNode`.
final class AtomNode extends SymbolParseNode {
  /// Creates an atom node.
  const AtomNode({
    required super.mode,
    required super.text,
    required this.family,
    super.loc,
  });

  /// The atom family. KaTeX restricts this to `Atom` (bin/close/inner/open/
  /// punct/rel); the [Group] enum is the superset and is reused here.
  final Group family;

  @override
  String get type => 'atom';
}

/// `mathord` — an ordinary math symbol (e.g. a letter or `\alpha`).
/// Mirrors KaTeX `MathOrdinaryNode`.
final class MathOrdNode extends SymbolParseNode {
  /// Creates a math-ord node.
  const MathOrdNode({required super.mode, required super.text, super.loc});

  @override
  String get type => 'mathord';
}

/// `textord` — an ordinary text/upright symbol (e.g. a digit or `\Gamma`).
/// Mirrors KaTeX `TextOrdinaryNode`.
final class TextOrdNode extends SymbolParseNode {
  /// Creates a text-ord node.
  const TextOrdNode({required super.mode, required super.text, super.loc});

  @override
  String get type => 'textord';
}

/// `spacing` — a horizontal spacing command symbol (e.g. `\,`, `~`).
/// Mirrors KaTeX `SpacingNode`.
final class SpacingNode extends SymbolParseNode {
  /// Creates a spacing node.
  const SpacingNode({required super.mode, required super.text, super.loc});

  @override
  String get type => 'spacing';
}

/// `accent-token` — a raw combining-accent token symbol.
/// Mirrors KaTeX `AccentTokenNode`.
final class AccentTokenNode extends SymbolParseNode {
  /// Creates an accent-token node.
  const AccentTokenNode({required super.mode, required super.text, super.loc});

  @override
  String get type => 'accent-token';
}

/// `op-token` — a raw big-operator token symbol.
/// Mirrors KaTeX `OperatorTokenNode`.
final class OpTokenNode extends SymbolParseNode {
  /// Creates an op-token node.
  const OpTokenNode({required super.mode, required super.text, super.loc});

  @override
  String get type => 'op-token';
}

// ===========================================================================
// Grouping / structural nodes
// ===========================================================================

/// `ordgroup` — an ordinary group `{...}`. Mirrors KaTeX `OrdinaryGroupNode`.
final class OrdGroupNode extends ParseNode {
  /// Creates an ordgroup node.
  const OrdGroupNode({
    required super.mode,
    required this.body,
    super.loc,
    this.semisimple,
  });

  /// The grouped expression.
  final List<ParseNode> body;

  /// Whether this group was produced by a `\begingroup`-style semisimple
  /// group rather than braces.
  final bool? semisimple;

  @override
  String get type => 'ordgroup';
}

/// `supsub` — a base with a superscript and/or subscript.
/// Mirrors KaTeX `SupSubNode`. At least one of [sup]/[sub] is non-null.
final class SupSubNode extends ParseNode {
  /// Creates a supsub node.
  const SupSubNode({
    required super.mode,
    required this.base,
    super.loc,
    this.sup,
    this.sub,
  });

  /// The base the scripts attach to, or `null`.
  final ParseNode? base;

  /// The superscript, or `null`.
  final ParseNode? sup;

  /// The subscript, or `null`.
  final ParseNode? sub;

  @override
  String get type => 'supsub';
}

/// `genfrac` — a generalized fraction (`\frac`, `\dfrac`, `\tfrac`, `\binom`,
/// `\atop`, …). Mirrors KaTeX `GeneralizedFractionNode`.
final class GenfracNode extends ParseNode {
  /// Creates a genfrac node.
  const GenfracNode({
    required super.mode,
    required this.numer,
    required this.denom,
    required this.hasBarLine,
    required this.continued,
    super.loc,
    this.leftDelim,
    this.rightDelim,
    this.barSize,
  });

  /// The numerator expression.
  final ParseNode numer;

  /// The denominator expression.
  final ParseNode denom;

  /// Whether the fraction draws a bar line (false for `\atop`/`\binom`).
  final bool hasBarLine;

  /// Whether this is a `\cfrac`-style continued fraction.
  final bool continued;

  /// The left delimiter (e.g. `(` for `\binom`), or `null`.
  final String? leftDelim;

  /// The right delimiter, or `null`.
  final String? rightDelim;

  /// An explicit bar thickness, or `null` for the default.
  final Measurement? barSize;

  @override
  String get type => 'genfrac';
}

/// `sqrt` — a radical, optionally with an [index] (`\sqrt[3]{x}`).
/// Mirrors KaTeX `SqrtNode`.
final class SqrtNode extends ParseNode {
  /// Creates a sqrt node.
  const SqrtNode({
    required super.mode,
    required this.body,
    super.loc,
    this.index,
  });

  /// The radicand.
  final ParseNode body;

  /// The optional root index, or `null`.
  final ParseNode? index;

  @override
  String get type => 'sqrt';
}

/// `op` — a big operator (`\sum`, `\int`, `\prod`, …).
/// Mirrors KaTeX `OperatorNode`. Either [symbol] is true with a [name], or it
/// is false with a [body] (or a [name] for named operators).
final class OpNode extends ParseNode {
  /// Creates an op node.
  const OpNode({
    required super.mode,
    required this.limits,
    required this.parentIsSupSub,
    required this.symbol,
    super.loc,
    this.name,
    this.body,
    this.alwaysHandleSupSub,
    this.suppressBaseShift,
  });

  /// Whether scripts render as limits (above/below) rather than as sup/sub.
  final bool limits;

  /// Whether this op is the base of a parent `supsub` node.
  final bool parentIsSupSub;

  /// Whether the operator is a single symbol glyph (`symbol: true`) vs. a
  /// composite body.
  final bool symbol;

  /// The operator name/character (for `symbol`/named ops), or `null`.
  final String? name;

  /// The composite body (for non-symbol ops), or `null`.
  final List<ParseNode>? body;

  /// Force handling of attached sup/sub, or `null`.
  final bool? alwaysHandleSupSub;

  /// Suppress the operator's base vertical shift, or `null`.
  final bool? suppressBaseShift;

  /// Returns a copy of this node with the given fields replaced.
  OpNode copyWith({
    Mode? mode,
    bool? limits,
    bool? parentIsSupSub,
    bool? symbol,
    SourceLocation? loc,
    String? name,
    List<ParseNode>? body,
    bool? alwaysHandleSupSub,
    bool? suppressBaseShift,
  }) => OpNode(
    mode: mode ?? this.mode,
    limits: limits ?? this.limits,
    parentIsSupSub: parentIsSupSub ?? this.parentIsSupSub,
    symbol: symbol ?? this.symbol,
    loc: loc ?? this.loc,
    name: name ?? this.name,
    body: body ?? this.body,
    alwaysHandleSupSub: alwaysHandleSupSub ?? this.alwaysHandleSupSub,
    suppressBaseShift: suppressBaseShift ?? this.suppressBaseShift,
  );

  @override
  String get type => 'op';
}

/// `operatorname` — `\operatorname{...}`. Mirrors KaTeX `OperatorNameNode`.
final class OperatorNameNode extends ParseNode {
  /// Creates an operatorname node.
  const OperatorNameNode({
    required super.mode,
    required this.body,
    required this.alwaysHandleSupSub,
    required this.limits,
    required this.parentIsSupSub,
    super.loc,
  });

  /// The operator-name body.
  final List<ParseNode> body;

  /// Force handling of attached sup/sub.
  final bool alwaysHandleSupSub;

  /// Whether scripts render as limits.
  final bool limits;

  /// Whether this is the base of a parent `supsub` node.
  final bool parentIsSupSub;

  /// Returns a copy of this node with the given fields replaced.
  OperatorNameNode copyWith({
    Mode? mode,
    List<ParseNode>? body,
    bool? alwaysHandleSupSub,
    bool? limits,
    bool? parentIsSupSub,
    SourceLocation? loc,
  }) => OperatorNameNode(
    mode: mode ?? this.mode,
    body: body ?? this.body,
    alwaysHandleSupSub: alwaysHandleSupSub ?? this.alwaysHandleSupSub,
    limits: limits ?? this.limits,
    parentIsSupSub: parentIsSupSub ?? this.parentIsSupSub,
    loc: loc ?? this.loc,
  );

  @override
  String get type => 'operatorname';
}

/// `leftright` — a `\left ... \right` delimiter group.
/// Mirrors KaTeX `LeftRightNode`.
final class LeftRightNode extends ParseNode {
  /// Creates a leftright node.
  const LeftRightNode({
    required super.mode,
    required this.body,
    required this.left,
    required this.right,
    super.loc,
    this.rightColor,
  });

  /// The delimited expression.
  final List<ParseNode> body;

  /// The left delimiter string (`.` means none).
  final String left;

  /// The right delimiter string (`.` means none).
  final String right;

  /// An optional color carried for the right delimiter.
  final String? rightColor;

  @override
  String get type => 'leftright';
}

/// `delimsizing` — a manually-sized delimiter (`\bigl`, `\Big`, …).
/// Mirrors KaTeX `DelimiterSizingNode`.
final class DelimsizingNode extends ParseNode {
  /// Creates a delimsizing node.
  const DelimsizingNode({
    required super.mode,
    required this.size,
    required this.mclass,
    required this.delim,
    super.loc,
  });

  /// The delimiter size (1–4).
  final DelimiterSize size;

  /// The math class to give the sized delimiter (`mopen`/`mclose`/`mrel`/
  /// `mord` in KaTeX).
  final MathClass mclass;

  /// The delimiter string.
  final String delim;

  @override
  String get type => 'delimsizing';
}

// ===========================================================================
// Accent nodes
// ===========================================================================

/// Shared base for the two accent node types.
sealed class AccentBaseNode extends ParseNode {
  const AccentBaseNode({
    required super.mode,
    required this.label,
    required this.base,
    super.loc,
    this.isStretchy,
    this.isShifty,
  });

  /// The accent command label (e.g. `\hat`, `\overline`).
  final String label;

  /// The accented expression.
  final ParseNode base;

  /// Whether the accent stretches to the base width, or `null`.
  final bool? isStretchy;

  /// Whether the accent shifts with the base's italic correction, or `null`.
  final bool? isShifty;
}

/// `accent` — an over-accent (`\hat`, `\bar`, `\vec`, `\tilde`, `\overline`
/// via the accent machinery). Mirrors KaTeX `AccentNode`.
final class AccentNode extends AccentBaseNode {
  /// Creates an accent node.
  const AccentNode({
    required super.mode,
    required super.label,
    required super.base,
    super.loc,
    super.isStretchy,
    super.isShifty,
  });

  @override
  String get type => 'accent';
}

/// `accentUnder` — an under-accent (e.g. `\underline` family).
/// Mirrors KaTeX `AccentUnderNode`.
final class AccentUnderNode extends AccentBaseNode {
  /// Creates an accentUnder node.
  const AccentUnderNode({
    required super.mode,
    required super.label,
    required super.base,
    super.loc,
    super.isStretchy,
    super.isShifty,
  });

  @override
  String get type => 'accentUnder';
}

/// `overline` — `\overline{...}`. Mirrors KaTeX `OverlineNode`.
final class OverlineNode extends ParseNode {
  /// Creates an overline node.
  const OverlineNode({required super.mode, required this.body, super.loc});

  /// The overlined expression.
  final ParseNode body;

  @override
  String get type => 'overline';
}

/// `underline` — `\underline{...}`. Mirrors KaTeX `UnderlineNode`.
final class UnderlineNode extends ParseNode {
  /// Creates an underline node.
  const UnderlineNode({required super.mode, required this.body, super.loc});

  /// The underlined expression.
  final ParseNode body;

  @override
  String get type => 'underline';
}

// ===========================================================================
// Text / font / color / sizing / styling
// ===========================================================================

/// `text` — `\text{...}` and friends. Mirrors KaTeX `TextNode`.
final class TextNode extends ParseNode {
  /// Creates a text node.
  const TextNode({
    required super.mode,
    required this.body,
    super.loc,
    this.font,
  });

  /// The text-mode body.
  final List<ParseNode> body;

  /// An optional text font command (e.g. `textrm`), or `null`.
  final String? font;

  @override
  String get type => 'text';
}

/// `font` — a math font command (`\mathbf`, `\mathrm`, `\mathbb`, …).
/// Mirrors KaTeX `FontNode`.
final class FontNode extends ParseNode {
  /// Creates a font node.
  const FontNode({
    required super.mode,
    required this.font,
    required this.body,
    super.loc,
  });

  /// The font command name (KaTeX `MathFont` minus the empty string).
  final String font;

  /// The expression the font applies to.
  final ParseNode body;

  @override
  String get type => 'font';
}

/// `color` — `\color`/`\textcolor`. Mirrors KaTeX `ColorNode`.
final class ColorNode extends ParseNode {
  /// Creates a color node.
  const ColorNode({
    required super.mode,
    required this.color,
    required this.body,
    super.loc,
  });

  /// The CSS color string.
  final String color;

  /// The colored expression.
  final List<ParseNode> body;

  @override
  String get type => 'color';
}

/// `color-token` — a raw color argument token. Mirrors KaTeX `ColorTokenNode`.
final class ColorTokenNode extends ParseNode {
  /// Creates a color-token node.
  const ColorTokenNode({required super.mode, required this.color, super.loc});

  /// The CSS color string.
  final String color;

  @override
  String get type => 'color-token';
}

/// `sizing` — a size command (`\Large`, `\small`, …).
/// Mirrors KaTeX `SizingNode`.
final class SizingNode extends ParseNode {
  /// Creates a sizing node.
  const SizingNode({
    required super.mode,
    required this.size,
    required this.body,
    super.loc,
  });

  /// The size index (KaTeX size 1–11).
  final int size;

  /// The resized expression.
  final List<ParseNode> body;

  @override
  String get type => 'sizing';
}

/// `styling` — a style command (`\displaystyle`, `\scriptstyle`, …).
/// Mirrors KaTeX `StylingNode`.
final class StylingNode extends ParseNode {
  /// Creates a styling node.
  const StylingNode({
    required super.mode,
    required this.style,
    required this.body,
    super.loc,
    this.resetFont,
  });

  /// The target style.
  final StyleStr style;

  /// The restyled expression.
  final List<ParseNode> body;

  /// Whether to reset the font within the style, or `null`.
  final bool? resetFont;

  @override
  String get type => 'styling';
}

// ===========================================================================
// Arrays / environments
// ===========================================================================

/// How columns are separated/aligned in an array, mirroring KaTeX's
/// `ColSeparationType` (`align`, `alignat`, `gather`, `small`, `CD`).
enum ColSeparationType {
  /// `align`/`aligned` separation.
  align,

  /// `alignat`/`alignedat` separation.
  alignat,

  /// `gather`/`gathered` separation.
  gather,

  /// Small (e.g. `smallmatrix`) separation.
  small,

  /// Commutative-diagram (`CD`) separation.
  cd,
}

/// A column alignment specification in an array's column descriptor.
///
/// Mirrors KaTeX's `AlignSpec` union, which is either a separator (a literal
/// gap/rule between columns) or an aligned column (`l`/`c`/`r` with optional
/// pre/post gaps). Represented here as one class with a [separator] flag.
@immutable
class AlignSpec {
  /// Creates a separator spec (`type: "separator"` in KaTeX), carrying the
  /// literal [separator] text drawn between columns.
  const AlignSpec.separator(this.separator)
    : align = null,
      pregap = null,
      postgap = null;

  /// Creates an aligned-column spec (`type: "align"` in KaTeX).
  const AlignSpec.align(String this.align, {this.pregap, this.postgap})
    : separator = null;

  /// The separator text, non-null iff this is a separator spec.
  final String? separator;

  /// The column alignment (`l`/`c`/`r`), non-null iff this is an align spec.
  final String? align;

  /// Optional space before the column.
  final double? pregap;

  /// Optional space after the column.
  final double? postgap;

  /// Whether this spec is a column separator (vs. an aligned column).
  bool get isSeparator => separator != null;
}

/// `array` — a tabular environment (`matrix`, `pmatrix`, `bmatrix`,
/// `aligned`, `cases`, …). Mirrors KaTeX `ArrayNode`.
final class ArrayNode extends ParseNode {
  /// Creates an array node.
  const ArrayNode({
    required super.mode,
    required this.body,
    required this.rowGaps,
    required this.hLinesBeforeRow,
    required this.arraystretch,
    super.loc,
    this.colSeparationType,
    this.hskipBeforeAndAfter,
    this.addJot,
    this.cols,
    this.tags,
    this.leqno,
  });

  /// Rows of cells; each cell is an expression.
  final List<List<ParseNode>> body;

  /// Per-row vertical gaps (`null` = default).
  final List<Measurement?> rowGaps;

  /// For each row position, the horizontal rules (`\hline`) before it.
  final List<List<bool>> hLinesBeforeRow;

  /// The `\arraystretch` factor applied to row heights.
  final double arraystretch;

  /// How columns are separated, or `null`.
  final ColSeparationType? colSeparationType;

  /// Whether to add horizontal skips before/after the array, or `null`.
  final bool? hskipBeforeAndAfter;

  /// Whether to add inter-row jot spacing, or `null`.
  final bool? addJot;

  /// The column descriptors, or `null`.
  final List<AlignSpec>? cols;

  /// Per-row tags: `true`/`false` for auto-numbering or an explicit tag
  /// expression (`List<ParseNode>`); `null` if untagged. Elements are either a
  /// [bool] or a `List<ParseNode>`.
  final List<Object>? tags;

  /// Whether equation numbers go on the left (`leqno`), or `null`.
  final bool? leqno;

  /// Returns a copy of this node with the given fields replaced.
  ArrayNode copyWith({
    Mode? mode,
    List<List<ParseNode>>? body,
    List<Measurement?>? rowGaps,
    List<List<bool>>? hLinesBeforeRow,
    double? arraystretch,
    SourceLocation? loc,
    ColSeparationType? colSeparationType,
    bool? hskipBeforeAndAfter,
    bool? addJot,
    List<AlignSpec>? cols,
    List<Object>? tags,
    bool? leqno,
  }) => ArrayNode(
    mode: mode ?? this.mode,
    body: body ?? this.body,
    rowGaps: rowGaps ?? this.rowGaps,
    hLinesBeforeRow: hLinesBeforeRow ?? this.hLinesBeforeRow,
    arraystretch: arraystretch ?? this.arraystretch,
    loc: loc ?? this.loc,
    colSeparationType: colSeparationType ?? this.colSeparationType,
    hskipBeforeAndAfter: hskipBeforeAndAfter ?? this.hskipBeforeAndAfter,
    addJot: addJot ?? this.addJot,
    cols: cols ?? this.cols,
    tags: tags ?? this.tags,
    leqno: leqno ?? this.leqno,
  );

  @override
  String get type => 'array';
}

// ===========================================================================
// Spacing / rules / phantoms / classes / wrappers
// ===========================================================================

/// `kern` — explicit horizontal/vertical space (`\kern`, `\mkern`, …).
/// Mirrors KaTeX `KernNode`.
final class KernNode extends ParseNode {
  /// Creates a kern node.
  const KernNode({required super.mode, required this.dimension, super.loc});

  /// The kern dimension.
  final Measurement dimension;

  @override
  String get type => 'kern';
}

/// `rule` — a filled rectangle (`\rule`). Mirrors KaTeX `RuleNode`.
final class RuleNode extends ParseNode {
  /// Creates a rule node.
  const RuleNode({
    required super.mode,
    required this.width,
    required this.height,
    super.loc,
    this.shift,
  });

  /// The rule width.
  final Measurement width;

  /// The rule height (above the baseline).
  final Measurement height;

  /// The vertical shift, or `null`.
  final Measurement? shift;

  @override
  String get type => 'rule';
}

/// `phantom` — `\phantom{...}` (reserves space, draws nothing).
/// Mirrors KaTeX `PhantomNode`.
final class PhantomNode extends ParseNode {
  /// Creates a phantom node.
  const PhantomNode({required super.mode, required this.body, super.loc});

  /// The phantom body.
  final List<ParseNode> body;

  @override
  String get type => 'phantom';
}

/// `vphantom` — `\vphantom{...}` (reserves height/depth, zero width, no ink).
/// Mirrors KaTeX `VPhantomNode`.
final class VphantomNode extends ParseNode {
  /// Creates a vphantom node.
  const VphantomNode({required super.mode, required this.body, super.loc});

  /// The phantom body.
  final ParseNode body;

  @override
  String get type => 'vphantom';
}

/// `mclass` — explicit math-class wrapper (`\mathbin`, `\mathrel`, …).
/// Mirrors KaTeX `MathClassNode`.
final class MclassNode extends ParseNode {
  /// Creates an mclass node.
  const MclassNode({
    required super.mode,
    required this.mclass,
    required this.body,
    required this.isCharacterBox,
    super.loc,
  });

  /// The math class to assign.
  final MathClass mclass;

  /// The wrapped expression.
  final List<ParseNode> body;

  /// Whether the body is a single character box (affects spacing).
  final bool isCharacterBox;

  @override
  String get type => 'mclass';
}

/// `htmlmathml` — a node carrying separate HTML and MathML renderings.
/// Mirrors KaTeX `HtmlMathmlNode`.
final class HtmlMathmlNode extends ParseNode {
  /// Creates an htmlmathml node.
  const HtmlMathmlNode({
    required super.mode,
    required this.html,
    required this.mathml,
    super.loc,
  });

  /// The HTML-side expression.
  final List<ParseNode> html;

  /// The MathML-side expression.
  final List<ParseNode> mathml;

  @override
  String get type => 'htmlmathml';
}

/// `raw` — a raw string argument token. Mirrors KaTeX `RawNode`.
final class RawNode extends ParseNode {
  /// Creates a raw node.
  const RawNode({required super.mode, required this.string, super.loc});

  /// The raw string.
  final String string;

  @override
  String get type => 'raw';
}

/// `size` — a size argument token (`{number, unit}` plus a blank flag).
/// Mirrors KaTeX `SizeNode`.
final class SizeNode extends ParseNode {
  /// Creates a size node.
  const SizeNode({
    required super.mode,
    required this.value,
    required this.isBlank,
    super.loc,
  });

  /// The measured size.
  final Measurement value;

  /// Whether the argument was blank.
  final bool isBlank;

  @override
  String get type => 'size';
}

/// `ordgroup`-less `internal` placeholder node. Mirrors KaTeX `InternalNode`.
final class InternalNode extends ParseNode {
  /// Creates an internal node.
  const InternalNode({required super.mode, super.loc});

  @override
  String get type => 'internal';
}

// ===========================================================================
// Transient parser-internal nodes
//
// These mirror KaTeX node types that exist only momentarily during parsing
// and never appear in the final returned tree (KaTeX's `infix`, `cr`,
// `leftright-right`, `middle`, `environment`). They are part of the sealed
// hierarchy here because function handlers (T-008) are typed to return a
// [ParseNode]; the Parser consumes and discards them. See T-008 report.
// ===========================================================================

/// `infix` — a transient infix operator (`\over`, `\atop`, `\above`, …) that
/// `handleInfixNodes` rewrites into a [GenfracNode]. Mirrors KaTeX
/// `InfixNode`. Never escapes parsing.
final class InfixNode extends ParseNode {
  /// Creates an infix node.
  const InfixNode({
    required super.mode,
    required this.replaceWith,
    super.loc,
    this.size,
    this.token,
  });

  /// The function name (e.g. `\frac`) this infix is rewritten into.
  final String replaceWith;

  /// An explicit bar size (for `\above`), or `null`.
  final Measurement? size;

  /// The originating token text, for error reporting.
  final String? token;

  @override
  String get type => 'infix';
}

/// `cr` — a transient row/line break (`\\`). Mirrors KaTeX `CarriageReturnNode`.
/// Within arrays the Parser breaks on `\\` and never builds this; it exists so
/// a stray top-level `\\` can be represented.
final class CrNode extends ParseNode {
  /// Creates a cr node.
  const CrNode({
    required super.mode,
    required this.newLine,
    super.loc,
    this.size,
  });

  /// Whether this is a hard line break.
  final bool newLine;

  /// An optional explicit gap size, or `null`.
  final Measurement? size;

  @override
  String get type => 'cr';
}

/// `leftright-right` — the transient result of parsing a `\right`. Mirrors
/// KaTeX `LeftRightRightNode`. Consumed immediately by the `\left` handler.
final class LeftRightRightNode extends ParseNode {
  /// Creates a leftright-right node.
  const LeftRightRightNode({
    required super.mode,
    required this.delim,
    super.loc,
    this.color,
  });

  /// The right delimiter string.
  final String delim;

  /// A color carried from a preceding `\color`, or `null`.
  final String? color;

  @override
  String get type => 'leftright-right';
}

/// `middle` — a transient `\middle` delimiter. Mirrors KaTeX `MiddleNode`.
final class MiddleNode extends ParseNode {
  /// Creates a middle node.
  const MiddleNode({required super.mode, required this.delim, super.loc});

  /// The delimiter string.
  final String delim;

  @override
  String get type => 'middle';
}

/// `environment` — the transient result of parsing a bare `\end{name}`.
/// Mirrors KaTeX `EnvironmentNode`. The `\begin` handler returns the actual
/// environment node (e.g. an [ArrayNode]); this only carries the closing name.
final class EnvironmentNode extends ParseNode {
  /// Creates an environment node.
  const EnvironmentNode({required super.mode, required this.name, super.loc});

  /// The environment name from `\end{name}`.
  final String name;

  @override
  String get type => 'environment';
}

/// `mathchoice` — `\mathchoice{D}{T}{S}{SS}` (picks a body by current style).
/// Mirrors KaTeX `MathChoiceNode`.
final class MathChoiceNode extends ParseNode {
  /// Creates a mathchoice node.
  const MathChoiceNode({
    required super.mode,
    required this.display,
    required this.text,
    required this.script,
    required this.scriptscript,
    super.loc,
  });

  /// The display-style body.
  final List<ParseNode> display;

  /// The text-style body.
  final List<ParseNode> text;

  /// The script-style body.
  final List<ParseNode> script;

  /// The scriptscript-style body.
  final List<ParseNode> scriptscript;

  @override
  String get type => 'mathchoice';
}

/// `htmlmathml` is defined above. `html` — `\htmlClass`/`\htmlId`/`\htmlStyle`/
/// `\htmlData` (attributes are visually no-ops in our backend). Mirrors KaTeX
/// `HtmlNode`.
final class HtmlNode extends ParseNode {
  /// Creates an html node.
  const HtmlNode({
    required super.mode,
    required this.attributes,
    required this.body,
    super.loc,
  });

  /// The HTML attributes (`class`/`id`/`style`/`data-*`). Kept faithfully even
  /// though the current backend does not render them.
  final Map<String, String> attributes;

  /// The wrapped expression.
  final List<ParseNode> body;

  @override
  String get type => 'html';
}

/// `href` — `\href{url}{body}` / `\url{url}`. Mirrors KaTeX `HrefNode`. The
/// link is a visual no-op in our backend; the URL is kept on the node.
final class HrefNode extends ParseNode {
  /// Creates an href node.
  const HrefNode({
    required super.mode,
    required this.href,
    required this.body,
    super.loc,
  });

  /// The link target URL.
  final String href;

  /// The wrapped expression.
  final List<ParseNode> body;

  @override
  String get type => 'href';
}

/// `smash` — `\smash[tb]{body}` (zeroes height and/or depth). Mirrors KaTeX
/// `SmashNode`.
final class SmashNode extends ParseNode {
  /// Creates a smash node.
  const SmashNode({
    required super.mode,
    required this.body,
    required this.smashHeight,
    required this.smashDepth,
    super.loc,
  });

  /// The body.
  final ParseNode body;

  /// Whether to zero the height.
  final bool smashHeight;

  /// Whether to zero the depth.
  final bool smashDepth;

  @override
  String get type => 'smash';
}

/// `lap` — `\mathllap`/`\mathrlap`/`\mathclap` (zero-width overlaps). Mirrors
/// KaTeX `LapNode`. [alignment] is one of `llap`/`rlap`/`clap`.
final class LapNode extends ParseNode {
  /// Creates a lap node.
  const LapNode({
    required super.mode,
    required this.alignment,
    required this.body,
    super.loc,
  });

  /// The lap alignment (`llap`, `rlap`, or `clap`).
  final String alignment;

  /// The body.
  final ParseNode body;

  @override
  String get type => 'lap';
}

/// `horizBrace` — `\overbrace`/`\underbrace` (stretchy brace). Mirrors KaTeX
/// `HorizBraceNode`.
final class HorizBraceNode extends ParseNode {
  /// Creates a horizBrace node.
  const HorizBraceNode({
    required super.mode,
    required this.label,
    required this.isOver,
    required this.base,
    super.loc,
  });

  /// The control-sequence name (`\overbrace` / `\underbrace`).
  final String label;

  /// Whether the brace sits above (`\overbrace`) the base.
  final bool isOver;

  /// The base expression.
  final ParseNode base;

  @override
  String get type => 'horizBrace';
}

/// `xArrow` — extensible arrows (`\xrightarrow` & friends). Mirrors KaTeX
/// `XArrowNode`.
final class XArrowNode extends ParseNode {
  /// Creates an xArrow node.
  const XArrowNode({
    required super.mode,
    required this.label,
    required this.body,
    super.loc,
    this.below,
  });

  /// The control-sequence name (`\xrightarrow`, …).
  final String label;

  /// The text above the arrow.
  final ParseNode body;

  /// The optional text below the arrow, or `null`.
  final ParseNode? below;

  @override
  String get type => 'xArrow';
}

/// `raisebox` — `\raisebox{dy}{body}`. Mirrors KaTeX `RaiseBoxNode`.
final class RaiseBoxNode extends ParseNode {
  /// Creates a raisebox node.
  const RaiseBoxNode({
    required super.mode,
    required this.dy,
    required this.body,
    super.loc,
  });

  /// The vertical raise amount.
  final Measurement dy;

  /// The body (parsed as an hbox).
  final ParseNode body;

  @override
  String get type => 'raisebox';
}

/// `vcenter` — `\vcenter{body}` (centers on the math axis). Mirrors KaTeX
/// `VCenterNode`.
final class VcenterNode extends ParseNode {
  /// Creates a vcenter node.
  const VcenterNode({required super.mode, required this.body, super.loc});

  /// The body.
  final ParseNode body;

  @override
  String get type => 'vcenter';
}

/// `pmb` — `\pmb{body}` (poor-man's bold). Mirrors KaTeX `PmbNode`.
final class PmbNode extends ParseNode {
  /// Creates a pmb node.
  const PmbNode({
    required super.mode,
    required this.mclass,
    required this.body,
    super.loc,
  });

  /// The math class derived from the body.
  final MathClass mclass;

  /// The wrapped expression.
  final List<ParseNode> body;

  @override
  String get type => 'pmb';
}

/// `hbox` — `\hbox{...}` (prevents a soft line break; renders its body).
/// Mirrors KaTeX `HboxNode`.
final class HboxNode extends ParseNode {
  /// Creates an hbox node.
  const HboxNode({required super.mode, required this.body, super.loc});

  /// The wrapped expression.
  final List<ParseNode> body;

  @override
  String get type => 'hbox';
}

/// `enclose` — `\fbox`, `\boxed`, `\colorbox`, `\fcolorbox`, `\cancel`,
/// `\bcancel`, `\xcancel`, `\sout`, `\angl`. Mirrors KaTeX's `enclose` parse
/// node. [label] is the command name (e.g. `\cancel`);
/// [backgroundColor]/[borderColor] are CSS color strings supplied by the
/// `\colorbox`/`\fcolorbox` color arguments (else `null`).
final class EncloseParseNode extends ParseNode {
  /// Creates an enclose node.
  const EncloseParseNode({
    required super.mode,
    required this.label,
    required this.body,
    super.loc,
    this.backgroundColor,
    this.borderColor,
  });

  /// The command name (e.g. `\fbox`, `\cancel`, `\colorbox`).
  final String label;

  /// The enclosed expression.
  final ParseNode body;

  /// The background fill color (CSS string), or `null`.
  final String? backgroundColor;

  /// The border color (CSS string), or `null`.
  final String? borderColor;

  @override
  String get type => 'enclose';
}

/// `includegraphics` — `\includegraphics[opts]{path}`. Mirrors KaTeX
/// `IncludegraphicsNode`. Sizes are [Measurement]s resolved at build time.
final class IncludegraphicsParseNode extends ParseNode {
  /// Creates an includegraphics node.
  const IncludegraphicsParseNode({
    required super.mode,
    required this.alt,
    required this.width,
    required this.height,
    required this.totalheight,
    required this.src,
    super.loc,
  });

  /// The alt text (defaults to the file name with no extension).
  final String alt;

  /// The requested width (`{number: 0, unit: "em"}` means "natural").
  final Measurement width;

  /// The requested height (default `0.9em`, sorta character sized).
  final Measurement height;

  /// The requested total height (height + depth); `0` means "no depth".
  final Measurement totalheight;

  /// The image source URL/path.
  final String src;

  @override
  String get type => 'includegraphics';
}

/// `verb` — `\verb|...|` literal monospace text. Mirrors KaTeX `VerbNode`.
final class VerbNode extends ParseNode {
  /// Creates a verb node.
  const VerbNode({
    required super.mode,
    required this.body,
    required this.star,
    super.loc,
  });

  /// The verbatim text.
  final String body;

  /// Whether this is the starred form (`\verb*`).
  final bool star;

  @override
  String get type => 'verb';
}
