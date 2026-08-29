import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/dev/dev_stats.dart';
import 'package:sort_rush/game/components/bin_component.dart';
import 'package:sort_rush/game/sort_rush_game.dart';

/// The chute press is input acknowledgement, so it has to end.
///
/// It shipped without a decay: `_press` was set to 1 and never decremented, so
/// the compression and both registration marks stayed on for the rest of the
/// run. `chute_press_test.dart` only asserted that nothing threw, which is why
/// nothing caught it.
void main() {
  Future<SortRushGame> boot(WidgetTester tester) async {
    final game = SortRushGame(
      level: levelById(2),
      seed: 4,
      onRunEnded: (_) {},
    );
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    return game;
  }

  BinComponent chute(SortRushGame game, int index) =>
      game.children.whereType<BinComponent>().elementAt(index);

  Offset centreOf(SortRushGame game, int index) {
    final w = game.size.x;
    final h = game.size.y;
    final count = game.children.whereType<BinComponent>().length;
    final binWidth = (w - SortRushGame.binGap * (count - 1)) / count;
    return Offset(
      index * (binWidth + SortRushGame.binGap) + binWidth / 2,
      h * (SortRushGame.statusFraction + SortRushGame.beltFraction) +
          h * SortRushGame.binsFraction / 2,
    );
  }

  testWidgets('the press response decays back to rest', (tester) async {
    final game = await boot(tester);
    final bin = chute(game, 1);
    expect(bin.pressLevel, 0);

    // Through the real pipeline, at the chute's centre.
    await tester.tapAt(centreOf(game, 1));
    expect(bin.pressLevel, greaterThan(0),
        reason: 'the press must be visible at all');
    // Clears Flame's multi-tap countdown so no timer outlives the test.
    await tester.pump(const Duration(milliseconds: 100));

    // Well past the 80-140ms the response is specified at.
    for (var i = 0; i < 60; i++) {
      bin.update(1 / 60);
    }
    expect(bin.pressLevel, 0, reason: 'the press must not outlive its event');
  });

  testWidgets('a removed chute hands back what its burst took', (tester) async {
    DevStats.reset();
    final game = await boot(tester);
    final bin = chute(game, 0);

    bin.flashCorrect();
    expect(DevStats.activeBursts, greaterThan(0));
    expect(DevStats.activeParticles, greaterThan(0));

    bin.removeFromParent();
    await tester.pump();
    await tester.pump();

    // A run ends on the same frame as its last sort, so a live burst at
    // teardown is the common case, not an edge one. Left leaking, the static
    // counter drifts for the whole process and the profiler's "returned to
    // baseline" signal becomes worthless from run two onward.
    expect(DevStats.activeBursts, 0);
    expect(DevStats.activeParticles, 0);
  });
}
