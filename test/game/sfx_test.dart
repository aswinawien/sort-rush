import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/game/sfx.dart';

void main() {
  test('every cue writes a real WAV, not silence', () {
    final cues = [
      SfxSynth.tick(tier: 1),
      SfxSynth.tick(tier: 5),
      SfxSynth.comboStab(tier: 3),
      SfxSynth.thud(),
      SfxSynth.descending(),
      SfxSynth.spinDown(),
    ];
    for (final wav in cues) {
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(wav.length, greaterThan(44));
      final pcm = wav.sublist(44);
      expect(pcm.any((b) => b != 0), isTrue, reason: 'cue was silence');
    }
  });

  test('a higher combo tick is a different waveform', () {
    expect(
      SfxSynth.tick(tier: 1),
      isNot(SfxSynth.tick(tier: 5)),
    );
  });

  test('a muted synth bus plays nothing', () {
    final played = <int>[];
    final bus = SynthSfx(playBytes: (wav) => played.add(wav.length));
    bus.muted = true;
    bus.sorted(tier: 2, comboUp: false);
    bus.misroute();
    bus.dropped();
    bus.ended();
    expect(played, isEmpty);
  });

  test('an open synth bus plays the spec cues', () {
    final played = <int>[];
    final bus = SynthSfx(playBytes: (wav) => played.add(wav.length));
    bus.sorted(tier: 1, comboUp: false);
    bus.sorted(tier: 3, comboUp: true);
    bus.misroute();
    bus.dropped();
    bus.ended();
    expect(played, hasLength(5));
  });
}
