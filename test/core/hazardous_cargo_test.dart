import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/package_spec.dart';
import 'package:sort_rush/core/routing.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/core/shop.dart';

import 'test_level.dart';

void main() {
  final hazard = EndlessShop.byId('hazardous-cargo');

  group('hazardousAccepts', () {
    test('on three chutes the unique destination is forbidden', () {
      expect(hazardousAccepts(1, 1, 3), isFalse);
      expect(hazardousAccepts(1, 0, 3), isTrue);
      expect(hazardousAccepts(1, 2, 3), isTrue);
    });

    test('on four chutes the same function holds', () {
      expect(hazardousAccepts(0, 0, 4), isFalse);
      expect(hazardousAccepts(0, 1, 4), isTrue);
      expect(hazardousAccepts(0, 3, 4), isTrue);
    });

    test('on two chutes the unique destination stays the only tap', () {
      expect(hazardousAccepts(0, 0, 2), isTrue);
      expect(hazardousAccepts(0, 1, 2), isFalse);
    });
  });

  group('hazardous cargo', () {
    test('the catalog slip is a visible tradeoff', () {
      expect(hazard.mechanic, CardMechanic.hazardous);
      expect(hazard.delta.scorePercent, 50);
      expect(hazard.body.contains(' · '), isTrue);
    });

    test('the matched chute is a misroute; any other is correct', () {
      final engine = RunEngine(
        level: testLevel(spawnInterval: 0.65, maxActive: 1),
        seed: 1,
      )..start();
      engine.debugPin(hazard);
      expect(engine.hazardousCargo, isTrue);
      if (engine.frontMost == null) {
        spawnNext(engine);
      }
      final spec = engine.frontMost!.spec;
      final matched = engine.binFor(spec);
      expect(engine.isCorrectBin(spec, matched), isFalse);
      expect(engine.liveBinCount, 3);
      var valids = 0;
      for (var i = 0; i < engine.liveBinCount; i++) {
        if (engine.isCorrectBin(spec, i)) {
          valids++;
        }
      }
      expect(valids, 2);
      expect(sortCorrectly(engine), TapResult.correct);
    });

    test('tapping the matched chute is a misroute', () {
      final engine = RunEngine(
        level: testLevel(spawnInterval: 0.65, maxActive: 1, mistakeLimit: 5),
        seed: 1,
      )..start();
      engine.debugPin(hazard);
      if (engine.frontMost == null) {
        spawnNext(engine);
      }
      expect(sortWrongly(engine), TapResult.misroute);
      expect(engine.score.misrouted, 1);
    });

    test('two chutes cannot express the rule, so the unique tap stays', () {
      final engine = RunEngine(
        level: testLevel(
          spawnInterval: 0.65,
          maxActive: 1,
          shapes: const [PackageShape.circle, PackageShape.triangle],
          routing: ShapeRouting(const [
            PackageShape.circle,
            PackageShape.triangle,
          ]),
        ),
        seed: 1,
      )..start();
      engine.debugPin(hazard);
      if (engine.frontMost == null) {
        spawnNext(engine);
      }
      final spec = engine.frontMost!.spec;
      expect(engine.liveBinCount, 2);
      expect(engine.isCorrectBin(spec, engine.binFor(spec)), isTrue);
      expect(sortCorrectly(engine), TapResult.correct);
    });
  });
}
