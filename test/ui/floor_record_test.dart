import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/floor_board.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/core/run_summary.dart';
import 'package:sort_rush/ui/home_screen.dart';
import 'package:sort_rush/ui/results_screen.dart';
import 'package:sort_rush/ui/score_board.dart';
import 'package:sort_rush/ui/theme.dart';

void main() {
  Widget wrap(Widget child, {required ScoreBoard board}) => ScoreBoardScope(
        notifier: board,
        child: MaterialApp(theme: buildTheme(), home: child),
      );

  RunSummary endless({int score = 400, int sorted = 32, int pay = 0}) =>
      RunSummary(
        levelId: 0,
        outcome: RunOutcome.failed,
        score: score,
        sorted: sorted,
        misrouted: 1,
        dropped: 0,
        bestCombo: 4,
        endless: true,
        seed: 7,
        pay: pay,
      );

  const curated = RunSummary(
    levelId: 1,
    outcome: RunOutcome.passed,
    score: 170,
    sorted: 10,
    misrouted: 0,
    dropped: 0,
    bestCombo: 3,
  );

  testWidgets('an empty board prints NO CLOCKINGS, not a fake best',
      (tester) async {
    final board = ScoreBoard(MemoryScoreStore());
    await board.load();
    await tester.pumpWidget(wrap(const HomeScreen(), board: board));

    expect(find.text('FLOOR RECORD'), findsOneWidget);
    expect(find.text('NO CLOCKINGS'), findsOneWidget);
    expect(find.text('PAY 0'), findsOneWidget);
    expect(find.text('PUNCH IN'), findsOneWidget);
  });

  testWidgets('home ranks clockings by score', (tester) async {
    final board = ScoreBoard(
      MemoryScoreStore([
        const BoardEntry(
          score: 120,
          sorted: 12,
          seed: 1,
          bestCombo: 2,
          atMs: 1,
        ),
        const BoardEntry(
          score: 400,
          sorted: 32,
          seed: 2,
          bestCombo: 5,
          atMs: 2,
        ),
      ]),
    );
    await board.load();
    await tester.pumpWidget(wrap(const HomeScreen(), board: board));

    expect(find.text('NO CLOCKINGS'), findsNothing);
    expect(find.text('400'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('32 SORTED'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('400')).dy,
      lessThan(tester.getTopLeft(find.text('120')).dy),
    );
  });

  testWidgets('an endless report writes the board once', (tester) async {
    final board = ScoreBoard(MemoryScoreStore());
    await tester.pumpWidget(
      ScoreBoardScope(
        notifier: board,
        child: MaterialApp(
          theme: buildTheme(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: ResultsScreen(
              summary: endless(),
              level: kEndlessShift,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(board.entries, hasLength(1));
    expect(board.entries.first.score, 400);
    expect(board.entries.first.sorted, 32);
    expect(board.entries.first.seed, 7);
    expect(board.wallet, 0);
  });

  testWidgets('an endless report banks leftover pay, capped', (tester) async {
    final board = ScoreBoard(MemoryScoreStore());
    await tester.pumpWidget(
      ScoreBoardScope(
        notifier: board,
        child: MaterialApp(
          theme: buildTheme(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: ResultsScreen(
              summary: endless(pay: 40),
              level: kEndlessShift,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(board.wallet, FloorBoard.walletCap);
  });

  testWidgets('home shows the carried wallet', (tester) async {
    final store = MemoryScoreStore(const [], 7);
    final board = ScoreBoard(store);
    await board.load();
    await tester.pumpWidget(wrap(const HomeScreen(), board: board));

    expect(find.text('PAY 7'), findsOneWidget);
  });

  testWidgets('a curated report does not write the board', (tester) async {
    final board = ScoreBoard(MemoryScoreStore());
    await tester.pumpWidget(
      ScoreBoardScope(
        notifier: board,
        child: MaterialApp(
          theme: buildTheme(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: ResultsScreen(
              summary: curated,
              level: levelById(1),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(board.entries, isEmpty);
    expect(board.wallet, 0);
  });
}
