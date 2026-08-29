import 'dart:convert';

import 'run_summary.dart';
import 'shop.dart';

/// One clocking on the local floor record.
class BoardEntry {
  const BoardEntry({
    required this.score,
    required this.sorted,
    required this.seed,
    required this.bestCombo,
    required this.atMs,
  });

  factory BoardEntry.fromSummary(RunSummary summary, {required int atMs}) =>
      BoardEntry(
        score: summary.postedScore,
        sorted: summary.sorted,
        seed: summary.seed,
        bestCombo: summary.bestCombo,
        atMs: atMs,
      );

  factory BoardEntry.fromJson(Map<String, dynamic> json) => BoardEntry(
        score: json['score'] as int,
        sorted: json['sorted'] as int,
        seed: json['seed'] as int,
        bestCombo: json['combo'] as int,
        atMs: json['at'] as int,
      );

  final int score;
  final int sorted;
  final int seed;
  final int bestCombo;
  final int atMs;

  Map<String, Object?> toJson() => {
        'score': score,
        'sorted': sorted,
        'seed': seed,
        'combo': bestCombo,
        'at': atMs,
      };
}

/// Ranks endless clockings. Pure Dart so a malformed save can be tested
/// without a plugin or a widget tree.
abstract final class FloorBoard {
  static const int cap = 5;
  static const int walletCap = EndlessShop.walletCap;
  static const String prefsKey = 'sort_rush.floor_board.v1';
  static const String walletKey = 'sort_rush.wallet.v1';

  static int clampWallet(int pay) => EndlessShop.clampWallet(pay);

  /// Missing or unreadable input becomes 0 — a corrupt wallet must not crash.
  static int decodeWallet(Object? raw) {
    if (raw is int) {
      return clampWallet(raw);
    }
    if (raw is String) {
      return clampWallet(int.tryParse(raw) ?? 0);
    }
    return 0;
  }

  /// Highest score first. Earlier clocking wins a tie. Never longer than [cap].
  static List<BoardEntry> ranked(List<BoardEntry> entries) {
    if (entries.isEmpty) {
      return const [];
    }
    final next = [...entries]..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) {
          return byScore;
        }
        return a.atMs.compareTo(b.atMs);
      });
    if (next.length <= cap) {
      return next;
    }
    return next.sublist(0, cap);
  }

  static List<BoardEntry> insert(
    List<BoardEntry> current,
    BoardEntry incoming,
  ) =>
      ranked([...current, incoming]);

  /// Empty on any parse failure — a corrupt save must not crash launch.
  static List<BoardEntry> decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return ranked([
        for (final item in decoded)
          if (item is Map) BoardEntry.fromJson(Map<String, dynamic>.from(item)),
      ]);
    } on Object {
      return const [];
    }
  }

  static String encode(List<BoardEntry> entries) =>
      jsonEncode([for (final entry in entries) entry.toJson()]);
}

/// Where clockings live. Implementations may use prefs; this type does not.
abstract class ScoreStore {
  Future<List<BoardEntry>> load();

  Future<void> record(BoardEntry entry);

  Future<int> loadWallet();

  Future<void> saveWallet(int pay);
}

/// In-memory store for tests and for a first frame before prefs resolve.
class MemoryScoreStore implements ScoreStore {
  MemoryScoreStore([List<BoardEntry>? seed, int wallet = 0])
      : _entries = FloorBoard.ranked([...?seed]),
        _wallet = FloorBoard.clampWallet(wallet);

  List<BoardEntry> _entries;
  int _wallet;

  @override
  Future<List<BoardEntry>> load() async =>
      List<BoardEntry>.unmodifiable(_entries);

  @override
  Future<void> record(BoardEntry entry) async {
    _entries = FloorBoard.insert(_entries, entry);
  }

  @override
  Future<int> loadWallet() async => _wallet;

  @override
  Future<void> saveWallet(int pay) async {
    _wallet = FloorBoard.clampWallet(pay);
  }
}
