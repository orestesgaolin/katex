/// SITE-2 — the live editor at the top of the page.
///
/// A `@client` island: a text field (plus a display-mode toggle) drives three
/// live renderers side by side for whatever the user types —
/// **KaTeX JS** (`katex.render`), **katex Dart SVG** (client-side
/// `renderToSvg` via [renderLeanScaledSvg] — `package:katex` is pure Dart and
/// already in the `@client` bundle), and **katex_flutter** (a
/// `FlutterEmbedView` hosting [mathCellWidget], rebuilt on each input).
///
/// Input is debounced (~250 ms). Parse errors are caught per-renderer and shown
/// inline — a bad expression never crashes the page.
library;

import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_flutter_embed/jaspr_flutter_embed.dart';
import 'package:universal_web/js_interop.dart';
import 'package:universal_web/web.dart' as web;

import 'dart_svg.dart';
import 'gh_issue.dart';
import 'math_cell_builder.dart';

/// The global `katex` object exposed by the vendored `katex.min.js`.
@JS('katex')
external _Katex? get _katex;

extension type _Katex._(JSObject _) implements JSObject {
  external void render(JSString tex, web.Element element, _KatexOptions options);
}

@JS()
@anonymous
extension type _KatexOptions._(JSObject _) implements JSObject {
  external factory _KatexOptions({
    JSBoolean displayMode,
    JSBoolean throwOnError,
  });
}

/// Debounce window for input → re-render.
const Duration _kDebounce = Duration(milliseconds: 250);

/// The live LaTeX editor. Renders the typed expression three ways as you type.
@client
class Editor extends StatefulComponent {
  const Editor({this.initialTex = r'\frac{1}{2} + \sqrt{x^2 + 1}', super.key});

  /// Seed expression shown on first paint.
  final String initialTex;

  @override
  State<Editor> createState() => _EditorState();

  @css
  static List<StyleRule> get styles => [
        css('.editor', [
          css('&').styles(
            padding: Padding.all(20.px),
            margin: Margin.only(bottom: 28.px),
            border: Border.all(color: const Color('#ddd'), width: 1.px),
            radius: BorderRadius.circular(8.px),
            backgroundColor: const Color('#fcfcfc'),
          ),
          css('h2').styles(margin: Margin.only(top: .zero, bottom: 4.px), fontSize: 1.3.rem),
          css('.editor-hint').styles(
            margin: Margin.only(top: .zero, bottom: 12.px),
            color: const Color('#555'),
            fontSize: 0.85.rem,
          ),
          css('.editor-controls').styles(
            display: Display.flex,
            margin: Margin.only(bottom: 16.px),
            flexWrap: FlexWrap.wrap,
            alignItems: AlignItems.center,
            gap: Gap.all(12.px),
          ),
          css('.editor-input', [
            css('&').styles(
              padding: Padding.symmetric(horizontal: 10.px, vertical: 8.px),
              border: Border.all(color: const Color('#bbb'), width: 1.px),
              radius: BorderRadius.circular(6.px),
              flex: Flex(grow: 1, shrink: 1, basis: 260.px),
              fontFamily: const FontFamily.list([
                FontFamily('SFMono-Regular'),
                FontFamily('Menlo'),
                FontFamilies.monospace,
              ]),
              fontSize: 0.95.rem,
            ),
          ]),
          css('.editor-toggle').styles(
            display: Display.flex,
            userSelect: UserSelect.none,
            alignItems: AlignItems.center,
            color: const Color('#333'),
            fontSize: 0.85.rem,
          ),
          // Three side-by-side preview cells (collapse to a column when narrow).
          css('.editor-outputs').styles(
            display: Display.grid,
            gridTemplate: GridTemplate(
              columns: GridTracks([
                GridTrack(TrackSize.fr(1)),
                GridTrack(TrackSize.fr(1)),
                GridTrack(TrackSize.fr(1)),
              ]),
            ),
            gap: Gap.all(12.px),
          ),
          css('.editor-cell', [
            css('&').styles(
              display: Display.flex,
              border: Border.all(color: const Color('#e3e3e3'), width: 1.px),
              radius: BorderRadius.circular(6.px),
              overflow: Overflow.hidden,
              flexDirection: FlexDirection.column,
            ),
            css('.editor-cell-head').styles(
              padding: Padding.symmetric(horizontal: 8.px, vertical: 4.px),
              color: const Color('#555'),
              fontSize: 0.72.rem,
              fontWeight: FontWeight.bold,
              textTransform: TextTransform.upperCase,
              backgroundColor: const Color('#f3f3f3'),
            ),
            css('.editor-cell-body').styles(
              display: Display.flex,
              position: const Position.relative(),
              minHeight: 96.px,
              padding: Padding.all(10.px),
              justifyContent: JustifyContent.center,
              alignItems: AlignItems.center,
              backgroundColor: const Color('#fafafa'),
            ),
            // The Flutter embed host must fill the cell so its view gets a real
            // height (same chain as the comparison rows' .flutter-cell).
            css('.editor-cell-body > *').styles(
              width: 100.percent,
              height: 100.percent,
              minHeight: 96.px,
            ),
          ]),
        ]),
      ];
}

