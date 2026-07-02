/// A runnable demo gallery for the `katex` [Math] widget (T-018).
///
/// Renders every entry of the shared KaTeX test gallery
/// (`reference/gallery.json`) in a scrollable list. Each row shows the LaTeX
/// source alongside the rendered [Math] widget so the output can be compared
/// by eye against the KaTeX reference PNGs in `reference/fixtures/png/`.
///
/// Run on a device with `flutter run` from this `example/` directory. Unlike
/// the headless `flutter_test` golden harness (where glyphs fall back to filled
/// boxes), real KaTeX glyphs render here.
library;

import 'package:flutter/material.dart';
import 'package:katex/katex.dart';

void main() => runApp(const KatexGalleryApp());

/// One gallery entry, mirrored from `reference/gallery.json`.
class GalleryEntry {
  const GalleryEntry(this.id, this.tex, {this.displayMode = false});

  /// Stable id, matching the reference fixture file name.
  final String id;

  /// The LaTeX math source.
  final String tex;

  /// Whether to typeset as display math.
  final bool displayMode;
}

/// The full 26-entry gallery (kept in sync with `reference/gallery.json`).
const List<GalleryEntry> kGallery = <GalleryEntry>[
  GalleryEntry('frac-a-b', r'\frac{a}{b}', displayMode: true),
  GalleryEntry('sup-x-2', 'x^2'),
  GalleryEntry('sub-x-i', 'x_i'),
  GalleryEntry('supsub-x-2-i', 'x^2_i'),
  GalleryEntry('sqrt-x', r'\sqrt{x}'),
  GalleryEntry('sqrt-index-3-x', r'\sqrt[3]{x}'),
  GalleryEntry('sum-limits', r'\sum_{i=0}^n i', displayMode: true),
  GalleryEntry('int-limits', r'\int_0^1', displayMode: true),
  GalleryEntry('prod', r'\prod', displayMode: true),
  GalleryEntry(
    'left-right-frac',
    r'\left(\frac{a}{b}\right)',
    displayMode: true,
  ),
  GalleryEntry('accent-hat-x', r'\hat{x}'),
  GalleryEntry('accent-bar-x', r'\bar{x}'),
  GalleryEntry('accent-vec-x', r'\vec{x}'),
  GalleryEntry('accent-tilde-x', r'\tilde{x}'),
  GalleryEntry('mathbf-x', r'\mathbf{x}'),
  GalleryEntry('mathbb-r', r'\mathbb{R}'),
  GalleryEntry('mathcal-l', r'\mathcal{L}'),
  GalleryEntry('overline-x', r'\overline{x}'),
  GalleryEntry('underline-x', r'\underline{x}'),
  GalleryEntry('greek-alpha-beta', r'\alpha+\beta'),
  GalleryEntry('cdot-a-b', r'a \cdot b'),
  GalleryEntry('text-hi', r'\text{hi}'),
  GalleryEntry(
    'pmatrix',
    r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}',
    displayMode: true,
  ),
  GalleryEntry(
    'bmatrix',
    r'\begin{bmatrix} a & b \\ c & d \end{bmatrix}',
    displayMode: true,
  ),
  GalleryEntry(
    'aligned',
    r'\begin{aligned} a &= b \\ c &= d \end{aligned}',
    displayMode: true,
  ),
  GalleryEntry(
    'nablas',
    r'f(x) = \begin{cases} 1 & x > 0 \\ 0 & x \le 0 \end{cases}',
    displayMode: true,
  ),
  GalleryEntry(
    'cases',
    r'\left\{ \begin{array}{l} \nabla\cdot\vec{E} = \rho \\ \nabla\times\vec{B} = \vec{J} \end{array} \right.',
    displayMode: true,
  ),
];

/// The demo app root.
class KatexGalleryApp extends StatelessWidget {
  /// Creates the demo app.
  const KatexGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'katex gallery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      home: const GalleryPage(),
    );
  }
}

/// The scrollable gallery list page.
class GalleryPage extends StatelessWidget {
  /// Creates the gallery page.
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('katex gallery')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _RichTextDemo(),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: kGallery.length,
              separatorBuilder: (_, __) => const Divider(height: 32),
              itemBuilder: (context, index) =>
                  _GalleryRow(entry: kGallery[index]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Demonstrates **inline math in rich text**: `Math` typeset inline within a
/// paragraph via [mathSpan] in a `Text.rich`, baseline-aligned with the prose.
class _RichTextDemo extends StatelessWidget {
  const _RichTextDemo();

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      fontSize: 16,
      height: 1.7,
      color: Colors.black87,
    );
    return Container(
      width: double.infinity,
      color: const Color(0xFFF7F9FC),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inline math in rich text',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: textStyle,
              children: [
                const TextSpan(text: 'The quadratic formula '),
                mathSpan(r'x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}'),
                const TextSpan(text: ' gives the roots of '),
                mathSpan('ax^2 + bx + c = 0'),
                const TextSpan(text: '. Euler’s identity '),
                mathSpan(r'e^{i\pi} + 1 = 0'),
                const TextSpan(text: ' ties together '),
                mathSpan('e'),
                const TextSpan(text: ', '),
                mathSpan('i'),
                const TextSpan(text: ', and '),
                mathSpan(r'\pi'),
                const TextSpan(text: '. A sum like '),
                mathSpan(r'\sum_{i=1}^{n} i = \tfrac{n(n+1)}{2}'),
                const TextSpan(
                  text: ' flows inline with the text, on the baseline.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryRow extends StatelessWidget {
  const _GalleryRow({required this.entry});

  final GalleryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                entry.tex,
                style: const TextStyle(
                  fontFamily: 'MesloLGS NF',
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
            ),
            if (entry.displayMode)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Chip(
                  label: Text('display', style: TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Math(
            entry.tex,
            displayMode: entry.displayMode,
            fontSize: 28,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
