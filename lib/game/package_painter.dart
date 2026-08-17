import 'dart:ui';

import '../core/package_spec.dart';
import '../ui/theme.dart';
import 'text_util.dart';

/// Drawing routines shared by packages on the belt and the identity swatch on
/// a bin, so the two can never drift out of sync visually.
///
/// Every hue is drawn through its paired pattern. Nothing here ever renders a
/// hue as a flat fill without its pattern.
abstract final class PackagePainter {
  static final Paint _fillPaint = Paint();

  static Path shapePath(PackageShape shape, Rect r) {
    switch (shape) {
      case PackageShape.circle:
        return Path()..addOval(r);
      case PackageShape.triangle:
        return Path()
          ..moveTo(r.center.dx, r.top)
          ..lineTo(r.right, r.bottom)
          ..lineTo(r.left, r.bottom)
          ..close();
      case PackageShape.square:
        return Path()
          ..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)));
    }
  }

  /// Fills [path] with [hue] rendered through [pattern].
  static void fillPattern(
    Canvas canvas,
    Path path,
    Color hue,
    FillPattern pattern,
  ) {
    canvas.save();
    canvas.clipPath(path);
    final bounds = path.getBounds();
    // Reused rather than allocated: this runs once per package per frame, and
    // every property below is set before use.
    final paint = _fillPaint
      ..color = hue
      ..style = PaintingStyle.fill
      ..strokeWidth = 0;

    switch (pattern) {
      case FillPattern.solid:
        canvas.drawRect(bounds, paint);
      case FillPattern.hatch:
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = 3;
        final span = bounds.height;
        for (var x = bounds.left - span; x < bounds.right + span; x += 9) {
          canvas.drawLine(
            Offset(x, bounds.bottom),
            Offset(x + span, bounds.top),
            paint,
          );
        }
      case FillPattern.dotted:
        for (var y = bounds.top + 4; y < bounds.bottom; y += 9) {
          for (var x = bounds.left + 4; x < bounds.right; x += 9) {
            canvas.drawCircle(Offset(x, y), 2.2, paint);
          }
        }
    }
    canvas.restore();
  }

  /// Draws one package. [isActive] marks the package the next bin tap will
  /// route, which is the only thing distinguishing it from the lookahead
  /// queue behind it.
  static void paintPackage(
    Canvas canvas,
    Rect rect,
    PackageSpec spec, {
    required bool isActive,
    bool isUnstable = false,
  }) {
    final path = shapePath(spec.shape, rect);

    // The corrupted state, drawn *behind* the package: a warning-coloured
    // ghost offset like a mistracked print head. This is the whole `DAMAGED`
    // mechanic — the player is meant to see this and hold their tap until the
    // package settles. Without it the shape-shift is silent, which is the
    // version that was rejected for punishing a decision already committed to.
    if (isUnstable) {
      canvas.drawPath(
        shapePath(spec.shape, rect.translate(-3.5, 0)),
        Paint()..color = Tokens.warn.withValues(alpha: 0.55),
      );
    }

    fillPattern(canvas, path, Tokens.hues[spec.colorIndex], spec.pattern);

    if (isUnstable) {
      _paintTear(canvas, path, rect);
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isActive ? 3.5 : 1.5
        ..color =
            isUnstable ? Tokens.warn : (isActive ? Tokens.acid : Tokens.paper),
    );

    if (spec.stamp == PackageStamp.priority) {
      _paintPriority(canvas, rect);
    }

    if (isActive) {
      canvas.drawPath(
        shapePath(spec.shape, rect.inflate(7)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Tokens.acid.withValues(alpha: 0.45),
      );
    }
  }

  /// Horizontal tear bands across a corrupting package.
  ///
  /// Positions are fixed rather than random per frame. A package that jitters
  /// every tick would be a strobe, which `docs/design-system.md` forbids —
  /// this has to read as damage while staying still enough to look at.
  static void _paintTear(Canvas canvas, Path path, Rect rect) {
    canvas.save();
    canvas.clipPath(path);
    final paint = Paint()
      ..color = Tokens.warn.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    for (final at in const [0.24, 0.42, 0.63, 0.81]) {
      final y = rect.top + rect.height * at;
      canvas.drawRect(Rect.fromLTWH(rect.left, y, rect.width, 2.5), paint);
    }
    // A displaced slab, as though one band of the label slipped.
    canvas.drawRect(
      Rect.fromLTWH(
        rect.left + 6,
        rect.top + rect.height * 0.46,
        rect.width,
        rect.height * 0.13,
      ),
      Paint()..color = Tokens.ink.withValues(alpha: 0.75),
    );
    canvas.restore();
  }

  /// A static acid "P" badge. The override is the whole mechanic: if it is
  /// not visible, the reflex chute is a silent lie. Positions are fixed —
  /// a jittering badge would be a strobe.
  static void _paintPriority(Canvas canvas, Rect rect) {
    final badge = Rect.fromLTWH(
      rect.right - 16,
      rect.top - 2,
      16,
      14,
    );
    canvas.drawRect(badge, Paint()..color = Tokens.acid);
    final mark = layoutText(
      'P',
      Tokens.label.copyWith(
        color: Tokens.ink,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
    mark.paint(
      canvas,
      Offset(
        badge.center.dx - mark.width / 2,
        badge.center.dy - mark.height / 2,
      ),
    );
  }

  /// Draws the identity swatch on a bin: a silhouette for shape-routed levels,
  /// a pattern swatch for colour-routed ones. Never an identifying fill colour.
  static void paintBinIdentity(
    Canvas canvas,
    Rect rect, {
    PackageShape? shape,
    FillPattern? pattern,
  }) {
    if (shape != null) {
      final path = shapePath(shape, rect);
      // A compound chute carries both, and both have to be drawn. Returning
      // after the silhouette left two chutes on levels 8, 9 and endless
      // rendering as identical outlines while the routing rule told them
      // apart by pattern — the player was being asked to sort by an attribute
      // the destination never showed. See docs/decision-log.md, "D-02".
      if (pattern != null) {
        fillPattern(canvas, path, Tokens.paper, pattern);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Tokens.paper,
      );
      return;
    }
    if (pattern != null) {
      final path = shapePath(PackageShape.square, rect);
      fillPattern(canvas, path, Tokens.paper, pattern);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Tokens.paper,
      );
    }
  }
}
