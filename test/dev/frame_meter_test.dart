import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/dev/debug_summary.dart';
import 'package:sort_rush/dev/dev_stats.dart';
import 'package:sort_rush/dev/frame_meter.dart';

void main() {
  group('grading against the 60fps budget', () {
    test('under 16.67ms is good', () {
      expect(FrameMeter.gradeOf(12.0), FrameGrade.good);
      expect(FrameMeter.gradeOf(16.0), FrameGrade.good);
    });

    test('16.67 to 25ms is a warning', () {
      expect(FrameMeter.gradeOf(16.67), FrameGrade.warning);
      expect(FrameMeter.gradeOf(20.0), FrameGrade.warning);
      expect(FrameMeter.gradeOf(25.0), FrameGrade.warning);
    });

    test('above 25ms is bad', () {
      expect(FrameMeter.gradeOf(25.1), FrameGrade.bad);
      expect(FrameMeter.gradeOf(120.0), FrameGrade.bad);
    });
  });

  group('the rolling window', () {
    test('averages what it holds', () {
      final meter = FrameMeter(window: 4)
        ..addSample(10)
        ..addSample(20);
      expect(meter.average, 15);
      expect(meter.sampleCount, 2);
    });

    test('ages old frames out of the average', () {
      final meter = FrameMeter(window: 2)
        ..addSample(100)
        ..addSample(10)
        ..addSample(10);
      expect(meter.sampleCount, 2);
      expect(meter.average, 10);
    });

    test('worst survives ageing out of the window', () {
      // The hitch you are hunting has usually already scrolled past.
      final meter = FrameMeter(window: 2)
        ..addSample(100)
        ..addSample(10)
        ..addSample(10);
      expect(meter.worst, 100);
    });

    test('fps derives from the average', () {
      final meter = FrameMeter()..addSample(20);
      expect(meter.fps, closeTo(50, 0.01));
    });

    test('an empty meter reports zeroes rather than dividing by zero', () {
      final meter = FrameMeter();
      expect(meter.hasSamples, isFalse);
      expect(meter.average, 0);
      expect(meter.fps, 0);
      expect(meter.last, 0);
    });

    test('ignores nonsense samples', () {
      final meter = FrameMeter()
        ..addSample(double.nan)
        ..addSample(-5);
      expect(meter.hasSamples, isFalse);
    });

    test('reset clears the window, the worst, and the count', () {
      final meter = FrameMeter()
        ..addSample(40)
        ..addSample(10);
      meter.reset();
      expect(meter.worst, 0);
      expect(meter.average, 0);
      expect(meter.totalFrames, 0);
    });
  });

  group('effect counters', () {
    setUp(DevStats.reset);

    test('a burst adds and removes its own particles', () {
      DevStats.addBurst(4);
      expect(DevStats.activeBursts, 1);
      expect(DevStats.activeParticles, 4);

      DevStats.removeBurst(4);
      expect(DevStats.activeBursts, 0);
      expect(DevStats.activeParticles, 0);
    });

    test('counts return to baseline after a storm of bursts', () {
      // The property the profiler exists to prove: effects that end release
      // what they took. A count that ratchets upward is the leak.
      for (var i = 0; i < 200; i++) {
        DevStats.addBurst(4);
        DevStats.removeBurst(4);
      }
      expect(DevStats.activeBursts, 0);
      expect(DevStats.activeParticles, 0);
      expect(DevStats.peakBursts, 1);
    });

    test('peaks record the high-water mark', () {
      DevStats.addBurst(4);
      DevStats.addBurst(4);
      DevStats.addBurst(4);
      expect(DevStats.peakParticles, 12);
      DevStats.removeBurst(4);
      expect(DevStats.peakParticles, 12);
      expect(DevStats.activeParticles, 8);
    });

    test('counters never go negative on an unbalanced release', () {
      DevStats.removeBurst(4);
      DevStats.removeTrail();
      expect(DevStats.activeBursts, 0);
      expect(DevStats.activeParticles, 0);
      expect(DevStats.activeTrails, 0);
    });
  });

  group('the QA capture', () {
    setUp(DevStats.reset);

    test('reads back the shape QA is asked to record', () {
      DevStats.addBurst(18);
      DevStats.addTrail();
      DevStats.addTrail();
      DevStats.addTrail();

      final meter = FrameMeter()
        ..addSample(12.4)
        ..addSample(12.4)
        ..addSample(19.8);

      final text = debugSummary(
        meter: meter,
        visualStyle: 'Immersive Neon',
        memoProfile: 'Corruption Warning',
        reduceMotion: false,
      );

      expect(text, contains('Visual style: Immersive Neon'));
      expect(text, contains('Memo profile: Corruption Warning'));
      expect(text, contains('Worst frame: 19.8ms'));
      expect(text, contains('Peak particles: 18'));
      expect(text, contains('Peak trails: 3'));
      expect(text, contains('Reduce motion: false'));
    });
  });
}
