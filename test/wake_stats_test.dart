import 'package:flutter_test/flutter_test.dart';
import 'package:rise_protocol/core/wake_stats.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('streakEndingOn', () {
    final day = DateTime(2026, 11, 19, 7, 0);

    test('counts back consecutive days', () {
      final days = {'2026-11-17', '2026-11-18', '2026-11-19'};
      expect(WakeStats.streakEndingOn(days, day), 3);
    });

    test('a gap ends the streak', () {
      final days = {'2026-11-15', '2026-11-18', '2026-11-19'};
      expect(WakeStats.streakEndingOn(days, day), 2);
    });

    test('no wake today means no streak', () {
      expect(WakeStats.streakEndingOn({'2026-11-18'}, day), 0);
    });

    test('crosses month boundaries', () {
      final days = {'2026-10-31', '2026-11-01'};
      expect(WakeStats.streakEndingOn(days, DateTime(2026, 11, 1)), 2);
    });
  });

  group('snooze counts written by native code', () {
    final now = DateTime(2026, 11, 19, 7, 0);

    test('are read while fresh', () async {
      SharedPreferences.setMockInitialValues({
        'snooze_count_4': 2,
        'snooze_at_4': now.subtract(const Duration(minutes: 10)).millisecondsSinceEpoch,
      });
      expect(await WakeStats().snoozesUsed(4, now: now), 2);
    });

    test('are ignored once stale', () async {
      SharedPreferences.setMockInitialValues({
        'snooze_count_4': 2,
        'snooze_at_4': now.subtract(const Duration(hours: 5)).millisecondsSinceEpoch,
      });
      expect(await WakeStats().snoozesUsed(4, now: now), 0);
    });
  });

  test('recordWake reports snoozes and streak, then clears the count',
      () async {
    final now = DateTime(2026, 11, 19, 7, 0);
    SharedPreferences.setMockInitialValues({
      'wake_days': ['2026-11-18'],
      'snooze_count_4': 1,
      'snooze_at_4': now.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
    });
    final stats = WakeStats();

    final summary = await stats.recordWake(4, now: now);
    expect(summary.snoozes, 1);
    expect(summary.streakDays, 2);
    expect(await stats.snoozesUsed(4, now: now), 0);
  });
}
