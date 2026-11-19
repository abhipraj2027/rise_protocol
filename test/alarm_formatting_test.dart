import 'package:flutter_test/flutter_test.dart';
import 'package:rise_protocol/data/alarm.dart';
import 'package:rise_protocol/features/alarms/alarm_formatting.dart';

/// Newer CLDR data puts a narrow no-break space before AM/PM.
String plain(String s) => s.replaceAll(String.fromCharCode(0x202f), ' ');

void main() {
  group('clock formatting follows the 12/24-hour setting', () {
    test('clockLabel', () {
      const alarm = Alarm(hour: 18, minute: 5);
      expect(plain(alarm.clockLabel(use24h: false)), '6:05 PM');
      expect(alarm.clockLabel(use24h: true), '18:05');
    });

    test('clockParts splits off the period only in 12-hour mode', () {
      expect(clockParts(6, 40, use24h: false), ('6:40', 'AM'));
      expect(clockParts(0, 15, use24h: false), ('12:15', 'AM'));
      expect(clockParts(6, 40, use24h: true), ('06:40', null));
    });

    test('dayAndTime', () {
      final now = DateTime(2026, 9, 25, 22, 0); // a Friday
      final tomorrow = DateTime(2026, 9, 26, 7, 30);
      expect(
        plain(dayAndTime(tomorrow, now: now, use24h: false)),
        'Tomorrow 7:30 AM',
      );
      expect(dayAndTime(tomorrow, now: now, use24h: true), 'Tomorrow 07:30');
    });
  });

  group('sleepHint', () {
    final alarm = DateTime(2026, 11, 20, 6, 40);

    test('suggests a bedtime while there is time', () {
      expect(
        plain(sleepHint(DateTime(2026, 11, 19, 21, 0), alarm, use24h: false)!),
        'Go to bed by 10:40 PM for 8 hours of sleep',
      );
    });

    test('says how much sleep is left once bedtime has passed', () {
      expect(
        sleepHint(DateTime(2026, 11, 20, 0, 3), alarm, use24h: true),
        "Sleep now and you'll get 6h 35m",
      );
    });

    test('stays quiet for far-off or imminent alarms', () {
      expect(sleepHint(DateTime(2026, 11, 19, 12, 0), alarm, use24h: true), isNull);
      expect(sleepHint(DateTime(2026, 11, 20, 6, 0), alarm, use24h: true), isNull);
    });
  });
}
