import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/game/music.dart';
import 'package:sort_rush/game/sfx.dart';
import 'package:sort_rush/ui/audio_scope.dart';
import 'package:sort_rush/ui/home_screen.dart';
import 'package:sort_rush/ui/theme.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(theme: buildTheme(), home: child);

  testWidgets('home offers a one-tap start', (tester) async {
    await tester.pumpWidget(wrap(const HomeScreen()));

    expect(find.text('PUNCH IN'), findsOneWidget);
    expect(find.text('DEPOT 7 · NIGHT SHIFT'), findsOneWidget);
    expect(find.textContaining('TODAY ·'), findsOneWidget);
  });

  testWidgets('home lists every curated shift', (tester) async {
    await tester.pumpWidget(wrap(const HomeScreen()));

    // Derived from the table so adding a level cannot leave it off the list
    // without a test noticing.
    for (final level in kCuratedLevels) {
      expect(
        find.text(level.title),
        findsOneWidget,
        reason: 'shift ${level.id} is missing from home',
      );
    }
  });

  testWidgets('the title is misregistered, not duplicated by accident',
      (tester) async {
    await tester.pumpWidget(wrap(const HomeScreen()));

    // Three offset copies form the print-misregistration effect.
    expect(find.text('SORT RUSH'), findsNWidgets(3));
  });

  testWidgets('dev tools stay off in VM tests unless asked', (tester) async {
    await tester.pumpWidget(wrap(const HomeScreen()));

    expect(find.text('DEV'), findsNothing);
    expect(find.text('FLOOR RECORD'), findsOneWidget);
    expect(find.text('NO CLOCKINGS'), findsOneWidget);
    expect(find.text('OPTIONS'), findsOneWidget);
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

  testWidgets('OPTIONS opens the settings terminal', (tester) async {
    await tester.pumpWidget(wrap(const HomeScreen()));

    await tester.ensureVisible(find.text('OPTIONS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OPTIONS'));
    await tester.pumpAndSettle();

    // Settings live on their own screen now, not inline on home.
    expect(find.text('VISUAL STYLE'), findsOneWidget);
    expect(find.text('REDUCE MOTION'), findsOneWidget);
  });

  testWidgets('lobby music resumes when a covering route pops', (tester) async {
    final music = RecordingMusic();
    final audio = AudioController(
      sfx: const SilentSfx(),
      music: music,
      tracks: const {'audio/home.ogg'},
    );
    final navKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      AudioScope(
        notifier: audio,
        child: MaterialApp(
          navigatorKey: navKey,
          navigatorObservers: [homeRouteObserver],
          theme: buildTheme(),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(music.calls, contains('home'));

    navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('COVER')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('COVER'), findsOneWidget);
    music.calls.clear();

    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('COVER'), findsNothing);
    expect(music.calls, contains('home'));
  });
}
