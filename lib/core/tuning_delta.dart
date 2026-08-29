/// An additive change to the numbers the belt runs on.
///
/// Additive on purpose. A stack of deltas is a sum, so the order they were
/// bought in can never change the result, and "which card did that" stays
/// answerable — which it would not be if effects multiplied. The project's
/// rule is that every failure is explainable, and that has to survive four
/// purchases stacking.
///
/// Percentages are integer points added to a base of 100, so the whole money
/// and scoring path stays in integers and a replay reproduces exactly rather
/// than within an epsilon.
class TuningDelta {
  const TuningDelta({
    this.readWindow = 0,
    this.spawnInterval = 0,
    this.maxActive = 0,
    this.mistakeLimit = 0,
    this.chaosRate = 0,
    this.telegraphSeconds = 0,
    this.scorePercent = 0,
    this.payPercent = 0,
    this.priorityRate = 0,
    this.priorityScorePercent = 0,
    this.clutchBonus = 0,
    this.maxComboTier = 0,
    this.missScorePenalty = 0,
    this.blindShift = 0,
    this.costBump = 0,
    this.swapInterval = 0,
  });

  /// The identity: what a run carries before anything is bought.
  static const TuningDelta none = TuningDelta();

  final double readWindow;
  final double spawnInterval;
  final int maxActive;
  final int mistakeLimit;
  final double chaosRate;
  final double telegraphSeconds;

  /// Points added to a base of 100. `+50` means one and a half times.
  final int scorePercent;
  final int payPercent;

  /// Added to the live PRIORITY spawn chance. A positive value can introduce
  /// PRIORITY before the endless unlock because the memo is a choice, and
  /// level 10 already taught the stamp.
  final double priorityRate;

  /// Extra integer points on PRIORITY sorts only, added to [scorePercent]
  /// for that one package.
  final int priorityScorePercent;

  /// Added to [RunScore.clutchBonus].
  final int clutchBonus;

  /// Added to [RunScore.maxTier]. Negative lowers the cap.
  final int maxComboTier;

  /// How many current-tier sorts a miss deducts. Zero is off.
  final int missScorePenalty;

  /// Extra packages required before later shop blinds. The first blind is
  /// never shifted — it is how the player reaches the board that sells this.
  final int blindShift;

  /// Extra added to the per-board slip price bump.
  final int costBump;

  /// Seconds added to the endless lane-swap interval. Negative brings the
  /// next swap sooner. The live value is still floored so a storm cannot
  /// spam the board.
  final double swapInterval;

  TuningDelta operator +(TuningDelta other) => TuningDelta(
        readWindow: readWindow + other.readWindow,
        spawnInterval: spawnInterval + other.spawnInterval,
        maxActive: maxActive + other.maxActive,
        mistakeLimit: mistakeLimit + other.mistakeLimit,
        chaosRate: chaosRate + other.chaosRate,
        telegraphSeconds: telegraphSeconds + other.telegraphSeconds,
        scorePercent: scorePercent + other.scorePercent,
        payPercent: payPercent + other.payPercent,
        priorityRate: priorityRate + other.priorityRate,
        priorityScorePercent: priorityScorePercent + other.priorityScorePercent,
        clutchBonus: clutchBonus + other.clutchBonus,
        maxComboTier: maxComboTier + other.maxComboTier,
        missScorePenalty: missScorePenalty + other.missScorePenalty,
        blindShift: blindShift + other.blindShift,
        costBump: costBump + other.costBump,
        swapInterval: swapInterval + other.swapInterval,
      );

  /// Inverse of this delta. Used to peel a band-limited event off the
  /// stack without rebuilding from pins.
  TuningDelta get negated => TuningDelta(
        readWindow: -readWindow,
        spawnInterval: -spawnInterval,
        maxActive: -maxActive,
        mistakeLimit: -mistakeLimit,
        chaosRate: -chaosRate,
        telegraphSeconds: -telegraphSeconds,
        scorePercent: -scorePercent,
        payPercent: -payPercent,
        priorityRate: -priorityRate,
        priorityScorePercent: -priorityScorePercent,
        clutchBonus: -clutchBonus,
        maxComboTier: -maxComboTier,
        missScorePenalty: -missScorePenalty,
        blindShift: -blindShift,
        costBump: -costBump,
        swapInterval: -swapInterval,
      );

  /// Whether this delta would change anything at all.
  bool get isEmpty =>
      readWindow == 0 &&
      spawnInterval == 0 &&
      maxActive == 0 &&
      mistakeLimit == 0 &&
      chaosRate == 0 &&
      telegraphSeconds == 0 &&
      scorePercent == 0 &&
      payPercent == 0 &&
      priorityRate == 0 &&
      priorityScorePercent == 0 &&
      clutchBonus == 0 &&
      maxComboTier == 0 &&
      missScorePenalty == 0 &&
      blindShift == 0 &&
      costBump == 0 &&
      swapInterval == 0;
}
