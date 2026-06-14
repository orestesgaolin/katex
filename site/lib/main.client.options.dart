// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/client.dart';

import 'package:site/components/editor.dart' deferred as _editor;
import 'package:site/components/flutter_cell.dart' deferred as _flutter_cell;
import 'package:site/components/katex_js.dart' deferred as _katex_js;

/// Default [ClientOptions] for use with your Jaspr project.
///
/// Use this to initialize Jaspr **before** calling [runApp].
///
/// Example:
/// ```dart
/// import 'main.client.options.dart';
///
/// void main() {
///   Jaspr.initializeApp(
///     options: defaultClientOptions,
///   );
///
///   runApp(...);
/// }
/// ```
ClientOptions get defaultClientOptions => ClientOptions(
  clients: {
    'editor': ClientLoader(
      (p) => _editor.Editor(initialTex: p['initialTex'] as String),
      loader: _editor.loadLibrary,
    ),
    'flutter_cell': ClientLoader(
      (p) => _flutter_cell.FlutterCell(
        tex: p['tex'] as String,
        displayMode: p['displayMode'] as bool,
        heightPx: p['heightPx'] as int,
      ),
      loader: _flutter_cell.loadLibrary,
    ),
    'katex_js': ClientLoader(
      (p) => _katex_js.KatexJs(
        tex: p['tex'] as String,
        displayMode: p['displayMode'] as bool,
      ),
      loader: _katex_js.loadLibrary,
    ),
  },
);
