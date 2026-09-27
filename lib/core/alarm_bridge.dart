import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The seam between Dart and the native alarm-scheduling code
/// (see android/.../AlarmScheduler.kt).
///
/// This is intentionally a *dumb* pipe: Dart decides *when* an alarm should
/// next fire (see `Alarm.nextTriggerMillis`) and just tells native "wake me
/// up at this exact millis with this id/label/mission". All of the
/// reliability work — exact-alarm permission, full-screen intent, boot
/// rescheduling — lives natively, per the plan's Phase 0 spike.
///
/// [PlatformAlarmBridge] is the real implementation; [FakeAlarmBridge] backs
/// the web UI preview, which has no platform channels.
abstract interface class AlarmBridge {
  Future<void> schedule({
    required int alarmId,
    required int triggerAtMillis,
    required String label,
    required String missionType,
    required int snoozeMinutes,
    required int hour,
    required int minute,
    required List<int> repeatDays,
    required String qnaQuestion,
    required String qnaAnswer,
  });

  Future<void> cancel(int alarmId);

  /// True if the app currently holds permission to schedule *exact* alarms.
  Future<bool> canScheduleExactAlarms();

  /// Opens the OS "Alarms & reminders" settings page for this app.
  Future<void> openExactAlarmSettings();

  /// Opens the OS battery-optimization exemption prompt/settings.
  Future<void> requestIgnoreBatteryOptimizations();

  /// True if the app is already exempt from battery optimization.
  Future<bool> isIgnoringBatteryOptimizations();

  /// True if the app may post full-screen-intent notifications. Always true
  /// below Android 14; on 14+ it's a user-revocable permission and, without
  /// it, a firing alarm shows only a heads-up notification.
  Future<bool> canUseFullScreenIntent();

  /// Opens the OS "Full-screen notifications" settings page for this app.
  Future<void> openFullScreenIntentSettings();

  /// Stops the ringing foreground service / audio if the user force-closed
  /// the app instead of dismissing normally.
  Future<void> stopAnyRingingService();

  /// Mission passed (or no mission configured): stop audio, stop the
  /// foreground service, close the native ringing Activity.
  Future<void> dismissRinging(int alarmId);

  /// Re-schedules this alarm and closes the ringing UI without marking the
  /// mission complete. [snoozeMinutes] null means "use this alarm's own
  /// snooze length" (as saved in the editor).
  Future<void> snoozeRinging(int alarmId, int? snoozeMinutes);

  /// Silences the alarm sound + vibration for [seconds] while the user is
  /// solving the mission. Native brings it back automatically after that
  /// long unless this is called again, so an abandoned mission can't leave
  /// the alarm muted.
  Future<void> muteRinging(int seconds);

  /// The on-device alarm event log (scheduled / fired / screen opened /
  /// snoozed…), oldest first. Used by the Alarm diagnostics screen.
  Future<List<String>> getAlarmLog();

  Future<void> clearAlarmLog();

  /// Ids of one-time alarms that have rung since the app last checked (and
  /// clears the list). Native can't touch the alarm database, so the app
  /// switches those alarms off in the UI when it next runs.
  Future<List<int>> takeFiredOneShots();
}

class PlatformAlarmBridge implements AlarmBridge {
  const PlatformAlarmBridge();

  static const _channel = MethodChannel('riseprotocol.app/alarm');

  @override
  Future<void> schedule({
    required int alarmId,
    required int triggerAtMillis,
    required String label,
    required String missionType,
    required int snoozeMinutes,
    required int hour,
    required int minute,
    required List<int> repeatDays,
    required String qnaQuestion,
    required String qnaAnswer,
  }) async {
    await _channel.invokeMethod('scheduleAlarm', {
      'id': alarmId,
      'triggerAtMillis': triggerAtMillis,
      'label': label,
      'missionType': missionType,
      'snoozeMinutes': snoozeMinutes,
      'hour': hour,
      'minute': minute,
      'repeatDays': repeatDays,
    });
  }

