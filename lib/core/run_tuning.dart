import 'level_config.dart';
import 'tuning_delta.dart';

/// The numbers the belt is actually running on right now.
///
/// [LevelConfig] is the run's *contract* — its identity, its chutes, what it
/// asks of the player. This is the run's *state*: the same knobs, resolved for
/// a moment in time from the level, the difficulty curve, and whatever the
/// player has bought. Keeping them apart is what stops "which level is this"
/// from becoming a moving target mid-run.
///
/// Deliberately not a `LevelConfig.copyWith`. `SortRushGame` holds its own
/// reference to the level and the HUD reads the mistake limit through it, so
/// swapping the engine's config would leave the mistake pips showing a number
/// that is not the number that ends the run.
class RunTuning {
  const RunTuning({
    required this.readWindow,
    required this.spawnInterval,
    required this.maxActive,
    required this.mistakeLimit,
    required this.chaosRate,
    required this.telegraphSeconds,
    required this.scorePercent,
    required this.payPercent,
  })  : assert(readWindow >= readWindowFloor, 'read window floor breached'),
        assert(
          spawnInterval >= spawnIntervalFloor,
          'spawn interval floor breached',
        ),
        assert(maxActive >= 1 && maxActive <= maxActiveCeiling),
        assert(chaosRate >= 0 && chaosRate <= 1),
        assert(
          chaosRate == 0 || telegraphSeconds >= telegraphFloor,
          'chaos without a telegraph is a coin flip, not a skill',
        );

  /// The fairness contract from docs/level-spec.md. Below these a first-time
  /// player cannot reliably read two attributes and act, and they may only be
  /// lowered with device-test evidence.
  static const double readWindowFloor = 1.20;
  static const double spawnIntervalFloor = 0.65;

  /// Escalation in this game is the shrinking warning, never its removal.
  static const double telegraphFloor = 0.50;

  static const int maxActiveCeiling = 5;

  /// A run's numbers for right now.
  ///
  /// The clamp happens **last and unconditionally**, which is what makes "no
  /// stack of purchases can breach the floors" structurally true rather than
  /// something every card has to remember. The asserts above then hold for
  /// free in debug and are unreachable in release.
  factory RunTuning.resolve({
    required LevelConfig level,
    TuningDelta modifiers = TuningDelta.none,
  }) {
    final chaos = _clampDouble(level.chaosRate + modifiers.chaosRate, 0, 1);

    // A level with no chaos is allowed a telegraph of zero — there is nothing
    // to warn about. The moment chaos exists, the warning is floored.
    var telegraph = level.telegraphSeconds + modifiers.telegraphSeconds;
    if (chaos > 0 && telegraph < telegraphFloor) {
      telegraph = telegraphFloor;
    }

    final limit = level.mistakeLimit;

    return RunTuning(
      readWindow: _atLeast(
        level.readWindow + modifiers.readWindow,
        readWindowFloor,
      ),
      spawnInterval: _atLeast(
        level.spawnInterval + modifiers.spawnInterval,
        spawnIntervalFloor,
      ),
      maxActive: _clampInt(
        level.maxActive + modifiers.maxActive,
        1,
        maxActiveCeiling,
      ),
      // Null means the level cannot be failed at all, and no purchase should
      // be able to introduce a way to fail it.
      mistakeLimit:
          limit == null ? null : _atLeastInt(limit + modifiers.mistakeLimit, 1),
      chaosRate: chaos,
      telegraphSeconds: telegraph,
      scorePercent: _atLeastInt(100 + modifiers.scorePercent, _percentFloor),
      payPercent: _atLeastInt(100 + modifiers.payPercent, _percentFloor),
    );
  }

  /// Rates never reach zero: a card that stopped scoring entirely would end
  /// the run's purpose without ending the run.
  static const int _percentFloor = 10;

  final double readWindow;
  final double spawnInterval;
  final int maxActive;

  /// Mistakes allowed before the run fails. Null means it cannot be failed.
  final int? mistakeLimit;

  final double chaosRate;
  final double telegraphSeconds;

  /// Multipliers as integer percentages, so the money path stays exact.
  final int scorePercent;
  final int payPercent;

  static double _atLeast(double value, double floor) =>
      value < floor ? floor : value;

  static int _atLeastInt(int value, int floor) => value < floor ? floor : value;

  static double _clampDouble(double value, double low, double high) =>
      value < low ? low : (value > high ? high : value);

  static int _clampInt(int value, int low, int high) =>
      value < low ? low : (value > high ? high : value);
}
