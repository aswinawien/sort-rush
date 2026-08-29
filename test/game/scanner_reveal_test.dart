import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/package_spec.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/core/run_tuning.dart';
import 'package:sort_rush/game/clutch_band.dart';
import 'package:sort_rush/game/package_painter.dart';

/// Hidden labels are the whole scanner rule. A hidden package that still
/// showed its identity would be the mechanic lying, same class of bug as
/// an invisible DAMAGED telegraph.
void main() {
  const rect = Rect.fromLTWH(4, 4, 48, 48);
  const spec = PackageSpec(shape: PackageShape.circle, colorIndex: 0);

  Future<List<int>> render({
    required bool labelVisible,
    bool isActive = false,
    bool isUnstable = false,
    bool hazardous = false,
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
      labelVisible: labelVisible,
      hazardous: hazardous,
    );
    final image = await recorder.endRecording().toImage(56, 56);
    final data = await image.toByteData(format: ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List().toList();
  }

  test('a hidden label does not look like the real package', () async {
    expect(
      await render(labelVisible: false),
      isNot(await render(labelVisible: true)),
    );
  });

  test('hiding is stable frame to frame, not a strobe', () async {
    expect(
      await render(labelVisible: false),
      await render(labelVisible: false),
    );
  });

  test('a hidden label does not leak DAMAGED or PRIORITY', () async {
    const damaged = PackageSpec(
      shape: PackageShape.circle,
      colorIndex: 0,
      stamp: PackageStamp.damaged,
    );
    const priority = PackageSpec(
      shape: PackageShape.circle,
      colorIndex: 0,
      stamp: PackageStamp.priority,
    );
    final hidden = await render(labelVisible: false);
    expect(hidden, await render(labelVisible: false, of: damaged));
    expect(hidden, await render(labelVisible: false, of: priority));
    expect(
      hidden,
      await render(labelVisible: false, isUnstable: true, of: damaged),
    );
  });

  test('a hidden label does not leak the hazard slash', () async {
    expect(
      await render(labelVisible: false, hazardous: true),
      await render(labelVisible: false, hazardous: false),
    );
  });

  test('the clutch band still sizes from the live read window', () {
    const belt = 620.0;
    expect(
      clutchBandHeight(belt, RunTuning.readWindowFloor),
      belt * (RunEngine.clutchWindow / RunTuning.readWindowFloor),
    );
    expect(RunEngine.scannerRevealAt, isNot(RunEngine.clutchWindow));
  });
}
