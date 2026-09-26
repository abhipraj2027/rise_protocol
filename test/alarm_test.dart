import 'package:flutter_test/flutter_test.dart';
import 'package:rise_protocol/data/alarm.dart';
import 'package:rise_protocol/features/alarms/alarm_formatting.dart';

DateTime nextFire(Alarm alarm, DateTime from) =>
    DateTime.fromMillisecondsSinceEpoch(alarm.nextTriggerMillis(from: from));

void main() {
  // 2026-09-25 is a Friday (weekday 5), so 09-26 is Sat and 09-28 is Mon.
  test('the fixed test dates are the weekdays these tests assume', () {
    expect(DateTime(2026, 9, 25).weekday, DateTime.friday);
    expect(DateTime(2026, 9, 28).weekday, DateTime.monday);
  });

  group('one-time alarms', () {
    const alarm = Alarm(hour: 6, minute: 40);

    test('ring later today when the time is still ahead', () {
      expect(nextFire(alarm, DateTime(2026, 9, 25, 5, 0)),
          DateTime(2026, 9, 25, 6, 40));
    });

    test('ring tomorrow when the time has already passed', () {
      expect(nextFire(alarm, DateTime(2026, 9, 25, 7, 0)),
          DateTime(2026, 9, 26, 6, 40));
    });

    test('ring tomorrow when the time is exactly now', () {
      expect(nextFire(alarm, DateTime(2026, 9, 25, 6, 40)),
          DateTime(2026, 9, 26, 6, 40));
    });
  });

  group('repeating alarms', () {
    const weekdays = Alarm(
      hour: 6,
      minute: 40,
      repeatDays: {1, 2, 3, 4, 5},
    );

    test('ring the same day when that time is still ahead', () {
      expect(nextFire(weekdays, DateTime(2026, 9, 25, 5, 0)),
          DateTime(2026, 9, 25, 6, 40));
    });

    test('skip the weekend after Friday morning has passed', () {
      expect(nextFire(weekdays, DateTime(2026, 9, 25, 18, 0)),
          DateTime(2026, 9, 28, 6, 40));
    });

    test('at the exact trigger time, move on to the next matching day', () {
      expect(nextFire(weekdays, DateTime(2026, 9, 25, 6, 40)),
          DateTime(2026, 9, 28, 6, 40));
    });

    test('a weekend alarm asked on Friday evening rings Saturday', () {
      const weekend = Alarm(hour: 8, minute: 0, repeatDays: {6, 7});
      expect(nextFire(weekend, DateTime(2026, 9, 25, 18, 0)),
          DateTime(2026, 9, 26, 8, 0));
    });

    test('an every-day alarm just after its time rings tomorrow', () {
      const daily = Alarm(
        hour: 6,
        minute: 40,
        repeatDays: {1, 2, 3, 4, 5, 6, 7},
      );
      expect(nextFire(daily, DateTime(2026, 9, 25, 6, 41)),
          DateTime(2026, 9, 26, 6, 40));
    });

    test('a single-weekday alarm rolls a full week', () {
      const fridays = Alarm(hour: 6, minute: 40, repeatDays: {5});
      expect(nextFire(fridays, DateTime(2026, 9, 25, 7, 0)),
          DateTime(2026, 10, 2, 6, 40));
    });

    test('month and year boundaries roll over correctly', () {
      const daily = Alarm(
        hour: 6,
        minute: 40,
        repeatDays: {1, 2, 3, 4, 5, 6, 7},
      );
      expect(nextFire(daily, DateTime(2026, 12, 31, 23, 0)),
          DateTime(2027, 1, 1, 6, 40));
    });
  });

  group('storage round trip', () {
    test('toMap / fromMap keep every field', () {
      const original = Alarm(
        id: 7,
        hour: 6,
        minute: 40,
        label: 'Gym',
        enabled: false,
        repeatDays: {1, 3, 5},
        missionType: MissionType.none,
        snoozeMinutes: 9,
      );
      final copy = Alarm.fromMap(original.toMap());
      expect(copy.id, 7);
      expect(copy.hour, 6);
      expect(copy.minute, 40);
      expect(copy.label, 'Gym');
      expect(copy.enabled, false);
      expect(copy.repeatDays, {1, 3, 5});
      expect(copy.missionType, MissionType.none);
      expect(copy.snoozeMinutes, 9);
    });

    test('an unknown mission name falls back to none', () {
      expect(MissionType.fromName('does-not-exist'), MissionType.none);
    });
  });

  group('display helpers', () {
    test('humanizeUntil', () {
      expect(humanizeUntil(const Duration(seconds: 30)),
          'in less than a minute');
      expect(humanizeUntil(const Duration(minutes: 45)), 'in 45m');
      expect(humanizeUntil(const Duration(hours: 7, minutes: 32)), 'in 7h 32m');
      expect(humanizeUntil(const Duration(hours: 2)), 'in 2h');
      expect(humanizeUntil(const Duration(hours: 24)), 'in 1 day');
      expect(humanizeUntil(const Duration(days: 3)), 'in 3 days');
    });

    test('repeatSummary', () {
      expect(repeatSummary({}), 'Once');
      expect(repeatSummary({1, 2, 3, 4, 5, 6, 7}), 'Every day');
      expect(repeatSummary({1, 2, 3, 4, 5}), 'Mon–Fri');
      expect(repeatSummary({6, 7}), 'Weekends');
      expect(repeatSummary({1, 3, 5}), 'Mon Wed Fri');
    });
  });
}
