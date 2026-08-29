import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../core/machine_intensity.dart';
import '../../ui/theme.dart';
import '../sort_rush_game.dart';
import '../text_util.dart';

/// Score, combo, and mistake pips.
///
/// Lives inside the Flame canvas rather than in a widget overlay so that
/// feedback in the score region is frame-synced with feedback at the bin. The
/// design requires both to land together; a widget rebuild cannot guarantee
/// that.
/// Holds one laid-out `TextPainter` and re-lays it only when what it draws
/// actually changes.
///
/// Text shaping is the most expensive thing this HUD does, and the score
/// string changes a few times a second while the frame rate is sixty. Only
/// the pulse animations vary continuously, and then only briefly.
class _CachedText {
  TextPainter? _painter;
  String? _text;
  double? _fontSize;
  Color? _color;

  TextPainter layout(String text, TextStyle style) {
    final painter = _painter;
    if (painter != null &&
        _text == text &&
        _fontSize == style.fontSize &&
        _color == style.color) {
      return painter;
    }
    _text = text;
    _fontSize = style.fontSize;
    _color = style.color;
    return _painter = layoutText(text, style);
  }
}

class HudComponent extends PositionComponent
    with HasGameReference<SortRushGame> {
  /// Space reserved at the right edge for the Flutter pause button that sits
  /// over the canvas. Without it the mistake pips and the level-1 notice draw
  /// underneath the icon.
  static const double rightInset = 56;

  final _CachedText _ghostText = _CachedText();
  final _CachedText _scoreText = _CachedText();
  final _CachedText _scoreCyan = _CachedText();
  final _CachedText _scoreMagenta = _CachedText();
  final _CachedText _comboText = _CachedText();
  final _CachedText _comboCyan = _CachedText();
  final _CachedText _comboMagenta = _CachedText();
  final _CachedText _payText = _CachedText();
  final _CachedText _chipText = _CachedText();
  final _CachedText _noticeText = _CachedText();

  /// Reused across pips and frames. Every property is set on each use.
  static final Paint _pipPaint = Paint()..strokeWidth = 1.5;

  double _scorePulse = 0;
  double _comboPulse = 0;

  /// Drives the channel offset on error.
  ///
  /// Widened and slowed on 2026-08-17: at a 3px offset decaying in 167ms it
  /// was imperceptible, which meant the play field's whole experimentation
  /// budget was being spent on feedback nobody could see. A misroute is the
  /// single most important thing to communicate — Gate 3 approved play-field
  /// effects that carry information, and this carries the most.
  double _glitch = 0;

  void pulseScore() => _scorePulse = 1;

  void pulseCombo() => _comboPulse = 1;

  void glitch() => _glitch = 1;

  @override
  void update(double dt) {
    super.update(dt);
    if (_scorePulse > 0) {
      _scorePulse -= dt * 4;
      if (_scorePulse < 0) _scorePulse = 0;
    }
    if (_comboPulse > 0) {
      _comboPulse -= dt * 3;
      if (_comboPulse < 0) _comboPulse = 0;
    }
    if (_glitch > 0) {
      _glitch -= dt * 2.5;
      if (_glitch < 0) _glitch = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    final engine = game.engine;
    final score = engine.score;

    final scoreStyle = Tokens.display.copyWith(
      fontSize: 44 + _scorePulse * 6,
    );

    const scoreOrigin = Offset(16, 10);
    final split = game.reduceMotion
        ? 0.0
        : MachineIntensity.comboSplitPx(score.comboTier);

    if (_glitch > 0) {
      // A mistake owns the score for a beat — warn ghost, not the roll split.
      final ghost = _ghostText.layout(
        '${score.score}',
        scoreStyle.copyWith(color: Tokens.warn.withValues(alpha: 0.8)),
      );
      ghost.paint(canvas, Offset(16 + _glitch * 14, 10 - _glitch * 3));
    } else if (split > 0) {
      _scoreCyan
          .layout(
            '${score.score}',
            scoreStyle.copyWith(color: Tokens.hues[0].withValues(alpha: 0.7)),
          )
          .paint(canvas, scoreOrigin.translate(-split, 0));
      _scoreMagenta
          .layout(
            '${score.score}',
            scoreStyle.copyWith(color: Tokens.hues[1].withValues(alpha: 0.7)),
          )
          .paint(canvas, scoreOrigin.translate(split, 0));
    }

    final scoreText = _scoreText.layout('${score.score}', scoreStyle);
    scoreText.paint(canvas, scoreOrigin);

    final comboStyle = Tokens.label.copyWith(
      color: score.comboTier > 1 ? Tokens.acid : Tokens.mute,
      fontSize: 13 + _comboPulse * 3,
    );
    // At the ceiling the tier stops being a number. `MAXXXX` is the whole
    // reward for fifty consecutive clean sorts — the payout is flat up here
    // (`RunScore.centsPerTier`), so this is what the streak buys.
    final comboLabel =
        score.isMaxxxx ? 'MAXXXX' : 'COMBO x${score.comboTier}';
    final comboOrigin = Offset(18, 12 + scoreText.height);
    if (split > 0) {
      _comboCyan
          .layout(
            comboLabel,
            comboStyle.copyWith(color: Tokens.hues[0].withValues(alpha: 0.7)),
          )
          .paint(canvas, comboOrigin.translate(-split, 0));
      _comboMagenta
          .layout(
            comboLabel,
            comboStyle.copyWith(color: Tokens.hues[1].withValues(alpha: 0.7)),
          )
          .paint(canvas, comboOrigin.translate(split, 0));
    }
    final combo = _comboText.layout(comboLabel, comboStyle);
    combo.paint(canvas, comboOrigin);

    if (engine.level.curve != null) {
      final barY = 12 + scoreText.height + combo.height + 8;
      _renderPressure(canvas, 18, barY);
      _renderPay(canvas, 18, barY + 10, engine.score.pay);
      _renderPins(canvas, 18, barY + 26);
    }

    _renderMistakes(canvas, score.mistakes);
  }

  void _renderPressure(Canvas canvas, double x, double y) {
    const width = 88.0;
    const height = 3.0;
    final fill = game.engine.pressureProgress.clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTWH(x, y, width, height),
      _pipPaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Tokens.mute,
    );
    if (fill > 0) {
      canvas.drawRect(
        Rect.fromLTWH(x, y, width * fill, height),
        _pipPaint
          ..style = PaintingStyle.fill
          ..color = Tokens.acid,
      );
    }
  }

  void _renderPay(Canvas canvas, double x, double y, int pay) {
    final payText = _payText.layout('PAY $pay', Tokens.label);
    payText.paint(canvas, Offset(x, y));
  }

  void _renderPins(Canvas canvas, double x, double y) {
    final event = game.engine.liveEvent;
    final pinned = game.engine.pinned;
    if (event == null && pinned.isEmpty) {
      return;
    }
    final memoSlots = event == null ? 3 : 2;
    final overflow = pinned.length > memoSlots;
    final shown = overflow
        ? pinned.take(memoSlots > 1 ? memoSlots - 1 : 0)
        : pinned.take(memoSlots);
    var cursor = x;
    const gap = 6.0;
    const pad = 5.0;
    final chipStyle = Tokens.label.copyWith(
      color: Tokens.ink,
      fontSize: 10,
      letterSpacing: 1,
    );
    if (event != null) {
      cursor = _paintChip(
        canvas,
        cursor,
        y,
        event.chip,
        chipStyle,
        pad,
        acidBorder: true,
      );
      cursor += gap;
    }
    for (final card in shown) {
      cursor = _paintChip(canvas, cursor, y, card.chip, chipStyle, pad);
      cursor += gap;
    }
    if (overflow) {
      final hidden = pinned.length - shown.length;
      final more = _chipText.layout('·$hidden', chipStyle);
      more.paint(canvas, Offset(cursor, y + pad / 2));
    }
  }

  double _paintChip(
    Canvas canvas,
    double x,
    double y,
    String chip,
    TextStyle chipStyle,
    double pad, {
    bool acidBorder = false,
  }) {
    final label = _chipText.layout(chip, chipStyle);
    final width = label.width + pad * 2;
    final height = label.height + pad;
    final rect = Rect.fromLTWH(x, y, width, height);
    canvas.drawRect(
      rect,
      _pipPaint
        ..style = PaintingStyle.fill
        ..color = Tokens.paper,
    );
    if (acidBorder) {
      canvas.drawRect(
        rect,
        _pipPaint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Tokens.acid,
      );
    }
    label.paint(canvas, Offset(x + pad, y + pad / 2));
    return x + width;
  }

  void _renderMistakes(Canvas canvas, int mistakes) {
    // Read from the engine, not the level: a run's mistake limit can move,
    // and pips showing a stale number would be showing a lie.
    final limit = game.engine.tuning.mistakeLimit;
    if (limit == null) {
      // Level 1 cannot be failed, so showing empty pips would imply a threat
      // that does not exist.
      final note = _noticeText.layout('NO PENALTY', Tokens.label);
      note.paint(canvas, Offset(size.x - note.width - rightInset, 16));
      return;
    }

    const radius = 6.0;
    const gap = 18.0;
    for (var i = 0; i < limit; i++) {
      final spent = i < mistakes;
      final centre =
          Offset(size.x - rightInset - radius - (limit - 1 - i) * gap, 22);
      canvas.drawCircle(
        centre,
        radius,
        _pipPaint
          ..style = spent ? PaintingStyle.fill : PaintingStyle.stroke
          ..color = spent ? Tokens.warn : Tokens.mute,
      );
    }
  }
}
