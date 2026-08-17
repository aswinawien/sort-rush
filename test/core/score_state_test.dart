import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/score_state.dart';

void main() {
  group('RunScore combo tiers', () {
    test('starts at tier 1', () {
      expect(RunScore().comboTier, 1);
    });

    test('advances one tier every five consecutive sorts', () {
      expect(RunScore.tierFor(0), 1);
      expect(RunScore.tierFor(4), 1);
      expect(RunScore.tierFor(5), 2);
      expect(RunScore.tierFor(9), 2);
      expect(RunScore.tierFor(10), 3);
      expect(RunScore.tierFor(15), 4);
      expect(RunScore.tierFor(20), 5);
    });

    test('caps at tier 5', () {
      expect(RunScore.tierFor(100), 5);
      expect(RunScore.tierFor(1000), 5);
    });
  });

  group('RunScore scoring', () {
    test('a correct sort at tier 1 pays the base value', () {
      final score = RunScore();
      expect(score.registerCorrect(), 10);
      expect(score.score, 10);
      expect(score.sorted, 1);
      expect(score.pay, 1);
    });

    test('the sort that completes a tier pays the higher rate', () {
      final score = RunScore();
      for (var i = 0; i < 4; i++) {
        expect(score.registerCorrect(), 10);
      }
      // The fifth consecutive sort tips into tier 2 and is paid at tier 2.
      expect(score.registerCorrect(), 20);
      expect(score.score, 60);
      expect(score.comboTier, 2);
    });

    test('a misroute breaks the combo and counts as a mistake', () {
      final score = RunScore();
      for (var i = 0; i < 6; i++) {
        score.registerCorrect();
      }
      expect(score.comboTier, 2);

      score.registerMisroute();
      expect(score.comboTier, 1);
      expect(score.consecutive, 0);
      expect(score.misrouted, 1);
      expect(score.mistakes, 1);
    });

    test('a drop breaks the combo and counts as a mistake', () {
      final score = RunScore();
      score.registerCorrect();
      score.registerDrop();
      expect(score.consecutive, 0);
      expect(score.dropped, 1);
      expect(score.mistakes, 1);
    });

    test('best combo records the peak, not the current tier', () {
      final score = RunScore();
      for (var i = 0; i < 10; i++) {
        score.registerCorrect();
      }
      expect(score.comboTier, 3);
      score.registerMisroute();
      expect(score.comboTier, 1);
      expect(score.bestCombo, 3);
    });

    test('mistakes combine misroutes and drops', () {
      final score = RunScore();
      score.registerMisroute();
      score.registerDrop();
      score.registerMisroute();
      expect(score.mistakes, 3);
    });
  });
}
