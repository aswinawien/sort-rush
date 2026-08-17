import 'package_spec.dart';
import 'routing.dart';

/// Live chute order. Endless owns one; curated levels never move theirs.
///
/// Compound pairs, same matching rule as [CompoundRouting]: a package belongs
/// in the chute whose shape *and* hue both match. Stamp is ignored — stamps
/// override elsewhere, they do not invent a fifth chute.
class ChuteBoard {
  ChuteBoard(List<PackageSpec> order)
      : assert(order.isNotEmpty, 'a board with no chutes is not a game'),
        _order = List<PackageSpec>.unmodifiable(order);

  final List<PackageSpec> _order;

  List<PackageSpec> get order => _order;

  int get length => _order.length;

  int binFor(PackageSpec package) => compoundBinFor(_order, package);

  late final List<BinSpec> bins = [
    for (var i = 0; i < _order.length; i++)
      BinSpec(
        label: String.fromCharCode(65 + i),
        shape: _order[i].shape,
        pattern: _order[i].pattern,
      ),
  ];

  ChuteBoard grown(PackageSpec extra) => ChuteBoard([..._order, extra]);

  ChuteBoard swapped(int a, int b) {
    final next = List<PackageSpec>.of(_order);
    final hold = next[a];
    next[a] = next[b];
    next[b] = hold;
    return ChuteBoard(next);
  }
}

enum LayoutChangeKind { grow, swap }

/// A board change the player can see coming.
///
/// Duration is frozen when the warning starts, and is at least the live read
/// window *and* at least as long as any package still on the belt has left.
/// Spawning also pauses for the warning. Together that means nobody is still
/// reading a package when the chutes move.
class LayoutTelegraph {
  LayoutTelegraph({
    required this.kind,
    required this.next,
    required this.duration,
    required this.highlighted,
  }) : remaining = duration;

  final LayoutChangeKind kind;
  final ChuteBoard next;
  final double duration;
  final Set<int> highlighted;
  double remaining;
}

/// The endless chute ladder and when it grows.
///
/// Opens at two compound pairs — the colour-switch lesson, not a new rule —
/// then adds a third and a fourth as pressure rises. Morphing a chute's
/// identity was rejected: that is `DAMAGED` applied to the board, and it
/// changes the answer for every package at once.
abstract final class EndlessBoard {
  static const List<PackageSpec> ladder = [
    PackageSpec(shape: PackageShape.circle, colorIndex: 0),
    PackageSpec(shape: PackageShape.circle, colorIndex: 1),
    PackageSpec(shape: PackageShape.triangle, colorIndex: 0),
    PackageSpec(shape: PackageShape.triangle, colorIndex: 1),
  ];

  static const int openingCount = 2;
  static const int growToThreeAt = 18;
  static const int growToFourAt = 45;
  static const int priorityAt = 65;
  static const double priorityRate = 0.20;
  static const double swapInterval = 25;

  static int targetCount(int pressure) {
    if (pressure >= growToFourAt) {
      return 4;
    }
    if (pressure >= growToThreeAt) {
      return 3;
    }
    return openingCount;
  }

  /// Fill of the current pressure band, 0–1. The HUD draws this; it is not a
  /// third counter.
  static double pressureProgress(int pressure) {
    if (pressure >= 130) {
      return 1;
    }
    if (pressure >= growToFourAt) {
      return (pressure - growToFourAt) / (130 - growToFourAt);
    }
    if (pressure >= growToThreeAt) {
      return (pressure - growToThreeAt) / (growToFourAt - growToThreeAt);
    }
    return pressure / growToThreeAt;
  }
}
