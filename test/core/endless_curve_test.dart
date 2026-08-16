import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/difficulty.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/core/run_tuning.dart';
import 'package:sort_rush/core/tuning_delta.dart';

/// The endless curve, checked against the numbers in `docs/level-spec.md`
/// rather than against itself.
void main() {
  const curve = EndlessCurve();

  group('the curve', () {
    test('starts where the spec says it starts', () {
      expect(curve.readWindowAt(0), 4.0);
      expect(curve.spawnIntervalAt(0), 2.4);
      expect(curve.maxActiveAt(0), 1);
    });

    test('the spawn interval reaches its floor at P = 87', () {
      // 2.4 - 0.020 * 87 = 0.66, still above; 88 is the first at the floor.
      expect(curve.spawnIntervalAt(86), greaterThan(0.65));
      expect(curve.spawnIntervalAt(88), 0.65);
      expect(curve.spawnIntervalAt(500), 0.65);
    });

    test('the read window reaches its floor at P = 93', () {
      expect(curve.readWindowAt(92), greaterThan(1.20));
      expect(curve.readWindowAt(94), 1.20);
      expect(curve.readWindowAt(500), 1.20);
    });

    test('the spawn interval floors before the read window', () {
      // Difficulty escalates by compressing recovery time before reading
      // time: taking away the read window is what makes a game feel unfair,
      // while taking away recovery is what makes it feel fast.
      var spawnFloored = 0;
      var readFloored = 0;
      for (var p = 0; p < 200; p++) {
        if (spawnFloored == 0 && curve.spawnIntervalAt(p) == 0.65) {
          spawnFloored = p;
        }
        if (readFloored == 0 && curve.readWindowAt(p) == 1.20) {
          readFloored = p;
        }
      }
      expect(spawnFloored, lessThan(readFloored));
    });

    test('packages on the belt step up every 18 sorts, capped at five', () {
      expect(curve.maxActiveAt(0), 1);
      expect(curve.maxActiveAt(17), 1);
      expect(curve.maxActiveAt(18), 2);
      expect(curve.maxActiveAt(72), 5);
      expect(curve.maxActiveAt(1000), 5);
    });

    test('it only ever tightens', () {
      var previousSpawn = double.infinity;
      var previousRead = double.infinity;
      var previousActive = 0;
      for (var p = 0; p < 300; p++) {
        expect(curve.spawnIntervalAt(p), lessThanOrEqualTo(previousSpawn));
        expect(curve.readWindowAt(p), lessThanOrEqualTo(previousRead));
        expect(curve.maxActiveAt(p), greaterThanOrEqualTo(previousActive));
        previousSpawn = curve.spawnIntervalAt(p);
        previousRead = curve.readWindowAt(p);
        previousActive = curve.maxActiveAt(p);
      }
    });

    test('it never asks for anything the floors would refuse', () {
      // The curve declining to ask and the clamp refusing are two separate
      // guarantees. If they ever disagree, one of them is wrong.
      for (var p = 0; p < 300; p++) {
        expect(curve.readWindowAt(p),
            greaterThanOrEqualTo(RunTuning.readWindowFloor));
        expect(curve.spawnIntervalAt(p),
            greaterThanOrEqualTo(RunTuning.spawnIntervalFloor));
      }
    });
  });

  group('the endless shift', () {
    test('is not part of the curated ladder', () {
      // It has no teaching objective and no pass target, so every guard in
      // levels_test.dart would be asking it the wrong questions.
      expect(kCuratedLevels.map((l) => l.id), isNot(contains(0)));
      expect(kEndlessShift.curve, isNotNull);
    });

    test('cannot be cleared, only ended', () {
      final engine = RunEngine(level: kEndlessShift, seed: 1)..start();
      for (var i = 0; i < 400; i++) {
        engine.update(1 / 60);
        final package = engine.frontMost;
        if (package != null) {
          engine.tapBin(kEndlessShift.routing.binFor(package.spec));
        }
      }
      expect(engine.outcome, isNot(RunOutcome.passed));
    });

    test('a curated level is unaffected by all of this', () {
      // Curated levels have no curve, so their numbers must not move with
      // pressure — a lesson you can feel changing underneath you is not a
      // lesson.
      final level = levelById(6);
      final atStart = RunTuning.resolve(level: level);
      final deepIn = RunTuning.resolve(level: level, pressure: 200);
      expect(deepIn.readWindow, atStart.readWindow);
      expect(deepIn.spawnInterval, atStart.spawnInterval);
      expect(deepIn.maxActive, atStart.maxActive);
    });
  });

  group('the curve through the engine', () {
    test('the belt tightens as the player sorts', () {
      final engine = RunEngine(level: kEndlessShift, seed: 5)..start();
      final opening = engine.tuning.spawnInterval;

      var guard = 0;
      while (engine.score.sorted < 30 && guard++ < 20000) {
        engine.update(1 / 60);
        final package = engine.frontMost;
        if (package != null && engine.phase == RunPhase.running) {
          engine.tapBin(kEndlessShift.routing.binFor(package.spec));
        }
      }

      expect(engine.score.sorted, greaterThanOrEqualTo(30));
      expect(engine.tuning.spawnInterval, lessThan(opening));
      expect(engine.tuning.maxActive, greaterThan(1));
    });

    test('a purchase and the curve compose without breaching the floors', () {
      final engine = RunEngine(level: kEndlessShift, seed: 5)..start();
      engine.applyModifier(const TuningDelta(spawnInterval: -99, readWindow: -99));

      var guard = 0;
      while (engine.score.sorted < 40 && guard++ < 30000) {
        engine.update(1 / 60);
        final package = engine.frontMost;
        if (package != null && engine.phase == RunPhase.running) {
          engine.tapBin(kEndlessShift.routing.binFor(package.spec));
        }
        expect(engine.tuning.readWindow,
            greaterThanOrEqualTo(RunTuning.readWindowFloor));
        expect(engine.tuning.spawnInterval,
            greaterThanOrEqualTo(RunTuning.spawnIntervalFloor));
      }
    });
  });
}
