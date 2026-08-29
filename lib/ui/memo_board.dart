import 'dart:async';

import 'package:flutter/material.dart';

import '../core/run_engine.dart';
import '../core/shop.dart';
import 'memo/memo_transition.dart';
import 'memo/memo_variant.dart';
import 'theme.dart';
import 'visual_style.dart';
import 'widgets/halftone.dart';
import 'widgets/scan_lines.dart';

/// Mid-run depot board. Flutter overlay, 60% zine. Core still owns buy/skip.
class MemoBoard extends StatefulWidget {
  const MemoBoard({
    super.key,
    required this.engine,
    required this.onClosed,
    this.variant = MemoVariant.shop,
  });

  final RunEngine engine;
  final VoidCallback onClosed;

  /// Which presentation the board wears. The endless shop is the only caller
  /// today; the other five are reachable from the Dev Lab and from future
  /// memo kinds without a second overlay.
  final MemoVariant variant;

  @override
  State<MemoBoard> createState() => _MemoBoardState();
}

class _MemoBoardState extends State<MemoBoard> {
  RunEngine get engine => widget.engine;

  /// Latched the instant a choice is committed.
  ///
  /// The engine mutation happens immediately; only the *visual* close is
  /// animated. Without this latch a second tap during the exit would spend
  /// `PAY` twice, because the slips are still mounted while the paper
  /// retracts.
  bool _closing = false;

  void _pin(int index) {
    if (_closing) {
      return;
    }
    if (engine.buy(index)) {
      setState(() => _closing = true);
    }
  }

  void _walkOn() {
    if (_closing) {
      return;
    }
    engine.skipShop();
    setState(() => _closing = true);
  }

