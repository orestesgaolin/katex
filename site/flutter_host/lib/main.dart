/// Flutter-web host for the comparison site's `katex_flutter` column (T-024).
///
/// **Multi-view embedding.** This app runs as a single Flutter web engine in
/// *multi-view* mode (`runWidget` + a multi-view root), with **one `View` per
/// comparison row**. The Jaspr site boots the engine once and, for each row,
/// calls `app.addView({hostElement, initialData})` to attach a Flutter view to
/// that row's host `<div>`. Each view renders a single `Math` widget for that
/// row's expression — so the Flutter cell sits truly inline beside the
/// TeX / KaTeX-JS / Dart-SVG cells for the same expression.
///
/// Per-view configuration (`{tex, displayMode, fontSize}`) is passed as
/// `initialData` at `addView` time and read back here via
/// `dart:ui_web` `ui_web.views.getInitialData(viewId)`.
library;

import 'dart:js_interop';
import 'dart:ui' show FlutterView, PlatformDispatcher;
import 'dart:ui_web' as ui_web;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:katex_flutter/katex_flutter.dart';

void main() => runWidget(const _MultiViewKatexApp());

/// The shape of the per-view `initialData` object passed from JS at
/// `addView({ hostElement, initialData })` time.
extension type _ViewData._(JSObject _) implements JSObject {
  external String? get tex;
  external bool? get displayMode;
  external double? get fontSize;
}

/// A multi-view root that renders one [View] per registered Flutter view and
/// rebuilds whenever views are added or removed.
///
/// This mirrors the documented `MultiViewApp` pattern: it listens to
/// [PlatformDispatcher.onMetricsChanged] (fired when views are added/removed)
/// and maps every entry of `platformDispatcher.views` to a [View] widget
/// wrapping a [KatexView] built from that view's `initialData`.
class _MultiViewKatexApp extends StatefulWidget {
  const _MultiViewKatexApp();

  @override
  State<_MultiViewKatexApp> createState() => _MultiViewKatexAppState();
}

class _MultiViewKatexAppState extends State<_MultiViewKatexApp> {
  Map<Object, Widget> _views = <Object, Widget>{};

  @override
  void initState() {
    super.initState();
    final PlatformDispatcher dispatcher = WidgetsBinding.instance.platformDispatcher;
    dispatcher.onMetricsChanged = _onMetricsChanged;
    _updateViews();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.platformDispatcher.onMetricsChanged = null;
    super.dispose();
  }

  void _onMetricsChanged() {
    final bool didChange = _updateViews();
    if (didChange) {
      // onMetricsChanged can fire during a frame; defer setState if so.
      if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
        setState(() {});
      } else {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  /// Rebuilds [_views] from the current set of registered views. Returns true
  /// if the set of views changed.
  bool _updateViews() {
    final Map<Object, Widget> newViews = <Object, Widget>{};
    bool changed = false;
    for (final FlutterView view in WidgetsBinding.instance.platformDispatcher.views) {
      final Widget existing = _views[view.viewId] ?? _buildView(view);
      if (!_views.containsKey(view.viewId)) changed = true;
      newViews[view.viewId] = existing;
    }
    if (newViews.length != _views.length) changed = true;
    _views = newViews;
    return changed;
  }

  Widget _buildView(FlutterView view) {
    final JSAny? raw = ui_web.views.getInitialData(view.viewId);
    final _ViewData? data = raw as _ViewData?;
    return View(
      view: view,
      child: KatexView(
        tex: data?.tex ?? '',
        displayMode: data?.displayMode ?? false,
        fontSize: data?.fontSize ?? 22,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ViewCollection(views: _views.values.toList(growable: false));
  }
}

/// Renders a single [Math] expression centered on white, sized to its host
/// element (the host `<div>` in the Jaspr row sets the bounds).
class KatexView extends StatelessWidget {
  const KatexView({
    required this.tex,
    required this.displayMode,
    required this.fontSize,
    super.key,
  });

  /// The LaTeX math source for this row.
  final String tex;

  /// Whether to typeset as display math.
  final bool displayMode;

  /// Math font size in logical pixels.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      debugShowCheckedModeBanner: false,
      color: const Color(0xFFFFFFFF),
      builder: (BuildContext context, Widget? child) {
        return DefaultTextStyle(
          style: const TextStyle(color: Color(0xFF1A1A1A)),
          child: Container(
            color: const Color(0xFFFFFFFF),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Math(
                tex,
                displayMode: displayMode,
                fontSize: fontSize,
                onError: (BuildContext context, Object error) => Text(
                  'error: $error',
                  style: const TextStyle(color: Color(0xFFCC0000), fontSize: 11),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
