import 'package:flutter/widgets.dart';

import '../core/floor_board.dart';

/// Live floor record. Home listens; Results writes; prefs stay behind
/// [ScoreStore] so widget tests can inject memory.
class ScoreBoard extends ChangeNotifier {
  ScoreBoard(this._store);

  final ScoreStore _store;
  List<BoardEntry> _entries = const [];
  int _wallet = 0;

  List<BoardEntry> get entries => _entries;

  int get wallet => _wallet;

  Future<void> load() async {
    _entries = await _store.load();
    _wallet = await _store.loadWallet();
    notifyListeners();
  }

  Future<void> record(BoardEntry entry) async {
    await _store.record(entry);
    _entries = await _store.load();
    notifyListeners();
  }

  Future<void> deposit(int leftover) async {
    await _store.saveWallet(leftover);
    _wallet = await _store.loadWallet();
    notifyListeners();
  }
}

class ScoreBoardScope extends InheritedNotifier<ScoreBoard> {
  const ScoreBoardScope({
    super.key,
    required ScoreBoard super.notifier,
    required super.child,
  });

  static ScoreBoard? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScoreBoardScope>()?.notifier;
}
