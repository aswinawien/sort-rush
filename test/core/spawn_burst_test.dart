import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/difficulty.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/run_engine.dart';

import 'test_level.dart';

/// Packages arrive in clusters deep into endless.
///
/// The lever exists because density is `readWindow / spawnInterval` and both
/// sit on their fairness floors by P=130 — so the only way left to crowd the
/// belt is to change the *shape* of arrivals, not their rate.
///
/// The load-bearing property is that **average spacing is unchanged**: a
/// cluster is paid for by the recovery gap that follows it. What genuinely
/// changes is local reading time inside a cluster, which is a real trade and
/// is why this wants a device session before the thresholds are settled.
void main() {
  const curve = EndlessCurve();

  group('the curve', () {
    test('single file until deep in the run', () {
      expect(curve.burstSizeAt(0), 1);
      expect(curve.burstSizeAt(EndlessCurve.phaseTwoEnd), 1);
      expect(curve.burstSizeAt(EndlessCurve.burstTwoAt - 1), 1);
    });

    test('clusters grow with pressure and then hold', () {
      expect(curve.burstSizeAt(EndlessCurve.burstTwoAt), 2);
      expect(curve.burstSizeAt(EndlessCurve.burstThreeAt), 3);
      expect(curve.burstSizeAt(5000), 3);
    });

    test('a curated shift never clusters', () {
      expect(levelById(4).curve, isNull);
      // No curve means the engine never asks for a size above one.
      for (final level in kCuratedLevels) {
        expect(level.curve, isNull, reason: 'shift ${level.id}');
      }
    });
  });

  group('lanes', () {
    /// Drives a real endless run to [target] pressure and returns the lanes
    /// seen on the belt at their widest.
    Set<double> lanesAt(int target) {
      final engine = RunEngine(level: kEndlessShift, seed: 11)..start();
      final seen = <double>{};
      var steps = 0;
      while (engine.score.sorted < target && steps++ < 200000) {
        if (engine.isShopping) {
          engine.skipShop();
        }
        if (engine.score.sorted >= EndlessCurve.burstTwoAt) {
          for (final p in engine.active) {
            seen.add(p.lane);
          }
        }
        if (engine.frontMost != null) {
          sortCorrectly(engine);
        }
        engine.update(1 / 60);
      }
      return seen;
    }

    test('a solo package still travels dead centre', () {
      final engine = RunEngine(level: testLevel(), seed: 1)..start();
      expect(engine.frontMost!.lane, 0);
    });

    test('a cluster spreads its members off centre', () {
      final lanes = lanesAt(EndlessCurve.burstTwoAt + 30);
      expect(
        lanes.any((l) => l != 0),
        isTrue,
        reason: 'clusters never spread, so they would render on top of '
            'each other',
      );
    });

    test('every lane stays inside the drawn belt lane', () {
      final lanes = lanesAt(EndlessCurve.burstThreeAt + 20);
      for (final lane in lanes) {
        expect(lane.abs(), lessThanOrEqualTo(1.0));
      }
    });
  });

  group('the contract clusters must not break', () {
    RunEngine deepRun(int seed) {
      final engine = RunEngine(level: kEndlessShift, seed: seed)..start();
      var steps = 0;
      while (engine.score.sorted < EndlessCurve.burstThreeAt + 40 &&
          engine.phase != RunPhase.finished &&
          steps++ < 300000) {
        if (engine.isShopping) {
          engine.skipShop();
        }
        if (engine.frontMost != null) {
          sortCorrectly(engine);
        }
        engine.update(1 / 60);
      }
      return engine;
    }

    test('packages still never overtake each other', () {
      final engine = RunEngine(level: kEndlessShift, seed: 5)..start();
      var steps = 0;
      while (engine.score.sorted < EndlessCurve.burstThreeAt + 20 &&
          engine.phase != RunPhase.finished &&
          steps++ < 300000) {
        if (engine.isShopping) {
          engine.skipShop();
        }
        // Order on the belt must always be spawn order.
        var previous = double.infinity;
        for (final p in engine.active) {
          expect(
            p.progress,
            lessThanOrEqualTo(previous + 1e-9),
            reason: 'a package overtook the one in front of it',
          );
          previous = p.progress;
        }
        if (engine.frontMost != null) {
          sortCorrectly(engine);
        }
        engine.update(1 / 60);
      }
      expect(engine.score.sorted, greaterThan(EndlessCurve.burstTwoAt));
    });

    test('the belt never exceeds the active ceiling', () {
      final engine = RunEngine(level: kEndlessShift, seed: 9)..start();
      var steps = 0;
      while (engine.score.sorted < EndlessCurve.burstThreeAt + 20 &&
          engine.phase != RunPhase.finished &&
          steps++ < 300000) {
        if (engine.isShopping) {
          engine.skipShop();
        }
        expect(
          engine.active.length,
          lessThanOrEqualTo(engine.tuning.maxActive),
        );
        if (engine.frontMost != null) {
          sortCorrectly(engine);
        }
        engine.update(1 / 60);
      }
    });

    test('the same seed and the same taps still replay exactly', () {
      // Clusters derive their lanes from a member index, never from a roll,
      // so the replay contract is untouched.
      final a = deepRun(21);
      final b = deepRun(21);
      expect(a.score.score, b.score.score);
      expect(a.score.sorted, b.score.sorted);
      expect(a.score.mistakes, b.score.mistakes);
      expect(
        a.active.map((p) => p.lane).toList(),
        b.active.map((p) => p.lane).toList(),
      );
    });
  });

  test('average spacing survives clustering', () {
    // The whole justification: a cluster is paid for by the gap after it.
    // Measured as sorts achieved per second of belt time, before clustering
    // starts and well after it does.
    double throughput({required int from, required int to}) {
      final engine = RunEngine(level: kEndlessShift, seed: 3)..start();
      var steps = 0;
      var elapsed = 0.0;
      var started = false;
      var startSorted = 0;
      while (engine.score.sorted < to &&
          engine.phase != RunPhase.finished &&
          steps++ < 400000) {
        if (engine.isShopping) {
          engine.skipShop();
        }
        if (!started && engine.score.sorted >= from) {
          started = true;
          startSorted = engine.score.sorted;
          elapsed = 0;
        }
        if (engine.frontMost != null) {
          sortCorrectly(engine);
        }
        engine.update(1 / 60);
        if (started) {
          elapsed += 1 / 60;
        }
      }
      return (engine.score.sorted - startSorted) / elapsed;
    }

    final before = throughput(from: 140, to: 165);
    final during = throughput(from: 310, to: 335);
    // Within a quarter of each other: lumpy, not faster.
    expect(during, closeTo(before, before * 0.25));
  });
}
