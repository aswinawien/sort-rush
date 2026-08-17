import 'dart:collection';

import 'board.dart';
import 'level_config.dart';
import 'package_spec.dart';
import 'routing.dart';
import 'run_tuning.dart';
import 'score_state.dart';
import 'shop.dart';
import 'tuning_delta.dart';
import 'seeded_rng.dart';

/// Where a run is in its lifecycle.
enum RunPhase { ready, running, paused, shopping, ending, finished }

enum RunOutcome { none, passed, failed }

/// What a bin tap did.
enum TapResult { correct, misroute, ignored }

/// A package travelling down the belt.
///
/// Position is held as normalised progress in time, not pixels, so the core
/// runs identically headless and on any screen size. Pixel-based speed would
/// make the game measurably easier on tall phones.
class ActivePackage {
  ActivePackage({
    required this.id,
    required PackageSpec spec,
    required this.readWindow,
    required this.telegraphSeconds,
    this.morphAt,
    this.morphTo,
  }) : _spec = spec;

  final int id;

  /// How long this package's corrupted state shows before it changes, fixed
  /// when it spawned — for the same reason as [readWindow]. A warning that
  /// grew or shrank while the player was already reading it would be the
  /// mechanic lying about itself.
  final double telegraphSeconds;

  /// Seconds this package gets from spawn to the sort line, fixed when it
  /// spawned.
  ///
  /// Deliberately *not* read from the level each tick. A package's contract is
  /// set the moment it appears: anything that later shortens the level's read
  /// window would otherwise speed up packages already in the air, and could
  /// move one into or out of the clutch window without it moving at all. That
  /// is randomness resolving after the player has already committed, which is
  /// the thing the whole design is built to avoid.
  final double readWindow;

  /// Progress at which a `DAMAGED` package re-renders as [morphTo], or null
  /// for an ordinary package.
  final double? morphAt;

  /// What this package becomes.
  ///
  /// Always routes to a different chute than the package spawned with. A
  /// morph that does not change the destination is indistinguishable from no
  /// morph — it would teach the player that glitching is decorative.
  final PackageSpec? morphTo;

  PackageSpec _spec;
  bool _unstable = false;
  bool _morphed = false;

  /// 0 at spawn, 1 at the sort line.
  double progress = 0;

  /// The package as it reads *right now*. Routing uses this, so a morphed
  /// package belongs in the bin for its new shape.
  PackageSpec get spec => _spec;

  bool get isDamaged => morphAt != null;

  /// True while the corrupted state is showing and the shape has not changed
  /// yet. This is the window in which the player should hold their tap.
  bool get isUnstable => _unstable;

  bool get hasMorphed => _morphed;
}

/// Something the presentation layer may want to react to. Drained each frame.
sealed class RunEvent {
  const RunEvent();
}

class PackageSortedEvent extends RunEvent {
  const PackageSortedEvent({
    required this.binIndex,
    required this.gained,
    required this.tier,
    this.clutch = false,
  });

  final int binIndex;
  final int gained;
  final int tier;

  /// Whether this was pulled out of the last moments before the sort line.
  final bool clutch;
}

class PackageMisroutedEvent extends RunEvent {
  const PackageMisroutedEvent(this.binIndex);

  final int binIndex;
}

class PackageDroppedEvent extends RunEvent {
  const PackageDroppedEvent();
}

/// A `DAMAGED` package just changed shape. The presentation layer uses this
/// to punctuate the moment; the engine has already applied it.
class PackageMorphedEvent extends RunEvent {
  const PackageMorphedEvent(this.packageId);

  final int packageId;
}

class ComboAdvancedEvent extends RunEvent {
  const ComboAdvancedEvent(this.tier);

  final int tier;
}

class RunEndedEvent extends RunEvent {
  const RunEndedEvent(this.outcome);

  final RunOutcome outcome;
}

class LayoutTelegraphEvent extends RunEvent {
  const LayoutTelegraphEvent(this.kind);

  final LayoutChangeKind kind;
}

class LayoutChangedEvent extends RunEvent {
  const LayoutChangedEvent(this.kind);

  final LayoutChangeKind kind;
}

/// The belt is empty and the depot board is up. Presentation draws the memos;
/// the engine will not spawn or accept taps until [RunEngine.buy] or
/// [RunEngine.skipShop].
class ShopOpenedEvent extends RunEvent {
  const ShopOpenedEvent(this.offers);

