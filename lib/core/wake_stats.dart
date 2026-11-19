import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the morning screen shows after a mission is cleared.
class WakeSummary {
  const WakeSummary({
    required this.wokeAt,
    required this.snoozes,
    required this.streakDays,
  });

  final DateTime wokeAt;

  /// Snoozes used on this alarm before it was dismissed.
  final int snoozes;

  /// Consecutive days, ending today, with at least one cleared mission.
  final int streakDays;
}

/// Wake-up bookkeeping in shared preferences: snooze counts per alarm and
/// the days the user actually got up.
///
/// Snooze counts are written natively (SnoozeCounter.kt) because snoozing
/// from the notification never touches Dart; this side reads them and
/// clears them once the alarm is dismissed.
class WakeStats {
  static const _wakeDaysKey = 'wake_days';
  static String _countKey(int id) => 'snooze_count_$id';
  static String _atKey(int id) => 'snooze_at_$id';

  /// Counts older than this belong to an earlier ring that was never
  /// properly dismissed. Matches STALE_AFTER_MILLIS in SnoozeCounter.kt.
  static const snoozeStaleAfter = Duration(hours: 3);

  /// Only this many days are kept — plenty for a streak and a week view.
  static const _maxDays = 120;

  Future<SharedPreferences> _prefs() async {
    final prefs = await SharedPreferences.getInstance();
    // Native may have written since this engine cached the file.
    await prefs.reload();
    return prefs;
  }

  /// Snoozes already used on [alarmId] in the current ring.
  Future<int> snoozesUsed(int alarmId, {DateTime? now}) async {
    final prefs = await _prefs();
    final at = prefs.getInt(_atKey(alarmId)) ?? 0;
    final ref = (now ?? DateTime.now()).millisecondsSinceEpoch;
    if (ref - at > snoozeStaleAfter.inMilliseconds) return 0;
    return prefs.getInt(_countKey(alarmId)) ?? 0;
  }

  /// Records a cleared mission: marks today as a wake day, clears the
  /// alarm's snooze count, and returns the summary for the morning screen.
  Future<WakeSummary> recordWake(int alarmId, {DateTime? now}) async {
    final when = now ?? DateTime.now();
    final snoozes = await snoozesUsed(alarmId, now: when);
    final prefs = await _prefs();

    final days = {...prefs.getStringList(_wakeDaysKey) ?? const <String>[]}
      ..add(dayKey(when));
    final kept = (days.toList()..sort()).reversed.take(_maxDays).toList();
    await prefs.setStringList(_wakeDaysKey, kept);
    await prefs.remove(_countKey(alarmId));
    await prefs.remove(_atKey(alarmId));

    return WakeSummary(
      wokeAt: when,
      snoozes: snoozes,
      streakDays: streakEndingOn(kept.toSet(), when),
    );
  }

  /// "2026-11-19" — sortable and locale-independent.
  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// How many consecutive days ending on [day] appear in [days].
  static int streakEndingOn(Set<String> days, DateTime day) {
    var streak = 0;
    var cursor = DateTime(day.year, day.month, day.day);
    while (days.contains(dayKey(cursor))) {
      streak++;
      // Calendar-day step (not 24h) so DST changes can't skip or repeat a day.
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }
}

final wakeStatsProvider = Provider<WakeStats>((ref) => WakeStats());
