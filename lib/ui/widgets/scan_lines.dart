import 'package:flutter/material.dart';

import '../theme.dart';

/// Faint horizontal rules over a surface. Part of the zine treatment on Home
/// and Results only — the play field gets none of this.
class ScanLines extends StatelessWidget {
  const ScanLines({super.key, this.spacing = 4, this.opacity = 0.05});

  final double spacing;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ScanLinePainter(spacing: spacing, opacity: opacity),
        size: Size.infinite,
      ),
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  const _ScanLinePainter({required this.spacing, required this.opacity});

  final double spacing;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Tokens.paper.withValues(alpha: opacity)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanLinePainter oldDelegate) =>
      oldDelegate.spacing != spacing || oldDelegate.opacity != opacity;
}
