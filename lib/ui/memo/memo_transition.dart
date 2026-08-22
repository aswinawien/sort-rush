import 'package:flutter/widgets.dart';

import '../../dev/dev_stats.dart';
import '../theme.dart';
import '../visual_style.dart';
import 'memo_variant.dart';

/// Drives one depot-board presentation.
///
/// All six variants run through this single controller. A variant only changes
/// parameters — axis, overshoot, stamp, registration split — so interruption,
/// skipping and completion behave identically everywhere, and there is one
/// place to get that right rather than six.
///
/// Interruption contract:
///  * [skip] jumps the entrance to its end. It never fires the close callback.
///  * [close] runs the exit once. Calling it again while closing is ignored,
///    so a double tap cannot dismiss twice or run the action twice.
///  * Disposal mid-flight cancels cleanly and leaves no listener behind.
class MemoTransition extends StatefulWidget {
  const MemoTransition({
    super.key,
    required this.variant,
    required this.child,
    this.onClosed,
    this.closing = false,
  });

  final MemoVariant variant;
  final Widget child;

  /// Fired once, after the exit finishes. Never fired by [skip].
  final VoidCallback? onClosed;

  /// Drive the exit from the parent. Flipping this to true starts the retract.
  final bool closing;

  @override
  State<MemoTransition> createState() => MemoTransitionState();
}

class MemoTransitionState extends State<MemoTransition>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  VisualProfile? _profile;
  bool _closing = false;
  bool _closedFired = false;

  /// Seconds since the current phase began. Read by the profiler.
  double get elapsed =>
      (_controller?.lastElapsedDuration?.inMilliseconds ??
          (_controller?.value ?? 0) * _phaseMs) /
      1000.0;

  double get _phaseMs => (_closing
          ? MemoTiming.exit(_profile!, widget.variant)
          : MemoTiming.entrance(_profile!, widget.variant))
      .inMilliseconds
      .toDouble();

  bool get isAnimating => _controller?.isAnimating ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = VisualProfile.of(context);
    if (_controller != null &&
        _profile?.style == profile.style &&
        _profile?.reduceMotion == profile.reduceMotion) {
      return;
    }
    _profile = profile;
    _controller ??= AnimationController(vsync: this);
    if (widget.closing) {
      // A style or reduce-motion change mid-exit must not resurrect the panel.
      // `_startEntrance` clears `_closing`, and `didUpdateWidget` only calls
      // `close()` on a false-to-true edge that will never come again — so the
      // parent stays latched shut and the overlay strands open.
      return;
    }
    _startEntrance();
  }

  @override
  void didUpdateWidget(MemoTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.variant != oldWidget.variant) {
      _closing = false;
      _closedFired = false;
      _startEntrance();
    }
    if (widget.closing && !oldWidget.closing) {
      close();
    }
  }

  void _startEntrance() {
    final controller = _controller!;
    _closing = false;
    controller.duration = MemoTiming.entrance(_profile!, widget.variant);
    if (kDevTools) {
      DevStats.memoProfile = widget.variant.label;
    }
    if (controller.duration == Duration.zero) {
      controller.value = 1;
      return;
    }
    controller.forward(from: 0);
  }

  /// Jump the entrance to its resting state. Safe to call at any time, and
  /// deliberately not a way to close.
  void skip() {
    final controller = _controller;
    if (controller == null || _closing) {
      return;
    }
    controller.stop();
    controller.value = 1;
  }

  /// Replay from the top. Clears the fired-once latch so a preview can run the
  /// same variant repeatedly without the close callback going stale.
  void replay() {
    _closedFired = false;
    _startEntrance();
  }

  /// Run the exit once. Repeat calls while already closing are ignored.
  void close() {
    final controller = _controller;
    if (controller == null || _closing) {
      return;
    }
    _closing = true;
    controller.duration = MemoTiming.exit(_profile!, widget.variant);
    if (controller.duration == Duration.zero) {
      controller.value = 0;
      // `close()` reaches here from `didUpdateWidget`, i.e. during build.
      // Firing synchronously calls `setState` on an ancestor that has already
      // built this frame, which throws. The animated path is already safe
      // because `whenCompleteOrCancel` lands after the frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _fireClosed());
      return;
    }
    controller.reverse(from: 1).whenCompleteOrCancel(_fireClosed);
  }

  void _fireClosed() {
    // Fired at most once per open. A skipped or interrupted exit must not be
    // able to run the caller's action twice.
    if (_closedFired || !mounted) {
      return;
    }
    _closedFired = true;
    widget.onClosed?.call();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final profile = _profile;
    if (controller == null || profile == null) {
      return widget.child;
    }
    final spec = specFor(widget.variant);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = spec.entranceCurve.transform(controller.value.clamp(0, 1));
        if (kDevTools) {
          DevStats.memoElapsed = controller.value * _phaseMs / 1000.0;
        }
        return _paint(profile, spec, t, child!);
      },
      child: widget.child,
    );
  }

  Widget _paint(
    VisualProfile profile,
    MemoVariantSpec spec,
    double t,
    Widget child,
  ) {
    if (profile.reduceMotion) {
      return child;
    }

    // Neon gets the full flourish; standard gets a restrained fraction of it,
    // so both read as the same motion rather than as two different screens.
    final strength = profile.neon ? 1.0 : 0.35;
    final travel = (1 - t) * 46 * (spec.feedFromStart ? -1 : 1);
    final offset = spec.feedAxis == Axis.horizontal
        ? Offset(travel, 0)
        : Offset(0, travel);

    final settle = 1 + spec.stampImpact * strength * _impulse(t);
    final split = spec.registrationPx * strength * (1 - t);

    Widget body = Transform.scale(
      scale: settle,
      child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
    );

    if (split > 0.05) {
      // Two tinted ghosts either side of the real panel. Never applied to the
      // panel's own text layer, so copy stays legible throughout.
      body = Stack(
        children: [
          Transform.translate(
            offset: Offset(-split, 0),
            child: Opacity(
              opacity: 0.35 * (1 - t),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Tokens.hues[0],
                  BlendMode.srcATop,
                ),
                child: body,
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(split, 0),
            child: Opacity(
              opacity: 0.35 * (1 - t),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Tokens.hues[1],
                  BlendMode.srcATop,
                ),
                child: body,
              ),
            ),
          ),
          body,
        ],
      );
    }

    return Transform.translate(offset: offset, child: body);
  }

  /// A single settle bump: zero at both ends, peaking just before rest.
  double _impulse(double t) {
    if (t <= 0 || t >= 1) {
      return 0;
    }
    final x = (t - 0.82) / 0.18;
    return x <= -1 ? 0 : (1 - x * x).clamp(0.0, 1.0);
  }
}
