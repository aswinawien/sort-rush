import 'package:flutter/widgets.dart';

import '../visual_style.dart';

/// The six depot-board presentations.
///
/// One transition system drives all of them: a variant is a set of parameters,
/// never its own animation. That is what stops this becoming six unrelated
/// implementations that drift apart.
enum MemoVariant {
  /// Paper-feed entrance, clean retract exit.
  normal('Normal'),

  /// Heavier mechanical stamp, stronger confirmation pulse.
  newRule('New Rule'),

  /// Controlled cyan/magenta registration offset. Restrained instability, and
  /// deliberately no silhouette flicker.
  corruptionWarning('Corruption Warning'),

  /// Cards snap in like files entering a rack.
  shop('Shop'),

  /// Feeds out vertically like a printed receipt.
  shiftResults('Shift Results'),

  /// Folds and scans away into the next shift.
  shiftTransition('Shift Transition');

  const MemoVariant(this.label);

  /// Shown in the profiler and in QA reports.
  final String label;
}

/// What makes one variant look different from another.
class MemoVariantSpec {
  const MemoVariantSpec({
    required this.feedAxis,
    this.feedFromStart = true,
    this.overshoot = 0,
    this.stampImpact = 0,
    this.registrationPx = 0,
    this.sequentialReveal = false,
    this.entranceCurve = Curves.easeOutCubic,
    this.durationScale = 1.0,
  });

  /// Which way the paper travels.
  final Axis feedAxis;

  /// Feeds from the leading edge (left/top) rather than the trailing one.
  final bool feedFromStart;

  /// Mechanical bounce past the resting position before settling, as a
  /// fraction of the travel.
  final double overshoot;

  /// Scale punch on settle, as a fraction above 1.
  final double stampImpact;

  /// Cyan/magenta channel split at peak, in logical pixels.
  final double registrationPx;

  /// Whether rows print in sequence rather than all at once.
  final bool sequentialReveal;

  final Curve entranceCurve;

  /// Nudges this variant's duration inside its band. Never escapes the band —
  /// see [MemoTiming].
  final double durationScale;
}

/// Per-variant parameters. Standard and neon share these; only the durations
/// and the strength of the flourish differ, and that is handled by
/// [MemoTiming] and by scaling in the transition widget.
const Map<MemoVariant, MemoVariantSpec> kMemoVariants = {
  MemoVariant.normal: MemoVariantSpec(
    feedAxis: Axis.horizontal,
    overshoot: 0.04,
  ),
  MemoVariant.newRule: MemoVariantSpec(
    feedAxis: Axis.vertical,
    feedFromStart: true,
    overshoot: 0.10,
    stampImpact: 0.06,
    entranceCurve: Curves.easeOutBack,
    durationScale: 1.05,
  ),
  MemoVariant.corruptionWarning: MemoVariantSpec(
    feedAxis: Axis.horizontal,
    overshoot: 0.03,
    // Restrained on purpose. The registration split is the whole effect; the
    // silhouette must never flicker and the text must stay readable.
    registrationPx: 2.5,
  ),
  MemoVariant.shop: MemoVariantSpec(
    feedAxis: Axis.horizontal,
    feedFromStart: false,
    overshoot: 0.08,
    stampImpact: 0.03,
    sequentialReveal: true,
    entranceCurve: Curves.easeOutBack,
  ),
  MemoVariant.shiftResults: MemoVariantSpec(
    feedAxis: Axis.vertical,
    feedFromStart: true,
    sequentialReveal: true,
    entranceCurve: Curves.easeOutCubic,
    durationScale: 1.1,
  ),
  MemoVariant.shiftTransition: MemoVariantSpec(
    feedAxis: Axis.vertical,
    feedFromStart: false,
    overshoot: 0.02,
    durationScale: 0.95,
  ),
};

MemoVariantSpec specFor(MemoVariant variant) => kMemoVariants[variant]!;

/// Durations, clamped into the bands the brief fixed.
///
/// A variant may nudge its own timing, but it cannot leave the band. The clamp
/// is the point: it makes "standard entrance is 150-250ms" a property of the
/// code rather than a note someone has to remember.
abstract final class MemoTiming {
  static const int standardEntranceMin = 150;
  static const int standardEntranceMax = 250;
  static const int neonEntranceMin = 350;
  static const int neonEntranceMax = 500;
  static const int standardExitMin = 110;
  static const int standardExitMax = 250;
  static const int neonExitMin = 180;
  static const int neonExitMax = 280;

  static Duration entrance(VisualProfile profile, MemoVariant variant) {
    if (profile.reduceMotion) {
      return Duration.zero;
    }
    final scale = specFor(variant).durationScale;
    return _clamped(
      profile.memoIn.inMilliseconds * scale,
      profile.neon ? neonEntranceMin : standardEntranceMin,
      profile.neon ? neonEntranceMax : standardEntranceMax,
    );
  }

  static Duration exit(VisualProfile profile, MemoVariant variant) {
    if (profile.reduceMotion) {
      return Duration.zero;
    }
    final scale = specFor(variant).durationScale;
    return _clamped(
      profile.memoOut.inMilliseconds * scale,
      profile.neon ? neonExitMin : standardExitMin,
      profile.neon ? neonExitMax : standardExitMax,
    );
  }

  static Duration _clamped(double value, int min, int max) =>
      Duration(milliseconds: value.round().clamp(min, max));
}
