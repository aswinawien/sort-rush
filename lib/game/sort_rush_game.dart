import 'dart:ui';

import 'package:flame/game.dart';

import '../core/level_config.dart';
import '../core/run_engine.dart';
import '../ui/theme.dart';
import 'components/belt_component.dart';
import 'components/bin_component.dart';
import 'components/hud_component.dart';
import 'components/sort_line_component.dart';
import 'music.dart';
import 'music_catalog.dart';
import 'sfx.dart';

/// The active play loop. Flame owns this; everything outside it is Flutter.
///
/// This class holds no game rules. It reads [RunEngine] state, draws it, and
/// forwards taps back. Anything that decides an outcome belongs in `core/`.
class SortRushGame extends FlameGame {
  SortRushGame({
    required this.level,
    required this.seed,
    required this.onRunEnded,
    this.onShopOpened,
    this.onReady,
    this.startingPay = 0,
    SfxBus? sfx,
    MusicBus? music,
  })  : sfx = sfx ?? const SilentSfx(),
        music = music ?? const SilentMusic();

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
  final int startingPay;
  final SfxBus sfx;

  /// Atmosphere only. The endless crossfade is driven from [update] rather
  /// than from Flutter's `build`, because `engine` is late-initialised in the
  /// async `onLoad` and the first build lands before it exists.
  final MusicBus music;
  final void Function(RunEngine engine) onRunEnded;
  final void Function()? onShopOpened;

  /// Called once after [engine] exists and has started. Debug jumps use this
  /// to force a shop, a roll, or a hold without lying in Flutter.
  final void Function(RunEngine engine)? onReady;

  late final RunEngine engine;

  /// The depot overlay is still covering the belt.
  ///
  /// `buy` / `skipShop` flip the engine back to [RunPhase.running] on the
  /// tap, while the paper takes ~160ms (standard) or ~230ms (neon) to
  /// retract. Without this hold, a presentation setting would advance
  /// `_elapsed` — and therefore the endless swap clock and the spawn
  /// timer — behind a covering overlay. Acceptance criterion 8.
  bool overlayHoldsEngine = false;

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

  /// Pushed from Flutter each build. Zeros the held combo split and the
  /// belt scan lines; timings stay identical.
  bool reduceMotion = false;

  /// Presentation only. Set by [PlayScreen] from the visual-style setting;
  /// nothing reachable from this flag may change a rule or a timing value.
  bool neon = false;

  @override
  Color backgroundColor() => Tokens.ink;

  @override
  Future<void> onLoad() async {
    engine = RunEngine(level: level, seed: seed, startingPay: startingPay);

    _hud = HudComponent();
    _belt = BeltComponent();
    _sortLine = SortLineComponent();
    await addAll([_belt, _sortLine, _hud]);

    _laidOut = true;
    engine.start();
    onReady?.call(engine);
    _syncBins();
    _applyLayout();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _applyLayout();
  }

  void _syncBins() {
    final specs = engine.visibleBins;
    final highlighted = engine.telegraph?.highlighted ?? const <int>{};
    while (_bins.length > specs.length) {
      _bins.removeLast().removeFromParent();
    }
    for (var i = 0; i < specs.length; i++) {
      if (i < _bins.length) {
        _bins[i].adopt(specs[i]);
      } else {
        final bin = BinComponent(index: i, spec: specs[i]);
        _bins.add(bin);
        add(bin);
      }
      _bins[i].warned = highlighted.contains(i);
    }
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
    if (count == 0) {
      return;
    }
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
    if (!overlayHoldsEngine) {
      engine.update(dt);
    }

    if (level.curve != null) {
      // Throttled inside the bus: setting volume every frame is a platform
      // channel call per player per frame.
      music.setEndlessMix(MusicCatalog.endlessMix(engine.pressure));
    }

    final events = engine.drainEvents();
    final comboUp = events.whereType<ComboAdvancedEvent>().isNotEmpty;
    for (final event in events) {
      switch (event) {
        case final PackageSortedEvent e:
          _bins[e.binIndex].flashCorrect();
          _hud.pulseScore();
          sfx.sorted(tier: e.tier, comboUp: comboUp);
        case final PackageMisroutedEvent e:
          _bins[e.binIndex].flashMisroute();
          _hud.glitch();
          sfx.misroute();
        case PackageDroppedEvent():
          _hud.glitch();
          sfx.dropped();
        case PackageMorphedEvent():
          // The corrupted state is drawn from `ActivePackage.isUnstable` by
          // BeltComponent; this punctuates the instant it resolves, so the
          // change is felt and not merely noticed.
          _hud.glitch();
        case ComboAdvancedEvent():
          _hud.pulseCombo();
        case LayoutTelegraphEvent():
        case LayoutChangedEvent():
          _syncBins();
          _applyLayout();
        case ShopOpenedEvent():
          onShopOpened?.call();
        case RunEndedEvent():
          sfx.ended();
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
