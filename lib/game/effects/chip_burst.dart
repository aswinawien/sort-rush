import 'dart:math' as math;
import 'dart:ui';

/// Tuning for a [ChipBurst].
///
/// Every field has a default that is already inside the play-field budget, so
/// a caller that just wants "the standard burst" passes nothing.
class ChipBurstSpec {
  const ChipBurstSpec({
    this.count = 4,
    this.lifetime = 0.18,
    this.length = 9,
    this.thickness = 2.5,
    this.spreadDegrees = 54,
    this.travel = 22,
    this.wakeLength = 0,
    this.fragments = 0,
    this.flash = 0,
  });

  /// Chips per burst. Kept small deliberately: this fires on every correct
  /// sort, so the cost is paid at the game's highest-frequency event.
  final int count;

  /// Seconds from spawn to gone.
  final double lifetime;

  final double length;
  final double thickness;

  /// Total fan angle, centred on straight up.
  final double spreadDegrees;

  /// Pixels travelled over the whole lifetime.
  final double travel;

  /// Height of the vertical wake drawn above the lip, following the package
  /// into the chute. Zero disables it.
  ///
  /// This is a *post-action* effect, not an active-package trail: it is drawn
  /// only once the package has been removed from the belt and can no longer be
  /// routed, so it can never decorate something the player still has to read.
  ///
  /// Render clips to [maxWakeAboveLip] even if a caller asks for more. The
  /// 0.65s spawn floor used to be the only thing keeping a 34px wake off the
  /// next package; the effect now owns that bound itself.
  final double wakeLength;

  /// Hard ceiling, in pixels above the lip. Short enough that a package at
  /// progress 0.90 cannot share the band.
  static const double maxWakeAboveLip = 10;

  /// Thin paper-like bars that separate from the main spray.
  final int fragments;

  /// Peak alpha of the impact flash at the lip. Zero disables it.
  final double flash;

  /// Everything drawn by one burst, for the effect counter.
  int get pieceCount => count + fragments;
}

/// A short spray of thin bars, thrown from the lip of a chute when a package
/// lands in it.
///
/// Three constraints come from the design review and are not incidental:
///
/// * Chips are **bars**, never circles, triangles or squares. Those three
///   silhouettes carry package identity, so emitting them as decoration would
///   put decoys into the one read the player has to perform.
/// * Positions are derived from the chip index, never from a random source, so
///   the burst is identical frame to frame and run to run. `design-system.md`
///   forbids strobing, and a seeded run has to stay reproducible.
/// * It fires *after* the package has left the belt, so it can never overlap
///   something still routable.
///
/// No blur and no `saveLayer`: this is the first per-frame effect in the
/// project and it stays on the cheap side of the rasteriser until a real
/// device has been profiled.
class ChipBurst {
  ChipBurst({
    required this.origin,
    required this.color,
    this.spec = const ChipBurstSpec(),
  });

  final Offset origin;
  final Color color;
  final ChipBurstSpec spec;

  final Paint _paint = Paint()..strokeCap = StrokeCap.square;

  double _elapsed = 0;

  bool get isDone => _elapsed >= spec.lifetime;

  void update(double dt) => _elapsed += dt;

  void render(Canvas canvas) {
    if (isDone) return;

    final t = _elapsed / spec.lifetime;
    _renderFlash(canvas, t);
    _renderWake(canvas, t);
    // Ease out: chips leave fast and settle, which reads as an impact rather
    // than a drift.
    final eased = 1 - (1 - t) * (1 - t);
    final fade = 1 - t;

    _paint
      ..color = color.withValues(alpha: fade)
      ..strokeWidth = spec.thickness;

    final spread = spec.spreadDegrees * math.pi / 180;
    final step = spec.count == 1 ? 0.0 : spread / (spec.count - 1);
    final start = -math.pi / 2 - spread / 2;

    for (var i = 0; i < spec.count; i++) {
      final angle = start + step * i;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final head = origin + dir * (spec.travel * eased);
      canvas.drawLine(head, head - dir * (spec.length * fade), _paint);
    }

    _renderFragments(canvas, eased, fade);
  }

  /// A brief bloom of light at the lip. A filled rect, not a blur — the
  /// project still has no `saveLayer` anywhere and this is not the place to
  /// introduce one.
  void _renderFlash(Canvas canvas, double t) {
    if (spec.flash <= 0) return;
    final fade = (1 - t * 2.2).clamp(0.0, 1.0);
    if (fade <= 0) return;
    canvas.drawRect(
      Rect.fromCenter(
        center: origin,
        width: 46 + 26 * t,
        height: 5,
      ),
      Paint()..color = color.withValues(alpha: spec.flash * fade),
    );
  }

  /// A narrowing vertical streak above the lip: the path the package just
  /// took, collapsing after it.
  void _renderWake(Canvas canvas, double t) {
    if (spec.wakeLength <= 0) return;
    final fade = (1 - t).clamp(0.0, 1.0);
    if (fade <= 0) return;
    final height =
        math.min(spec.wakeLength * fade, ChipBurstSpec.maxWakeAboveLip);
    final width = 5 * fade;
    canvas.drawRect(
      Rect.fromLTWH(origin.dx - width / 2, origin.dy - height, width, height),
      Paint()..color = color.withValues(alpha: 0.45 * fade),
    );
  }

  /// Thin bars peeling off sideways. Bars only — a circle, triangle or square
  /// here would put a decoy into the identity vocabulary.
  void _renderFragments(Canvas canvas, double eased, double fade) {
    if (spec.fragments <= 0) return;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55 * fade)
      ..strokeCap = StrokeCap.square
      ..strokeWidth = 1.6;
    for (var i = 0; i < spec.fragments; i++) {
      // Derived from the index, never from a random source: the burst has to
      // be identical frame to frame and run to run.
      final side = i.isEven ? 1.0 : -1.0;
      final rank = (i ~/ 2) + 1;
      final x = origin.dx + side * (10.0 + rank * 9) * eased;
      final y = origin.dy - (6.0 + rank * 5) * eased;
      canvas.drawLine(Offset(x, y), Offset(x + side * 7 * fade, y), paint);
    }
  }
}
