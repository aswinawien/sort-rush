import '../core/run_engine.dart';

/// Pixel height of the clutch window painted on the belt wall.
///
/// Package Y is `progress * beltHeight`. A clutch save is the last
/// [RunEngine.clutchWindow] seconds of that travel, so the band occupies
/// `clutchWindow / readWindow` of the belt. Pass the live package's
/// `readWindow`, or [RunEngine.tuning.readWindow] when the belt is empty —
/// a fixed-pixel strip would lie on a slow level and vanish on a fast one.
double clutchBandHeight(double beltHeight, double readWindow) {
  return beltHeight * (RunEngine.clutchWindow / readWindow);
}

/// Seconds of travel that size the painted band.
///
/// Uses the front-most package so a shop-bought speed-up stays honest;
/// falls back to current tuning so an empty belt still shows the zone.
double clutchBandReadWindow({
  required double? liveReadWindow,
  required double tuningReadWindow,
}) {
  return liveReadWindow ?? tuningReadWindow;
}
