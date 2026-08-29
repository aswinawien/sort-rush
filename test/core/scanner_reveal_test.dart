import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/core/run_tuning.dart';
import 'package:sort_rush/core/shop.dart';

import 'test_level.dart';

void main() {
  final scanner = EndlessShop.byId('scanner-reveal');

  group('scanner reveal', () {
    test('the catalog slip does not touch readWindow', () {
      expect(scanner.mechanic, CardMechanic.scanner);
      expect(scanner.delta.readWindow, 0);
      expect(scanner.delta.scorePercent, 50);
      expect(RunEngine.scannerRevealAt, 0.60);
    });

    test('labels stay hidden until the progress threshold', () {
      final engine = RunEngine(
        level: testLevel(readWindow: 2.0, spawnInterval: 0.65, maxActive: 1),
        seed: 1,
      )..start();
      engine.debugPin(scanner);
      expect(engine.scannerReveal, isTrue);
      expect(engine.tuning.readWindow, 2.0);

      if (engine.frontMost == null) {
        spawnNext(engine);
      }
      final package = engine.frontMost!;
      expect(engine.labelVisible(package), isFalse);

      engine.update(package.readWindow * (RunEngine.scannerRevealAt - 0.05));
      expect(engine.frontMost, isNotNull);
      expect(engine.frontMost!.progress, lessThan(RunEngine.scannerRevealAt));
      expect(engine.labelVisible(engine.frontMost!), isFalse);

      engine.update(package.readWindow * 0.10);
      expect(engine.frontMost, isNotNull);
      expect(
        engine.frontMost!.progress,
        greaterThanOrEqualTo(RunEngine.scannerRevealAt),
      );
      expect(engine.labelVisible(engine.frontMost!), isTrue);
    });

    test('on the floor the reveal lands inside the clutch window', () {
      final engine = RunEngine(
        level: testLevel(
          readWindow: RunTuning.readWindowFloor,
          spawnInterval: 0.65,
          maxActive: 1,
        ),
        seed: 1,
      )..start();
      engine.debugPin(scanner);
      if (engine.frontMost == null) {
        spawnNext(engine);
      }
      final package = engine.frontMost!;
      engine.update(package.readWindow * RunEngine.scannerRevealAt);
      expect(engine.labelVisible(engine.frontMost!), isTrue);
      final remaining =
          (1 - engine.frontMost!.progress) * engine.frontMost!.readWindow;
      expect(remaining, lessThanOrEqualTo(RunEngine.clutchWindow));
      expect(engine.tuning.readWindow, RunTuning.readWindowFloor);
    });

    test('without the memo every package is visible', () {
      final engine = RunEngine(
        level: testLevel(spawnInterval: 0.65, maxActive: 1),
        seed: 1,
      )..start();
      if (engine.frontMost == null) {
        spawnNext(engine);
      }
      expect(engine.scannerReveal, isFalse);
      expect(engine.labelVisible(engine.frontMost!), isTrue);
    });
  });
}
