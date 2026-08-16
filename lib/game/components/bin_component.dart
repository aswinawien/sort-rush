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

  /// The parts of a chute that never change: its identity swatch and its
  /// letter. Rebuilt only when the chute is resized.
  ///
  /// Measured before caching, three chutes cost 137us of a 333us frame — 41%
  /// — to redraw identical pixels sixty times a second, including a full text
  /// layout per chute per frame. See test/perf/render_cost_test.dart.
  Picture? _identity;
  double _identityWidth = -1;
  double _identityHeight = -1;

  /// Reused across frames; every property is set before each use.
  static final Paint _bodyPaint = Paint();

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
  void onRemove() {
    _identity?.dispose();
    _identity = null;
    super.onRemove();
  }

  /// Records the static layer once, so the per-frame path draws a cached
  /// picture instead of re-laying out text and re-walking the pattern loop.
  Picture _buildIdentity(double w, double h) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    const swatch = 34.0;
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

    return recorder.endRecording();
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    if (_identity == null || _identityWidth != w || _identityHeight != h) {
      _identity?.dispose();
      _identity = _buildIdentity(w, h);
      _identityWidth = w;
      _identityHeight = h;
    }

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
        _bodyPaint
          ..style = PaintingStyle.fill
          ..color = (_flash > 0 ? Tokens.acid : Tokens.warn)
              .withValues(alpha: 0.22 * _flash.abs()),
      );
    }

    canvas.drawRRect(
      body,
      _bodyPaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _flash > 0
            ? Tokens.acid
            : _flash < 0
                ? Tokens.warn
                : Tokens.paper,
    );

    canvas.drawPicture(_identity!);

    canvas.restore();
  }
}
