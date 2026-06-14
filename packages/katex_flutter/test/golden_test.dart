/// Self-captured **regression** golden tests for the [Math] widget over the
/// shared KaTeX test gallery (`reference/gallery.json`, 26 entries).
///
/// ## What these goldens are (and are NOT)
/// Each test pumps `Math(tex, displayMode: ...)` at a fixed `fontSize` inside a
/// fixed-size, white-background [RepaintBoundary] and compares the rasterised
/// result against `goldens/<id>.png` via [matchesGoldenFile]. The golden files
/// were produced by THIS test via `flutter test --update-goldens` — i.e. they
/// are **self-captured snapshots of our own renderer**, committed purely to
/// catch *regressions* in our pipeline (parser → box tree → painter).
///
/// They are deliberately NOT the KaTeX reference PNGs in
/// `reference/fixtures/png/<id>.png`. The KaTeX PNGs are the **visual ground
/// truth** for *manual* comparison, but they are not byte-comparable with our
/// output, for two structural reasons established in T-014:
///   1. **Line-box vs ink-box.** KaTeX's browser screenshots include CSS
///      line-height padding around the formula (a "line box"), whereas our
///      widget sizes itself to the *tight ink extent* of the box tree. The
///      canvases therefore have different dimensions and origins.
///   2. **Anti-aliasing / rasteriser differences.** Skia (Flutter) and the
///      browser/Cairo rasteriser that produced the reference PNGs anti-alias
///      glyph edges differently, so even pixel-aligned glyphs differ per-pixel.
/// Holding our output to byte-parity against the KaTeX PNGs is therefore not
/// achievable in the MVP and is intentionally NOT attempted here. The
/// `example/` app (run on a real device) is the primary path for confirming
/// our rendering visually matches KaTeX.
///
/// ## Fonts in the test harness — KNOWN LIMITATION (be honest)
/// The KaTeX glyph fonts are declared as package fonts in `pubspec.yaml`, are
/// bundled into the test asset bundle (verified: `rootBundle.load` returns the
/// real bytes), and are additionally registered via [FontLoader] in
/// [setUpAll]. **Despite this, glyphs do NOT render as real glyphs in the
/// headless `flutter_test` harness — they fall back to solid filled "tofu"
/// boxes.** Filled *rules* (fraction bars, sqrt lines, matrix/`\overline`
/// rules) render correctly, but every character is a black rectangle.
///
/// This is a flutter_test font-rasterisation limitation, not a bug in our
/// renderer: the same `Math` widget renders real KaTeX glyphs on a device/the
/// example app. Consequently these goldens protect **layout/positioning and
/// rule geometry** (each formula's ink boxes land in stable places), but NOT
/// glyph shapes. The `example/` app is the primary path for confirming glyphs
/// match KaTeX visually. Captured-as-is per the ticket; rendering real glyphs
/// in the golden harness is tracked as a follow-up.
///
/// Regenerate goldens after an intentional rendering change with:
/// ```sh
/// flutter test --update-goldens test/golden_test.dart
/// ```
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katex_flutter/katex_flutter.dart';

/// One gallery entry: stable [id], the LaTeX [tex], and [displayMode].
///
/// Kept in sync with `reference/gallery.json` (the source of truth). Mirrored
/// here as a literal so the test has no runtime file-IO dependency on the repo
/// layout above this package.
class _Entry {
  const _Entry(this.id, this.tex, {this.displayMode = false});
  final String id;
  final String tex;
  final bool displayMode;
}

const List<_Entry> _gallery = <_Entry>[
  _Entry('frac-a-b', r'\frac{a}{b}', displayMode: true),
  _Entry('sup-x-2', 'x^2'),
  _Entry('sub-x-i', 'x_i'),
  _Entry('supsub-x-2-i', 'x^2_i'),
  _Entry('sqrt-x', r'\sqrt{x}'),
  _Entry('sqrt-index-3-x', r'\sqrt[3]{x}'),
  _Entry('sum-limits', r'\sum_{i=0}^n i', displayMode: true),
  _Entry('int-limits', r'\int_0^1', displayMode: true),
  _Entry('prod', r'\prod', displayMode: true),
  _Entry('left-right-frac', r'\left(\frac{a}{b}\right)', displayMode: true),
  _Entry('accent-hat-x', r'\hat{x}'),
  _Entry('accent-bar-x', r'\bar{x}'),
  _Entry('accent-vec-x', r'\vec{x}'),
  _Entry('accent-tilde-x', r'\tilde{x}'),
  _Entry('mathbf-x', r'\mathbf{x}'),
  _Entry('mathbb-r', r'\mathbb{R}'),
  _Entry('mathcal-l', r'\mathcal{L}'),
  _Entry('overline-x', r'\overline{x}'),
  _Entry('underline-x', r'\underline{x}'),
  _Entry('greek-alpha-beta', r'\alpha+\beta'),
  _Entry('cdot-a-b', r'a \cdot b'),
  _Entry('text-hi', r'\text{hi}'),
  _Entry(
    'pmatrix',
    r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}',
    displayMode: true,
  ),
  _Entry(
    'bmatrix',
    r'\begin{bmatrix} a & b \\ c & d \end{bmatrix}',
    displayMode: true,
  ),
  _Entry(
    'aligned',
    r'\begin{aligned} a &= b \\ c &= d \end{aligned}',
    displayMode: true,
  ),
  _Entry(
    'cases',
    r'f(x) = \begin{cases} 1 & x > 0 \\ 0 & x \le 0 \end{cases}',
    displayMode: true,
  ),
];

