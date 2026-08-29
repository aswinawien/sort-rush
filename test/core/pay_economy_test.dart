import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/score_state.dart';

/// Pay is earned in cents, and the rate is the combo tier.
///
/// Before this, every correct sort paid the same flat one pay regardless of
/// how the run was going. That made money a formality: the first board opens
/// at P=22, so the player arrived holding twenty-two pay against a catalog
/// whose dearest slip costs six. They could afford almost the whole board,
/// and the only real limit was that they may pin one.
///
/// Income now tracks streaks. A broken combo drops it back to a trickle.
void main() {
  group('the rate is the tier', () {
    test('cents rise strictly up to x5, then hold', () {
      for (var tier = 2; tier <= RunScore.curatedTierCap; tier++) {
        expect(
          RunScore.centsFor(tier),
          greaterThan(RunScore.centsFor(tier - 1)),
          reason: 'x$tier must out-earn x${tier - 1} or streaks mean nothing',
        );
      }
      // Flat above x5 on purpose: see `RunScore.centsPerTier`. The last board
      // closes long before a run ends, so income that kept climbing would
      // simply pile up unspent.
      for (var tier = RunScore.curatedTierCap + 1;
          tier <= RunScore.maxTier;
          tier++) {
        expect(RunScore.centsFor(tier), RunScore.centsFor(tier - 1));
      }
    });

    test('x1 is a trickle and x5 is nearly a whole pay', () {
      expect(RunScore.centsFor(1), lessThan(10));
      expect(RunScore.centsFor(RunScore.maxTier), greaterThan(50));
    });

    test('out-of-range tiers clamp rather than throw', () {
      expect(RunScore.centsFor(0), RunScore.centsFor(1));
      expect(RunScore.centsFor(99), RunScore.centsFor(RunScore.maxTier));
    });
  });

  group('earning', () {
    int payAfter(int sorts, {int payPercent = 100}) {
      final score = RunScore();
      for (var i = 0; i < sorts; i++) {
        score.registerCorrect(payPercent: payPercent);
      }
      return score.pay;
    }

    test('one sort at x1 does not pay a whole unit', () {
      expect(payAfter(1), 0);
    });

    test('the first whole pay takes a run of sorts, not one', () {
      expect(payAfter(5), 0);
      expect(payAfter(12), greaterThan(0));
    });

    test('a clean run reaches the first board able to afford one memo', () {
      // Board one opens at P=22 (`EndlessShop.blinds`), and the cheapest
      // slips in the catalog cost 4. The player should be able to buy, and
      // should not be able to buy the whole board.
      final pay = payAfter(22);
      expect(pay, greaterThanOrEqualTo(4));
      expect(pay, lessThan(20));
    });

    test('breaking the combo costs real income', () {
      final clean = RunScore();
      for (var i = 0; i < 30; i++) {
        clean.registerCorrect();
      }

      final sloppy = RunScore();
      for (var i = 0; i < 30; i++) {
        sloppy.registerCorrect();
        // A misroute every fifth sort keeps the tier pinned near the floor.
        if (i % 5 == 4) {
          sloppy.registerMisroute();
        }
      }

      expect(
        sloppy.pay,
        lessThan(clean.pay),
        reason: 'a streak has to be worth more than attendance',
      );
    });

    test('a pay multiplier still scales the rate', () {
      expect(payAfter(22, payPercent: 200), greaterThan(payAfter(22)));
    });

    test('pay stays an integer so a replay stays exact', () {
      final score = RunScore();
      for (var i = 0; i < 37; i++) {
        score.registerCorrect();
      }
      expect(score.pay, isA<int>());
      expect(score.pay, greaterThanOrEqualTo(0));
    });
  });
}
