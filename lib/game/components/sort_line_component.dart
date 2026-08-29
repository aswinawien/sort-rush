import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/run_engine.dart';
import '../../ui/theme.dart';
import '../sort_rush_game.dart';

/// The deadline. Turns to the warning colour when the front-most package is
/// about to cross it, so a drop is always something the player saw coming.
///
/// Aligned with [RunEngine.clutchWindow]: the colour flip and the clutch
/// save are the same moment. The painted band on the belt is the spatial
/// version of this same window.
class SortLineComponent extends PositionComponent
    with HasGameReference<SortRushGame> {
  /// Seconds of warning before the sort line is crossed.
  ///
  /// Same instant as a clutch save. Do not re-literal 0.5 here.
  static const double warnWindow = RunEngine.clutchWindow;

  @override
  void render(Canvas canvas) {
    final remaining = game.engine.timeToLine;
    final urgent = remaining != null && remaining <= warnWindow;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = urgent ? Tokens.warn : Tokens.mute,
    );
  }
}
