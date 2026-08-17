import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/game/sort_rush_game.dart';
import 'package:sort_rush/ui/home_screen.dart';
import 'package:sort_rush/ui/theme.dart';

void main() {
  Widget wrap({required bool showDevTools}) => MaterialApp(
        theme: buildTheme(),
        home: HomeScreen(showDevTools: showDevTools),
      );

  Future<void> settleBoot(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
  }

  Future<void> openDev(WidgetTester tester) async {
    await tester.pumpWidget(wrap(showDevTools: true));
    await tester.ensureVisible(find.text('DEV'));
    await tester.pumpAndSettle();
  }

  testWidgets('dev tools show the four jumps when asked', (tester) async {
    await openDev(tester);

    expect(find.text('DEV'), findsOneWidget);
    expect(find.text('MEMO'), findsOneWidget);
    expect(find.text('ROLL'), findsOneWidget);
    expect(find.text('RESULTS'), findsOneWidget);
    expect(find.text('PAUSE'), findsOneWidget);
  });

  testWidgets('dev tools are absent on the release path', (tester) async {
    await tester.pumpWidget(wrap(showDevTools: false));

    expect(find.text('DEV'), findsNothing);
    expect(find.text('MEMO'), findsNothing);
    expect(find.text('ROLL'), findsNothing);
    expect(find.text('RESULTS'), findsNothing);
    expect(find.text('PAUSE'), findsNothing);
    expect(find.text('PUNCH IN'), findsOneWidget);
  });

  testWidgets('MEMO opens the depot board on an empty belt', (tester) async {
    await openDev(tester);
    await tester.tap(find.text('MEMO'));
    await settleBoot(tester);

    expect(find.text('DEPOT MEMO'), findsOneWidget);
    expect(find.text('WALK ON'), findsOneWidget);
  });

  testWidgets('ROLL forces combo x5 and pinned chips', (tester) async {
    await openDev(tester);
    await tester.tap(find.text('ROLL'));
    await settleBoot(tester);

    final game = tester
        .widget<GameWidget<SortRushGame>>(
          find.byType(GameWidget<SortRushGame>),
        )
        .game!;
    expect(game.engine.phase, RunPhase.running);
    expect(game.engine.score.comboTier, 5);
    expect(game.engine.pinned, isNotEmpty);
    expect(game.engine.isShopping, isFalse);
    expect(find.text('DEPOT MEMO'), findsNothing);
  });

  testWidgets('RESULTS opens a cleared curated report with the wager',
      (tester) async {
    await openDev(tester);
    await tester.tap(find.text('RESULTS'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 8));

    expect(find.text('SHIFT COMPLETE'), findsOneWidget);
    expect(find.text('DOUBLE OR NOTHING'), findsOneWidget);
  });

  testWidgets('long-press RESULTS opens the fail stamp', (tester) async {
    await openDev(tester);
    await tester.longPress(find.text('RESULTS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SHIFT ENDED'));
    await tester.pump();

    expect(find.text('SHIFT ENDED'), findsOneWidget);
    expect(find.text('PROBATIONARY'), findsOneWidget);
  });

  testWidgets('PAUSE opens endless already held', (tester) async {
    await openDev(tester);
    await tester.tap(find.text('PAUSE'));
    await settleBoot(tester);

    expect(find.text('BELT HELD'), findsOneWidget);
    final game = tester
        .widget<GameWidget<SortRushGame>>(
          find.byType(GameWidget<SortRushGame>),
        )
        .game!;
    expect(game.engine.phase, RunPhase.paused);
  });
}
