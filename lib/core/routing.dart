import 'package_spec.dart';

/// What a bin displays as its identity.
///
/// Bins never carry an identifying fill colour. They are distinguished by a
/// silhouette or a fill pattern, plus a mono letter. See docs/decision-log.md,
/// "Color is never load-bearing alone" (approved).
class BinSpec {
  const BinSpec({required this.label, this.shape, this.pattern})
      : assert(
          shape != null || pattern != null,
          'a bin must show either a shape or a pattern',
        );

  /// Mono letter shown on the bin, e.g. "A".
  final String label;

  /// Set when the level routes by shape.
  final PackageShape? shape;

  /// Set when the level routes by colour; drawn as the pattern swatch.
  final FillPattern? pattern;
}

/// Maps a package to the index of the bin it belongs in.
///
/// Implementations are pure and engine-free so routing can be unit tested
/// without a game loop.
abstract class RoutingRule {
  /// Index of the correct bin, or -1 if this package has no valid destination
  /// (a level-configuration error, not a legal game state).
  int binFor(PackageSpec package);

  /// The bins this rule addresses, in display order.
  List<BinSpec> get bins;
}

/// Routes on silhouette. Used by levels 1-2, where shape is the only attribute
/// that matters.
class ShapeRouting implements RoutingRule {
  ShapeRouting(this.order)
      : assert(order.isNotEmpty, 'need at least one destination');

  /// Shapes in bin order. Position in this list *is* the bin index.
  final List<PackageShape> order;

  @override
  int binFor(PackageSpec package) => order.indexOf(package.shape);

  /// Built once. `binCount` is read on every tap, so this must not allocate
  /// a fresh list each time it is asked.
  @override
  late final List<BinSpec> bins = [
    for (var i = 0; i < order.length; i++)
      BinSpec(label: _letter(i), shape: order[i]),
  ];
}

/// Routes on hue. Used from level 3, where shape becomes the irrelevant
/// attribute and the player must switch which property they read.
///
/// This switch is the point of levels 3-4: the reflex answer built in levels
/// 1-2 is now the wrong one.
class ColorRouting implements RoutingRule {
  ColorRouting(this.order)
      : assert(order.isNotEmpty, 'need at least one destination');

  /// Hue indices in bin order. Position in this list *is* the bin index.
  final List<int> order;

  @override
  int binFor(PackageSpec package) => order.indexOf(package.colorIndex);

  @override
  late final List<BinSpec> bins = [
    for (var i = 0; i < order.length; i++)
      BinSpec(
        label: _letter(i),
        pattern: FillPattern.values[order[i]],
      ),
  ];
}

String _letter(int index) => String.fromCharCode(65 + index);
