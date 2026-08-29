import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Gameplay cues from `docs/design-spec.md` §6.
///
/// Presentation-only. The engine does not know this type exists.
abstract class SfxBus {
  const SfxBus();

  void sorted({required int tier, required bool comboUp});

  void misroute();

  void dropped();

  void ended();
}

/// Tests and any surface that has not wired audio.
class SilentSfx implements SfxBus {
  const SilentSfx();

  @override
  void sorted({required int tier, required bool comboUp}) {}

  @override
  void misroute() {}

  @override
  void dropped() {}

  @override
  void ended() {}
}

/// Builds the five spec cues as mono 16-bit WAV. No `Random` — envelopes
/// and pitches are fixed functions of [tier].
abstract final class SfxSynth {
  static const int sampleRate = 22050;

  static Uint8List tick({required int tier}) {
    final freq = 660.0 + 70.0 * _clampTier(tier);
    return _wav(_tone(freq: freq, ms: 45, gain: 0.28));
  }

  static Uint8List comboStab({required int tier}) {
    final base = 740.0 + 50.0 * _clampTier(tier);
    return _wav([
      ..._tone(freq: base, ms: 55, gain: 0.32),
      ..._tone(freq: base * 1.5, ms: 80, gain: 0.3),
    ]);
  }

  static Uint8List thud() => _wav(_tone(freq: 92, ms: 90, gain: 0.4));

  static Uint8List descending() =>
      _wav(_sweep(from: 420, to: 140, ms: 140, gain: 0.3));

  static Uint8List spinDown() =>
      _wav(_sweep(from: 220, to: 48, ms: 280, gain: 0.34));

  static int _clampTier(int tier) {
    if (tier < 1) {
      return 1;
    }
    if (tier > 5) {
      return 5;
    }
    return tier;
  }

  static List<int> _tone({
    required double freq,
    required int ms,
    required double gain,
  }) {
    final n = sampleRate * ms ~/ 1000;
    final out = <int>[];
    for (var i = 0; i < n; i++) {
      final env = 1.0 - (i / n);
      final sample = math.sin(2 * math.pi * freq * i / sampleRate) * gain * env;
      out.add((sample * 32767).round().clamp(-32767, 32767));
    }
    return out;
  }

  static List<int> _sweep({
    required double from,
    required double to,
    required int ms,
    required double gain,
  }) {
    final n = sampleRate * ms ~/ 1000;
    final out = <int>[];
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / n;
      final freq = from + (to - from) * t;
      phase += 2 * math.pi * freq / sampleRate;
      final env = 1.0 - t;
      final sample = math.sin(phase) * gain * env;
      out.add((sample * 32767).round().clamp(-32767, 32767));
    }
    return out;
  }

  static Uint8List _wav(List<int> pcm) {
    final dataSize = pcm.length * 2;
    final bytes = ByteData(44 + dataSize);
    var o = 0;
    void ascii(String s) {
      for (var i = 0; i < s.length; i++) {
        bytes.setUint8(o++, s.codeUnitAt(i));
      }
    }

    ascii('RIFF');
    bytes.setUint32(o, 36 + dataSize, Endian.little);
    o += 4;
    ascii('WAVE');
    ascii('fmt ');
    bytes.setUint32(o, 16, Endian.little);
    o += 4;
    bytes.setUint16(o, 1, Endian.little);
    o += 2;
    bytes.setUint16(o, 1, Endian.little);
    o += 2;
    bytes.setUint32(o, sampleRate, Endian.little);
    o += 4;
    bytes.setUint32(o, sampleRate * 2, Endian.little);
    o += 4;
    bytes.setUint16(o, 2, Endian.little);
    o += 2;
    bytes.setUint16(o, 16, Endian.little);
    o += 2;
    ascii('data');
    bytes.setUint32(o, dataSize, Endian.little);
    o += 4;
    for (final sample in pcm) {
      bytes.setInt16(o, sample, Endian.little);
      o += 2;
    }
    return bytes.buffer.asUint8List();
  }
}

/// Plays synthesised cues through a small [AudioPlayer] pool.
class SynthSfx implements SfxBus {
  SynthSfx({this.playBytes});

  /// Tests inject a recorder. Production uses a player pool.
  final void Function(Uint8List wav)? playBytes;

  bool muted = false;

  final List<AudioPlayer> _pool = [];
  int _next = 0;
  bool _started = false;

  static const int _poolSize = 4;

  void _ensurePool() {
    if (_started || playBytes != null) {
      return;
    }
    _started = true;
    for (var i = 0; i < _poolSize; i++) {
      _pool.add(AudioPlayer()..setPlayerMode(PlayerMode.lowLatency));
    }
  }

  void _play(Uint8List wav) {
    if (muted) {
      return;
    }
    final injected = playBytes;
    if (injected != null) {
      injected(wav);
      return;
    }
    _ensurePool();
    if (_pool.isEmpty) {
      return;
    }
    final player = _pool[_next];
    _next = (_next + 1) % _pool.length;
    // Unawaited but not unguarded: a rejected future here is an unhandled
    // async error, and a failed tick must never cost the player a run.
    unawaited(
      player.play(BytesSource(wav, mimeType: 'audio/wav')).catchError((_) {}),
    );
  }

  @override
  void sorted({required int tier, required bool comboUp}) {
    _play(comboUp ? SfxSynth.comboStab(tier: tier) : SfxSynth.tick(tier: tier));
  }

  @override
  void misroute() => _play(SfxSynth.thud());

  @override
  void dropped() => _play(SfxSynth.descending());

  @override
  void ended() => _play(SfxSynth.spinDown());

  void dispose() {
    for (final player in _pool) {
      player.dispose();
    }
    _pool.clear();
  }
}
