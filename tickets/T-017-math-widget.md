# T-017 — Public Math widget API

**Milestone:** M5  **Status:** review  **Depends on:** T-016

## Goal
The public widget users embed.

## Scope
- `lib/src/math_widget.dart` — `Math(String tex, {bool displayMode, double? fontSize,
  Color? color, MathStyle? style, Widget Function(BuildContext, Object error)? onError})`.
  Parses via `katex.renderToBox` once, holds the tree, paints via the T-016 painter.
- Error handling honoring `throwOnError`/`onError`.
- Export from `lib/katex_flutter.dart`.

## Acceptance criteria
- `flutter analyze` clean.
- `Math(r'\frac{a}{b}')` builds and renders in a widget test without error.
- `onError` builder is invoked for invalid TeX when `throwOnError` is false.
- `test/math_widget_test.dart` passes.
