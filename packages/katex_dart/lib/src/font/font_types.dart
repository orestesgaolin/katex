/// Font families and variants used by KaTeX, ported to Dart.
///
/// KaTeX organises glyphs into a handful of TrueType font files named
/// `KaTeX_<Family>-<Variant>` (e.g. `KaTeX_Main-Regular`,
/// `KaTeX_Math-Italic`). The combination of [KatexFontFamily] and
/// [KatexFontVariant] identifies one of those files; `fontName` produces the
/// `<Family>-<Variant>` key used by the metric tables (see
/// `font_metrics_data.g.dart`), and `fontFileName` produces the on-disk asset
/// name.
library;

import 'package:meta/meta.dart';

/// The KaTeX font families.
///
/// Names mirror the `KaTeX_<Family>` prefix of the shipped `.ttf` files.
enum KatexFontFamily {
  main('Main'),
  math('Math'),
  ams('AMS'),
  size1('Size1'),
  size2('Size2'),
  size3('Size3'),
  size4('Size4'),
  caligraphic('Caligraphic'),
  fraktur('Fraktur'),
  sansSerif('SansSerif'),
  script('Script'),
  typewriter('Typewriter');

  const KatexFontFamily(this.familyName);

  /// The capitalised family token used in font file / metric keys.
  final String familyName;
}

/// The weight/shape variant of a font file.
///
/// Mirrors the `-<Variant>` suffix of the shipped `.ttf` files. Not every
/// family ships every variant (e.g. the `Size*` families are regular-only).
enum KatexFontVariant {
  regular('Regular'),
  bold('Bold'),
  italic('Italic'),
  boldItalic('BoldItalic');

  const KatexFontVariant(this.variantName);

  /// The variant token used in font file / metric keys.
  final String variantName;
}

/// A concrete (family, variant) pair identifying a single KaTeX font file.
@immutable
class KatexFont {
  const KatexFont(this.family, this.variant);

  final KatexFontFamily family;
  final KatexFontVariant variant;

  /// The `<Family>-<Variant>` key used by the metric map, e.g.
  /// `Main-Regular`, `Math-Italic`.
  String get fontName => '${family.familyName}-${variant.variantName}';

  /// The CSS/asset font-family string, e.g. `KaTeX_Main`.
  String get cssFamily => 'KaTeX_${family.familyName}';

  /// The on-disk asset file name, e.g. `KaTeX_Main-Regular.ttf`.
  String get fontFileName => 'KaTeX_$fontName.ttf';

  @override
  bool operator ==(Object other) =>
      other is KatexFont && other.family == family && other.variant == variant;

  @override
  int get hashCode => Object.hash(family, variant);

  @override
  String toString() => 'KatexFont($fontName)';
}
