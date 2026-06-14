# T-030 — Site Flutter column via jaspr_flutter_embed (fix disappear-on-click)

**Milestone:** M7 (site)  **Status:** done  **Depends on:** T-029

## Problem (user-reported)
With per-row `<iframe>`s (T-029), the Flutter cells **disappeared on click/scroll**. Cause:
68 iframes each hold a WebGL context; Chrome caps simultaneous contexts (~16), so engines get
evicted and those cells blank. The user asked for proper Jaspr embedding instead.

## Migration (fork agent, commit 4af404d)
Switched column 4 to **`jaspr_flutter_embed`** — `jaspr: flutter: embedded` + one shared
Flutter engine with one embedded `FlutterEmbedView` per cell (no context exhaustion; each view
is its own grid cell). Web-only conditional import so the static prerender never imports
`package:flutter`. Removed the per-row iframe `flutter_host/` app.

## Two follow-up bugs found + fixed (orchestrator, verified in real headful Chrome)
The migration built but the column was **blank** in the browser. Diagnosed via headful Chrome +
CDP (`window._flutter` undefined, 0 views, 68× "Unexpected null value"; then views mounted but
`flutter-view` was 249×**0**):
1. **Bootstrap not loaded** — jaspr does NOT auto-inject the engine bootstrap. Added
   `script(src: 'flutter_bootstrap.js', async: true)` to `main.server.dart`'s `Document` head.
2. **Zero-height views** — `.flutter-cell` inherited `.cmp-cell`'s flex-centering, collapsing the
   embed host so `height:100%` never resolved → `flutter-view` 0px tall. Made `.flutter-cell` a
   `display:block` cell whose child fills the grid-stretched row height (`app.dart`).

## Key finding (answers the user's question)
The CanvasKit **multi-view glyph drop was NOT fundamental** — it was the earlier *hand-rolled*
bootstrap. With the standard `flutter_bootstrap.js`, `jaspr_flutter_embed`'s multi-view renders
**all** previously-missing glyphs. So the skwasm-renderer fallback is **not needed**.

## Verification (real headful Chrome via CDP, this machine)
- `_flutter` defined, **68 views mounted**, 0 page errors.
- katex_flutter column renders, correct KaTeX fonts, aligned per row across the whole gallery.
- Previously-tofu glyphs now render: `⟨x,y⟩`, `⌈x⌉+⌊y⌋`, nested `([{⟨x⟩}])`, `\oint`/`\bigcup`,
  `∑`/`∫`, `√`, accents.
- One shared engine → no WebGL-context exhaustion → **no disappear-on-click**.
- `dart analyze` (site) clean.

Run: `cd site && flutter pub get && jaspr serve` → http://localhost:8080 (real browser).