  @override
  Widget build(BuildContext context) {
    final profile = VisualProfile.of(context);
    final reduce = profile.reduceMotion;
    final offers = engine.shopOffers;
    return Positioned.fill(
      child: Stack(
        children: [
          const ModalBarrier(color: Tokens.ink, dismissible: false),
          // The wall is the machine and may carry the neon. The slips stay
          // paper — docs/design-spec.md §5.5, "do not CRT-wash the memos".
          if (!reduce) ScanLines(opacity: profile.neon ? 0.09 : 0.04),
          if (profile.neon && !reduce) const _NeonWipe(),
          if (!reduce)
            const IgnorePointer(
              child: CustomPaint(
                  painter: _OffsetRulePainter(), size: Size.infinite),
            ),
          MemoTransition(
            variant: widget.variant,
            closing: _closing,
            onClosed: widget.onClosed,
            child: SafeArea(
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
                    if (engine.pendingEvent case final event?) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${event.title} · ${event.body}',
                        key: const Key('shift-event-line'),
                        style: Tokens.label.copyWith(color: Tokens.paper),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Expanded(
                      child: ListView(
                        children: [
                          for (var i = 0; i < offers.length; i++)
                            _Staggered(
                              index: i,
                              enabled: profile.sequentialReveal,
                              child: _MemoSlip(
                                card: offers[i],
                                tilt: const [-0.025, 0.02, -0.015][i % 3],
                                affordable: engine.score.pay >= offers[i].cost,
                                stamped: profile.neon,
                                halftone: profile.neon,
                                onPin: () => _pin(i),
                              ),
                            ),
                        ],
                      ),
                    ),
                    _AskAgainTab(
                      cost: engine.redrawCost,
                      affordable: engine.score.pay >= engine.redrawCost,
                      onPressed: () {
                        // The slips unmount on a buy but this tab does not,
                        // and the exit leaves it hit-testable. It was saved
                        // only by RunEngine's phase guard — a latch with a
                        // hole in it is not a latch.
                        if (_closing) {
                          return;
                        }
                        if (engine.redrawShop()) {
                          setState(() {});
                        }
                      },
                    ),
                    _WalkOnTab(onPressed: _walkOn),
                  ],
                ),
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
    this.stamped = false,
    this.halftone = false,
  });

  final CardSpec card;
  final double tilt;
  final bool affordable;
  final VoidCallback onPin;

  /// Neon only: the cost prints in like a stamp rather than simply being there.
  final bool stamped;

  /// Photocopy grain on the slip. A print artefact, not a CRT one — the slips
  /// stay paper however loud the wall behind them gets.
  final bool halftone;

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
                  if (halftone)
                    const Positioned.fill(
                      child: Halftone(spacing: 4, radius: 0.6, opacity: 0.07),
                    ),
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
                          child: _CostStamp(
                            cost: card.cost,
                            color: affordable ? Tokens.ink : Tokens.warn,
                            stamped: stamped,
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

class _AskAgainTab extends StatelessWidget {
  const _AskAgainTab({
    required this.cost,
    required this.affordable,
    required this.onPressed,
  });

  final int cost;
  final bool affordable;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = affordable ? Tokens.mute : Tokens.warn;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: TextButton(
          onPressed: affordable ? onPressed : null,
          style: TextButton.styleFrom(
            foregroundColor: color,
            shape: const RoundedRectangleBorder(),
          ),
          child: Text(
            'ASK AGAIN  ·  COST $cost',
            style: Tokens.label.copyWith(color: color),
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
    canvas.drawRect(
        Rect.fromLTWH(6, 6, size.width - 12, size.height - 12), paint);
    paint.color = Tokens.acid.withValues(alpha: 0.12);
    canvas.drawRect(
        Rect.fromLTWH(8, 4, size.width - 12, size.height - 12), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Prints a slip in after a short per-index delay.
///
/// Neon only. Standard and reduce-motion resolve instantly, because a stagger
/// that delays interaction is exactly what the brief rules out there — the
/// slips must be tappable the moment they are visible.
class _Staggered extends StatefulWidget {
  const _Staggered({
    required this.index,
    required this.enabled,
    required this.child,
  });

  final int index;
  final bool enabled;
  final Widget child;

  @override
  State<_Staggered> createState() => _StaggeredState();
}

class _StaggeredState extends State<_Staggered>
    with SingleTickerProviderStateMixin {
  static const Duration step = Duration(milliseconds: 70);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) {
      _controller.value = 1;
      return;
    }
    _timer = Timer(step * widget.index, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset((1 - t) * 22, 0),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// `COST N`, with a one-shot press on arrival in neon.
class _CostStamp extends StatefulWidget {
  const _CostStamp({
    required this.cost,
    required this.color,
    required this.stamped,
  });

  final int cost;
  final Color color;
  final bool stamped;

  @override
  State<_CostStamp> createState() => _CostStampState();
}

class _CostStampState extends State<_CostStamp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: widget.stamped ? 0 : 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.stamped) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = Text(
      'COST ${widget.cost}',
      style: Tokens.label.copyWith(color: widget.color),
    );
    if (!widget.stamped) {
      return label;
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Lands from slightly oversized, like a stamp coming down. Never
        // below 1, so the text never shrinks out of readability.
        final t = Curves.easeOutBack.transform(_controller.value);
        return Transform.scale(scale: 1 + (1 - t) * 0.35, child: child);
      },
      child: label,
    );
  }
}

/// A thin acid line crossing the wall once, behind the paper.
///
/// Wall only. It never touches the slips, and it fires once on entry rather
/// than looping — a repeating sweep behind a decision screen is the CRT
/// screensaver the design system rules out.
class _NeonWipe extends StatefulWidget {
  const _NeonWipe();

  @override
  State<_NeonWipe> createState() => _NeonWipeState();
}

class _NeonWipeState extends State<_NeonWipe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _WipePainter(_controller.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _WipePainter extends CustomPainter {
  const _WipePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) {
      return;
    }
    final y = size.height * Curves.easeOutCubic.transform(t);
    final fade = 1 - t;
    canvas.drawRect(
      Rect.fromLTWH(0, y, size.width, 2),
      Paint()..color = Tokens.acid.withValues(alpha: 0.5 * fade),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, y + 2, size.width, 26),
      Paint()..color = Tokens.acid.withValues(alpha: 0.07 * fade),
    );
  }

  @override
  bool shouldRepaint(_WipePainter old) => old.t != t;
}
