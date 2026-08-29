import 'difficulty_ref.dart';

/// Which music file belongs to which surface, and what to do when it is
/// missing.
///
/// Pure Dart with no player and no asset bundle, so the fallback rules are
/// testable without audio hardware. Resolution takes the set of files that
/// actually shipped, because the soundtrack lands in pieces: a build with
/// seven of ten level loops has to sound deliberate rather than silent.
abstract final class MusicCatalog {
  /// Tempo per curated level, indexed by `id - 1`. From docs/audio-brief.md.
  static const List<int> tempos = [
    92,
    92,
    100,
    100,
    104,
    108,
    108,
    108,
    116,
    116,
  ];

  static const String home = 'audio/home.ogg';
  static const String endlessLow = 'audio/endless_low.ogg';
  static const String endlessHigh = 'audio/endless_high.ogg';
  static const String results = 'audio/results.ogg';

  static String levelAsset(int id) =>
      'audio/l${id.toString().padLeft(2, '0')}.ogg';

  /// The track for a curated level, or null for silence.
  ///
  /// Falls back to another level in the same tempo band before giving up.
  /// That is the collapse strategy the audio brief already names — "collapse
  /// to four tracks by tempo band" — so a partial drop degrades along the
  /// axis the music was written around instead of going quiet.
  static String? resolveLevel(int id, Set<String> available) {
    if (id < 1 || id > tempos.length) {
      return null;
    }
    final exact = levelAsset(id);
    if (available.contains(exact)) {
      return exact;
    }
    final tempo = tempos[id - 1];
    // Nearest neighbour in the band first, so level 8 borrows 7 before 6.
    final peers = <int>[
      for (var other = 1; other <= tempos.length; other++)
        if (other != id && tempos[other - 1] == tempo) other,
    ]..sort((a, b) => (a - id).abs().compareTo((b - id).abs()));
    for (final peer in peers) {
      final candidate = levelAsset(peer);
      if (available.contains(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  /// How far endless has climbed, 0 at the opening and 1 once the curve stops
  /// moving. Drives the crossfade between the two endless loops.
  ///
  /// Tied to `EndlessCurve.phaseTwoEnd` so the music reaches full intensity at
  /// the same moment the difficulty does, rather than on a number picked to
  /// sound good.
  static double endlessMix(int pressure) {
    if (pressure <= 0) {
      return 0;
    }
    final t = pressure / endlessPhaseTwoEnd;
    return t < 1 ? t : 1;
  }
}
