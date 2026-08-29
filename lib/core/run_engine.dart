import 'dart:collection';

import 'board.dart';
import 'difficulty.dart';
import 'level_config.dart';
import 'package_spec.dart';
import 'routing.dart';
import 'run_tuning.dart';
import 'score_state.dart';
import 'shift_events.dart';
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
    this.lane = 0,
    this.morphAt,
    this.morphTo,
  }) : _spec = spec;

  final int id;

  /// Horizontal position across the belt lane, in package-width steps.
  ///
  /// Zero is dead centre, which is where every package sat before clusters
  /// existed and where a solo package still sits. A cluster spreads its
  /// members symmetrically — `-1, 0, +1` for three — so they read as separate
  /// objects rather than one column.
  ///
  /// Derived from the member's index in its cluster, never rolled, so the
  /// replay contract is untouched: same seed plus same taps still reproduces
  /// the run exactly.
  final double lane;

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

/// A quota contract just paid out or forfeited. Presentation may stamp it;
/// the wallet has already moved.
class QuotaSettledEvent extends RunEvent {
  const QuotaSettledEvent({required this.success, required this.segmentPay});

  final bool success;

  /// Pay earned during the contract — doubled on success, stripped on fail.
  final int segmentPay;
}

/// The whole game, minus rendering.
///
/// Imports neither Flame nor Flutter. This is what makes the scoring, combo,
/// routing, and state-transition tests possible without a game loop or a
/// widget tree, and it is the main defence against hidden coupling.
class RunEngine {
  RunEngine({
    required this.level,
    required this.seed,
    int startingPay = 0,
  })  : _rng = SeededRng(seed),
        // Own stream, derived from the run seed, so a shop draw can never
        // shift package spawns. XOR is a bijection: every seed still maps
        // to a distinct shop stream.
        _shopRng = SeededRng(seed ^ 0x51A70FF),
        _tuning = RunTuning.resolve(level: level),
        _board = level.curve == null
            ? null
            : ChuteBoard(
                EndlessBoard.ladder.sublist(0, EndlessBoard.openingCount),
              ) {
    if (_board != null) {
      score.pay = EndlessShop.clampWallet(startingPay);
    }
  }

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

  /// Progress at which a scanned package shows its label.
  ///
  /// Does not touch [ActivePackage.readWindow]. On the 1.20s floor the
  /// clutch window begins at ~0.583, so the label appears already inside
  /// the save — that is the designed interaction, not a coincidence.
  /// See docs/decision-log.md, "Scanner reveal as a progress threshold".
  static const double scannerRevealAt = 0.60;

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
  int _redrawsThisBoard = 0;
  List<CardSpec> _shopOffers = const [];
  final List<CardSpec> _pinned = [];
  ShiftEventSpec? _pendingEvent;
  ShiftEventSpec? _liveEvent;
  bool _hazardousCargo = false;
  bool _scannerReveal = false;
  bool _quotaLive = false;
  bool _quotaMissed = false;
  int _quotaPayStart = 0;
  int _quotaSortedStart = 0;
  int _quotaTarget = 0;

  /// The numbers the belt is running on right now — the level as modified by
  /// the difficulty curve and anything the player has bought. Read this, never
  /// [level], for anything that can change during a run.
  RunTuning get tuning => _tuning;

  /// Live chute count. Endless opens at two and grows; curated is fixed.
  int get liveBinCount => _board?.length ?? level.binCount;

  /// Where [package] belongs *right now*. Endless reads the live board, which
  /// can swap and grow; curated reads the level's rule, which never moves.
  ///
  /// Under hazardous cargo this is the *forbidden* chute, not the tap.
  int binFor(PackageSpec package) =>
      _board?.binFor(package) ?? level.routing.binFor(package);

  /// Whether tapping [binIndex] is a correct sort for [package].
  ///
  /// Hazardous cargo flips unique-destination equality into avoid-the-match.
  /// Autoplay, tests, and [tapBin] all go through here.
  bool isCorrectBin(PackageSpec package, int binIndex) {
    final unique = binFor(package);
    if (!_hazardousCargo) {
      return unique == binIndex;
    }
    return hazardousAccepts(unique, binIndex, liveBinCount);
  }

  /// Whether the scanner has uncovered [package]'s identity.
  ///
  /// A visibility rule, not a tap target. Progress threshold only.
  bool labelVisible(ActivePackage package) =>
      !_scannerReveal || package.progress >= scannerRevealAt;

