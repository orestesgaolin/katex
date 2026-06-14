# katex_flutter

A Flutter widget that renders LaTeX math by painting the backend-agnostic box
tree produced by the pure-Dart [`katex`](../katex) package. There is no
re-parsing during paint — the widget is a pure consumer of the box tree.

## Usage

```dart
import 'package:katex_flutter/katex_flutter.dart';

// Inline math (default).
Math(r'\frac{a}{b}')

// Display math, with an explicit size and color.
Math(
  r'\sum_{i=0}^{n} i',
  displayMode: true,
  fontSize: 28,
  color: Colors.indigo,
)
```

`Math(String tex, {bool displayMode = false, double? fontSize, Color? color,
Widget Function(BuildContext, Object)? onError, bool throwOnError = false})`:

- `fontSize` is the base size in **logical pixels per em** (default `20`). The
  widget sizes itself to the tight ink extent of the rendered formula.
- On a parse/build error: rethrows if `throwOnError`, else uses `onError`, else
  shows the raw source in KaTeX error-red. The widget tree never crashes.

The bundled KaTeX glyph fonts (SIL OFL) are declared as package fonts, so no
font setup is required by consumers.

## Example app

See [`example/`](example) for a runnable gallery rendering all 26 expressions
from the shared test gallery. Run on a device with:

```sh
cd example && flutter run
```

## Goldens

`test/golden_test.dart` holds the widget to **self-captured regression
goldens** in `test/goldens/<id>.png`, one per gallery entry. Regenerate after an
intentional rendering change with:

```sh
flutter test --update-goldens test/golden_test.dart
```

### Relationship to the KaTeX reference PNGs

The KaTeX reference PNGs in `reference/fixtures/png/<id>.png` are the **visual
ground truth** for *manual* comparison (see the example app), but they are
**not** used as byte-comparable golden files, for two reasons established in
T-014:

1. **Line-box vs ink-box.** KaTeX's browser screenshots include CSS
   line-height padding (a line box); our widget sizes to the tight ink extent.
   The canvases differ in size and origin.
2. **Anti-aliasing.** Skia and the browser rasteriser anti-alias glyph edges
   differently, so even aligned glyphs differ per-pixel.

Pixel-parity with KaTeX is therefore **not** claimed or tested in the MVP.

### Known limitation: glyphs in the golden harness

In the headless `flutter_test` harness, KaTeX glyphs currently fall back to
solid filled boxes (filled *rules* — fraction bars, sqrt/overline lines —
render correctly). Real glyphs do render on a device / in the example app, which
is the primary visual-confirmation path. The goldens therefore protect
layout/positioning and rule geometry, not glyph shapes. Rendering real glyphs in
the golden harness is a follow-up.
