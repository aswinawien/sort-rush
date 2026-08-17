import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/daily_seed.dart';
import '../core/level_config.dart';
import '../core/levels.dart';
import '../core/run_engine.dart';
import '../core/run_summary.dart';
import 'play_screen.dart';
import 'results_screen.dart';
import 'theme.dart';
import 'widgets/fit_or_scroll.dart';
import 'widgets/scan_lines.dart';

/// Home carries the full zine treatment. The one rule it still owes the
/// player is that starting a run takes exactly one tap.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.showDevTools = kDebugMode});

  /// Debug jumps for UI review. Tests pass this explicitly — widget tests
  /// always run in debug, so they cannot rely on [kDebugMode] alone.
  final bool showDevTools;

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
                  const SizedBox(height: 22),
                  _EndlessRow(
                    onTap: () => _startLevel(
                      context,
                      kEndlessShift,
                      seed: dailySeed(),
                    ),
                  ),
                  if (showDevTools) ...[
                    const SizedBox(height: 22),
                    _DevJumpStrip(
                      onMemo: () => _jumpPlay(context, DevJump.memo),
                      onRoll: () => _jumpPlay(context, DevJump.roll),
                      onResultsPass: () => _jumpResults(context, passed: true),
                      onResultsFail: () => _jumpResults(context, passed: false),
                      onPause: () => _jumpPlay(context, DevJump.pause),
                    ),
                  ],
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startLevel(BuildContext context, LevelConfig level, {int? seed}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayScreen(level: level, seed: seed),
      ),
    );
  }

  void _jumpPlay(BuildContext context, DevJump jump) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayScreen(
          level: kEndlessShift,
          seed: 1,
          jump: jump,
        ),
      ),
    );
  }

  void _jumpResults(BuildContext context, {required bool passed}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultsScreen(
          summary: passed ? _devPassedSummary : _devFailedSummary,
          level: levelById(passed ? 3 : 2),
        ),
      ),
    );
  }
}

const RunSummary _devPassedSummary = RunSummary(
  levelId: 3,
  outcome: RunOutcome.passed,
  score: 240,
  sorted: 18,
  misrouted: 1,
  dropped: 0,
  bestCombo: 4,
);

const RunSummary _devFailedSummary = RunSummary(
  levelId: 2,
  outcome: RunOutcome.failed,
  score: 80,
  sorted: 6,
  misrouted: 3,
  dropped: 0,
  bestCombo: 2,
);

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

/// The way into endless.
///
/// Set apart from the numbered shifts rather than listed among them: it is a
/// different mode, not an eleventh lesson, and the product brief unlocks it
/// after onboarding. There is no persistence yet to gate on, so it is visible
/// from the start — recorded as interim in docs/decision-log.md.
class _EndlessRow extends StatelessWidget {
  const _EndlessRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Tokens.acid, width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kEndlessShift.title,
                    style: Tokens.body.copyWith(color: Tokens.acid),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text('TODAY · ${dailyStamp()}', style: Tokens.label),
                ],
              ),
            ),
            Text('▸', style: Tokens.label.copyWith(color: Tokens.acid)),
          ],
        ),
      ),
    );
  }
}

/// Mute, under the endless row, never on PUNCH IN. Release builds omit it.
class _DevJumpStrip extends StatelessWidget {
  const _DevJumpStrip({
    required this.onMemo,
    required this.onRoll,
    required this.onResultsPass,
    required this.onResultsFail,
    required this.onPause,
  });

  final VoidCallback onMemo;
  final VoidCallback onRoll;
  final VoidCallback onResultsPass;
  final VoidCallback onResultsFail;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DEV', style: Tokens.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _DevChip(label: 'MEMO', onTap: onMemo),
            _DevChip(label: 'ROLL', onTap: onRoll),
            _DevChip(
              label: 'RESULTS',
              onTap: onResultsPass,
              onLongPress: onResultsFail,
            ),
            _DevChip(label: 'PAUSE', onTap: onPause),
          ],
        ),
      ],
    );
  }
}

class _DevChip extends StatelessWidget {
  const _DevChip({
    required this.label,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Tokens.mute),
        ),
        child: Text(label, style: Tokens.label),
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
