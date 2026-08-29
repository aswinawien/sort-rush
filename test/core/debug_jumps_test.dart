import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/core/shop.dart';

void main() {
  test('debugOpenShop leaves shopping with three offers and an empty belt', () {
    final engine = RunEngine(level: kEndlessShift, seed: 7)..start();
    expect(engine.active, isNotEmpty);

    engine.debugOpenShop(pay: 20);

    expect(engine.isShopping, isTrue);
    expect(engine.shopOffers, hasLength(3));
    expect(engine.pendingEvent, isNotNull);
    expect(engine.active, isEmpty);
    expect(engine.score.pay, 20);
    for (final card in engine.shopOffers) {
      expect(engine.score.pay, greaterThanOrEqualTo(card.cost));
    }
  });

  test('debugForceRoll reports combo tier 5 and pinned memos', () {
    final engine = RunEngine(level: kEndlessShift, seed: 7)..start();
    engine.debugForceRoll();

    expect(engine.phase, RunPhase.running);
    expect(engine.score.comboTier, 5);
    expect(engine.pinned, isNotEmpty);
    expect(engine.pinned, hasLength(2));
    expect(engine.pinned.first.id, EndlessShop.catalog[0].id);
  });

  test('debugForceRoll uses the supplied pins when given', () {
    final engine = RunEngine(level: kEndlessShift, seed: 7);
    engine.debugForceRoll(
      pinned: [EndlessShop.byId('long-warn')],
    );

    expect(engine.pinned.single.id, 'long-warn');
    expect(engine.score.comboTier, 5);
  });

  test('debugForceRoll does not trip the shop on the first frames', () {
    final engine = RunEngine(level: kEndlessShift, seed: 7)..start();
    engine.debugForceRoll();

    for (var i = 0; i < 120; i++) {
      engine.update(1 / 60);
    }

    expect(engine.isShopping, isFalse);
    expect(engine.phase, RunPhase.running);
  });
}
