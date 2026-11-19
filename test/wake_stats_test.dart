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

  group('WeekStats', () {
    final now = DateTime(2026, 11, 19, 21, 0); // evening, no wake today yet

    test("uses each day's first wake-up and totals the week", () {
      final entries = [
        WakeEntry(at: DateTime(2026, 11, 18, 6, 30), snoozes: 1),
        WakeEntry(at: DateTime(2026, 11, 18, 9, 0), snoozes: 0),
        WakeEntry(at: DateTime(2026, 11, 17, 7, 30), snoozes: 2),
        WakeEntry(at: DateTime(2026, 11, 1, 7, 0), snoozes: 5), // outside week
      ];
      final w = WeekStats.from(entries, {'2026-11-17', '2026-11-18'}, now);

      expect(w.days.first, DateTime(2026, 11, 13));
      expect(w.days.last, DateTime(2026, 11, 19));
      expect(w.daysUp, 2);
      expect(w.snoozes, 3);
      expect(w.mornings[5]?.at, DateTime(2026, 11, 18, 6, 30));
      expect(w.averageWake, const Duration(hours: 7)); // 6:30 and 7:30
    });

    test("keeps yesterday's streak until today has a wake-up", () {
      final w = WeekStats.from(const [], {'2026-11-17', '2026-11-18'}, now);
      expect(w.streakDays, 2);
    });
  });

  test('wake log entries round-trip', () {
    final e = WakeEntry(at: DateTime(2026, 11, 19, 6, 58), snoozes: 2);
    final back = WakeEntry.decode(e.encode())!;
    expect(back.at, e.at);
    expect(back.snoozes, 2);
    expect(WakeEntry.decode('garbage'), isNull);
  });
}
