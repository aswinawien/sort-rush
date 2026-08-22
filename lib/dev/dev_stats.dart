import 'package:flutter/foundation.dart';

/// Live effect counts for the development profiler.
///
/// Every mutation is behind `if (kDevTools)` at the call site, so release
/// builds carry neither the counting nor the branch — the constant folds and
/// the code is dropped.
///
/// Counters, not a registry: the profiler needs to know *how many* effects are
/// alive and whether that number returns to baseline. Holding references to
/// the effects themselves would let a profiler keep them from being collected,
/// which is the exact bug it exists to find.
/// True in debug and profile builds, false in release.
///
/// Deliberately not `kDebugMode`: profile mode is where honest frame times come
/// from, and a profiler that switched itself off there would be unavailable in
/// exactly the build you measure with. Release still carries none of it, which
/// is the requirement.
const bool kDevTools = !kReleaseMode;

abstract final class DevStats {
  static int activeBursts = 0;
  static int activeTrails = 0;
  static int activeParticles = 0;

  static int peakBursts = 0;
  static int peakTrails = 0;
  static int peakParticles = 0;

  /// Set by whatever is on screen, so a capture says what it was looking at.
  static String screen = 'unknown';
  static String memoProfile = 'none';
  static double memoElapsed = 0;

  static void addBurst([int particles = 0]) {
    activeBursts++;
    activeParticles += particles;
    if (activeBursts > peakBursts) peakBursts = activeBursts;
    if (activeParticles > peakParticles) peakParticles = activeParticles;
  }

  static void removeBurst([int particles = 0]) {
    activeBursts--;
    activeParticles -= particles;
    if (activeBursts < 0) activeBursts = 0;
    if (activeParticles < 0) activeParticles = 0;
  }

  static void addTrail() {
    activeTrails++;
    if (activeTrails > peakTrails) peakTrails = activeTrails;
  }

  static void removeTrail() {
    activeTrails--;
    if (activeTrails < 0) activeTrails = 0;
  }

  /// Clears peaks and live counts. Called when a QA pass starts a new capture.
  static void reset() {
    activeBursts = 0;
    activeTrails = 0;
    activeParticles = 0;
    peakBursts = 0;
    peakTrails = 0;
    peakParticles = 0;
    memoElapsed = 0;
  }

  /// Guards every call site. See [kDevTools].
  static bool get enabled => kDevTools;
}
