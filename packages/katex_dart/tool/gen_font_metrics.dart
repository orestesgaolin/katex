// Generator: KaTeX fontMetricsData.js -> Dart const map.
//
// Approach
// --------
// KaTeX ships `src/fontMetricsData.js` as an ES module of the form
// `export default { "<family>": { "<charcode>": [d, h, ital, skew, w], ... } }`.
// Rather than re-implement a JS parser in Dart, this tool shells out to Node
// (`node --input-type=module`) to `import` that module and `JSON.stringify` the
// data to stdout. We then decode the JSON in Dart and emit a Dart `const`:
//
//   const Map<String, Map<int, List<double>>> fontMetricsData = { ... };
//
// (family -> charcode -> [depth, height, italic, skew, width]).
//
// This keeps the generated table byte-faithful to upstream and trivially
// regenerable when the pinned KaTeX version changes. Requires `node` on PATH.
//
// Run from the package root:
//   dart run tool/gen_font_metrics.dart
import 'dart:convert';
import 'dart:io';

const _sourceJs =
    '../../reference/node_modules/katex/src/fontMetricsData.js';
const _outPath = 'lib/src/font/font_metrics_data.g.dart';

Future<void> main() async {
  final sourceFile = File(_sourceJs);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Cannot find KaTeX fontMetricsData.js at $_sourceJs');
    exit(1);
  }

  // Use Node to load the ES module and dump it as JSON. We pass an absolute
  // path so Node's resolver does not depend on the import being relative to a
  // package boundary.
  final absSource = sourceFile.absolute.uri.toString();
  final script = '''
import data from ${jsonEncode(absSource)};
const m = data.default || data;
process.stdout.write(JSON.stringify(m));
''';

  final result = await Process.run(
    'node',
    ['--input-type=module', '-e', script],
  );
  if (result.exitCode != 0) {
    stderr.writeln('node failed (exit ${result.exitCode}):');
    stderr.writeln(result.stderr);
    exit(1);
  }

  final decoded = jsonDecode(result.stdout as String) as Map<String, dynamic>;

  final buffer = StringBuffer()
    ..writeln('// GENERATED FILE — DO NOT EDIT.')
    ..writeln('// Regenerate with: dart run tool/gen_font_metrics.dart')
    ..writeln('//')
    ..writeln('// Source: KaTeX src/fontMetricsData.js (SIL OFL fonts; MIT data).')
    ..writeln('// family -> charcode -> [depth, height, italic, skew, width].')
    ..writeln()
    ..writeln(
      'const Map<String, Map<int, List<double>>> fontMetricsData = {',
    );

  // Sort families for deterministic output.
  final families = decoded.keys.toList()..sort();
  for (final family in families) {
    final glyphs = decoded[family] as Map<String, dynamic>;
    buffer.writeln('  ${_dartString(family)}: {');
    // Sort charcodes numerically for deterministic, diffable output.
    final codes = glyphs.keys.map(int.parse).toList()..sort();
    for (final code in codes) {
      final tuple = (glyphs['$code'] as List)
          .map((n) => _dartNum(n as num))
          .join(', ');
      buffer.writeln('    $code: [$tuple],');
    }
    buffer.writeln('  },');
  }
  buffer.writeln('};');

  final outFile = File(_outPath);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(buffer.toString());

  final glyphCount =
      decoded.values.fold<int>(0, (s, g) => s + (g as Map).length);
  stdout.writeln(
    'Wrote $_outPath: ${families.length} families, $glyphCount glyphs.',
  );
}

String _dartString(String s) => "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";

/// Render a number as a Dart `double` literal, preserving the source value.
String _dartNum(num n) {
  // All metric values are doubles; ensure a decimal point so the literal types
  // as double inside `List<double>`.
  if (n == n.truncate() && n.toString().indexOf('.') == -1) {
    return '${n.toInt()}.0';
  }
  return n.toString();
}
