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

/// The package attribute a routing rule reads.
///
/// Exposed so `DAMAGED` can corrupt the attribute that actually decides the
/// destination. Corrupting a fixed attribute would be inert on any level that
/// routes on the other one — see docs/decision-log.md, "`DAMAGED` corrupts
/// the wrong attribute on colour-routed levels".
enum RoutedAttribute { shape, colour, compound }

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

  /// Which attribute this rule reads. Everything else about a package is
  /// decoration as far as this rule is concerned.
  RoutedAttribute get reads;
}

/// Hazardous cargo: the unique destination is forbidden; any other live
/// chute is valid.
///
/// Needs three chutes to express "forbidden in a third". On a smaller
/// board the unique destination stays the only correct tap. At four
/// chutes the same function holds — one forbidden, the rest valid.
/// See docs/decision-log.md, "Hazardous cargo as avoid-the-wrong-chute".
bool hazardousAccepts(int uniqueBin, int binIndex, int binCount) {
  if (binIndex < 0 || binIndex >= binCount) {
    return false;
  }
  if (binCount < 3) {
    return uniqueBin == binIndex;
  }
  return uniqueBin != binIndex;
}

/// Routes on silhouette. Used by levels 1-2, where shape is the only attribute
/// that matters.
class ShapeRouting implements RoutingRule {
  ShapeRouting(this.order)
      : assert(order.isNotEmpty, 'need at least one destination');

  /// Shapes in bin order. Position in this list *is* the bin index.
  final List<PackageShape> order;

  @override
  RoutedAttribute get reads => RoutedAttribute.shape;

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
  RoutedAttribute get reads => RoutedAttribute.colour;

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

/// Exact pair match, ignoring stamps. Used as the reflex answer.
int exactCompoundBin(List<PackageSpec> order, PackageSpec package) {
  for (var i = 0; i < order.length; i++) {
    if (order[i].shape == package.shape &&
        order[i].colorIndex == package.colorIndex) {
      return i;
    }
  }
  return -1;
}

/// Compound routing, with `PRIORITY` flipping which attribute wins.
///
/// The stamp is a Stroop conflict: the pair is the reflex, and the stamp
/// outranks it by sending the package to the chute that matches the *other*
/// attribute — hue without shape, or shape without hue if no such chute
/// exists. Shared by [CompoundRouting] and the live endless board so a swap
/// cannot invent a second matching rule.
int compoundBinFor(List<PackageSpec> order, PackageSpec package) {
  final exact = exactCompoundBin(order, package);
  if (package.stamp != PackageStamp.priority) {
    return exact;
  }
  int? hueOnly;
  int? shapeOnly;
  for (var i = 0; i < order.length; i++) {
    final chute = order[i];
    if (chute.colorIndex == package.colorIndex &&
        chute.shape != package.shape) {
      hueOnly ??= i;
    }
    if (chute.shape == package.shape &&
        chute.colorIndex != package.colorIndex) {
      shapeOnly ??= i;
    }
  }
  if (hueOnly != null) {
    return hueOnly;
  }
  if (shapeOnly != null) {
    return shapeOnly;
  }
  return exact;
}

/// Routes on shape *and* hue together, with each chute owning one exact pair.
///
/// The pairs are chosen so that neither attribute alone disambiguates: two
/// chutes share a shape and two share a hue, so reading only one of them
/// leaves the player guessing between two chutes. That is the whole lesson of
/// level 8 — the ladder in docs/design-spec.md §2 goes identity, attribute
/// switch, compound, override, and this is the third rung.
///
/// Only the pairs listed here are ever spawned. A level that could spawn a
/// combination with no chute would be unwinnable through no fault of the
/// player, which `levels_test.dart` checks for.
class CompoundRouting implements RoutingRule {
  CompoundRouting(this.order)
      : assert(order.isNotEmpty, 'need at least one destination');

  /// (shape, hue) pairs in chute order. Position in this list *is* the index.
  final List<PackageSpec> order;

  @override
  RoutedAttribute get reads => RoutedAttribute.compound;

  @override
  int binFor(PackageSpec package) => compoundBinFor(order, package);

  @override
  late final List<BinSpec> bins = [
    for (var i = 0; i < order.length; i++)
      BinSpec(
        label: _letter(i),
        shape: order[i].shape,
        pattern: order[i].pattern,
      ),
  ];
}
