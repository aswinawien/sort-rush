import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/core/run_tuning.dart';
import 'package:sort_rush/core/shop.dart';

import 'test_level.dart';

void main() {
  group('the depot board', () {
    test('opens on a drained belt at the first blind', () {
      final engine = RunEngine(level: kEndlessShift, seed: 4)..start();
      var steps = 0;
      while (!engine.isShopping &&
          engine.phase != RunPhase.finished &&
          steps++ < 8000) {
        if (engine.frontMost != null) {
          sortCorrectly(engine);
        }
        engine.update(1 / 60);
      }

      expect(engine.isShopping, isTrue);
      expect(engine.active, isEmpty);
      expect(engine.shopOffers, hasLength(EndlessShop.offerCount));
      expect(engine.score.sorted, greaterThanOrEqualTo(EndlessShop.blinds.first));
    });

    test('the same seed pins the same memos', () {
      List<String> draw(int seed) {
        final engine = RunEngine(level: kEndlessShift, seed: seed)..start();
        var steps = 0;
        while (!engine.isShopping && steps++ < 8000) {
          if (engine.frontMost != null) {
            sortCorrectly(engine);
          }
          engine.update(1 / 60);
        }
        return engine.shopOffers.map((card) => card.id).toList();
      }

      expect(draw(12), draw(12));
      expect(draw(12), isNot(draw(99)));
    });

    test('skip is always legal and the belt resumes', () {
      final engine = RunEngine(level: kEndlessShift, seed: 4)..start();
      var steps = 0;
      while (!engine.isShopping && steps++ < 8000) {
        if (engine.frontMost != null) {
          sortCorrectly(engine);
        }
        engine.update(1 / 60);
      }
      engine.skipShop();
      expect(engine.isShopping, isFalse);
      expect(engine.phase, RunPhase.running);
      engine.update(engine.tuning.spawnInterval + 0.01);
      expect(engine.active, isNotEmpty);
    });

    test('a pin spends pay and retunes the belt', () {
      final engine = RunEngine(level: kEndlessShift, seed: 4)..start();
      var steps = 0;
      while (!engine.isShopping && steps++ < 8000) {
        if (engine.frontMost != null) {
          sortCorrectly(engine);
        }
        engine.update(1 / 60);
      }

      final beforeWindow = engine.tuning.readWindow;
      final cheap = engine.shopOffers.indexWhere(
        (card) => card.cost <= engine.score.pay,
      );
      expect(cheap, greaterThanOrEqualTo(0));
      final card = engine.shopOffers[cheap];
      final payBefore = engine.score.pay;
      expect(engine.buy(cheap), isTrue);
      expect(engine.score.pay, payBefore - card.cost);
      expect(engine.isShopping, isFalse);
      if (card.delta.readWindow != 0) {
        expect(engine.tuning.readWindow, isNot(beforeWindow));
      }
      expect(
        engine.tuning.readWindow,
        greaterThanOrEqualTo(RunTuning.readWindowFloor),
      );
    });

    test('a memo the run cannot afford does not take money', () {
      final engine = RunEngine(level: kEndlessShift, seed: 4)..start();
      var steps = 0;
      while (!engine.isShopping && steps++ < 8000) {
        if (engine.frontMost != null) {
          sortCorrectly(engine);
        }
        engine.update(1 / 60);
      }
      engine.score.pay = 0;
      expect(engine.buy(0), isFalse);
      expect(engine.isShopping, isTrue);
      expect(engine.score.pay, 0);
    });

    test('no card text hides a probability', () {
      for (final card in EndlessShop.catalog) {
        expect(card.body.contains('%') && card.body.contains('chance'), isFalse);
        expect(card.id.contains('lucky'), isFalse);
      }
    });

    test('every memo has a chip title', () {
      for (final card in EndlessShop.catalog) {
        expect(card.chip, isNotEmpty, reason: card.id);
        expect(card.chip.length, lessThanOrEqualTo(12), reason: card.id);
      }
    });

    test('a pin is remembered for the rest of the run', () {
      final engine = RunEngine(level: kEndlessShift, seed: 4)..start();
      playToShop(engine);
      expect(engine.pinned, isEmpty);
      final cheap = engine.shopOffers.indexWhere(
        (card) => card.cost <= engine.score.pay,
      );
      final card = engine.shopOffers[cheap];
      expect(engine.buy(cheap), isTrue);
      expect(engine.pinned, hasLength(1));
      expect(engine.pinned.single.id, card.id);
    });

    test('skip does not pin a memo', () {
      final engine = RunEngine(level: kEndlessShift, seed: 4)..start();
      playToShop(engine);
      engine.skipShop();
      expect(engine.pinned, isEmpty);
    });

    test('the same seed plus the same buys pins the same memos', () {
      List<String> run(int seed) {
        final engine = RunEngine(level: kEndlessShift, seed: seed)..start();
        playToShop(engine);
        final first = engine.shopOffers.first;
        if (engine.score.pay >= first.cost) {
          engine.buy(0);
        } else {
          engine.skipShop();
        }
        playToShop(engine);
        if (engine.isShopping &&
            engine.score.pay >= engine.shopOffers.first.cost) {
          engine.buy(0);
        }
        return engine.pinned.map((card) => card.id).toList();
      }

      expect(run(12), run(12));
    });
  });
}
