/// Score, combo, and tally state for a single run.
///
/// Combo is active and displayed from level 1. Level 5 teaches the player to
/// chase it; it does not switch it on. See docs/decision-log.md, "Prototype
/// builds curated levels 1-3, not endless".
class RunScore {
  /// Points for one correct sort before the combo multiplier.
  static const int baseValue = 10;

  /// Consecutive correct sorts needed to advance one tier.
  static const int sortsPerTier = 5;

  /// Combo multiplier ceiling.
  static const int maxTier = 5;

  int score = 0;
  int sorted = 0;
  int misrouted = 0;
  int dropped = 0;

  /// Highest tier reached this run. Starts at 1 because x1 is a real tier,
  /// not the absence of one.
  int bestCombo = 1;

  int _consecutive = 0;

  int get consecutive => _consecutive;

  int get comboTier => tierFor(_consecutive);

  /// Misroutes and drops both count against the mistake limit.
  int get mistakes => misrouted + dropped;

  static int tierFor(int consecutive) {
    final tier = 1 + consecutive ~/ sortsPerTier;
    return tier > maxTier ? maxTier : tier;
  }

  /// Registers a correct sort and returns the points gained.
  ///
  /// The tier advances *before* the award is calculated, so the sort that
  /// completes a tier is the one that pays the higher rate. That is the
  /// moment the player feels, so it is the moment that should pay.
  int registerCorrect() {
    _consecutive++;
    sorted++;
    final tier = comboTier;
    if (tier > bestCombo) {
      bestCombo = tier;
    }
    final gained = baseValue * tier;
    score += gained;
    return gained;
  }

  void registerMisroute() {
    misrouted++;
    _consecutive = 0;
  }

  void registerDrop() {
    dropped++;
    _consecutive = 0;
  }
}
