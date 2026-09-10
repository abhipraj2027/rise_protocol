import 'package:intl/intl.dart';

import '../../data/alarm.dart';

/// Presentation helpers shared by the alarm list, the row, and the
/// next-alarm hero. Pure functions — no widgets — so they're trivial to
/// unit-test.
extension AlarmDisplay on Alarm {
  /// "6:40 AM" — the wall-clock time, locale-formatted.
  String get clockLabel {
    final dt = DateTime(2000, 1, 1, hour, minute);
    return DateFormat.jm().format(dt);
  }

  /// The next moment this alarm fires, as a [DateTime], or null if disabled.
  DateTime? nextFire({DateTime? from}) {
    if (!enabled) return null;
    return DateTime.fromMillisecondsSinceEpoch(nextTriggerMillis(from: from));
  }
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

/// "Today 6:40 AM", "Tomorrow 6:40 AM", "Fri 6:40 AM".
String dayAndTime(DateTime when, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final today = DateTime(ref.year, ref.month, ref.day);
  final target = DateTime(when.year, when.month, when.day);
  final deltaDays = target.difference(today).inDays;
  final time = DateFormat.jm().format(when);
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
