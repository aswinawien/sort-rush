import 'difficulty.dart';
import 'package_spec.dart';
import 'pass_condition.dart';
import 'routing.dart';
import 'score_state.dart';

/// A fully data-driven level definition.
///
/// Every difficulty knob lives here rather than in scattered constants, so
/// tuning is a data edit and difficulty can be asserted in tests.
class LevelConfig {
  const LevelConfig({
    required this.id,
    required this.title,
    required this.objective,
    required this.tutorialCopy,
    required this.routing,
    required this.shapes,
    required this.colors,
    required this.readWindow,
    required this.spawnInterval,
    required this.maxActive,
    required this.mistakeLimit,
    required this.passCondition,
    this.chaosRate = 0.0,
    this.telegraphSeconds = 0.0,
    this.priorityRate = 0.0,
    this.spawnPool,
    this.curve,
    this.comboCap = RunScore.curatedTierCap,
  })  : assert(chaosRate >= 0 && chaosRate <= 1, 'chaosRate is a probability'),
        assert(
          priorityRate >= 0 && priorityRate <= 1,
          'priorityRate is a probability',
        ),
        assert(
          chaosRate == 0 || telegraphSeconds > 0,
          'chaos without a telegraph is a coin flip, not a skill',
        );

  /// 1-based level number.
  final int id;

  final String title;

  /// The one pressure this level teaches.
  final String objective;

  /// Shown before the level starts. Expressive but obvious.
  final String tutorialCopy;

  final RoutingRule routing;

  /// Shapes this level may spawn.
  final List<PackageShape> shapes;

  /// Hue indices this level may spawn.
  final List<int> colors;

  /// How this run's numbers move as pressure rises, or null for a level whose
  /// numbers are fixed.
  ///
  /// Every curated level is fixed: a lesson you can feel changing underneath
  /// you is not a lesson. Only endless carries a curve.
  final DifficultyCurve? curve;

  /// Combo ceiling for this shift.
  ///
  /// Curated shifts keep `RunScore.curatedTierCap`: their sort targets are in
  /// the twenties, so a fifty-sort tier could never be reached and advertising
  /// it would be dishonest. Endless opts up to `RunScore.maxTier`.
  final int comboCap;

  /// Exact packages this level may spawn, overriding the cross product of
  /// [shapes] and [colors].
  ///
  /// Compound levels need this: with three chutes owning three specific
  /// (shape, hue) pairs, most of the nine possible combinations have no
  /// destination at all, and spawning one would be unwinnable.
  final List<PackageSpec>? spawnPool;

  /// Seconds from spawn to the sort line. This is the player's read window and
  /// the primary fairness lever.
  final double readWindow;

  /// Seconds between spawns.
  final double spawnInterval;

  /// Maximum packages on the belt at once.
  final int maxActive;

  /// Mistakes allowed before the run fails. `null` means the level cannot be
  /// failed — level 1 uses this deliberately.
  final int? mistakeLimit;

  /// What clearing this shift requires.
  final PassCondition passCondition;

  /// Chance that a spawned package is `DAMAGED` and will change shape in
  /// transit. Zero for every level until the chaos ramp is gated.
  final double chaosRate;

  /// Chance that a spawned package is stamped `PRIORITY`. Mutually exclusive
  /// with [chaosRate] at spawn: two "the obvious answer is wrong" mechanics
  /// on one package read as arbitrary.
  final double priorityRate;

  /// How long a `DAMAGED` package shows its corrupted state before it
  /// changes.
  ///
  /// The telegraph *is* the mechanic. A silent change punishes a decision the
  /// player already committed to; a telegraphed one teaches them to withhold
  /// the tap until the package settles. Escalation shortens this — it never
  /// removes it. See docs/decision-log.md, "`DAMAGED` defined as a
  /// telegraphed shape-shift".
  final double telegraphSeconds;

  bool get isUnfailable => mistakeLimit == null;

  int get binCount => routing.bins.length;
}
