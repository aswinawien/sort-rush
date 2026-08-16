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

  TuningDelta operator +(TuningDelta other) => TuningDelta(
        readWindow: readWindow + other.readWindow,
        spawnInterval: spawnInterval + other.spawnInterval,
        maxActive: maxActive + other.maxActive,
        mistakeLimit: mistakeLimit + other.mistakeLimit,
        chaosRate: chaosRate + other.chaosRate,
        telegraphSeconds: telegraphSeconds + other.telegraphSeconds,
        scorePercent: scorePercent + other.scorePercent,
        payPercent: payPercent + other.payPercent,
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
      payPercent == 0;
}
