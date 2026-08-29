import 'tuning_delta.dart';

/// A named rule for the next Night Shift band.
///
/// Drawn when the memo board opens, printed in full, applied when the board
/// closes — pin or walk-on, same event. It is not a second shop. The player
/// picks a memo *knowing* the event. See docs/decision-log.md, "Night Shift
/// events".
class ShiftEventSpec {
  const ShiftEventSpec({
    required this.id,
    required this.title,
    required this.chip,
    required this.body,
    required this.delta,
  });

  final String id;
  final String title;

  /// Short HUD label while the event lasts this band.
  final String chip;
  final String body;
  final TuningDelta delta;
}

/// Boss-blind style events. Existing knobs only. No probability in the copy.
abstract final class ShiftEvents {
  static ShiftEventSpec byId(String id) =>
      catalog.firstWhere((event) => event.id == id);

  static const List<ShiftEventSpec> catalog = [
    ShiftEventSpec(
      id: 'corruption-notice',
      title: 'CORRUPTION NOTICE',
      chip: 'CORRUPTION',
      body: 'CHAOS +0.30 · THIS BAND',
      delta: TuningDelta(chaosRate: 0.30),
    ),
    ShiftEventSpec(
      id: 'rush-order',
      title: 'RUSH ORDER',
      chip: 'RUSH ORDER',
      body: 'PRIORITY +0.20 · THIS BAND',
      delta: TuningDelta(priorityRate: 0.20),
    ),
    ShiftEventSpec(
      id: 'lane-storm',
      title: 'LANE STORM',
      chip: 'LANE STORM',
      body: 'SWAP −12s · WARN HOLDS',
      delta: TuningDelta(swapInterval: -12),
    ),
    ShiftEventSpec(
      id: 'skeleton-crew',
      title: 'SKELETON CREW',
      chip: 'SKELETON',
      body: 'MAX ACTIVE −1 · THIS BAND',
      delta: TuningDelta(maxActive: -1),
    ),
    ShiftEventSpec(
      id: 'double-time',
      title: 'DOUBLE TIME',
      chip: 'DOUBLE TIME',
      body: 'SCORE +50% · READ WINDOW −0.25s',
      delta: TuningDelta(scorePercent: 50, readWindow: -0.25),
    ),
  ];
}
