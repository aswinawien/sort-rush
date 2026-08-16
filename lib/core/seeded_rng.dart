/// Deterministic pseudo-random source.
///
/// Uses xorshift32 rather than `dart:math`'s `Random` so that a given seed
/// produces an identical sequence on every platform and every SDK version.
/// "Same seed plus same input timeline reproduces a run exactly" is an
/// acceptance criterion, so the algorithm is pinned here deliberately instead
/// of being inherited from the SDK.
class SeededRng {
  SeededRng(int seed) : _state = (seed == 0 ? _fallbackSeed : seed) & _mask;

  /// xorshift32 degenerates to a fixed point at zero, so seed 0 is remapped.
  static const int _fallbackSeed = 0x9E3779B9;
  static const int _mask = 0xFFFFFFFF;

  int _state;

  /// Current internal state. Exposed so a run can be snapshotted in tests.
  int get state => _state;

  int _next() {
    var x = _state;
    x ^= (x << 13) & _mask;
    x ^= x >> 17;
    x ^= (x << 5) & _mask;
    _state = x & _mask;
    return _state;
  }

  /// Uniform integer in `[0, max)`.
  int nextInt(int max) {
    if (max <= 0) {
      throw ArgumentError.value(max, 'max', 'must be positive');
    }
    return _next() % max;
  }

  /// Uniform double in `[0, 1)`.
  double nextDouble() => _next() / 0x100000000;

  /// Picks one element uniformly. Throws if [items] is empty.
  T pick<T>(List<T> items) {
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'must not be empty');
    }
    return items[nextInt(items.length)];
  }
}
