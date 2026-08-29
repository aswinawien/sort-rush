import 'package:flutter/material.dart';

import '../core/floor_board.dart';
import 'audio_scope.dart';
import 'home_screen.dart';
import 'prefs_score_store.dart';
import 'score_board.dart';
import 'theme.dart';
import 'visual_style.dart';

class SortRushApp extends StatefulWidget {
  const SortRushApp({super.key, this.store});

  /// Tests inject a memory store. The app uses prefs.
  final ScoreStore? store;

  @override
  State<SortRushApp> createState() => _SortRushAppState();
}

class _SortRushAppState extends State<SortRushApp> {
  late final ScoreBoard _board = ScoreBoard(widget.store ?? PrefsScoreStore());
  late final AudioController _audio = AudioController();
  late final VisualStyleController _visual = VisualStyleController();

  @override
  void initState() {
    super.initState();
    _board.load();
    _audio.load();
    _visual.load();
  }

  @override
  void dispose() {
    _board.dispose();
    _audio.dispose();
    _visual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScoreBoardScope(
      notifier: _board,
      child: AudioScope(
        notifier: _audio,
        child: VisualStyleScope(
          notifier: _visual,
          child: MaterialApp(
            title: 'Sort Rush',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            navigatorObservers: [homeRouteObserver],
            home: const HomeScreen(),
          ),
        ),
      ),
    );
  }
}
