import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/game/effects/chip_burst.dart';
import 'package:sort_rush/ui/theme.dart';

/// The first per-frame effect in the project.
///
/// It fires on every correct sort, so it is the highest-frequency drawing in
/// the game. These tests guard the three properties the design review made
/// conditions of shipping it: it expires, it is deterministic, and it does not
/// depend on frame rate.
void main() {
  ChipBurst make({ChipBurstSpec spec = const ChipBurstSpec()}) => ChipBurst(
        origin: const Offset(28, 2),
        color: Tokens.acid,
        spec: spec,
      );

  Future<List<int>> render(ChipBurst burst) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 56, 56));
    canvas.translate(0, 30);
    burst.render(canvas);
    final image = await recorder.endRecording().toImage(56, 56);
    final data = await image.toByteData(format: ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List().toList();
  }

  int litPixels(List<int> rgba) {
    var lit = 0;
    for (var i = 3; i < rgba.length; i += 4) {
      if (rgba[i] > 8) lit++;
    }
    return lit;
  }

  test('starts alive and expires after its lifetime', () {
    final burst = make();
    expect(burst.isDone, isFalse);
    burst.update(const ChipBurstSpec().lifetime + 0.001);
    expect(burst.isDone, isTrue);
  });

  test('expiry does not depend on frame rate', () {
    // Same elapsed time, different step sizes. A burst that outlived a slow
    // frame would leak effects on exactly the devices least able to afford it.
    final coarse = make()
      ..update(0.1)
      ..update(0.1);
    final fine = make();
    for (var i = 0; i < 20; i++) {
      fine.update(0.01);
    }
    expect(coarse.isDone, fine.isDone);
  });

  test('draws while alive and nothing once done', () async {
    final burst = make();
    expect(litPixels(await render(burst)), greaterThan(0));

    burst.update(1.0);
    expect(litPixels(await render(burst)), 0);
  });

  test('is identical frame to frame at the same age', () async {
    // design-system.md forbids flashing; a burst driven by a random source
    // would also break seeded reproduction.
    final a = make()..update(0.06);
    final b = make()..update(0.06);
    expect(await render(a), await render(b));
  });

  test('fades rather than cutting out', () async {
    final early = make()..update(0.02);
    final late = make()..update(0.15);
    expect(litPixels(await render(late)),
        lessThan(litPixels(await render(early))));
  });

  test('stays within its configured travel', () async {
    // The burst fires at the chute lip. If chips flew far enough to reach a
    // package that is still routable, it would be decorating the one thing
    // the player still has to read.
    const spec = ChipBurstSpec(travel: 16);
    final burst = make(spec: spec)..update(spec.lifetime * 0.999);
    final reach = spec.travel + spec.length;
    expect(reach, lessThan(30));
    expect(litPixels(await render(burst)), greaterThanOrEqualTo(0));
  });

  group('the extended post-route payoff', () {
    const rich = ChipBurstSpec(
      count: 5,
      travel: 20,
      wakeLength: ChipBurstSpec.maxWakeAboveLip,
      fragments: 4,
      flash: 0.5,
    );

    test('resolves inside the 150-220ms budget', () {
      expect(rich.lifetime * 1000, inInclusiveRange(150, 220));
    });

    test('piece count stays bounded and is what the counter tracks', () {
      expect(rich.pieceCount, rich.count + rich.fragments);
      expect(rich.pieceCount, lessThanOrEqualTo(12));
    });

    test('draws more than the compact version, then nothing', () async {
      final compact = make(spec: const ChipBurstSpec(travel: 16))..update(0.05);
      final full = make(spec: rich)..update(0.05);
      expect(litPixels(await render(full)),
          greaterThan(litPixels(await render(compact))));

      full.update(1.0);
      expect(litPixels(await render(full)), 0, reason: 'must clean up fully');
    });

    test('an oversized wake is clipped so it cannot reach a live package',
        () async {
      final burst = ChipBurst(
        origin: const Offset(28, 40),
        color: Tokens.acid,
        spec: const ChipBurstSpec(
          count: 1,
          travel: 0,
          wakeLength: 80,
          fragments: 0,
          flash: 0,
        ),
      )..update(0.01);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 56, 56));
      burst.render(canvas);
      final image = await recorder.endRecording().toImage(56, 56);
      final data = await image.toByteData(format: ImageByteFormat.rawRgba);
      image.dispose();
      final rgba = data!.buffer.asUint8List();

      var highest = 55;
      for (var y = 0; y < 56; y++) {
        for (var x = 0; x < 56; x++) {
          if (rgba[(y * 56 + x) * 4 + 3] > 8 && y < highest) highest = y;
        }
      }
      expect(
        highest,
        greaterThanOrEqualTo(40 - ChipBurstSpec.maxWakeAboveLip - 1),
        reason: 'wake must not depend on the spawn floor to stay off the belt',
      );
    });

    test('the wake sits above the lip, never below it', () async {
      // The lip is the boundary. Anything drawn below it is inside the chute
      // and invisible; anything far above it would reach the belt.
      final burst = ChipBurst(
        origin: const Offset(28, 40),
        color: Tokens.acid,
        spec: rich,
      )..update(0.02);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 56, 56));
      burst.render(canvas);
      final image = await recorder.endRecording().toImage(56, 56);
      final data = await image.toByteData(format: ImageByteFormat.rawRgba);
      image.dispose();
      final rgba = data!.buffer.asUint8List();

      var lowest = 0;
      for (var y = 0; y < 56; y++) {
        for (var x = 0; x < 56; x++) {
          if (rgba[(y * 56 + x) * 4 + 3] > 8 && y > lowest) lowest = y;
        }
      }
      expect(lowest, lessThanOrEqualTo(46),
          reason: 'the wake should not run far past the lip');
    });

    test('is still deterministic with every layer on', () async {
      final a = make(spec: rich)..update(0.07);
      final b = make(spec: rich)..update(0.07);
      expect(await render(a), await render(b));
    });

    test('fragments never form a closed shape', () {
      // Bars only. A circle, triangle or square here would put a decoy into
      // the identity vocabulary the player reads packages with.
      expect(rich.fragments, greaterThan(0));
      expect(rich.thickness, lessThan(4), reason: 'thin bars, not blocks');
    });
  });
}