class _EditorState extends State<Editor> {
  late String _tex = component.initialTex;
  bool _displayMode = true;
  Timer? _debounce;

  // The KaTeX-JS render targets a real DOM node we own.
  final GlobalNodeKey<web.HTMLElement> _jsHostKey = GlobalNodeKey();

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      Future<void>.microtask(_renderJs);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onInput(String value) {
    _debounce?.cancel();
    _debounce = Timer(_kDebounce, () {
      setState(() => _tex = value);
      _renderJs();
    });
  }

  void _toggleDisplay(bool value) {
    setState(() => _displayMode = value);
    _renderJs();
  }

  /// (Re)render the KaTeX-JS preview into the host node imperatively, since
  /// `katex.render` writes raw DOM that Jaspr does not manage.
  void _renderJs() {
    if (!kIsWeb) {
      return;
    }
    final host = _jsHostKey.currentNode;
    final katex = _katex;
    if (host == null || katex == null) {
      // katex.min.js may not have loaded yet; retry shortly.
      Future<void>.delayed(const Duration(milliseconds: 50), _renderJs);
      return;
    }
    try {
      katex.render(
        _tex.toJS,
        host,
        _KatexOptions(
          displayMode: _displayMode.toJS,
          throwOnError: false.toJS,
        ),
      );
    } on Object catch (error) {
      host.textContent = 'KaTeX JS error: $error';
    }
  }

  /// The client-side Dart-SVG preview (caught so a parse error shows inline).
  Component _svgPreview() {
    String svg;
    try {
      svg = renderLeanScaledSvg(_tex, displayMode: _displayMode);
    } on Object catch (error) {
      return div(classes: 'render-error', [.text('Dart SVG error: $error')]);
    }
    return div(classes: 'dart-svg', [RawText(svg)]);
  }

  @override
  Component build(BuildContext context) {
    return section(classes: 'editor', [
      h2([.text('Live editor')]),
      p(classes: 'editor-hint', [
        .text('Type a LaTeX expression — it renders live in all three '),
        .text('renderers below.'),
      ]),
      div(classes: 'editor-controls', [
        input<String>(
          type: InputType.text,
          classes: 'editor-input',
          value: _tex,
          attributes: const {
            'spellcheck': 'false',
            'autocapitalize': 'off',
            'autocomplete': 'off',
            'aria-label': 'LaTeX expression',
          },
          onInput: _onInput,
        ),
        label(classes: 'editor-toggle', [
          input<bool>(
            type: InputType.checkbox,
            checked: _displayMode,
            onChange: _toggleDisplay,
          ),
          .text(' display mode'),
        ]),
        a(
          classes: 'issue-link',
          href: ghIssueUrl(_tex, displayMode: _displayMode),
          target: Target.blank,
          attributes: const {
            'rel': 'noopener',
            'title': 'Report a rendering issue with this input',
          },
          [.text('⚠ report issue with this input')],
        ),
      ]),
      div(classes: 'editor-outputs', [
        _outputCell('KaTeX JS', div(key: _jsHostKey, classes: 'katex-js', [])),
        _outputCell('katex Dart SVG', _svgPreview()),
        _outputCell(
          'katex_flutter',
          FlutterEmbedView(
            // Keyed by the rendered string + mode so the embedded view rebuilds
            // its widget whenever the input changes.
            key: ValueKey<String>('$_displayMode|$_tex'),
            widget: mathCellWidget(_tex, displayMode: _displayMode),
            loader: div(classes: 'flutter-loading', const []),
          ),
        ),
      ]),
    ]);
  }

  Component _outputCell(String title, Component child) {
    return div(classes: 'editor-cell', [
      div(classes: 'editor-cell-head', [.text(title)]),
      div(classes: 'editor-cell-body', [child]),
    ]);
  }
}
