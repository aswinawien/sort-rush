import 'package:flutter/material.dart';

/// The token table from docs/design-spec.md §4.
///
/// Bins never use [hues] — they are identified by silhouette or pattern plus a
/// mono letter. Hues decorate packages only, and are always paired with a fill
/// pattern, so the game stays playable rendered entirely in grey.
abstract final class Tokens {
  static const Color ink = Color(0xFF0D0D0F);
  static const Color paper = Color(0xFFF2EDE3);
  static const Color acid = Color(0xFFC6FF00);
  static const Color warn = Color(0xFFFF4B26);
  static const Color mute = Color(0xFF6E6E76);

  /// Indexed by `PackageSpec.colorIndex`, paired one-to-one with `FillPattern`.
  static const List<Color> hues = [
    Color(0xFF38E1FF),
    Color(0xFFFF4FD8),
    Color(0xFFFFC53D),
  ];

  /// No asset pipeline in v1, so we lean on the platform mono face.
  static const String mono = 'monospace';

  static const TextStyle display = TextStyle(
    fontFamily: mono,
    fontSize: 44,
    fontWeight: FontWeight.w700,
    color: acid,
    height: 1,
  );

  static const TextStyle label = TextStyle(
    fontFamily: mono,
    fontSize: 13,
    letterSpacing: 2,
    color: mute,
  );

  static const TextStyle body = TextStyle(
    fontFamily: mono,
    fontSize: 15,
    letterSpacing: 1,
    color: paper,
  );
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Tokens.ink,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Tokens.acid,
      brightness: Brightness.dark,
    ),
    fontFamily: Tokens.mono,
  );
}
