import 'level_config.dart';
import 'package_spec.dart';
import 'score_state.dart';
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
  ActivePackage({required this.id, required this.spec});

  final int id;
  final PackageSpec spec;

  /// 0 at spawn, 1 at the sort line.
  double progress = 0;
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
  });

  final int binIndex;
  final int gained;
  final int tier;
}

class PackageMisroutedEvent extends RunEvent {
  const PackageMisroutedEvent(this.binIndex);

  final int binIndex;
}

class PackageDroppedEvent extends RunEvent {
  const PackageDroppedEvent();
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
      : _rng = SeededRng(seed);

  /// How long the belt keeps still after a run ends, before results show.
  /// An instant cut on failure reads as a crash and robs the player of the
  /// beat where they work out what just happened.
  static const double endingDuration = 0.9;

  final LevelConfig level;
  final int seed;

  final SeededRng _rng;
  final RunScore score = RunScore();
  final List<ActivePackage> _active = [];
  final List<RunEvent> _events = [];

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

  List<ActivePackage> get active => List.unmodifiable(_active);

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
    return (1 - package.progress) * level.readWindow;
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
      package.progress += dt / level.readWindow;
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
    if (_spawnTimer >= level.spawnInterval && _active.length < level.maxActive) {
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

    _active.remove(package);

    if (level.routing.binFor(package.spec) == binIndex) {
      final tierBefore = score.comboTier;
      final gained = score.registerCorrect();
      final tierAfter = score.comboTier;
      _events.add(
        PackageSortedEvent(binIndex: binIndex, gained: gained, tier: tierAfter),
      );
      if (tierAfter > tierBefore) {
        _events.add(ComboAdvancedEvent(tierAfter));
      }
      _checkEnd();
      return TapResult.correct;
    }

    score.registerMisroute();
    _events.add(PackageMisroutedEvent(binIndex));
    _checkEnd();
    return TapResult.misroute;
  }

  /// Returns and clears pending events.
  List<RunEvent> drainEvents() {
    final drained = List<RunEvent>.of(_events);
    _events.clear();
    return drained;
  }

  bool _checkEnd() {
    if (score.sorted >= level.passTarget) {
      _end(RunOutcome.passed);
      return true;
    }
    final limit = level.mistakeLimit;
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

  void _spawn() {
    _active.add(
      ActivePackage(
        id: _nextId++,
        spec: PackageSpec(
          shape: _rng.pick(level.shapes),
          colorIndex: _rng.pick(level.colors),
        ),
      ),
    );
  }
}
