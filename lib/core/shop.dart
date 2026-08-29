import 'tuning_delta.dart';

/// A memo that does more than retune numbers.
///
/// Most slips are [CardMechanic.none] plus a [TuningDelta]. Quota, hazardous
/// cargo and the scanner are named rules that cannot be expressed as a
/// delta. See docs/decision-log.md, 2026-08-23.
enum CardMechanic { none, quota, hazardous, scanner }

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
    this.mechanic = CardMechanic.none,
  });

  final String id;
  final String title;

  /// Short HUD label. A pin lasts the run; this is how the player still
  /// sees it after the board closes.
  final String chip;
  final String body;
  final int cost;
  final TuningDelta delta;

  /// Named rule this slip arms. [CardMechanic.none] means the delta is
  /// the whole effect.
  final CardMechanic mechanic;

  CardSpec withCost(int cost) => CardSpec(
        id: id,
        title: title,
        chip: chip,
        body: body,
        cost: cost,
        delta: delta,
        mechanic: mechanic,
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
  /// Boards now run the length of a real run, not just its opening.
  ///
  /// The first three are unchanged. Three more were added because a marathon
  /// on 2026-08-24 finished at P=488 holding **235 unspent pay** — the last
  /// board closed at P=80 and income never stopped, so the currency was
  /// visible, accumulating and inert. These give it somewhere to go.
  static const List<int> blinds = [22, 50, 80, 120, 170, 230];

  static const int offerCount = 3;

  /// Added to every slip each time the board opens later in the run.
  static const int costBumpPerBlind = 3;

  /// First redraw on a board. Each further redraw adds this again.
  static const int redrawBase = 3;
  static const int redrawBump = 3;

  /// Clean sorts that close a quota contract on the last board, where
  /// there is no next shop. Same +12 `OVERTIME` already uses as a band
  /// length. See docs/decision-log.md, "Quota contracts as the in-run wager".
  static const int quotaLastBandTarget = 12;

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
      body: 'CHAOS −0.15 · COMBO CAP −2',
      cost: 6,
      // Was -1, which was a 20% haircut against a ceiling of five. Against ten
      // it would have been 10%, and after the cents change it also cuts income
      // — a memo that was a real tradeoff would have become a near-free buy.
      delta: TuningDelta(chaosRate: -0.15, maxComboTier: -2),
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
    CardSpec(
      id: 'quota-contract',
      title: 'QUOTA CONTRACT',
      chip: 'QUOTA',
      body: '2× SEGMENT PAY · MISS FORFEITS IT',
      cost: 5,
      delta: TuningDelta.none,
      mechanic: CardMechanic.quota,
    ),
    CardSpec(
      id: 'hazardous-cargo',
      title: 'HAZARDOUS CARGO',
      chip: 'HAZARD',
      body: 'SCORE +50% · MATCHED CHUTE IS FORBIDDEN',
      cost: 6,
      delta: TuningDelta(scorePercent: 50),
      mechanic: CardMechanic.hazardous,
    ),
    CardSpec(
      id: 'scanner-reveal',
      title: 'SCANNER',
      chip: 'SCANNER',
      body: 'SCORE +50% · LABELS HIDE UNTIL THE LINE',
      cost: 6,
      delta: TuningDelta(scorePercent: 50),
      mechanic: CardMechanic.scanner,
    ),
  ];
}
