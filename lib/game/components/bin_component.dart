import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart';

import '../../core/routing.dart';
import '../../ui/theme.dart';
import '../../dev/dev_stats.dart';
import '../effects/chip_burst.dart';
import '../package_painter.dart';
import '../sort_rush_game.dart';
import '../text_util.dart';

/// A destination chute. Large, bottom-anchored, and flush to the screen edge
/// on the outside so edge taps still register.
class BinComponent extends PositionComponent
    with TapCallbacks, HasGameReference<SortRushGame> {
  BinComponent({required this.index, required BinSpec spec}) : _spec = spec;

  final int index;
  BinSpec _spec;

  BinSpec get spec => _spec;

  /// Swap the face without rebuilding the component. Endless lanes move.
  void adopt(BinSpec next) {
    if (next.label == _spec.label &&
        next.shape == _spec.shape &&
        next.pattern == _spec.pattern) {
      return;
    }
    _spec = next;
    _identity?.dispose();
    _identity = null;
  }

  bool warned = false;

  /// Positive while flashing a correct sort, negative while flashing a
  /// misroute. One field because the two can never overlap.
  double _flash = 0;
  double _shake = 0;

  /// Input acknowledgement, not outcome feedback.
  ///
  /// Fires on every press including a no-op on an empty belt, exactly as a
  /// physical button depresses whether or not it does anything. Deliberately
  /// neutral-coloured: `acid` means "correct" and `warn` means "you lost
  /// something", so neither may be spent on merely confirming a tap.
  double _press = 0;

  /// Strength of the press response, 1 at the tap and 0 at rest.
  ///
  /// Exposed so a test can prove the effect *ends*. It shipped without a decay
  /// and no pixel assertion caught it, because the only press test asserted
  /// that nothing threw.
  @visibleForTesting
  double get pressLevel => _press;

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

  /// At most one live burst per chute, so effect count is bounded by the
  /// number of chutes no matter how fast the player sorts.
  ChipBurst? _burst;

  void flashCorrect() {
    _flash = 1;
    if (game.reduceMotion) return;
    // Standard stays compact; neon gets the wake, the flash and the paper
    // fragments. Both resolve inside ~180ms and both are post-route: the
    // package is already off the belt before any of this is drawn.
    final spec = game.neon
        ? const ChipBurstSpec(
            count: 5,
            travel: 20,
            wakeLength: 34,
            fragments: 4,
            flash: 0.5,
          )
        : const ChipBurstSpec(travel: 16);
    // Replacing a live burst retires it first, so the count cannot drift
    // upward when the player sorts faster than a burst lives.
    if (kDevTools && _burst != null) {
      DevStats.removeBurst(_burst!.spec.pieceCount);
    }
    _burst = ChipBurst(
      origin: Offset(size.x / 2, 2),
      color: Tokens.acid,
      spec: spec,
    );
    if (kDevTools) {
      DevStats.addBurst(spec.pieceCount);
    }
  }

  void flashMisroute() {
    _flash = -1;
    _shake = 1;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!game.reduceMotion) {
      _press = 1;
    }
    game.handleBinTap(index);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final burst = _burst;
    if (burst != null) {
      burst.update(dt);
      if (burst.isDone) {
        _burst = null;
        if (kDevTools) {
          DevStats.removeBurst(burst.spec.pieceCount);
        }
      }
    }
    if (_flash > 0) {
      _flash -= dt * 2.5;
      if (_flash < 0) _flash = 0;
    } else if (_flash < 0) {
      _flash += dt * 2.5;
      if (_flash > 0) _flash = 0;
    }
    if (_shake > 0) {
      _shake -= dt * 3;
      if (_shake < 0) _shake = 0;
    }
    if (_press > 0) {
      // ~110ms, inside the 80-140ms the press response is specified at.
      _press -= dt * 9;
      if (_press < 0) _press = 0;
    }
  }

  @override
  void onRemove() {
    // A run ends on the same frame that emits its last sort, so a live burst
    // is the common case here, not an edge one. Without this the static
    // counter drifts upward for the whole process and the profiler's "did it
    // return to baseline" signal is worthless from run two onward.
    final burst = _burst;
    if (kDevTools && burst != null) {
      DevStats.removeBurst(burst.spec.pieceCount);
    }
    _burst = null;
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
    if (_press > 0) {
      // Compress toward the lip, so the chute reads as taking the press.
      final squash = 1 - _press * 0.028;
      canvas.translate(w / 2, 0);
      canvas.scale(1, squash);
      canvas.translate(-w / 2, 0);
    }
    if (_shake > 0) {
      // A misroute has to be felt. The spec's 6px was set before anything
      // ran on a real screen and read as no movement at all.
      canvas.translate(_shake * 16 * (_shake > 0.5 ? 1 : -1), 0);
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
              .withValues(alpha: 0.45 * _flash.abs()),
      );
    }

    canvas.drawRRect(
      body,
      _bodyPaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = warned
            ? Tokens.warn
            : _flash > 0
                ? Tokens.acid
                : _flash < 0
                    ? Tokens.warn
                    : Tokens.paper,
    );

    if (_press > 0 && _flash == 0) {
      // Two short registration marks at the lip. Mute, never acid: this says
      // "registered", not "correct".
      final mark = Paint()
        ..color = Tokens.mute.withValues(alpha: 0.85 * _press)
        ..strokeWidth = 2;
      const inset = 14.0;
      canvas.drawLine(Offset(inset, 3), Offset(inset + 12, 3), mark);
      canvas.drawLine(Offset(w - inset - 12, 3), Offset(w - inset, 3), mark);
    }

    canvas.drawPicture(_identity!);

    // Last, so chips sit over the chute face.
    //
    // These do reach above the chute lip — the neon wake by ~24px — so the
    // claim is not that they stay below it. It is that the belt is never
    // occupied that low: a package needs progress > 0.90 to enter the band,
    // and the 0.65s spawn floor against the live read window keeps the
    // following package further back. Narrow that gap and this needs redoing.
    _burst?.render(canvas);

    canvas.restore();
  }
}
