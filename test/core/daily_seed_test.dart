import 'package:flutter_test/flutter_test.dart';
import 'package:sort_rush/core/daily_seed.dart';

void main() {
  test('the same UTC day produces the same seed', () {
    final morning = DateTime.utc(2026, 8, 17, 1);
    final night = DateTime.utc(2026, 8, 17, 23, 59);
    expect(dailySeed(morning), dailySeed(night));
    expect(dailyStamp(morning), '2026-08-17');
  });

  test('the next day is a different seed', () {
    expect(
      dailySeed(DateTime.utc(2026, 8, 17)),
      isNot(dailySeed(DateTime.utc(2026, 8, 18))),
    );
  });
}
