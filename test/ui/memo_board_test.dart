import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/ui/memo_board.dart';
import 'package:sort_rush/ui/theme.dart';

import '../core/test_level.dart';

void main() {
  Future<RunEngine> openBoard() async {
    final engine = RunEngine(level: kEndlessShift, seed: 4)..start();
    playToShop(engine);
    expect(engine.isShopping, isTrue);
    return engine;
  }

  Widget wrap(RunEngine engine, {VoidCallback? onClosed}) {
    return MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: Stack(
          children: [
            MemoBoard(engine: engine, onClosed: onClosed ?? () {}),
          ],
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
    expect(find.textContaining('PAY'), findsOneWidget);
    for (final card in engine.shopOffers) {
      expect(find.text(card.title), findsOneWidget);
      expect(find.text('COST ${card.cost}'), findsOneWidget);
    }
  });

  testWidgets('walk on is always legal', (tester) async {
    final engine = await openBoard();
    var closed = false;
    await tester.pumpWidget(wrap(engine, onClosed: () => closed = true));

    await tester.tap(find.text('WALK ON'));
    await tester.pump();

    expect(closed, isTrue);
    expect(engine.isShopping, isFalse);
    expect(engine.pinned, isEmpty);
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

    expect(closed, isTrue);
    expect(engine.isShopping, isFalse);
    expect(engine.score.pay, payBefore - card.cost);
    expect(engine.pinned.single.id, card.id);
  });
}
