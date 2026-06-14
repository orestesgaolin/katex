// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/server.dart';
import 'package:site/components/katex_js.dart' as _katex_js;
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
    _katex_js.KatexJs: ClientTarget<_katex_js.KatexJs>(
      'katex_js',
      params: __katex_jsKatexJs,
    ),
  },
  styles: () => [..._app.App.styles],
);

Map<String, Object?> __katex_jsKatexJs(_katex_js.KatexJs c) => {
  'tex': c.tex,
  'displayMode': c.displayMode,
};