  /// Every later package is two-valid / one-forbidden. Pin lasts the run.
  bool get hazardousCargo => _hazardousCargo;

  /// Labels stay hidden until [scannerRevealAt]. Pin lasts the run.
  bool get scannerReveal => _scannerReveal;

  /// A quota contract is armed and has not yet paid out or forfeited.
  bool get quotaLive => _quotaLive;

  /// Clean sorts still needed to close the live contract. Zero when idle.
  int get quotaTarget => _quotaLive ? _quotaTarget : 0;

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

  /// What the next `ASK AGAIN` costs on this board.
  int get redrawCost => EndlessShop.redrawCost(_redrawsThisBoard);

  /// Memos pinned this run, in buy order. Lasts until the run ends.
  List<CardSpec> get pinned => List.unmodifiable(_pinned);

  /// Named rule printed on the open board. Not applied until the board
  /// closes. Null when the shop is shut.
  ShiftEventSpec? get pendingEvent => _pendingEvent;

  /// Named rule currently running this band. Expires when the next shop
  /// opens, or when the run ends.
  ShiftEventSpec? get liveEvent => _liveEvent;

  bool get isShopping => _phase == RunPhase.shopping;

  /// Fill of the current pressure band, 0–1. Curated levels have no band.
  double get pressureProgress =>
      _board == null ? 0 : EndlessBoard.pressureProgress(pressure);

  /// Pressure index. Increments per correct sort and never decreases, which
  /// is exactly what `score.sorted` already does — so there is no second
  /// counter to keep in step.
  int get pressure => score.sorted;

  RunPhase _phase = RunPhase.ready;
  RunOutcome _outcome = RunOutcome.none;
  double _spawnTimer = 0;

  /// Seconds until the next spawn. Equal to `spawnInterval` outside a cluster;
  /// shorter inside one and longer after it, so the average holds.
  double _spawnDue = 0;

  /// Members still owed by the cluster in progress.
  int _burstLeft = 0;