/// Base font size (logical px per em) used for every golden. Fixed so captures
/// are deterministic.
const double _fontSize = 32;

/// Fixed canvas every formula is centered in, so goldens have stable
/// dimensions independent of each formula's intrinsic size.
const Size _canvas = Size(360, 200);

/// Loads every bundled `KaTeX_*` font family into the test font collection so
/// real glyphs render rather than fallback boxes.
Future<void> _loadKatexFonts() async {
  // Families and their asset files, matching this package's pubspec.yaml.
  const families = <String, List<String>>{
    'KaTeX_Main': [
      'fonts/KaTeX_Main-Regular.ttf',
      'fonts/KaTeX_Main-Bold.ttf',
      'fonts/KaTeX_Main-Italic.ttf',
      'fonts/KaTeX_Main-BoldItalic.ttf',
    ],
    'KaTeX_Math': [
      'fonts/KaTeX_Math-Italic.ttf',
      'fonts/KaTeX_Math-BoldItalic.ttf',
    ],
    'KaTeX_AMS': ['fonts/KaTeX_AMS-Regular.ttf'],
    'KaTeX_Size1': ['fonts/KaTeX_Size1-Regular.ttf'],
    'KaTeX_Size2': ['fonts/KaTeX_Size2-Regular.ttf'],
    'KaTeX_Size3': ['fonts/KaTeX_Size3-Regular.ttf'],
    'KaTeX_Size4': ['fonts/KaTeX_Size4-Regular.ttf'],
    'KaTeX_Caligraphic': [
      'fonts/KaTeX_Caligraphic-Regular.ttf',
      'fonts/KaTeX_Caligraphic-Bold.ttf',
    ],
    'KaTeX_Fraktur': [
      'fonts/KaTeX_Fraktur-Regular.ttf',
      'fonts/KaTeX_Fraktur-Bold.ttf',
    ],
    'KaTeX_SansSerif': [
      'fonts/KaTeX_SansSerif-Regular.ttf',
      'fonts/KaTeX_SansSerif-Bold.ttf',
      'fonts/KaTeX_SansSerif-Italic.ttf',
    ],
    'KaTeX_Script': ['fonts/KaTeX_Script-Regular.ttf'],
    'KaTeX_Typewriter': ['fonts/KaTeX_Typewriter-Regular.ttf'],
  };

  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final asset in entry.value) {
      loader.addFont(_loadAsset(asset));
    }
    await loader.load();
  }
}

/// Reads a bundled font asset, preferring the rootBundle (test asset bundle)
/// and falling back to reading the file directly off disk.
Future<ByteData> _loadAsset(String asset) async {
  try {
    return await rootBundle.load(asset);
  } on Object {
    final bytes = await File(asset).readAsBytes();
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }
}

Widget _harness(_Entry e) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.white,
      body: RepaintBoundary(
        child: SizedBox(
          width: _canvas.width,
          height: _canvas.height,
          child: ColoredBox(
            color: Colors.white,
            child: Center(
              child: Math(
                e.tex,
                displayMode: e.displayMode,
                fontSize: _fontSize,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(_loadKatexFonts);

  group('gallery regression goldens (self-captured)', () {
    for (final entry in _gallery) {
      testWidgets(entry.id, (tester) async {
        await tester.binding.setSurfaceSize(_canvas);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_harness(entry));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'render "${entry.tex}"');

        await expectLater(
          find.byType(RepaintBoundary).first,
          matchesGoldenFile('goldens/${entry.id}.png'),
        );
      });
    }
  });
}
