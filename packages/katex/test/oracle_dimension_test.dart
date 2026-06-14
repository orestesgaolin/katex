@TestOn('vm')
// This is a verification harness: it deliberately prints a human-readable
// pass-rate report, and uses `\sqrt` (an escape) in follow-up messages.
// ignore_for_file: avoid_print, document_ignores, use_raw_strings,
// ignore_for_file: lines_longer_than_80_chars
library;

// ---------------------------------------------------------------------------
// T-014 — Core verification: dimension goldens against ORIGINAL KaTeX.
//
// For every entry in the shared gallery (`reference/gallery.json`) this test
// runs the public `renderToBox` pipeline with the matching displayMode and
// compares the ROOT box's height/depth (and width where the oracle provides a
// non-null number) against KaTeX's own internal dimensions captured in
// `reference/fixtures/metrics/<id>.json` (the `root` object).
//
// These oracle numbers are KaTeX's domTree height/depth/width in EM units —
// exactly the numbers our box tree must reproduce, font-rendering aside. The
// root `width` is `null` for every gallery entry (KaTeX advances horizontal
// lists via CSS, not explicit widths), so the width assertion is conditional
// and currently never fires; it is kept so it activates automatically if a
// future fixture records a non-null root width.
//
// TOLERANCE (documented):
//   An entry's dimension PASSES when it is within EITHER
//     - relative error <= 2%   (|ours - oracle| / |oracle|), OR
//     - absolute error <= 0.01 em
//   whichever is looser. This mirrors the ticket's suggested tolerance. The
//   absolute floor matters for dimensions that are exactly 0 (e.g. inline
//   depth), where relative error is undefined/infinite.
//
//   This tolerance is INTENTIONALLY tight: empirically all non-sqrt entries
//   match KaTeX to <0.1% (most to 5 decimal places exactly). The tolerance was
//   NOT loosened to force passes.
//
// KNOWN-APPROX (excluded from the hard assertion, listed as follow-up):
//   None. As of T-020 the `\sqrt` builder matches the oracle exactly, so the
//   `_knownApprox` set is empty and every gallery entry (26/26) is hard-gated.
//   The known-approx reporting machinery is retained for any future stub.
// ---------------------------------------------------------------------------

import 'dart:convert';
import 'dart:io';

import 'package:katex/katex.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Relative tolerance: 2%.
const double _relTol = 0.02;

/// Absolute tolerance: 0.01 em (looser-of-the-two floor).
const double _absTol = 0.01;

/// Gallery ids excluded from the HARD pass/fail gate because they exercise a
/// known MVP approximation. They are still measured and reported, just not
/// asserted on.
///
/// As of T-020 this set is empty: `\sqrt` now matches the KaTeX oracle exactly,
/// so `sqrt-x` and `sqrt-index-3-x` are hard-gated like the rest of the gallery
/// (the dimension gate is 26/26).
const Set<String> _knownApprox = <String>{};

/// Minimum fraction of *gated* (non-known-approx) entries that must pass for
/// the suite to succeed. Empirically every gated entry passes (26/26), so the
/// bar is set at the full set: a regression in any gated entry should fail CI.
const double _passThreshold = 1;

/// Locates the repository root (the directory that contains `reference/`),
/// walking up from the test's working directory so it resolves regardless of
/// where the runner is invoked.
String _repoRoot() {
  var dir = Directory.current.absolute.path;
  while (true) {
    if (Directory(p.join(dir, 'reference', 'fixtures', 'metrics'))
        .existsSync()) {
      return dir;
    }
    final parent = p.dirname(dir);
    if (parent == dir) {
      fail('Could not locate repo root (with reference/fixtures) '
          'from ${Directory.current}');
    }
    dir = parent;
  }
}

/// One dimension comparison result.
class _DimResult {
  _DimResult(this.name, this.ours, this.oracle);
  final String name;
  final double ours;
  final double? oracle;

  bool get applicable => oracle != null;

  double get absDiff => (ours - oracle!).abs();

  /// Relative difference vs the oracle (0 when oracle is 0 and we match).
  double get relDiff {
    final o = oracle!;
    if (o == 0) return ours == 0 ? 0 : double.infinity;
    return absDiff / o.abs();
  }

  bool get pass {
    if (!applicable) return true;
    return relDiff <= _relTol || absDiff <= _absTol;
  }

  String get pctStr =>
      applicable ? '${(relDiff * 100).toStringAsFixed(3)}%' : '   n/a';
}

