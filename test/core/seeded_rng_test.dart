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
}
