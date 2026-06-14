/// Builds a pre-filled GitHub "new issue" URL for reporting a rendering bug
/// against a specific TeX example.
///
/// The returned URL targets the `orestesgaolin/katex` repo's new-issue form
/// with a `render-bug` label and a templated title/body. Both the title and
/// the body are percent-encoded with [Uri.encodeQueryComponent], so tricky
/// TeX (backslashes, braces, etc.) survives the round-trip into the form.
library;

/// The GitHub repo slug used for filed issues.
const String _kRepoSlug = 'orestesgaolin/katex';

/// Maximum number of TeX characters shown inline in the issue title before it
/// is truncated with an ellipsis.
const int _kTitleTexMax = 60;

/// Returns a `https://github.com/orestesgaolin/katex/issues/new?...` URL with
/// the title and body pre-filled for the given [tex] and [displayMode].
String ghIssueUrl(String tex, {required bool displayMode}) {
  final truncated = tex.length > _kTitleTexMax
      ? '${tex.substring(0, _kTitleTexMax)}…'
      : tex;
  final title = 'Rendering issue: $truncated';
  final body = '''
**TeX input:**
```
$tex
```
Display mode: $displayMode

**What looks wrong:** (describe — e.g. SVG vs KaTeX vs Flutter)

_Filed from the comparison site._''';

  final encodedTitle = Uri.encodeQueryComponent(title);
  final encodedBody = Uri.encodeQueryComponent(body);
  return 'https://github.com/$_kRepoSlug/issues/new'
      '?title=$encodedTitle&body=$encodedBody&labels=render-bug';
}
