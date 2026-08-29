import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/core/run_tuning.dart';
import 'package:sort_rush/core/tuning_delta.dart';

import 'test_level.dart';

/// `RunTuning` is the one place a run's live numbers come from.
///
/// Its job is to make the fairness floors structurally unreachable rather than
/// something every future card has to remember. Most of these tests are about
/// what it refuses to do.
void main() {
  group('resolving from a level', () {
    test('with no modifiers it is the level', () {
      for (final level in kCuratedLevels) {
        final tuning = RunTuning.resolve(level: level);
        expect(tuning.readWindow, level.readWindow,
            reason: 'level ${level.id}');
        expect(tuning.spawnInterval, level.spawnInterval);
        expect(tuning.maxActive, level.maxActive);
        expect(tuning.mistakeLimit, level.mistakeLimit);
        expect(tuning.chaosRate, level.chaosRate);
        expect(tuning.scorePercent, 100);
        expect(tuning.payPercent, 100);
      }
    });

    test('a level that cannot be failed stays that way', () {
      // Level 1's whole job is being unfailable. No purchase may introduce a
      // way to lose it.
      final tuning = RunTuning.resolve(
        level: levelById(1),
        modifiers: const TuningDelta(mistakeLimit: -5),
      );
      expect(tuning.mistakeLimit, isNull);
    });
  });

  group('the floors hold', () {
    test('no stack of modifiers can breach the read window floor', () {
      // Deliberately abusive: far past anything the card set could reach.
      final tuning = RunTuning.resolve(
        level: levelById(9),
        modifiers: const TuningDelta(readWindow: -99),
      );
      expect(tuning.readWindow, RunTuning.readWindowFloor);
    });

    test('no stack of modifiers can breach the swap interval floor', () {
      final tuning = RunTuning.resolve(
        level: kEndlessShift,
        modifiers: const TuningDelta(swapInterval: -99),
      );
      expect(tuning.swapInterval, RunTuning.swapIntervalFloor);
    });

    test('no stack of modifiers can breach the spawn interval floor', () {
      final tuning = RunTuning.resolve(
        level: levelById(9),
        modifiers: const TuningDelta(spawnInterval: -99),
      );
      expect(tuning.spawnInterval, RunTuning.spawnIntervalFloor);
    });

    test('max active is held between one and the ceiling', () {
      expect(
        RunTuning.resolve(
          level: levelById(1),
          modifiers: const TuningDelta(maxActive: 99),
        ).maxActive,
        RunTuning.maxActiveCeiling,
      );
      expect(
        RunTuning.resolve(
          level: levelById(9),
          modifiers: const TuningDelta(maxActive: -99),
        ).maxActive,
        1,
      );
    });

    test('chaos can never arrive without a warning', () {
      // The level has no chaos and therefore no telegraph. A modifier that
      // switches chaos on must not produce a mechanic that fires silently —
      // that is the exact failure DAMAGED was rejected for.
      final clean = levelById(4);
      expect(clean.chaosRate, 0);
      expect(clean.telegraphSeconds, 0);

      final tuning = RunTuning.resolve(
        level: clean,
        modifiers: const TuningDelta(chaosRate: 0.3),
      );

      expect(tuning.chaosRate, 0.3);
      expect(tuning.telegraphSeconds,
          greaterThanOrEqualTo(RunTuning.telegraphFloor));
    });

    test('the warning can be shortened but never removed', () {
      final tuning = RunTuning.resolve(
        level: levelById(5),
        modifiers: const TuningDelta(telegraphSeconds: -99),
      );
      expect(tuning.telegraphSeconds, RunTuning.telegraphFloor);
    });

    test('rates never reach zero', () {
      final tuning = RunTuning.resolve(
        level: levelById(5),
        modifiers: const TuningDelta(scorePercent: -500, payPercent: -500),
      );
      expect(tuning.scorePercent, greaterThan(0));
      expect(tuning.payPercent, greaterThan(0));
    });

    test('combo cap cannot fall below the system floor', () {
      final tuning = RunTuning.resolve(
        level: levelById(5),
        modifiers: const TuningDelta(maxComboTier: -99),
      );
      expect(tuning.maxComboTier, RunTuning.minComboTier);
    });

    test('priority rate extra is clamped to a probability', () {
      expect(
        RunTuning.resolve(
          level: levelById(5),
          modifiers: const TuningDelta(priorityRate: 4),
        ).priorityRate,
        1,
      );
      expect(
        RunTuning.resolve(
          level: levelById(5),
          modifiers: const TuningDelta(priorityRate: -1),
        ).priorityRate,
        0,
      );
    });
  });

  group('modifiers stack additively', () {
    test('order of purchase cannot change the result', () {
      const a = TuningDelta(readWindow: 0.4, spawnInterval: -0.15);
      const b = TuningDelta(readWindow: -0.2, chaosRate: 0.1);

      final ab = RunTuning.resolve(level: levelById(6), modifiers: a + b);
      final ba = RunTuning.resolve(level: levelById(6), modifiers: b + a);

      expect(ab.readWindow, ba.readWindow);
      expect(ab.spawnInterval, ba.spawnInterval);
      expect(ab.chaosRate, ba.chaosRate);
    });
  });

  group('in the engine', () {
    test('a modifier does not touch a package already in flight', () {
      // The decisive test, and the reason the read window is anchored on the
      // package rather than read from the level each tick. A purchase must
      // never change the answer to a question the player is already
      // considering.
      final engine = RunEngine(
        level: testLevel(readWindow: 4.0, spawnInterval: 1000),
        seed: 1,
      )..start();
      final package = engine.frontMost!;

      for (var i = 0; i < 60; i++) {
        engine.update(1 / 60);
      }
      final before = engine.timeToLine!;

      engine.applyModifier(const TuningDelta(readWindow: -2.5));

      expect(engine.tuning.readWindow, 1.5, reason: 'the belt did change');
      expect(package.readWindow, 4.0, reason: 'the package did not');
      expect(engine.timeToLine, before, reason: 'its deadline did not move');
    });

    test('a package spawned after a modifier gets the new numbers', () {
      final engine = RunEngine(
        level: testLevel(readWindow: 4.0, spawnInterval: 0.65),
        seed: 1,
      )..start();

      engine.applyModifier(const TuningDelta(readWindow: -2.0));
      sortCorrectly(engine);
      spawnNext(engine);

      expect(engine.frontMost!.readWindow, 2.0);
    });

    test('tuning is not rebuilt on ticks where nothing happened', () {
      final engine = RunEngine(
        level: testLevel(readWindow: 4.0, spawnInterval: 1000),
        seed: 1,
      )..start();
      final before = engine.tuning;

      for (var i = 0; i < 30; i++) {
        engine.update(1 / 60);
      }

      expect(identical(engine.tuning, before), isTrue);
    });
  });
}
