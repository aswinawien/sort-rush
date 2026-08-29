// Dev-only entrypoint. Nothing in the shipped app imports this file.
//
//   flutter build apk --profile -t lib/dev/dev_marathon.dart
//
// A sibling of `dev_autoplay.dart`, which deliberately downs tools eleven
// seconds after the first board so a capture stays short. This one does the
// opposite: it plays the endless shift until the run actually ends, so the
// question "how deep does a perfect player get" has an answer.
//
// IT IS NOT A MASTER PLAYER. It reads `isCorrectBin` straight off the engine,
// which no human can do, and it never misreads a compound rule or a stamp.
// Footage from here is evidence that the loop survives its own difficulty
// curve. It is NOT evidence that a person can, and it must never be used to
// argue the fairness floors are comfortable.
import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/levels.dart';
import '../core/run_engine.dart';
import '../core/shop.dart';
import '../game/sort_rush_game.dart';
import '../ui/audio_scope.dart';
import '../ui/play_screen.dart';
import '../ui/theme.dart';
import '../ui/visual_style.dart';
import 'dev_stats.dart';

void main() => runApp(const DevMarathonApp());

final GlobalKey _rootKey = GlobalKey();

class DevMarathonApp extends StatefulWidget {
  const DevMarathonApp({super.key});

  @override
  State<DevMarathonApp> createState() => _DevMarathonAppState();
}

class _DevMarathonAppState extends State<DevMarathonApp> {
  /// Commit earlier than `dev_autoplay`'s 0.55. Survival is the point here,
  /// and the optimal play is to route as soon as the package is readable.
  static const double commitAt = 0.30;

  /// A corrupting package is held until the morph resolves — the exact thing
  /// the `DAMAGED` telegraph exists to let a player do. Past this progress it
  /// commits anyway rather than eating a drop.
  static const double forceCommitAt = 0.85;

  /// Long enough that the board is legible on camera before it is answered.
  static const double browseSeconds = 4.0;

  /// Hard stop, so an immortal bot cannot record forever.
  static const double giveUpAfter = 420.0;

  /// Music does not play without an `AudioScope`: `PlayScreen._startMusic`
  /// reads `AudioScope.maybeOf(context)?.music` and returns early when there
  /// is none. Neither dev entrypoint installed one, so every capture until now
  /// ran silent.
  final AudioController _audio = AudioController();
  bool _audioReady = false;

  Timer? _driver;
  double _t = 0;
  bool _started = false;
  int _pointer = 100;

  double? _boardOpenedAt;
  bool _boardAnswered = false;

  int _shops = 0;
  int _bought = 0;
  int _peakPressure = 0;
  int _peakActive = 0;
  String _lastAction = '—';
  bool _capped = false;

  @override
  void initState() {
    super.initState();
    DevStats.screen = 'endless';
    // The belt is not mounted until tracks are discovered. `AudioController.load`
    // reads the asset manifest, and `PlayScreen` picks its track once on mount —
    // mounting first would start the run against an empty track set and stay
    // silent for the whole run.
    _audio.load().whenComplete(() {
      if (mounted) {
        setState(() => _audioReady = true);
      }
    });
    _driver = Timer.periodic(const Duration(milliseconds: 40), (_) {
      _t += 0.04;
      _step();
    });
  }

  @override
  void dispose() {
    _driver?.cancel();
    _audio.dispose();
    super.dispose();
  }

  Element? _root() => _rootKey.currentContext as Element?;

  T? _find<T>(bool Function(Widget w) match) {
    final root = _root();
    if (root == null) return null;
    Widget? hit;
    void visit(Element el) {
      if (hit != null) return;
      if (match(el.widget)) {
        hit = el.widget;
        return;
      }
      el.visitChildren(visit);
    }

    root.visitChildren(visit);
    return hit as T?;
  }

  SortRushGame? get _game =>
      _find<GameWidget<SortRushGame>>((w) => w is GameWidget<SortRushGame>)
          ?.game;

  Element? _elementWithText(String label) {
    final root = _root();
    if (root == null) return null;
    Element? hit;
    void visit(Element el) {
      if (hit != null) return;
      final w = el.widget;
      if (w is Text && w.data == label) {
        hit = el;
        return;
      }
      el.visitChildren(visit);
    }

    root.visitChildren(visit);
    return hit;
  }

