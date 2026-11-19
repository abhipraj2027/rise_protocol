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

/// One cleared alarm: when the mission was finished and how many snoozes
/// it took to get there.
class WakeEntry {
  const WakeEntry({required this.at, required this.snoozes});

  final DateTime at;
  final int snoozes;

  String encode() => '${at.toIso8601String()}|$snoozes';

  static WakeEntry? decode(String raw) {
    final parts = raw.split('|');
    final at = DateTime.tryParse(parts.first);
    if (at == null) return null;
    return WakeEntry(
      at: at,
      snoozes: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }
}

/// The last seven days (oldest first, ending today) as the stats screen
/// shows them.
class WeekStats {
  WeekStats._({
    required this.days,
    required this.mornings,
    required this.streakDays,
  });

  /// Midnight of each of the seven days, oldest first.
  final List<DateTime> days;

  /// The first wake-up on each of [days], or null if there wasn't one.
  final List<WakeEntry?> mornings;

  /// Today's streak, or yesterday's if today has no wake-up yet — so the
  /// number doesn't drop to zero every evening.
  final int streakDays;

  int get daysUp => mornings.whereType<WakeEntry>().length;

  int get snoozes =>
      mornings.whereType<WakeEntry>().fold(0, (sum, e) => sum + e.snoozes);

  /// Mean wake-up time of day over the days with one, or null if none.
  Duration? get averageWake {
    final up = mornings.whereType<WakeEntry>().toList();
    if (up.isEmpty) return null;
    final total = up.fold<int>(0, (sum, e) => sum + e.at.hour * 60 + e.at.minute);
    return Duration(minutes: (total / up.length).round());
  }

  factory WeekStats.from(List<WakeEntry> entries, Set<String> wakeDays, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final days = [
      for (var i = 6; i >= 0; i--) DateTime(today.year, today.month, today.day - i),
    ];
    WakeEntry? firstOn(DateTime day) {
      WakeEntry? best;
      for (final e in entries) {
        final d = e.at;
        if (d.year == day.year && d.month == day.month && d.day == day.day) {
          if (best == null || d.isBefore(best.at)) best = e;
        }
      }
      return best;
    }

    final streakToday = WakeStats.streakEndingOn(wakeDays, today);
    return WeekStats._(
      days: days,
      mornings: [for (final d in days) firstOn(d)],
      streakDays: streakToday > 0
          ? streakToday
          : WakeStats.streakEndingOn(wakeDays, days[5]),
    );
  }
}

/// Wake-up bookkeeping in shared preferences: snooze counts per alarm and
/// the days the user actually got up.
///
/// Snooze counts are written natively (SnoozeCounter.kt) because snoozing
/// from the notification never touches Dart; this side reads them and
/// clears them once the alarm is dismissed.
class WakeStats {
  static const _wakeDaysKey = 'wake_days';
  static const _logKey = 'wake_log';
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
    final log = [
      ...prefs.getStringList(_logKey) ?? const <String>[],
      WakeEntry(at: when, snoozes: snoozes).encode(),
    ];
    await prefs.setStringList(
      _logKey,
      log.length > _maxDays ? log.sublist(log.length - _maxDays) : log,
    );
    await prefs.remove(_countKey(alarmId));
    await prefs.remove(_atKey(alarmId));

    return WakeSummary(
      wokeAt: when,
      snoozes: snoozes,
      streakDays: streakEndingOn(kept.toSet(), when),
    );
  }

  /// The last seven days, for the stats screen.
  Future<WeekStats> week({DateTime? now}) async {
    final prefs = await _prefs();
    final entries = (prefs.getStringList(_logKey) ?? const <String>[])
        .map(WakeEntry.decode)
        .whereType<WakeEntry>()
        .toList();
    final days = {...prefs.getStringList(_wakeDaysKey) ?? const <String>[]};
    return WeekStats.from(entries, days, now ?? DateTime.now());
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
