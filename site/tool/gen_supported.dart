// Generator for `lib/supported_data.dart` (T-037).
//
// Parses KaTeX's by-category documentation (`docs/supported.md`) into an
// ordered, categorized list of renderable TeX commands/symbols and emits a
// `const` Dart data file. Run ONCE and commit the OUTPUT — the generated
// `supported_data.dart` is what the site depends on, not this script.
//
// Usage (from the `site/` directory):
//   curl -sL https://raw.githubusercontent.com/KaTeX/KaTeX/main/docs/supported.md \
//     -o /tmp/supported.md
//   dart run tool/gen_supported.dart /tmp/supported.md > lib/supported_data.dart
//
// Parsing model
// -------------
// The markdown groups commands under `##` (category) and `###` (subcategory)
// headings, plus bold `**Subcategory**` / italic `***Subcategory***` labels.
// Commands live in markdown tables whose cells look like:
//
//     | $\tilde{a}$ `\tilde{a}` | ... |
//
// i.e. a `$...$` "rendered" segment followed by a backtick `source` segment.
// For each cell we take the FIRST `$...$` content as the renderable `tex`,
// falling back to the backtick source (the bare command) when there is no
// math segment. Cells that carry neither — pure prose, comments like
// `% comment`, or empty separators — are skipped.
import 'dart:io';

/// A parsed entry: a renderable command/symbol within a category.
class _Entry {
  _Entry(this.category, this.subcategory, this.name, this.tex);

  final String category;
  final String? subcategory;

  /// Human-facing label for the command column (the source/command text).
  final String name;

  /// The renderable LaTeX (math segment, or the command itself).
  final String tex;
}

/// Matches a markdown table data row (starts with `|`, not a separator like
/// `|:---|`).
final RegExp _sepRow = RegExp(r'^\s*\|?[\s:|-]*\|?\s*$');

/// First `$...$` (non-greedy) math segment in a cell. Allows escaped `\$`
/// inside the segment so literal dollar signs (e.g. `$\$$`) survive.
final RegExp _mathSeg = RegExp(r'\$((?:\\.|[^$])+?)\$');

/// Backtick `source` segment (single or doubled backticks).
final RegExp _backtick = RegExp(r'`([^`]+)`');

/// `<code>...</code>` segment (used when the source contains backticks).
final RegExp _codeTag = RegExp(r'<code>(.*?)</code>', dotAll: true);

void main(List<String> args) {
  final path = args.isNotEmpty ? args.first : '/tmp/supported.md';
  final lines = File(path).readAsLinesSync();

  final entries = <_Entry>[];
  final seen = <String>{}; // de-dupe identical (category, tex) pairs.

  String? category;
  String? subcategory;

  for (final raw in lines) {
    final line = raw.trimRight();

    // Category / subcategory headings.
    final h2 = RegExp(r'^##\s+(.+?)\s*$').firstMatch(line);
    if (h2 != null && !line.startsWith('###')) {
      category = _stripInline(h2.group(1)!);
      subcategory = null;
      continue;
    }
    final h3 = RegExp(r'^###\s+(.+?)\s*$').firstMatch(line);
    if (h3 != null) {
      subcategory = _stripInline(h3.group(1)!);
      continue;
    }
    // Bold / italic inline subheadings: **Foo**, ***Foo***.
    final bold = RegExp(r'^\*{2,3}(.+?)\*{2,3}\s*$').firstMatch(line);
    if (bold != null) {
      subcategory = _stripInline(bold.group(1)!);
      continue;
    }

    if (category == null) continue;
    if (!line.contains('|')) continue;
    if (_sepRow.hasMatch(line)) continue;

    // Split the row into cells on unescaped pipes.
    final cells = _splitCells(line);
    for (final cell in cells) {
      final parsed = _parseCell(cell);
      if (parsed == null) continue;
      final (name, tex) = parsed;
      final key = '$category::$subcategory::$tex';
      if (!seen.add(key)) continue;
      entries.add(_Entry(category, subcategory, name, tex));
    }
  }

  stdout.write(_emit(entries));
  stderr.writeln('Parsed ${entries.length} entries across '
      '${entries.map((e) => e.category).toSet().length} categories.');
}

/// Splits a markdown table row into cell strings, dropping the leading/trailing
/// empty cells produced by the bounding pipes. Honors `\|` escaping.
List<String> _splitCells(String line) {
  final cells = <String>[];
  final buf = StringBuffer();
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == r'\' && i + 1 < line.length) {
      buf.write(ch);
      buf.write(line[i + 1]);
      i++;
      continue;
    }
    if (ch == '|') {
      cells.add(buf.toString());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  cells.add(buf.toString());
  // Drop empty bounding cells.
  if (cells.isNotEmpty && cells.first.trim().isEmpty) cells.removeAt(0);
  if (cells.isNotEmpty && cells.last.trim().isEmpty) cells.removeLast();
  return cells;
}

