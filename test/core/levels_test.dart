import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/package_spec.dart';

void main() {
  group('the prototype level table', () {
    test('ships levels 1 to 3', () {
      expect(kPrototypeLevels.map((level) => level.id), [1, 2, 3]);
    });

    test('matches the approved parameters in docs/level-spec.md', () {
      final one = levelById(1);
      expect(one.readWindow, 4.0);
      expect(one.spawnInterval, 2.6);
      expect(one.maxActive, 1);
      expect(one.mistakeLimit, isNull);
      expect(one.passTarget, 10);
      expect(one.binCount, 1);

      final two = levelById(2);
      expect(two.readWindow, 4.0);
      expect(two.spawnInterval, 2.4);
      expect(two.maxActive, 1);
      expect(two.mistakeLimit, 3);
      expect(two.passTarget, 12);
      expect(two.binCount, 3);

      final three = levelById(3);
      expect(three.readWindow, 3.6);
      expect(three.spawnInterval, 2.2);
      expect(three.maxActive, 2);
      expect(three.mistakeLimit, 3);
      expect(three.passTarget, 14);
      expect(three.binCount, 2);
    });

    test('level 1 cannot be failed', () {
      // A player who fails inside the first thirty seconds of their first
      // launch does not come back.
      expect(levelById(1).isUnfailable, isTrue);
      expect(levelById(2).isUnfailable, isFalse);
      expect(levelById(3).isUnfailable, isFalse);
    });

    test('every level respects the fairness floors', () {
      for (final level in kPrototypeLevels) {
        expect(
          level.readWindow,
          greaterThanOrEqualTo(1.20),
          reason: 'read window floor, level ${level.id}',
        );
        expect(
          level.spawnInterval,
          greaterThanOrEqualTo(0.65),
          reason: 'spawn interval floor, level ${level.id}',
        );
      }
    });

    test('every level lands in the 30 to 90 second band', () {
      for (final level in kPrototypeLevels) {
        final estimate =
            level.passTarget * level.spawnInterval + level.readWindow;
        expect(
          estimate,
          inInclusiveRange(30, 90),
          reason: 'estimated duration, level ${level.id}',
        );
      }
    });

    test('difficulty never eases as levels advance', () {
      for (var i = 1; i < kPrototypeLevels.length; i++) {
        final previous = kPrototypeLevels[i - 1];
        final current = kPrototypeLevels[i];
        expect(
          current.spawnInterval,
          lessThanOrEqualTo(previous.spawnInterval),
          reason: 'spawn interval, level ${current.id}',
        );
        expect(
          current.readWindow,
          lessThanOrEqualTo(previous.readWindow),
          reason: 'read window, level ${current.id}',
        );
      }
    });

    test('every package a level can spawn has a destination', () {
      // A level that can spawn a package with no valid bin is unwinnable
      // through no fault of the player, so this is a configuration error the
      // table must never contain.
      for (final level in kPrototypeLevels) {
        for (final shape in level.shapes) {
          for (final hue in level.colors) {
            final bin = level.routing.binFor(
              PackageSpec(shape: shape, colorIndex: hue),
            );
            expect(
              bin,
              greaterThanOrEqualTo(0),
              reason: 'level ${level.id}: ${shape.name} hue $hue has no bin',
            );
            expect(
              bin,
              lessThan(level.binCount),
              reason: 'level ${level.id}: ${shape.name} hue $hue is off-table',
            );
          }
        }
      }
    });
  });
}
