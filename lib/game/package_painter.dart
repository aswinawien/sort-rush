import 'dart:ui';

import '../core/package_spec.dart';
import '../ui/theme.dart';

/// Drawing routines shared by packages on the belt and the identity swatch on
/// a bin, so the two can never drift out of sync visually.
///
/// Every hue is drawn through its paired pattern. Nothing here ever renders a
/// hue as a flat fill without its pattern.
abstract final class PackagePainter {
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
    final paint = Paint()..color = hue;

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
  }) {
    final path = shapePath(spec.shape, rect);
    fillPattern(canvas, path, Tokens.hues[spec.colorIndex], spec.pattern);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isActive ? 3.5 : 1.5
        ..color = isActive ? Tokens.acid : Tokens.paper,
    );

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

  /// Draws the identity swatch on a bin: a silhouette for shape-routed levels,
  /// a pattern swatch for colour-routed ones. Never an identifying fill colour.
  static void paintBinIdentity(
    Canvas canvas,
    Rect rect, {
    PackageShape? shape,
    FillPattern? pattern,
  }) {
    if (shape != null) {
      canvas.drawPath(
        shapePath(shape, rect),
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
