# T-013 — CLI `bin/katex.dart`

**Milestone:** M4  **Status:** review  **Depends on:** T-011, T-012

## Goal
A small CLI that renders TeX to SVG on stdout.

## Scope
- `packages/katex/bin/katex.dart` — `dart run katex "\frac{a}{b}" [--display] [-o out.svg]`.
  Flags: `--display`/`-d` (displayMode), `--output`/`-o`, `--font-size`, `--color`,
  `--help`. Reads the single positional TeX arg, prints SVG to stdout or writes to `-o`.
- Exit non-zero with a readable message on parse error.

## Acceptance criteria
- `dart run katex "\\frac{a}{b}"` prints valid SVG to stdout.
- `--display` toggles display mode; `-o file` writes the file.
- `test/cli_test.dart` runs the CLI via `Process.run` and asserts valid SVG / exit codes.
