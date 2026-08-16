import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/level_config.dart';
import '../core/run_engine.dart';
import '../core/run_summary.dart';
import '../game/sort_rush_game.dart';
import 'results_screen.dart';
import 'theme.dart';

/// Hosts the Flame surface and everything around it.
///
/// The briefing, pause, and the route to results are Flutter's job; only the
/// active loop belongs to Flame.
class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, required this.level, this.seed});

  final LevelConfig level;

  /// Fixed seed for tests and reproducible bug reports. Null means pick one.
  final int? seed;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  SortRushGame? _game;
  bool _paused = false;

  void _begin() {
    setState(() {
      _game = SortRushGame(
        level: widget.level,
        seed: widget.seed ?? DateTime.now().millisecondsSinceEpoch,
        onRunEnded: _handleRunEnded,
      );
    });
  }

  void _handleRunEnded(RunEngine engine) {
    if (!mounted) {
      return;
    }
    final summary = RunSummary.fromEngine(engine);
    // The engine finishes inside a frame; leaving the route mid-frame is not
    // safe, so the navigation waits for the frame to close.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              ResultsScreen(summary: summary, level: widget.level),
        ),
      );
    });
  }

  void _togglePause() {
    final game = _game;
    if (game == null) {
      return;
    }
    setState(() {
      _paused = !_paused;
      if (_paused) {
        game.pauseRun();
      } else {
        game.resumeRun();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    if (game == null) {
      return _BriefingScreen(level: widget.level, onStart: _begin);
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: GameWidget(game: game)),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: _togglePause,
                icon: Icon(
                  _paused ? Icons.play_arrow : Icons.pause,
                  color: Tokens.mute,
                ),
                iconSize: 28,
                tooltip: _paused ? 'Resume' : 'Pause',
              ),
            ),
          ),
          if (_paused) _PauseScrim(onResume: _togglePause),
        ],
      ),
    );
  }
}

/// Shown before the belt starts. Expressive but obvious: the player must know
/// what they are being asked to do before anything moves.
class _BriefingScreen extends StatelessWidget {
  const _BriefingScreen({required this.level, required this.onStart});

  final LevelConfig level;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(
                'SHIFT ${level.id.toString().padLeft(2, '0')}',
                style: Tokens.label.copyWith(color: Tokens.acid),
              ),
              const SizedBox(height: 8),
              Text(
                level.title,
                style: Tokens.display.copyWith(color: Tokens.paper),
              ),
              const SizedBox(height: 24),
              Text(
                level.tutorialCopy,
                style: Tokens.body.copyWith(fontSize: 18, height: 1.5),
              ),
              const SizedBox(height: 24),
              Text(
                level.isUnfailable
                    ? 'NO PENALTY THIS SHIFT.'
                    : 'SORT ${level.passTarget} · ${level.mistakeLimit} MISTAKES ALLOWED.',
                style: Tokens.label,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: FilledButton(
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: Tokens.acid,
                    foregroundColor: Tokens.ink,
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: Text(
                    'START BELT',
                    style: Tokens.body.copyWith(
                      color: Tokens.ink,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PauseScrim extends StatelessWidget {
  const _PauseScrim({required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Tokens.ink.withValues(alpha: 0.88),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('BELT HELD', style: Tokens.display.copyWith(color: Tokens.paper)),
            const SizedBox(height: 32),
            TextButton(
              onPressed: onResume,
              child: Text(
                'RESUME',
                style: Tokens.body.copyWith(color: Tokens.acid),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('QUIT TO HOME', style: Tokens.label),
            ),
          ],
        ),
      ),
    );
  }
}