  @override
  Future<void> cancel(int alarmId) async {
    await _channel.invokeMethod('cancelAlarm', {'id': alarmId});
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    final result = await _channel.invokeMethod<bool>('canScheduleExactAlarms');
    return result ?? false;
  }

  @override
  Future<void> openExactAlarmSettings() async {
    await _channel.invokeMethod('openExactAlarmSettings');
  }

  @override
  Future<void> requestIgnoreBatteryOptimizations() async {
    await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
  }

  @override
  Future<bool> isIgnoringBatteryOptimizations() async {
    final result =
        await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
    return result ?? false;
  }

  @override
  Future<bool> canUseFullScreenIntent() async {
    final result = await _channel.invokeMethod<bool>('canUseFullScreenIntent');
    return result ?? true;
  }

  @override
  Future<void> openFullScreenIntentSettings() async {
    await _channel.invokeMethod('openFullScreenIntentSettings');
  }

  @override
  Future<void> stopAnyRingingService() async {
    await _channel.invokeMethod('stopRingingService');
  }

  @override
  Future<void> dismissRinging(int alarmId) async {
    await _channel.invokeMethod('dismissRinging', {'id': alarmId});
  }

  @override
  Future<void> snoozeRinging(int alarmId, int? snoozeMinutes) async {
    await _channel.invokeMethod('snoozeRinging', {
      'id': alarmId,
      'snoozeMinutes': snoozeMinutes,
      'qnaQuestion': qnaQuestion,
      'qnaAnswer': qnaAnswer,
    });
  }

  @override
  Future<void> muteRinging(int seconds) async {
    await _channel.invokeMethod('muteRinging', {'seconds': seconds});
  }

  @override
  Future<List<String>> getAlarmLog() async {
    final result = await _channel.invokeListMethod<String>('getAlarmLog');
    return result ?? const [];
  }

  @override
  Future<void> clearAlarmLog() async {
    await _channel.invokeMethod('clearAlarmLog');
  }

  @override
  Future<List<int>> takeFiredOneShots() async {
    final result = await _channel.invokeListMethod<int>('takeFiredOneShots');
    return result ?? const [];
  }
}

/// No-op bridge for the web UI preview: scheduling does nothing, and the
/// permission checks report "granted" so the onboarding screen isn't stuck.
class FakeAlarmBridge implements AlarmBridge {
  const FakeAlarmBridge();

  @override
  Future<void> schedule({
    required int alarmId,
    required int triggerAtMillis,
    required String label,
    required String missionType,
    required int snoozeMinutes,
    required int hour,
    required int minute,
    required List<int> repeatDays,
    required String qnaQuestion,
    required String qnaAnswer,
  }) async {}

  @override
  Future<void> cancel(int alarmId) async {}

  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<void> openExactAlarmSettings() async {}

  @override
  Future<void> requestIgnoreBatteryOptimizations() async {}

  @override
  Future<bool> isIgnoringBatteryOptimizations() async => true;

  @override
  Future<bool> canUseFullScreenIntent() async => true;

  @override
  Future<void> openFullScreenIntentSettings() async {}

  @override
  Future<void> stopAnyRingingService() async {}

  @override
  Future<void> dismissRinging(int alarmId) async {}

  @override
  Future<void> snoozeRinging(int alarmId, int? snoozeMinutes) async {}

  @override
  Future<void> muteRinging(int seconds) async {}

  @override
  Future<List<String>> getAlarmLog() async =>
      const ['(the alarm log is only available in the Android app)'];

  @override
  Future<void> clearAlarmLog() async {}

  @override
  Future<List<int>> takeFiredOneShots() async => const [];
}

final alarmBridgeProvider = Provider<AlarmBridge>(
  (ref) => kIsWeb ? const FakeAlarmBridge() : const PlatformAlarmBridge(),
);
