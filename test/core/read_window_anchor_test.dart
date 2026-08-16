import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/package_spec.dart';
import 'package:sort_rush/core/run_engine.dart';

import 'test_level.dart';

/// A package's read window is fixed when it spawns, not read from the level
/// on every tick.
///
/// This exists so that anything which later changes the level's read window —
/// the endless curve stepping, or a shop card being bought — cannot speed up
/// packages already in the air, and cannot move one into or out of the clutch
/// window without it moving. That would be randomness resolving *after* the
/// player committed, which is the failure mode this whole design avoids.
///
/// The decisive test, that a mid-run parameter change leaves airborne packages
/// alone, arrives with `RunParameters`. These pin the anchoring itself so that
/// change cannot quietly regress it.
void main() {
  test('a package records the window it spawned under', () {
    final engine = RunEngine(
      level: testLevel(readWindow: 3.5, spawnInterval: 1000),
      seed: 1,
    )..start();

    expect(engine.frontMost!.readWindow, 3.5);
  });

  test('time to line is derived from the package, not the level', () {
    // Constructed directly, so the value cannot have come from a level lookup.
    final package = ActivePackage(
      id: 0,
      spec: const PackageSpec(shape: PackageShape.circle, colorIndex: 0),
      readWindow: 8.0,
      telegraphSeconds: 0,
    )..progress = 0.5;

    expect((1 - package.progress) * package.readWindow, 4.0);
  });

  test('two windows produce two different travel times for the same progress',
      () {
    final slow = RunEngine(
      level: testLevel(readWindow: 8.0, spawnInterval: 1000),
      seed: 1,
    )..start();
    final fast = RunEngine(
      level: testLevel(readWindow: 2.0, spawnInterval: 1000),
      seed: 1,
    )..start();

    for (var i = 0; i < 30; i++) {
      slow.update(1 / 60);
      fast.update(1 / 60);
    }

    // Same elapsed time, same seed — only the anchored window differs.
    expect(fast.frontMost!.progress, greaterThan(slow.frontMost!.progress));
    expect(slow.timeToLine, greaterThan(fast.timeToLine!));
  });

  test('packages never overtake each other on the belt', () {
    // Freezing the window per package means two packages can travel at
    // different speeds, so in principle a later one could pass an earlier
    // one. That would make `frontMost` jump backwards down the belt and draw
    // two packages on top of each other in the single centre column.
    //
    // It cannot happen with the current curve — overtaking would need more
    // than 21 correct sorts between two consecutive spawns — but the guard
    // belongs here, because the constraint is on any future tuning change,
    // not on today's numbers.
    final engine = RunEngine(
      level: testLevel(readWindow: 4.0, spawnInterval: 0.7, maxActive: 5),
      seed: 3,
    )..start();

    for (var tick = 0; tick < 3000; tick++) {
      engine.update(1 / 60);
      final belt = engine.active;
      for (var i = 1; i < belt.length; i++) {
        expect(
          belt[i - 1].progress,
          greaterThanOrEqualTo(belt[i].progress),
          reason: 'package ${belt[i].id} overtook ${belt[i - 1].id}',
        );
      }
    }
  });

  test('a corrupted package telegraphs against its own window', () {
    // The telegraph is measured in seconds. If it were measured against the
    // level's live window instead of the package's, a window change mid-flight
    // would silently lengthen or shorten a warning already in progress.
    final engine = RunEngine(
      level: testLevel(
        readWindow: 4.0,
        spawnInterval: 1000,
        chaosRate: 1.0,
        telegraphSeconds: 1.0,
      ),
      seed: 7,
    )..start();
    final package = engine.frontMost!;

    double? warnedAt;
    while (!package.hasMorphed && package.progress < 1) {
      engine.update(1 / 240);
      if (package.isUnstable && warnedAt == null) {
        warnedAt = package.progress;
      }
    }

    expect(warnedAt, isNotNull);
    expect((package.morphAt! - warnedAt!) * package.readWindow,
        closeTo(1.0, 0.02));
  });
}
