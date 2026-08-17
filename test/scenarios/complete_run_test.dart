import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/game/sort_rush_game.dart';
import 'package:sort_rush/ui/home_screen.dart';
import 'package:sort_rush/ui/results_screen.dart';
import 'package:sort_rush/ui/theme.dart';

/// Layer 4 of docs/testing-strategy.md: scripted deterministic play through
/// the real widget tree and the real tap pipeline.
///
/// This is the direct evidence for Milestone 3's acceptance criteria — one
/// complete run, scoring, combo, game over, restart — none of which any single
/// unit or widget test can demonstrate on its own.
void main() {
  SortRushGame gameOf(WidgetTester tester) => tester
      .widget<GameWidget<SortRushGame>>(find.byType(GameWidget<SortRushGame>))
      .game!;

  /// Centre of a chute in screen coordinates.
  ///
  /// Mirrors the layout arithmetic in SortRushGame so a drift between the two
  /// shows up as a failing tap rather than as a silent mislanding.
  Offset chuteCentre(SortRushGame game, int index) {
    final w = game.size.x;
    final h = game.size.y;
    final statusHeight = h * SortRushGame.statusFraction;
    final beltHeight = h * SortRushGame.beltFraction;
    final binsHeight = h * SortRushGame.binsFraction;
    final count = game.level.binCount;
    final binWidth = (w - SortRushGame.binGap * (count - 1)) / count;

    return Offset(
      index * (binWidth + SortRushGame.binGap) + binWidth / 2,
      statusHeight +
          beltHeight +
          SortRushGame.binGap +
          (binsHeight - SortRushGame.binGap * 2) / 2,
    );
  }

  Future<void> settleBoot(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
  }

  /// Plays the run to its end, choosing a chute with [choose].
  ///
  /// Taps go through Flame's real tap pipeline. The 100ms pump after each tap
  /// clears Flame's multi-tap countdown, which would otherwise leave a pending
  /// timer at the end of the test.
  Future<void> playOut(
    WidgetTester tester,
    SortRushGame game, {
    required int Function(int correctBin, int binCount) choose,
  }) async {
    var steps = 0;
    while (!game.engine.isOver && steps++ < 2000) {
      final package = game.engine.frontMost;
      if (package != null && game.engine.phase == RunPhase.running) {
        final correct = game.level.routing.binFor(package.spec);
        await tester.tapAt(
          chuteCentre(game, choose(correct, game.level.binCount)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      } else {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    expect(game.engine.isOver, isTrue,
        reason: 'the run never ended within the step budget');
  }

  /// The run ends inside a frame and navigates on the frame after it. Pumped
  /// explicitly rather than with pumpAndSettle, because a mounted Flame game
  /// schedules frames continuously and would never settle.
  Future<void> arriveAtResults(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 500));
    if (find.byType(ResultsScreen).evaluate().isNotEmpty) {
      await tester.pump(const Duration(seconds: 8));
    }
  }

  int alwaysCorrect(int correct, int binCount) => correct;
  int alwaysWrong(int correct, int binCount) => (correct + 1) % binCount;

  testWidgets(
      'a first-launch player can complete a whole shift and see it '
      'reported', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const HomeScreen()),
    );

    // One tap from launch to a shift, per the home screen's contract.
    await tester.tap(find.text('PUNCH IN'));
    await tester.pumpAndSettle();
    expect(find.text('SHIFT 01'), findsOneWidget);

    await tester.tap(find.text('START BELT'));
    await settleBoot(tester);
    final game = gameOf(tester);

    await playOut(tester, game, choose: alwaysCorrect);

    // Ten clean sorts crosses two combo tiers: four sorts at x1, the fifth
    // paying x2, four more at x2, the tenth paying x3.
    expect(game.engine.outcome, RunOutcome.passed);
    expect(game.engine.score.sorted, 10);
    expect(game.engine.score.mistakes, 0);
    expect(game.engine.score.bestCombo, 3);
    expect(game.engine.score.score, 170);

    await arriveAtResults(tester);

    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(find.text('SHIFT COMPLETE'), findsOneWidget);
    expect(find.text('SCORE         170'), findsOneWidget);
    expect(find.text('BEST COMBO    x3'), findsOneWidget);
  });

  testWidgets('the player can restart from results and play again',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const HomeScreen()),
    );
    await tester.tap(find.text('PUNCH IN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START BELT'));
    await settleBoot(tester);

    await playOut(tester, gameOf(tester), choose: alwaysCorrect);
    await arriveAtResults(tester);

    await tester.tap(find.text('CLOCK BACK IN'));
    await tester.pumpAndSettle();
    expect(find.text('SHIFT 01'), findsOneWidget);

    await tester.tap(find.text('START BELT'));
    await settleBoot(tester);

    // A genuinely fresh run, not the finished one redisplayed.
    final second = gameOf(tester);
    expect(second.engine.phase, RunPhase.running);
    expect(second.engine.score.score, 0);
    expect(second.engine.score.sorted, 0);
    expect(second.engine.active, hasLength(1));
  });

  testWidgets('running out of mistakes ends the shift and says so',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const HomeScreen()),
    );

    // Shift 2 is the first failable level: three chutes, three mistakes.
    await tester.tap(find.text('THREE CHUTES'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START BELT'));
    await settleBoot(tester);
    final game = gameOf(tester);

    await playOut(tester, game, choose: alwaysWrong);

    expect(game.engine.outcome, RunOutcome.failed);
    expect(game.engine.score.misrouted, 3);
    expect(game.engine.score.sorted, 0);

    await arriveAtResults(tester);

    expect(find.text('SHIFT ENDED'), findsOneWidget);
    expect(find.text('MISROUTED     3'), findsOneWidget);
    // A failed shift must not offer progression it has not earned.
    expect(find.text('NEXT SHIFT'), findsNothing);
    expect(find.text('CLOCK BACK IN'), findsOneWidget);
  });

  testWidgets(
      'a dropped package is a mistake, and enough of them end the '
      'shift', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const HomeScreen()),
    );
    await tester.tap(find.text('THREE CHUTES'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START BELT'));
    await settleBoot(tester);
    final game = gameOf(tester);

    // Never tap. Every package rides past the sort line.
    var steps = 0;
    while (!game.engine.isOver && steps++ < 2000) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(game.engine.outcome, RunOutcome.failed);
    expect(game.engine.score.dropped, 3);
    expect(game.engine.score.misrouted, 0);

    await arriveAtResults(tester);
    expect(find.text('SHIFT ENDED'), findsOneWidget);
    expect(find.text('DROPPED       3'), findsOneWidget);
  });
}
