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

  /// Extra points for sorting a package in the last moments before it drops.
  /// Small by design: the reward for a clutch save is mostly that you did not
  /// lose the package.
  static const int clutchBonus = 5;

  int score = 0;
  int sorted = 0;

  /// Correct sorts made inside the clutch window.
  int clutchSaves = 0;
  int misrouted = 0;
  int dropped = 0;

  /// Shop cash. Endless spends it; leftover can carry into the next
  /// endless run, capped. Integer, so a replay stays exact.
  int pay = 0;
  int _payTally = 0;

  /// Highest tier reached this run. Starts at 1 because x1 is a real tier,
  /// not the absence of one.
  int bestCombo = 1;

  /// Live combo cap. The shop may lower this; it must not raise it past
  /// [maxTier].
  int comboCap = maxTier;

  int _consecutive = 0;

  int get consecutive => _consecutive;

  int get comboTier => tierFor(_consecutive, cap: comboCap);

  /// Misroutes and drops both count against the mistake limit.
  int get mistakes => misrouted + dropped;

  static int tierFor(int consecutive, {int cap = maxTier}) {
    final tier = 1 + consecutive ~/ sortsPerTier;
    return tier > cap ? cap : tier;
  }

  /// Registers a correct sort and returns the points gained.
  ///
  /// The tier advances *before* the award is calculated, so the sort that
  /// completes a tier is the one that pays the higher rate. That is the
  /// moment the player feels, so it is the moment that should pay.
  ///
  /// [scorePercent] and [payPercent] are integer rates around a base of 100,
  /// applied here so a shop multiplier cannot drift from the scoreboard.
  int registerCorrect({
    bool clutch = false,
    int scorePercent = 100,
    int payPercent = 100,
    int clutchBonus = RunScore.clutchBonus,
  }) {
    _consecutive++;
    sorted++;
    if (clutch) {
      clutchSaves++;
    }
    final tier = comboTier;
    if (tier > bestCombo) {
      bestCombo = tier;
    }
    final raw = baseValue * tier + (clutch ? clutchBonus : 0);
    final gained = raw * scorePercent ~/ 100;
    score += gained;
    _payTally += payPercent;
    pay += _payTally ~/ 100;
    _payTally %= 100;
    return gained;
  }

  /// Spends [cost] pay. Returns false and changes nothing if the run cannot
  /// afford it — a greyed memo must not take money.
  bool spend(int cost) {
    if (cost < 0 || pay < cost) {
      return false;
    }
    pay -= cost;
    return true;
  }

  void registerMisroute({int scorePenalty = 0}) {
    _applyMissPenalty(scorePenalty);
    misrouted++;
    _consecutive = 0;
  }

  void registerDrop({int scorePenalty = 0}) {
    _applyMissPenalty(scorePenalty);
    dropped++;
    _consecutive = 0;
  }

  void _applyMissPenalty(int scorePenalty) {
    if (scorePenalty <= 0) {
      return;
    }
    score -= scorePenalty;
    if (score < 0) {
      score = 0;
    }
  }

  /// Debug-only. Snaps combo and tallies so a review jump can show a roll
  /// without playing one. Never called from a release path.
  void debugForce({
    required int consecutive,
    required int sorted,
    int score = 0,
    int pay = 0,
  }) {
    _consecutive = consecutive;
    this.sorted = sorted;
    this.score = score;
    this.pay = pay;
    bestCombo = comboTier;
  }
}
