import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/difficulty.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/machine_intensity.dart';
import 'package:sort_rush/core/run_tuning.dart';
import 'package:sort_rush/core/score_state.dart';
import 'package:sort_rush/core/shop.dart';
import 'package:sort_rush/core/tuning_delta.dart';

/// The combo ceiling is x10 in endless and x5 everywhere else.
///
/// x10 costs fifty consecutive clean sorts. Curated shifts run 30–90 seconds
/// against sort targets in the twenties, so they cannot reach it — advertising
/// a ceiling a shift cannot touch would be a lie in the HUD.
void main() {
  group('the ceiling', () {
    test('endless opts up and curated shifts do not', () {
      expect(kEndlessShift.comboCap, RunScore.maxTier);
      for (final level in kCuratedLevels) {
        expect(
          level.comboCap,
          RunScore.curatedTierCap,
          reason: 'shift ${level.id} should keep the curated ceiling',
        );
      }
    });

    test('a curated shift cannot reach the endless ceiling anyway', () {
      // Belt and braces: even without the cap, no curated sort target is long
      // enough for fifty in a row.
      const needed = RunScore.sortsPerTier * (RunScore.maxTier - 1);
      expect(needed, 45);
      expect(RunScore.tierFor(needed), RunScore.maxTier);
    });

    test('tuning resolves the level ceiling, not the absolute one', () {
      final curated = RunTuning.resolve(level: levelById(4));
      expect(curated.maxComboTier, RunScore.curatedTierCap);

      final endless = RunTuning.resolve(level: kEndlessShift);
      expect(endless.maxComboTier, RunScore.maxTier);
    });

    test('a memo may lower the ceiling and never raise it', () {
      final lowered = RunTuning.resolve(
        level: kEndlessShift,
        modifiers: const TuningDelta(maxComboTier: -2),
      );
      expect(lowered.maxComboTier, RunScore.maxTier - 2);

      final raised = RunTuning.resolve(
        level: levelById(4),
        modifiers: const TuningDelta(maxComboTier: 5),
      );
      expect(
        raised.maxComboTier,
        RunScore.curatedTierCap,
        reason: 'a purchase must not breach the shift ceiling',
      );
    });
  });

  group('MAXXXX', () {
    test('is the top tier, reached at fifty consecutive', () {
      final score = RunScore()..comboCap = RunScore.maxTier;
      for (var i = 0; i < 44; i++) {
        score.registerCorrect();
      }
      expect(score.isMaxxxx, isFalse);
      score.registerCorrect();
      expect(score.comboTier, RunScore.maxTier);
      expect(score.isMaxxxx, isTrue);
    });

    test('a curated run never reports it', () {
      final score = RunScore(); // defaults to the curated cap
      for (var i = 0; i < 200; i++) {
        score.registerCorrect();
      }
      expect(score.comboTier, RunScore.curatedTierCap);
      expect(score.isMaxxxx, isFalse);
    });

    test('a mistake drops it straight back out', () {
      final score = RunScore()..comboCap = RunScore.maxTier;
      for (var i = 0; i < 50; i++) {
        score.registerCorrect();
      }
      expect(score.isMaxxxx, isTrue);
      score.registerMisroute();
      expect(score.isMaxxxx, isFalse);
      expect(score.comboTier, 1);
    });

    test('prints wider than any numbered tier, and still holds', () {
      expect(
        MachineIntensity.comboSplitPx(RunScore.maxxxxTier),
        greaterThan(MachineIntensity.comboSplitPx(RunScore.maxxxxTier - 1)),
      );
      // Held, not animated: the same tier always prints the same width.
      expect(
        MachineIntensity.comboSplitPx(RunScore.maxxxxTier),
        MachineIntensity.comboSplitPx(RunScore.maxxxxTier),
      );
    });

    test('the wall reaches full intensity only at MAXXXX', () {
      expect(MachineIntensity.comboStepFor(RunScore.maxxxxTier), 1.0);
      expect(
        MachineIntensity.comboStepFor(RunScore.maxxxxTier - 1),
        lessThan(1.0),
      );
    });
  });

  group('the x1-x5 range is untouched', () {
    test('curated wall steps are byte-identical to the approved values', () {
      // Extending the curve must not re-space what already shipped.
      expect(
        MachineIntensity.comboSteps.take(5).toList(),
        [0, 0.25, 0.40, 0.55, 0.70],
      );
    });

    test('splits below the ceiling are unchanged', () {
      expect(MachineIntensity.comboSplitPx(1), 0);
      expect(MachineIntensity.comboSplitPx(2), 2);
      expect(MachineIntensity.comboSplitPx(3), 2);
      expect(MachineIntensity.comboSplitPx(4), 3);
      expect(MachineIntensity.comboSplitPx(5), 3);
    });
  });

  group('income is flat above x5', () {
    test('tiers six and up pay the x5 rate', () {
      for (var tier = RunScore.curatedTierCap; tier <= RunScore.maxTier; tier++) {
        expect(
          RunScore.centsFor(tier),
          RunScore.centsFor(RunScore.curatedTierCap),
          reason: 'x$tier must not out-earn x5, or late pay piles up unspent',
        );
      }
    });

    test('the climb below x5 still exists', () {
      for (var tier = 2; tier <= RunScore.curatedTierCap; tier++) {
        expect(RunScore.centsFor(tier), greaterThan(RunScore.centsFor(tier - 1)));
      }
    });
  });

  group('phase three', () {
    const curve = EndlessCurve();

    test('adds nothing until the timing levers bottom out', () {
      expect(curve.chaosBonusAt(0), 0);
      expect(curve.chaosBonusAt(EndlessCurve.phaseTwoEnd), 0);
    });

    test('escalates past the point the old curve stopped', () {
      final at200 = curve.chaosBonusAt(200);
      final at300 = curve.chaosBonusAt(300);
      expect(at200, greaterThan(0));
      expect(at300, greaterThan(at200));
    });

    test('a run past P=130 is measurably harder than one at it', () {
      final atFloor = RunTuning.resolve(
        level: kEndlessShift,
        pressure: EndlessCurve.phaseTwoEnd,
      );
      final deep = RunTuning.resolve(level: kEndlessShift, pressure: 300);

      // Timing is identical — both sit on the fairness floors.
      expect(deep.readWindow, atFloor.readWindow);
      expect(deep.spawnInterval, atFloor.spawnInterval);
      // Chaos is not.
      expect(
        deep.chaosRate,
        greaterThan(atFloor.chaosRate),
        reason: 'endless stopped escalating at 130 and a perfect run reached '
            '488 without a mistake',
      );
    });

    test('chaos still clamps, so it cannot exceed every package', () {
      final absurd = RunTuning.resolve(level: kEndlessShift, pressure: 5000);
      expect(absurd.chaosRate, lessThanOrEqualTo(1.0));
    });

    test('a curated shift has no third phase', () {
      final level = levelById(4);
      expect(level.curve, isNull);
      final tuning = RunTuning.resolve(level: level, pressure: 400);
      expect(tuning.chaosRate, level.chaosRate);
    });
  });

  group('boards', () {
    test('run the length of a run, not just its opening', () {
      expect(EndlessShop.blinds.length, greaterThan(3));
      expect(
        EndlessShop.blinds.last,
        greaterThan(EndlessCurve.phaseTwoEnd),
        reason: 'pay earned after the curve flattens had nowhere to go',
      );
    });

    test('thresholds stay strictly increasing', () {
      for (var i = 1; i < EndlessShop.blinds.length; i++) {
        expect(
          EndlessShop.blinds[i],
          greaterThan(EndlessShop.blinds[i - 1]),
        );
      }
    });

    test('the first three are unchanged', () {
      expect(EndlessShop.blinds.take(3).toList(), [22, 50, 80]);
    });
  });

  test('CLEAN SHIFT keeps its bite against the taller ceiling', () {
    final card = EndlessShop.catalog.firstWhere((c) => c.id == 'clean-shift');
    final capped = RunTuning.resolve(
      level: kEndlessShift,
      modifiers: card.delta,
    );
    final ratio =
        (RunScore.maxTier - capped.maxComboTier) / RunScore.maxTier;
    expect(
      ratio,
      greaterThanOrEqualTo(0.2),
      reason: 'a -1 against a ceiling of ten would be a near-free buy',
    );
  });
}
