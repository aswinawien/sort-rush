import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/core/run_tuning.dart';
import 'package:sort_rush/game/clutch_band.dart';
import 'package:sort_rush/game/components/sort_line_component.dart';
import 'package:sort_rush/game/sort_rush_game.dart';

/// The clutch band is a presentation of an approved rule, not a new one.
///
/// Height is derived from the live read window so a slow level and the
/// 1.20s floor paint the same 0.5s of travel. The sort line's colour flip
/// is that same instant. Tapping the band must not route anything.
void main() {
  test('the sort line warns at the clutch window, not earlier', () {
    expect(SortLineComponent.warnWindow, RunEngine.clutchWindow);
  });

  test('band height is the last clutchWindow of travel', () {
    const beltHeight = 620.0;
    expect(
      clutchBandHeight(beltHeight, 4.0),
      beltHeight * (RunEngine.clutchWindow / 4.0),
    );
    expect(
      clutchBandHeight(beltHeight, RunTuning.readWindowFloor),
      beltHeight * (RunEngine.clutchWindow / RunTuning.readWindowFloor),
    );
  });

  test('an empty belt sizes the band from current tuning', () {
    expect(
      clutchBandReadWindow(liveReadWindow: null, tuningReadWindow: 4.0),
      4.0,
    );
    expect(
      clutchBandReadWindow(liveReadWindow: 1.20, tuningReadWindow: 4.0),
      1.20,
    );
  });

  Future<SortRushGame> boot(
    WidgetTester tester, {
    bool reduceMotion = false,
  }) async {
    final game = SortRushGame(
      level: levelById(1),
      seed: 1,
      onRunEnded: (_) {},
    )..reduceMotion = reduceMotion;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    return game;
  }

  testWidgets('tapping the clutch band does not route a package',
      (tester) async {
    final game = await boot(tester);
    expect(game.engine.score.sorted, 0);

    final beltHeight = game.size.y * SortRushGame.beltFraction;
    final statusHeight = game.size.y * SortRushGame.statusFraction;
    final readWindow = game.engine.frontMost!.readWindow;
    final bandH = clutchBandHeight(beltHeight, readWindow);
    await tester.tapAt(
      Offset(game.size.x / 2, statusHeight + beltHeight - bandH / 2),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(game.engine.score.sorted, 0);
    expect(game.engine.score.score, 0);
  });

  testWidgets('reduce motion keeps the colour flip and still boots',
      (tester) async {
    final game = await boot(tester, reduceMotion: true);
    expect(game.reduceMotion, isTrue);
    expect(game.engine.phase, RunPhase.running);

    while (game.engine.timeToLine! > SortLineComponent.warnWindow) {
      game.engine.update(1 / 60);
    }
    await tester.pump(const Duration(milliseconds: 16));

    expect(game.engine.timeToLine, lessThanOrEqualTo(RunEngine.clutchWindow));
    expect(game.engine.phase, RunPhase.running);
  });
}
