import 'dart:ui';

import 'package:flame/components.dart';

import '../../ui/theme.dart';
import '../sort_rush_game.dart';

/// The deadline. Turns to the warning colour when the front-most package is
/// about to cross it, so a drop is always something the player saw coming.
class SortLineComponent extends PositionComponent
    with HasGameReference<SortRushGame> {
  /// Seconds of warning before the sort line is crossed.
  static const double warnWindow = 0.4;

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
