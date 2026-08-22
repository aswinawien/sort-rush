import 'dev_stats.dart';
import 'frame_meter.dart';

/// The compact capture QA pastes into a report.
///
/// Pure string building so it can be asserted in a test rather than eyeballed
/// in an overlay.
String debugSummary({
  required FrameMeter meter,
  required String visualStyle,
  required String memoProfile,
  required bool reduceMotion,
}) {
  String ms(double value) => '${value.toStringAsFixed(1)}ms';
  return [
    'Visual style: $visualStyle',
    'Memo profile: $memoProfile',
    'Average frame: ${ms(meter.average)}',
    'Worst frame: ${ms(meter.worst)}',
    'Peak particles: ${DevStats.peakParticles}',
    'Peak trails: ${DevStats.peakTrails}',
    'Reduce motion: $reduceMotion',
  ].join('\n');
}
