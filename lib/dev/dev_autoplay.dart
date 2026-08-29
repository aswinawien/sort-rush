// Dev-only entrypoint. Nothing in the shipped app imports this file; it exists
// so a scripted player can drive a real run in a browser for capture.
//
//   flutter build web -t lib/dev/dev_autoplay.dart
//
// It drives the real PlayScreen, so the briefing, the depot board and the
// results slip on camera are the genuine screens, not a rebuild of them. The
// player reaches into the engine for the correct chute, which a real player
// cannot do: footage is evidence the loop runs and reads, never evidence of
// difficulty.
import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/levels.dart';
import '../core/run_engine.dart';
import '../game/sort_rush_game.dart';
import '../ui/play_screen.dart';
import '../ui/visual_style.dart';
import '../ui/theme.dart';
import 'dev_stats.dart';
import 'profiler_overlay.dart';

void main() => runApp(const DevCaptureApp());

final GlobalKey _rootKey = GlobalKey();

class DevCaptureApp extends StatefulWidget {
  const DevCaptureApp({super.key});

  @override
  State<DevCaptureApp> createState() => _DevCaptureAppState();
}

class _DevCaptureAppState extends State<DevCaptureApp> {
  /// How far down the belt a package gets before the scripted player commits.
  /// Tapping on spawn would hide the queue pressure the run is built around.
  static const double commitAt = 0.55;

  /// Seconds the depot board is left on screen before walking on.
  static const double browseSeconds = 6.0;

  /// Seconds of play after the board closes, before the player downs tools.
  static const double afterShopSeconds = 11.0;

  Timer? _driver;
  double _t = 0;
  bool _started = false;
  bool _sawShop = false;
  double? _shopClosedAt;
  bool _downedTools = false;
  int _pointer = 100;

  @override
  void initState() {
    super.initState();
    DevStats.screen = 'endless';
    _driver = Timer.periodic(const Duration(milliseconds: 40), (_) {
      _t += 0.04;
      _step();
    });
  }

  @override
  void dispose() {
    _driver?.cancel();
    super.dispose();
  }

  // --- driving the real widget tree -----------------------------------

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

  /// A real pointer down/up through the gesture pipeline, so the button under
  /// it behaves exactly as it would under a thumb.
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

  // --- the script -------------------------------------------------------

  void _step() {
    if (!_started) {
      if (_t > 1.5 && _tapText('START BELT')) _started = true;
      return;
    }

    final game = _game;
    if (game == null) return; // results is up; nothing left to drive
    final RunEngine engine;
    try {
      engine = game.engine;
    } catch (_) {
      return; // not loaded yet
    }

    if (engine.isShopping) {
      if (!_sawShop) {
        _sawShop = true;
        _shopClosedAt = _t + browseSeconds;
      }
      if (_shopClosedAt != null && _t >= _shopClosedAt!) {
        if (_tapText('WALK ON')) _shopClosedAt = _t + 1e9;
      }
      return;
    }

    if (_sawShop && _shopClosedAt != null && _shopClosedAt! > 1e8) {
      // Board is closed; mark the resume moment once.
      _shopClosedAt = _t;
    }

    if (engine.phase != RunPhase.running) return;

    // After a stretch of clean play the player downs tools, so the run ends
    // on dropped parcels and the results slip is reached the way a real one
    // would be.
    if (_sawShop &&
        _shopClosedAt != null &&
        _t - _shopClosedAt! > afterShopSeconds) {
      _downedTools = true;
    }
    if (_downedTools) return;

    final front = engine.frontMost;
    if (front == null || front.progress < commitAt) return;
    for (var i = 0; i < engine.liveBinCount; i++) {
      if (engine.isCorrectBin(front.spec, i)) {
        game.handleBinTap(i);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: VisualStyleScope(
        notifier: VisualStyleController(initial: VisualStyle.immersiveNeon),
        child: Builder(
          key: _rootKey,
          builder: (_) => ProfilerOverlay(
            child: PlayScreen(level: kEndlessShift, seed: 20260822),
          ),
        ),
      ),
    );
  }
}
