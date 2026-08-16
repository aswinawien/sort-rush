import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

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
  final _CachedText _comboText = _CachedText();
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

    if (_glitch > 0) {
      final ghost = _ghostText.layout(
        '${score.score}',
        scoreStyle.copyWith(color: Tokens.warn.withValues(alpha: 0.8)),
      );
      ghost.paint(canvas, Offset(16 + _glitch * 14, 10 - _glitch * 3));
    }

    final scoreText = _scoreText.layout('${score.score}', scoreStyle);
    scoreText.paint(canvas, const Offset(16, 10));

    final comboStyle = Tokens.label.copyWith(
      color: score.comboTier > 1 ? Tokens.acid : Tokens.mute,
      fontSize: 13 + _comboPulse * 3,
    );
    final combo = _comboText.layout('COMBO x${score.comboTier}', comboStyle);
    combo.paint(canvas, Offset(18, 12 + scoreText.height));

    _renderMistakes(canvas, score.mistakes);
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
