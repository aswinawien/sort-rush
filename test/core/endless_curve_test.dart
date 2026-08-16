import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/difficulty.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/core/run_tuning.dart';
import 'package:sort_rush/core/tuning_delta.dart';

/// The endless curve.
///
/// Escalation happens in the order `docs/level-spec.md` states — spawn gap
/// first, read window second — because that order is what makes the belt
/// crowd before it gets fast. These tests hold that order, not just the
/// endpoints.
void main() {
  const curve = EndlessCurve();

  /// How many packages can be in flight at once: a package lives one read
  /// window, and one spawns per interval.
  int density(int pressure) =>
      (curve.readWindowAt(pressure) ~/ curve.spawnIntervalAt(pressure)) + 1;

  group('where it starts', () {
    test('it opens at the pace level 9 ended on', () {
      final nine = levelById(9);
      expect(curve.spawnIntervalAt(0), nine.spawnInterval);
      expect(curve.readWindowAt(0), greaterThan(nine.readWindow));
      expect(curve.readWindowAt(0), lessThan(nine.readWindow + 0.5));
    });

    test('it never opens easier than the shift before it', () {
      // The original curve opened at a 4.0s read window and a 2.4s spawn gap
      // against level 9's 2.2 and 1.1, then took about sixty sorts to climb
      // back. A player who has just cleared the hardest shift should not be
      // handed a warm-up.
      final nine = levelById(9);
      expect(curve.spawnIntervalAt(0), lessThanOrEqualTo(nine.spawnInterval));
    });
  });

  group('phase one crowds the belt', () {
    test('the spawn gap closes while the read window holds', () {
      final openingRead = curve.readWindowAt(0);
      for (var p = 0; p <= EndlessCurve.phaseOneEnd; p++) {
        expect(curve.readWindowAt(p), openingRead,
            reason: 'the read window moved during phase one, at P=$p');
      }
      expect(curve.spawnIntervalAt(EndlessCurve.phaseOneEnd),
          EndlessCurve.spawnIntervalFloor);
    });

    test('density actually rises, which the old curve never did', () {
      // The whole point of compressing the spawn gap first. Packages in
      // flight is readWindow / spawnInterval, so holding one while shrinking
      // the other is the only thing that fills the belt.
      expect(density(EndlessCurve.phaseOneEnd), greaterThan(density(0)));
      expect(density(EndlessCurve.phaseOneEnd), greaterThanOrEqualTo(4));
    });
  });

  group('phase two takes the reading time', () {
    test('the spawn gap holds at its floor while the read window closes', () {
      for (var p = EndlessCurve.phaseOneEnd; p <= EndlessCurve.phaseTwoEnd; p++) {
        expect(curve.spawnIntervalAt(p), EndlessCurve.spawnIntervalFloor,
            reason: 'the spawn gap moved during phase two, at P=$p');
      }
      expect(curve.readWindowAt(EndlessCurve.phaseTwoEnd),
          EndlessCurve.readWindowFloor);
    });

    test('it settles and stays settled', () {
      expect(curve.readWindowAt(500), EndlessCurve.readWindowFloor);
      expect(curve.spawnIntervalAt(500), EndlessCurve.spawnIntervalFloor);
    });
  });

  group('invariants', () {
    test('it only ever tightens', () {
      var previousSpawn = double.infinity;
      var previousRead = double.infinity;
      for (var p = 0; p < 300; p++) {
        expect(curve.spawnIntervalAt(p), lessThanOrEqualTo(previousSpawn));
        expect(curve.readWindowAt(p), lessThanOrEqualTo(previousRead));
        previousSpawn = curve.spawnIntervalAt(p);
        previousRead = curve.readWindowAt(p);
      }
    });

    test('it never asks for anything the floors would refuse', () {
      for (var p = 0; p < 300; p++) {
        expect(curve.readWindowAt(p),
            greaterThanOrEqualTo(RunTuning.readWindowFloor));
        expect(curve.spawnIntervalAt(p),
            greaterThanOrEqualTo(RunTuning.spawnIntervalFloor));
      }
    });

    test('the spawn gap floors before the read window', () {
      // The stated escalation rule, held as a property rather than as two
      // endpoints that happen to line up.
      var spawnFloored = -1;
      var readFloored = -1;
      for (var p = 0; p < 300; p++) {
        if (spawnFloored < 0 &&
            curve.spawnIntervalAt(p) == EndlessCurve.spawnIntervalFloor) {
          spawnFloored = p;
        }
        if (readFloored < 0 &&
            curve.readWindowAt(p) == EndlessCurve.readWindowFloor) {
          readFloored = p;
        }
      }
      expect(spawnFloored, lessThan(readFloored));
    });
  });

  group('the endless shift', () {
    test('is not part of the curated ladder', () {
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
      final level = levelById(6);
      final atStart = RunTuning.resolve(level: level);
      final deepIn = RunTuning.resolve(level: level, pressure: 200);
      expect(deepIn.readWindow, atStart.readWindow);
      expect(deepIn.spawnInterval, atStart.spawnInterval);
      expect(deepIn.maxActive, atStart.maxActive);
    });
  });

  group('through the engine', () {
    test('the belt genuinely fills up during phase one', () {
      // Plays like a person rather than a reflex: reads the package for most
      // of its travel before committing. Sorting the instant one appears
      // empties the belt faster than anyone could and would measure nothing.
      final engine = RunEngine(level: kEndlessShift, seed: 5)..start();
      var peak = 0;

      var guard = 0;
      while (engine.score.sorted < EndlessCurve.phaseOneEnd && guard++ < 40000) {
        engine.update(1 / 60);
        if (engine.active.length > peak) {
          peak = engine.active.length;
        }
        final package = engine.frontMost;
        if (package != null &&
            package.progress > 0.6 &&
            engine.phase == RunPhase.running) {
          engine.tapBin(kEndlessShift.routing.binFor(package.spec));
        }
      }

      expect(
        engine.score.sorted,
        greaterThanOrEqualTo(EndlessCurve.phaseOneEnd),
      );
      expect(peak, greaterThan(2),
          reason: 'phase one never crowded the belt beyond two packages');
    });

    test('a purchase and the curve compose without breaching the floors', () {
      final engine = RunEngine(level: kEndlessShift, seed: 5)..start();
      engine.applyModifier(
        const TuningDelta(spawnInterval: -99, readWindow: -99),
      );

      var guard = 0;
      while (engine.score.sorted < 40 && guard++ < 40000) {
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
