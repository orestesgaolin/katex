/// Builds the embedded `katex_flutter` widget — web-only, stubbed on the server
/// so the static prerender never imports `package:flutter`.
library;

export 'math_cell_builder_io.dart'
    if (dart.library.js_interop) 'math_cell_builder_web.dart';
