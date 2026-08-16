// A command-line benchmark: printing is the entire point of it.
// ignore_for_file: avoid_print
// Headless benchmark of the gameplay core at maximum pressure.
//
// Runs with plain `dart run`, no Flutter and no device, because lib/core
// imports neither Flame nor Flutter. That architectural rule is what makes
// this measurable at all.
//
//   ~/flutter/bin/dart run tool/benchmark_core.dart
//
// What this does and does not tell you: it measures the simulation, not the
// rendering. Frame budget on a real device is dominated by paint and raster
// work this benchmark never touches. Treat a regression here as a real
// regression, but never treat a good number here as evidence of 60fps.
import 'package:sort_rush/core/level_config.dart';
import 'package:sort_rush/core/package_spec.dart';
import 'package:sort_rush/core/pass_condition.dart';
import 'package:sort_rush/core/routing.dart';
import 'package:sort_rush/core/run_engine.dart';

const _allShapes = [
  PackageShape.circle,
  PackageShape.triangle,
  PackageShape.square,
];

/// Endless at its hardest: the fairness floors, five packages, chaos on.
LevelConfig _maxPressure({double chaosRate = 0.35}) => LevelConfig(
      id: 999,
      title: 'BENCH',
      objective: 'bench',
      tutorialCopy: 'bench',
      routing: ShapeRouting(_allShapes),
      shapes: _allShapes,
      colors: const [0, 1, 2],
      readWindow: 1.20,
      spawnInterval: 0.65,
      maxActive: 5,
      mistakeLimit: null,
      passCondition: const SortTarget(1 << 30),
      chaosRate: chaosRate,
      telegraphSeconds: chaosRate > 0 ? 0.5 : 0.0,
    );

void _report(String label, int frames, Duration elapsed) {
  final perFrame = elapsed.inMicroseconds / frames;
  // 60fps is a 16667us budget for everything: simulation, layout, paint,
  // raster. Simulation should be a rounding error inside it.
  final share = perFrame / 16666.7 * 100;
  print('$label: ${perFrame.toStringAsFixed(3)} us/frame '
      '(${share.toStringAsFixed(3)}% of a 60fps budget)');
}

int _run(LevelConfig level, int frames, {required bool sorting}) {
  final engine = RunEngine(level: level, seed: 1234)..start();
  var sorted = 0;
  for (var i = 0; i < frames; i++) {
    engine.update(1 / 60);
    // The presentation layer drains every frame, so the benchmark must too —
    // otherwise the event list grows unboundedly and this measures a leak
    // rather than a frame.
    engine.drainEvents();
    if (sorting && i % 12 == 0) {
      final package = engine.frontMost;
      if (package != null) {
        engine.tapBin(level.routing.binFor(package.spec));
        sorted++;
      }
    }
  }
  return sorted;
}

void main() {
  const frames = 300000;

  // Warm the JIT so the first measurement is not the slowest.
  _run(_maxPressure(), 20000, sorting: true);

  var watch = Stopwatch()..start();
  _run(_maxPressure(chaosRate: 0), frames, sorting: false);
  watch.stop();
  _report('drifting belt, no chaos ', frames, watch.elapsed);

  watch = Stopwatch()..start();
  _run(_maxPressure(), frames, sorting: false);
  watch.stop();
  _report('drifting belt, chaos on ', frames, watch.elapsed);

  watch = Stopwatch()..start();
  final sorted = _run(_maxPressure(), frames, sorting: true);
  watch.stop();
  _report('sorting under chaos     ', frames, watch.elapsed);
  print('  ($sorted packages routed)');
}