/// Parses one table cell into `(name, tex)` or null if it carries no
/// renderable command. `tex` is the first `$...$` math segment, falling back
/// to the backtick/`<code>` source. `name` is the human-facing command label.
(String, String)? _parseCell(String cell) {
  var c = cell.trim();
  if (c.isEmpty) return null;

  // Strip <br> and surrounding tilde-padding artifacts used for alignment.
  c = c.replaceAll(RegExp(r'<br\s*/?>'), ' ');

  // Pull the source/command label: prefer <code>…</code>, else first backtick.
  String? source;
  final codeM = _codeTag.firstMatch(c);
  if (codeM != null) {
    source = _decodeEntities(codeM.group(1)!.trim());
  } else {
    final btM = _backtick.firstMatch(c);
    if (btM != null) source = btM.group(1)!.trim();
  }

  // Pull the renderable math segment (first $...$), ignoring pure spacing
  // segments like `$~~~~$` used only for layout.
  String? tex;
  for (final m in _mathSeg.allMatches(c)) {
    final inner = m.group(1)!.trim();
    if (inner.isEmpty) continue;
    if (RegExp(r'^~+$').hasMatch(inner)) continue; // spacing-only
    tex = inner;
    break;
  }

  tex ??= source; // fall back to the bare command.
  if (tex == null) return null;
  tex = tex.trim();
  if (tex.isEmpty) return null;

  // Skip pure comments / non-renderable prose.
  if (tex.startsWith('%')) return null;

  final name = (source ?? tex).trim();
  if (name.isEmpty) return null;
  return (name, tex);
}

/// Removes markdown links/inline formatting from heading text.
String _stripInline(String s) {
  var out = s;
  out = out.replaceAll(RegExp(r'\\'), '');
  out = out.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^)]*\)'),
    (m) => m.group(1)!,
  );
  out = out.replaceAll(RegExp(r'[`*]'), '');
  return out.trim();
}

/// Decodes the handful of HTML entities used in the doc cells.
String _decodeEntities(String s) => s
    .replaceAll('&#124;', '|')
    .replaceAll('&#92;', r'\')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"');

/// Emits the generated Dart source.
String _emit(List<_Entry> entries) {
  final b = StringBuffer();
  b.writeln('// GENERATED FILE — DO NOT EDIT BY HAND.');
  b.writeln('//');
  b.writeln('// Produced by `tool/gen_supported.dart` from KaTeX\'s');
  b.writeln('// `docs/supported.md` (mirrors https://katex.org/docs/supported).');
  b.writeln('// Regenerate with:');
  b.writeln('//   dart run tool/gen_supported.dart <supported.md> > lib/supported_data.dart');
  b.writeln('//');
  b.writeln('// Each entry is a renderable TeX command/symbol in KaTeX category');
  b.writeln('// order. `tex` is the renderable LaTeX (the `\$...\$` segment of the');
  b.writeln('// doc\'s "rendered" cell, falling back to the bare command).');
  b.writeln('library;');
  b.writeln();
  b.writeln('/// A single catalog entry: one renderable TeX command/symbol.');
  b.writeln('class SupportedEntry {');
  b.writeln('  const SupportedEntry(this.category, this.subcategory, this.name, this.tex);');
  b.writeln();
  b.writeln('  /// Top-level KaTeX category (e.g. `Accents`, `Operators`).');
  b.writeln('  final String category;');
  b.writeln();
  b.writeln('  /// Optional subcategory within the category (e.g. `Big Operators`).');
  b.writeln('  final String? subcategory;');
  b.writeln();
  b.writeln('  /// Human-facing command label (the source text shown in the code column).');
  b.writeln('  final String name;');
  b.writeln();
  b.writeln('  /// The renderable LaTeX math source.');
  b.writeln('  final String tex;');
  b.writeln('}');
  b.writeln();
  b.writeln('/// The full catalog of KaTeX commands/symbols, in documentation order.');
  b.writeln('const List<SupportedEntry> kSupportedEntries = <SupportedEntry>[');
  for (final e in entries) {
    final cat = _dartStr(e.category);
    final sub = e.subcategory == null ? 'null' : _dartStr(e.subcategory!);
    final name = _dartStr(e.name);
    final tex = _dartStr(e.tex);
    b.writeln('  SupportedEntry($cat, $sub, $name, $tex),');
  }
  b.writeln('];');
  return b.toString();
}

/// Emits a Dart string literal. Uses a raw single-quoted literal when possible
/// (TeX is backslash-heavy); falls back to an escaped literal otherwise.
String _dartStr(String s) {
  if (!s.contains("'") && !s.contains(r'$') && !s.contains('\n')) {
    return "r'$s'";
  }
  final esc = s
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n');
  return "'$esc'";
}
