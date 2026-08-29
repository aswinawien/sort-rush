import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/ui/memo_board.dart';
import 'package:sort_rush/ui/memo/memo_variant.dart';
import 'package:sort_rush/ui/theme.dart';
import 'package:sort_rush/ui/visual_style.dart';

import '../core/test_level.dart';

void main() {
  Future<RunEngine> openBoard() async {
    final engine = RunEngine(level: kEndlessShift, seed: 4)..start();
    playToShop(engine);
    expect(engine.isShopping, isTrue);
    return engine;
  }

  Widget wrap(
    RunEngine engine, {
    VoidCallback? onClosed,
    MemoVariant variant = MemoVariant.shop,
    bool neon = false,
    bool reduce = false,
  }) {
    return VisualStyleScope(
      notifier: VisualStyleController(
        initial: neon ? VisualStyle.immersiveNeon : VisualStyle.standard,
      ),
      child: MaterialApp(
        theme: buildTheme(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: Scaffold(
            body: Stack(
              children: [
                MemoBoard(
                  engine: engine,
                  onClosed: onClosed ?? () {},
                  variant: variant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the board uses depot copy, not shop copy', (tester) async {
    final engine = await openBoard();
    await tester.pumpWidget(wrap(engine));

    expect(find.text('DEPOT MEMO'), findsOneWidget);
    expect(find.text('PIN ONE. OR WALK ON.'), findsNWidgets(3));
    expect(find.text('WALK ON'), findsOneWidget);
    expect(find.text('SHOP'), findsNothing);
    expect(find.text('BUY'), findsNothing);
    expect(find.text('REROLL'), findsNothing);
    expect(find.textContaining('ASK AGAIN'), findsOneWidget);
    expect(find.text('PAY ${engine.score.pay}'), findsOneWidget);
    for (final card in engine.shopOffers) {
      expect(find.text(card.title), findsOneWidget);
      expect(find.text(card.body), findsOneWidget);
      expect(find.text('COST ${card.cost}'), findsAtLeastNWidgets(1));
    }
    final event = engine.pendingEvent!;
    expect(find.byKey(const Key('shift-event-line')), findsOneWidget);
    expect(find.text('${event.title} · ${event.body}'), findsOneWidget);
  });

  testWidgets('walk on is always legal', (tester) async {
    final engine = await openBoard();
    var closed = false;
    await tester.pumpWidget(wrap(engine, onClosed: () => closed = true));

    await tester.tap(find.text('WALK ON'));
    await tester.pump();
    // The engine commits on the tap; the callback waits for the paper to
    // retract, so settle before asserting the close.
    expect(engine.isShopping, isFalse);
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(engine.isShopping, isFalse);
    expect(engine.pinned, isEmpty);
    expect(engine.liveEvent, isNotNull);
  });

  testWidgets('an unaffordable slip takes no money', (tester) async {
    final engine = await openBoard();
    engine.score.pay = 0;
    var closed = false;
    await tester.pumpWidget(wrap(engine, onClosed: () => closed = true));

    await tester.tap(find.text(engine.shopOffers.first.title));
    await tester.pump();

    expect(closed, isFalse);
    expect(engine.isShopping, isTrue);
    expect(engine.score.pay, 0);
    expect(engine.pinned, isEmpty);
  });

  testWidgets('pinning a slip spends pay and closes the board', (tester) async {
    final engine = await openBoard();
    final cheap = engine.shopOffers.indexWhere(
      (card) => card.cost <= engine.score.pay,
    );
    expect(cheap, greaterThanOrEqualTo(0));
    final card = engine.shopOffers[cheap];
    final payBefore = engine.score.pay;
    var closed = false;
    await tester.pumpWidget(wrap(engine, onClosed: () => closed = true));

    await tester.tap(find.text(card.title));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(engine.isShopping, isFalse);
    expect(engine.score.pay, payBefore - card.cost);
    expect(engine.pinned.single.id, card.id);
    expect(engine.liveEvent, isNotNull);
  });

  testWidgets('ASK AGAIN spends pay and keeps the board open', (tester) async {
    final engine = await openBoard();
    engine.score.pay = 20;
    await tester.pumpWidget(wrap(engine));

    await tester.tap(find.textContaining('ASK AGAIN'));
    await tester.pump();

    expect(engine.isShopping, isTrue);
    expect(engine.score.pay, 17);
    expect(find.textContaining('COST ${engine.redrawCost}'), findsWidgets);
    expect(find.byKey(const Key('shift-event-line')), findsOneWidget);
  });

  group('the transition wiring', () {
    testWidgets('every variant mounts the board with the approved copy intact',
        (tester) async {
      for (final variant in MemoVariant.values) {
        for (final neon in [false, true]) {
          final engine = await openBoard();
          await tester.pumpWidget(wrap(engine, variant: variant, neon: neon));
          await tester.pumpAndSettle();

          expect(find.text('DEPOT MEMO'), findsOneWidget,
              reason: '${variant.name} neon=$neon');
          expect(find.text('WALK ON'), findsOneWidget);
          expect(find.text('SHOP'), findsNothing);
          expect(find.text('STORE'), findsNothing);
          expect(find.text('BUY'), findsNothing);
          expect(find.text('REROLL'), findsNothing);
          expect(find.text('PAID'), findsNothing);
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('reduce motion shows the content immediately', (tester) async {
      final engine = await openBoard();
      await tester.pumpWidget(wrap(engine, reduce: true, neon: true));
      await tester.pump();

      // No settling: the slips must be present and tappable on the first frame.
      expect(find.text('DEPOT MEMO'), findsOneWidget);
      for (final card in engine.shopOffers) {
        expect(find.text(card.title), findsOneWidget);
      }
    });

    testWidgets('reduce motion closes without waiting for an animation',
        (tester) async {
      final engine = await openBoard();
      var closed = 0;
      await tester.pumpWidget(
        wrap(engine, onClosed: () => closed++, reduce: true, neon: true),
      );
      await tester.pump();

      await tester.tap(find.text('WALK ON'));
      await tester.pump();

      expect(closed, 1);
    });

    testWidgets('WALK ON during the exit cannot double-commit', (tester) async {
      // Buying empties the offers, so the slips unmount — but WALK ON is still
      // on screen while the paper retracts. Without the commit latch that tap
      // would call skipShop after a buy and fire a second callback.
      final engine = await openBoard();
      engine.score.pay = 99;
      var closed = 0;
      await tester
          .pumpWidget(wrap(engine, onClosed: () => closed++, neon: true));
      await tester.pumpAndSettle();

      final first = engine.shopOffers[0];
      final payBefore = engine.score.pay;

      await tester.tap(find.text(first.title));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(find.text('WALK ON'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(engine.pinned, hasLength(1), reason: 'one purchase only');
      expect(engine.pinned.single.id, first.id);
      expect(engine.score.pay, payBefore - first.cost);
      expect(closed, 1, reason: 'one close callback only');
    });

    testWidgets('walking on twice fires one callback', (tester) async {
      final engine = await openBoard();
      var closed = 0;
      await tester
          .pumpWidget(wrap(engine, onClosed: () => closed++, neon: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('WALK ON'));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.text('WALK ON'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(closed, 1);
      expect(engine.pinned, isEmpty);
    });

    testWidgets('the slips stay paper in neon', (tester) async {
      // docs/design-spec.md 5.5: the wall is the machine, the slips are paper.
      final engine = await openBoard();
      await tester.pumpWidget(wrap(engine, neon: true));
      await tester.pumpAndSettle();

      final materials = tester
          .widgetList<Material>(find.byType(Material))
          .where((m) => m.color == Tokens.paper);
      expect(materials, isNotEmpty,
          reason: 'memo slips must still be cream paper under neon');
    });
  });
}
