import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/machine_intensity.dart';

void main() {
  test('a quiet run is silent', () {
    expect(MachineIntensity.scanlineOpacity(0, 1), 0);
    expect(MachineIntensity.comboSplitPx(1), 0);
  });

  test('combo steps are louder than an empty bar', () {
    expect(
      MachineIntensity.scanlineOpacity(0, 2),
      MachineIntensity.scanlineCap * 0.25,
    );
    expect(
      MachineIntensity.scanlineOpacity(0, 5),
      MachineIntensity.scanlineCap * 0.70,
    );
  });

  test('a full bar is louder than x2', () {
    expect(
      MachineIntensity.scanlineOpacity(1, 2),
      MachineIntensity.scanlineCap,
    );
  });

  test('the louder of bar and combo wins, and never exceeds the cap', () {
    expect(
      MachineIntensity.scanlineOpacity(0.9, 5),
      MachineIntensity.scanlineCap * 0.9,
    );
    expect(
      MachineIntensity.scanlineOpacity(1.5, 5),
      MachineIntensity.scanlineCap,
    );
  });

  test('the combo split steps with the tier', () {
    expect(MachineIntensity.comboSplitPx(2), 2);
    expect(MachineIntensity.comboSplitPx(3), 2);
    expect(MachineIntensity.comboSplitPx(4), 3);
    expect(MachineIntensity.comboSplitPx(5), 3);
  });
}
