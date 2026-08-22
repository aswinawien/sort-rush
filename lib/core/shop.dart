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

  CardSpec withCost(int cost) => CardSpec(
        id: id,
        title: title,
        chip: chip,
        body: body,
        cost: cost,
        delta: delta,
      );
}

/// Endless shop: seeded offers between blinds.
///
/// Leftover pay can carry into the next endless run, capped. List prices
/// rise with the blind index this run, not with a career counter.
abstract final class EndlessShop {
  /// Pressure at which the belt drains and the board opens. Chosen to sit
  /// *between* chute grows (18, 45) so a shop and a layout change never
  /// share a moment.
  static const List<int> blinds = [22, 50, 80];

  static const int offerCount = 3;

  /// Added to every slip each time the board opens later in the run.
  static const int costBumpPerBlind = 3;

  /// First redraw on a board. Each further redraw adds this again.
  static const int redrawBase = 3;
  static const int redrawBump = 3;

  /// Leftover pay that may start the next endless run. Not an unlock tree.
  static const int walletCap = 12;

  static int clampWallet(int pay) {
    if (pay < 0) {
      return 0;
    }
    if (pay > walletCap) {
      return walletCap;
    }
    return pay;
  }

  static int slipCost(CardSpec card, int blindIndex, {int extraBump = 0}) =>
      card.cost + blindIndex * (costBumpPerBlind + extraBump);

  static int redrawCost(int redrawsUsed) =>
      redrawBase + redrawsUsed * redrawBump;

  static CardSpec byId(String id) =>
      catalog.firstWhere((card) => card.id == id);

  /// Visible tradeoffs. RNG picks which three appear; the player sees both
  /// sides and pins one. No probability in the copy, no curse after the tap.
  static const List<CardSpec> catalog = [
    CardSpec(
      id: 'long-warn',
      title: 'LONG WARN',
      chip: 'LONG WARN',
      body: 'TELEGRAPH +0.40s · CHAOS +0.10',
      cost: 4,
      delta: TuningDelta(telegraphSeconds: 0.40, chaosRate: 0.10),
    ),
    CardSpec(
      id: 'double-stamp',
      title: 'DOUBLE STAMP',
      chip: 'DBL STAMP',
      body: 'SCORE +50% · MISS TAXES THE TIER',
      cost: 6,
      delta: TuningDelta(scorePercent: 50, missScorePenalty: 1),
    ),
    CardSpec(
      id: 'wide-gap',
      title: 'WIDE GAP',
      chip: 'WIDE GAP',
      body: 'SPAWN INTERVAL +0.15s · PAY −40%',
      cost: 5,
      delta: TuningDelta(spawnInterval: 0.15, payPercent: -40),
    ),
    CardSpec(
      id: 'hot-belt',
      title: 'HOT BELT',
      chip: 'HOT BELT',
      body: 'SCORE +50% · READ WINDOW −0.25s',
      cost: 6,
      delta: TuningDelta(scorePercent: 50, readWindow: -0.25),
    ),
    CardSpec(
      id: 'clean-shift',
      title: 'CLEAN SHIFT',
      chip: 'CLEAN SHIFT',
      body: 'CHAOS −0.15 · COMBO CAP x4',
      cost: 6,
      delta: TuningDelta(chaosRate: -0.15, maxComboTier: -1),
    ),
    CardSpec(
      id: 'priority-bonus',
      title: 'PRIORITY BONUS',
      chip: 'PRI BONUS',
      body: 'PRIORITY SCORE +50% · PRIORITY +0.15',
      cost: 5,
      delta: TuningDelta(priorityScorePercent: 50, priorityRate: 0.15),
    ),
    CardSpec(
      id: 'salvage-crew',
      title: 'SALVAGE CREW',
      chip: 'SALVAGE',
      body: 'CLUTCH +15 · SCORE −25%',
      cost: 5,
      delta: TuningDelta(clutchBonus: 15, scorePercent: -25),
    ),
    CardSpec(
      id: 'overtime',
      title: 'OVERTIME',
      chip: 'OVERTIME',
      body: 'NEXT BLIND +12 · PRICES +3/BOARD',
      cost: 4,
      delta: TuningDelta(blindShift: 12, costBump: 3),
    ),
    CardSpec(
      id: 'quiet-machine',
      title: 'QUIET MACHINE',
      chip: 'QUIET MACH',
      body: 'MAX ACTIVE −1 · SCORE −30%',
      cost: 5,
      delta: TuningDelta(maxActive: -1, scorePercent: -30),
    ),
  ];
}