  final List<CardSpec> offers;
}

/// The whole game, minus rendering.
///
/// Imports neither Flame nor Flutter. This is what makes the scoring, combo,
/// routing, and state-transition tests possible without a game loop or a
/// widget tree, and it is the main defence against hidden coupling.
class RunEngine {
  RunEngine({required this.level, required this.seed})
      : _rng = SeededRng(seed),
        // Own stream, derived from the run seed, so a shop draw can never
        // shift package spawns. XOR is a bijection: every seed still maps
        // to a distinct shop stream.
        _shopRng = SeededRng(seed ^ 0x51A70FF),
        _tuning = RunTuning.resolve(level: level),
        _board = level.curve == null
            ? null
            : ChuteBoard(
                EndlessBoard.ladder.sublist(0, EndlessBoard.openingCount),
              );

  /// How long the belt keeps still after a run ends, before results show.
  /// An instant cut on failure reads as a crash and robs the player of the
  /// beat where they work out what just happened.
  static const double endingDuration = 0.9;

  /// Latest progress at which a `DAMAGED` package may change shape, leaving a
  /// quarter of the read window to react to what it became.
  static const double _latestMorph = 0.75;

  /// How close to the sort line a correct sort counts as a clutch save.
  ///
  /// Deliberately shorter than the 1.20s read-window floor: a save has to be
  /// a save, not the ordinary case. See docs/decision-log.md, "Clutch saves".
  static const double clutchWindow = 0.5;

  final LevelConfig level;
  final int seed;

  final SeededRng _rng;
  final SeededRng _shopRng;
  final RunScore score = RunScore();
  final List<ActivePackage> _active = [];
  final List<RunEvent> _events = [];

  RunTuning _tuning;
  TuningDelta _modifiers = TuningDelta.none;
  ChuteBoard? _board;
  LayoutTelegraph? _telegraph;
  double _nextSwapAt = EndlessBoard.swapInterval;
  bool _drainingForShop = false;
  int _nextBlind = 0;
  List<CardSpec> _shopOffers = const [];
  final List<CardSpec> _pinned = [];

  /// The numbers the belt is running on right now — the level as modified by
  /// the difficulty curve and anything the player has bought. Read this, never
  /// [level], for anything that can change during a run.
  RunTuning get tuning => _tuning;

  /// Live chute count. Endless opens at two and grows; curated is fixed.
  int get liveBinCount => _board?.length ?? level.binCount;

  /// Where [package] belongs *right now*. Endless reads the live board, which
  /// can swap and grow; curated reads the level's rule, which never moves.
  int binFor(PackageSpec package) =>
      _board?.binFor(package) ?? level.routing.binFor(package);

  /// Chutes to draw. During a grow telegraph this is the *next* board, so the
  /// new chute is visible as a warning before it can be tapped.
  List<BinSpec> get visibleBins {
    final pending = _telegraph;
    if (pending != null && pending.kind == LayoutChangeKind.grow) {
      return pending.next.bins;
    }
    return _board?.bins ?? level.routing.bins;
  }

  LayoutTelegraph? get telegraph => _telegraph;

  /// Memos currently on the board. Empty when the shop is closed.
  List<CardSpec> get shopOffers => _shopOffers;

  /// Memos pinned this run, in buy order. Lasts until the run ends.
  List<CardSpec> get pinned => List.unmodifiable(_pinned);

  bool get isShopping => _phase == RunPhase.shopping;

  /// Fill of the current pressure band, 0–1. Curated levels have no band.
  double get pressureProgress => _board == null
      ? 0
      : EndlessBoard.pressureProgress(pressure);

  /// Pressure index. Increments per correct sort and never decreases, which
  /// is exactly what `score.sorted` already does — so there is no second
  /// counter to keep in step.
  int get pressure => score.sorted;

  RunPhase _phase = RunPhase.ready;
  RunOutcome _outcome = RunOutcome.none;
  double _spawnTimer = 0;
  double _endingTimer = 0;
  double _elapsed = 0;
  int _nextId = 0;

  RunPhase get phase => _phase;
  RunOutcome get outcome => _outcome;
  double get elapsed => _elapsed;
  bool get isOver => _phase == RunPhase.finished;

