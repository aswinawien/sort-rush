import 'dart:async';

import 'package:flutter/material.dart';

import '../core/level_config.dart';
import '../core/levels.dart';
import '../core/run_summary.dart';
import 'play_screen.dart';
import 'theme.dart';
import 'widgets/scan_lines.dart';

/// The run report, printed like a dot-matrix shipping manifest.
///
/// Characters type out on a fixed cadence — no `dart:math` Random, no
/// per-frame jitter. Tap skips. Reduce-motion prints the whole slip at once.
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({
    super.key,
    required this.summary,
    required this.level,
  });

  final RunSummary summary;
  final LevelConfig level;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  static const Duration _tick = Duration(milliseconds: 24);
  static const Duration _cursorPeriod = Duration(milliseconds: 500);
  static const int _pauseTicks = 8;

  late final List<String> _lines = _buildLines();
  Timer? _timer;
  Timer? _cursorTimer;
  bool _bootstrapped = false;
  bool _complete = false;
  bool _cursorOn = true;
  int _lineIndex = 0;
  int _charIndex = 0;
  int _pauseLeft = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) {
      return;
    }
    _bootstrapped = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _finishPrint();
      return;
    }
    _timer = Timer.periodic(_tick, _onTick);
    _cursorTimer = Timer.periodic(_cursorPeriod, (_) {
      if (!mounted || _complete) {
        return;
      }
      setState(() => _cursorOn = !_cursorOn);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  List<String> _buildLines() {
    final summary = widget.summary;
    return [
      summary.passed ? 'SHIFT COMPLETE' : 'SHIFT ENDED',
      'SHIFT ${summary.levelId.toString().padLeft(2, '0')}  ${widget.level.title}',
      '',
      'SORTED        ${summary.sorted}',
      'MISROUTED     ${summary.misrouted}',
      'DROPPED       ${summary.dropped}',
      if (summary.endless) ...[
        'HAZARD PAY    x${summary.bestCombo}',
        'INCIDENTS     ${summary.misrouted + summary.dropped}',
        'RATE          ${summary.rate}%',
        'PAY           ${summary.pay}',
      ] else ...[
        'BEST COMBO    x${summary.bestCombo}',
      ],
      '--------------------------',
      'SCORE         ${summary.postedScore}',
    ];
  }

  void _onTick(Timer timer) {
    if (_complete) {
      timer.cancel();
      return;
    }
    if (_pauseLeft > 0) {
      setState(() => _pauseLeft--);
      return;
    }
    if (_lineIndex >= _lines.length) {
      setState(_finishPrint);
      return;
    }
    final line = _lines[_lineIndex];
    if (_charIndex < line.length) {
      setState(() => _charIndex++);
      return;
    }
    if (_lineIndex + 1 >= _lines.length) {
      setState(_finishPrint);
      return;
    }
    setState(() {
      _lineIndex++;
      _charIndex = 0;
      _pauseLeft = _pauseTicks;
    });
  }

  void _finishPrint() {
    _timer?.cancel();
    _cursorTimer?.cancel();
    _complete = true;
    _lineIndex = _lines.length;
    _charIndex = 0;
    _cursorOn = false;
  }

  void _skip() {
    if (_complete) {
      return;
    }
    setState(_finishPrint);
  }

  LevelConfig? get _nextLevel {
    // Endless has no next shift, and its id of 0 would otherwise resolve to
    // shift 1 and offer to send the player back to the tutorial.
    if (widget.summary.endless) {
      return null;
    }
    final nextId = widget.summary.levelId + 1;
    for (final level in kCuratedLevels) {
      if (level.id == nextId) {
        return level;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final next = _nextLevel;

    return Scaffold(
      backgroundColor: Tokens.paper,
      body: Stack(
        children: [
          const Positioned.fill(child: ScanLines(opacity: 0.06)),
          SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The manifest scrolls rather than pushing the actions off
                    // a short screen. Restarting must never become unreachable.
                    Expanded(
                      child: IgnorePointer(
                        ignoring: !_complete,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              ..._typedLines(),
                              const SizedBox(height: 24),
                              if (_complete)
                                _VerdictStamp(text: summary.verdict),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_complete) ...[
                      if (summary.passed && next != null)
                        _ManifestButton(
                          label: 'NEXT SHIFT',
                          emphasised: true,
                          onPressed: () => _replaceWith(next),
                        ),
                      if (summary.passed &&
                          !summary.endless &&
                          !summary.wagered)
                        _ManifestButton(
                          label: 'DOUBLE OR NOTHING',
                          emphasised: false,
                          onPressed: () => _replaceWith(
                            widget.level,
                            wager: true,
                          ),
                        ),
                      _ManifestButton(
                        label: 'CLOCK BACK IN',
                        emphasised: !summary.passed,
                        onPressed: () => _replaceWith(
                          widget.level,
                          seed: summary.endless ? summary.seed : null,
                        ),
                      ),
                      _ManifestButton(
                        label: 'HOME',
                        emphasised: false,
                        onPressed: () => Navigator.of(context)
                            .popUntil((route) => route.isFirst),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (!_complete)
            Positioned.fill(
              key: const Key('skip-manifest'),
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => _skip(),
                child: const ColoredBox(color: Color(0x00000000)),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _typedLines() {
    final out = <Widget>[];
    final last = _complete ? _lines.length : _lineIndex;
    for (var i = 0; i < last; i++) {
      out.add(_lineView(i, _lines[i], cursor: false));
    }
    if (!_complete && _lineIndex < _lines.length) {
      out.add(
        _lineView(
          _lineIndex,
          _lines[_lineIndex].substring(0, _charIndex),
          cursor: true,
        ),
      );
    }
    return out;
  }

  Widget _lineView(int index, String text, {required bool cursor}) {
    final display = index == 0;
    final style = display
        ? Tokens.display.copyWith(color: Tokens.ink, fontSize: 34)
        : Tokens.body.copyWith(color: Tokens.ink);
    final pad = EdgeInsets.only(
      bottom: display
          ? 8
          : index == 1
              ? 28
              : 0,
    );
    return Padding(
      padding: pad,
      child: Text.rich(
        TextSpan(
          style: style,
          children: [
            TextSpan(text: text),
            if (cursor)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Opacity(
                    opacity: _cursorOn ? 1 : 0,
                    child: ColoredBox(
                      color: Tokens.ink,
                      child: SizedBox(
                        width: display ? 12 : 8,
                        height: display ? 28 : 16,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _replaceWith(LevelConfig level, {int? seed, bool wager = false}) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PlayScreen(level: level, seed: seed, wager: wager),
      ),
    );
  }
}

class _VerdictStamp extends StatelessWidget {
  const _VerdictStamp({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.06,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Tokens.warn, width: 2.5),
        ),
        child: Text(
          text,
          style: Tokens.label.copyWith(
            color: Tokens.warn,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ManifestButton extends StatelessWidget {
  const _ManifestButton({
    required this.label,
    required this.emphasised,
    required this.onPressed,
  });

  final String label;
  final bool emphasised;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: emphasised ? Tokens.ink : Tokens.paper,
            foregroundColor: emphasised ? Tokens.paper : Tokens.ink,
            side: const BorderSide(color: Tokens.ink, width: 2),
            shape: const RoundedRectangleBorder(),
          ),
          child: Text(
            label,
            style: Tokens.body.copyWith(
              color: emphasised ? Tokens.paper : Tokens.ink,
              letterSpacing: 3,
            ),
          ),
        ),
      ),
    );
  }
}
