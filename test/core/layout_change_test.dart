import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/board.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/package_spec.dart';
import 'package:sort_rush/core/run_engine.dart';

import 'test_level.dart';

void main() {
  group('ChuteBoard', () {
    test('matches on shape and hue, not stamp', () {
      final board = ChuteBoard(EndlessBoard.ladder.sublist(0, 2));
      expect(
        board.binFor(
          const PackageSpec(shape: PackageShape.circle, colorIndex: 1),
        ),
        1,
      );
      expect(
        board.binFor(
          const PackageSpec(
            shape: PackageShape.circle,
            colorIndex: 1,
            stamp: PackageStamp.damaged,
          ),
        ),
        1,
      );
      expect(
        board.binFor(
          const PackageSpec(shape: PackageShape.triangle, colorIndex: 0),
        ),
        -1,
      );
    });

    test('every ladder pair is distinguishable', () {
      final board = ChuteBoard(EndlessBoard.ladder);
      expect(board.length, 4);
      for (var i = 0; i < board.bins.length; i++) {
        for (var j = i + 1; j < board.bins.length; j++) {
          expect(board.bins[i].shape != board.bins[j].shape ||
              board.bins[i].pattern != board.bins[j].pattern, isTrue);
        }
      }
    });
  });

  group('endless layout', () {
    RunEngine running() =>
        RunEngine(level: kEndlessShift, seed: 7)..start();

    test('opens on two chutes', () {
      final engine = running();
      expect(engine.liveBinCount, 2);
      expect(engine.visibleBins, hasLength(2));
    });

    test('grows with a telegraph at least as long as the read window', () {
      final engine = running();
      var steps = 0;
      while (engine.telegraph == null &&
          engine.phase == RunPhase.running &&
          steps++ < 4000) {
        if (engine.frontMost != null) {
          sortCorrectly(engine);
        } else {
          engine.update(1 / 60);
        }
      }

      final warning = engine.telegraph!;
      expect(warning.kind, LayoutChangeKind.grow);
      expect(warning.duration, greaterThanOrEqualTo(engine.tuning.readWindow));
      expect(engine.liveBinCount, 2);
      expect(engine.visibleBins, hasLength(3));

      engine.update(warning.remaining + 0.01);
      expect(engine.liveBinCount, 3);
      expect(engine.telegraph, isNull);
    });

    test('the belt does not spawn during a layout telegraph', () {
      final engine = running();
      var steps = 0;
      while (engine.telegraph == null &&
          engine.phase == RunPhase.running &&
          steps++ < 4000) {
        if (engine.frontMost != null) {
          sortCorrectly(engine);
        } else {
          engine.update(1 / 60);
        }
      }
      final ids = engine.active.map((p) => p.id).toSet();
      engine.update(0.25);
      expect(
        engine.active.every((p) => ids.contains(p.id)),
        isTrue,
        reason: 'a package that appears after the warning would still be in '
            'flight when the chutes moved',
      );
    });

    test('a tap on a ghost chute during a grow telegraph does nothing', () {
      final engine = running();
      var steps = 0;
      while (engine.telegraph == null && steps++ < 4000) {
        if (engine.frontMost != null) {
          sortCorrectly(engine);
        } else {
          engine.update(1 / 60);
        }
      }
      expect(engine.telegraph?.kind, LayoutChangeKind.grow);
      expect(engine.tapBin(2), TapResult.ignored);
    });

    test('lanes swap after the interval, telegraphed', () {
      final engine = running();
      var steps = 0;
      while ((engine.telegraph == null ||
              engine.telegraph!.kind != LayoutChangeKind.swap) &&
          engine.phase != RunPhase.finished &&
          steps++ < 12000) {
        skipShopIfOpen(engine);
        if (engine.frontMost != null) {
          sortCorrectly(engine);
        }
        engine.update(1 / 60);
      }

      skipShopIfOpen(engine);
      expect(engine.phase, RunPhase.running);
      final warning = engine.telegraph!;
      expect(warning.kind, LayoutChangeKind.swap);
      expect(warning.duration, greaterThanOrEqualTo(engine.tuning.readWindow));

      final before = <PackageSpec, int>{
        for (final spec in EndlessBoard.ladder)
          if (engine.binFor(spec) >= 0) spec: engine.binFor(spec),
      };
      engine.update(warning.remaining + 0.01);
      expect(engine.telegraph, isNull);
      final after = <PackageSpec, int>{
        for (final spec in EndlessBoard.ladder)
          if (engine.binFor(spec) >= 0) spec: engine.binFor(spec),
      };
      expect(after.length, before.length);
      expect(after, isNot(before));
    });

    test('the same seed produces the same board timeline', () {
      List<int> counts(int seed) {
        final engine = RunEngine(level: kEndlessShift, seed: seed)..start();
        final seen = <int>[];
        var steps = 0;
        while (engine.score.sorted < 50 &&
            engine.phase == RunPhase.running &&
            steps++ < 8000) {
          skipShopIfOpen(engine);
          if (engine.frontMost != null) {
            sortCorrectly(engine);
          }
          engine.update(1 / 60);
          seen.add(engine.liveBinCount);
        }
        return seen;
      }

      expect(counts(11), counts(11));
    });
  });
}
