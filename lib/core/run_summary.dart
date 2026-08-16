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
  });

  factory RunSummary.fromEngine(RunEngine engine) => RunSummary(
        levelId: engine.level.id,
        outcome: engine.outcome,
        score: engine.score.score,
        sorted: engine.score.sorted,
        misrouted: engine.score.misrouted,
        dropped: engine.score.dropped,
        bestCombo: engine.score.bestCombo,
      );

  final int levelId;
  final RunOutcome outcome;
  final int score;
  final int sorted;
  final int misrouted;
  final int dropped;
  final int bestCombo;

  bool get passed => outcome == RunOutcome.passed;

  /// The rubber-stamp verdict. Clearing the shift is the baseline; the top
  /// stamp is reserved for holding a combo, not merely surviving.
  String get verdict {
    if (!passed) {
      return 'PROBATIONARY';
    }
    return bestCombo >= 4 ? 'EMPLOYEE OF THE SHIFT' : 'CLEARED';
  }
}
