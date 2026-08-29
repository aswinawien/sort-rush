import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How much presentation the player wants.
///
/// Presentation only. Nothing reachable from here may change a rule, a timing
/// number, a score, or a difficulty value — the setting exists so the belt can
/// look richer, never so it can play differently.
enum VisualStyle {
  /// Readability first, and the setting a device that has never been profiled
  /// gets by default.
  standard,

  /// Full CRT/neon atmosphere.
  immersiveNeon,
}

/// Persisted visual-style choice. Home toggles; every surface reads.
class VisualStyleController extends ChangeNotifier {
  VisualStyleController({SharedPreferences? prefs, VisualStyle? initial})
      : _prefs = prefs,
        _style = initial ?? VisualStyle.standard;

  static const String prefsKey = 'sort_rush.visual.style.v1';
  static const String reduceMotionKey = 'sort_rush.visual.reduce.v1';

  final SharedPreferences? _prefs;
  VisualStyle _style;
  bool _reduceMotion = false;
  bool _loaded = false;

  VisualStyle get style => _style;

  bool get isNeon => _style == VisualStyle.immersiveNeon;

  /// In-game request for less movement.
  ///
  /// This can only ever *add* to the platform preference. Someone whose device
  /// asks for reduced motion keeps it reduced whatever this says — see
  /// [VisualProfile.of].
  bool get reduceMotion => _reduceMotion;

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final stored = prefs.getString(prefsKey);
    // An unknown or absent value falls back to standard rather than throwing.
    // A corrupt preference must never cost someone the app.
    _style =
        VisualStyle.values.where((value) => value.name == stored).firstOrNull ??
            VisualStyle.standard;
    _reduceMotion = prefs.getBool(reduceMotionKey) ?? false;
    notifyListeners();
  }

  Future<void> toggle() => set(
        isNeon ? VisualStyle.standard : VisualStyle.immersiveNeon,
      );

  Future<void> set(VisualStyle value) async {
    if (_style == value && _loaded) {
      return;
    }
    _style = value;
    notifyListeners();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, value.name);
  }

  Future<void> setReduceMotion(bool value) async {
    if (_reduceMotion == value && _loaded) {
      return;
    }
    _reduceMotion = value;
    notifyListeners();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setBool(reduceMotionKey, value);
  }

  /// Back to shipped defaults. Leaves anything that is not a setting alone —
  /// the floor record and wallet are progress, not preferences.
  Future<void> reset() async {
    _style = VisualStyle.standard;
    _reduceMotion = false;
    notifyListeners();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
    await prefs.remove(reduceMotionKey);
  }
}

class VisualStyleScope extends InheritedNotifier<VisualStyleController> {
  const VisualStyleScope({
    super.key,
    required VisualStyleController super.notifier,
    required super.child,
  });

  static VisualStyleController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VisualStyleScope>()?.notifier;

  /// The style in force, defaulting to standard where no scope is installed —
  /// so a screen shown in isolation, including in a widget test, still builds.
  static VisualStyle of(BuildContext context) =>
      maybeOf(context)?.style ?? VisualStyle.standard;
}

/// The style resolved against the platform's accessibility preference.
///
/// `reduceMotion` is not a third style: it overrides. Someone who has asked
/// the system for less movement has already answered this question, and a
/// game setting does not get to overrule it.
class VisualProfile {
  const VisualProfile({required this.style, required this.reduceMotion});

  /// The platform preference and the in-game one are OR'd, never replaced.
  /// A device asking for reduced motion cannot be talked out of it by a
  /// setting inside the game.
  factory VisualProfile.of(BuildContext context) => VisualProfile(
        style: VisualStyleScope.of(context),
        reduceMotion: MediaQuery.disableAnimationsOf(context) ||
            (VisualStyleScope.maybeOf(context)?.reduceMotion ?? false),
      );

  final VisualStyle style;
  final bool reduceMotion;

  /// The only question most callers need to ask.
  bool get neon => style == VisualStyle.immersiveNeon && !reduceMotion;

  /// Depot-board entrance. Standard stays inside the 150-250ms the brief asks
  /// for; neon gets the paper-feed budget.
  Duration get memoIn => reduceMotion
      ? Duration.zero
      : neon
          ? const Duration(milliseconds: 420)
          : const Duration(milliseconds: 200);

  Duration get memoOut => reduceMotion
      ? Duration.zero
      : neon
          ? const Duration(milliseconds: 230)
          : const Duration(milliseconds: 160);

  /// Whether options print in sequence. Never in standard: sequential reveal
  /// that delays interaction is exactly what the brief rules out there.
  bool get sequentialReveal => neon;
}
