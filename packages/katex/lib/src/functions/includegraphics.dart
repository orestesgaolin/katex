/// Parser handler for `\includegraphics`, ported from
/// `reference/node_modules/katex/src/functions/includegraphics.ts` (pinned
/// KaTeX 0.17.0).
///
/// `\includegraphics[key=val,…]{path}` parses the optional `width`/`height`/
/// `totalheight`/`alt` keys (sizes are [Measurement]s) and a `url` path, and
/// produces an [IncludegraphicsParseNode] of the resulting dimensions. The
/// box-producing builder lives in `build/builders/includegraphics_builder.dart`.
///
/// Image loading: the SVG backend emits an `<image>` so a browser fetches and
/// displays the bitmap; the Flutter backend only reserves correctly-sized space
/// (it paints a placeholder outline) — real async bitmap loading is out of
/// scope (documented in the painter).
library;

import 'package:katex/src/ast/parse_node.dart';
import 'package:katex/src/functions/function_spec.dart';
import 'package:katex/src/parse/parse_error.dart';

const Set<String> _validUnits = <String>{
  'pt', 'mm', 'cm', 'in', 'bp', 'pc', 'dd', 'cc', 'nd', 'nc', 'sp', 'px', //
  'ex', 'em', 'mu',
};

// Port of KaTeX's `sizeData` (includegraphics.ts): parses a size string into a
// Measurement. A bare number defaults to `bp` (per the graphix package).
Measurement _sizeData(String str) {
  if (RegExp(r'^[-+]? *(\d+(\.\d*)?|\.\d+)$').hasMatch(str)) {
    return Measurement(double.parse(str), 'bp');
  }
  final match = RegExp(
    r'([-+]?) *(\d+(?:\.\d*)?|\.\d+) *([a-z]{2})',
  ).firstMatch(str);
  if (match == null) {
    throw ParseError("Invalid size: '$str' in \\includegraphics");
  }
  final number = double.parse('${match.group(1)}${match.group(2)}');
  final unit = match.group(3)!;
  if (!_validUnits.contains(unit)) {
    throw ParseError("Invalid unit: '$unit' in \\includegraphics.");
  }
  return Measurement(number, unit);
}

/// Registers the `\includegraphics` function handler.
void registerIncludegraphics() {
  defineFunction(
    <String>[r'\includegraphics'],
    FunctionSpec(
      type: 'includegraphics',
      numArgs: 1,
      numOptionalArgs: 1,
      argTypes: const <ArgType?>[ArgType.raw, ArgType.url],
      handler: (context, args, optArgs) {
        final parser = context.parser;
        var width = const Measurement(0, 'em');
        var height = const Measurement(0.9, 'em'); // sorta character sized.
        var totalheight = const Measurement(0, 'em');
        var alt = '';

        final optArg = optArgs[0];
        if (optArg != null) {
          final attributeStr = assertNodeType<RawNode>(optArg, 'raw').string;
          // Parser doesn't split key/value pairs; we get a raw string.
          for (final attribute in attributeStr.split(',')) {
            final keyVal = attribute.split('=');
            if (keyVal.length == 2) {
              final str = keyVal[1].trim();
              switch (keyVal[0].trim()) {
                case 'alt':
                  alt = str;
                case 'width':
                  width = _sizeData(str);
                case 'height':
                  height = _sizeData(str);
                case 'totalheight':
                  totalheight = _sizeData(str);
                default:
                  throw ParseError(
                    "Invalid key: '${keyVal[0]}' in \\includegraphics.",
                  );
              }
            }
          }
        }

        // ArgType.url delivers a RawNode carrying the URL string.
        final src = assertNodeType<RawNode>(args[0], 'raw').string;

        if (alt == '') {
          // No alt given. Use the file name, stripped of path and extension.
          alt = src.replaceAll(RegExp(r'^.*[\\/]'), '');
          final dot = alt.lastIndexOf('.');
          if (dot >= 0) {
            alt = alt.substring(0, dot);
          }
        }

        if (!parser.settings.isTrusted(<String, Object?>{
          'command': r'\includegraphics',
          'url': src,
        })) {
          return parser.formatUnsupportedCmd(r'\includegraphics');
        }

        return IncludegraphicsParseNode(
          mode: parser.mode,
          alt: alt,
          width: width,
          height: height,
          totalheight: totalheight,
          src: src,
        );
      },
    ),
  );
}
