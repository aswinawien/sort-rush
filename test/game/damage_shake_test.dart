import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/core/run_tuning.dart';
import 'package:sort_rush/game/sort_rush_game.dart';

/// Losing a package shakes the screen.
///
/// This is feedback, not decoration: it reports damage, which is what the
/// 2026-08-16 play-field ruling requires of any effect during running. Three
/// properties are load-bearing and each has a test here — it is bounded, it
/// obeys reduce-motion, and it never moves a tap target.
void main() {
  Future<SortRushGame> boot(
    WidgetTester tester, {
    bool reduceMotion = false,
    int levelId = 2,
  }) async {
    final game = SortRushGame(
      level: levelById(levelId),
      seed: 3,
      onRunEnded: (_) {},
    )..reduceMotion = reduceMotion;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    return game;
  }

  /// Routes to a deliberately wrong chute, then lets the shell drain events.
  Future<void> misroute(WidgetTester tester, SortRushGame game) async {
    final front = game.engine.frontMost!;
    for (var i = 0; i < game.engine.liveBinCount; i++) {
      if (!game.engine.isCorrectBin(front.spec, i)) {
        game.handleBinTap(i);
        break;
      }
    }
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('a misroute shakes the screen', (tester) async {
    final game = await boot(tester);
    expect(game.isShaking, isFalse);
    await misroute(tester, game);
    expect(game.isShaking, isTrue);
  });

  testWidgets('reduce motion never shakes', (tester) async {
    final game = await boot(tester, reduceMotion: true);
    await misroute(tester, game);
    expect(
      game.isShaking,
      isFalse,
      reason: 'reduce motion asked for less movement, not a shorter shake',
    );
  });

  testWidgets('the shake is bounded and decays to rest', (tester) async {
    final game = await boot(tester);
    await misroute(tester, game);
    expect(game.isShaking, isTrue);

    // Well past the specified duration.
    for (var i = 0; i < 40; i++) {
      game.update(1 / 60);
    }
    expect(game.isShaking, isFalse);
    expect(SortRushGame.shakeSeconds, lessThanOrEqualTo(0.18));
    expect(SortRushGame.shakePixels, lessThanOrEqualTo(6));
  });

  test('the spawn floor already keeps damage out of the clutch window', () {
    // `_shakeForDamage` suppresses the shake when the next package is inside
    // the clutch window, because shaking during the last 0.5s before the sort
    // line would corrupt the read the clutch band exists to protect.
    //
    // That guard is currently UNREACHABLE, and this is the reason. Packages
    // trail each other by `spawnInterval / readWindow` of travel while the
    // clutch window is `clutchWindow / readWindow` of it, so the follower can
    // only be inside the window when `spawnInterval < clutchWindow`. The
    // fairness floor forbids exactly that.
    //
    // The guard stays as a cheap safety net. This test is what makes it dead
    // code on purpose rather than by accident: lower the spawn floor past the
    // clutch window and it fails, telling you the shake now needs it.
    expect(
      RunTuning.spawnIntervalFloor,
      greaterThan(RunEngine.clutchWindow),
      reason: 'a follower can now sit in the clutch window; the shake '
          'suppression in SortRushGame is live and needs its own test',
    );
  });

  testWidgets('a shaking screen does not move the chutes', (tester) async {
    // The canvas is displaced; the components are not. Flame hit-tests
    // against component positions, so a tap during the shake must still land
    // exactly where it would at rest — a shake that relocated the chutes
    // would punish the player for the mistake it is reporting.
    // Level 9 carries up to four packages, so misrouting the front one
    // leaves another behind to route during the shake.
    final game = await boot(tester, levelId: 9);
    for (var i = 0; i < 90; i++) {
      game.engine.update(1 / 60);
    }
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.engine.active.length, greaterThanOrEqualTo(2));

    await misroute(tester, game);
    expect(game.isShaking, isTrue);

    final sortedBefore = game.engine.score.sorted;
    final front = game.engine.frontMost;
    expect(front, isNotNull);

    var correct = -1;
    for (var i = 0; i < game.engine.liveBinCount; i++) {
      if (game.engine.isCorrectBin(front!.spec, i)) {
        correct = i;
        break;
      }
    }
    expect(correct, greaterThanOrEqualTo(0));

    final h = game.size.y;
    final w = game.size.x;
    final count = game.children.length;
    final binCount = game.engine.liveBinCount;
    final binWidth = (w - SortRushGame.binGap * (binCount - 1)) / binCount;
    expect(count, greaterThan(0));

    await tester.tapAt(
      Offset(
        correct * (binWidth + SortRushGame.binGap) + binWidth / 2,
        h * (SortRushGame.statusFraction + SortRushGame.beltFraction) +
            h * SortRushGame.binsFraction / 2,
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    expect(
      game.engine.score.sorted,
      sortedBefore + 1,
      reason: 'the tap missed, so the shake moved the hit area',
    );

    // Flush the gesture recognizer's own deadline timer, which outlives a
    // 16ms pump and trips the binding's pending-timer assertion at teardown.
    await tester.pump(const Duration(seconds: 1));
  });
}
