import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/package_spec.dart';
import 'package:sort_rush/game/package_painter.dart';

/// A corrupting package must look corrupted.
///
/// This is not a polish test. The whole `DAMAGED` mechanic rests on the player
/// seeing the corrupted state and choosing to hold their tap — that is what
/// makes it randomness resolving *before* a decision rather than after, and it
/// is the argument the mechanic was approved on. Rendered identically to a
/// clean package, it is exactly the silent shape-shift that was rejected.
///
/// It shipped that way: nothing in `lib/game/` read `ActivePackage.isUnstable`
/// until 2026-08-17, while a comment in `sort_rush_game.dart` claimed the
/// state was drawn every frame.
void main() {
  const rect = Rect.fromLTWH(4, 4, 48, 48);
  const spec = PackageSpec(shape: PackageShape.circle, colorIndex: 0);

  Future<List<int>> render({
    required bool isActive,
    required bool isUnstable,
    PackageSpec of = spec,
  }) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 56, 56));
    PackagePainter.paintPackage(
      canvas,
      rect,
      of,
      isActive: isActive,
      isUnstable: isUnstable,
    );
    final image = await recorder.endRecording().toImage(56, 56);
    final data = await image.toByteData(format: ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List().toList();
  }

  test('a corrupting package does not look like a clean one', () async {
    expect(
      await render(isActive: false, isUnstable: true),
      isNot(await render(isActive: false, isUnstable: false)),
    );
  });

  test('it is distinguishable even while it is the active package', () async {
    // The active package already carries an acid halo and a heavier stroke.
    // Corruption has to read through that, or the one package the player is
    // about to tap is the one whose warning is hidden.
    expect(
      await render(isActive: true, isUnstable: true),
      isNot(await render(isActive: true, isUnstable: false)),
    );
  });

  test('corruption reads differently from selection', () async {
    // Damage and "this is the one you are about to route" must not look alike.
    expect(
      await render(isActive: false, isUnstable: true),
      isNot(await render(isActive: true, isUnstable: false)),
    );
  });

  test('it is stable frame to frame, not a strobe', () async {
    // docs/design-system.md forbids rapid flashing. Drawing the corrupted
    // state from a per-frame random would fail this.
    final first = await render(isActive: false, isUnstable: true);
    final second = await render(isActive: false, isUnstable: true);
    expect(first, second);
  });

  test('every shape shows corruption', () async {
    for (final shape in PackageShape.values) {
      final of = PackageSpec(shape: shape, colorIndex: 1);
      expect(
        await render(isActive: false, isUnstable: true, of: of),
        isNot(await render(isActive: false, isUnstable: false, of: of)),
        reason: '${shape.name} does not show its corrupted state',
      );
    }
  });
}
