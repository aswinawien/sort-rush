import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/ui/memo/memo_transition.dart';
import 'package:sort_rush/ui/memo/memo_variant.dart';
import 'package:sort_rush/ui/visual_style.dart';

void main() {
  VisualProfile profile({required bool neon, required bool reduce}) =>
      VisualProfile(
        style: neon ? VisualStyle.immersiveNeon : VisualStyle.standard,
        reduceMotion: reduce,
      );

  group('all six variants exist and are distinct', () {
    test('there are exactly six, each with a spec and a label', () {
      expect(MemoVariant.values, hasLength(6));
      for (final variant in MemoVariant.values) {
        expect(kMemoVariants[variant], isNotNull,
            reason: '${variant.name} has no spec');
        expect(variant.label, isNotEmpty);
      }
      expect(
        MemoVariant.values.map((v) => v.label).toSet(),
        hasLength(6),
        reason: 'labels must be distinguishable in a QA report',
      );
    });

    test('the variants are not all the same animation wearing new names', () {
      // If every spec were identical this would be six names over one effect.
      final shapes = kMemoVariants.values
          .map((s) => '${s.feedAxis}/${s.feedFromStart}/${s.overshoot}/'
              '${s.stampImpact}/${s.registrationPx}/${s.sequentialReveal}')
          .toSet();
      expect(shapes.length, greaterThanOrEqualTo(5));
    });

    test('only the corruption variant carries a registration split', () {
      for (final entry in kMemoVariants.entries) {
        if (entry.key == MemoVariant.corruptionWarning) {
          expect(entry.value.registrationPx, greaterThan(0));
        } else {
          expect(entry.value.registrationPx, 0,
              reason: '${entry.key.name} should not split channels');
        }
      }
    });

    test('corruption instability stays restrained', () {
      // Readable is the requirement. A large split would smear the copy.
      expect(specFor(MemoVariant.corruptionWarning).registrationPx,
          lessThanOrEqualTo(4));
    });
  });

  group('timing bands hold for every variant in every mode', () {
    test('standard entrance lands in 150-250ms', () {
      for (final variant in MemoVariant.values) {
        final ms = MemoTiming.entrance(
          profile(neon: false, reduce: false),
          variant,
        ).inMilliseconds;
        expect(ms, inInclusiveRange(150, 250), reason: variant.name);
      }
    });

    test('immersive neon entrance lands in 350-500ms', () {
      for (final variant in MemoVariant.values) {
        final ms = MemoTiming.entrance(
          profile(neon: true, reduce: false),
          variant,
        ).inMilliseconds;
        expect(ms, inInclusiveRange(350, 500), reason: variant.name);
      }
    });

    test('immersive neon exit lands in 180-280ms', () {
      for (final variant in MemoVariant.values) {
        final ms = MemoTiming.exit(
          profile(neon: true, reduce: false),
          variant,
        ).inMilliseconds;
        expect(ms, inInclusiveRange(180, 280), reason: variant.name);
      }
    });

    test('standard exit stays quick', () {
      for (final variant in MemoVariant.values) {
        final ms = MemoTiming.exit(
          profile(neon: false, reduce: false),
          variant,
        ).inMilliseconds;
        expect(ms, lessThanOrEqualTo(250), reason: variant.name);
      }
    });

    test('reduce motion collapses every variant to zero, in both styles', () {
      for (final neon in [false, true]) {
        for (final variant in MemoVariant.values) {
          final p = profile(neon: neon, reduce: true);
          expect(MemoTiming.entrance(p, variant), Duration.zero,
              reason: '${variant.name} neon=$neon');
          expect(MemoTiming.exit(p, variant), Duration.zero,
              reason: '${variant.name} neon=$neon');
        }
      }
    });

    test('a variant cannot scale itself out of its band', () {
      // The clamp is the guarantee. Someone tuning durationScale later must
      // not be able to break the contract by accident.
      final ms = MemoTiming.entrance(
        profile(neon: true, reduce: false),
        MemoVariant.shiftResults,
      ).inMilliseconds;
      expect(ms, lessThanOrEqualTo(MemoTiming.neonEntranceMax));
    });
  });

  group('interruption never duplicates an action', () {
    Future<GlobalKey<MemoTransitionState>> mount(
      WidgetTester tester, {
      required MemoVariant variant,
      required bool neon,
      required bool reduce,
      required VoidCallback onClosed,
    }) async {
      final key = GlobalKey<MemoTransitionState>();
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: VisualStyleScope(
            notifier: VisualStyleController(
              initial: neon ? VisualStyle.immersiveNeon : VisualStyle.standard,
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: MemoTransition(
                key: key,
                variant: variant,
                onClosed: onClosed,
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return key;
    }

    testWidgets('closing twice fires the callback once', (tester) async {
      var closed = 0;
      final key = await mount(tester,
          variant: MemoVariant.normal,
          neon: true,
          reduce: false,
          onClosed: () => closed++);

      key.currentState!.close();
      key.currentState!.close();
      key.currentState!.close();
      await tester.pumpAndSettle();

      expect(closed, 1);
    });

    testWidgets('skipping the entrance never closes', (tester) async {
      var closed = 0;
      final key = await mount(tester,
          variant: MemoVariant.shop,
          neon: true,
          reduce: false,
          onClosed: () => closed++);

      key.currentState!.skip();
      await tester.pumpAndSettle();

      expect(closed, 0, reason: 'skip is not a dismiss');
    });

    testWidgets('replaying does not fire a stale close', (tester) async {
      var closed = 0;
      final key = await mount(tester,
          variant: MemoVariant.newRule,
          neon: true,
          reduce: false,
          onClosed: () => closed++);

      for (var i = 0; i < 5; i++) {
        key.currentState!.replay();
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pumpAndSettle();
      expect(closed, 0);
    });

    testWidgets('interrupting the exit still fires exactly once',
        (tester) async {
      var closed = 0;
      final key = await mount(tester,
          variant: MemoVariant.shiftTransition,
          neon: true,
          reduce: false,
          onClosed: () => closed++);

      key.currentState!.close();
      await tester.pump(const Duration(milliseconds: 60));
      key.currentState!.skip(); // an interrupt mid-exit
      key.currentState!.close();
      await tester.pumpAndSettle();

      expect(closed, 1);
    });

    testWidgets('under reduce motion close still fires once, immediately',
        (tester) async {
      var closed = 0;
      final key = await mount(tester,
          variant: MemoVariant.shiftResults,
          neon: true,
          reduce: true,
          onClosed: () => closed++);

      key.currentState!.close();
      await tester.pump();
      expect(closed, 1);

      key.currentState!.close();
      await tester.pump();
      expect(closed, 1);
    });

    testWidgets('disposing mid-flight leaves nothing behind', (tester) async {
      var closed = 0;
      final key = await mount(tester,
          variant: MemoVariant.corruptionWarning,
          neon: true,
          reduce: false,
          onClosed: () => closed++);

      key.currentState!.close();
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(closed, 0, reason: 'a disposed memo must not call back');
      expect(tester.takeException(), isNull);
    });

    testWidgets('every variant mounts and settles in all four modes',
        (tester) async {
      for (final variant in MemoVariant.values) {
        for (final neon in [false, true]) {
          for (final reduce in [false, true]) {
            await mount(tester,
                variant: variant, neon: neon, reduce: reduce, onClosed: () {});
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull,
                reason: '${variant.name} neon=$neon reduce=$reduce');
          }
        }
      }
    });
  });
}
