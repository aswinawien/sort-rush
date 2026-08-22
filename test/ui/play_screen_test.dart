import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/game/sort_rush_game.dart';
import 'package:sort_rush/ui/play_screen.dart';
import 'package:sort_rush/game/music.dart';
import 'package:sort_rush/ui/theme.dart';
import 'package:sort_rush/ui/visual_style.dart';

/// The Flutter shell around the Flame surface.
///
/// The engine tests prove the rules and the game test proves the surface
/// boots. Neither touches the briefing gate, the pause control, or the route
/// out of a run — which is where "pause/resume" and "restart" in
/// docs/testing-strategy.md actually live.
void main() {
  SortRushGame gameOf(WidgetTester tester) => tester
      .widget<GameWidget<SortRushGame>>(find.byType(GameWidget<SortRushGame>))
      .game!;

  /// Pumps past Flame's async onLoad so the engine exists before asserting.
  Future<void> settleBoot(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
  }

  Future<void> openBriefing(WidgetTester tester, {int levelId = 1}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: PlayScreen(level: levelById(levelId), seed: 7),
      ),
    );
  }

  Future<void> startBelt(WidgetTester tester, {int levelId = 1}) async {
    await openBriefing(tester, levelId: levelId);
    await tester.tap(find.text('START BELT'));
    await settleBoot(tester);
  }

  group('the briefing', () {
    testWidgets('holds the belt until the player starts it', (tester) async {
      await openBriefing(tester);

      // Nothing may move while the player is still reading the rule.
      expect(find.byType(GameWidget<SortRushGame>), findsNothing);
      expect(find.text('START BELT'), findsOneWidget);
    });

    testWidgets('states the pass target and mistake budget of a failable level',
        (tester) async {
      await openBriefing(tester, levelId: 2);

      expect(find.text('SORT 12 · 3 MISTAKES ALLOWED.'), findsOneWidget);
    });

    testWidgets('starting puts a package on a running belt', (tester) async {
      await startBelt(tester);

      final game = gameOf(tester);
      expect(game.engine.phase, RunPhase.running);
      expect(game.engine.active, hasLength(1));
    });
  });

  group('pause', () {
    testWidgets('holds the belt in place', (tester) async {
      await startBelt(tester);
      final game = gameOf(tester);
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      final held = game.engine.frontMost!.progress;
      await tester.pump(const Duration(milliseconds: 600));

      expect(game.engine.phase, RunPhase.paused);
      expect(game.engine.frontMost!.progress, held);
      expect(find.text('BELT HELD'), findsOneWidget);
    });

    testWidgets('a tap while held cannot route a package', (tester) async {
      await startBelt(tester);
      final game = gameOf(tester);
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();

      // The scrim covers the play field, but a tap that reaches through it
      // must still not score: a held belt accepts no input.
      game.handleBinTap(0);
      await tester.pump();

      expect(game.engine.score.sorted, 0);
      expect(game.engine.score.mistakes, 0);
    });

    testWidgets('resuming releases the belt', (tester) async {
      await startBelt(tester);
      final game = gameOf(tester);
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      final held = game.engine.frontMost!.progress;

      await tester.tap(find.text('RESUME'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(game.engine.phase, RunPhase.running);
      expect(game.engine.frontMost!.progress, greaterThan(held));
      expect(find.text('BELT HELD'), findsNothing);
    });

    testWidgets('backgrounding the app holds the belt', (tester) async {
      await startBelt(tester);
      final game = gameOf(tester);
      await tester.pump(const Duration(milliseconds: 300));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(game.engine.phase, RunPhase.paused);
      expect(find.text('BELT HELD'), findsOneWidget);
    });

    testWidgets('returning does not restart the belt on its own',
        (tester) async {
      // The whole point: coming back must be a deliberate act, not something
      // that happens to the player while they are still putting their phone
      // to their ear.
      await startBelt(tester);
      final game = gameOf(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      final held = game.engine.frontMost!.progress;
      await tester.pump(const Duration(milliseconds: 500));

      expect(game.engine.phase, RunPhase.paused);
      expect(game.engine.frontMost!.progress, held);
      expect(find.text('BELT HELD'), findsOneWidget);

      await tester.tap(find.text('RESUME'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(game.engine.phase, RunPhase.running);
      expect(game.engine.frontMost!.progress, greaterThan(held));
    });

    testWidgets('an already-held belt is not disturbed by backgrounding',
        (tester) async {
      await startBelt(tester);
      final game = gameOf(tester);
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Must not toggle back to running.
      expect(game.engine.phase, RunPhase.paused);
      expect(find.text('BELT HELD'), findsOneWidget);
    });

    testWidgets('system back holds the belt instead of discarding the run',
        (tester) async {
      // M3-01. Before the fix, back popped straight to the previous route and
      // the run was gone with no warning.
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlayScreen(level: levelById(1), seed: 7),
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
      await tester.tap(find.text('START BELT'));
      await settleBoot(tester);
      final game = gameOf(tester);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(game.engine.phase, RunPhase.paused);
      expect(find.text('BELT HELD'), findsOneWidget);
      expect(find.text('DEPOT'), findsNothing);
    });

    testWidgets(
        'a second back leaves the held belt, so quitting stays possible',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlayScreen(level: levelById(1), seed: 7),
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
      await tester.tap(find.text('START BELT'));
      await settleBoot(tester);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('DEPOT'), findsOneWidget);
      expect(find.byType(GameWidget<SortRushGame>), findsNothing);
    });

    testWidgets('quitting from the scrim returns to where the run started',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlayScreen(level: levelById(1), seed: 7),
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
      await tester.tap(find.text('START BELT'));
      await settleBoot(tester);
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();

      await tester.tap(find.text('QUIT TO HOME'));
      await tester.pumpAndSettle();

      expect(find.text('DEPOT'), findsOneWidget);
      expect(find.byType(GameWidget<SortRushGame>), findsNothing);
    });
  });

  group('endless boots', () {
    testWidgets('NIGHT SHIFT starts without throwing', (tester) async {
      // Regression: the endless music crossfade read `game.engine` from
      // `build`, but `engine` is late-initialised in Flame's async `onLoad`.
      // The first build after START BELT therefore threw
      // LateInitializationError — and only on endless, because curated shifts
      // have no curve and skipped the branch entirely.
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: PlayScreen(level: kEndlessShift, seed: 7),
        ),
      );
      await tester.tap(find.text('START BELT'));
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'endless must survive the frame before onLoad completes');

      await settleBoot(tester);
      expect(tester.takeException(), isNull);
      expect(gameOf(tester).engine.phase, RunPhase.running);
    });

    testWidgets('the crossfade is driven by the loop, not by build',
        (tester) async {
      // The crash was `build` reading `game.engine` before Flame's async
      // `onLoad` had run. Driving it from `update` also fixes a second bug:
      // from `build` the mix only moved when something else rebuilt the
      // screen, which in endless is almost never.
      final music = RecordingMusic();
      final game = SortRushGame(
        level: kEndlessShift,
        seed: 7,
        music: music,
        onRunEnded: (_) {},
      );
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await settleBoot(tester);

      expect(music.mix, 0);
      for (var i = 0; i < 400; i++) {
        final front = game.engine.frontMost;
        if (front != null) {
          game.handleBinTap(game.engine.binFor(front.spec));
        }
        game.update(0.1);
      }
      expect(game.engine.pressure, greaterThan(0));
      expect(music.mix, greaterThan(0),
          reason: 'the loop must move the crossfade with pressure');
    });

    testWidgets('endless survives repeated frames from first build',
        (tester) async {
      // Driving the mix from `build` would only update when something else
      // happened to rebuild the screen, which in endless is almost never.
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: PlayScreen(level: kEndlessShift, seed: 7),
        ),
      );
      await tester.tap(find.text('START BELT'));
      await settleBoot(tester);

      final game = gameOf(tester);
      expect(game.engine.pressure, 0);
      for (var i = 0; i < 30; i++) {
        final front = game.engine.frontMost;
        if (front != null) {
          game.handleBinTap(game.engine.binFor(front.spec));
        }
        game.update(0.2);
      }
      expect(game.engine.pressure, greaterThan(0));
      expect(tester.takeException(), isNull);
    });
  });

  group('shop overlay', () {
    testWidgets('does not advance the engine while the paper retracts',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: PlayScreen(
            level: kEndlessShift,
            seed: 1,
            jump: DevJump.memo,
          ),
        ),
      );
      await settleBoot(tester);

      final game = gameOf(tester);
      expect(find.text('WALK ON'), findsOneWidget);
      expect(game.overlayHoldsEngine, isTrue);

      await tester.tap(find.text('WALK ON'));
      await tester.pump();
      expect(game.engine.isShopping, isFalse);
      expect(game.engine.phase, RunPhase.running);

      final frozen = game.engine.elapsed;
      await tester.pump(const Duration(milliseconds: 100));
      expect(game.engine.elapsed, frozen,
          reason: 'standard exit is 160ms; the belt must not move behind it');

      await tester.pump(const Duration(milliseconds: 200));
      expect(game.overlayHoldsEngine, isFalse);
      await tester.pump(const Duration(milliseconds: 100));
      expect(game.engine.elapsed, greaterThan(frozen),
          reason: 'once the overlay is gone the belt must run again');
    });

    testWidgets('neon exit is longer and still does not move the clock',
        (tester) async {
      await tester.pumpWidget(
        VisualStyleScope(
          notifier: VisualStyleController(initial: VisualStyle.immersiveNeon),
          child: MaterialApp(
            theme: buildTheme(),
            home: PlayScreen(
              level: kEndlessShift,
              seed: 1,
              jump: DevJump.memo,
            ),
          ),
        ),
      );
      await settleBoot(tester);
      final game = gameOf(tester);

      await tester.tap(find.text('WALK ON'));
      await tester.pump();
      final frozen = game.engine.elapsed;
      await tester.pump(const Duration(milliseconds: 200));
      expect(game.engine.elapsed, frozen,
          reason: 'neon exit is ~230ms; 200ms in, the overlay still holds');
      await tester.pump(const Duration(milliseconds: 150));
      expect(game.overlayHoldsEngine, isFalse);
      await tester.pump(const Duration(milliseconds: 100));
      expect(game.engine.elapsed, greaterThan(frozen));
    });
  });
}
