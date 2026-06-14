# T-035 — Publishing prep: pub.dev metadata + GH issue button + Pages deploy

**Milestone:** M7  **Status:** done  **Depends on:** T-024  **Repo:** orestesgaolin/katex

## Done
- **git remote** `origin` = `git@github.com:orestesgaolin/katex.git`.
- **pub.dev metadata** (both packages): `description`, `repository`, `homepage`, `issue_tracker`,
  `topics`, version `0.1.0`, per-package `README.md` + `CHANGELOG.md` + `LICENSE`.
- **Issue button**: `site/lib/components/gh_issue.dart` builds a prefilled new-issue URL
  (`orestesgaolin/katex/issues/new`, `render-bug` label, TeX + display-mode in the body,
  URL-encoded). A "⚠ report" link on every comparison row + a "report this input" link in the
  live editor. Plain server-rendered anchors (no JS). Verified: 69 links in the built HTML.
- **GitHub Pages workflow** `.github/workflows/pages.yml`: on push to `main` (site/** or
  packages/**) + manual dispatch, builds the Jaspr static site + embedded Flutter and deploys via
  `actions/deploy-pages`. Project-page sub-path `/katex/` handled natively via Jaspr's
  `Document(base:)` + a `BASE_HREF` dart-define (`jaspr build --dart-define BASE_HREF=/katex/`),
  defaulting to `/` for local `jaspr serve`. Clean build + `.nojekyll`. Verified in a real browser
  under the `/katex/` sub-path: 0 asset 404s; KaTeX-JS, Dart-SVG, AND embedded-Flutter columns all
  render (engine + fonts load under /katex/).
- Root `README.md`: live-demo link + pub.dev-name note.

## ⚠️ Blocker for actual publishing — names are taken on pub.dev
- `katex` → already published (0.1.0, different author).
- `katex_flutter` → already published (4.0.2, established package).
Both kept `publish_to: none` (with a note). **Publishing requires renaming** (e.g. `katex_dart`
+ a free Flutter name) — pending a user decision. The site (the public artifact) is unaffected.

## User action required (one-time)
GitHub repo → **Settings → Pages → Source → GitHub Actions**. Then pushes to `main` deploy to
<https://orestesgaolin.github.io/katex/>.

## Gates
katex 297 tests, katex_flutter 60 tests, site analyze + `jaspr build` clean. Monorepo build was
briefly broken by an initial hosted-dep experiment on `katex_flutter`; reverted to the path dep.
