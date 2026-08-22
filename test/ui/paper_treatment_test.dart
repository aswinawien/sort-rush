import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/core/run_summary.dart';
import 'package:sort_rush/ui/results_screen.dart';
import 'package:sort_rush/ui/theme.dart';
import 'package:sort_rush/ui/visual_style.dart';
import 'package:sort_rush/ui/widgets/halftone.dart';
import 'package:sort_rush/ui/widgets/scan_lines.dart';

/// Paper and machine are different materials.
///
/// `ScanLines` is the CRT treatment and belongs on `ink`. A paper surface that
/// carries scan lines has been CRT-washed, which docs/design-spec.md §5.5 rules
/// out by name — "do not CRT-wash the memos". Paper gets halftone instead,
/// which is a print artefact.
void main() {
  const summary = RunSummary(
    levelId: 3,
    outcome: RunOutcome.passed,
    score: 240,
    sorted: 18,
    misrouted: 1,
    dropped: 0,
    bestCombo: 4,
  );

  Widget wrap({required bool neon}) => VisualStyleScope(
        notifier: VisualStyleController(
          initial: neon ? VisualStyle.immersiveNeon : VisualStyle.standard,
        ),
        child: MaterialApp(
          theme: buildTheme(),
          home: ResultsScreen(summary: summary, level: levelById(3)),
        ),
      );

  testWidgets('the results manifest is paper, so it is never CRT-washed',
      (tester) async {
    await tester.pumpWidget(wrap(neon: false));
    // A single long pump, not pumpAndSettle: the cursor blinks forever, so
    // the tree never settles. Matches test/ui/results_screen_test.dart.
    await tester.pump(const Duration(seconds: 8));

    expect(find.byType(Halftone), findsWidgets);
    expect(find.byType(ScanLines), findsNothing,
        reason: 'scan lines are the machine treatment; this surface is paper');
  });

  testWidgets('neon deepens the halftone rather than adding scan lines',
      (tester) async {
    await tester.pumpWidget(wrap(neon: true));
    // A single long pump, not pumpAndSettle: the cursor blinks forever, so
    // the tree never settles. Matches test/ui/results_screen_test.dart.
    await tester.pump(const Duration(seconds: 8));

    final halftone = tester.widget<Halftone>(find.byType(Halftone).first);
    expect(halftone.opacity, greaterThan(0.05));
    expect(find.byType(ScanLines), findsNothing);
  });

  testWidgets('the manifest carries a serial derived from the run',
      (tester) async {
    await tester.pumpWidget(wrap(neon: false));
    // A single long pump, not pumpAndSettle: the cursor blinks forever, so
    // the tree never settles. Matches test/ui/results_screen_test.dart.
    await tester.pump(const Duration(seconds: 8));

    // Derived, never invented: level 3, score 240, 18 sorted.
    expect(find.text('DOC 03-00240-018'), findsOneWidget);
  });

  testWidgets('the halftone is identical between frames, never a strobe',
      (tester) async {
    await tester.pumpWidget(wrap(neon: true));
    // A single long pump, not pumpAndSettle: the cursor blinks forever, so
    // the tree never settles. Matches test/ui/results_screen_test.dart.
    await tester.pump(const Duration(seconds: 8));
    final first = tester.widget<Halftone>(find.byType(Halftone).first);
    await tester.pump(const Duration(milliseconds: 120));
    final second = tester.widget<Halftone>(find.byType(Halftone).first);

    expect(first.opacity, second.opacity);
    expect(first.spacing, second.spacing);
  });
}
