import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/pass_condition.dart';
import 'package:sort_rush/core/score_state.dart';

/// Pass conditions decide when a shift is cleared, so a wrong one either ends
/// a level early or makes it unwinnable. Both are P1s.
void main() {
  RunScore scoreAfter({int correct = 0, int misroutes = 0}) {
    final score = RunScore();
    for (var i = 0; i < correct; i++) {
      score.registerCorrect();
    }
    for (var i = 0; i < misroutes; i++) {
      score.registerMisroute();
    }
    return score;
  }

  group('SortTarget', () {
    test('is met on the sort that reaches the count, not before', () {
      expect(const SortTarget(10).isMetBy(scoreAfter(correct: 9)), isFalse);
      expect(const SortTarget(10).isMetBy(scoreAfter(correct: 10)), isTrue);
    });

    test('ignores mistakes — the count is of correct sorts only', () {
      final score = scoreAfter(correct: 10, misroutes: 5);
      expect(const SortTarget(10).isMetBy(score), isTrue);
    });

    test('reports its own count as the minimum sorts', () {
      expect(const SortTarget(16).minimumSorts, 16);
    });

    test('says what it wants', () {
      expect(const SortTarget(16).briefingCopy, 'SORT 16');
    });
  });

  group('ComboTarget', () {
    test('is met by the peak tier, not the streak still held', () {
      // A player who reaches x3 and then misroutes has still done the thing
      // the level asked for. Taking it back would punish them twice.
      final score = scoreAfter(correct: 10);
      expect(score.bestCombo, 3);

      score.registerMisroute();

      expect(score.comboTier, 1, reason: 'the live streak is broken');
      expect(const ComboTarget(3).isMetBy(score), isTrue);
    });

    test('minimumSorts is exactly the shortest clean streak that works', () {
      // Checked against the real scoring rules rather than asserted as a
      // magic number, so a change to sortsPerTier fails here instead of
      // silently shifting every level's estimated duration.
      const target = ComboTarget(3);
      expect(target.isMetBy(scoreAfter(correct: target.minimumSorts)), isTrue);
      expect(
        target.isMetBy(scoreAfter(correct: target.minimumSorts - 1)),
        isFalse,
      );
    });

    test('a broken streak needs the full run-up again', () {
      final score = scoreAfter(correct: 9, misroutes: 1);
      expect(const ComboTarget(3).isMetBy(score), isFalse);

      for (var i = 0; i < 10; i++) {
        score.registerCorrect();
      }
      expect(const ComboTarget(3).isMetBy(score), isTrue);
    });

    test('says what it wants', () {
      expect(const ComboTarget(3).briefingCopy, 'REACH COMBO x3');
    });
  });
}
