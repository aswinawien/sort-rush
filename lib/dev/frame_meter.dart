import 'dart:collection';

/// How a frame time reads against the 60fps budget.
enum FrameGrade { good, warning, bad }

/// A rolling window of frame times.
///
/// Pure Dart on purpose: the thresholds and the arithmetic are the part worth
/// testing, and they should be testable without a binding or a game loop — the
/// same reason `lib/core` stays engine-free.
class FrameMeter {
  FrameMeter({this.window = 120})
      : assert(window > 0, 'a window needs at least one frame');

  /// 60fps. Anything under this had time to spare.
  static const double goodMs = 16.67;

  /// Above this a frame is late enough to be felt rather than measured.
  static const double badMs = 25.0;

  /// Frames kept for the rolling average. 120 is about two seconds at 60fps —
  /// long enough to survive one hitch, short enough to still track a scene.
  final int window;

  final Queue<double> _samples = Queue<double>();
  double _sum = 0;
  double _worst = 0;
  int _total = 0;

  void addSample(double milliseconds) {
    if (milliseconds.isNaN || milliseconds.isNegative) {
      return;
    }
    _samples.addLast(milliseconds);
    _sum += milliseconds;
    _total++;
    if (milliseconds > _worst) {
      _worst = milliseconds;
    }
    while (_samples.length > window) {
      _sum -= _samples.removeFirst();
    }
  }

  bool get hasSamples => _samples.isNotEmpty;

  int get sampleCount => _samples.length;

  /// Frames seen since the last [reset], including ones aged out of the window.
  int get totalFrames => _total;

  double get last => _samples.isEmpty ? 0 : _samples.last;

  double get average => _samples.isEmpty ? 0 : _sum / _samples.length;

  /// Worst frame since the last [reset], not merely within the window. A hitch
  /// that scrolled out of view is still the thing you were hunting.
  double get worst => _worst;

  double get fps => average <= 0 ? 0 : 1000 / average;

  FrameGrade get grade => gradeOf(average);

  static FrameGrade gradeOf(double milliseconds) {
    if (milliseconds > badMs) {
      return FrameGrade.bad;
    }
    if (milliseconds >= goodMs) {
      return FrameGrade.warning;
    }
    return FrameGrade.good;
  }

  void reset() {
    _samples.clear();
    _sum = 0;
    _worst = 0;
    _total = 0;
  }
}
