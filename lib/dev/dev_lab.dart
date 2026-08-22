import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/sfx.dart';
import '../ui/audio_scope.dart';
import '../ui/memo/memo_transition.dart';
import '../ui/memo/memo_variant.dart';
import '../ui/options_screen.dart';
import '../ui/theme.dart';
import '../ui/visual_style.dart';
import 'dev_stats.dart';
import 'profiler_overlay.dart';

/// One development lab, replacing the scattered dev entrypoints.
///
///   flutter run -t lib/dev/dev_lab.dart -d chrome
///
/// Nothing in the shipped app imports this file, and every control is guarded
/// by [kDevTools], so a release build carries none of it.
///
///   F3  profiler overlay        F6  replay current memo
///   F4  cycle visual style      F7  optional particles and trails
///   F5  next memo variant       F8  reduce-motion preview
///   F9  print a QA capture      F10 reset measurements
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final audio = AudioController(sfx: const SilentSfx(), prefs: prefs);
  final visual = VisualStyleController(prefs: prefs);
  await audio.load();
  await visual.load();
  runApp(DevLabApp(audio: audio, visual: visual));
}

class DevLabApp extends StatelessWidget {
  const DevLabApp({super.key, required this.audio, required this.visual});

  final AudioController audio;
  final VisualStyleController visual;

  @override
  Widget build(BuildContext context) {
    return AudioScope(
      notifier: audio,
      child: VisualStyleScope(
        notifier: visual,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: const DevLab(),
        ),
      ),
    );
  }
}

class DevLab extends StatefulWidget {
  const DevLab({super.key});

  @override
  State<DevLab> createState() => _DevLabState();
}

class _DevLabState extends State<DevLab> {
  final FocusNode _keys = FocusNode();
  final GlobalKey<MemoTransitionState> _memo = GlobalKey<MemoTransitionState>();
  final GlobalKey<State<ProfilerOverlay>> _profiler =
      GlobalKey<State<ProfilerOverlay>>();

  MemoVariant _variant = MemoVariant.normal;
  bool _showProfiler = true;
  bool _effectsOn = true;
  bool _reducePreview = false;
  bool _memoOpen = true;
  int _closes = 0;

  @override
  void initState() {
    super.initState();
    DevStats.screen = 'dev-lab';
  }

  @override
  void dispose() {
    _keys.dispose();
    super.dispose();
  }

  VisualStyleController? get _visual => VisualStyleScope.maybeOf(context);

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!kDevTools || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.f3:
        setState(() => _showProfiler = !_showProfiler);
      case LogicalKeyboardKey.f4:
        _visual?.toggle();
      case LogicalKeyboardKey.f5:
        _nextVariant();
      case LogicalKeyboardKey.f6:
        _memo.currentState?.replay();
      case LogicalKeyboardKey.f7:
        setState(() => _effectsOn = !_effectsOn);
      case LogicalKeyboardKey.f8:
        setState(() => _reducePreview = !_reducePreview);
      case LogicalKeyboardKey.f9:
        _printCapture();
      case LogicalKeyboardKey.f10:
        (_profiler.currentState as dynamic)?.reset();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _nextVariant() {
    final next =
        MemoVariant.values[(_variant.index + 1) % MemoVariant.values.length];
    setState(() => _variant = next);
  }

  void _printCapture() {
    final state = _profiler.currentState as dynamic;
    final text = state?.summary(VisualProfile.of(context));
    if (text != null) {
      debugPrint('--- QA CAPTURE ---\n$text\n------------------');
    }
  }

  @override
  Widget build(BuildContext context) {
    // F8 previews reduce motion without touching the persisted setting, so a
    // tester can flip it repeatedly without leaving the device changed.
    final media = MediaQuery.of(context);
    return Focus(
      focusNode: _keys,
      autofocus: true,
      onKeyEvent: _onKey,
      child: MediaQuery(
        data: media.copyWith(
          disableAnimations: media.disableAnimations || _reducePreview,
        ),
        child: ProfilerOverlay(
          key: _profiler,
          visible: _showProfiler,
          child: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(72, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DEV LAB', style: Tokens.label),
                    const SizedBox(height: 4),
                    Text(
                      _variant.label.toUpperCase(),
                      style: Tokens.display
                          .copyWith(color: Tokens.paper, fontSize: 26),
                    ),
                    const SizedBox(height: 12),
                    _Controls(
                      effectsOn: _effectsOn,
                      reducePreview: _reducePreview,
                      closes: _closes,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Center(
                        child: _memoOpen
                            ? MemoTransition(
                                key: _memo,
                                variant: _variant,
                                onClosed: () => setState(() {
                                  _closes++;
                                  _memoOpen = false;
                                }),
                                child: _MemoSample(variant: _variant),
                              )
                            : const SizedBox(),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Chip('NEXT (F5)', _nextVariant),
                        _Chip('REPLAY (F6)', () {
                          setState(() => _memoOpen = true);
                          _memo.currentState?.replay();
                        }),
                        _Chip('SKIP', () => _memo.currentState?.skip()),
                        _Chip('CLOSE', () => _memo.currentState?.close()),
                        _Chip('REOPEN', () {
                          setState(() => _memoOpen = true);
                        }),
                        _Chip('CAPTURE (F9)', _printCapture),
                        _Chip('OPTIONS', () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const OptionsScreen(),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.effectsOn,
    required this.reducePreview,
    required this.closes,
  });

  final bool effectsOn;
  final bool reducePreview;
  final int closes;

  @override
  Widget build(BuildContext context) {
    final profile = VisualProfile.of(context);
    return DefaultTextStyle(
      style: Tokens.label.copyWith(fontSize: 11, height: 1.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('style ${profile.neon ? 'IMMERSIVE NEON' : 'STANDARD'} (F4)'),
          Text('reduce ${profile.reduceMotion} (F8 preview $reducePreview)'),
          Text('effects $effectsOn (F7)   closes $closes'),
        ],
      ),
    );
  }
}

/// Stand-in content, sized like a real depot board so the motion reads true.
class _MemoSample extends StatelessWidget {
  const _MemoSample({required this.variant});

  final MemoVariant variant;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      color: Tokens.paper,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEPOT MEMO',
            style: Tokens.label.copyWith(color: Tokens.ink),
          ),
          const SizedBox(height: 8),
          Text(
            variant.label.toUpperCase(),
            style: Tokens.body.copyWith(
              color: Tokens.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 1; i <= 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'LINE $i · SAMPLE ROW',
                style: Tokens.label.copyWith(color: Tokens.ink),
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(border: Border.all(color: Tokens.mute)),
        child: Text(label, style: Tokens.label),
      ),
    );
  }
}
