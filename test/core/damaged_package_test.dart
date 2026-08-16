import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/package_spec.dart';
import 'package:sort_rush/core/routing.dart';
import 'package:sort_rush/core/run_engine.dart';

import 'test_level.dart';

/// `DAMAGED` packages: the telegraphed shape-shift approved at Gate 3.
///
/// The mechanic is the *warning*, not the change. A silent morph punishes a
/// decision the player already committed to; these tests exist mostly to hold
/// that line, because it is the thing an optimisation would quietly remove.
void main() {
  RunEngine engineWith({
    double chaosRate = 1.0,
    double telegraphSeconds = 1.0,
    double readWindow = 4.0,
    int seed = 7,
  }) {
    final engine = RunEngine(
      level: testLevel(
        readWindow: readWindow,
        spawnInterval: 1000, // one package, so tests stay about that package
        chaosRate: chaosRate,
        telegraphSeconds: telegraphSeconds,
      ),
      seed: seed,
    );
    engine.start();
    return engine;
  }

  group('when chaos is off', () {
    test('no package is ever damaged', () {
      final engine = engineWith(chaosRate: 0, telegraphSeconds: 0);
      for (var i = 0; i < 200; i++) {
        engine.update(0.05);
        for (final package in engine.active) {
          expect(package.isDamaged, isFalse);
          expect(package.isUnstable, isFalse);
        }
      }
    });

    test('the random sequence is untouched, so existing levels are unchanged',
        () {
      // Chaos must cost nothing when off. If the rate check consumed a draw,
      // turning chaos on for one level would reseed every other level's run.
      final clean = RunEngine(
        level: testLevel(readWindow: 4, spawnInterval: 0.5),
        seed: 99,
      )..start();
      final alsoClean = RunEngine(
        level: testLevel(
          readWindow: 4,
          spawnInterval: 0.5,
          chaosRate: 0,
          telegraphSeconds: 0,
        ),
        seed: 99,
      )..start();

      for (var i = 0; i < 40; i++) {
        clean.update(0.1);
        alsoClean.update(0.1);
      }

      expect(
        clean.active.map((p) => p.spec).toList(),
        alsoClean.active.map((p) => p.spec).toList(),
      );
    });
  });

  group('a damaged package', () {
    test('is stamped and carries a shape it will become', () {
      final engine = engineWith();
      final package = engine.frontMost!;

      expect(package.isDamaged, isTrue);
      expect(package.spec.stamp, PackageStamp.damaged);
      expect(package.morphTo, isNotNull);
    });

    test('always changes where the package belongs', () {
      // The property that matters, and the one that holds on every level
      // whichever attribute it routes on. Asserting "the shape changed" would
      // pass on a colour-routed level while the mechanic did nothing at all.
      for (var seed = 1; seed < 40; seed++) {
        final engine = engineWith(seed: seed);
        final package = engine.frontMost!;
        final routing = engine.level.routing;
        expect(
          routing.binFor(package.morphTo!),
          isNot(routing.binFor(package.spec)),
          reason: 'seed \$seed: the morph did not move the destination',
        );
      }
    });

    test('corrupts the attribute a colour-routed level actually reads', () {
      // Levels 3-7 route on hue. A shape-shift there would be pure theatre.
      final engine = RunEngine(
        level: testLevel(
          readWindow: 4,
          spawnInterval: 1000,
          colors: const [0, 1, 2],
          routing: ColorRouting(const [0, 1, 2]),
          chaosRate: 1.0,
          telegraphSeconds: 1.0,
        ),
        seed: 3,
      )..start();
      final package = engine.frontMost!;

      expect(package.morphTo!.colorIndex, isNot(package.spec.colorIndex));
      expect(
        engine.level.routing.binFor(package.morphTo!),
        isNot(engine.level.routing.binFor(package.spec)),
      );
    });

    test('warns before it changes, for the telegraph duration', () {
      final engine = engineWith(telegraphSeconds: 1.0, readWindow: 4.0);
      final package = engine.frontMost!;

      var sawWarning = false;
      double? warnedAt;
      while (!package.hasMorphed && package.progress < 1) {
        engine.update(1 / 60);
        if (package.isUnstable && !sawWarning) {
          sawWarning = true;
          warnedAt = package.progress;
        }
      }

      expect(sawWarning, isTrue, reason: 'the change was never telegraphed');
      expect(package.hasMorphed, isTrue);

      // The warning must last about as long as the level promises.
      final warnedFor = (package.morphAt! - warnedAt!) * 4.0;
      expect(warnedFor, closeTo(1.0, 0.05));
    });

    test('leaves time to act on what it became', () {
      // Escalation shortens the warning; it must never eat the whole window.
      for (var seed = 1; seed < 40; seed++) {
        final package = engineWith(seed: seed).frontMost!;
        expect(package.morphAt, lessThanOrEqualTo(0.75));
      }
    });

    test('changes shape exactly once', () {
      final engine = engineWith();
      final package = engine.frontMost!;
      final before = package.spec.shape;

      var morphEvents = 0;
      while (package.progress < 0.99) {
        engine.update(1 / 60);
        morphEvents +=
            engine.drainEvents().whereType<PackageMorphedEvent>().length;
      }

      expect(morphEvents, 1);
      expect(package.spec.shape, isNot(before));
      expect(package.spec, package.morphTo);
      expect(package.isUnstable, isFalse, reason: 'settled after changing');
    });
  });

  group('routing follows the change', () {
    test('a morphed package belongs in the bin for its new shape', () {
      final engine = engineWith();
      final package = engine.frontMost!;
      final originalBin = engine.level.routing.binFor(package.spec);

      while (!package.hasMorphed) {
        engine.update(1 / 60);
      }
      engine.drainEvents();

      final newBin = engine.level.routing.binFor(package.spec);
      expect(newBin, isNot(originalBin));

      // The reflex answer is now wrong, and the game must treat it that way.
      expect(engine.tapBin(originalBin), TapResult.misroute);
    });

    test('sorting into the new bin is correct', () {
      final engine = engineWith();
      final package = engine.frontMost!;

      while (!package.hasMorphed) {
        engine.update(1 / 60);
      }
      engine.drainEvents();

      expect(
        engine.tapBin(engine.level.routing.binFor(package.spec)),
        TapResult.correct,
      );
    });
  });

  test('the same seed reproduces the same corruption', () {
    List<String> run(int seed) {
      final engine = engineWith(seed: seed);
      final package = engine.frontMost!;
      while (!package.hasMorphed && package.progress < 1) {
        engine.update(1 / 60);
      }
      return [package.morphAt!.toStringAsFixed(6), package.spec.shape.name];
    }

    expect(run(1234), run(1234));
    expect(run(1234), isNot(run(4321)));
  });
}