void main() {
  final root = _repoRoot();
  final galleryFile = File(p.join(root, 'reference', 'gallery.json'));
  final gallery =
      (jsonDecode(galleryFile.readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();

  // Accumulate per-entry results so we can print one summary table at the end.
  final rows = <String>[];
  final gatedFailures = <String>[];
  final knownApproxRows = <String>[];
  var gatedTotal = 0;
  var gatedPass = 0;

  rows.add(
    'id                     dim    ours       oracle     %diff      PASS/FAIL',
  );

  for (final entry in gallery) {
    final id = entry['id'] as String;
    final tex = entry['tex'] as String;
    final displayMode = entry['displayMode'] as bool;

    test('dimension: $id', () {
      final box = renderToBox(tex, options: KatexOptions(displayMode: displayMode));

      final metricsFile =
          File(p.join(root, 'reference', 'fixtures', 'metrics', '$id.json'));
      expect(metricsFile.existsSync(), isTrue,
          reason: 'missing metrics fixture for $id');
      final fx = jsonDecode(metricsFile.readAsStringSync()) as Map;
      final oracleRoot = fx['root'] as Map;

      double? num3(Object? v) => v == null ? null : (v as num).toDouble();

      final results = <_DimResult>[
        _DimResult('height', box.height, num3(oracleRoot['height'])),
        _DimResult('depth', box.depth, num3(oracleRoot['depth'])),
        _DimResult('width', box.width, num3(oracleRoot['width'])),
      ];

      final isKnownApprox = _knownApprox.contains(id);
      final entryPass = results.every((r) => r.pass);

      // Build printable rows (one line per applicable dimension).
      for (final r in results) {
        if (!r.applicable && r.name == 'width') {
          // width is null on the oracle root for the whole gallery; skip the
          // noisy "n/a" line but keep height/depth.
          continue;
        }
        final line = '${id.padRight(22)} '
            '${r.name.padRight(6)} '
            '${r.ours.toStringAsFixed(5).padRight(10)} '
            '${(r.oracle?.toStringAsFixed(5) ?? 'null').padRight(10)} '
            '${r.pctStr.padRight(10)} '
            '${r.pass ? 'PASS' : 'FAIL'}'
            '${isKnownApprox ? '  [KNOWN-APPROX]' : ''}';
        if (isKnownApprox) {
          knownApproxRows.add(line);
        } else {
          rows.add(line);
        }
      }

      if (isKnownApprox) {
        // Measured + reported, but NOT gated. Always "passes" the test case so
        // the suite reflects the documented MVP scope.
        return;
      }

      gatedTotal++;
      if (entryPass) {
        gatedPass++;
      } else {
        for (final r in results) {
          if (!r.pass) {
            gatedFailures.add('$id.${r.name}: ours=${r.ours.toStringAsFixed(5)} '
                'oracle=${r.oracle} (${r.pctStr})');
          }
        }
      }

      // Per-entry assertion for gated entries: each must be within tolerance.
      expect(entryPass, isTrue,
          reason: 'dimension mismatch for $id:\n'
              '${results.where((r) => r.applicable).map((r) => '  ${r.name}: '
                  'ours=${r.ours.toStringAsFixed(5)} oracle=${r.oracle} '
                  '(${r.pctStr}) ${r.pass ? "ok" : "OUT OF TOLERANCE"}').join('\n')}');
    });
  }

  tearDownAll(() {
    final total = gallery.length;
    print('\n===== DIMENSION GOLDEN REPORT '
        '(tolerance: rel<=${(_relTol * 100).toStringAsFixed(0)}% '
        'OR abs<=${_absTol}em) =====');
    for (final row in rows) {
      print(row);
    }
    if (knownApproxRows.isNotEmpty) {
      print('\n----- KNOWN-APPROX (excluded from gate; follow-up) -----');
      for (final row in knownApproxRows) {
        print(row);
      }
    }
    final rate = gatedTotal == 0 ? 0.0 : gatedPass / gatedTotal;
    print('\nDIMENSION PASS RATE (gated): $gatedPass/$gatedTotal '
        '(${(rate * 100).toStringAsFixed(1)}%)');
    print('DIMENSION PASS RATE (whole gallery, incl. known-approx as fail): '
        '$gatedPass/$total');
    if (gatedFailures.isNotEmpty) {
      print('\nGATED FAILURES:');
      for (final f in gatedFailures) {
        print('  $f');
      }
    }
    if (_knownApprox.isEmpty) {
      print('FOLLOW-UP: none — all gallery entries are hard-gated.');
    } else {
      print('FOLLOW-UP: ${_knownApprox.join(', ')} excluded from the hard gate '
          '(MVP approximation).');
    }
  });

  test('gated dimension pass-rate meets threshold', () {
    // Runs after the per-entry tests have populated the counters (test order
    // is registration order in package:test).
    final rate = gatedTotal == 0 ? 0.0 : gatedPass / gatedTotal;
    expect(rate, greaterThanOrEqualTo(_passThreshold),
        reason: 'gated dimension pass rate $gatedPass/$gatedTotal '
            '(${(rate * 100).toStringAsFixed(1)}%) below '
            'threshold ${(_passThreshold * 100).toStringAsFixed(0)}%. '
            'Failures: ${gatedFailures.join('; ')}');
  });
}
