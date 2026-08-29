import 'dart:io';
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/game/sort_rush_game.dart';

/// Renders play-field frames straight to PNG, with no browser and no capture
/// harness. Run it, do not commit its output blindly:
///
///     flutter test tool/capture_play_field.dart
///
/// Software rendering makes this deterministic, so two runs of the same seed
/// and the same frame count produce identical files. It sees the CPU paint
/// path only — it is a way to look at the composition, never evidence about
/// frame rate on a device.
void main() {
  const width = 390.0;
  const height = 844.0;

  Future<void> shoot(
    WidgetTester tester, {
    required String name,
    required int levelId,
    required int ticks,
    bool reduceMotion = false,
    bool neon = false,
  }) async {
    final game = SortRushGame(
      level: levelById(levelId),
      seed: 7,
      onRunEnded: (_) {},
    )
      ..reduceMotion = reduceMotion
      ..neon = neon;

    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    game.onGameResize(Vector2(width, height));

    for (var i = 0; i < ticks; i++) {
      game.engine.update(1 / 60);
    }
    await tester.pump(const Duration(milliseconds: 16));

    final recorder = PictureRecorder();
    final canvas = Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, width, height),
    );
    // The scaffold colour the real game paints behind the components.
    canvas.drawPaint(Paint()..color = game.backgroundColor());
    game.render(canvas);
    final picture = recorder.endRecording();

    await tester.runAsync(() async {
      final image = await picture.toImage(width.round(), height.round());
      final data = await image.toByteData(format: ImageByteFormat.png);
      image.dispose();
      final out = File('${Directory.systemTemp.path}/sort-rush-capture/$name');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(data!.buffer.asUint8List());
      // ignore: avoid_print
      print('wrote ${out.path}');
    });
    picture.dispose();
  }

  testWidgets('capture', (tester) async {
    await shoot(tester, name: '01-level1.png', levelId: 1, ticks: 120);
    await shoot(tester, name: '02-level4.png', levelId: 4, ticks: 400);
    await shoot(
      tester,
      name: '03-level4-reduce-motion.png',
      levelId: 4,
      ticks: 400,
      reduceMotion: true,
    );
  });
}
