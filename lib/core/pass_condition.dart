import 'score_state.dart';

/// What clearing a shift requires.
///
/// Levels 1–4 ask only for a count of correct sorts, but the approved table in
/// `docs/level-spec.md` also asks for a combo tier (level 5), a bounded
/// misroute count (level 8), and both at once (level 10). A bare integer
/// cannot express those, so the target is a type.
///
/// Engine-free by construction: this reads [RunScore] and nothing else.
sealed class PassCondition {
  const PassCondition();

  /// Whether the run has cleared the shift.
  bool isMetBy(RunScore score);

  /// The fewest correct sorts that could satisfy this condition.
  ///
  /// Used to estimate a level's duration in tests. It is a lower bound, not a
  /// prediction — a player who breaks a combo takes longer.
  int get minimumSorts;

  /// Shown on the briefing, so the player knows what is being asked before the
  /// belt moves.
  String get briefingCopy;
}

/// Clear the shift by sorting [count] packages correctly.
class SortTarget extends PassCondition {
  const SortTarget(this.count)
      : assert(count > 0, 'a target of zero is not a shift');

  final int count;

  @override
  bool isMetBy(RunScore score) => score.sorted >= count;

  @override
  int get minimumSorts => count;

  @override
  String get briefingCopy => 'SORT $count';
}

/// Clear the shift by reaching combo [tier].
///
/// Reads `bestCombo` rather than the live tier, so a streak that peaks and
/// then breaks still counts — the player did the thing that was asked.
class ComboTarget extends PassCondition {
  const ComboTarget(this.tier) : assert(tier > 1, 'x1 is the starting tier');

  final int tier;

  @override
  bool isMetBy(RunScore score) => score.bestCombo >= tier;

  @override
  int get minimumSorts => (tier - 1) * RunScore.sortsPerTier;

  @override
  String get briefingCopy => 'REACH COMBO x$tier';
}

/// Clear the shift by saving [count] packages inside the clutch window.
///
/// Level 7 teaches recovery from a near miss, so its target has to be about
/// the recovery rather than about volume.
class ClutchTarget extends PassCondition {
  const ClutchTarget(this.count)
      : assert(count > 0, 'zero saves is not a rule');

  final int count;

  @override
  bool isMetBy(RunScore score) => score.clutchSaves >= count;

  @override
  int get minimumSorts => count;

  @override
  String get briefingCopy => 'SAVE $count AT THE LINE';
}

/// Clear the shift by meeting every one of [conditions].
///
/// Levels 7 and 10 both ask for two things at once, and asking for two things
/// is different from asking for the harder of them — a player can be well past
/// one target and nowhere near the other.
class EveryOf extends PassCondition {
  /// Wrapping a single condition is pointless but harmless, and asserting
  /// against it is not possible in a const constructor.
  const EveryOf(this.conditions);

  final List<PassCondition> conditions;

  @override
  bool isMetBy(RunScore score) =>
      conditions.every((condition) => condition.isMetBy(score));

  /// A lower bound: the largest of the parts. Satisfying every condition can
  /// take more sorts than this, never fewer.
  @override
  int get minimumSorts => conditions
      .map((condition) => condition.minimumSorts)
      .reduce((a, b) => a > b ? a : b);

  @override
  String get briefingCopy =>
      conditions.map((condition) => condition.briefingCopy).join(' · ');
}
