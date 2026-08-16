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

  /// Draws [count] distinct elements uniformly, in random order.
  ///
  /// A partial Fisher–Yates shuffle: each step swaps one more element into
  /// place from whatever is still unpicked, so a value can never be drawn
  /// twice and every possible hand is equally likely.
  ///
  /// The property that matters here is that it spends **exactly [count]
  /// draws**, whatever the size of [items]. The obvious alternative — pick at
  /// random and redraw on a duplicate — spends a *variable* number, so the
  /// sequence would depend on which values happened to collide. Anything
  /// drawing from a shared stream would then shift depending on game state,
  /// and a bug reported with a seed would no longer reproduce from that seed
  /// alone.
  ///
  /// [items] is not modified.
  List<T> take<T>(List<T> items, int count) {
    if (count < 0 || count > items.length) {
      throw ArgumentError.value(
        count,
        'count',
        'must be between 0 and ${items.length}',
      );
    }
    final work = List<T>.of(items);
    final drawn = <T>[];
    for (var i = 0; i < count; i++) {
      // Choose from what is left, then swap the choice out of the way so the
      // next step cannot reach it.
      final j = i + nextInt(work.length - i);
      final chosen = work[j];
      work[j] = work[i];
      drawn.add(chosen);
    }
    return drawn;
  }
}
