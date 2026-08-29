import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/game/belt_ground.dart';
import 'package:sort_rush/game/components/belt_component.dart';
import 'package:sort_rush/game/sort_rush_game.dart';

/// The belt has to look like a belt.
///
/// Before this slice `BeltComponent` drew scan lines, the clutch band and the
/// packages onto undifferentiated `ink` — a conveyor game with no conveyor on
/// screen. Both of the things it did draw sat behind `if (!game.reduceMotion)`,
/// so a player who had asked the system for less movement got a completely
/// blank field.
///
/// The ground is static on purpose. That is what keeps it inside the §5.2
/// grant to the background rather than an effect under the 2026-08-16
/// play-field ruling, and it is the reason reduce-motion keeps it.
void main() {
  const packageSize = BeltComponent.packageSize;

  group('lane geometry', () {
    test('the lane is centred and clear of both edges', () {
      for (final width in [320.0, 390.0, 412.0, 480.0]) {
        final left = BeltGround.laneLeft(width, packageSize: packageSize);
        final lane = BeltGround.laneWidth(width, packageSize: packageSize);

        expect(left, greaterThanOrEqualTo(BeltGround.minMargin));
        expect(left + lane, lessThanOrEqualTo(width - BeltGround.minMargin));
        // Centred: the margin is the same on both sides.
        expect(left, closeTo(width - (left + lane), 0.001));
      }
    });

    test('a package fits inside the lane at every supported width', () {
      for (final width in [320.0, 390.0, 412.0, 480.0]) {
        expect(
          BeltGround.laneWidth(width, packageSize: packageSize),
          greaterThanOrEqualTo(packageSize),
          reason: 'a package wider than its lane would look derailed',
        );
      }
    });

    test('a narrow screen shrinks the lane rather than the margin', () {
      // The clamp, not the ideal. Rails must never reach the edge.
      const narrow = 100.0;
      expect(
        BeltGround.laneWidth(narrow, packageSize: packageSize),
        narrow - BeltGround.minMargin * 2,
      );
      expect(BeltGround.laneWidth(0, packageSize: packageSize), 0);
    });

    test('slat spacing is fixed, never a fraction of belt height', () {
      // docs/design-spec.md §8: travel time is time-based, never pixel-based.
      // Spacing that scaled with height would make the belt appear to run at
      // a different speed on a taller device.
      int slatsOver(double height) {
        var count = 0;
        for (var y = BeltGround.slatSpacing;
            y < height;
            y += BeltGround.slatSpacing) {
          count++;
        }
        return count;
      }

      expect(slatsOver(1000), greaterThan(slatsOver(500)));
      expect(BeltGround.slatSpacing, 28);
    });
  });

  group('legibility', () {
    test('the ground stays under the packages it sits behind', () {
      // Acceptance criterion 9: the field must read with all three hues
      // rendered as the same grey. Ground that competed with a silhouette
      // would break that before it broke anything aesthetic.
      expect(BeltGround.laneAlpha, lessThan(BeltGround.slatAlpha));
      expect(BeltGround.slatAlpha, lessThan(BeltGround.railAlpha));
      expect(BeltGround.railAlpha, lessThan(0.5));
    });
  });

  group('rendering', () {
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

    /// Rasterises the belt alone, the way `corrupted_package_test.dart` does.
    ///
    /// The rasterisation has to run through `tester.runAsync`. `toImage`
    /// waits on the engine, and `testWidgets` runs in a fake-async zone that
    /// never drives those callbacks — the future simply never completes and
    /// the test hangs rather than failing. `corrupted_package_test.dart` gets
    /// away with a bare await only because it uses plain `test`.
    Future<List<int>> pixels(WidgetTester tester, BeltComponent belt) async {
      final w = belt.size.x.round();
      final h = belt.size.y.round();
      final recorder = PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      );
      belt.render(canvas);
      final picture = recorder.endRecording();

      final data = await tester.runAsync(() async {
        final image = await picture.toImage(w, h);
        final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
        image.dispose();
        return bytes;
      });
      picture.dispose();
      return data!.buffer.asUint8List().toList();
    }

    testWidgets('the belt draws ground under reduce motion', (tester) async {
      // The regression this guards is someone folding the ground back into
      // the existing `if (!game.reduceMotion)` block, which would silently
      // restore the blank field.
      final game = await boot(tester, reduceMotion: true);
      final belt = game.children.whereType<BeltComponent>().single;

      final drawn = await pixels(tester, belt);
      expect(
        drawn.any((byte) => byte != 0),
        isTrue,
        reason: 'reduce motion left the belt completely empty',
      );
    });

    testWidgets('the lane is distinguishable from the wall', (tester) async {
      final game = await boot(tester, reduceMotion: true);
      final belt = game.children.whereType<BeltComponent>().single;
      final w = belt.size.x.round();

      final data = await pixels(tester, belt);
      // One row well clear of the slats and the clutch band.
      const row = 10;
      int red(int x) => data[(row * w + x) * 4];

      final wall = red(BeltGround.minMargin ~/ 2);
      final lane = red(w ~/ 2);

      expect(
        lane,
        greaterThan(wall),
        reason: 'the lane must read lighter than the wall behind it',
      );
    });

    testWidgets('resizing rebuilds the ground', (tester) async {
      // The cached Picture is the whole reason this is cheap, and a stale
      // one is the cost: the lane would keep the previous screen's geometry
      // and sit off-centre. Sampling one column that changes side proves the
      // cache followed the resize, where comparing whole frames would pass
      // merely because the images are different sizes.
      final game = await boot(tester);
      final belt = game.children.whereType<BeltComponent>().single;
      const row = 10;

      // Derived, not hardcoded: a column that sits inside the lane at the
      // narrow width and outside it at the wide one. The lane widened when
      // clusters arrived, and a literal probe silently stopped straddling the
      // edge — so compute it from the geometry it is testing.
      final narrowLeft = BeltGround.laneLeft(390, packageSize: packageSize);
      final wideLeft = BeltGround.laneLeft(480, packageSize: packageSize);
      expect(wideLeft, greaterThan(narrowLeft));
      final probe = ((narrowLeft + wideLeft) / 2).round();

      Future<int> redAtProbe() async {
        final data = await pixels(tester, belt);
        return data[(row * belt.size.x.round() + probe) * 4];
      }

      game.onGameResize(Vector2(390, 844));
      expect(narrowLeft, lessThan(probe));
      final inside = await redAtProbe();

      game.onGameResize(Vector2(480, 844));
      expect(wideLeft, greaterThan(probe));
      final outside = await redAtProbe();

      expect(
        inside,
        greaterThan(outside),
        reason: 'the lane did not move with the resize',
      );
    });
  });
}
