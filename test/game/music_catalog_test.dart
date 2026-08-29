import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/difficulty.dart';
import 'package:sort_rush/game/music_catalog.dart';

void main() {
  /// What actually shipped on 2026-08-22: seven of ten level loops, both
  /// endless layers and home. `l07`, `l08`, `l10` and the results sting are
  /// still missing.
  const dropped = {
    'audio/l01.ogg',
    'audio/l02.ogg',
    'audio/l03.ogg',
    'audio/l04.ogg',
    'audio/l05.ogg',
    'audio/l06.ogg',
    'audio/l09.ogg',
    'audio/endless_low.ogg',
    'audio/endless_high.ogg',
    'audio/home.ogg',
  };

  group('naming', () {
    test('level assets are lowercase L, not the digit one', () {
      // `l01.ogg` and `101.ogg` are near-identical in most fonts, and the
      // failure mode is silent: the game simply never finds the track.
      expect(MusicCatalog.levelAsset(1), 'audio/l01.ogg');
      expect(MusicCatalog.levelAsset(10), 'audio/l10.ogg');
      expect(MusicCatalog.levelAsset(1).contains('101'), isFalse);
    });
  });

  group('resolution against what shipped', () {
    test('a level with its own track uses it', () {
      for (final id in [1, 2, 3, 4, 5, 6, 9]) {
        expect(MusicCatalog.resolveLevel(id, dropped), 'audio/l0$id.ogg');
      }
    });

    test('a missing track borrows from its own tempo band', () {
      // 7 and 8 are 108 BPM, same as 6.
      expect(MusicCatalog.resolveLevel(7, dropped), 'audio/l06.ogg');
      expect(MusicCatalog.resolveLevel(8, dropped), 'audio/l06.ogg');
      // 10 is 116 BPM, same as 9.
      expect(MusicCatalog.resolveLevel(10, dropped), 'audio/l09.ogg');
    });

    test('it never borrows across a tempo band', () {
      // A 92 BPM loop under a 116 BPM shift would be worse than silence.
      const only92 = {'audio/l01.ogg', 'audio/l02.ogg'};
      expect(MusicCatalog.resolveLevel(9, only92), isNull);
      expect(MusicCatalog.resolveLevel(10, only92), isNull);
      expect(MusicCatalog.resolveLevel(2, only92), 'audio/l02.ogg');
    });

    test('it prefers the nearest neighbour in the band', () {
      const partial = {'audio/l07.ogg', 'audio/l06.ogg'};
      expect(MusicCatalog.resolveLevel(8, partial), 'audio/l07.ogg');
    });

    test('nothing available is silence, not a crash', () {
      for (var id = 1; id <= 10; id++) {
        expect(MusicCatalog.resolveLevel(id, const {}), isNull);
      }
    });

    test('an out-of-range level is silence', () {
      expect(MusicCatalog.resolveLevel(0, dropped), isNull);
      expect(MusicCatalog.resolveLevel(11, dropped), isNull);
    });

    test('every curated level has a tempo', () {
      expect(MusicCatalog.tempos, hasLength(10));
    });
  });

  group('endless crossfade', () {
    test('opens on the low layer and tops out on the high one', () {
      expect(MusicCatalog.endlessMix(0), 0);
      expect(MusicCatalog.endlessMix(EndlessCurve.phaseTwoEnd), 1);
    });

    test('it follows the difficulty curve rather than a chosen number', () {
      // Full intensity lands where the curve stops moving.
      expect(MusicCatalog.endlessMix(EndlessCurve.phaseTwoEnd ~/ 2),
          closeTo(0.5, 0.01));
    });

    test('it never leaves 0..1', () {
      for (final p in [-10, 0, 1, 50, 130, 500]) {
        final mix = MusicCatalog.endlessMix(p);
        expect(mix, greaterThanOrEqualTo(0));
        expect(mix, lessThanOrEqualTo(1));
      }
    });

    test('it rises monotonically', () {
      var previous = -1.0;
      for (var p = 0; p <= 200; p += 5) {
        final mix = MusicCatalog.endlessMix(p);
        expect(mix, greaterThanOrEqualTo(previous));
        previous = mix;
      }
    });
  });
}
