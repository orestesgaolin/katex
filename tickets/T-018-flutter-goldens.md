# T-018 — Flutter golden tests + example app

**Milestone:** M5  **Status:** review  **Depends on:** T-002, T-017

## Goal
Hold the widget to original-KaTeX output and provide a runnable demo.

## Scope
- `test/golden_test.dart` — `matchesGoldenFile` over the gallery. Where feasible, use the
  KaTeX `reference/fixtures/png/<id>.png` as the golden (documenting DPR/size alignment);
  otherwise self-capture goldens but add a comparison note vs the KaTeX PNG.
- `example/` — runnable Flutter app rendering the full gallery in a scrollable list for
  manual visual review (`flutter run`).

## Acceptance criteria
- `flutter test` golden tests run over the gallery (pass within tolerance, or list known
  diffs as follow-up tickets — no silent skips).
- `example/` builds and runs (`flutter run -d <device>` / `flutter build` smoke).
- A note documents how goldens relate to the KaTeX reference PNGs.
