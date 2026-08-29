import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sort_rush/game/music.dart';
import 'package:sort_rush/game/sfx.dart';
import 'package:sort_rush/ui/audio_scope.dart';
import 'package:sort_rush/ui/options_screen.dart';
import 'package:sort_rush/ui/theme.dart';
import 'package:sort_rush/ui/visual_style.dart';

void main() {
  late AudioController audio;
  late VisualStyleController visual;
  late SharedPreferences prefs;

  Future<void> boot(
    WidgetTester tester, {
    Map<String, Object> seed = const {},
    bool platformReduceMotion = false,
  }) async {
    SharedPreferences.setMockInitialValues(seed);
    prefs = await SharedPreferences.getInstance();
    audio = AudioController(
      sfx: const SilentSfx(),
      music: const SilentMusic(),
      prefs: prefs,
      // Injected rather than discovered: the asset-manifest read does not
      // complete under the test binding.
      tracks: const {},
    );
    visual = VisualStyleController(prefs: prefs);
    await audio.load();
    await visual.load();

    await tester.pumpWidget(
      AudioScope(
        notifier: audio,
        child: VisualStyleScope(
          notifier: visual,
          child: MaterialApp(
            theme: buildTheme(),
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: platformReduceMotion),
              child: const OptionsScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Options are addressed by key: 'ON' and 'OFF' appear in more than one
  /// group, so text finders cannot say which control they mean.
  Future<void> choose(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  group('the terminal', () {
    testWidgets('shows every setting group', (tester) async {
      await boot(tester);
      expect(find.text('OPTIONS'), findsOneWidget);
      expect(find.text('SOUND'), findsOneWidget);
      expect(find.text('VISUAL STYLE'), findsOneWidget);
      expect(find.text('REDUCE MOTION'), findsOneWidget);
      expect(find.text('RESET SETTINGS'), findsOneWidget);
    });

    testWidgets('closes back to where it was opened from', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        VisualStyleScope(
          notifier: VisualStyleController(prefs: p),
          child: MaterialApp(
            theme: buildTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OptionsScreen(),
                    ),
                  ),
                  child: const Text('GO'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('GO'));
      await tester.pumpAndSettle();
      expect(find.text('BACK TO DEPOT'), findsOneWidget);

      // The terminal is taller than a small viewport, so the way out has to be
      // scrolled to before it can be tapped.
      await tester.ensureVisible(find.text('BACK TO DEPOT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BACK TO DEPOT'));
      await tester.pumpAndSettle();
      expect(find.text('GO'), findsOneWidget);
      expect(find.text('BACK TO DEPOT'), findsNothing);
    });
  });

  group('selection is not carried by colour alone', () {
    testWidgets('the chosen option is marked with a filled glyph',
        (tester) async {
      await boot(tester);
      // Three groups, one filled marker each: SOUND, VISUAL STYLE,
      // REDUCE MOTION. RESET is an action row and carries no glyph.
      expect(find.text('■'), findsNWidgets(3));
      expect(find.text('□'), findsNWidgets(3));
    });
  });

  group('sound', () {
    testWidgets('toggles and persists', (tester) async {
      await boot(tester);
      expect(audio.muted, isFalse);

      await choose(tester, 'sound-off');
      expect(audio.muted, isTrue);
      expect(prefs.getBool(AudioController.prefsKey), isTrue);
    });

    testWidgets('restores a stored choice', (tester) async {
      await boot(tester, seed: {AudioController.prefsKey: true});
      expect(audio.muted, isTrue);
    });
  });

  group('visual style', () {
    testWidgets('switches to neon and persists', (tester) async {
      await boot(tester);
      await choose(tester, 'style-neon');

      expect(visual.style, VisualStyle.immersiveNeon);
      expect(prefs.getString(VisualStyleController.prefsKey), 'immersiveNeon');
    });

    testWidgets('an unknown stored value falls back to standard',
        (tester) async {
      await boot(tester, seed: {
        VisualStyleController.prefsKey: 'chromeDeluxe9000',
      });
      expect(visual.style, VisualStyle.standard);
      expect(find.text('STANDARD'), findsOneWidget);
    });
  });

  group('reduce motion', () {
    testWidgets('the in-game switch persists', (tester) async {
      await boot(tester);
      await choose(tester, 'motion-on');

      expect(visual.reduceMotion, isTrue);
      expect(prefs.getBool(VisualStyleController.reduceMotionKey), isTrue);
    });

    testWidgets('it overrides neon rather than sitting beside it',
        (tester) async {
      await boot(tester, seed: {
        VisualStyleController.prefsKey: 'immersiveNeon',
        VisualStyleController.reduceMotionKey: true,
      });

      late VisualProfile profile;
      await tester.pumpWidget(
        VisualStyleScope(
          notifier: visual,
          child: MaterialApp(
            home: Builder(builder: (context) {
              profile = VisualProfile.of(context);
              return const SizedBox();
            }),
          ),
        ),
      );

      expect(profile.style, VisualStyle.immersiveNeon);
      expect(profile.neon, isFalse);
    });

    testWidgets('the platform preference cannot be switched off in game',
        (tester) async {
      // The device asked for less motion. Turning the in-game switch to OFF
      // must not be able to overrule that.
      await boot(tester, platformReduceMotion: true);
      await choose(tester, 'motion-off');

      late VisualProfile profile;
      await tester.pumpWidget(
        VisualStyleScope(
          notifier: visual,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Builder(builder: (context) {
                profile = VisualProfile.of(context);
                return const SizedBox();
              }),
            ),
          ),
        ),
      );

      expect(visual.reduceMotion, isFalse);
      expect(profile.reduceMotion, isTrue);
    });
  });

  group('reset', () {
    testWidgets('returns settings to shipped defaults', (tester) async {
      await boot(tester, seed: {
        VisualStyleController.prefsKey: 'immersiveNeon',
        VisualStyleController.reduceMotionKey: true,
      });
      expect(visual.isNeon, isTrue);

      await choose(tester, 'reset-settings');

      expect(visual.style, VisualStyle.standard);
      expect(visual.reduceMotion, isFalse);
      expect(prefs.getString(VisualStyleController.prefsKey), isNull);
    });
  });
}
