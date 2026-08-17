import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/machine_intensity.dart';
import '../../ui/theme.dart';
import '../package_painter.dart';
import '../sort_rush_game.dart';

/// Renders every package currently on the belt.
///
/// Packages are drawn straight from engine state rather than being mirrored
/// into one component each. Keeping a component per package would mean
/// reconciling two lifecycles every frame for no visual gain, and a desync
/// between them would be a bug the player sees.
class BeltComponent extends PositionComponent
    with HasGameReference<SortRushGame> {
  static const double packageSize = 56;

  static final Paint _scanPaint = Paint()..strokeWidth = 1;

  @override
  void render(Canvas canvas) {
    final engine = game.engine;
    if (!game.reduceMotion) {
      final opacity = MachineIntensity.scanlineOpacity(
        engine.pressureProgress,
        engine.score.comboTier,
      );
      if (opacity > 0) {
        _scanPaint.color = Tokens.paper.withValues(alpha: opacity);
        for (var y = 0.0; y < size.y; y += 4) {
          canvas.drawLine(Offset(0, y), Offset(size.x, y), _scanPaint);
        }
      }
    }

    final front = engine.frontMost;

    for (final package in engine.active) {
      final centre = Offset(size.x / 2, package.progress * size.y);
      PackagePainter.paintPackage(
        canvas,
        Rect.fromCenter(
          center: centre,
          width: packageSize,
          height: packageSize,
        ),
        package.spec,
        isActive: identical(package, front),
        isUnstable: package.isUnstable,
      );
    }
  }
}
