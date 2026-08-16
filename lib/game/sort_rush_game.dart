import 'dart:ui';

import 'package:flame/game.dart';

import '../core/level_config.dart';
import '../core/run_engine.dart';
import '../ui/theme.dart';
import 'components/belt_component.dart';
import 'components/bin_component.dart';
import 'components/hud_component.dart';
import 'components/sort_line_component.dart';

/// The active play loop. Flame owns this; everything outside it is Flutter.
///
/// This class holds no game rules. It reads [RunEngine] state, draws it, and
/// forwards taps back. Anything that decides an outcome belongs in `core/`.
class SortRushGame extends FlameGame {
  SortRushGame({
    required this.level,
    required this.seed,
    required this.onRunEnded,
  });

  /// Vertical layout split from docs/design-spec.md §8. Proportional so the
  /// belt absorbs extra height on tall screens without changing timings.
  static const double statusFraction = 0.14;
  static const double beltFraction = 0.62;
  static const double binsFraction = 0.24;

  /// Gap between adjacent bins. Outer edges stay flush to the screen so an
  /// edge tap still lands.
  static const double binGap = 8;

  final LevelConfig level;
  final int seed;
  final void Function(RunEngine engine) onRunEnded;

  late final RunEngine engine;

  final List<BinComponent> _bins = [];
  late final BeltComponent _belt;
  late final SortLineComponent _sortLine;
  late final HudComponent _hud;

  /// Height at the top of the canvas occluded by system chrome — the status
  /// bar, or a display cutout that stays occluding even in immersive mode.
  ///
  /// The play geometry below the status band is deliberately unaffected: the
  /// belt keeps its full height, because the fairness timings in
  /// docs/level-spec.md are expressed in that geometry and must not shift with
  /// the device's notch.
  double _safeTop = 0;

  set safeTop(double value) {
    if (value == _safeTop) {
      return;
    }
    _safeTop = value;
    _applyLayout();
  }

  bool _laidOut = false;
  bool _endNotified = false;

  @override
  Color backgroundColor() => Tokens.ink;

  @override
  Future<void> onLoad() async {
    engine = RunEngine(level: level, seed: seed);

    _hud = HudComponent();
    _belt = BeltComponent();
    _sortLine = SortLineComponent();
    await addAll([_belt, _sortLine, _hud]);

    for (var i = 0; i < level.binCount; i++) {
      final bin = BinComponent(index: i, spec: level.routing.bins[i]);
      _bins.add(bin);
      await add(bin);
    }

    _laidOut = true;
    _applyLayout();
    engine.start();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _applyLayout();
  }

  void _applyLayout() {
    if (!_laidOut) {
      return;
    }
    final w = size.x;
    final h = size.y;
    final statusHeight = h * statusFraction;
    final beltHeight = h * beltFraction;
    final binsHeight = h * binsFraction;

    // Inset only the HUD. See docs/decision-log.md, "D-01".
    final hudTop = _safeTop.clamp(0.0, statusHeight * 0.6);
    _hud.position = Vector2(0, hudTop);
    _hud.size = Vector2(w, statusHeight - hudTop);

    _belt.position = Vector2(0, statusHeight);
    _belt.size = Vector2(w, beltHeight);

    _sortLine.position = Vector2(0, statusHeight + beltHeight - 2);
    _sortLine.size = Vector2(w, 4);

    final count = _bins.length;
    final binWidth = (w - binGap * (count - 1)) / count;
    for (var i = 0; i < count; i++) {
      _bins[i].position = Vector2(
        i * (binWidth + binGap),
        statusHeight + beltHeight + binGap,
      );
      _bins[i].size = Vector2(binWidth, binsHeight - binGap * 2);
    }
  }

  /// Called by [BinComponent]. Routing and scoring happen in the engine; the
  /// visual response comes back through drained events, so a tap can never
  /// produce feedback that disagrees with the score.
  void handleBinTap(int index) {
    engine.tapBin(index);
  }

  @override
  void update(double dt) {
    super.update(dt);
    // `engine` is late-initialised in onLoad; never tick before it exists.
    if (!_laidOut) {
      return;
    }
    engine.update(dt);

    for (final event in engine.drainEvents()) {
      switch (event) {
        case final PackageSortedEvent e:
          _bins[e.binIndex].flashCorrect();
          _hud.pulseScore();
        case final PackageMisroutedEvent e:
          _bins[e.binIndex].flashMisroute();
          _hud.glitch();
        case PackageDroppedEvent():
          _hud.glitch();
        case PackageMorphedEvent():
          // The corrupted state and the changed silhouette are both drawn
          // from package state by BeltComponent each frame, so nothing
          // one-shot is needed here yet. The punctuation lands with the
          // effects work, not with the mechanic.
          break;
        case ComboAdvancedEvent():
          _hud.pulseCombo();
        case RunEndedEvent():
          break;
      }
    }

    if (engine.isOver && !_endNotified) {
      _endNotified = true;
      onRunEnded(engine);
    }
  }

  void pauseRun() => engine.pause();

  void resumeRun() => engine.resume();
}
