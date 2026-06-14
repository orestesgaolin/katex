/// Column 4 — the `katex_flutter` `Math` widget, rendered inline per row via
/// **Flutter web multi-view embedding** (T-024).
///
/// Jaspr server-renders an empty, fixed-size host `<div>` for this row. On the
/// client, this `@client` component hydrates and calls the shared bridge
/// `window.__katexFlutter.add(hostDiv, {tex, displayMode, fontSize})` — which
/// attaches a single Flutter *view* (from the one engine booted by
/// `flutter_embed.js`) into this exact div. The view renders `Math(tex)` for
/// this row, so the Flutter cell sits inline beside the TeX / KaTeX-JS /
/// Dart-SVG cells for the same expression.
///
/// Uses `js_interop` per the jaspr-js-interop skill: `package:universal_web`
/// for safe server stubbing, guarded by `kIsWeb`. The view is removed on
/// dispose so re-hydration/hot-reload don't leak views.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:universal_web/js_interop.dart';
import 'package:universal_web/web.dart' as web;

/// The bridge exposed by `web/flutter_embed.js` once the engine is booting.
@JS('__katexFlutter')
external _KatexFlutter? get _bridge;

extension type _KatexFlutter._(JSObject _) implements JSObject {
  /// Attaches a Flutter view to [hostElement]; resolves to its view id.
  external JSPromise<JSNumber> add(web.Element hostElement, _ViewData data);

  /// Removes a previously-added view by id.
  external void remove(JSNumber viewId);
}

/// The per-view config passed to the Flutter engine as `initialData`.
@JS()
@anonymous
extension type _ViewData._(JSObject _) implements JSObject {
  external factory _ViewData({
    JSString tex,
    JSBoolean displayMode,
    JSNumber fontSize,
  });
}

/// Embeds the `katex_flutter` render of [tex] for one row.
@client
class FlutterView extends StatefulComponent {
  const FlutterView({
    required this.tex,
    required this.displayMode,
    this.fontSize = 22,
    super.key,
  });

  /// The LaTeX math source.
  final String tex;

  /// Whether to typeset as display math.
  final bool displayMode;

  /// Math font size (logical px per em) for the Flutter `Math` widget.
  final double fontSize;

  @override
  State<FlutterView> createState() => _FlutterViewState();
}

class _FlutterViewState extends State<FlutterView> {
  final GlobalNodeKey<web.HTMLElement> _hostKey = GlobalNodeKey();

  /// The view id once the Flutter engine has attached a view here.
  int? _viewId;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Attach after the host element is mounted in the DOM.
      Future<void>.microtask(_attach);
    }
  }

  void _attach() {
    final host = _hostKey.currentNode;
    final bridge = _bridge;
    if (host == null || bridge == null) {
      // flutter_embed.js may not have defined the bridge yet; retry shortly.
      Future<void>.delayed(const Duration(milliseconds: 50), _attach);
      return;
    }
    final data = _ViewData(
      tex: component.tex.toJS,
      displayMode: component.displayMode.toJS,
      fontSize: component.fontSize.toJS,
    );
    bridge.add(host, data).toDart.then((JSNumber id) {
      _viewId = id.toDartInt;
    });
  }

  @override
  void dispose() {
    if (kIsWeb && _viewId != null) {
      _bridge?.remove(_viewId!.toJS);
    }
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return div(key: _hostKey, classes: 'flutter-host', []);
  }
}
