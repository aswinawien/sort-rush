import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/package_spec.dart';
import 'package:sort_rush/game/package_painter.dart';

/// A PRIORITY package must look stamped.
///
/// The override is the whole mechanic. Drawn identically to a clean package,
/// the reflex chute is a silent lie — the same failure as an undrawn DAMAGED
/// telegraph.
void main() {
  const rect = Rect.fromLTWH(4, 4, 48, 48);
  const clean = PackageSpec(shape: PackageShape.circle, colorIndex: 0);
  const stamped = PackageSpec(
    shape: PackageShape.circle,
    colorIndex: 0,
    stamp: PackageStamp.priority,
  );

  Future<List<int>> render(PackageSpec spec, {required bool isActive}) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 56, 56));
    PackagePainter.paintPackage(
      canvas,
      rect,
      spec,
      isActive: isActive,
    );
    final image = await recorder.endRecording().toImage(56, 56);
    final data = await image.toByteData(format: ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List().toList();
  }

  test('a priority package does not look like a clean one', () async {
    expect(
      await render(stamped, isActive: false),
      isNot(await render(clean, isActive: false)),
    );
  });

  test('the stamp reads through the active halo', () async {
    expect(
      await render(stamped, isActive: true),
      isNot(await render(clean, isActive: true)),
    );
  });

  test('it is stable frame to frame, not a strobe', () async {
    expect(
      await render(stamped, isActive: false),
      await render(stamped, isActive: false),
    );
  });
}
