import 'dart:convert';

/// The challenge a user must clear before an alarm can be dismissed.
///
/// Kept as a plain enum + registry (see `mission_type_x` below) rather than
/// a class hierarchy so new mission types are a one-line addition on both
/// the Dart and native sides.
enum MissionType {
  none,
  math,
  shake,
  photo,
  barcode;

  static MissionType fromName(String name) {
    return MissionType.values.firstWhere(
      (m) => m.name == name,
      orElse: () => MissionType.none,
    );
  }
}

extension MissionTypeX on MissionType {
  String get label {
    switch (this) {
      case MissionType.none:
        return 'None (tap to dismiss)';
      case MissionType.math:
        return 'Math problem';
      case MissionType.shake:
        return 'Shake to wake';
      case MissionType.photo:
        return 'Photo match';
      case MissionType.barcode:
        return 'Scan barcode';
    }
  }

  bool get isImplemented =>
      this == MissionType.none || this == MissionType.math;
}

/// The days of the week an alarm repeats on. Empty set = one-off alarm.
/// Uses DateTime.weekday values: 1 = Monday ... 7 = Sunday.
typedef RepeatDays = Set<int>;

class Alarm {
  final int? id;
  final int hour;
  final int minute;
  final String label;
  final bool enabled;
  final RepeatDays repeatDays;
  final MissionType missionType;
  final int missionDifficulty; // 1-3, meaning depends on mission type
  final String soundAsset;
  final int snoozeMinutes;
  final int maxSnoozes;

  const Alarm({
    this.id,
    required this.hour,
    required this.minute,
    this.label = '',
    this.enabled = true,
    this.repeatDays = const {},
    this.missionType = MissionType.math,
    this.missionDifficulty = 1,
    this.soundAsset = 'default_alarm',
    this.snoozeMinutes = 5,
    this.maxSnoozes = 3,
  });

  bool get isRepeating => repeatDays.isNotEmpty;

  Alarm copyWith({
    int? id,
    int? hour,
    int? minute,
    String? label,
    bool? enabled,
    RepeatDays? repeatDays,
    MissionType? missionType,
    int? missionDifficulty,
    String? soundAsset,
    int? snoozeMinutes,
    int? maxSnoozes,
  }) {
    return Alarm(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      label: label ?? this.label,
      enabled: enabled ?? this.enabled,
      repeatDays: repeatDays ?? this.repeatDays,
      missionType: missionType ?? this.missionType,
      missionDifficulty: missionDifficulty ?? this.missionDifficulty,
      soundAsset: soundAsset ?? this.soundAsset,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      maxSnoozes: maxSnoozes ?? this.maxSnoozes,
    );
  }

  /// Next epoch-millis this alarm should fire at, relative to [from].
  /// One-off alarms roll over to tomorrow if today's time has passed.
  int nextTriggerMillis({DateTime? from}) {
    final now = from ?? DateTime.now();
    DateTime candidate = DateTime(now.year, now.month, now.day, hour, minute);

    if (!isRepeating) {
      if (!candidate.isAfter(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      return candidate.millisecondsSinceEpoch;
    }

    // Repeating: walk forward up to 7 days to find the next matching weekday.
    for (int i = 0; i < 8; i++) {
      final c = candidate.add(Duration(days: i));
      final isToday = i == 0;
      if (repeatDays.contains(c.weekday) && (!isToday || c.isAfter(now))) {
        return c.millisecondsSinceEpoch;
      }
    }
    // Fallback — should not happen with a non-empty repeatDays set.
    return candidate.add(const Duration(days: 7)).millisecondsSinceEpoch;
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'hour': hour,
      'minute': minute,
      'label': label,
      'enabled': enabled ? 1 : 0,
      'repeat_days': jsonEncode(repeatDays.toList()),
      'mission_type': missionType.name,
      'mission_difficulty': missionDifficulty,
      'sound_asset': soundAsset,
      'snooze_minutes': snoozeMinutes,
      'max_snoozes': maxSnoozes,
    };
  }

  factory Alarm.fromMap(Map<String, Object?> map) {
    final rawDays = (jsonDecode(map['repeat_days'] as String? ?? '[]') as List)
        .map((e) => e as int)
        .toSet();
    return Alarm(
      id: map['id'] as int?,
      hour: map['hour'] as int,
      minute: map['minute'] as int,
      label: map['label'] as String? ?? '',
      enabled: (map['enabled'] as int? ?? 1) == 1,
      repeatDays: rawDays,
      missionType: MissionType.fromName(map['mission_type'] as String? ?? 'math'),
      missionDifficulty: map['mission_difficulty'] as int? ?? 1,
      soundAsset: map['sound_asset'] as String? ?? 'default_alarm',
      snoozeMinutes: map['snooze_minutes'] as int? ?? 5,
      maxSnoozes: map['max_snoozes'] as int? ?? 3,
    );
  }
}
