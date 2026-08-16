/// The silhouette of a package. Shape is always readable without colour.
enum PackageShape { circle, triangle, square }

/// Fill patterns are permanently paired with hues, one-to-one by index, so
/// that colour is never the only carrier of identity. A player who sees all
/// three hues as the same grey can still play on pattern alone.
///
/// See docs/decision-log.md, "Color is never load-bearing alone" (approved).
enum FillPattern { solid, hatch, dotted }

/// Rule modifiers that outrank the base routing rule.
///
/// Not used by levels 1-3. Present so the routing layer has a stable shape
/// when stamps arrive in Milestone 4; [PackageStamp.none] is the only value
/// the prototype ever constructs.
enum PackageStamp { none, priority, damaged }

/// An immutable description of one package.
class PackageSpec {
  const PackageSpec({
    required this.shape,
    required this.colorIndex,
    this.stamp = PackageStamp.none,
  }) : assert(colorIndex >= 0 && colorIndex < 3, 'colorIndex must be 0..2');

  final PackageShape shape;

  /// Index into the three-hue palette, 0..2.
  final int colorIndex;

  final PackageStamp stamp;

  /// Derived, never stored separately: the pattern is a function of the hue so
  /// the two can never drift apart.
  FillPattern get pattern => FillPattern.values[colorIndex];

  @override
  bool operator ==(Object other) =>
      other is PackageSpec &&
      other.shape == shape &&
      other.colorIndex == colorIndex &&
      other.stamp == stamp;

  @override
  int get hashCode => Object.hash(shape, colorIndex, stamp);

  @override
  String toString() =>
      'PackageSpec(${shape.name}, hue $colorIndex, ${stamp.name})';
}
