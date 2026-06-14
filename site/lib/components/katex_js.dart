/// Column 1 — the ground-truth KaTeX JS rendering.
///
/// A `@client` component: Jaspr server-renders an empty host `<div>`, then on
/// the client it hydrates and calls the vendored `katex.render(tex, host,
/// {displayMode, throwOnError:false})` (see `web/katex/katex.min.js`, loaded
/// from `Document.head`). Uses `js_interop` per the jaspr-js-interop skill —
/// `package:universal_web/js_interop.dart` for safe server stubbing, guarded by
/// `kIsWeb`.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:universal_web/js_interop.dart';
import 'package:universal_web/web.dart' as web;

/// The global `katex` object exposed by `katex.min.js`.
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

/// Renders [tex] with real KaTeX JS on hydrate.
@client
class KatexJs extends StatefulComponent {
  const KatexJs({required this.tex, required this.displayMode, super.key});

  /// The LaTeX math source.
  final String tex;

  /// Whether to typeset as display math.
  final bool displayMode;

  @override
  State<KatexJs> createState() => _KatexJsState();
}

class _KatexJsState extends State<KatexJs> {
  final GlobalNodeKey<web.HTMLElement> _hostKey = GlobalNodeKey();

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Render after the element is mounted in the DOM.
      Future<void>.microtask(_render);
    }
  }

  void _render() {
    final host = _hostKey.currentNode;
    final katex = _katex;
    if (host == null || katex == null) {
      // katex.min.js may not have loaded yet; retry shortly.
      Future<void>.delayed(const Duration(milliseconds: 50), _render);
      return;
    }
    try {
      katex.render(
        component.tex.toJS,
        host,
        _KatexOptions(
          displayMode: component.displayMode.toJS,
          throwOnError: false.toJS,
        ),
      );
    } on Object catch (error) {
      host.textContent = 'KaTeX JS error: $error';
    }
  }

  @override
  Component build(BuildContext context) {
    return div(key: _hostKey, classes: 'katex-js', []);
  }
}
