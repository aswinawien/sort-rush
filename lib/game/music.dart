import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'music_catalog.dart';

/// Music playback. Atmosphere only.
///
/// The constitution is explicit that no gameplay information may be carried by
/// audio, so nothing here is allowed to become a cue. A muted run and an
/// unmuted run must be exactly as winnable.
abstract class MusicBus {
  /// Which assets actually shipped. Resolution is done against this rather
  /// than assumed, because the soundtrack lands in pieces.
  set available(Set<String> assets);

  set muted(bool value);

  Future<void> playHome();

  Future<void> playLevel(int levelId);

  Future<void> playEndless();

  /// 0 at the opening, 1 at full pressure. Ignored outside endless.
  void setEndlessMix(double t);

  Future<void> stop();

  void dispose();
}

/// Used by tests and by any build with no audio.
class SilentMusic implements MusicBus {
  const SilentMusic();

  @override
  set available(Set<String> assets) {}

  @override
  set muted(bool value) {}

  @override
  Future<void> playHome() async {}

  @override
  Future<void> playLevel(int levelId) async {}

  @override
  Future<void> playEndless() async {}

  @override
  void setEndlessMix(double t) {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

/// Records calls instead of playing. Lets the wiring be asserted without
/// audio hardware, which no test runner has.
class RecordingMusic implements MusicBus {
  final List<String> calls = [];
  Set<String> assets = const {};
  bool isMuted = false;
  double mix = 0;

  @override
  set available(Set<String> value) => assets = value;

  @override
  set muted(bool value) {
    isMuted = value;
    calls.add('muted:$value');
  }

  @override
  Future<void> playHome() async => calls.add('home');

  @override
  Future<void> playLevel(int levelId) async {
    calls.add('level:$levelId:${MusicCatalog.resolveLevel(levelId, assets)}');
  }

  @override
  Future<void> playEndless() async => calls.add('endless');

  @override
  void setEndlessMix(double t) => mix = t;

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  void dispose() {}
}

/// Two looping players: one for the current track, one for the endless
/// high-pressure layer that crossfades against it.
class AssetMusic implements MusicBus {
  AssetMusic();

  /// Created on first playback, never at construction.
  ///
  /// `SynthSfx` pools lazily for the same reason: building a platform player
  /// in a test binding never settles, and a controller that cannot be built in
  /// a test is a controller that cannot be tested.
  AudioPlayer? _aPlayer;
  AudioPlayer? _bPlayer;

  AudioPlayer get _a => _aPlayer ??= AudioPlayer();
  AudioPlayer get _b => _bPlayer ??= AudioPlayer();

  Set<String> _available = const {};
  bool _muted = false;
  bool _endless = false;
  double _mix = 0;
  String? _current;

  @override
  set available(Set<String> assets) => _available = assets;

  @override
  set muted(bool value) {
    if (_muted == value) {
      return;
    }
    _muted = value;
    _applyVolume();
  }

  double get _base => _muted ? 0 : 0.55;

  void _applyVolume() {
    // Nothing has played yet; there is no volume to set.
    if (_aPlayer == null && _bPlayer == null) {
      return;
    }
    if (_endless) {
      _aPlayer?.setVolume(_base * (1 - _mix));
      _bPlayer?.setVolume(_base * _mix);
    } else {
      _aPlayer?.setVolume(_base);
      _bPlayer?.setVolume(0);
    }
  }

  Future<void> _loop(AudioPlayer player, String asset) async {
    await player.setReleaseMode(ReleaseMode.loop);
    await player.play(AssetSource(asset));
  }

  @override
  Future<void> playHome() => _single(MusicCatalog.home);

  @override
  Future<void> playLevel(int levelId) {
    final asset = MusicCatalog.resolveLevel(levelId, _available);
    if (asset == null) {
      return stop();
    }
    return _single(asset);
  }

  Future<void> _single(String asset) async {
    if (!_available.contains(asset)) {
      return stop();
    }
    _endless = false;
    _mix = 0;
    if (_current == asset) {
      _applyVolume();
      return;
    }
    await _guard(() async => _bPlayer?.stop());
    await _guard(() => _loop(_a, asset));
    // Recorded only once playback was attempted. Setting it first meant a
    // failed decode left `_current` naming a track that was not playing, and
    // the short-circuit above then refused to retry it for the session.
    _current = asset;
    _applyVolume();
  }

  @override
  Future<void> playEndless() async {
    final low = MusicCatalog.endlessLow;
    final high = MusicCatalog.endlessHigh;
    if (!_available.contains(low)) {
      return stop();
    }
    _endless = true;
    // Reset with the run, like `_single` does. Carrying the previous run's
    // value meant a second endless run could open with the high-pressure
    // layer at full until the loop's first mix update corrected it.
    _mix = 0;
    _current = low;
    await _guard(() => _loop(_a, low));
    if (_available.contains(high)) {
      await _guard(() => _loop(_b, high));
    }
    _applyVolume();
  }

  @override
  void setEndlessMix(double t) {
    final clamped = t < 0 ? 0.0 : (t > 1 ? 1.0 : t);
    // Only move on a visible step. Setting volume every frame is a platform
    // channel call per player per frame, which is exactly the kind of cost
    // that never shows up on desktop.
    if ((clamped - _mix).abs() < 0.02) {
      return;
    }
    _mix = clamped;
    _applyVolume();
  }

  @override
  Future<void> stop() async {
    _current = null;
    _endless = false;
    _mix = 0;
    await _guard(() async => _aPlayer?.stop());
    await _guard(() async => _bPlayer?.stop());
  }

  /// A missing or unplayable file must never cost the player a run.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('music: $error');
      }
    }
  }

  @override
  void dispose() {
    _aPlayer?.dispose();
    _bPlayer?.dispose();
    _aPlayer = null;
    _bPlayer = null;
  }
}
