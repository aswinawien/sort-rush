import 'dart:math' as math;

/// The static ground the packages travel over: a lane, its rails, and the
/// slats that segment it.
///
/// Geometry and tokens only, with no Flame import, so it is testable without a
/// game loop — the same reason `clutch_band.dart` is a pair of free functions.
///
/// **Everything here is static.** Nothing scrolls, nothing reacts to score,
/// combo, pressure or mistakes. That is the whole argument for it: it is
/// background ground under the grant in docs/design-spec.md §5.2, not an
/// effect under *Play-field effects may carry information* (2026-08-16), whose
/// test is whether removing it costs the player something they could have
/// acted on. Removing this costs them nothing, which is exactly why it is
/// allowed to be always on — and why it is drawn under reduce-motion, where
/// the scan lines and the clutch band are not.
///
/// A reactive version of any of this would be a new decision, not a tweak.
abstract final class BeltGround {
  /// Lane fill, over `Tokens.ink`.
  ///
  /// Low enough that it never competes with a package silhouette, including
  /// with all three hues rendered as the same grey — acceptance criterion 9
  /// is the constraint that sets this number, not taste.
  static const double laneAlpha = 0.06;

  /// The two verticals bounding the lane. The strongest mark here, and still
  /// well under the `paper` stroke every package carries.
  static const double railAlpha = 0.35;

  /// Belt segmentation. Sits between the fill and the rails so the lane reads
  /// as a surface rather than as a flat block.
  static const double slatAlpha = 0.10;

  /// Distance between slats, in logical pixels.
  ///
  /// Fixed, and deliberately never a fraction of belt height. A taller screen
  /// shows *more* slats, not larger ones. Scaling this with height would make
  /// the belt appear to run at a different speed on a different device, while
  /// travel time is time-based and identical — see docs/design-spec.md §8,
  /// which makes that a hard requirement rather than a preference.
  static const double slatSpacing = 28;

  /// Clear space kept between a rail and the screen edge.
  static const double minMargin = 12;

  /// Width of the travelled lane, centred on the belt.
  ///
  /// Wide enough for a three-package cluster with a margin either side.
  ///
  /// Was twice the package box, which held one centred package and read as a
  /// narrow chute on a 1080px panel — about a quarter of the screen, noted
  /// when the belt ground first ran on Android. Clusters need the room and
  /// the composition wanted it anyway. Clamped on narrow screens so the rails
  /// never reach the edge across the 4:3 through 21:9 range in §8.
  /// Horizontal step between adjacent cluster members, in package widths.
  ///
  /// Just over one, so two packages arriving together read as two objects
  /// rather than one blob.
  static const double laneStepFactor = 1.05;

  /// Package widths the lane must hold: a three-package cluster spread across
  /// [laneStepFactor] steps, plus a margin either side.
  static const double laneWidthFactor = 3.4;

  static double laneStep(double packageSize) => packageSize * laneStepFactor;

  static double laneWidth(double beltWidth, {required double packageSize}) {
    final ideal = packageSize * laneWidthFactor;
    final available = beltWidth - minMargin * 2;
    return math.max(0, math.min(ideal, available));
  }

  /// Left edge of the lane, in belt-local coordinates.
  static double laneLeft(double beltWidth, {required double packageSize}) =>
      (beltWidth - laneWidth(beltWidth, packageSize: packageSize)) / 2;
}
