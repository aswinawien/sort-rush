import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../../core/routing.dart';
import '../../ui/theme.dart';
import '../package_painter.dart';
import '../sort_rush_game.dart';
import '../text_util.dart';

/// A destination chute. Large, bottom-anchored, and flush to the screen edge
/// on the outside so edge taps still register.
class BinComponent extends PositionComponent
    with TapCallbacks, HasGameReference<SortRushGame> {
  BinComponent({required this.index, required this.spec});

  final int index;
  final BinSpec spec;

  /// Positive while flashing a correct sort, negative while flashing a
  /// misroute. One field because the two can never overlap.
  double _flash = 0;
  double _shake = 0;

  void flashCorrect() => _flash = 1;

  void flashMisroute() {
    _flash = -1;
    _shake = 1;
  }

  @override
  void onTapDown(TapDownEvent event) {
    game.handleBinTap(index);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_flash > 0) {
      _flash -= dt * 5;
      if (_flash < 0) _flash = 0;
    } else if (_flash < 0) {
      _flash += dt * 5;
      if (_flash > 0) _flash = 0;
    }
    if (_shake > 0) {
      _shake -= dt * 6;
      if (_shake < 0) _shake = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    canvas.save();
    if (_shake > 0) {
      // 6px at full strength, per docs/design-spec.md §5.2.
      canvas.translate(_shake * 6 * (_shake > 0.5 ? 1 : -1), 0);
    }

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      const Radius.circular(6),
    );

    if (_flash != 0) {
      canvas.drawRRect(
        body,
        Paint()
          ..color = (_flash > 0 ? Tokens.acid : Tokens.warn)
              .withValues(alpha: 0.22 * _flash.abs()),
      );
    }

    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _flash > 0
            ? Tokens.acid
            : _flash < 0
                ? Tokens.warn
                : Tokens.paper,
    );

    final swatch = 34.0;
    PackagePainter.paintBinIdentity(
      canvas,
      Rect.fromCenter(
        center: Offset(w / 2, h / 2 - 8),
        width: swatch,
        height: swatch,
      ),
      shape: spec.shape,
      pattern: spec.pattern,
    );

    final letter = layoutText(spec.label, Tokens.label);
    letter.paint(
      canvas,
      Offset(w / 2 - letter.width / 2, h - letter.height - 8),
    );

    canvas.restore();
  }
}
