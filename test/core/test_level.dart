import 'package:sort_rush/core/level_config.dart';
import 'package:sort_rush/core/package_spec.dart';
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
  int passTarget = 1000,
  List<int> colors = const [0],
}) {
  return LevelConfig(
    id: 99,
    title: 'TEST',
    objective: 'test',
    tutorialCopy: 'test',
    routing: ShapeRouting(allShapes),
    shapes: allShapes,
    colors: colors,
    readWindow: readWindow,
    spawnInterval: spawnInterval,
    maxActive: maxActive,
    mistakeLimit: mistakeLimit,
    passTarget: passTarget,
  );
}

/// Routes the front-most package into its correct bin.
TapResult sortCorrectly(RunEngine engine) {
  final package = engine.frontMost!;
  return engine.tapBin(engine.level.routing.binFor(package.spec));
}

/// Routes the front-most package into a bin that is definitely wrong.
TapResult sortWrongly(RunEngine engine) {
  final package = engine.frontMost!;
  final correct = engine.level.routing.binFor(package.spec);
  return engine.tapBin((correct + 1) % engine.level.binCount);
}
