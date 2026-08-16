import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/seeded_rng.dart';

void main() {
  group('SeededRng', () {
    test('the same seed produces the same sequence', () {
      final a = SeededRng(12345);
      final b = SeededRng(12345);
      final left = List.generate(50, (_) => a.nextInt(1000));
      final right = List.generate(50, (_) => b.nextInt(1000));
      expect(left, equals(right));
    });

    test('different seeds diverge', () {
      final a = SeededRng(1);
      final b = SeededRng(2);
      final left = List.generate(50, (_) => a.nextInt(1000));
      final right = List.generate(50, (_) => b.nextInt(1000));
      expect(left, isNot(equals(right)));
    });

    test('seed zero does not collapse to a fixed point', () {
      final rng = SeededRng(0);
      final draws = List.generate(20, (_) => rng.nextInt(100));
      expect(draws.toSet().length, greaterThan(1));
    });

    test('nextInt stays in range', () {
      final rng = SeededRng(99);
      for (var i = 0; i < 500; i++) {
        final value = rng.nextInt(7);
        expect(value, greaterThanOrEqualTo(0));
        expect(value, lessThan(7));
      }
    });

    test('nextDouble stays in [0, 1)', () {
      final rng = SeededRng(7);
      for (var i = 0; i < 500; i++) {
        final value = rng.nextDouble();
        expect(value, greaterThanOrEqualTo(0));
        expect(value, lessThan(1));
      }
    });

    test('rejects a non-positive bound', () {
      expect(() => SeededRng(1).nextInt(0), throwsArgumentError);
    });

    test('rejects picking from an empty list', () {
      expect(() => SeededRng(1).pick<int>([]), throwsArgumentError);
    });
  });

  group('take', () {
    final pool = List.generate(8, (i) => 'card$i');

    test('draws the number asked for, with no repeats', () {
      final drawn = SeededRng(1).take(pool, 3);
      expect(drawn, hasLength(3));
      expect(drawn.toSet(), hasLength(3));
      for (final card in drawn) {
        expect(pool, contains(card));
      }
    });

    test('spends exactly one draw per item, whatever the pool size', () {
      // The property the shop depends on. If a duplicate ever caused a
      // redraw, the number of draws would depend on which values collided,
      // and a seeded bug report would stop reproducing from its seed alone.
      final viaTake = SeededRng(42)..take(pool, 3);
      final viaCounted = SeededRng(42);
      for (var i = 0; i < 3; i++) {
        viaCounted.nextInt(8 - i);
      }
      expect(viaTake.state, viaCounted.state);
    });

    test('the same seed draws the same hand', () {
      expect(SeededRng(7).take(pool, 4), SeededRng(7).take(pool, 4));
      expect(SeededRng(7).take(pool, 4), isNot(SeededRng(8).take(pool, 4)));
    });

    test('taking everything is a permutation, not a copy', () {
      final all = SeededRng(3).take(pool, pool.length);
      expect(all.toSet(), pool.toSet());
      expect(all, isNot(orderedEquals(pool)));
    });

    test('leaves the source list alone', () {
      final before = List.of(pool);
      SeededRng(1).take(pool, 5);
      expect(pool, orderedEquals(before));
    });

    test('taking none is legal and costs nothing', () {
      final rng = SeededRng(1);
      final before = rng.state;
      expect(rng.take(pool, 0), isEmpty);
      expect(rng.state, before);
    });

    test('rejects asking for more than exists', () {
      expect(() => SeededRng(1).take(pool, 9), throwsArgumentError);
      expect(() => SeededRng(1).take(pool, -1), throwsArgumentError);
    });

    test('every item comes up about as often as every other', () {
      // Not a proof of uniformity, but it would catch an off-by-one in the
      // range — the classic Fisher-Yates bug, which biases the result while
      // still looking shuffled.
      final counts = <String, int>{for (final c in pool) c: 0};
      for (var seed = 1; seed <= 4000; seed++) {
        for (final card in SeededRng(seed).take(pool, 3)) {
          counts[card] = counts[card]! + 1;
        }
      }
      final expected = 4000 * 3 / pool.length;
      for (final entry in counts.entries) {
        expect(entry.value, closeTo(expected, expected * 0.15),
            reason: '${entry.key} came up ${entry.value} times');
      }
    });
  });
}
