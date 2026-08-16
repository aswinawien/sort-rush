/// How a run's base numbers move as pressure rises.
///
/// Curated levels have no curve: their numbers are fixed for the whole shift,
/// which is what makes a lesson teachable. Endless has one, and it is the only
/// thing that makes endless *endless* rather than a very long level.
abstract class DifficultyCurve {
  const DifficultyCurve();

  double readWindowAt(int pressure);
  double spawnIntervalAt(int pressure);
  int maxActiveAt(int pressure);
}

/// The endless curve from `docs/level-spec.md`.
///
/// ```
/// S(P) = max(0.65, 2.4 - 0.020P)   spawn interval, floors at P = 87
/// T(P) = max(1.20, 4.0 - 0.030P)   read window,    floors at P = 93
/// A(P) = min(5,    1 + P ~/ 18)    packages at once
/// M    = 3                         fixed for the whole run
/// ```
///
/// `P` is the pressure index — correct sorts, which never decrease. Failure
/// ends a run rather than easing it, so the curve only ever tightens and stays
/// legible.
///
/// Note what the two floors mean together: difficulty escalates by compressing
/// the spawn interval toward its floor *before* the read window, because
/// taking away the read window is what makes a game feel unfair while taking
/// away recovery time is what makes it feel fast.
class EndlessCurve extends DifficultyCurve {
  const EndlessCurve();

  /// Below these the curve stops tightening. `RunTuning` clamps to the same
  /// values regardless — this is the curve declining to ask, rather than the
  /// clamp having to refuse.
  static const double spawnIntervalFloor = 0.65;
  static const double readWindowFloor = 1.20;
  static const int maxActiveCeiling = 5;

  /// Sorts per additional package on the belt.
  static const int activeStep = 18;

  @override
  double spawnIntervalAt(int pressure) {
    final value = 2.4 - 0.020 * pressure;
    return value < spawnIntervalFloor ? spawnIntervalFloor : value;
  }

  @override
  double readWindowAt(int pressure) {
    final value = 4.0 - 0.030 * pressure;
    return value < readWindowFloor ? readWindowFloor : value;
  }

  @override
  int maxActiveAt(int pressure) {
    final value = 1 + pressure ~/ activeStep;
    return value > maxActiveCeiling ? maxActiveCeiling : value;
  }
}
