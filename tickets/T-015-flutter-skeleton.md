# T-015 — katex_flutter skeleton + font bundling

**Milestone:** M5  **Status:** review  **Depends on:** T-001, T-009

## Goal
Flutter package shell that depends on `katex` and bundles the KaTeX fonts.

## Scope
- `packages/katex_flutter/pubspec.yaml` — Flutter package; `dependencies: katex:
  {path: ../katex}`; declare every vendored KaTeX `.ttf` under `flutter: fonts:` with the
  correct family names (KaTeX_Main, KaTeX_Math, KaTeX_AMS, KaTeX_Size1..4, KaTeX_Caligraphic,
  KaTeX_Fraktur, KaTeX_SansSerif, KaTeX_Script, KaTeX_Typewriter), incl. bold/italic variants.
- Copy/reference the fonts into the Flutter package asset path (fonts can live in
  `packages/katex_flutter/fonts/` to satisfy Flutter asset bundling).
- `lib/katex_flutter.dart` barrel stub; `lib/src/font_mapping.dart` mapping
  box `FontFamily`+`FontVariant`+size → Flutter `TextStyle` (family name + weight/style).

## Acceptance criteria
- `flutter pub get` succeeds in `packages/katex_flutter`.
- `flutter analyze` clean.
- Font family declarations match the KaTeX glyph families the metrics reference.
