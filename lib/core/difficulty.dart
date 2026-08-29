/// How a run's base numbers move as pressure rises.
///
/// Curated levels have no curve: their numbers are fixed for the whole shift,
/// which is what makes a lesson teachable. Endless has one, and it is the only
/// thing that makes endless *endless* rather than a very long level.
abstract class DifficultyCurve {
  const DifficultyCurve();

  double readWindowAt(int pressure);
  double spawnIntervalAt(int pressure);

  /// Extra chaos added at this pressure. Zero for a curve with no third phase.
  ///
  /// Separate from timing on purpose: the read window and the spawn interval
  /// are the fairness contract in `docs/product-brief.md` and both sit on
  /// their floors by P=130, so anything escalating past that point has to be
  /// something other than time.
  double chaosBonusAt(int pressure) => 0;

  /// How many packages arrive together at this pressure. One means no burst.
  ///
  /// Density is `readWindow / spawnInterval`, and both are pinned to their
  /// fairness floors by the time this matters — so the only way left to crowd
  /// the belt is to change the *shape* of arrivals rather than their rate.
  int burstSizeAt(int pressure) => 1;
}

/// The endless curve.
///
/// Two phases, in the order `docs/level-spec.md` actually asks for: *"escalate
/// by compressing `S` toward its floor **before** compressing `T` — taking
/// away the read window is what makes a game feel unfair, while taking away
/// recovery time is what makes it feel fast."*
///
/// ```
/// Phase 1  P 0  → 38    S: 1.10 → 0.65   T holds 2.60
/// Phase 2  P 38 → 130   S holds 0.65     T: 2.60 → 1.20
/// ```
///
/// The arc that produces: **the belt crowds first, then the reading time
/// collapses.** How many packages are in flight is `readWindow / spawnInterval`
/// — so compressing the spawn gap while holding the read window is the only
/// thing that actually fills the belt. Phase one is a queue problem; phase two
/// is a reaction problem. That is a genuinely different second half rather than
/// the same half played faster.
///
/// The original single-phase curve compressed both at once, which held their
/// ratio near-constant and meant density never changed for the entire run — and
/// it opened far easier than level 9, taking around sixty sorts to climb back
/// to where onboarding had already left the player. Recorded in
/// `docs/decision-log.md`.
class EndlessCurve extends DifficultyCurve {
  const EndlessCurve();

  /// Where endless begins: level 9's spawn interval, and a read window a
  /// little longer so the belt has room to crowd before it tightens.
  static const double openingSpawnInterval = 1.10;
  static const double openingReadWindow = 2.60;

  /// Below these the curve stops asking. `RunTuning` clamps to the same values
  /// regardless — this is the curve declining rather than the clamp refusing.
  static const double spawnIntervalFloor = 0.65;
  static const double readWindowFloor = 1.20;

  /// Where the spawn gap bottoms out and the read window starts to give.
  static const int phaseOneEnd = 38;

  /// Where the read window reaches its floor.
  static const int phaseTwoEnd = 130;

  /// Phase three: what escalates once time cannot.
  ///
  /// Measured on 2026-08-24: a perfect run reached **P=488 with zero
  /// mistakes**, because both timing levers bottom out at [phaseTwoEnd] and
  /// nothing replaced them. The run had no terminal condition at all.
  ///
  /// Chaos is the lever, because the alternative — lowering the floors — is
  /// forbidden without device evidence that does not exist yet. It ramps from
  /// [phaseTwoEnd] and is clamped to 1.0 by `RunTuning`, which it reaches
  /// around P=380: every package corrupting, which is a real end state rather
  /// than another plateau.
  static const double phaseThreeChaosPerPressure = 0.004;

  /// Where packages start arriving in clusters rather than singly.
  ///
  /// **Average spacing is unchanged.** A group of `n` is followed by a longer
  /// recovery gap, so the belt still receives one package per
  /// `spawnInterval` on average — what changes is that they arrive lumpy
  /// instead of metronomic. Density spikes inside a cluster and the player
  /// gets breathing room after it.
  ///
  /// **This is still a real reduction in local reading time** — see
  /// [burstGapFraction] — and it presses on what the fairness floor exists to
  /// protect. It wants the device session in `docs/playtest-2026-08-24.md`
  /// before the thresholds below are treated as settled.
  static const int burstTwoAt = 170;
  static const int burstThreeAt = 300;

  /// Spacing inside a cluster, as a fraction of the spawn interval.
  ///
  /// At the 0.65s floor this is ~0.33s between cluster members. The floor
  /// itself is untouched — the *average* gap is still `spawnInterval` — but a
  /// player inside a cluster genuinely has half the usual time to read the
  /// next package. That is the trade being made, stated plainly.
  static const double burstGapFraction = 0.5;

  @override
  double spawnIntervalAt(int pressure) {
    if (pressure >= phaseOneEnd) {
      return spawnIntervalFloor;
    }
    final t = pressure / phaseOneEnd;
    return openingSpawnInterval -
        (openingSpawnInterval - spawnIntervalFloor) * t;
  }

  @override
  int burstSizeAt(int pressure) {
    if (pressure >= burstThreeAt) {
      return 3;
    }
    if (pressure >= burstTwoAt) {
      return 2;
    }
    return 1;
  }

  @override
  double chaosBonusAt(int pressure) {
    if (pressure <= phaseTwoEnd) {
      return 0;
    }
    return (pressure - phaseTwoEnd) * phaseThreeChaosPerPressure;
  }

  @override
  double readWindowAt(int pressure) {
    if (pressure <= phaseOneEnd) {
      return openingReadWindow;
    }
    if (pressure >= phaseTwoEnd) {
      return readWindowFloor;
    }
    final t = (pressure - phaseOneEnd) / (phaseTwoEnd - phaseOneEnd);
    return openingReadWindow - (openingReadWindow - readWindowFloor) * t;
  }
}
