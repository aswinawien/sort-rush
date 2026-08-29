import 'package:shared_preferences/shared_preferences.dart';

import '../core/floor_board.dart';

/// Device-side store. Malformed JSON becomes an empty board, never a crash.
class PrefsScoreStore implements ScoreStore {
  PrefsScoreStore({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<List<BoardEntry>> load() async {
    final prefs = await _instance();
    return FloorBoard.decode(prefs.getString(FloorBoard.prefsKey));
  }

  @override
  Future<void> record(BoardEntry entry) async {
    final prefs = await _instance();
    final next = FloorBoard.insert(
      FloorBoard.decode(prefs.getString(FloorBoard.prefsKey)),
      entry,
    );
    await prefs.setString(FloorBoard.prefsKey, FloorBoard.encode(next));
  }

  @override
  Future<int> loadWallet() async {
    final prefs = await _instance();
    return FloorBoard.decodeWallet(prefs.get(FloorBoard.walletKey));
  }

  @override
  Future<void> saveWallet(int pay) async {
    final prefs = await _instance();
    await prefs.setInt(FloorBoard.walletKey, FloorBoard.clampWallet(pay));
  }
}
