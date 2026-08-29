import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../ui/theme.dart';
import '../ui/visual_style.dart';
import 'debug_summary.dart';
import 'dev_stats.dart';
import 'frame_meter.dart';

/// Development frame/effect readout.
///
/// Pinned to the middle of the left edge on purpose: the score sits top-left
/// inside the top 14%, the mistake pips top-right, packages travel down the
/// centre and the chutes own the bottom quarter. The mid-left strip is the one
/// region of the play field nothing gameplay-critical ever occupies.
///
/// Returns [child] untouched in release. Nothing here reaches a shipped build.
class ProfilerOverlay extends StatefulWidget {
  const ProfilerOverlay({
    super.key,
    required this.child,
    this.visible = true,
  });

  final Widget child;
  final bool visible;

  @override
  State<ProfilerOverlay> createState() => _ProfilerOverlayState();
}

class _ProfilerOverlayState extends State<ProfilerOverlay> {
  final FrameMeter _meter = FrameMeter();
  TimingsCallback? _callback;

  @override
  void initState() {
    super.initState();
    if (!kDevTools) {
      return;
    }
    _callback = _onTimings;
    SchedulerBinding.instance.addTimingsCallback(_callback!);
  }

  @override
  void dispose() {
    final callback = _callback;
    if (callback != null) {
      SchedulerBinding.instance.removeTimingsCallback(callback);
    }
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      // Total span, not just build: rasterisation is where a real device falls
      // over, and reporting build time alone would hide exactly that.
      _meter.addSample(
        timing.totalSpan.inMicroseconds / 1000.0,
      );
    }
    if (mounted && widget.visible) {
      setState(() {});
    }
  }

  void reset() {
    _meter.reset();
    DevStats.reset();
    setState(() {});
  }

  Color _colorFor(double ms) => switch (FrameMeter.gradeOf(ms)) {
        FrameGrade.good => Tokens.acid,
        FrameGrade.warning => Tokens.hues[2],
        FrameGrade.bad => Tokens.warn,
      };

  @override
  Widget build(BuildContext context) {
    if (!kDevTools || !widget.visible) {
      return widget.child;
    }
    final profile = VisualProfile.of(context);

    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                color: Tokens.ink.withValues(alpha: 0.72),
                child: DefaultTextStyle(
                  style: Tokens.label.copyWith(fontSize: 10, height: 1.5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_meter.fps.toStringAsFixed(0)} FPS',
                        style: Tokens.label.copyWith(
                          fontSize: 13,
                          color: _colorFor(_meter.average),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _row('now', '${_meter.last.toStringAsFixed(1)}ms',
                          _colorFor(_meter.last)),
                      _row('avg', '${_meter.average.toStringAsFixed(1)}ms',
                          _colorFor(_meter.average)),
                      _row('worst', '${_meter.worst.toStringAsFixed(1)}ms',
                          _colorFor(_meter.worst)),
                      const SizedBox(height: 6),
                      _row('parts', '${DevStats.activeParticles}'),
                      _row('burst', '${DevStats.activeBursts}'),
                      _row('trail', '${DevStats.activeTrails}'),
                      const SizedBox(height: 6),
                      _row('memo', DevStats.memoProfile),
                      _row('t', '${DevStats.memoElapsed.toStringAsFixed(2)}s'),
                      const SizedBox(height: 6),
                      _row('style', profile.neon ? 'NEON' : 'STD'),
                      _row('reduce', '${profile.reduceMotion}'),
                      _row('screen', DevStats.screen),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value, [Color? color]) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: Tokens.label.copyWith(fontSize: 10, letterSpacing: 0.5),
            ),
          ),
          Text(
            value,
            style: Tokens.label.copyWith(
              fontSize: 10,
              color: color ?? Tokens.paper,
            ),
          ),
        ],
      );

  /// The compact capture QA pastes into a report.
  String summary(VisualProfile profile) => debugSummary(
        meter: _meter,
        visualStyle: profile.neon ? 'Immersive Neon' : 'Standard',
        memoProfile: DevStats.memoProfile,
        reduceMotion: profile.reduceMotion,
      );
}
