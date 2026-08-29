import 'score_state.dart';

/// Stepped "on a roll" treatment for the belt wall and the combo line.
///
/// Tied to numbers the player can already see — pressure fill and combo
/// tier — so the wall getting noisier is information, not decoration.
/// Per-frame jitter is forbidden: it flashes and it costs frames.
/// See docs/design-spec.md §5.2.
abstract final class MachineIntensity {
  /// x1–x5 are byte-identical to the values approved on 2026-08-17. The
  /// x6–x10 range is new and lands on a full wall at MAXXXX. Extending rather
  /// than re-spacing keeps every curated shift — which caps at x5 — looking
  /// exactly as it did.
  static const List<double> comboSteps = [
    0, 0.25, 0.40, 0.55, 0.70, // x1–x5, unchanged
    0.78, 0.85, 0.91, 0.96, 1.0, // x6–x10
  ];

  static const double scanlineCap = 0.12;

  static double comboStepFor(int tier) {
    final index = tier.clamp(1, comboSteps.length) - 1;
    return comboSteps[index];
  }

  /// Scan-line opacity on the ink belt. The louder of [pFill] and the
  /// combo step wins; they do not add past [scanlineCap].
  static double scanlineOpacity(double pFill, int comboTier) {
    final fill = pFill.clamp(0.0, 1.0);
    final step = comboStepFor(comboTier);
    final intensity = fill > step ? fill : step;
    return scanlineCap * intensity;
  }

  /// Horizontal channel split on the score numeral and `COMBO xN`, in logical pixels.
  static double comboSplitPx(int tier) {
    if (tier <= 1) {
      return 0;
    }
    if (tier <= 3) {
      return 2;
    }
    // MAXXXX prints wider than any numbered tier. Still held, still printed
    // once per tier — a per-frame jitter here is the CRT-screensaver failure
    // the 2026-08-17 ruling rejected, and it is still rejected.
    if (tier >= RunScore.maxxxxTier) {
      return 4;
    }
    return 3;
  }
}
