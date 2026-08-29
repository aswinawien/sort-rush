import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/core/shop.dart';

import 'test_level.dart';

void main() {
  final quota = EndlessShop.byId('quota-contract');

  group('quota contracts', () {
    test('the catalog slip is the relocated wager, not a delta', () {
      expect(quota.mechanic, CardMechanic.quota);
      expect(quota.delta.isEmpty, isTrue);
      expect(quota.body.contains(' · '), isTrue);
      expect(EndlessShop.quotaLastBandTarget, 12);
    });

    test('a clean target doubles pay earned during the contract', () {
      final engine = RunEngine(
        level: testLevel(spawnInterval: 0.65, maxActive: 1),
        seed: 1,
      )..start();
      engine.debugPin(quota);
      expect(engine.quotaLive, isTrue);
      expect(engine.quotaTarget, EndlessShop.quotaLastBandTarget);

      final payStart = engine.score.pay;
      for (var i = 0; i < EndlessShop.quotaLastBandTarget; i++) {
        if (engine.frontMost == null) {
          spawnNext(engine);
        }
        expect(sortCorrectly(engine), TapResult.correct);
      }

      final events = engine.drainEvents().whereType<QuotaSettledEvent>();
      expect(engine.quotaLive, isFalse);
      expect(events, hasLength(1));
      expect(events.single.success, isTrue);
      expect(engine.score.pay, payStart + events.single.segmentPay * 2);
      expect(engine.score.pay, greaterThan(payStart));
    });

    test('a misroute forfeits the segment pay', () {
      final engine = RunEngine(
        level: testLevel(spawnInterval: 0.65, maxActive: 1, mistakeLimit: 5),
        seed: 1,
      )..start();
      engine.debugPin(quota);
      // Ten clean sorts, not one. Pay accrues in cents now
      // (`RunScore.centsPerTier`), and a single sort at x1 is worth six of
      // them — so the old one-sort setup would forfeit nothing and the test
      // would pass without testing anything.
      for (var i = 0; i < 10; i++) {
        if (engine.frontMost == null) {
          spawnNext(engine);
        }
        expect(sortCorrectly(engine), TapResult.correct);
      }
      expect(engine.score.pay, greaterThan(0));
      if (engine.frontMost == null) {
        spawnNext(engine);
      }
      expect(sortWrongly(engine), TapResult.misroute);

      final events = engine.drainEvents().whereType<QuotaSettledEvent>();
      expect(engine.quotaLive, isFalse);
      expect(events, hasLength(1));
      expect(events.single.success, isFalse);
      expect(engine.score.pay, 0);
    });

    test('a drop forfeits the same way', () {
      final engine = RunEngine(
        level: testLevel(spawnInterval: 0.65, maxActive: 1, mistakeLimit: 5),
        seed: 2,
      )..start();
      engine.debugPin(quota);
      // Same reason as above: cents, so one sort is not yet one pay.
      for (var i = 0; i < 10; i++) {
        if (engine.frontMost == null) {
          spawnNext(engine);
        }
        expect(sortCorrectly(engine), TapResult.correct);
      }
      expect(engine.score.pay, greaterThan(0));
      spawnNext(engine);
      engine.update(engine.tuning.readWindow + 0.01);

      final events = engine.drainEvents().whereType<QuotaSettledEvent>();
      expect(engine.quotaLive, isFalse);
      expect(events.single.success, isFalse);
      expect(engine.score.pay, 0);
    });

    test('score is not the wagered number', () {
      final engine = RunEngine(
        level: testLevel(spawnInterval: 0.65, maxActive: 1, mistakeLimit: 5),
        seed: 3,
      )..start();
      engine.debugPin(quota);
      if (engine.frontMost == null) {
        spawnNext(engine);
      }
      sortCorrectly(engine);
      final scoreBeforeMiss = engine.score.score;
      if (engine.frontMost == null) {
        spawnNext(engine);
      }
      sortWrongly(engine);
      expect(engine.score.score, scoreBeforeMiss);
    });

    test('a pin at the first endless shop targets the next blind', () {
      final engine = RunEngine(level: kEndlessShift, seed: 4)..start();
      playToShop(engine);
      engine.debugPin(quota);
      expect(engine.quotaLive, isTrue);
      expect(
        engine.quotaTarget,
        EndlessShop.blinds[1] - engine.score.sorted,
      );
    });
  });
}
