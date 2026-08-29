import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/board.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/core/run_tuning.dart';
import 'package:sort_rush/core/shift_events.dart';
import 'package:sort_rush/core/tuning_delta.dart';

import 'test_level.dart';

void main() {
  group('the shift-event catalog', () {
    test('every event is a visible tradeoff with a short chip', () {
      expect(ShiftEvents.catalog, hasLength(5));
      for (final event in ShiftEvents.catalog) {
        expect(event.body.contains(' · '), isTrue, reason: event.id);
        expect(event.chip, isNotEmpty, reason: event.id);
        expect(event.chip.length, lessThanOrEqualTo(12), reason: event.id);
        expect(event.delta.isEmpty, isFalse, reason: event.id);
      }
    });

    test('no event text hides a probability', () {
      for (final event in ShiftEvents.catalog) {
        expect(
          event.body.contains('%') && event.body.contains('chance'),
          isFalse,
          reason: event.id,
        );
        expect(event.title.contains('%'), isFalse, reason: event.id);
      }
    });
  });

  group('drawing from the shop stream', () {
    test('the same seed draws the same event', () {
      String draw(int seed) {
        final engine = RunEngine(level: kEndlessShift, seed: seed)..start();
        playToShop(engine);
        return engine.pendingEvent!.id;
      }

      expect(draw(12), draw(12));
      final ids = {for (var seed = 1; seed <= 20; seed++) draw(seed)};
      expect(ids.length, greaterThan(1));
    });

    test('ASK AGAIN replaces the slips, not the pending event', () {
      final engine = RunEngine(
        level: kEndlessShift,
        seed: 4,
        startingPay: 12,
      )..start();
      playToShop(engine);
      engine.score.pay = 30;
      final eventId = engine.pendingEvent!.id;
      final firstHand = engine.shopOffers.map((c) => c.id).toList();

      expect(engine.redrawShop(), isTrue);
      expect(engine.pendingEvent!.id, eventId);
      expect(engine.shopOffers.map((c) => c.id), isNot(firstHand));
    });
  });

  group('apply and expire', () {
    test('walk-on applies the event with no pin', () {
      final engine = RunEngine(level: kEndlessShift, seed: 4)..start();
      playToShop(engine);
      final pending = engine.pendingEvent!;
      expect(engine.active, isEmpty);

      engine.skipShop();

      expect(engine.pinned, isEmpty);
      expect(engine.pendingEvent, isNull);
      expect(engine.liveEvent!.id, pending.id);
    });

    test('a pin applies the memo and the event', () {
      final engine = RunEngine(level: kEndlessShift, seed: 4)..start();
      playToShop(engine);
      final pending = engine.pendingEvent!;
      final cheap = engine.shopOffers.indexWhere(
        (card) => card.cost <= engine.score.pay,
      );
      expect(engine.buy(cheap), isTrue);
      expect(engine.pinned, hasLength(1));
      expect(engine.liveEvent!.id, pending.id);
    });

    test('the event expires when the next shop opens', () {
      final engine = RunEngine(level: kEndlessShift, seed: 4)..start();
      playToShop(engine);
      final first = engine.pendingEvent!;
      engine.skipShop();
      expect(engine.liveEvent!.id, first.id);

      playToShop(engine);
      expect(engine.isShopping, isTrue);
      expect(engine.liveEvent, isNull);
      expect(engine.pendingEvent, isNotNull);
      expect(engine.active, isEmpty);

      if (first.id == 'corruption-notice') {
        expect(
          engine.tuning.chaosRate,
          lessThan(ShiftEvents.byId(first.id).delta.chaosRate),
        );
      }
      if (first.id == 'skeleton-crew') {
        expect(engine.tuning.maxActive, RunTuning.maxActiveCeiling);
      }
    });

    test('applying an event does not touch in-flight packages', () {
      final engine = RunEngine(level: kEndlessShift, seed: 4)..start();
      playToShop(engine);
      expect(engine.active, isEmpty);
      final pending = engine.pendingEvent!;
      engine.skipShop();
      expect(engine.active, isEmpty);

      engine.update(engine.tuning.spawnInterval + 0.01);
      final spawned = engine.frontMost!;
      final window = spawned.readWindow;

      if (pending.delta.readWindow != 0) {
        expect(engine.tuning.readWindow, isNot(kEndlessShift.readWindow));
      }
      expect(spawned.readWindow, window);
    });
  });

  group('fairness', () {
    test('no event can breach the floors, even stacked with memos', () {
      var stack = TuningDelta.none;
      for (final event in ShiftEvents.catalog) {
        stack = stack + event.delta;
      }
      stack = stack + const TuningDelta(readWindow: -99, spawnInterval: -99);

      final tuning = RunTuning.resolve(
        level: kEndlessShift,
        pressure: 200,
        modifiers: stack,
      );
      expect(
          tuning.readWindow, greaterThanOrEqualTo(RunTuning.readWindowFloor));
      expect(
        tuning.spawnInterval,
        greaterThanOrEqualTo(RunTuning.spawnIntervalFloor),
      );
      expect(tuning.swapInterval,
          greaterThanOrEqualTo(RunTuning.swapIntervalFloor));
      expect(tuning.maxActive, greaterThanOrEqualTo(1));
    });

    test('a negated event peels cleanly off the stack', () {
      const delta =
          TuningDelta(chaosRate: 0.30, maxActive: -1, swapInterval: -12);
      expect((delta + delta.negated).isEmpty, isTrue);
    });
  });

  group('Lane Storm', () {
    test('hurries the next swap and keeps the telegraph readable', () {
      final engine = _shopWithEvent('lane-storm');
      engine.skipShop();
      expect(engine.tuning.swapInterval, lessThan(EndlessBoard.swapInterval));
      expect(
        engine.tuning.swapInterval,
        greaterThanOrEqualTo(RunTuning.swapIntervalFloor),
      );

      final openedAt = engine.elapsed;
      var steps = 0;
      while ((engine.telegraph == null ||
              engine.telegraph!.kind != LayoutChangeKind.swap) &&
          engine.phase != RunPhase.finished &&
          steps++ < 8000) {
        skipShopIfOpen(engine);
        if (engine.frontMost != null) {
          sortCorrectly(engine);
        }
        engine.update(1 / 60);
      }

      skipShopIfOpen(engine);
      expect(engine.telegraph!.kind, LayoutChangeKind.swap);
      expect(
        engine.telegraph!.duration,
        greaterThanOrEqualTo(engine.tuning.readWindow),
      );
      expect(
        engine.elapsed - openedAt,
        lessThan(EndlessBoard.swapInterval),
      );
    });
  });
}

RunEngine _shopWithEvent(String id) {
  for (var seed = 1; seed < 200; seed++) {
    final engine = RunEngine(level: kEndlessShift, seed: seed)..start();
    playToShop(engine);
    if (engine.pendingEvent?.id == id) {
      return engine;
    }
  }
  fail('no seed in 1..199 drew $id');
}
