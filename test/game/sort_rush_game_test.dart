import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/game/sfx.dart';
import 'package:sort_rush/game/sort_rush_game.dart';

/// Boots the real Flame surface.
///
/// The unit tests cover the engine without a game loop, which is the point of
/// keeping it engine-free — but that leaves onLoad, layout, and the tap
/// pipeline never actually executed. These tests run them.
void main() {
  Future<SortRushGame> boot(
    WidgetTester tester, {
    int levelId = 1,
    SfxBus sfx = const SilentSfx(),
  }) async {
    final game = SortRushGame(
      level: levelById(levelId),
      seed: 1,
      onRunEnded: (_) {},
      sfx: sfx,
    );
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    // onLoad is async; give it frames to settle before asserting.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    return game;
  }

  testWidgets('boots, starts the belt, and puts a package on it',
      (tester) async {
    final game = await boot(tester);

    expect(game.engine.phase, RunPhase.running);
    expect(game.engine.active, hasLength(1));
  });

  testWidgets('the belt advances as frames are pumped', (tester) async {
    final game = await boot(tester);
    final start = game.engine.frontMost!.progress;

    await tester.pump(const Duration(milliseconds: 500));

    expect(game.engine.frontMost!.progress, greaterThan(start));
  });

  testWidgets('a real tap on a bin routes the front-most package',
      (tester) async {
    final game = await boot(tester);
    expect(game.engine.score.sorted, 0);

    // Level 1 has a single full-width bin, so any tap inside the bin band is
    // the correct destination.
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final binBandTop =
        size.height * (SortRushGame.statusFraction + SortRushGame.beltFraction);
    await tester.tapAt(
      Offset(size.width / 2, binBandTop + size.height * 0.1),
    );
    // Flame's multi-tap recognizer arms a 40ms countdown on pointer-down.
    // Pump past it, or the test ends with a timer still pending.
    await tester.pump(const Duration(milliseconds: 100));

    expect(game.engine.score.sorted, 1);
    expect(game.engine.score.score, 10);
  });

  testWidgets('a correct sort fires a tick on the sfx bus', (tester) async {
    final bus = _LogSfx();
    await boot(tester, sfx: bus);
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final binBandTop =
        size.height * (SortRushGame.statusFraction + SortRushGame.beltFraction);
    await tester.tapAt(
      Offset(size.width / 2, binBandTop + size.height * 0.1),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(bus.log, contains('sorted:1'));
  });

  testWidgets('level 3 lays out one bin per routing destination',
      (tester) async {
    final game = await boot(tester, levelId: 3);

    // Level 3 routes on hue with two hues in play, so it shows two chutes.
    expect(game.level.binCount, 2);
    expect(game.engine.phase, RunPhase.running);
  });

  group('chute boundaries', () {
    // "Destination controls must be large and forgiving" in
    // docs/design-system.md is only true if the edges of a chute are live.

    double chuteWidth(SortRushGame game) =>
        (game.size.x - SortRushGame.binGap * (game.level.binCount - 1)) /
        game.level.binCount;

    double chuteY(SortRushGame game) =>
        game.size.y *
            (SortRushGame.statusFraction + SortRushGame.beltFraction) +
        SortRushGame.binGap +
        (game.size.y * SortRushGame.binsFraction - SortRushGame.binGap * 2) / 2;

    testWidgets('the leading edge of a chute is live', (tester) async {
      final game = await boot(tester, levelId: 2);
      final target = game.level.routing.binFor(game.engine.frontMost!.spec);
      final left = target * (chuteWidth(game) + SortRushGame.binGap);

      await tester.tapAt(Offset(left + 0.5, chuteY(game)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(game.engine.score.sorted, 1);
      expect(game.engine.score.mistakes, 0);
    });

    testWidgets('the trailing edge of a chute is live', (tester) async {
      final game = await boot(tester, levelId: 2);
      final target = game.level.routing.binFor(game.engine.frontMost!.spec);
      final right =
          target * (chuteWidth(game) + SortRushGame.binGap) + chuteWidth(game);

      await tester.tapAt(Offset(right - 0.5, chuteY(game)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(game.engine.score.sorted, 1);
      expect(game.engine.score.mistakes, 0);
    });

    testWidgets('a tap in the gap between chutes costs the player nothing',
        (tester) async {
      final game = await boot(tester, levelId: 2);
      final gapCentre = chuteWidth(game) + SortRushGame.binGap / 2;

      await tester.tapAt(Offset(gapCentre, chuteY(game)));
      await tester.pump(const Duration(milliseconds: 100));

      // Landing between two chutes is a miss, not a misroute. Charging a
      // mistake for it would punish aim rather than judgement.
      expect(game.engine.score.sorted, 0);
      expect(game.engine.score.mistakes, 0);
      expect(game.engine.active, hasLength(1));
    });
  });
}

class _LogSfx implements SfxBus {
  final List<String> log = [];

  @override
  void sorted({required int tier, required bool comboUp}) =>
      log.add(comboUp ? 'combo:$tier' : 'sorted:$tier');

  @override
  void misroute() => log.add('misroute');

  @override
  void dropped() => log.add('dropped');

  @override
  void ended() => log.add('ended');
}
