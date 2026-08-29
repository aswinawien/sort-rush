import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/board.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/package_spec.dart';
import 'package:sort_rush/core/routing.dart';
import 'package:sort_rush/core/run_engine.dart';

import 'test_level.dart';

void main() {
  group('PRIORITY on compound chutes', () {
    final routing = CompoundRouting(const [
      PackageSpec(shape: PackageShape.circle, colorIndex: 0),
      PackageSpec(shape: PackageShape.circle, colorIndex: 1),
      PackageSpec(shape: PackageShape.triangle, colorIndex: 0),
    ]);

    test('the reflex pair is the wrong chute', () {
      const spec = PackageSpec(shape: PackageShape.circle, colorIndex: 0);
      const stamped = PackageSpec(
        shape: PackageShape.circle,
        colorIndex: 0,
        stamp: PackageStamp.priority,
      );
      expect(routing.binFor(spec), 0);
      expect(routing.binFor(stamped), isNot(0));
      expect(routing.binFor(stamped), 2);
    });

    test('every spawnable pair on level 10 has a different priority chute', () {
      final level = levelById(10);
      for (final spec in level.spawnPool!) {
        final stamped = PackageSpec(
          shape: spec.shape,
          colorIndex: spec.colorIndex,
          stamp: PackageStamp.priority,
        );
        expect(
          level.routing.binFor(stamped),
          isNot(level.routing.binFor(spec)),
          reason: '${spec.shape.name} hue ${spec.colorIndex} is inert',
        );
        expect(level.routing.binFor(stamped), greaterThanOrEqualTo(0));
      }
    });

    test('a two-chute board still flips', () {
      final board = ChuteBoard(EndlessBoard.ladder.sublist(0, 2));
      const spec = PackageSpec(shape: PackageShape.circle, colorIndex: 0);
      const stamped = PackageSpec(
        shape: PackageShape.circle,
        colorIndex: 0,
        stamp: PackageStamp.priority,
      );
      expect(board.binFor(stamped), isNot(board.binFor(spec)));
    });
  });

  group('spawn', () {
    test('never stacks PRIORITY and DAMAGED on one package', () {
      final engine = RunEngine(level: levelById(10), seed: 9)..start();
      var steps = 0;
      while (engine.score.sorted < 40 &&
          engine.phase == RunPhase.running &&
          steps++ < 8000) {
        for (final package in engine.active) {
          expect(
            package.spec.stamp != PackageStamp.priority || !package.isDamaged,
            isTrue,
          );
        }
        if (engine.frontMost != null) {
          sortCorrectly(engine);
        }
        engine.update(1 / 60);
      }
    });

    test('endless withholds PRIORITY until the pressure gate', () {
      final engine = RunEngine(level: kEndlessShift, seed: 3)..start();
      var sawEarly = false;
      var eventRaisedPriority = false;
      var steps = 0;
      while (engine.score.sorted < EndlessBoard.priorityAt &&
          engine.phase != RunPhase.finished &&
          steps++ < 20000) {
        skipShopIfOpen(engine);
        if ((engine.liveEvent?.delta.priorityRate ?? 0) > 0) {
          eventRaisedPriority = true;
        }
        if (engine.active.any((p) => p.spec.stamp == PackageStamp.priority)) {
          sawEarly = true;
        }
        if (engine.frontMost != null) {
          sortCorrectly(engine);
        }
        engine.update(1 / 60);
      }
      if (!eventRaisedPriority) {
        expect(sawEarly, isFalse);
      }
    });
  });
}
