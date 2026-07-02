/// An animated variant of the [Math] widget that *reveals* a LaTeX formula
/// over time — wiping it in from the left, from the right, or fading it in
/// uniformly (see [MathAnimationMode]).
///
/// Like [Math] it is a pure consumer of the box tree produced by
/// `package:katex` — it parses/builds once per `build`, then paints with
/// [KatexBoxPainter]. The animation runs entirely in the painter (driven by an
/// [Animation] wired as the painter's `repaint` listenable), so each frame is a
/// repaint, not a rebuild, and the box tree is never re-parsed mid-animation.
library;

import 'package:flutter/widgets.dart';
import 'package:katex/src/math_widget.dart'
    show Math, kDefaultMathFontSize;
import 'package:katex/src/render/box_painter.dart';
import 'package:katex_dart/katex_dart.dart';

/// A widget that renders a LaTeX math [tex] string with a reveal animation.
///
/// Example:
/// ```dart
/// // Wipe in from the left over 700ms (the default).
/// AnimatedMath(r'\int_0^1 x^2 \, dx')
///
/// // Fade the whole thing in.
/// AnimatedMath(r'E = mc^2', mode: MathAnimationMode.fadeIn)
///
/// // Drive it yourself with an external controller (replays, scrubbing, …).
/// AnimatedMath(r'a^2 + b^2 = c^2', controller: myController)
/// ```
///
/// ## Playback
///  * With no [controller], an internal [AnimationController] is created; it
///    plays once on first build when [autoPlay] is `true`, and replays whenever
///    [tex] or [mode] changes.
///  * Pass a [controller] to drive playback yourself (loop, reverse, scrub). In
///    that case [duration]/[autoPlay] are ignored and you own its lifecycle.
///
/// Sizing, color, and error handling match [Math].
class AnimatedMath extends StatefulWidget {
  /// Creates an [AnimatedMath] widget for the LaTeX source [tex].
  const AnimatedMath(
    this.tex, {
    super.key,
    this.mode = MathAnimationMode.leftToRight,
    this.duration = const Duration(milliseconds: 700),
    this.stepDuration,
    this.curve = Curves.easeOutCubic,
    this.autoPlay = true,
    this.controller,
    this.displayMode = false,
    this.fontSize,
    this.color,
    this.onError,
    this.throwOnError = false,
    this.onCompleted,
  });

  /// The LaTeX math source to render (e.g. `r'\frac{a}{b}'`).
  final String tex;

  /// How the formula is revealed. Defaults to [MathAnimationMode.leftToRight].
  final MathAnimationMode mode;

  /// Duration of the *whole* reveal when using the internal controller.
  /// Ignored when [stepDuration] is set, or when an external [controller] is
  /// supplied.
  final Duration duration;

  /// When set, the reveal is **paced one element per [stepDuration]** — the
  /// total duration becomes `elementCount × stepDuration` and a linear curve is
  /// used, so elements appear at a steady rate (e.g. `Duration(seconds: 1)` ⇒
  /// one element per second). Overrides [duration] and [curve]. Has no effect
  /// with [MathAnimationMode.fadeIn] (which fades the whole formula at once) or
  /// an external [controller].
  final Duration? stepDuration;

  /// Easing applied to the reveal progress. Defaults to [Curves.easeOutCubic].
  /// Ignored (forced linear) when [stepDuration] is set.
  final Curve curve;

  /// Whether the internal controller plays automatically on first build and on
  /// [tex]/[mode] changes. Ignored when an external [controller] is supplied.
  final bool autoPlay;

  /// An optional external controller (0 → 1) driving the reveal. When provided,
  /// the caller owns its lifecycle and [duration]/[autoPlay] are ignored.
  final AnimationController? controller;

  /// Display vs inline math, mirroring KaTeX's `displayMode`.
  final bool displayMode;

  /// Base size in **logical pixels per em**. Defaults to
  /// [kDefaultMathFontSize] when `null`.
  final double? fontSize;

  /// The base text color. When `null`, the ambient [DefaultTextStyle] color is
  /// used (falling back to opaque black).
  final Color? color;

  /// Builder invoked to render a fallback when parsing/building throws and
  /// [throwOnError] is `false`. When `null`, the raw [tex] is shown in KaTeX's
  /// error red.
  final Widget Function(BuildContext context, Object error)? onError;

  /// Whether to rethrow a parse/build error out of `build` (`false` by
  /// default).
  final bool throwOnError;

  /// Called once each time the reveal animation completes (reaches 1.0). Useful
  /// for chaining reveals or kicking off follow-on work.
  final VoidCallback? onCompleted;

  @override
  State<AnimatedMath> createState() => _AnimatedMathState();
}

