import 'package:sort_rush/core/level_config.dart';
import 'package:sort_rush/core/package_spec.dart';
import 'package:sort_rush/core/pass_condition.dart';
import 'package:sort_rush/core/routing.dart';
import 'package:sort_rush/core/run_engine.dart';

const List<PackageShape> allShapes = [
  PackageShape.circle,
  PackageShape.triangle,
  PackageShape.square,
];

/// A three-bin shape-routed level with every knob exposed, so each test can
/// isolate the one pressure it cares about.
LevelConfig testLevel({
  double readWindow = 2.0,
  double spawnInterval = 1.0,
  int maxActive = 1,
  int? mistakeLimit = 3,
  PassCondition passCondition = const SortTarget(1000),
  List<int> colors = const [0],
  double chaosRate = 0.0,
  double telegraphSeconds = 0.0,
  RoutingRule? routing,
}) {
  return LevelConfig(
    id: 99,
    title: 'TEST',
    objective: 'test',
    tutorialCopy: 'test',
    routing: routing ?? ShapeRouting(allShapes),
    shapes: allShapes,
    colors: colors,
    readWindow: readWindow,
    spawnInterval: spawnInterval,
    maxActive: maxActive,
    mistakeLimit: mistakeLimit,
    passCondition: passCondition,
    chaosRate: chaosRate,
    telegraphSeconds: telegraphSeconds,
  );
}

/// Routes the front-most package into its correct bin.
TapResult sortCorrectly(RunEngine engine) {
  final package = engine.frontMost!;
  return engine.tapBin(engine.binFor(package.spec));
}

/// Routes the front-most package into a bin that is definitely wrong.
TapResult sortWrongly(RunEngine engine) {
  final package = engine.frontMost!;
  final correct = engine.binFor(package.spec);
  return engine.tapBin((correct + 1) % engine.liveBinCount);
}

/// Walks past a depot board so a long scripted run is not a shop test.
void skipShopIfOpen(RunEngine engine) {
  if (engine.isShopping) {
    engine.skipShop();
  }
}

/// Plays correctly until the depot board opens, or gives up.
void playToShop(RunEngine engine, {int steps = 8000}) {
  var n = 0;
  while (!engine.isShopping &&
      engine.phase != RunPhase.finished &&
      n++ < steps) {
    if (engine.frontMost != null) {
      sortCorrectly(engine);
    }
    engine.update(1 / 60);
  }
}

/// Advances just far enough for the next package to spawn.
///
/// Tests used to pass a spawn interval of 0.01 to get a package on demand.
/// That is below the 0.65s fairness floor, so `RunTuning` now clamps it — the
/// fixtures were describing levels the game would never allow. This reads the
/// live interval instead, so it stays correct if a floor ever moves.
void spawnNext(RunEngine engine) =>
    engine.update(engine.tuning.spawnInterval + 0.01);