  /// A real pointer down/up through the gesture pipeline, so every widget
  /// behaves exactly as it would under a thumb. The board is answered by
  /// tapping it, never by calling `buy` behind the UI's back.
  bool _tapText(String label) {
    final el = _elementWithText(label);
    final box = el?.renderObject;
    if (box is! RenderBox || !box.hasSize) return false;
    final at = box.localToGlobal(box.size.center(Offset.zero));
    final id = _pointer++;
    GestureBinding.instance
        .handlePointerEvent(PointerDownEvent(pointer: id, position: at));
    Future.delayed(const Duration(milliseconds: 70), () {
      GestureBinding.instance
          .handlePointerEvent(PointerUpEvent(pointer: id, position: at));
    });
    return true;
  }

  void _step() {
    if (!_started) {
      if (_t > 1.5 && _tapText('START BELT')) _started = true;
      return;
    }

    final game = _game;
    if (game == null) return; // results is up
    final RunEngine engine;
    try {
      engine = game.engine;
    } catch (_) {
      return;
    }

    if (engine.pressure > _peakPressure) _peakPressure = engine.pressure;
    if (engine.active.length > _peakActive) _peakActive = engine.active.length;

    if (engine.isShopping) {
      _boardOpenedAt ??= _t;
      if (!_boardAnswered && _t - _boardOpenedAt! >= browseSeconds) {
        _answerBoard(engine);
        _boardAnswered = true;
      }
      return;
    }

    if (_boardAnswered) {
      _shops++;
      _boardAnswered = false;
      _boardOpenedAt = null;
    }

    if (engine.phase != RunPhase.running) return;

    if (_t > giveUpAfter) {
      _capped = true;
      return; // stop routing; the run ends on drops
    }

    final front = engine.frontMost;
    if (front == null) return;
    // Hold a corrupting package until its telegraph resolves.
    if (front.isUnstable && front.progress < forceCommitAt) return;
    if (front.progress < commitAt) return;

    for (var i = 0; i < engine.liveBinCount; i++) {
      if (engine.isCorrectBin(front.spec, i)) {
        game.handleBinTap(i);
        return;
      }
    }
  }

  /// Takes the FIRST affordable slip, else walks on.
  ///
  /// This is not strategic play and must not be described as such. It does
  /// not read the pending shift event, so it will happily pin `CLEAN SHIFT`
  /// (`chaos -0.15`, and a permanent combo cap of x4) against a visible
  /// `CORRUPTION NOTICE` (`chaos +0.30`, this band) — paying six for a net
  /// chaos *increase* plus a lower score ceiling for the rest of the run.
  ///
  /// A human sees that coming: docs/design-spec.md §5.5 draws the event with
  /// the board and requires it "visible in full before pin or walk-on". The
  /// routing in this file is perfect; the shopping is naive. Footage from
  /// here is master-level at the belt and worse than novice at the board.
  void _answerBoard(RunEngine engine) {
    final offers = engine.shopOffers;
    for (var i = 0; i < offers.length; i++) {
      if (offers[i].cost <= engine.score.pay) {
        if (_tapText(offers[i].title)) {
          _bought++;
          _lastAction = 'PINNED ${offers[i].chip}';
          return;
        }
      }
    }
    _tapText('WALK ON');
    _lastAction = 'WALKED ON';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: AudioScope(
        notifier: _audio,
        child: VisualStyleScope(
          notifier: VisualStyleController(initial: VisualStyle.immersiveNeon),
          child: Builder(
            key: _rootKey,
            builder: (_) => !_audioReady
                ? const ColoredBox(color: Tokens.ink)
                : Stack(
                    children: [
                      PlayScreen(level: kEndlessShift, seed: 20260822),
                      const IgnorePointer(child: _MarathonReadout()),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Self-documenting caption, so the recording says what it is without a
/// voice-over. Repaints on its own clock rather than from the driver.
class _MarathonReadout extends StatefulWidget {
  const _MarathonReadout();

  @override
  State<_MarathonReadout> createState() => _MarathonReadoutState();
}

class _MarathonReadoutState extends State<_MarathonReadout> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(
      const Duration(milliseconds: 400),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.findAncestorStateOfType<_DevMarathonAppState>();
    if (s == null) return const SizedBox.shrink();
    final line = 'BOARDS ${s._shops}/${EndlessShop.blinds.length}'
        '  PINNED ${s._bought}'
        '  PEAK P ${s._peakPressure}'
        '  BELT ${s._peakActive}'
        '${s._capped ? '  CAPPED' : ''}';
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(line, style: Tokens.label),
            Text(s._lastAction, style: Tokens.label),
          ],
        ),
      ),
    );
  }
}
