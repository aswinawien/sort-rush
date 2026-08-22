import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/level_config.dart';
import '../core/run_engine.dart';
import '../core/run_summary.dart';
import '../game/sfx.dart';
import '../game/music.dart';
import '../game/sort_rush_game.dart';
import 'audio_scope.dart';
import 'memo_board.dart';
import 'results_screen.dart';
import 'theme.dart';
import 'visual_style.dart';
import 'widgets/fit_or_scroll.dart';

/// Debug-only landing for a [PlayScreen] already in the right overlay.
///
/// Home's DEV strip uses these. Release builds never construct one.
enum DevJump { memo, roll, pause }

/// Hosts the Flame surface and everything around it.
///
/// The briefing, pause, and the route to results are Flutter's job; only the
/// active loop belongs to Flame.
class PlayScreen extends StatefulWidget {
  const PlayScreen({
    super.key,
    required this.level,
    this.seed,
    this.wager = false,
    this.jump,
    this.startingPay = 0,
  });

  final LevelConfig level;

  /// Fixed seed for tests and reproducible bug reports. Null means pick one.
  final int? seed;

  /// Double-or-nothing replay of a cleared shift. Fail scores zero.
  final bool wager;

  /// Skips the briefing and opens already in the named overlay. Null in
  /// every release path.
  final DevJump? jump;

  /// Capped leftover pay from the last endless clocking. Curated ignores it.
  final int startingPay;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with WidgetsBindingObserver {
  SortRushGame? _game;
  bool _paused = false;
  bool _shopOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // D-01: the play field is the whole screen, so system chrome is hidden
    // while a shift is open. Sticky rather than plain immersive, so a stray
    // edge swipe does not leave the bars sitting over the belt for the rest
    // of the run.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (widget.jump != null) {
      _game = _createGame();
      if (widget.jump == DevJump.pause) {
        _paused = true;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _music?.stop();
    super.dispose();
  }

  /// Captured on the way in: `dispose` runs after the element is detached, so
  /// the scope is no longer reachable by then.
  MusicBus? _music;

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
    if (_game != null && !_paused && !_shopOpen) {
      _togglePause();
    }
  }

  void _begin() {
    setState(() {
      _game = _createGame();
    });
    _startMusic();
  }

  /// Endless crossfades two loops by pressure; a curated shift plays its own
  /// track. Music is atmosphere either way — nothing here is a cue.
  void _startMusic() {
    final music = AudioScope.maybeOf(context)?.music;
    if (music == null) {
      return;
    }
    if (widget.level.curve != null) {
      music.playEndless();
    } else {
      music.playLevel(widget.level.id);
    }
  }

  SortRushGame _createGame() {
    return SortRushGame(
      level: widget.level,
      seed: widget.seed ?? DateTime.now().millisecondsSinceEpoch,
      startingPay: widget.startingPay,
      sfx: context.getInheritedWidgetOfExactType<AudioScope>()?.notifier?.sfx ??
          const SilentSfx(),
      // `getInheritedWidgetOfExactType`, not `maybeOf`: `_createGame` runs
      // from `initState` on a dev jump, and `maybeOf` registers a dependency,
      // which is illegal there. Same reason the sfx lookup above uses it.
      music: context
              .getInheritedWidgetOfExactType<AudioScope>()
              ?.notifier
              ?.music ??
          const SilentMusic(),
      onRunEnded: _handleRunEnded,
      onShopOpened: () {
        if (!mounted) {
          return;
        }
        _game?.overlayHoldsEngine = true;
        setState(() => _shopOpen = true);
      },
      onReady: _applyJump,
    );
  }

  void _applyJump(RunEngine engine) {
    switch (widget.jump) {
      case DevJump.memo:
        engine.debugOpenShop();
      case DevJump.roll:
        engine.debugForceRoll();
      case DevJump.pause:
        engine.pause();
      case null:
        break;
    }
  }

  void _handleRunEnded(RunEngine engine) {
    if (!mounted) {
      return;
    }
    final summary = RunSummary.fromEngine(engine, wagered: widget.wager);
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

  void _closeShop() {
    if (!mounted) {
      return;
    }
    // Release the engine only once the paper has retracted. The commit
    // happened on the tap; this is the moment the belt is actually visible.
    _game?.overlayHoldsEngine = false;
    setState(() => _shopOpen = false);
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
    final profile = VisualProfile.of(context);
    game.reduceMotion = profile.reduceMotion;
    game.neon = profile.neon;

    _music ??= AudioScope.maybeOf(context)?.music;

    return PopScope(
      canPop: _paused,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        if (_shopOpen) {
          game.engine.skipShop();
          _closeShop();
          return;
        }
        _togglePause();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                ignoring: _shopOpen || _paused,
                child: GameWidget(game: game),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: _shopOpen
                    ? const SizedBox.shrink()
                    : IconButton(
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
            if (_shopOpen) MemoBoard(engine: game.engine, onClosed: _closeShop),
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
