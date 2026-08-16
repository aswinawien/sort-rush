import 'dart:collection';

import 'level_config.dart';
import 'package_spec.dart';
import 'routing.dart';
import 'run_tuning.dart';
import 'score_state.dart';
import 'tuning_delta.dart';
import 'seeded_rng.dart';

/// Where a run is in its lifecycle.
enum RunPhase { ready, running, paused, ending, finished }

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

/// The whole game, minus rendering.
///
/// Imports neither Flame nor Flutter. This is what makes the scoring, combo,
/// routing, and state-transition tests possible without a game loop or a
/// widget tree, and it is the main defence against hidden coupling.
class RunEngine {
  RunEngine({required this.level, required this.seed})
      : _rng = SeededRng(seed),
        _tuning = RunTuning.resolve(level: level);

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
  final RunScore score = RunScore();
  final List<ActivePackage> _active = [];
  final List<RunEvent> _events = [];

  RunTuning _tuning;
  TuningDelta _modifiers = TuningDelta.none;

  /// The numbers the belt is running on right now — the level as modified by
  /// the difficulty curve and anything the player has bought. Read this, never
  /// [level], for anything that can change during a run.
  RunTuning get tuning => _tuning;

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

    _spawnTimer += dt;
    if (_spawnTimer >= _tuning.spawnInterval &&
        _active.length < _tuning.maxActive) {
      // Reset rather than subtract, so a backlog cannot burst-spawn several
      // packages the instant the belt clears.
      _spawnTimer = 0;
      _spawn();
    }
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
    if (binIndex < 0 || binIndex >= level.binCount) {
      return TapResult.ignored;
    }
    final package = frontMost;
    if (package == null) {
      return TapResult.ignored;
    }

    // Measured before the package leaves the belt: how long it had left.
    final clutch = (1 - package.progress) * package.readWindow <= clutchWindow;

    _active.remove(package);

    if (level.routing.binFor(package.spec) == binIndex) {
      final tierBefore = score.comboTier;
      final gained = score.registerCorrect(clutch: clutch);
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
      return TapResult.correct;
    }

    score.registerMisroute();
    _events.add(PackageMisroutedEvent(binIndex));
    _checkEnd();
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
    final pool = level.spawnPool;
    final spec = pool != null
        ? _rng.pick(pool)
        : PackageSpec(
            shape: _rng.pick(level.shapes),
            colorIndex: _rng.pick(level.colors),
          );

    // Guarded so a level with no chaos draws exactly the numbers it always
    // did: turning chaos on must not silently reseed every other level.
    if (_tuning.chaosRate <= 0 || _rng.nextDouble() >= _tuning.chaosRate) {
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
    final alternatives = switch (level.routing.reads) {
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
      // On a compound level either attribute could change, but only the pairs
      // that own a chute are legal packages — so the alternatives are simply
      // the other chutes.
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
}
