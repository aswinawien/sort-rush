import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/game/sort_rush_game.dart';
import 'package:sort_rush/ui/home_screen.dart';
import 'package:sort_rush/ui/results_screen.dart';
import 'package:sort_rush/ui/theme.dart';

/// Endless, entered the way a player enters it.
///
/// The mode existed in `lib/core` for a while before anything could reach it,
/// which meant it could not be played and therefore could not be judged. These
/// tests cover the route in and the route out.
void main() {
  SortRushGame gameOf(WidgetTester tester) => tester
      .widget<GameWidget<SortRushGame>>(find.byType(GameWidget<SortRushGame>))
      .game!;

  Future<void> settleBoot(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('home offers a way into endless, set apart from the shifts',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const HomeScreen()),
    );

    expect(find.text(kEndlessShift.title), findsOneWidget);
    expect(find.textContaining('TODAY ·'), findsOneWidget);
  });

  testWidgets('starting endless briefs it as survival, not a quota',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const HomeScreen()),
    );

    // Home now carries nine shifts plus endless, so the row sits below the
    // fold on the default test viewport and has to be scrolled to first.
    await tester.ensureVisible(find.text(kEndlessShift.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kEndlessShift.title));
    await tester.pumpAndSettle();

    expect(find.textContaining('LAST AS LONG AS YOU CAN'), findsOneWidget);
    expect(find.text('START BELT'), findsOneWidget);
  });

  testWidgets('the belt tightens as the run goes on', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const HomeScreen()),
    );
    // Home now carries nine shifts plus endless, so the row sits below the
    // fold on the default test viewport and has to be scrolled to first.
    await tester.ensureVisible(find.text(kEndlessShift.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kEndlessShift.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START BELT'));
    await settleBoot(tester);

    final game = gameOf(tester);
    final opening = game.engine.tuning.spawnInterval;

    // Play it properly: sort whatever is at the front, correctly.
    var steps = 0;
    while (game.engine.score.sorted < 25 && steps++ < 600) {
      if (find.text('WALK ON').evaluate().isNotEmpty) {
        await tester.tap(find.text('WALK ON'));
        await tester.pump();
        // Exit animation, not pumpAndSettle — the Flame loop never settles.
        await tester.pump(const Duration(milliseconds: 250));
        continue;
      }
      final package = game.engine.frontMost;
      if (package != null && game.engine.phase == RunPhase.running) {
        game.handleBinTap(game.engine.binFor(package.spec));
      }
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(game.engine.score.sorted, greaterThanOrEqualTo(25));
    expect(game.engine.tuning.spawnInterval, lessThan(opening));
    expect(game.engine.tuning.maxActive, greaterThan(1));
  });

  testWidgets('an endless run ends without ever being passed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const HomeScreen()),
    );
    // Home now carries nine shifts plus endless, so the row sits below the
    // fold on the default test viewport and has to be scrolled to first.
    await tester.ensureVisible(find.text(kEndlessShift.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kEndlessShift.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START BELT'));
    await settleBoot(tester);
    final game = gameOf(tester);

    // Never tap. Three drops end it.
    var steps = 0;
    while (!game.engine.isOver && steps++ < 600) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(game.engine.outcome, RunOutcome.failed);
    expect(game.engine.score.dropped, 3);

    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 8));

    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(find.text('SHIFT ENDED'), findsOneWidget);

    // Endless has no next shift, and its id of 0 must not resolve to shift 1
    // and offer to send the player back to the tutorial.
    expect(find.text('NEXT SHIFT'), findsNothing);
    expect(find.text('CLOCK BACK IN'), findsOneWidget);

    // And it must not stamp the player PROBATIONARY for finishing the mode
    // the only way it can be finished.
    expect(find.text('PROBATIONARY'), findsNothing);
    expect(find.text('TEMP'), findsOneWidget);
  });
}
