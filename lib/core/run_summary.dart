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
  });

  factory RunSummary.fromEngine(RunEngine engine) => RunSummary(
        levelId: engine.level.id,
        outcome: engine.outcome,
        score: engine.score.score,
        sorted: engine.score.sorted,
        misrouted: engine.score.misrouted,
        dropped: engine.score.dropped,
        bestCombo: engine.score.bestCombo,
        endless: engine.level.curve != null,
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

  bool get passed => outcome == RunOutcome.passed;

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