  /// Size of the cluster in progress, kept so the recovery gap can be sized
  /// to keep the average spacing at `spawnInterval`.
  int _burstSize = 1;
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
    _resetBurst();
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
    score.pay = pay;
    _openShop();
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
    _pendingEvent = null;
    _liveEvent = null;
    _modifiers = TuningDelta.none;
    _hazardousCargo = false;
    _scannerReveal = false;
    _clearQuota();
    for (final card in pins) {
      _modifiers = _modifiers + card.delta;
      _activateMechanic(card.mechanic);
    }
    _snapBoardToPressure();
    _retune();
    // P=32 is already past the first blind. Skip blinds the jump leapt over
    // so the board does not slam open on the first frame of a roll review.
    while (_nextBlind < EndlessShop.blinds.length &&
        pressure >= _shopThreshold(_nextBlind)) {
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
    score.comboCap = _tuning.maxComboTier;
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
      score.registerDrop(scorePenalty: _missScorePenalty);
      _events.add(const PackageDroppedEvent());
      _quotaForfeit();
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
        _spawnTimer >= _spawnDueOrInterval &&
        _active.length < _tuning.maxActive) {
      // Reset rather than subtract, so a backlog cannot burst-spawn several
      // packages the instant the belt clears.
      _spawnTimer = 0;
      _spawnFromSchedule();
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

    if (isCorrectBin(package.spec, binIndex)) {
      final tierBefore = score.comboTier;
      var scorePercent = _tuning.scorePercent;
      if (package.spec.stamp == PackageStamp.priority) {
        scorePercent += _tuning.priorityScorePercent;
      }
      final gained = score.registerCorrect(
        clutch: clutch,
        scorePercent: scorePercent,
        payPercent: _tuning.payPercent,
        clutchBonus: _tuning.clutchBonus,
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
      _quotaCheckSuccess();
      _considerGrow();
      _considerShop();
      _maybeOpenShop();
      return TapResult.correct;
    }

    score.registerMisroute(scorePenalty: _missScorePenalty);
    _events.add(PackageMisroutedEvent(binIndex));
    _quotaForfeit();
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
  ActivePackage _plain(PackageSpec spec, {double lane = 0}) => ActivePackage(
        id: _nextId++,
        spec: spec,
        readWindow: _tuning.readWindow,
        telegraphSeconds: _tuning.telegraphSeconds,
        lane: lane,
      );

  /// The interval currently in force. Falls back to the plain spawn interval
  /// until the first cluster is scheduled.
  double get _spawnDueOrInterval =>
      _spawnDue > 0 ? _spawnDue : _tuning.spawnInterval;

  /// Emits one package and schedules the next.
  ///
  /// A cluster of `n` is emitted `burstGapFraction * spawnInterval` apart and
  /// is followed by a recovery gap sized so the whole cycle still takes
  /// `spawnInterval * n`. **Average spacing is therefore unchanged** — the
  /// belt receives packages lumpy rather than metronomic, which is the only
  /// density lever left once the read window and spawn interval are both
  /// pinned to their fairness floors.
  void _spawnFromSchedule() {
    final interval = _tuning.spawnInterval;
    final curve = level.curve;

    if (_burstLeft <= 0) {
      _burstSize = curve == null ? 1 : curve.burstSizeAt(pressure);
      _burstLeft = _burstSize;
    }

    final index = _burstSize - _burstLeft;
    _spawn(lane: _laneFor(index, _burstSize));
    _burstLeft--;

    if (_burstLeft > 0) {
      _spawnDue = interval * EndlessCurve.burstGapFraction;
      return;
    }
    // Recovery: what is left of the cluster's share of the clock.
    final spent =
        interval * EndlessCurve.burstGapFraction * (_burstSize - 1);
    final recovery = interval * _burstSize - spent;
    _spawnDue = recovery < interval ? interval : recovery;
  }

  void _resetBurst() {
    _burstLeft = 0;
    _burstSize = 1;
    _spawnDue = 0;
  }

  /// Symmetric spread: `0` alone, `-0.5/+0.5` for a pair, `-1/0/+1` for three.
  static double _laneFor(int index, int size) =>
      size <= 1 ? 0 : index - (size - 1) / 2;

  void _spawn({double lane = 0}) {
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
            lane: lane,
          ),
        );
        return;
      }
      _active.add(_plain(spec, lane: lane));
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
    _nextSwapAt = _elapsed + _tuning.swapInterval;
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
      _nextSwapAt = _elapsed + _tuning.swapInterval;
    }
    _events.add(LayoutChangedEvent(pending.kind));
    // A swap can straddle a grow threshold. Recheck once the board is live.
    _considerGrow();
    _considerShop();
    _maybeOpenShop();
  }

  double get _priorityRate {
    var base = 0.0;
    if (level.priorityRate > 0) {
      base = level.priorityRate;
    } else if (_board != null && pressure >= EndlessBoard.priorityAt) {
      base = EndlessBoard.priorityRate;
    }
    final rate = base + _tuning.priorityRate;
    if (rate <= 0) {
      return 0;
    }
    if (rate > 1) {
      return 1;
    }
    return rate;
  }

  /// How many current-tier sorts a miss deducts. Zero when the memo is off.
  int get _missScorePenalty {
    if (_tuning.missScorePenalty <= 0) {
      return 0;
    }
    return RunScore.baseValue *
        score.comboTier *
        _tuning.scorePercent ~/
        100 *
        _tuning.missScorePenalty;
  }

  /// Pressure that opens board [index]. The first blind never shifts — that
  /// is how the player reaches the memo that would delay the others.
  int _shopThreshold(int index) {
    final shift = index == 0 ? 0 : _tuning.blindShift;
    return EndlessShop.blinds[index] + shift;
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
    if (pressure < _shopThreshold(_nextBlind)) {
      return;
    }
    _drainingForShop = true;
  }

  void _maybeOpenShop() {
    if (!_drainingForShop || _active.isNotEmpty || _phase != RunPhase.running) {
      return;
    }
    _openShop();
  }

  /// Belt is empty. Expire the last band's event, draw the hand, draw one
  /// event for the *next* band. ASK AGAIN later replaces the slips only.
  void _openShop() {
    _quotaSucceedIfLive();
    _expireLiveEvent();
    _redrawsThisBoard = 0;
    _shopOffers = _drawHand();
    _pendingEvent = _board == null ? null : _drawEvent();
    _drainingForShop = false;
    _phase = RunPhase.shopping;
    _events.add(ShopOpenedEvent(_shopOffers));
  }

  ShiftEventSpec _drawEvent() =>
      _shopRng.pick(List<ShiftEventSpec>.of(ShiftEvents.catalog));

  void _expireLiveEvent() {
    final live = _liveEvent;
    if (live == null) {
      return;
    }
    final previousInterval = _tuning.swapInterval;
    _modifiers = _modifiers + live.delta.negated;
    _liveEvent = null;
    _retune();
    _rescheduleSwapIfNeeded(previousInterval);
  }

  void _applyPendingEvent() {
    final event = _pendingEvent;
    if (event == null) {
      return;
    }
    final previousInterval = _tuning.swapInterval;
    _liveEvent = event;
    _pendingEvent = null;
    _modifiers = _modifiers + event.delta;
    _retune();
    _rescheduleSwapIfNeeded(previousInterval);
  }

  void _rescheduleSwapIfNeeded(double previousInterval) {
    if (_tuning.swapInterval != previousInterval) {
      _nextSwapAt = _elapsed + _tuning.swapInterval;
    }
  }

  List<CardSpec> _drawHand() {
    final drawn = _shopRng.take(
      List<CardSpec>.of(EndlessShop.catalog),
      EndlessShop.offerCount,
    );
    return [
      for (final card in drawn)
        card.withCost(
          EndlessShop.slipCost(
            card,
            _nextBlind,
            extraBump: _tuning.costBump,
          ),
        ),
    ];
  }

  /// Pays for a new hand. No-op if the shop is closed or the run cannot
  /// afford the live redraw cost. Does not close the board.
  bool redrawShop() {
    if (_phase != RunPhase.shopping) {
      return false;
    }
    if (!score.spend(redrawCost)) {
      return false;
    }
    _shopOffers = _drawHand();
    _redrawsThisBoard++;
    return true;
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
    _activateMechanic(card.mechanic);
    _closeShop();
    return true;
  }

  /// Test/debug. Pins [card] as if bought on a drained belt. Does not
  /// spend pay and does not close a shop. Unused by any release path.
  void debugPin(CardSpec card) {
    if (_phase == RunPhase.ready) {
      start();
    }
    applyModifier(card.delta);
    _pinned.add(card);
    _activateMechanic(card.mechanic);
  }

  /// Leaves the memos on the wall. Always legal.
  void skipShop() {
    if (_phase != RunPhase.shopping) {
      return;
    }
    _closeShop();
  }

  void _closeShop() {
    _applyPendingEvent();
    _shopOffers = const [];
    _redrawsThisBoard = 0;
    _nextBlind++;
    _phase = RunPhase.running;
    _spawnTimer = 0;
    // The board drains the belt, so a half-emitted cluster must not resume
    // across it and land its remainder on an empty belt at cluster spacing.
    _resetBurst();
  }

  void _activateMechanic(CardMechanic mechanic) {
    switch (mechanic) {
      case CardMechanic.none:
        return;
      case CardMechanic.quota:
        _armQuota();
      case CardMechanic.hazardous:
        _hazardousCargo = true;
      case CardMechanic.scanner:
        _scannerReveal = true;
    }
  }

  void _armQuota() {
    _quotaLive = true;
    _quotaMissed = false;
    _quotaPayStart = score.pay;
    _quotaSortedStart = score.sorted;
    _quotaTarget = _quotaTargetForCurrentBoard();
  }

  int _quotaTargetForCurrentBoard() {
    if (_board == null) {
      return EndlessShop.quotaLastBandTarget;
    }
    final next = _nextBlind + 1;
    if (next >= EndlessShop.blinds.length) {
      return EndlessShop.quotaLastBandTarget;
    }
    final remaining = _shopThreshold(next) - score.sorted;
    return remaining < 1 ? EndlessShop.quotaLastBandTarget : remaining;
  }

  void _quotaCheckSuccess() {
    if (!_quotaLive || _quotaMissed) {
      return;
    }
    if (score.sorted - _quotaSortedStart < _quotaTarget) {
      return;
    }
    _quotaPayout();
  }

  void _quotaSucceedIfLive() {
    if (!_quotaLive || _quotaMissed) {
      return;
    }
    _quotaPayout();
  }

  void _quotaPayout() {
    final earned = score.pay - _quotaPayStart;
    score.pay = _quotaPayStart + earned * 2;
    _events.add(QuotaSettledEvent(success: true, segmentPay: earned));
    _clearQuota();
  }

  void _quotaForfeit() {
    if (!_quotaLive || _quotaMissed) {
      return;
    }
    _quotaMissed = true;
    final earned = score.pay - _quotaPayStart;
    score.pay = _quotaPayStart;
    _events.add(QuotaSettledEvent(success: false, segmentPay: earned));
    _clearQuota();
  }

  void _clearQuota() {
    _quotaLive = false;
    _quotaMissed = false;
    _quotaPayStart = 0;
    _quotaSortedStart = 0;
    _quotaTarget = 0;
  }
}
