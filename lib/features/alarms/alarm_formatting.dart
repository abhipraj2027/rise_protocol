import 'package:intl/intl.dart';

import '../../data/alarm.dart';

/// Presentation helpers shared by the alarm list, the row, and the
/// next-alarm hero. Pure functions — no widgets — so they're trivial to
/// unit-test.
extension AlarmDisplay on Alarm {
  /// "6:40 AM" or "06:40", following the device's 12/24-hour setting
  /// (pass `MediaQuery.alwaysUse24HourFormatOf(context)`).
  String clockLabel({required bool use24h}) =>
      formatClock(DateTime(2000, 1, 1, hour, minute), use24h: use24h);

  /// The next moment this alarm fires, as a [DateTime], or null if disabled.
  DateTime? nextFire({DateTime? from}) {
    if (!enabled) return null;
    return DateTime.fromMillisecondsSinceEpoch(nextTriggerMillis(from: from));
  }
}

/// "6:40 AM" / "06:40" for any [DateTime].
String formatClock(DateTime when, {required bool use24h}) =>
    (use24h ? DateFormat.Hm() : DateFormat.jm()).format(when);

/// The clock split for display at two sizes: ("6:40", "AM") in 12-hour
/// mode, ("06:40", null) in 24-hour mode.
(String, String?) clockParts(int hour, int minute, {required bool use24h}) {
  final dt = DateTime(2000, 1, 1, hour, minute);
  if (use24h) return (DateFormat.Hm().format(dt), null);
  return (DateFormat('h:mm').format(dt), DateFormat('a').format(dt));
}

/// "in 7h 32m", "in 45m", "in less than a minute", "in 3 days".
String humanizeUntil(Duration d) {
  if (d.isNegative || d.inSeconds < 60) return 'in less than a minute';
  if (d.inMinutes < 60) return 'in ${d.inMinutes}m';
  if (d.inHours < 24) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return m == 0 ? 'in ${h}h' : 'in ${h}h ${m}m';
  }
  final days = d.inHours ~/ 24;
  return days == 1 ? 'in 1 day' : 'in $days days';
}

/// "Today 6:40 AM", "Tomorrow 6:40 AM", "Fri 6:40 AM" (or 24-hour times).
String dayAndTime(DateTime when, {DateTime? now, required bool use24h}) {
  final ref = now ?? DateTime.now();
  final today = DateTime(ref.year, ref.month, ref.day);
  final target = DateTime(when.year, when.month, when.day);
  final deltaDays = target.difference(today).inDays;
  final time = formatClock(when, use24h: use24h);
  if (deltaDays <= 0) return 'Today $time';
  if (deltaDays == 1) return 'Tomorrow $time';
  return '${DateFormat.E().format(when)} $time';
}

/// The soonest-firing enabled alarm, or null if none are enabled.
Alarm? soonestAlarm(List<Alarm> alarms, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  Alarm? best;
  int bestMillis = 1 << 62;
  for (final a in alarms) {
    if (!a.enabled) continue;
    final m = a.nextTriggerMillis(from: ref);
    if (m < bestMillis) {
      bestMillis = m;
      best = a;
    }
  }
  return best;
}

/// "Mon–Fri", "Every day", "Weekends", "Mon Wed Fri", "Once".
String repeatSummary(Set<int> days) {
  if (days.isEmpty) return 'Once';
  if (days.length == 7) return 'Every day';
  final sorted = days.toList()..sort();
  if (sorted.length == 5 && sorted.every((d) => d <= 5)) return 'Mon–Fri';
  if (sorted.length == 2 && sorted.contains(6) && sorted.contains(7)) {
    return 'Weekends';
  }
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return sorted.map((d) => names[d - 1]).join(' ');
}

/// The sleep goal the home card plans around.
const sleepGoal = Duration(hours: 8);

/// A bedtime nudge for the next alarm, or null when it isn't tonight's
/// alarm (more than 14h away) or it's too close to matter (under 1h):
///  - "Go to bed by 10:40 PM for 8 hours of sleep" while there's time;
///  - "Sleep now and you'll get 6h 35m" once that bedtime has passed
///    (rounded down to 5 minutes).
String? sleepHint(DateTime now, DateTime fireAt, {required bool use24h}) {
  final until = fireAt.difference(now);
  if (until > const Duration(hours: 14) || until < const Duration(hours: 1)) {
    return null;
  }
  final bedtime = fireAt.subtract(sleepGoal);
  if (now.isBefore(bedtime)) {
    return 'Go to bed by ${formatClock(bedtime, use24h: use24h)} '
        'for ${sleepGoal.inHours} hours of sleep';
  }
  final minutes = until.inMinutes - until.inMinutes % 5;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return "Sleep now and you'll get ${m == 0 ? '${h}h' : '${h}h ${m}m'}";
}
