import 'run_engine.dart';

/// What the results screen is allowed to know about a finished run.
///
/// A flat snapshot rather than the live engine, so the results screen cannot
/// accidentally keep a run alive or mutate it.
class RunSummary {
  const RunSummary({
    required this.levelId,
    required this.outcome,
    required this.score,
    required this.sorted,
    required this.misrouted,
    required this.dropped,
    required this.bestCombo,
    this.endless = false,
    this.seed = 0,
    this.wagered = false,
    this.pay = 0,
  });

  factory RunSummary.fromEngine(RunEngine engine, {bool wagered = false}) =>
      RunSummary(
        levelId: engine.level.id,
        outcome: engine.outcome,
        score: engine.score.score,
        sorted: engine.score.sorted,
        misrouted: engine.score.misrouted,
        dropped: engine.score.dropped,
        bestCombo: engine.score.bestCombo,
        endless: engine.level.curve != null,
        seed: engine.seed,
        wagered: wagered,
        pay: engine.score.pay,
      );

  final int levelId;
  final RunOutcome outcome;
  final int score;
  final int sorted;
  final int misrouted;
  final int dropped;
  final int bestCombo;

  /// Endless runs are judged on how far they got, not on whether they were
  /// cleared — they cannot be cleared.
  final bool endless;

  /// The seed this run was played under. Endless daily retries reuse it.
  final int seed;

  /// True when this report is the result of a double-or-nothing replay.
  final bool wagered;

  /// Leftover within-run shop cash. Printed on the endless slip only.
  /// Does not change [postedScore].
  final int pay;

  bool get passed => outcome == RunOutcome.passed;

  /// Score as posted. A failed wager zeros it; a cleared wager doubles it.
  int get postedScore {
    if (!wagered) {
      return score;
    }
    return passed ? score * 2 : 0;
  }

  /// Correct sorts as a percentage of every package that left the belt.
  int get rate {
    final total = sorted + misrouted + dropped;
    if (total == 0) {
      return 0;
    }
    return ((sorted / total) * 100).round();
  }

  /// The rubber-stamp verdict.
  ///
  /// A curated shift is judged on whether it was cleared. Endless cannot be
  /// cleared, so stamping every endless run `PROBATIONARY` would be calling
  /// the player a failure for finishing the mode as designed. It is judged on
  /// distance instead, with the top band set where the difficulty curve
  /// reaches both of its floors.
  String get verdict {
    if (endless) {
      if (sorted >= 90) {
        return 'RAN THE FLOOR';
      }
      if (sorted >= 60) {
        return 'SHIFT LEAD';
      }
      if (sorted >= 25) {
        return 'ON THE BOOKS';
      }
      return 'TEMP';
    }
    if (!passed) {
      return 'PROBATIONARY';
    }
    return bestCombo >= 4 ? 'EMPLOYEE OF THE SHIFT' : 'CLEARED';
  }
}
