import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/core/run_summary.dart';
import 'package:sort_rush/ui/home_screen.dart';
import 'package:sort_rush/ui/play_screen.dart';
import 'package:sort_rush/ui/results_screen.dart';
import 'package:sort_rush/ui/theme.dart';

/// Required scenarios from docs/testing-strategy.md that had no coverage:
/// small and large screens, text scaling, and orientation.
///
/// A layout overflow in Flutter reports through FlutterError rather than
/// throwing, so `takeException` is what actually catches one here. Without
/// that assertion these tests would pass on a screen that is visibly broken.
void main() {
  /// Logical sizes, not physical. 320x568 is the smallest phone still worth
  /// supporting; 600x1024 is a small tablet; the landscape entry exists
  /// because Android may ignore a portrait preference on tablets and
  /// foldables, and the app should not fall apart if it does.
  const sizes = <String, Size>{
    'small phone': Size(320, 568),
    'typical phone': Size(412, 915),
    'small tablet': Size(600, 1024),
    'landscape': Size(915, 412),
  };

  const textScales = <double>[1.0, 1.5, 2.0];

  Future<void> pumpAt(
    WidgetTester tester,
    Widget child, {
    required Size size,
    required double textScale,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(theme: buildTheme(), home: child),
      ),
    );
  }

  RunSummary passedRun() => const RunSummary(
        levelId: 1,
        outcome: RunOutcome.passed,
        score: 170,
        sorted: 10,
        misrouted: 0,
        dropped: 0,
        bestCombo: 3,
      );

  for (final entry in sizes.entries) {
    final label = entry.key;
    final size = entry.value;

    group('on a $label', () {
      for (final scale in textScales) {
        testWidgets('home lays out at ${scale}x text', (tester) async {
          await pumpAt(tester, const HomeScreen(),
              size: size, textScale: scale);

          expect(tester.takeException(), isNull);
          expect(find.text('PUNCH IN'), findsOneWidget);
        });

        testWidgets('the briefing lays out at ${scale}x text', (tester) async {
          // Shift 4 carries the longest briefing copy and a pass condition
          // line, so it is the worst case of the four.
          await pumpAt(tester, PlayScreen(level: levelById(4), seed: 7),
              size: size, textScale: scale);

          expect(tester.takeException(), isNull);
          expect(find.text('START BELT'), findsOneWidget);
        });

        testWidgets('results lays out at ${scale}x text', (tester) async {
          await pumpAt(
            tester,
            ResultsScreen(summary: passedRun(), level: levelById(1)),
            size: size,
            textScale: scale,
          );
          // Let the manifest finish printing: fully printed is the tallest
          // the screen ever gets.
          await tester.pump(const Duration(milliseconds: 500));

          expect(tester.takeException(), isNull);
          expect(find.text('CLOCK BACK IN'), findsOneWidget);
          expect(find.text('HOME'), findsOneWidget);
        });
      }
    });
  }

  testWidgets(
      'a run can still be started on the smallest screen at the '
      'largest text scale', (tester) async {
    // The worst case for the one rule home owes the player. Before the
    // FitOrScroll fix this was not merely below the fold — the column
    // overflowed and the button was unreachable by any means.
    await pumpAt(tester, const HomeScreen(),
        size: const Size(320, 568), textScale: 2.0);

    final button = find.text('PUNCH IN');
    expect(button, findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('START BELT'), findsOneWidget);
  });

  testWidgets('at 1x text the primary action needs no scrolling',
      (tester) async {
    // The scroll is a safety net for large type, not the normal experience.
    // If this ever fails, the composition has grown too tall on its own.
    await pumpAt(tester, const HomeScreen(),
        size: const Size(320, 568), textScale: 1.0);

    final rect = tester.getRect(find.text('PUNCH IN'));
    expect(rect.top, greaterThanOrEqualTo(0.0), reason: 'off the top');
    expect(rect.bottom, lessThanOrEqualTo(568.0), reason: 'off the bottom');
  });

  testWidgets(
      'restarting stays reachable on the smallest screen at the '
      'largest text scale', (tester) async {
    // Milestone 3 accepted "restart" as a criterion. A restart button below
    // the fold on a small phone would quietly retract that.
    await pumpAt(
      tester,
      ResultsScreen(summary: passedRun(), level: levelById(1)),
      size: const Size(320, 568),
      textScale: 2.0,
    );
    await tester.pump(const Duration(milliseconds: 500));

    final rect = tester.getRect(find.text('CLOCK BACK IN'));
    expect(rect.top, greaterThanOrEqualTo(0.0));
    expect(rect.bottom, lessThanOrEqualTo(568.0));
  });
}
