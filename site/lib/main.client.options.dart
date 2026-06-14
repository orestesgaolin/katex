// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/client.dart';

import 'package:site/components/flutter_view.dart' deferred as _flutter_view;
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
    'flutter_view': ClientLoader(
      (p) => _flutter_view.FlutterView(
        tex: p['tex'] as String,
        displayMode: p['displayMode'] as bool,
        fontSize: p['fontSize'] as double,
      ),
      loader: _flutter_view.loadLibrary,
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