class _AnimatedMathState extends State<AnimatedMath>
    with SingleTickerProviderStateMixin {
  /// The controller we created ourselves, or `null` when the caller supplied
  /// one via [AnimatedMath.controller].
  AnimationController? _internal;

  /// The curve-shaped progress fed to the painter.
  late CurvedAnimation _curved;

  /// The parsed box tree (cached so a step-paced reveal can size its duration
  /// from the element count without re-parsing each build), or `null` if the
  /// last parse failed.
  BoxNode? _box;

  /// The error from the last failed parse, shown via [_buildError].
  Object? _error;

  /// Number of individually-revealable elements in [_box] (for step pacing).
  int _leafCount = 0;

  AnimationController get _controller => widget.controller ?? _internal!;

  /// The reveal curve — forced linear under [AnimatedMath.stepDuration] so each
  /// element gets an equal real-time slice.
  Curve get _curve =>
      widget.stepDuration != null ? Curves.linear : widget.curve;

  @override
  void initState() {
    super.initState();
    _parse();
    if (widget.controller == null) {
      _internal = AnimationController(vsync: this, duration: _totalDuration());
    }
    _curved = CurvedAnimation(parent: _controller, curve: _curve);
    _controller.addStatusListener(_handleStatus);
    if (_internal != null && widget.autoPlay) {
      _internal!.forward(from: 0);
    }
  }

  /// (Re)parses [AnimatedMath.tex] into [_box] (or records [_error]) and counts
  /// its revealable elements.
  void _parse() {
    try {
      final box = renderToBox(
        widget.tex,
        options: KatexOptions(
          displayMode: widget.displayMode,
          color: _toCssColor(widget.color),
          throwOnError: widget.throwOnError,
        ),
      );
      _box = box;
      _error = null;
      _leafCount = countRevealableLeaves(box);
    } on Object catch (error) {
      _box = null;
      _error = error;
      _leafCount = 0;
    }
  }

  /// Total reveal duration for the internal controller: `N × stepDuration`
  /// when step-paced (one element per step), else [AnimatedMath.duration].
  Duration _totalDuration() {
    final step = widget.stepDuration;
    if (step == null) {
      return widget.duration;
    }
    final n = _leafCount < 1 ? 1 : _leafCount;
    return step * n;
  }

  /// Restart the internal controller's reveal with an up-to-date duration.
  void _play() {
    final internal = _internal;
    if (internal == null) {
      return;
    }
    internal
      ..duration = _totalDuration()
      ..forward(from: 0);
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onCompleted?.call();
    }
  }

  @override
  void didUpdateWidget(AnimatedMath oldWidget) {
    super.didUpdateWidget(oldWidget);

    // We don't support swapping between an external and an internal controller
    // after creation; that would require disposing/re-creating state.
    assert(
      (oldWidget.controller == null) == (widget.controller == null),
      'AnimatedMath: switching between an external and internal controller is '
      'not supported. Use a key to force a fresh widget instead.',
    );

    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?.removeStatusListener(_handleStatus);
      widget.controller?.addStatusListener(_handleStatus);
    }

    // Re-parse (and recount) when anything baked into the box tree changes.
    final boxChanged = widget.tex != oldWidget.tex ||
        widget.displayMode != oldWidget.displayMode ||
        widget.color != oldWidget.color ||
        widget.throwOnError != oldWidget.throwOnError;
    if (boxChanged) {
      _parse();
    }
    if (_curve != (oldWidget.stepDuration != null
        ? Curves.linear
        : oldWidget.curve)) {
      _curved.dispose();
      _curved = CurvedAnimation(parent: _controller, curve: _curve);
    }

    // Replay when the content, direction, or pacing changes (internal
    // controller only — an external controller is the caller's to drive).
    final replay = boxChanged ||
        widget.mode != oldWidget.mode ||
        widget.stepDuration != oldWidget.stepDuration ||
        widget.duration != oldWidget.duration;
    if (_internal != null) {
      if (widget.autoPlay && replay) {
        _play();
      } else if (replay) {
        // Not auto-playing: keep the controller's duration current for the
        // next manual play.
        _internal!.duration = _totalDuration();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleStatus);
    _curved.dispose();
    _internal?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color ??
        DefaultTextStyle.of(context).style.color ??
        const Color(0xFF000000);
    final fontSizePx = widget.fontSize ?? kDefaultMathFontSize;

    final box = _box;
    if (box == null) {
      final error = _error ?? StateError('no rendered box');
      if (widget.throwOnError) {
        // Re-surface the stored parse error (mirrors the old `rethrow`).
        // ignore: only_throw_errors
        throw error;
      }
      return _buildError(context, error);
    }

    final size = boxSizePxPadded(box, fontSizePx);
    return SizedBox.fromSize(
      size: size,
      child: CustomPaint(
        size: size,
        painter: KatexBoxPainter(
          box,
          fontSize: fontSizePx,
          color: baseColor,
          inkPadEm: kInkOverflowPadEm,
          animationMode: widget.mode,
          progress: _curved,
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    if (widget.onError != null) {
      return widget.onError!(context, error);
    }
    return Text(
      widget.tex,
      style: const TextStyle(color: Color(0xFFCC0000)),
    );
  }

  /// Converts a Flutter [Color] to the `#rrggbb` CSS string [KatexOptions]
  /// expects, or `null` when no color is set.
  static String? _toCssColor(Color? color) {
    if (color == null) {
      return null;
    }
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }
}
