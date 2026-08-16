import 'level_config.dart';
import 'pass_condition.dart';
import 'package_spec.dart';
import 'routing.dart';

/// The curated onboarding levels.
///
/// Parameters come from the approved table in docs/level-spec.md. They are
/// first-pass values derived from reaction-time ranges, not measured on this
/// game, and are expected to move after device testing.
final List<LevelConfig> kCuratedLevels = [
  LevelConfig(
    id: 1,
    title: 'INDUCTION',
    objective: 'Match one package type',
    tutorialCopy: 'ONE CHUTE.\nEVERYTHING GOES THERE.',
    routing: ShapeRouting(const [PackageShape.circle]),
    shapes: const [PackageShape.circle],
    colors: const [0],
    readWindow: 4.0,
    spawnInterval: 2.6,
    maxActive: 1,
    // Deliberately unfailable. A player who fails inside the first thirty
    // seconds of their first launch does not open the game again.
    mistakeLimit: null,
    passCondition: const SortTarget(10),
  ),
  LevelConfig(
    id: 2,
    title: 'THREE CHUTES',
    objective: 'Understand three bins',
    tutorialCopy: 'MATCH THE SHAPE\nTO THE CHUTE.',
    routing: ShapeRouting(const [
      PackageShape.circle,
      PackageShape.triangle,
      PackageShape.square,
    ]),
    shapes: const [
      PackageShape.circle,
      PackageShape.triangle,
      PackageShape.square,
    ],
    colors: const [0],
    readWindow: 4.0,
    spawnInterval: 2.4,
    maxActive: 1,
    mistakeLimit: 3,
    passCondition: const SortTarget(12),
  ),
  LevelConfig(
    id: 3,
    title: 'RELABELLED',
    objective: 'Recognize two package colors',
    // The switch is announced rather than sprung. Surprising the player here
    // would teach distrust, not skill; the difficulty is in re-training the
    // reflex, which stays hard even when you know it is coming.
    tutorialCopy: 'SHAPE NO LONGER MATTERS.\nMATCH THE PATTERN.',
    routing: ColorRouting(const [0, 1]),
    shapes: const [
      PackageShape.circle,
      PackageShape.triangle,
      PackageShape.square,
    ],
    colors: const [0, 1],
    readWindow: 3.6,
    spawnInterval: 2.2,
    maxActive: 2,
    mistakeLimit: 3,
    passCondition: const SortTarget(14),
  ),
  LevelConfig(
    id: 4,
    title: 'FULL SPECTRUM',
    objective: 'Recognize three package colors',
    tutorialCopy: 'THREE PATTERNS NOW.\nSAME JOB, LESS ROOM.',
    routing: ColorRouting(const [0, 1, 2]),
    shapes: const [
      PackageShape.circle,
      PackageShape.triangle,
      PackageShape.square,
    ],
    colors: const [0, 1, 2],
    readWindow: 3.2,
    spawnInterval: 1.9,
    maxActive: 2,
    mistakeLimit: 3,
    passCondition: const SortTarget(16),
  ),
  LevelConfig(
    id: 5,
    title: 'DAMAGED GOODS',
    objective: 'Read a package that changes, and chase a streak past it',
    tutorialCopy: 'SOME LABELS GO BAD.\nWAIT FOR THEM TO SETTLE.',
    routing: ColorRouting(const [0, 1, 2]),
    shapes: const [
      PackageShape.circle,
      PackageShape.triangle,
      PackageShape.square,
    ],
    colors: const [0, 1, 2],
    readWindow: 3.0,
    spawnInterval: 1.8,
    maxActive: 2,
    mistakeLimit: 3,
    // x4 rather than the x3 originally specified: x3 is reached on the tenth
    // clean sort, which cleared the level in ~21s against a 30-90s band and
    // made it shorter the better the player was. x4 needs fifteen and lands
    // at 30.0s. See docs/decision-log.md, "Level 5's pass condition".
    passCondition: const ComboTarget(4),
    // The teaching level for `DAMAGED`, so chaos is concentrated here rather
    // than sprinkled: a mechanic met once every ten packages reads as an
    // oddity, not a rule. The warning is at its most generous, and later
    // levels dilute the rate while shortening the warning.
    //
    // The combo target is what gives it teeth. Chaos is precisely what breaks
    // a streak, so the pressure this level teaches and the pressure it
    // applies are the same pressure.
    chaosRate: 0.30,
    telegraphSeconds: 1.2,
  ),
  LevelConfig(
    id: 6,
    title: 'BACKLOG',
    objective: 'Manage two active packages',
    tutorialCopy: 'THE BELT IS FILLING.\nONLY THE FRONT ONE COUNTS.',
    routing: ColorRouting(const [0, 1, 2]),
    shapes: const [
      PackageShape.circle,
      PackageShape.triangle,
      PackageShape.square,
    ],
    colors: const [0, 1, 2],
    readWindow: 2.8,
    spawnInterval: 1.4,
    maxActive: 3,
    mistakeLimit: 3,
    passCondition: const SortTarget(22),
    chaosRate: 0.20,
    telegraphSeconds: 1.0,
  ),
  LevelConfig(
    id: 7,
    title: 'LAST CALL',
    objective: 'Recover from a near miss',
    tutorialCopy: 'CATCH THEM AT THE EDGE.\nLATE STILL COUNTS.',
    routing: ColorRouting(const [0, 1, 2]),
    shapes: const [
      PackageShape.circle,
      PackageShape.triangle,
      PackageShape.square,
    ],
    colors: const [0, 1, 2],
    readWindow: 2.4,
    spawnInterval: 1.4,
    maxActive: 3,
    mistakeLimit: 3,
    // Volume alone would let a player clear this without ever cutting it
    // fine, which is the one thing the level exists to teach.
    passCondition: const EveryOf([SortTarget(20), ClutchTarget(2)]),
    chaosRate: 0.20,
    telegraphSeconds: 0.8,
  ),
  LevelConfig(
    id: 8,
    title: 'SKU MATCH',
    objective: 'Recognize shape plus color',
    tutorialCopy: 'SHAPE AND PATTERN.\nBOTH, OR NEITHER.',
    // Two chutes share a shape and two share a pattern, so reading only one
    // attribute leaves the player choosing between two chutes.
    routing: CompoundRouting(const [
      PackageSpec(shape: PackageShape.circle, colorIndex: 0),
      PackageSpec(shape: PackageShape.circle, colorIndex: 1),
      PackageSpec(shape: PackageShape.triangle, colorIndex: 0),
    ]),
    shapes: const [PackageShape.circle, PackageShape.triangle],
    colors: const [0, 1],
    spawnPool: const [
      PackageSpec(shape: PackageShape.circle, colorIndex: 0),
      PackageSpec(shape: PackageShape.circle, colorIndex: 1),
      PackageSpec(shape: PackageShape.triangle, colorIndex: 0),
    ],
    readWindow: 2.6,
    spawnInterval: 1.5,
    maxActive: 3,
    mistakeLimit: 3,
    // 19 rather than the 18 in docs/level-spec.md: at this level's 1.5s spawn
    // interval, 18 clears in 29.6s, under the spec's own 30-90s band. The
    // table's "<=1 misroute" half is not implemented — see the decision log.
    passCondition: const SortTarget(19),
    chaosRate: 0.25,
    telegraphSeconds: 0.7,
  ),
  LevelConfig(
    id: 9,
    title: 'FLOOD',
    objective: 'Combine speed and queue pressure',
    tutorialCopy: 'NO NEW RULES.\nJUST MORE OF THEM.',
    routing: CompoundRouting(const [
      PackageSpec(shape: PackageShape.circle, colorIndex: 0),
      PackageSpec(shape: PackageShape.circle, colorIndex: 1),
      PackageSpec(shape: PackageShape.triangle, colorIndex: 0),
    ]),
    shapes: const [PackageShape.circle, PackageShape.triangle],
    colors: const [0, 1],
    spawnPool: const [
      PackageSpec(shape: PackageShape.circle, colorIndex: 0),
      PackageSpec(shape: PackageShape.circle, colorIndex: 1),
      PackageSpec(shape: PackageShape.triangle, colorIndex: 0),
    ],
    readWindow: 2.2,
    spawnInterval: 1.1,
    maxActive: 4,
    mistakeLimit: 3,
    passCondition: const SortTarget(28),
    chaosRate: 0.30,
    telegraphSeconds: 0.6,
  ),
];

LevelConfig levelById(int id) =>
    kCuratedLevels.firstWhere((level) => level.id == id);
