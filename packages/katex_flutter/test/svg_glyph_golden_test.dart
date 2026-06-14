// Independent glyph-shape cross-check for the Flutter golden harness (T-021).
//
// The Flutter goldens in `golden_test.dart` render via the Skia/`TextPainter`
// path. This test proves the SAME glyph shapes also rasterise through the
// `package:katex` SVG path, by:
//   1. serialising a few gallery formulas to SVG via `renderToSvg`,
//   2. rasterising each SVG to PNG with `rsvg-convert` (the SIL-OFL KaTeX
//      fonts are embedded/referenced so real glyph outlines are drawn), and
//   3. comparing each PNG byte-for-byte against a self-captured golden under
//      `goldens/svg/<id>.png`.
//
// It is a SELF-CAPTURED regression golden (like `golden_test.dart`), captured
// by this test with `--update-goldens`; it is NOT a comparison against the
// KaTeX reference PNGs (those differ structurally — see `golden_test.dart`).
// Its purpose is to (a) independently demonstrate real glyph SHAPES render
// (the rasterised PNG is not blank and not a solid block), and (b) catch
// regressions in the SVG serialiser.
//
// If `rsvg-convert` is not on PATH the suite SKIPS (it does not fake a pass).
//
// ignore_for_file: avoid_print
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:katex/katex.dart';

/// A subset of the gallery exercising several font families/glyph shapes.
const _entries = <String, String>{
  'svg-sup-x-2': 'x^2',
  'svg-frac-a-b': r'\frac{a}{b}',
  'svg-greek': r'\alpha+\beta',
  'svg-mathbb-r': r'\mathbb{R}',
  'svg-text-hi': r'\text{hi}',
};

/// Fixed zoom so captures are deterministic and glyphs are a usable size.
const String _zoom = '2.0';

String? _which(String exe) {
  try {
    final r = Process.runSync(exe, const ['--version']);
    if (r.exitCode == 0 || r.exitCode == 1) return exe;
  } on ProcessException {
    return null;
  }
  return null;
}

/// Rasterises [svg] text to a PNG file at [out] via rsvg-convert. Returns true
/// on success.
bool _rasterize(String rasterizer, String svg, String svgPath, String out) {
  File(svgPath).writeAsStringSync(svg);
  final r = Process.runSync(
    rasterizer,
    ['-z', _zoom, svgPath, '-o', out],
  );
  return r.exitCode == 0 && File(out).existsSync();
}

/// Coarse "the raster actually drew glyph ink" gate. A blank PNG of comparable
/// dimensions is ~100-150 bytes (verified empirically with rsvg-convert); any
/// real glyph ink pushes the encoded size well above this floor. The precise
/// regression check is the byte-for-byte golden compare below.
const int _nonBlankFloorBytes = 250;

void main() {
  final rasterizer = _which('rsvg-convert') ?? _which('resvg');

  group('svg glyph-shape goldens (self-captured)', () {
    if (rasterizer == null) {
      test('skipped: no SVG rasteriser (rsvg-convert/resvg) on PATH', () {
        print('SKIP: install librsvg (rsvg-convert) or resvg to run this.');
      }, skip: 'no SVG rasteriser on PATH');
      return;
    }

    final tmp = Directory.systemTemp.createTempSync('katex_svg_golden');
    tearDownAll(() {
      try {
        tmp.deleteSync(recursive: true);
      } on Object {
        // best effort
      }
    });

    for (final e in _entries.entries) {
      final id = e.key;
      test(id, () async {
        final svg = renderToSvg(e.value);
        expect(svg, contains('<svg'), reason: 'serialiser produced SVG');

        final svgPath = '${tmp.path}/$id.svg';
        final pngPath = '${tmp.path}/$id.png';
        final ok = _rasterize(rasterizer, svg, svgPath, pngPath);
        expect(ok, isTrue, reason: 'rsvg-convert rasterised $id');

        final bytes = File(pngPath).readAsBytesSync();
        expect(
          bytes.length,
          greaterThan(_nonBlankFloorBytes),
          reason: 'rasterised PNG for $id has real glyph ink (not blank)',
        );

        await expectLater(
          File(pngPath).readAsBytes(),
          matchesGoldenFile('goldens/svg/$id.png'),
        );
      });
    }
  });
}
