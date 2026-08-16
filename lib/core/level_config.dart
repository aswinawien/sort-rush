import 'package_spec.dart';
import 'routing.dart';

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
    required this.passTarget,
  });

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

  /// Correct sorts needed to pass.
  final int passTarget;

  bool get isUnfailable => mistakeLimit == null;

  int get binCount => routing.bins.length;
}
