import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/game/sort_rush_game.dart';

/// Measures the CPU-side cost of one rendered frame, and pins the properties
/// that keep it low.
///
/// This measures paint work on the UI thread — text shaping, path building,
/// allocation — and nothing about the GPU. Rasterisation is where a real
/// device actually falls over, and no test on this machine can see it. Treat
/// the printed numbers as a regression signal, never as evidence of 60fps.
///
/// The assertions are deliberately *structural* rather than timing-based:
/// wall-clock thresholds are flaky under load, while "this getter does not
/// allocate" is exact and fails for a real reason.
void main() {
  Future<SortRushGame> boot(WidgetTester tester, {int levelId = 4}) async {
    final game = SortRushGame(
      level: levelById(levelId),
      seed: 1,
      onRunEnded: (_) {},
    );
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    return game;
  }

  testWidgets('one frame of paint, measured', (tester) async {
    final game = await boot(tester);
    game.onGameResize(Vector2(390, 844));

    // Fill the belt so the measurement is of a busy frame, not an idle one.
    for (var i = 0; i < 400; i++) {
      game.engine.update(1 / 60);
    }

    void renderOnce() {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      game.render(canvas);
      recorder.endRecording().dispose();
    }

    for (var i = 0; i < 50; i++) {
      renderOnce();
    }

    const frames = 400;
    final watch = Stopwatch()..start();
    for (var i = 0; i < frames; i++) {
      renderOnce();
    }
    watch.stop();

    final perFrame = watch.elapsed.inMicroseconds / frames;
    // ignore: avoid_print
    print('paint: ${perFrame.toStringAsFixed(1)} us/frame '
        '(${(perFrame / 16666.7 * 100).toStringAsFixed(1)}% of a 60fps budget, '
        '${game.engine.active.length} packages)');

    expect(perFrame, greaterThan(0));

    // Where the time actually goes. Guessing at the hot spot and optimising
    // it produced no measurable change; this prints the breakdown so the next
    // person does not repeat that.
    for (final child in game.children) {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      for (var i = 0; i < 20; i++) {
        child.renderTree(canvas);
      }
      recorder.endRecording().dispose();

      final componentWatch = Stopwatch()..start();
      final recorder2 = PictureRecorder();
      final canvas2 = Canvas(recorder2);
      for (var i = 0; i < frames; i++) {
        child.renderTree(canvas2);
      }
      componentWatch.stop();
      recorder2.endRecording().dispose();

      // ignore: avoid_print
      print('  ${child.runtimeType}: '
          '${(componentWatch.elapsed.inMicroseconds / frames).toStringAsFixed(1)} us');
    }
  });

  group('the hot path does not allocate', () {
    testWidgets('reading active packages returns a view, not a copy',
        (tester) async {
      final game = await boot(tester);

      // BeltComponent reads this every frame. A defensive copy here is an
      // O(n) allocation per frame that buys nothing, because the list is
      // already unmodifiable to callers.
      expect(identical(game.engine.active, game.engine.active), isTrue);
    });

    testWidgets('the view still reflects the belt', (tester) async {
      // The cheap version must not become a stale snapshot. Compared against
      // a real copy taken up front, because comparing the view to itself
      // would pass no matter what.
      final game = await boot(tester);
      final view = game.engine.active;
      final snapshot = List.of(view);
      expect(snapshot, isNotEmpty);

      final first = view.first;
      while (game.engine.active.contains(first)) {
        game.engine.update(1 / 60);
      }

      expect(view, isNot(orderedEquals(snapshot)),
          reason: 'the view is a stale snapshot, not a live view');
      expect(view.contains(first), isFalse);
    });

    testWidgets('the view cannot be modified through', (tester) async {
      final game = await boot(tester);
      expect(() => game.engine.active.clear(), throwsUnsupportedError);
    });

    testWidgets('draining an empty queue allocates nothing', (tester) async {
      // Drained every frame by SortRushGame.update, and empty on most of
      // them.
      final game = await boot(tester);
      game.engine.drainEvents();

      expect(identical(game.engine.drainEvents(), game.engine.drainEvents()),
          isTrue);
      expect(game.engine.drainEvents(), isEmpty);
    });
  });
}
