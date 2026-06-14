# T-001 — Repo scaffold, CI, licenses

**Milestone:** M1  **Status:** done  **Depends on:** —  **Owner:** orchestrator

## Goal
Stand up the standalone repo skeleton: two package shells, reference dir, CI, licenses,
.gitignore, README.

## Scope
- `packages/katex/` with `pubspec.yaml` (name `katex`, sdk `^3.11`, dev_dep `test`,
  `lints`/`very_good_analysis`), `analysis_options.yaml`, `lib/katex.dart` barrel stub,
  `lib/src/{parse,ast,symbols,font,build,box,svg}/` dirs, `bin/katex.dart` stub,
  `assets/fonts/`, `test/`.
- `packages/katex_flutter/` with `pubspec.yaml` (flutter pkg, `katex` path dep),
  `lib/katex_flutter.dart` stub, `example/` placeholder, `test/`.
- `reference/` with `package.json` (katex + puppeteer + pngjs/pixelmatch), `pin.json`.
- `.github/workflows/katex.yml` and `katex_flutter.yml`.
- Root `README.md`, MIT `LICENSE`, `.gitignore`.

## Acceptance criteria
- `dart pub get` succeeds in `packages/katex`.
- `dart analyze` runs clean (empty/stub code) in `packages/katex`.
- Directory structure matches PLAN.md.
- CI workflow files present and syntactically valid YAML.
