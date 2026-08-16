import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/ui/home_screen.dart';
import 'package:sort_rush/ui/theme.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(theme: buildTheme(), home: child);

  testWidgets('home offers a one-tap start', (tester) async {
    await tester.pumpWidget(wrap(const HomeScreen()));

    expect(find.text('PUNCH IN'), findsOneWidget);
    expect(find.text('DEPOT 7 · NIGHT SHIFT'), findsOneWidget);
  });

  testWidgets('home lists the three prototype shifts', (tester) async {
    await tester.pumpWidget(wrap(const HomeScreen()));

    expect(find.text('INDUCTION'), findsOneWidget);
    expect(find.text('THREE CHUTES'), findsOneWidget);
    expect(find.text('RELABELLED'), findsOneWidget);
  });

  testWidgets('the title is misregistered, not duplicated by accident',
      (tester) async {
    await tester.pumpWidget(wrap(const HomeScreen()));

    // Three offset copies form the print-misregistration effect.
    expect(find.text('SORT RUSH'), findsNWidgets(3));
  });

  testWidgets('starting a shift opens the briefing before anything moves',
      (tester) async {
    await tester.pumpWidget(wrap(const HomeScreen()));

    await tester.tap(find.text('PUNCH IN'));
    await tester.pumpAndSettle();

    expect(find.text('SHIFT 01'), findsOneWidget);
    expect(find.text('START BELT'), findsOneWidget);
    // Level 1 must announce that it carries no penalty.
    expect(find.text('NO PENALTY THIS SHIFT.'), findsOneWidget);
  });
}
