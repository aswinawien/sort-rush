import 'package:flutter/material.dart';

import '../theme.dart';

/// Photocopy dot texture for **paper** surfaces.
///
/// Paper and machine are different materials in this game. `ScanLines` is the
/// CRT treatment and belongs on `ink`; a paper slip that carries scan lines has
/// been CRT-washed, which `docs/design-spec.md` §5.5 rules out by name. This is
/// the print-side equivalent: a regular halftone screen, the artefact of a
/// document that has been photocopied one too many times.
///
/// Positions come from a fixed grid, never from a random source, so the texture
/// is identical frame to frame and cannot strobe.
class Halftone extends StatelessWidget {
  const Halftone({
    super.key,
    this.spacing = 5,
    this.radius = 0.7,
    this.opacity = 0.06,
    this.color,
  });

  /// Grid pitch in logical pixels.
  final double spacing;

  final double radius;
  final double opacity;

  /// Defaults to `ink`, because a photocopy deposits toner on paper.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _HalftonePainter(
          spacing: spacing,
          radius: radius,
          opacity: opacity,
          color: color ?? Tokens.ink,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _HalftonePainter extends CustomPainter {
  const _HalftonePainter({
    required this.spacing,
    required this.radius,
    required this.opacity,
    required this.color,
  });

  final double spacing;
  final double radius;
  final double opacity;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || spacing <= 0) {
      return;
    }
    final paint = Paint()..color = color.withValues(alpha: opacity);
    var row = 0;
    for (var y = 0.0; y < size.height; y += spacing) {
      // Offset alternate rows, which is what makes it read as a printed
      // screen rather than as graph paper.
      final shift = row.isOdd ? spacing / 2 : 0.0;
      for (var x = shift; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
      row++;
    }
  }

  @override
  bool shouldRepaint(_HalftonePainter old) =>
      old.spacing != spacing ||
      old.radius != radius ||
      old.opacity != opacity ||
      old.color != color;
}

/// A small stamped serial, in the manner of a depot document.
///
/// Derived from real run values rather than invented: a fabricated reference
/// number would be a prop pretending to be a record.
class SerialStamp extends StatelessWidget {
  const SerialStamp({super.key, required this.text, this.tilt = -0.02});

  final String text;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tilt,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: Tokens.mute, width: 1),
        ),
        child: Text(
          text,
          style: Tokens.label.copyWith(fontSize: 9, color: Tokens.mute),
        ),
      ),
    );
  }
}
