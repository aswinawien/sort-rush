/// How a run's base numbers move as pressure rises.
///
/// Curated levels have no curve: their numbers are fixed for the whole shift,
/// which is what makes a lesson teachable. Endless has one, and it is the only
/// thing that makes endless *endless* rather than a very long level.
abstract class DifficultyCurve {
  const DifficultyCurve();

  double readWindowAt(int pressure);
  double spawnIntervalAt(int pressure);
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

  /// Where the read window reaches its floor and the curve stops moving.
  static const int phaseTwoEnd = 130;

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
