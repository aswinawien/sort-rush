import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/pass_condition.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/core/score_state.dart';

import 'test_level.dart';

/// Clutch saves: a correct sort pulled out of the last moments before a
/// package would have dropped.
///
/// Level 7 exists to teach recovery from a near miss, so the thing being
/// measured has to actually be lateness — not volume, and not luck.
void main() {
  /// Advances until the front package has [seconds] left before the line.
  void advanceToWithin(RunEngine engine, double seconds) {
    while (engine.timeToLine! > seconds) {
      engine.update(1 / 240);
    }
  }

  RunEngine engineWith({double readWindow = 4.0}) => RunEngine(
        level: testLevel(readWindow: readWindow, spawnInterval: 1000),
        seed: 5,
      )..start();

  group('what counts as a save', () {
    test('a sort with time to spare is ordinary', () {
      final engine = engineWith();
      advanceToWithin(engine, 2.0);

      sortCorrectly(engine);

      expect(engine.score.sorted, 1);
      expect(engine.score.clutchSaves, 0);
      expect(engine.score.score, RunScore.baseValue);
    });

    test('a sort inside the window is a save and pays a little more', () {
      final engine = engineWith();
      advanceToWithin(engine, RunEngine.clutchWindow - 0.05);

      sortCorrectly(engine);

      expect(engine.score.clutchSaves, 1);
      expect(engine.score.score, RunScore.baseValue + RunScore.clutchBonus);
    });

    test('the window is measured in seconds, not in progress', () {
      // A short read window means the same progress is a very different
      // amount of time. Getting this wrong would make saves trivial on fast
      // levels and impossible on slow ones — the exact inversion of what the
      // fairness floors are for.
      final slow = engineWith(readWindow: 8.0);
      final fast = engineWith(readWindow: 2.0);

      advanceToWithin(slow, 0.4);
      advanceToWithin(fast, 0.4);
      sortCorrectly(slow);
      sortCorrectly(fast);

      expect(slow.score.clutchSaves, 1);
      expect(fast.score.clutchSaves, 1);
    });

    test('a misroute at the line is not a save', () {
      final engine = engineWith();
      advanceToWithin(engine, 0.2);

      sortWrongly(engine);

      expect(engine.score.clutchSaves, 0);
      expect(engine.score.misrouted, 1);
    });

    test('a dropped package is not a save', () {
      final engine = engineWith();
      while (engine.score.dropped == 0) {
        engine.update(1 / 60);
      }

      expect(engine.score.clutchSaves, 0);
    });

    test('the sort event says whether it was a save', () {
      final engine = engineWith();
      advanceToWithin(engine, 0.2);
      engine.drainEvents();

      sortCorrectly(engine);

      final sorted =
          engine.drainEvents().whereType<PackageSortedEvent>().single;
      expect(sorted.clutch, isTrue);
    });
  });

  group('ClutchTarget', () {
    test('is met by saves, not by ordinary sorts', () {
      final score = RunScore();
      for (var i = 0; i < 20; i++) {
        score.registerCorrect();
      }
      expect(const ClutchTarget(2).isMetBy(score), isFalse);

      score.registerCorrect(clutch: true);
      score.registerCorrect(clutch: true);
      expect(const ClutchTarget(2).isMetBy(score), isTrue);
    });
  });

  group('EveryOf', () {
    const condition = EveryOf([SortTarget(20), ClutchTarget(2)]);

    test('needs both, not the harder of the two', () {
      // The reason level 7 cannot be a plain sort target: a player can be
      // well past one half and nowhere near the other.
      final score = RunScore();
      for (var i = 0; i < 25; i++) {
        score.registerCorrect();
      }
      expect(condition.isMetBy(score), isFalse, reason: 'no saves yet');

      score.registerCorrect(clutch: true);
      expect(condition.isMetBy(score), isFalse, reason: 'one save is not two');

      score.registerCorrect(clutch: true);
      expect(condition.isMetBy(score), isTrue);
    });

    test('reports the larger part as its minimum sorts', () {
      expect(condition.minimumSorts, 20);
    });

    test('briefing copy names both halves', () {
      expect(condition.briefingCopy, 'SORT 20 · SAVE 2 AT THE LINE');
    });
  });
}
