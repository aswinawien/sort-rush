import 'package:flutter/material.dart';

import '../core/level_config.dart';
import '../core/levels.dart';
import 'play_screen.dart';
import 'theme.dart';
import 'widgets/fit_or_scroll.dart';
import 'widgets/scan_lines.dart';

/// Home carries the full zine treatment. The one rule it still owes the
/// player is that starting a run takes exactly one tap.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: ScanLines()),
          SafeArea(
            // Scrolls only when it has to. The spacers still do the work at
            // normal text sizes; past that the content grows and the view
            // scrolls instead of pushing PUNCH IN off the bottom. Without
            // this, a 320x568 phone at 2x text scale cannot start a run at
            // all — see docs/decision-log.md, "Home and briefing overflow".
            child: FitOrScroll(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 2),
                  const _MisregisteredTitle('SORT RUSH'),
                  const SizedBox(height: 12),
                  Text('DEPOT 7 · NIGHT SHIFT', style: Tokens.label),
                  const Spacer(flex: 2),
                  _PunchInButton(
                    onPressed: () => _startLevel(context, kCuratedLevels.first),
                  ),
                  const SizedBox(height: 28),
                  Text('SHIFTS', style: Tokens.label),
                  const SizedBox(height: 10),
                  for (final level in kCuratedLevels)
                    _ShiftRow(
                      level: level,
                      onTap: () => _startLevel(context, level),
                    ),
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startLevel(BuildContext context, LevelConfig level) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PlayScreen(level: level)),
    );
  }
}

/// Static offset rather than an animated one. Continuous motion behind the
/// primary call to action is a comprehension risk and a battery cost, so the
/// misregistration is printed once and left alone.
class _MisregisteredTitle extends StatelessWidget {
  const _MisregisteredTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final base = Tokens.display.copyWith(fontSize: 54, color: Tokens.paper);
    return Stack(
      children: [
        Transform.translate(
          offset: const Offset(-3, -2),
          child: Text(text, style: base.copyWith(color: Tokens.warn)),
        ),
        Transform.translate(
          offset: const Offset(3, 2),
          child: Text(text, style: base.copyWith(color: Tokens.acid)),
        ),
        Text(text, style: base),
      ],
    );
  }
}

class _PunchInButton extends StatelessWidget {
  const _PunchInButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Tokens.acid,
          foregroundColor: Tokens.ink,
          shape: const RoundedRectangleBorder(),
        ),
        child: Text(
          'PUNCH IN',
          style: Tokens.body.copyWith(
            color: Tokens.ink,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }
}

class _ShiftRow extends StatelessWidget {
  const _ShiftRow({required this.level, required this.onTap});

  final LevelConfig level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Text(
              level.id.toString().padLeft(2, '0'),
              style: Tokens.label.copyWith(color: Tokens.acid),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                level.title,
                style: Tokens.body,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text('▸', style: Tokens.label.copyWith(color: Tokens.acid)),
          ],
        ),
      ),
    );
  }
}
