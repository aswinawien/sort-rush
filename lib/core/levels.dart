import 'level_config.dart';
import 'package_spec.dart';
import 'routing.dart';

/// The curated levels shipped in the Milestone 3 prototype.
///
/// Parameters come from the approved table in docs/level-spec.md. They are
/// first-pass values derived from reaction-time ranges, not measured on this
/// game, and are expected to move after device testing.
final List<LevelConfig> kPrototypeLevels = [
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
    passTarget: 10,
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
    passTarget: 12,
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
    passTarget: 14,
  ),
];

LevelConfig levelById(int id) =>
    kPrototypeLevels.firstWhere((level) => level.id == id);
