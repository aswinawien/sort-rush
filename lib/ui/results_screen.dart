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
/// The printing is skippable on tap. A player restarting for the fifth time
/// must never be made to sit through it.
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
  static const Duration _lineInterval = Duration(milliseconds: 40);

  late final List<String> _lines = _buildLines();
  Timer? _timer;
  int _revealed = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_lineInterval, (timer) {
      if (_revealed >= _lines.length) {
        timer.cancel();
        return;
      }
      setState(() => _revealed++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<String> _buildLines() {
    final summary = widget.summary;
    return [
      'SHIFT ${summary.levelId.toString().padLeft(2, '0')}  ${widget.level.title}',
      '',
      'SORTED        ${summary.sorted}',
      'MISROUTED     ${summary.misrouted}',
      'DROPPED       ${summary.dropped}',
      'BEST COMBO    x${summary.bestCombo}',
      '--------------------------',
      'SCORE         ${summary.score}',
    ];
  }

  void _skip() {
    _timer?.cancel();
    setState(() => _revealed = _lines.length);
  }

  LevelConfig? get _nextLevel {
    final nextId = widget.summary.levelId + 1;
    for (final level in kPrototypeLevels) {
      if (level.id == nextId) {
        return level;
      }
    }
    return null;
  }

  bool get _isComplete => _revealed >= _lines.length;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final next = _nextLevel;

    return Scaffold(
      backgroundColor: Tokens.paper,
      body: GestureDetector(
        onTap: _isComplete ? null : _skip,
        behavior: HitTestBehavior.opaque,
        child: Stack(
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
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            Text(
                              summary.passed ? 'SHIFT COMPLETE' : 'SHIFT ENDED',
                              style: Tokens.display.copyWith(
                                color: Tokens.ink,
                                fontSize: 34,
                              ),
                            ),
                            const SizedBox(height: 28),
                            for (var i = 0;
                                i < _revealed && i < _lines.length;
                                i++)
                              Text(
                                _lines[i],
                                style: Tokens.body.copyWith(color: Tokens.ink),
                              ),
                            const SizedBox(height: 24),
                            if (_isComplete)
                              _VerdictStamp(text: summary.verdict),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                    if (_isComplete) ...[
                      if (summary.passed && next != null)
                        _ManifestButton(
                          label: 'NEXT SHIFT',
                          emphasised: true,
                          onPressed: () => _replaceWith(next),
                        ),
                      _ManifestButton(
                        label: 'CLOCK BACK IN',
                        emphasised: !summary.passed,
                        onPressed: () => _replaceWith(widget.level),
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
          ],
        ),
      ),
    );
  }

  void _replaceWith(LevelConfig level) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => PlayScreen(level: level)),
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
