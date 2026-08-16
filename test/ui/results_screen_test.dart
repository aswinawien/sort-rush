import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/level_config.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/core/run_summary.dart';
import 'package:sort_rush/ui/results_screen.dart';
import 'package:sort_rush/ui/theme.dart';

/// The results screen carries Milestone 3's restart criterion, so its buttons
/// are acceptance criteria rather than decoration.
void main() {
  RunSummary summary({
    int levelId = 1,
    RunOutcome outcome = RunOutcome.passed,
    int score = 120,
    int sorted = 10,
    int misrouted = 1,
    int dropped = 0,
    int bestCombo = 2,
  }) =>
      RunSummary(
        levelId: levelId,
        outcome: outcome,
        score: score,
        sorted: sorted,
        misrouted: misrouted,
        dropped: dropped,
        bestCombo: bestCombo,
      );

  Future<void> show(
    WidgetTester tester,
    RunSummary runSummary, {
    LevelConfig? level,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: ResultsScreen(
          summary: runSummary,
          level: level ?? levelById(runSummary.levelId),
        ),
      ),
    );
  }

  /// The manifest prints one line every 40ms and cancels its own timer on the
  /// tick after the last line. Pumping past that leaves no pending timer.
  Future<void> finishPrinting(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 500));

  group('the manifest', () {
    testWidgets('prints progressively rather than appearing at once',
        (tester) async {
      await show(tester, summary());

      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('SCORE         120'), findsNothing);

      await finishPrinting(tester);
      expect(find.text('SCORE         120'), findsOneWidget);
    });

    testWidgets('is skippable on tap, so a fifth restart is not a wait',
        (tester) async {
      await show(tester, summary());
      await tester.pump(const Duration(milliseconds: 40));

      await tester.tap(find.byType(ResultsScreen));
      await tester.pump();

      expect(find.text('SCORE         120'), findsOneWidget);
      expect(find.text('CLOCK BACK IN'), findsOneWidget);
    });

    testWidgets('reports the run the player actually had', (tester) async {
      await show(tester, summary(sorted: 12, misrouted: 2, dropped: 3));
      await finishPrinting(tester);

      expect(find.text('SORTED        12'), findsOneWidget);
      expect(find.text('MISROUTED     2'), findsOneWidget);
      expect(find.text('DROPPED       3'), findsOneWidget);
      expect(find.text('BEST COMBO    x2'), findsOneWidget);
    });
  });

  group('pass and fail read differently', () {
    testWidgets('a cleared shift is announced as complete', (tester) async {
      await show(tester, summary());
      await finishPrinting(tester);

      expect(find.text('SHIFT COMPLETE'), findsOneWidget);
      expect(find.text('CLEARED'), findsOneWidget);
    });

    testWidgets('a failed shift ends without blaming the player',
        (tester) async {
      await show(tester, summary(levelId: 2, outcome: RunOutcome.failed));
      await finishPrinting(tester);

      expect(find.text('SHIFT ENDED'), findsOneWidget);
      expect(find.text('PROBATIONARY'), findsOneWidget);
    });

    testWidgets('holding a combo earns the better stamp', (tester) async {
      await show(tester, summary(bestCombo: 4));
      await finishPrinting(tester);

      expect(find.text('EMPLOYEE OF THE SHIFT'), findsOneWidget);
    });
  });

  group('progression', () {
    testWidgets('a pass offers the next shift', (tester) async {
      await show(tester, summary());
      await finishPrinting(tester);

      expect(find.text('NEXT SHIFT'), findsOneWidget);
    });

    testWidgets('a failure offers a retry but no way forward', (tester) async {
      await show(tester, summary(levelId: 2, outcome: RunOutcome.failed));
      await finishPrinting(tester);

      expect(find.text('NEXT SHIFT'), findsNothing);
      expect(find.text('CLOCK BACK IN'), findsOneWidget);
    });

    testWidgets('the last curated level offers no next shift', (tester) async {
      // Derived from the table rather than hardcoded: this assertion is about
      // the end of the ladder, wherever the ladder currently ends. Naming a
      // level number here means the test silently becomes wrong the next time
      // one is added.
      final last = kCuratedLevels.last;
      await show(tester, summary(levelId: last.id), level: last);
      await finishPrinting(tester);

      expect(find.text('NEXT SHIFT'), findsNothing);
      expect(find.text('CLOCK BACK IN'), findsOneWidget);
    });
  });

  group('the way out', () {
    testWidgets('clocking back in reopens the same shift', (tester) async {
      await show(tester, summary(levelId: 2, outcome: RunOutcome.failed));
      await finishPrinting(tester);

      await tester.tap(find.text('CLOCK BACK IN'));
      await tester.pumpAndSettle();

      expect(find.text('SHIFT 02'), findsOneWidget);
      expect(find.text('START BELT'), findsOneWidget);
    });

    testWidgets('the next shift opens the following level', (tester) async {
      await show(tester, summary());
      await finishPrinting(tester);

      await tester.tap(find.text('NEXT SHIFT'));
      await tester.pumpAndSettle();

      expect(find.text('SHIFT 02'), findsOneWidget);
      expect(find.text('THREE CHUTES'), findsOneWidget);
    });

    testWidgets('home unwinds the whole run, not one route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ResultsScreen(
                      summary: summary(),
                      level: levelById(1),
                    ),
                  ),
                ),
                child: const Text('DEPOT'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('DEPOT'));
      await tester.pumpAndSettle();
      await finishPrinting(tester);

      await tester.tap(find.text('HOME'));
      await tester.pumpAndSettle();

      expect(find.text('DEPOT'), findsOneWidget);
      expect(find.byType(ResultsScreen), findsNothing);
    });
  });
}
