import 'package:flutter/material.dart';

import '../core/run_engine.dart';
import '../core/shop.dart';
import 'theme.dart';
import 'widgets/scan_lines.dart';

/// Mid-run depot board. Flutter overlay, 60% zine. Core still owns buy/skip.
class MemoBoard extends StatelessWidget {
  const MemoBoard({
    super.key,
    required this.engine,
    required this.onClosed,
  });

  final RunEngine engine;
  final VoidCallback onClosed;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final offers = engine.shopOffers;
    return Positioned.fill(
      child: Stack(
        children: [
          const ModalBarrier(color: Tokens.ink, dismissible: false),
          if (!reduce) const ScanLines(opacity: 0.04),
          if (!reduce)
            const IgnorePointer(
              child: CustomPaint(painter: _OffsetRulePainter(), size: Size.infinite),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Tokens.acid, width: 1.5),
                        ),
                        child: Text(
                          'DEPOT MEMO',
                          style: Tokens.label.copyWith(color: Tokens.acid),
                        ),
                      ),
                      const Spacer(),
                      Transform.rotate(
                        angle: 0.04,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          color: Tokens.paper,
                          child: Text(
                            'PAY ${engine.score.pay}',
                            style: Tokens.label.copyWith(color: Tokens.ink),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _MisregisteredHeadline(
                    'PIN ONE. OR WALK ON.',
                    reduce: reduce,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      children: [
                        for (var i = 0; i < offers.length; i++)
                          _MemoSlip(
                            card: offers[i],
                            tilt: const [-0.025, 0.02, -0.015][i % 3],
                            affordable: engine.score.pay >= offers[i].cost,
                            onPin: () {
                              if (engine.buy(i)) {
                                onClosed();
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                  _WalkOnTab(
                    onPressed: () {
                      engine.skipShop();
                      onClosed();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MisregisteredHeadline extends StatelessWidget {
  const _MisregisteredHeadline(this.text, {required this.reduce});

  final String text;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final style = Tokens.display.copyWith(fontSize: 26, color: Tokens.paper);
    if (reduce) {
      return Text(text, style: style);
    }
    return Stack(
      children: [
        Transform.translate(
          offset: const Offset(-2, 0),
          child: Text(
            text,
            style: style.copyWith(
              color: Tokens.hues[0].withValues(alpha: 0.7),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(2, 0),
          child: Text(
            text,
            style: style.copyWith(
              color: Tokens.hues[1].withValues(alpha: 0.7),
            ),
          ),
        ),
        Text(text, style: style),
      ],
    );
  }
}

class _MemoSlip extends StatelessWidget {
  const _MemoSlip({
    required this.card,
    required this.tilt,
    required this.affordable,
    required this.onPin,
  });

  final CardSpec card;
  final double tilt;
  final bool affordable;
  final VoidCallback onPin;

  @override
  Widget build(BuildContext context) {
    final ink = affordable ? Tokens.ink : Tokens.mute;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Transform.rotate(
        angle: tilt,
        child: Material(
          color: Tokens.paper,
          child: InkWell(
            onTap: affordable ? onPin : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 12, 14, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card.title,
                                style: Tokens.body.copyWith(
                                  color: ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                card.body,
                                style: Tokens.label.copyWith(color: ink),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: affordable ? Tokens.ink : Tokens.warn,
                            ),
                          ),
                          child: Text(
                            'COST ${card.cost}',
                            style: Tokens.label.copyWith(
                              color: affordable ? Tokens.ink : Tokens.warn,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: affordable ? Tokens.acid : Tokens.mute,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WalkOnTab extends StatelessWidget {
  const _WalkOnTab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Tokens.mute,
          shape: const RoundedRectangleBorder(),
        ),
        child: CustomPaint(
          painter: const _PerforationPainter(),
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'WALK ON',
              style: Tokens.body.copyWith(
                color: Tokens.mute,
                letterSpacing: 3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PerforationPainter extends CustomPainter {
  const _PerforationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Tokens.mute
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dash = 4.0;
    var x = 0.0;
    const y = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
      x += dash * 2;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OffsetRulePainter extends CustomPainter {
  const _OffsetRulePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Tokens.paper.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(Rect.fromLTWH(6, 6, size.width - 12, size.height - 12), paint);
    paint.color = Tokens.acid.withValues(alpha: 0.12);
    canvas.drawRect(Rect.fromLTWH(8, 4, size.width - 12, size.height - 12), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
