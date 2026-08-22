import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/floor_board.dart';
import 'package:sort_rush/core/run_engine.dart';
import 'package:sort_rush/core/run_summary.dart';

void main() {
  BoardEntry entry({
    required int score,
    int sorted = 10,
    int seed = 1,
    int combo = 2,
    required int atMs,
  }) =>
      BoardEntry(
        score: score,
        sorted: sorted,
        seed: seed,
        bestCombo: combo,
        atMs: atMs,
      );

  test('ranks by score descending and caps at five', () {
    var board = <BoardEntry>[];
    for (var i = 0; i < 6; i++) {
      board = FloorBoard.insert(
        board,
        entry(score: i * 10, atMs: i),
      );
    }

    expect(board, hasLength(FloorBoard.cap));
    expect(
      board.map((e) => e.score),
      [50, 40, 30, 20, 10],
    );
  });

  test('a tie keeps the earlier clocking above the later one', () {
    final board = FloorBoard.insert(
      [entry(score: 100, atMs: 10)],
      entry(score: 100, atMs: 20),
    );

    expect(board.map((e) => e.atMs), [10, 20]);
  });

  test('round-trips through JSON', () {
    final original = [
      entry(score: 400, sorted: 32, seed: 7, combo: 5, atMs: 99),
    ];
    final restored = FloorBoard.decode(FloorBoard.encode(original));

    expect(restored, hasLength(1));
    expect(restored.first.score, 400);
    expect(restored.first.sorted, 32);
    expect(restored.first.seed, 7);
    expect(restored.first.bestCombo, 5);
    expect(restored.first.atMs, 99);
  });

  test('malformed JSON loads as an empty board', () {
    expect(FloorBoard.decode(null), isEmpty);
    expect(FloorBoard.decode(''), isEmpty);
    expect(FloorBoard.decode('{'), isEmpty);
    expect(FloorBoard.decode('"nope"'), isEmpty);
    expect(FloorBoard.decode('{"score":1}'), isEmpty);
    expect(FloorBoard.decode('[{"score":"x"}]'), isEmpty);
  });

  test('fromSummary posts the wagered score', () {
    const summary = RunSummary(
      levelId: 0,
      outcome: RunOutcome.failed,
      score: 80,
      sorted: 12,
      misrouted: 1,
      dropped: 0,
      bestCombo: 3,
      endless: true,
      seed: 42,
      wagered: true,
    );

    expect(BoardEntry.fromSummary(summary, atMs: 1).score, 0);
  });

  test('a seeded memory store ranks on load, not insertion order', () async {
    final store = MemoryScoreStore([
      entry(score: 120, atMs: 1),
      entry(score: 400, atMs: 2),
    ]);
    expect((await store.load()).map((e) => e.score), [400, 120]);
  });

  test('the wallet clamps to twelve and treats junk as zero', () {
    expect(FloorBoard.clampWallet(-3), 0);
    expect(FloorBoard.clampWallet(12), 12);
    expect(FloorBoard.clampWallet(13), 12);
    expect(FloorBoard.decodeWallet(null), 0);
    expect(FloorBoard.decodeWallet('nope'), 0);
    expect(FloorBoard.decodeWallet('9'), 9);
    expect(FloorBoard.decodeWallet(40), 12);
  });

  test('MemoryScoreStore inserts through the same ranking', () async {
    final store = MemoryScoreStore();
    await store.record(entry(score: 10, atMs: 1));
    await store.record(entry(score: 30, atMs: 2));
    final loaded = await store.load();
    expect(loaded.map((e) => e.score), [30, 10]);
  });
}
