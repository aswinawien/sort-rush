import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/levels.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/core/run_summary.dart';

void main() {
  RunSummary endless(
          {required int sorted, int misrouted = 0, int dropped = 0}) =>
      RunSummary(
        levelId: 0,
        outcome: RunOutcome.failed,
        score: sorted * 10,
        sorted: sorted,
        misrouted: misrouted,
        dropped: dropped,
        bestCombo: 3,
        endless: true,
      );

  test('rate is correct sorts over everything that left the belt', () {
    expect(endless(sorted: 9, misrouted: 1).rate, 90);
    expect(endless(sorted: 0).rate, 0);
  });

  test('endless is judged on distance, not on a pass it cannot earn', () {
    expect(endless(sorted: 10).verdict, 'TEMP');
    expect(endless(sorted: 25).verdict, 'ON THE BOOKS');
    expect(endless(sorted: 60).verdict, 'SHIFT LEAD');
    expect(endless(sorted: 90).verdict, 'RAN THE FLOOR');
  });

  test('a wager doubles a clear and zeros a fail', () {
    const cleared = RunSummary(
      levelId: 2,
      outcome: RunOutcome.passed,
      score: 100,
      sorted: 12,
      misrouted: 0,
      dropped: 0,
      bestCombo: 2,
      wagered: true,
    );
    const bust = RunSummary(
      levelId: 2,
      outcome: RunOutcome.failed,
      score: 80,
      sorted: 8,
      misrouted: 3,
      dropped: 0,
      bestCombo: 1,
      wagered: true,
    );
    expect(cleared.postedScore, 200);
    expect(bust.postedScore, 0);
  });

  test('leftover pay is a snapshot and does not change the posted score', () {
    const run = RunSummary(
      levelId: 0,
      outcome: RunOutcome.failed,
      score: 2580,
      sorted: 55,
      misrouted: 4,
      dropped: 0,
      bestCombo: 5,
      endless: true,
      pay: 2,
    );
    expect(run.pay, 2);
    expect(run.postedScore, 2580);
  });

  test('fromEngine copies leftover pay without changing the score', () {
    final engine = RunEngine(level: kEndlessShift, seed: 1);
    engine.score.pay = 7;
    final summary = RunSummary.fromEngine(engine);
    expect(summary.pay, 7);
    expect(summary.postedScore, engine.score.score);
  });
}
