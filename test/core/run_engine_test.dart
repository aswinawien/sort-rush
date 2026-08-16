import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/package_spec.dart';
import 'package:sort_rush/core/pass_condition.dart';
import 'package:sort_rush/core/run_engine.dart';

import 'test_level.dart';

void main() {
  group('lifecycle', () {
    test('starts ready and spawns nothing until started', () {
      final engine = RunEngine(level: testLevel(), seed: 1);
      expect(engine.phase, RunPhase.ready);
      expect(engine.active, isEmpty);
    });

    test('start puts one package on the belt immediately', () {
      final engine = RunEngine(level: testLevel(), seed: 1)..start();
      expect(engine.phase, RunPhase.running);
      expect(engine.active, hasLength(1));
      // The player should not spend the first spawn interval staring at an
      // empty belt.
      expect(engine.elapsed, 0);
    });

    test('a paused engine does not advance', () {
      final engine = RunEngine(level: testLevel(), seed: 1)..start();
      final before = engine.frontMost!.progress;
      engine.pause();
      engine.update(1.0);
      expect(engine.frontMost!.progress, before);

      engine.resume();
      engine.update(1.0);
      expect(engine.frontMost!.progress, greaterThan(before));
    });
  });

  group('routing a tap', () {
    test('a correct sort scores and clears the package', () {
      final engine = RunEngine(level: testLevel(), seed: 1)..start();
      expect(sortCorrectly(engine), TapResult.correct);
      expect(engine.score.sorted, 1);
      expect(engine.score.score, 10);
      expect(engine.active, isEmpty);
    });

    test('a misroute counts a mistake and breaks the combo', () {
      final engine = RunEngine(level: testLevel(), seed: 1)..start();
      sortCorrectly(engine);
      engine.update(1.0);

      expect(sortWrongly(engine), TapResult.misroute);
      expect(engine.score.misrouted, 1);
      expect(engine.score.consecutive, 0);
      expect(engine.active, isEmpty);
    });

    test('tapping an empty belt is a no-op, not a mistake', () {
      final engine = RunEngine(level: testLevel(), seed: 1)..start();
      sortCorrectly(engine);
      expect(engine.active, isEmpty);

      expect(engine.tapBin(0), TapResult.ignored);
      expect(engine.tapBin(1), TapResult.ignored);
      expect(engine.score.mistakes, 0);
      expect(engine.score.score, 10);
    });

    test('an out-of-range bin index is ignored', () {
      final engine = RunEngine(level: testLevel(), seed: 1)..start();
      expect(engine.tapBin(-1), TapResult.ignored);
      expect(engine.tapBin(99), TapResult.ignored);
      expect(engine.score.mistakes, 0);
      expect(engine.active, hasLength(1));
    });

    test('rapid taps route exactly one package and never double-route', () {
      final engine = RunEngine(level: testLevel(), seed: 1)..start();
      final target = engine.level.routing.binFor(engine.frontMost!.spec);

      final results = [for (var i = 0; i < 5; i++) engine.tapBin(target)];

      expect(results.first, TapResult.correct);
      expect(results.skip(1), everyElement(TapResult.ignored));
      expect(engine.score.sorted, 1);
      expect(engine.score.mistakes, 0);
    });

    test('taps outside the running phase are ignored', () {
      final engine = RunEngine(level: testLevel(), seed: 1);
      expect(engine.tapBin(0), TapResult.ignored);
      engine.start();
      engine.pause();
      expect(engine.tapBin(0), TapResult.ignored);
      expect(engine.score.sorted, 0);
    });
  });

  group('the belt', () {
    test('a package crossing the sort line is dropped', () {
      final engine = RunEngine(
        level: testLevel(readWindow: 2.0, spawnInterval: 100),
        seed: 1,
      )..start();

      engine.update(2.1);
      expect(engine.score.dropped, 1);
      expect(engine.active, isEmpty);
    });

    test('timeToLine shrinks as the package advances, and is null when empty',
        () {
      final engine = RunEngine(
        level: testLevel(readWindow: 2.0, spawnInterval: 100),
        seed: 1,
      )..start();

      expect(engine.timeToLine, closeTo(2.0, 0.001));
      engine.update(0.5);
      expect(engine.timeToLine, closeTo(1.5, 0.001));

      sortCorrectly(engine);
      expect(engine.timeToLine, isNull);
    });

    test('the belt respects maxActive', () {
      final engine = RunEngine(
        level: testLevel(readWindow: 100, spawnInterval: 0.65, maxActive: 2),
        seed: 1,
      )..start();

      for (var i = 0; i < 20; i++) {
        engine.update(0.1);
      }
      expect(engine.active.length, lessThanOrEqualTo(2));
    });

    test('frontMost is the package nearest the sort line', () {
      final engine = RunEngine(
        level: testLevel(readWindow: 100, spawnInterval: 1.0, maxActive: 3),
        seed: 1,
      )..start();

      engine.update(1.0);
      engine.update(1.0);
      expect(engine.active.length, greaterThan(1));

      final front = engine.frontMost!;
      for (final package in engine.active) {
        expect(package.progress, lessThanOrEqualTo(front.progress));
      }
    });
  });

  group('ending a run', () {
    test('reaching the pass target passes the run', () {
      final engine = RunEngine(
        level: testLevel(
            readWindow: 100,
            spawnInterval: 0.65,
            passCondition: const SortTarget(3)),
        seed: 1,
      )..start();

      for (var i = 0; i < 3; i++) {
        sortCorrectly(engine);
        if (engine.phase == RunPhase.running) {
          spawnNext(engine);
        }
      }

      expect(engine.outcome, RunOutcome.passed);
      expect(engine.phase, RunPhase.ending);
    });

    test('hitting the mistake limit fails the run', () {
      final engine = RunEngine(
        level: testLevel(
          readWindow: 100,
          spawnInterval: 0.65,
          mistakeLimit: 2,
        ),
        seed: 1,
      )..start();

      sortWrongly(engine);
      spawnNext(engine);
      sortWrongly(engine);

      expect(engine.outcome, RunOutcome.failed);
      expect(engine.phase, RunPhase.ending);
    });

    test('the ending phase holds before the run is over', () {
      final engine = RunEngine(
        level: testLevel(
            readWindow: 100,
            spawnInterval: 0.65,
            passCondition: const SortTarget(1)),
        seed: 1,
      )..start();

      sortCorrectly(engine);
      expect(engine.phase, RunPhase.ending);
      expect(engine.isOver, isFalse);

      engine.update(RunEngine.endingDuration + 0.01);
      expect(engine.phase, RunPhase.finished);
      expect(engine.isOver, isTrue);
    });

    test('an unfailable level never fails, however many mistakes', () {
      final engine = RunEngine(
        level: testLevel(
          readWindow: 100,
          spawnInterval: 0.65,
          mistakeLimit: null,
        ),
        seed: 1,
      )..start();

      for (var i = 0; i < 12; i++) {
        sortWrongly(engine);
        spawnNext(engine);
      }

      expect(engine.score.mistakes, 12);
      expect(engine.phase, RunPhase.running);
      expect(engine.outcome, RunOutcome.none);
    });
  });

  group('events', () {
    test('a correct sort emits a sorted event carrying the points gained', () {
      final engine = RunEngine(level: testLevel(), seed: 1)..start();
      engine.drainEvents();

      sortCorrectly(engine);
      final events = engine.drainEvents();

      expect(events, hasLength(1));
      final event = events.single as PackageSortedEvent;
      expect(event.gained, 10);
      expect(event.tier, 1);
    });

    test('crossing a tier emits a combo event alongside the sort', () {
      final engine = RunEngine(
        level: testLevel(readWindow: 100, spawnInterval: 0.65),
        seed: 1,
      )..start();

      for (var i = 0; i < 4; i++) {
        sortCorrectly(engine);
        spawnNext(engine);
      }
      engine.drainEvents();

      sortCorrectly(engine);
      final events = engine.drainEvents();

      expect(events.whereType<ComboAdvancedEvent>(), hasLength(1));
      expect(events.whereType<ComboAdvancedEvent>().single.tier, 2);
    });

    test('draining clears the queue', () {
      final engine = RunEngine(level: testLevel(), seed: 1)..start();
      sortCorrectly(engine);
      expect(engine.drainEvents(), isNotEmpty);
      expect(engine.drainEvents(), isEmpty);
    });
  });

  group('determinism', () {
    List<PackageSpec> spawnSequence(int seed, int count) {
      final engine = RunEngine(
        level: testLevel(readWindow: 1000, spawnInterval: 1.0),
        seed: seed,
      )..start();

      final specs = <PackageSpec>[engine.frontMost!.spec];
      while (specs.length < count) {
        sortCorrectly(engine);
        engine.update(1.0);
        specs.add(engine.frontMost!.spec);
      }
      return specs;
    }

    test('the same seed reproduces the same packages', () {
      expect(spawnSequence(4242, 30), equals(spawnSequence(4242, 30)));
    });

    test('a different seed produces a different run', () {
      expect(spawnSequence(1, 30), isNot(equals(spawnSequence(2, 30))));
    });

    test('the same seed and input timeline reproduce the same score', () {
      int scoreFor(int seed) {
        final engine = RunEngine(
          level: testLevel(readWindow: 3.0, spawnInterval: 0.5, maxActive: 3),
          seed: seed,
        )..start();

        // A fixed timeline: alternate correct and wrong sorts on a metronome.
        var step = 0;
        while (engine.phase == RunPhase.running && step < 40) {
          if (engine.frontMost != null) {
            if (step.isEven) {
              sortCorrectly(engine);
            } else {
              sortWrongly(engine);
            }
          }
          engine.update(0.25);
          step++;
        }
        return engine.score.score;
      }

      expect(scoreFor(777), scoreFor(777));
    });
  });
}
