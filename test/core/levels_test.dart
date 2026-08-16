import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/package_spec.dart';
import 'package:sort_rush/core/pass_condition.dart';

void main() {
  group('the curated level table', () {
    test('ships a contiguous ladder starting at 1', () {
      // A gap would mean a level was added while an earlier one was still
      // blocked, which strands the player mid-ladder.
      expect(
        kCuratedLevels.map((level) => level.id),
        List.generate(kCuratedLevels.length, (i) => i + 1),
      );
    });

    test('matches the approved parameters in docs/level-spec.md', () {
      final one = levelById(1);
      expect(one.readWindow, 4.0);
      expect(one.spawnInterval, 2.6);
      expect(one.maxActive, 1);
      expect(one.mistakeLimit, isNull);
      expect(one.passCondition, const SortTarget(10));
      expect(one.binCount, 1);

      final two = levelById(2);
      expect(two.readWindow, 4.0);
      expect(two.spawnInterval, 2.4);
      expect(two.maxActive, 1);
      expect(two.mistakeLimit, 3);
      expect(two.passCondition, const SortTarget(12));
      expect(two.binCount, 3);

      final three = levelById(3);
      expect(three.readWindow, 3.6);
      expect(three.spawnInterval, 2.2);
      expect(three.maxActive, 2);
      expect(three.mistakeLimit, 3);
      expect(three.passCondition, const SortTarget(14));
      expect(three.binCount, 2);

      final four = levelById(4);
      expect(four.readWindow, 3.2);
      expect(four.spawnInterval, 1.9);
      expect(four.maxActive, 2);
      expect(four.mistakeLimit, 3);
      expect(four.passCondition, const SortTarget(16));
      expect(four.binCount, 3);

      final five = levelById(5);
      expect(five.readWindow, 3.0);
      expect(five.spawnInterval, 1.8);
      expect(five.maxActive, 2);
      expect(five.mistakeLimit, 3);
      // x4, not the x3 the spec first named — see the decision log.
      expect(five.passCondition, const ComboTarget(4));
      expect(five.binCount, 3);
      expect(five.chaosRate, 0.30);
      expect(five.telegraphSeconds, 1.2);

      final six = levelById(6);
      expect(six.readWindow, 2.8);
      expect(six.spawnInterval, 1.4);
      expect(six.maxActive, 3);
      expect(six.mistakeLimit, 3);
      expect(six.passCondition, const SortTarget(22));
      expect(six.binCount, 3);
      expect(six.chaosRate, 0.20);
      expect(six.telegraphSeconds, 1.0);
    });

    test('level 1 cannot be failed', () {
      // A player who fails inside the first thirty seconds of their first
      // launch does not come back.
      expect(levelById(1).isUnfailable, isTrue);
      expect(levelById(2).isUnfailable, isFalse);
      expect(levelById(3).isUnfailable, isFalse);
    });

    test('chaos never outruns its warning', () {
      // The telegraph is the mechanic. A level that corrupts packages faster
      // than it can warn about them is a coin flip, and the floor exists for
      // the same reason the read-window floor does.
      for (final level in kCuratedLevels) {
        if (level.chaosRate == 0) {
          expect(level.telegraphSeconds, 0,
              reason: 'level \${level.id} warns about chaos it never spawns');
          continue;
        }
        expect(level.telegraphSeconds, greaterThanOrEqualTo(0.5),
            reason: 'telegraph floor, level \${level.id}');
        expect(level.telegraphSeconds, lessThan(level.readWindow),
            reason: 'level \${level.id} warns for longer than the read window');
      }
    });

    test('the warning only ever gets shorter', () {
      // Escalation is the shrinking telegraph, not the rising rate. The rate
      // is a teaching dial — it peaks at level 5, which introduces DAMAGED,
      // then dilutes as other pressures arrive. The warning is the axis that
      // actually measures how hard the mechanic is, and it only tightens.
      var previous = double.infinity;
      for (final level in kCuratedLevels) {
        if (level.chaosRate == 0) {
          continue;
        }
        expect(level.telegraphSeconds, lessThanOrEqualTo(previous),
            reason: 'telegraph lengthened at level \${level.id}');
        previous = level.telegraphSeconds;
      }
    });

    test('the level that teaches chaos has the most of it', () {
      // A mechanic met once every ten packages reads as an oddity rather than
      // a rule. Whichever level introduces DAMAGED must be dense enough to
      // learn from.
      final chaotic = kCuratedLevels.where((l) => l.chaosRate > 0).toList();
      final teacher = chaotic.first;
      for (final level in chaotic.skip(1)) {
        expect(teacher.chaosRate, greaterThanOrEqualTo(level.chaosRate),
            reason: 'level \${level.id} is denser than the teaching level');
      }
      expect(teacher.chaosRate, greaterThanOrEqualTo(0.25),
          reason: 'too sparse to teach');
    });

    test('every level respects the fairness floors', () {
      for (final level in kCuratedLevels) {
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
      for (final level in kCuratedLevels) {
        final estimate =
            level.passCondition.minimumSorts * level.spawnInterval +
                level.readWindow;
        expect(
          estimate,
          inInclusiveRange(30, 90),
          reason: 'estimated duration, level ${level.id}',
        );
      }
    });

    test('difficulty never eases, except where a new rule arrives', () {
      // The approved table relaxes timing at level 8 on purpose: that level
      // introduces compound reading, and "teach one pressure at a time" means
      // relieving another pressure to make room for the new one. So easing is
      // allowed exactly where the routing rule changes, and nowhere else.
      // An earlier version of this guard forbade it outright and failed
      // against the approved spec.
      for (var i = 1; i < kCuratedLevels.length; i++) {
        final previous = kCuratedLevels[i - 1];
        final current = kCuratedLevels[i];
        if (current.routing.runtimeType != previous.routing.runtimeType) {
          continue;
        }
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
      for (final level in kCuratedLevels) {
        // Compound levels spawn from an explicit pool, because most of the
        // cross product of their shapes and hues owns no chute at all.
        final spawnable = level.spawnPool ??
            [
              for (final shape in level.shapes)
                for (final hue in level.colors)
                  PackageSpec(shape: shape, colorIndex: hue),
            ];
        for (final package in spawnable) {
          {
            final shape = package.shape;
            final hue = package.colorIndex;
            final bin = level.routing.binFor(package);
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