  /// Built once and handed out on every call.
  ///
  /// `List.unmodifiable` copies, and the belt reads this every frame, so the
  /// old version allocated and filled a fresh list 60 times a second to hand
  /// back data that was already immutable to the caller. This is a view: no
  /// copy, still unmodifiable, and it tracks the belt rather than snapshotting
  /// it.
  late final List<ActivePackage> _activeView = UnmodifiableListView(_active);

  List<ActivePackage> get active => _activeView;

  /// The package the player is currently sorting: the one nearest the sort
  /// line. Only this one can be routed, which is what keeps a bin tap
  /// unambiguous.
  ActivePackage? get frontMost {
    ActivePackage? best;
    for (final package in _active) {
      if (best == null || package.progress > best.progress) {
        best = package;
      }
    }
    return best;
  }

  /// Seconds until the front-most package crosses the sort line, or null if
  /// the belt is empty. Drives the sort line turning to the warning colour.
  double? get timeToLine {
    final package = frontMost;
    if (package == null) {
      return null;
    }
    return (1 - package.progress) * package.readWindow;
  }

  void start() {
    if (_phase != RunPhase.ready) {
      return;
    }
    _phase = RunPhase.running;
    _spawn();
    _spawnTimer = 0;
  }

  void pause() {
    if (_phase == RunPhase.running) {
      _phase = RunPhase.paused;
    }
  }

  /// Debug-only. Empties the belt, draws a real shop hand, and opens the
  /// board. [pay] defaults high enough that every slip is affordable.
  /// Unused by any release path.
  void debugOpenShop({int pay = 20}) {
    _active.clear();
    _telegraph = null;
    _drainingForShop = false;
    score.pay = pay;
    _shopOffers = _shopRng.take(
      List<CardSpec>.of(EndlessShop.catalog),
      EndlessShop.offerCount,
    );
    _phase = RunPhase.shopping;
    _events.add(ShopOpenedEvent(_shopOffers));
  }

  /// Debug-only. Forces combo `x5`, pins two memos, and parks pressure in
  /// the mid band so the HUD split and scan lines are on. Stays [running].
  /// Unused by any release path.
  void debugForceRoll({
    int consecutive = 20,
    List<CardSpec>? pinned,
    int sorted = 32,
    int scoreValue = 1840,
  }) {
    if (_phase == RunPhase.ready) {
      start();
    }
    score.debugForce(
      consecutive: consecutive,
      sorted: sorted,
      score: scoreValue,
    );
    final pins = pinned ??
        [
          EndlessShop.catalog[0],
          EndlessShop.catalog[2],
        ];
    _pinned
      ..clear()
      ..addAll(pins);
    _modifiers = TuningDelta.none;
    for (final card in pins) {
      _modifiers = _modifiers + card.delta;
    }
    _snapBoardToPressure();
    _retune();
    // P=32 is already past the first blind. Skip blinds the jump leapt over
    // so the board does not slam open on the first frame of a roll review.
    while (_nextBlind < EndlessShop.blinds.length &&
        pressure >= EndlessShop.blinds[_nextBlind]) {
      _nextBlind++;
    }
    if (_phase != RunPhase.finished && _phase != RunPhase.ending) {
      _phase = RunPhase.running;
    }
  }

  /// Instantly grows the live board to the count [pressure] already earned.
  /// A review jump that left two chutes at `P=32` would be lying about the
  /// mid-band. No telegraph: nothing is in flight that a warning would serve.
  void _snapBoardToPressure() {
    final current = _board;
    if (current == null) {
      return;
    }
    var board = current;
    final target = EndlessBoard.targetCount(pressure);
    while (board.length < target) {
      board = board.grown(EndlessBoard.ladder[board.length]);
    }
    _board = board;
    _telegraph = null;
  }

  void resume() {
    if (_phase == RunPhase.paused) {
      _phase = RunPhase.running;
    }
  }

  /// Applies a modifier for the remainder of the run.
  ///
  /// Packages already on the belt are untouched by design: each one froze its
  /// own timing when it spawned, so a change here can never speed up or slow
  /// down something the player is already reading. The shop additionally
  /// drains the belt before it opens, so in practice this is called with
  /// nothing in flight at all — belt and braces, because this is the exact
  /// seam where randomness could start resolving after a decision.
  void applyModifier(TuningDelta delta) {
    _modifiers = _modifiers + delta;
    _retune();
  }

