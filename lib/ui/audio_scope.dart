import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/music.dart';
import '../game/sfx.dart';

/// Mute plus the live SFX bus. Home toggles; Play reads.
class AudioController extends ChangeNotifier {
  AudioController({
    SfxBus? sfx,
    MusicBus? music,
    SharedPreferences? prefs,
    Set<String>? tracks,
  })  : sfx = sfx ?? SynthSfx(),
        music = music ?? AssetMusic(),
        _prefs = prefs,
        _tracks = tracks;

  static const String prefsKey = 'sort_rush.sound.muted.v1';

  final SfxBus sfx;

  /// Atmosphere only. One mute governs both buses — sound-off is a first-class
  /// mode, not two switches the player has to find.
  final MusicBus music;
  final SharedPreferences? _prefs;

  /// Injected by tests. Null means read the asset manifest.
  final Set<String>? _tracks;
  bool _muted = false;
  bool _loaded = false;

  bool get muted => _muted;

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _muted = prefs.getBool(prefsKey) ?? false;
    music.available = _tracks ?? await _discoverTracks();
    _applyMute();
    notifyListeners();
  }

  Future<void> toggle() => setMuted(!_muted);

  Future<void> setMuted(bool value) async {
    if (_muted == value && _loaded) {
      return;
    }
    _muted = value;
    _applyMute();
    notifyListeners();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, value);
  }

  void _applyMute() {
    final bus = sfx;
    if (bus is SynthSfx) {
      bus.muted = _muted;
    }
    music.muted = _muted;
  }

  /// Which music files actually shipped.
  ///
  /// Read from the asset manifest rather than assumed, because the soundtrack
  /// lands in pieces and a build missing four loops must still sound
  /// deliberate. A manifest that cannot be read yields an empty set, which is
  /// silence — never a crash.
  Future<Set<String>> _discoverTracks() async {
    try {
      // `AssetManifest.loadFromAssetBundle`, not a hand-rolled read of
      // `AssetManifest.json`. Flutter stopped emitting that file — the build
      // now ships `AssetManifest.bin` — so parsing the old name finds nothing
      // and plays no music, silently. Verified against a release web bundle.
      //
      // Timed out rather than awaited indefinitely: the manifest read does not
      // complete under the test binding, and a hung splash screen is worse
      // than silence.
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle)
          .timeout(const Duration(seconds: 2));
      return {
        for (final key in manifest.listAssets())
          if (key.startsWith('assets/audio/')) key.substring('assets/'.length),
      };
    } catch (_) {
      return const {};
    }
  }

  @override
  void dispose() {
    final bus = sfx;
    if (bus is SynthSfx) {
      bus.dispose();
    }
    music.dispose();
    super.dispose();
  }
}

class AudioScope extends InheritedNotifier<AudioController> {
  const AudioScope({
    super.key,
    required AudioController super.notifier,
    required super.child,
  });

  static AudioController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AudioScope>()?.notifier;
}
