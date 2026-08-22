import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sort_rush/core/floor_board.dart';
import 'package:sort_rush/ui/prefs_score_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  BoardEntry entry(int score) => BoardEntry(
        score: score,
        sorted: score ~/ 10,
        seed: 1,
        bestCombo: 2,
        atMs: score,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('a recorded clocking survives a fresh store', () async {
    final first = PrefsScoreStore();
    await first.record(entry(240));

    final relaunched = PrefsScoreStore();
    final loaded = await relaunched.load();
    expect(loaded, hasLength(1));
    expect(loaded.first.score, 240);
  });

  test('malformed prefs load empty instead of throwing', () async {
    SharedPreferences.setMockInitialValues({
      FloorBoard.prefsKey: '{not json',
    });

    final store = PrefsScoreStore();
    expect(await store.load(), isEmpty);

    await store.record(entry(50));
    expect((await store.load()).first.score, 50);
  });

  test('a wallet survives a fresh store and clamps', () async {
    final first = PrefsScoreStore();
    await first.saveWallet(40);
    expect(await first.loadWallet(), FloorBoard.walletCap);

    final relaunched = PrefsScoreStore();
    expect(await relaunched.loadWallet(), FloorBoard.walletCap);
  });

  test('a malformed wallet loads as zero', () async {
    SharedPreferences.setMockInitialValues({
      FloorBoard.walletKey: 'nope',
    });
    expect(await PrefsScoreStore().loadWallet(), 0);
  });
}
