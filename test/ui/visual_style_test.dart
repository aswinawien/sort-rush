import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sort_rush/ui/visual_style.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<VisualStyleController> loaded(
      [Map<String, Object> seed = const {}]) async {
    SharedPreferences.setMockInitialValues(seed);
    final prefs = await SharedPreferences.getInstance();
    final controller = VisualStyleController(prefs: prefs);
    await controller.load();
    return controller;
  }

  group('the setting', () {
    test('defaults to standard', () async {
      final controller = await loaded();
      expect(controller.style, VisualStyle.standard);
      expect(controller.isNeon, isFalse);
    });

    test('a corrupt stored value falls back to standard, never throws',
        () async {
      // A bad preference must not cost someone the app.
      final controller = await loaded({
        VisualStyleController.prefsKey: 'ultraNeonDeluxe',
      });
      expect(controller.style, VisualStyle.standard);
    });

    test('restores a stored choice', () async {
      final controller = await loaded({
        VisualStyleController.prefsKey: 'immersiveNeon',
      });
      expect(controller.style, VisualStyle.immersiveNeon);
    });

    test('toggling persists so the choice survives a relaunch', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = VisualStyleController(prefs: prefs);
      await first.load();
      await first.toggle();

      final second = VisualStyleController(prefs: prefs);
      await second.load();
      expect(second.style, VisualStyle.immersiveNeon);
    });

    test('notifies listeners on change', () async {
      final controller = await loaded();
      var calls = 0;
      controller.addListener(() => calls++);
      await controller.toggle();
      expect(calls, 1);
    });
  });

  group('reduceMotion overrides the setting', () {
    Widget probe({
      required VisualStyle style,
      required bool reduce,
      required void Function(VisualProfile) onBuild,
    }) {
      return MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: VisualStyleScope(
          notifier: VisualStyleController(initial: style),
          child: Builder(
            builder: (context) {
              onBuild(VisualProfile.of(context));
              return const SizedBox();
            },
          ),
        ),
      );
    }

    testWidgets('neon is off when the platform asks for less motion',
        (tester) async {
      late VisualProfile seen;
      await tester.pumpWidget(probe(
        style: VisualStyle.immersiveNeon,
        reduce: true,
        onBuild: (p) => seen = p,
      ));

      // Someone who asked the system for less movement has already answered
      // this question; the game setting does not get to overrule it.
      expect(seen.style, VisualStyle.immersiveNeon);
      expect(seen.neon, isFalse);
      expect(seen.sequentialReveal, isFalse);
      expect(seen.memoIn, Duration.zero);
      expect(seen.memoOut, Duration.zero);
    });

    testWidgets('neon is on when it is asked for and motion is allowed',
        (tester) async {
      late VisualProfile seen;
      await tester.pumpWidget(probe(
        style: VisualStyle.immersiveNeon,
        reduce: false,
        onBuild: (p) => seen = p,
      ));
      expect(seen.neon, isTrue);
      expect(seen.sequentialReveal, isTrue);
    });

    testWidgets('standard keeps the memo inside its snappy budget',
        (tester) async {
      late VisualProfile seen;
      await tester.pumpWidget(probe(
        style: VisualStyle.standard,
        reduce: false,
        onBuild: (p) => seen = p,
      ));
      expect(seen.neon, isFalse);
      expect(seen.sequentialReveal, isFalse);
      expect(seen.memoIn.inMilliseconds, inInclusiveRange(150, 250));
      expect(seen.memoOut.inMilliseconds, lessThanOrEqualTo(250));
    });

    testWidgets('neon memo timings stay inside the brief', (tester) async {
      late VisualProfile seen;
      await tester.pumpWidget(probe(
        style: VisualStyle.immersiveNeon,
        reduce: false,
        onBuild: (p) => seen = p,
      ));
      expect(seen.memoIn.inMilliseconds, inInclusiveRange(350, 500));
      expect(seen.memoOut.inMilliseconds, inInclusiveRange(180, 280));
    });

    testWidgets('a screen with no scope still builds, as standard',
        (tester) async {
      late VisualProfile seen;
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(),
        child: Builder(
          builder: (context) {
            seen = VisualProfile.of(context);
            return const SizedBox();
          },
        ),
      ));
      expect(seen.style, VisualStyle.standard);
    });
  });
}
