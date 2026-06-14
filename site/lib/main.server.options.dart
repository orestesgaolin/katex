// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/server.dart';
import 'package:site/components/editor.dart' as _editor;
import 'package:site/components/flutter_cell.dart' as _flutter_cell;
import 'package:site/components/katex_js.dart' as _katex_js;
import 'package:site/components/site_nav.dart' as _site_nav;
import 'package:site/components/supported_page.dart' as _supported_page;
import 'package:site/app.dart' as _app;

/// Default [ServerOptions] for use with your Jaspr project.
///
/// Use this to initialize Jaspr **before** calling [runApp].
///
/// Example:
/// ```dart
/// import 'main.server.options.dart';
///
/// void main() {
///   Jaspr.initializeApp(
///     options: defaultServerOptions,
///   );
///
///   runApp(...);
/// }
/// ```
ServerOptions get defaultServerOptions => ServerOptions(
  clientId: 'main.client.dart.js',
  clients: {
    _editor.Editor: ClientTarget<_editor.Editor>(
      'editor',
      params: __editorEditor,
    ),
    _flutter_cell.FlutterCell: ClientTarget<_flutter_cell.FlutterCell>(
      'flutter_cell',
      params: __flutter_cellFlutterCell,
    ),
    _katex_js.KatexJs: ClientTarget<_katex_js.KatexJs>(
      'katex_js',
      params: __katex_jsKatexJs,
    ),
  },
  styles: () => [
    ..._app.App.styles,
    ..._editor.Editor.styles,
    ..._site_nav.SiteNav.styles,
    ..._supported_page.SupportedPage.styles,
  ],
);

Map<String, Object?> __editorEditor(_editor.Editor c) => {
  'initialTex': c.initialTex,
};
Map<String, Object?> __flutter_cellFlutterCell(_flutter_cell.FlutterCell c) => {
  'tex': c.tex,
  'displayMode': c.displayMode,
  'heightPx': c.heightPx,
};
Map<String, Object?> __katex_jsKatexJs(_katex_js.KatexJs c) => {
  'tex': c.tex,
  'displayMode': c.displayMode,
};