  /// Recomputes the live numbers.
  ///
  /// Called when the pressure index moves or a modifier is applied — not per
  /// frame. It ends with [_checkEnd] so that a change which puts the run past
  /// its mistake limit takes effect immediately, rather than waiting for the
  /// next scoring event.
  void _retune() {
    _tuning = RunTuning.resolve(
      level: level,
      pressure: pressure,
      modifiers: _modifiers,
    );
    _checkEnd();
  }

  /// Abandons the run without an outcome.
  void quit() {
    _phase = RunPhase.finished;
  }

  void update(double dt) {
    if (_phase == RunPhase.ending) {
      _endingTimer -= dt;
      if (_endingTimer <= 0) {
        _phase = RunPhase.finished;
      }
      return;
    }
    if (_phase != RunPhase.running) {
      return;
    }

    _elapsed += dt;

    for (final package in _active) {
      package.progress += dt / package.readWindow;
      _advanceCorruption(package);
    }

    var anyDropped = false;
    _active.removeWhere((package) {
      if (package.progress < 1.0) {
        return false;
      }
      score.registerDrop();
      _events.add(const PackageDroppedEvent());
      anyDropped = true;
      return true;
    });
    if (anyDropped && _checkEnd()) {
      return;
    }
    _maybeOpenShop();

    _spawnTimer += dt;
    // Hold the belt while a layout warning is up, or while draining for the
    // shop. A package that appeared after the warning would still be in flight
    // when the chutes moved; a package that appeared during the drain would
    // postpone a shop that is supposed to open on an empty belt.
    if (_telegraph == null &&
        !_drainingForShop &&
        _spawnTimer >= _tuning.spawnInterval &&
        _active.length < _tuning.maxActive) {
      // Reset rather than subtract, so a backlog cannot burst-spawn several
      // packages the instant the belt clears.
      _spawnTimer = 0;
      _spawn();
    }

    _tickBoard(dt);
  }

  /// Routes the front-most package into [binIndex].
  ///
  /// Tapping with an empty belt is a no-op: never a mistake, never a score
  /// change. Each tap consumes at most one package, so rapid tapping can
  /// never double-route.
  TapResult tapBin(int binIndex) {
    if (_phase != RunPhase.running) {
      return TapResult.ignored;
    }
    if (binIndex < 0 || binIndex >= liveBinCount) {
      return TapResult.ignored;
    }
    final package = frontMost;
    if (package == null) {
      return TapResult.ignored;
    }

    // Measured before the package leaves the belt: how long it had left.
    final clutch = (1 - package.progress) * package.readWindow <= clutchWindow;

    _active.remove(package);

    if (binFor(package.spec) == binIndex) {
      final tierBefore = score.comboTier;
      final gained = score.registerCorrect(
        clutch: clutch,
        scorePercent: _tuning.scorePercent,
        payPercent: _tuning.payPercent,
      );
      final tierAfter = score.comboTier;
      _events.add(
        PackageSortedEvent(
          binIndex: binIndex,
          gained: gained,
          tier: tierAfter,
          clutch: clutch,
        ),
      );
      if (tierAfter > tierBefore) {
        _events.add(ComboAdvancedEvent(tierAfter));
      }
      // A correct sort moves the pressure index, so the numbers are resolved
      // again here. `_retune` ends with the same `_checkEnd` this used to do.
      _retune();
      _considerGrow();
      _considerShop();
      _maybeOpenShop();
      return TapResult.correct;
    }

    score.registerMisroute();
    _events.add(PackageMisroutedEvent(binIndex));
    _checkEnd();
    _maybeOpenShop();
    return TapResult.misroute;
  }

  /// Returns and clears pending events.
  ///
  /// Drained every frame by the presentation layer and empty on most of them,
  /// so the empty case must not allocate.
  List<RunEvent> drainEvents() {
    if (_events.isEmpty) {
      return const [];
    }
    final drained = List<RunEvent>.of(_events);
    _events.clear();
    return drained;
  }

  bool _checkEnd() {
    if (level.passCondition.isMetBy(score)) {
      _end(RunOutcome.passed);
      return true;
    }
    final limit = _tuning.mistakeLimit;
    if (limit != null && score.mistakes >= limit) {
      _end(RunOutcome.failed);
      return true;
    }
    return false;
  }

  void _end(RunOutcome outcome) {
    _outcome = outcome;
    _phase = RunPhase.ending;
    _endingTimer = endingDuration;
    // The belt is left standing rather than cleared: it halts in place so the
    // player can see the state they ended in. Sweeping it would read as a
    // crash, which is the thing the ending phase exists to avoid.
    _events.add(RunEndedEvent(outcome));
  }

