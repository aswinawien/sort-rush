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

  /// Absolute combo ceiling. Endless reaches it; curated levels do not.
  ///
  /// A tier costs [sortsPerTier] consecutive clean sorts, so x10 is fifty in a
  /// row — a long-run goal endless previously had no room for. The curated
  /// ladder keeps [curatedTierCap]: those shifts run 30–90 seconds against
  /// sort targets in the twenties, so fifty consecutive is not reachable
  /// inside one and a ceiling it cannot touch would be a lie in the HUD.
  static const int maxTier = 10;

  /// The ceiling a curated shift plays under. `LevelConfig.comboCap` defaults
  /// to this; only the endless shift opts up to [maxTier].
  static const int curatedTierCap = 5;

  /// The tier that stops being a number and becomes a state.
  static const int maxxxxTier = maxTier;

  /// Extra points for sorting a package in the last moments before it drops.
  /// Small by design: the reward for a clutch save is mostly that you did not
  /// lose the package.
  static const int clutchBonus = 5;

  /// Cents earned per correct sort, indexed by combo tier 1–5.
  ///
  /// Endless money is deliberately a trickle at x1 and a flood at x5, so
  /// income tracks *how well* a run is going rather than how long it has
  /// lasted. At x1 a sort is worth six cents, so the first whole pay takes
  /// about ten sorts; at x5 it is worth ninety-five and nearly every sort
  /// pays. Breaking a combo drops income back to the trickle immediately —
  /// that is the point. The board is funded by streaks, not by attendance.
  ///
  /// Sized against the first board: a clean run reaches it at P=22 holding
  /// roughly eight pay, against a catalog whose cheapest slip costs four. So
  /// the opening board buys one memo and makes the player choose, where a
  /// flat rate handed them twenty-two pay and no decision at all.
  ///
  /// One hundred cents make one pay. That fractional tally is not new; what
  /// is new is that the tiers no longer all pay the same flat rate.
  /// **Flat above x5, deliberately.** Tiers six to ten pay the x5 rate.
  ///
  /// Letting the top tiers keep scaling would have made the late game worse,
  /// not better: the last board closes long before a run ends, so extra income
  /// past that point has nothing to buy and simply piles up. A marathon run
  /// measured on 2026-08-24 finished holding 235 unspent pay at P=488. Combo
  /// past five is therefore a *score* goal — which is what MAXXXX is for —
  /// and not an income one.
  static const List<int> centsPerTier = [
    6, 15, 30, 55, 95, // x1–x5: income climbs with the streak
    95, 95, 95, 95, 95, // x6–x10: prestige, not payroll
  ];

  static int centsFor(int tier) => centsPerTier[tier.clamp(1, maxTier) - 1];

  int score = 0;
  int sorted = 0;

  /// Correct sorts made inside the clutch window.
  int clutchSaves = 0;
  int misrouted = 0;
  int dropped = 0;

  /// Shop cash. Endless spends it; leftover can carry into the next
  /// endless run, capped. Integer, so a replay stays exact — the fractional
  /// part lives in [_payTally] as cents and never reaches the player as a
  /// decimal. See [centsPerTier].
  int pay = 0;
  int _payTally = 0;

  /// Highest tier reached this run. Starts at 1 because x1 is a real tier,
  /// not the absence of one.
  int bestCombo = 1;

  /// Live combo cap. The shop may lower this; it must not raise it past
  /// [maxTier].
  int comboCap = curatedTierCap;

  int _consecutive = 0;

  int get consecutive => _consecutive;

  int get comboTier => tierFor(_consecutive, cap: comboCap);

  /// Whether the run is at the terminal combo state rather than a numbered
  /// tier. The HUD prints `MAXXXX` instead of `COMBO xN` here.
  bool get isMaxxxx => comboTier >= maxxxxTier;

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
    _payTally += centsFor(tier) * payPercent ~/ 100;
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
