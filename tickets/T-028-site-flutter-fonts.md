# T-028 — Site Flutter column rendered with wrong font (asset base 404)

**Milestone:** M7 (site)  **Status:** done  **Depends on:** T-024

## Problem (user-reported)
In the comparison site, the embedded `katex_flutter` column rendered with the wrong font and
was misaligned — the Math widgets fell back to a non-KaTeX font (wrong glyph metrics → wrong
widths → misalignment).

## Root cause
The fonts ARE bundled in the Flutter web build
(`site/web/flutter/assets/packages/katex_flutter/fonts/KaTeX_*.ttf` + `FontManifest.json`), but
the multi-view embed bootstrap (`site/web/flutter_embed.js`) set only `entrypointBaseUrl` and
`canvasKitBaseUrl` to `flutter/`, NOT `assetBase`. The Jaspr page is served at `/`, so the
engine fetched `assets/FontManifest.json` + fonts from the page root (`/assets/...`) → **404**
→ fallback font.

## Fix
Add `assetBase: "flutter/"` to the loader `config` in `flutter_embed.js` so runtime asset loads
(FontManifest, AssetManifest, fonts) resolve under `flutter/assets/`.

## Resolution
`/flutter/assets/FontManifest.json` and the bundled `KaTeX_*` fonts now return **200**.
Headless-Chrome screenshot of the served site confirms the Flutter column renders with the
correct KaTeX fonts, sized/aligned with the KaTeX-JS column across the gallery (verified
`a/b`, `n/k`, `x^2`, `x_i`, `{}^nC_k`, primes). The site's embedded Flutter build was also
rebuilt to pick up T-027 (painter skew fix). `dart analyze` (site) + `flutter analyze`
(flutter_host) clean. Generated `site/web/flutter/` stays gitignored; only `flutter_embed.js`
changed in git.
