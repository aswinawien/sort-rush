import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/level_config.dart';
import '../core/run_engine.dart';
import '../core/run_summary.dart';
import '../game/sort_rush_game.dart';
import 'results_screen.dart';
import 'theme.dart';
import 'widgets/fit_or_scroll.dart';

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

class _PlayScreenState extends State<PlayScreen> with WidgetsBindingObserver {
  SortRushGame? _game;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // D-01: the play field is the whole screen, so system chrome is hidden
    // while a shift is open. Sticky rather than plain immersive, so a stray
    // edge swipe does not leave the bars sitting over the belt for the rest
    // of the run.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// An interruption holds the belt rather than acting on it.
  ///
  /// Flame already pauses its own loop when the app is backgrounded, so no
  /// packages are lost while the player is away — but it resumes the instant
  /// they return, dropping them onto a moving belt with a package possibly
  /// already near the sort line. This shows the same scrim the back gesture
  /// does, so coming back is a deliberate act. See docs/decision-log.md,
  /// "Returning from the background".
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      return;
    }
    if (_game != null && !_paused) {
      _togglePause();
    }
  }

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
          builder: (_) => ResultsScreen(summary: summary, level: widget.level),
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

    // M3-01: back must not destroy a run in progress. While the belt is
    // running, back holds it and shows the scrim; leaving then takes a second,
    // deliberate action. Once held, back behaves normally and exits.
    // Pushed every build: the inset changes when the OS shows or hides the
    // bars, and a display cutout keeps occluding even in immersive mode, so
    // this is the fallback that keeps the HUD legible in either state.
    game.safeTop = MediaQuery.paddingOf(context).top;

    return PopScope(
      canPop: _paused,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _togglePause();
      },
      child: Scaffold(
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
        // Same reason as home: at large text scales the briefing outgrew the
        // screen and pushed START BELT out of reach.
        child: FitOrScroll(
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
                    : '${level.passCondition.briefingCopy} · ${level.mistakeLimit} MISTAKES ALLOWED.',
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
            Text('BELT HELD',
                style: Tokens.display.copyWith(color: Tokens.paper)),
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