  /// Runs the telegraph and the shape change for a `DAMAGED` package.
  void _advanceCorruption(ActivePackage package) {
    final morphAt = package.morphAt;
    if (morphAt == null || package._morphed) {
      return;
    }
    if (package.progress >= morphAt) {
      package._spec = package.morphTo!;
      package._morphed = true;
      package._unstable = false;
      _events.add(PackageMorphedEvent(package.id));
      return;
    }
    package._unstable = (morphAt - package.progress) * package.readWindow <=
        package.telegraphSeconds;
  }

  /// An ordinary package, taking the level's read window as it stands now.
  ActivePackage _plain(PackageSpec spec) => ActivePackage(
        id: _nextId++,
        spec: spec,
        readWindow: _tuning.readWindow,
        telegraphSeconds: _tuning.telegraphSeconds,
      );

  void _spawn() {
    final board = _board;
    final spec = board != null
        ? _rng.pick(board.order)
        : (level.spawnPool != null
            ? _rng.pick(level.spawnPool!)
            : PackageSpec(
                shape: _rng.pick(level.shapes),
                colorIndex: _rng.pick(level.colors),
              ));

    // Guarded so a level with no chaos draws exactly the numbers it always
    // did: turning chaos on must not silently reseed every other level.
    if (_tuning.chaosRate <= 0 || _rng.nextDouble() >= _tuning.chaosRate) {
      final priorityRate = _priorityRate;
      if (priorityRate > 0 && _rng.nextDouble() < priorityRate) {
        _active.add(
          _plain(
            PackageSpec(
              shape: spec.shape,
              colorIndex: spec.colorIndex,
              stamp: PackageStamp.priority,
            ),
          ),
        );
        return;
      }
      _active.add(_plain(spec));
      return;
    }

    // Corrupt whatever the level actually reads. On a shape-routed level the
    // silhouette changes; on a colour-routed one the hue and its paired
    // pattern do. Either way the destination moves, which is the point.
    final damagedSpec = PackageSpec(
      shape: spec.shape,
      colorIndex: spec.colorIndex,
      stamp: PackageStamp.damaged,
    );
    final alternatives = _corruptionTargets(spec);
    if (alternatives.isEmpty) {
      // A level with only one value of the attribute it routes on cannot
      // express a corruption. Not an error — level 1 is exactly this — so it
      // simply spawns clean.
      _active.add(_plain(spec));
      return;
    }

    // The morph window is bounded at both ends on purpose. Its start is late
    // enough that the whole telegraph is visible after spawn, and its end
    // leaves at least a quarter of the read window to act on what the package
    // became. Chaos escalates by shortening the warning, never by removing
    // the chance to respond.
    final earliest = (_tuning.telegraphSeconds / _tuning.readWindow)
        .clamp(0.0, _latestMorph);
    final morphAt = earliest + _rng.nextDouble() * (_latestMorph - earliest);

    _active.add(
      ActivePackage(
        id: _nextId++,
        spec: damagedSpec,
        readWindow: _tuning.readWindow,
        telegraphSeconds: _tuning.telegraphSeconds,
        morphAt: morphAt,
        morphTo: _rng.pick(alternatives),
      ),
    );
  }

  List<PackageSpec> _corruptionTargets(PackageSpec spec) {
    final board = _board;
    if (board != null) {
      return [
        for (final chute in board.order)
          if (chute.shape != spec.shape || chute.colorIndex != spec.colorIndex)
            PackageSpec(
              shape: chute.shape,
              colorIndex: chute.colorIndex,
              stamp: PackageStamp.damaged,
            ),
      ];
    }
    return switch (level.routing.reads) {
      RoutedAttribute.shape => [
          for (final shape in level.shapes)
            if (shape != spec.shape)
              PackageSpec(
                shape: shape,
                colorIndex: spec.colorIndex,
                stamp: PackageStamp.damaged,
              ),
        ],
      RoutedAttribute.colour => [
          for (final hue in level.colors)
            if (hue != spec.colorIndex)
              PackageSpec(
                shape: spec.shape,
                colorIndex: hue,
                stamp: PackageStamp.damaged,
              ),
        ],
      RoutedAttribute.compound => [
          for (final bin in level.routing.bins)
            if (bin.shape != spec.shape || bin.pattern != spec.pattern)
              PackageSpec(
                shape: bin.shape!,
                colorIndex: FillPattern.values.indexOf(bin.pattern!),
                stamp: PackageStamp.damaged,
              ),
        ],
    };
  }

