import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/package_spec.dart';
import 'package:sort_rush/core/routing.dart';
import 'package:sort_rush/game/package_painter.dart';

/// Every chute must be told apart from every other chute by looking at it.
///
/// This is not a polish concern. The routing rule decides where a package
/// belongs; the chute's face is the only way the player learns that rule. Two
/// chutes that render identically while accepting different packages make
/// every misroute between them unexplainable, which is the one thing
/// `docs/level-spec.md` says must never happen.
///
/// Found by eye on 2026-08-17, not by the 211 tests that existed at the time:
/// `paintBinIdentity` returned after drawing the silhouette, so a chute
/// carrying both a shape and a pattern never drew the pattern. Levels 8, 9 and
/// endless all shipped with two indistinguishable chutes.
void main() {
  const rect = Rect.fromLTWH(0, 0, 40, 40);

  Future<List<int>> renderBin(BinSpec spec) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder, rect);
    PackagePainter.paintBinIdentity(
      canvas,
      rect,
      shape: spec.shape,
      pattern: spec.pattern,
    );
    final image = await recorder.endRecording().toImage(40, 40);
    final data = await image.toByteData(format: ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List().toList();
  }

  test('a chute that carries a pattern actually draws it', () async {
    // The exact regression: same silhouette, different pattern.
    const solid = BinSpec(
      label: 'A',
      shape: PackageShape.circle,
      pattern: FillPattern.solid,
    );
    const hatched = BinSpec(
      label: 'B',
      shape: PackageShape.circle,
      pattern: FillPattern.hatch,
    );

    expect(await renderBin(solid), isNot(await renderBin(hatched)));
  });

  test('every chute of every level is distinguishable from its neighbours',
      () async {
    for (final level in [...kCuratedLevels, kEndlessShift]) {
      final bins = level.routing.bins;
      final rendered = <List<int>>[];
      for (final bin in bins) {
        rendered.add(await renderBin(bin));
      }

      for (var i = 0; i < bins.length; i++) {
        for (var j = i + 1; j < bins.length; j++) {
          expect(
            rendered[i],
            isNot(rendered[j]),
            reason: 'level ${level.id}: chutes ${bins[i].label} and '
                '${bins[j].label} render identically',
          );
        }
      }
    }
  });

  test('a chute with no pattern still draws its silhouette', () async {
    // Shape-routed levels carry no pattern at all, and must not regress into
    // drawing nothing.
    const circle = BinSpec(label: 'A', shape: PackageShape.circle);
    const blank = BinSpec(label: 'A', shape: PackageShape.square);

    expect(await renderBin(circle), isNot(await renderBin(blank)));
  });
}
