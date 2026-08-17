/// Stepped "on a roll" treatment for the belt wall and the combo line.
///
/// Tied to numbers the player can already see — pressure fill and combo
/// tier — so the wall getting noisier is information, not decoration.
/// Per-frame jitter is forbidden: it flashes and it costs frames.
/// See docs/design-spec.md §5.2.
abstract final class MachineIntensity {
  static const List<double> comboSteps = [0, 0.25, 0.40, 0.55, 0.70];

  static const double scanlineCap = 0.12;

  static double comboStepFor(int tier) {
    final index = tier.clamp(1, 5) - 1;
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
    return 3;
  }
}
