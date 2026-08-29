import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/package_spec.dart';
import 'package:sort_rush/game/package_painter.dart';

/// The slash is how the player learns the matched chute is forbidden.
/// Without it, hazardous cargo is a silent invert — the thing the
/// DAMAGED telegraph was rejected for.
void main() {
  const rect = Rect.fromLTWH(4, 4, 48, 48);

  Future<List<int>> render({
    required bool hazardous,
    bool isActive = false,
    PackageShape shape = PackageShape.circle,
  }) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 56, 56));
    PackagePainter.paintPackage(
      canvas,
      rect,
      PackageSpec(shape: shape, colorIndex: 0),
      isActive: isActive,
      hazardous: hazardous,
    );
    final image = await recorder.endRecording().toImage(56, 56);
    final data = await image.toByteData(format: ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List().toList();
  }

  test('a hazardous package does not look like a clean one', () async {
    expect(
      await render(hazardous: true),
      isNot(await render(hazardous: false)),
    );
  });

  test('the slash reads through the active marker', () async {
    expect(
      await render(hazardous: true, isActive: true),
      isNot(await render(hazardous: false, isActive: true)),
    );
  });

  test('the slash is stable frame to frame, not a strobe', () async {
    expect(
      await render(hazardous: true),
      await render(hazardous: true),
    );
  });

  test('every shape shows the slash', () async {
    for (final shape in PackageShape.values) {
      expect(
        await render(hazardous: true, shape: shape),
        isNot(await render(hazardous: false, shape: shape)),
      );
    }
  });
}
