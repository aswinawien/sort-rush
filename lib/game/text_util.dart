import 'package:flutter/painting.dart';

/// Lays out a string for drawing straight onto a `Canvas`.
///
/// Uses Flutter's `TextPainter` rather than Flame's text API so the in-canvas
/// HUD and the widget layer share one text stack and cannot render the same
/// copy two different ways.
TextPainter layoutText(
  String text,
  TextStyle style, {
  double maxWidth = double.infinity,
  TextAlign align = TextAlign.left,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: align,
  );
  painter.layout(maxWidth: maxWidth);
  return painter;
}
