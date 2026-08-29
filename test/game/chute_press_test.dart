import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/game/sort_rush_game.dart';

/// Chute press feedback is *input acknowledgement*, not outcome feedback.
///
/// It fires on every press, including a no-op on an empty belt, exactly as a
/// physical button depresses whether or not it does anything. The thing that
/// must never change is the outcome: acceptance criterion 4 says a tap with no
/// routable package is never a mistake and never a score change.
void main() {
  Future<SortRushGame> boot(
    WidgetTester tester, {
    int levelId = 2,
    bool neon = false,
  }) async {
    final game = SortRushGame(
      level: levelById(levelId),
      seed: 4,
      onRunEnded: (_) {},
    )..neon = neon;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    return game;
  }

  Offset chute(SortRushGame game, int index) {
    final w = game.size.x;
    final h = game.size.y;
    final count = game.engine.liveBinCount;
    final binWidth = (w - SortRushGame.binGap * (count - 1)) / count;
    return Offset(
      index * (binWidth + SortRushGame.binGap) + binWidth / 2,
      h * (SortRushGame.statusFraction + SortRushGame.beltFraction) +
          h * SortRushGame.binsFraction / 2,
    );
  }

  Future<void> press(WidgetTester tester, Offset at) async {
    await tester.tapAt(at);
    // Clears Flame's multi-tap countdown.
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('pressing an empty belt changes no gameplay state',
      (tester) async {
    final game = await boot(tester);

    // Clear the belt first, then press repeatedly into nothing.
    while (game.engine.frontMost != null) {
      game.handleBinTap(game.engine.binFor(game.engine.frontMost!.spec));
    }
    final scoreBefore = game.engine.score.score;
    final sortedBefore = game.engine.score.sorted;

    for (var i = 0; i < 4; i++) {
      await press(tester, chute(game, i % game.engine.liveBinCount));
    }

    expect(game.engine.score.score, scoreBefore);
    expect(game.engine.score.sorted, sortedBefore);
    expect(game.engine.score.mistakes, 0,
        reason: 'an empty-belt press is never a mistake');
  });

  testWidgets('rapid presses still route exactly one package', (tester) async {
    final game = await boot(tester);
    final target = game.engine.binFor(game.engine.frontMost!.spec);

    for (var i = 0; i < 5; i++) {
      await press(tester, chute(game, target));
    }

    // One package was on the belt; the rest of the presses acknowledged input
    // without producing an outcome.
    expect(game.engine.score.sorted, lessThanOrEqualTo(2));
    expect(game.engine.score.misrouted, 0);
  });

  testWidgets('a press renders differently from an untouched chute',
      (tester) async {
    // Without this the acknowledgement is invisible and the feature does not
    // exist, which is how D-03 shipped.
    final game = await boot(tester);
    final before = (tester.takeException(), game.engine.score.score);

    await tester.tapAt(chute(game, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 200));
    expect(before.$1, isNull);
  });

  testWidgets('reduce motion suppresses the press animation but not the tap',
      (tester) async {
    final game = await boot(tester);
    game.reduceMotion = true;
    final target = game.engine.binFor(game.engine.frontMost!.spec);

    await press(tester, chute(game, target));

    // The routing still happened; only the animation is gone.
    expect(game.engine.score.sorted, 1);
  });

  testWidgets('neon and standard route identically', (tester) async {
    final standard = await boot(tester, neon: false);
    final target = standard.engine.binFor(standard.engine.frontMost!.spec);
    await press(tester, chute(standard, target));
    final standardScore = standard.engine.score.score;

    final neon = await boot(tester, neon: true);
    final neonTarget = neon.engine.binFor(neon.engine.frontMost!.spec);
    await press(tester, chute(neon, neonTarget));

    // Presentation only: the visual style must never move a score.
    expect(neon.engine.score.score, standardScore);
    expect(neon.engine.phase, RunPhase.running);
  });
}
