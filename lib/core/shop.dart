import 'tuning_delta.dart';

/// One memo on the depot board.
///
/// Effects are additive [TuningDelta]s. A card whose text would contain a
/// probability is rejected on sight — that is output randomness, the thing
/// this shop exists to avoid. See docs/decision-log.md, "Endless shop".
class CardSpec {
  const CardSpec({
    required this.id,
    required this.title,
    required this.chip,
    required this.body,
    required this.cost,
    required this.delta,
  });

  final String id;
  final String title;

  /// Short HUD label. A pin lasts the run; this is how the player still
  /// sees it after the board closes.
  final String chip;
  final String body;
  final int cost;
  final TuningDelta delta;
}

/// Endless shop: seeded offers between blinds, within-run pay only.
abstract final class EndlessShop {
  /// Pressure at which the belt drains and the board opens. Chosen to sit
  /// *between* chute grows (18, 45) so a shop and a layout change never
  /// share a moment.
  static const List<int> blinds = [22, 50, 80];

  static const int offerCount = 3;

  /// Short v1 pool: parameter retunes plus one give-and-take. No extra
  /// chute — that would breach the 2–4 endless ceiling. No probability.
  static const List<CardSpec> catalog = [
    CardSpec(
      id: 'slow-belt',
      title: 'SLOW THE BELT',
      chip: 'SLOW BELT',
      body: 'READ WINDOW +0.40s',
      cost: 5,
      delta: TuningDelta(readWindow: 0.40),
    ),
    CardSpec(
      id: 'wide-gap',
      title: 'WIDE GAP',
      chip: 'WIDE GAP',
      body: 'SPAWN INTERVAL +0.15s',
      cost: 5,
      delta: TuningDelta(spawnInterval: 0.15),
    ),
    CardSpec(
      id: 'extra-pip',
      title: '+1 MISTAKE ALLOWED',
      chip: '+1 LIFE',
      body: 'ONE MORE LIFE THIS RUN',
      cost: 7,
      delta: TuningDelta(mistakeLimit: 1),
    ),
    CardSpec(
      id: 'calm-labels',
      title: 'CALM LABELS',
      chip: 'CALM',
      body: 'CHAOS −0.15',
      cost: 6,
      delta: TuningDelta(chaosRate: -0.15),
    ),
    CardSpec(
      id: 'long-warn',
      title: 'LONG WARN',
      chip: 'LONG WARN',
      body: 'TELEGRAPH +0.40s',
      cost: 4,
      delta: TuningDelta(telegraphSeconds: 0.40),
    ),
    CardSpec(
      id: 'overtime',
      title: 'OVERTIME PAY',
      chip: 'OT PAY',
      body: 'PAY RATE +50%',
      cost: 4,
      delta: TuningDelta(payPercent: 50),
    ),
    CardSpec(
      id: 'double-stamp',
      title: 'DOUBLE STAMP',
      chip: 'DBL STAMP',
      body: 'SCORE +50%',
      cost: 6,
      delta: TuningDelta(scorePercent: 50),
    ),
    CardSpec(
      id: 'high-volume',
      title: 'HIGH VOLUME',
      chip: 'HIGH VOL',
      body: 'SPAWN −0.10s · SCORE +50%',
      cost: 3,
      delta: TuningDelta(spawnInterval: -0.10, scorePercent: 50),
    ),
  ];
}