  void _tickBoard(double dt) {
    if (_board == null) {
      return;
    }
    final pending = _telegraph;
    if (pending != null) {
      pending.remaining -= dt;
      if (pending.remaining <= 0) {
        _applyTelegraph();
      }
      return;
    }
    if (_drainingForShop) {
      return;
    }
    if (_elapsed >= _nextSwapAt) {
      _considerSwap();
    }
  }

  void _considerGrow() {
    final board = _board;
    if (board == null || _telegraph != null) {
      return;
    }
    final target = EndlessBoard.targetCount(pressure);
    if (target <= board.length) {
      return;
    }
    final extra = EndlessBoard.ladder[board.length];
    _beginTelegraph(
      LayoutChangeKind.grow,
      board.grown(extra),
      {board.length},
    );
  }

  void _considerSwap() {
    final board = _board;
    if (board == null || _telegraph != null || board.length < 2) {
      return;
    }
    _nextSwapAt = _elapsed + EndlessBoard.swapInterval;
    final pair = _rng.take(List<int>.generate(board.length, (i) => i), 2);
    _beginTelegraph(
      LayoutChangeKind.swap,
      board.swapped(pair[0], pair[1]),
      pair.toSet(),
    );
  }

  void _beginTelegraph(
    LayoutChangeKind kind,
    ChuteBoard next,
    Set<int> highlighted,
  ) {
    // At least the live read window, and at least as long as any package
    // still on the belt has left — a shorter warning would change the
    // destination under a thumb that already committed.
    var duration = _tuning.readWindow;
    for (final package in _active) {
      final left = (1 - package.progress) * package.readWindow;
      if (left > duration) {
        duration = left;
      }
    }
    _telegraph = LayoutTelegraph(
      kind: kind,
      next: next,
      duration: duration,
      highlighted: highlighted,
    );
    _events.add(LayoutTelegraphEvent(kind));
  }

  void _applyTelegraph() {
    final pending = _telegraph;
    if (pending == null) {
      return;
    }
    _board = pending.next;
    _telegraph = null;
    if (pending.kind == LayoutChangeKind.grow) {
      _nextSwapAt = _elapsed + EndlessBoard.swapInterval;
    }
    _events.add(LayoutChangedEvent(pending.kind));
    // A swap can straddle a grow threshold. Recheck once the board is live.
    _considerGrow();
    _considerShop();
    _maybeOpenShop();
  }

  double get _priorityRate {
    if (level.priorityRate > 0) {
      return level.priorityRate;
    }
    if (_board != null && pressure >= EndlessBoard.priorityAt) {
      return EndlessBoard.priorityRate;
    }
    return 0;
  }

  void _considerShop() {
    if (_board == null ||
        _telegraph != null ||
        _drainingForShop ||
        _phase != RunPhase.running) {
      return;
    }
    if (_nextBlind >= EndlessShop.blinds.length) {
      return;
    }
    if (pressure < EndlessShop.blinds[_nextBlind]) {
      return;
    }
    _drainingForShop = true;
  }

  void _maybeOpenShop() {
    if (!_drainingForShop ||
        _active.isNotEmpty ||
        _phase != RunPhase.running) {
      return;
    }
    _shopOffers = _shopRng.take(
      List<CardSpec>.of(EndlessShop.catalog),
      EndlessShop.offerCount,
    );
    _drainingForShop = false;
    _phase = RunPhase.shopping;
    _events.add(ShopOpenedEvent(_shopOffers));
  }

  /// Pins a memo. No-op if the shop is closed or the run cannot afford it.
  bool buy(int index) {
    if (_phase != RunPhase.shopping) {
      return false;
    }
    if (index < 0 || index >= _shopOffers.length) {
      return false;
    }
    final card = _shopOffers[index];
    if (!score.spend(card.cost)) {
      return false;
    }
    applyModifier(card.delta);
    _pinned.add(card);
    _closeShop();
    return true;
  }

  /// Leaves the memos on the wall. Always legal.
  void skipShop() {
    if (_phase != RunPhase.shopping) {
      return;
    }
    _closeShop();
  }

  void _closeShop() {
    _shopOffers = const [];
    _nextBlind++;
    _phase = RunPhase.running;
    _spawnTimer = 0;
  }
}
