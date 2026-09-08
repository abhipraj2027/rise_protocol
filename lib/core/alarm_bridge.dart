import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin wrapper around the platform channel that talks to the native
/// alarm-scheduling code (see android/.../AlarmScheduler.kt).
///
/// This is intentionally a *dumb* pipe: Dart decides *when* an alarm should
/// next fire (see [Alarm.nextTriggerMillis]) and just tells native "wake me
/// up at this exact millis with this id/label/mission". All of the reliability
/// work — exact-alarm permission, full-screen intent, boot rescheduling —
/// lives natively, per the plan's Phase 0 spike.
class AlarmBridge {
  static const _channel = MethodChannel('riseprotocol.app/alarm');

  /// Schedules (or replaces) the native exact alarm for [alarmId].
  Future<void> schedule({
    required int alarmId,
    required int triggerAtMillis,
    required String label,
    required String missionType,
  }) async {
    await _channel.invokeMethod('scheduleAlarm', {
      'id': alarmId,
      'triggerAtMillis': triggerAtMillis,
      'label': label,
      'missionType': missionType,
    });
  }

  Future<void> cancel(int alarmId) async {
    await _channel.invokeMethod('cancelAlarm', {'id': alarmId});
  }

  /// True if the app currently holds permission to schedule *exact* alarms.
  /// On Android 12+ this can be revoked by the user in system settings even
  /// after being granted once, so check it right before scheduling.
  Future<bool> canScheduleExactAlarms() async {
    final result = await _channel.invokeMethod<bool>('canScheduleExactAlarms');
    return result ?? false;
  }

  /// Opens the OS "Alarms & reminders" settings page for this app.
  Future<void> openExactAlarmSettings() async {
    await _channel.invokeMethod('openExactAlarmSettings');
  }

  /// Opens the OS battery-optimization exemption prompt/settings for this
  /// app. Without this, OEMs (Samsung/Xiaomi/Huawei/OnePlus) may kill the
  /// process before a scheduled alarm fires — see the plan's Risks section.
  Future<void> requestIgnoreBatteryOptimizations() async {
    await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
  }

  /// True if the app is already exempt from battery optimization (Doze/App
  /// Standby won't defer or kill it). Used to drive the onboarding
  /// checklist's status icon without popping the system dialog just to look.
  Future<bool> isIgnoringBatteryOptimizations() async {
    final result = await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
    return result ?? false;
  }

  /// Called once at app start to stop the ringing foreground service / audio
  /// if the user force-closed the app instead of dismissing normally.
  Future<void> stopAnyRingingService() async {
    await _channel.invokeMethod('stopRingingService');
  }

  /// Mission passed (or no mission configured): stop audio, stop the
  /// foreground service, close the native ringing Activity, and — for a
  /// repeating alarm — let native compute and arm the next occurrence.
  Future<void> dismissRinging(int alarmId) async {
    await _channel.invokeMethod('dismissRinging', {'id': alarmId});
  }

  /// Re-schedules this alarm [snoozeMinutes] from now and closes the
  /// ringing UI without marking the mission complete.
  Future<void> snoozeRinging(int alarmId, int snoozeMinutes) async {
    await _channel.invokeMethod('snoozeRinging', {
      'id': alarmId,
      'snoozeMinutes': snoozeMinutes,
    });
  }
}

final alarmBridgeProvider = Provider<AlarmBridge>((ref) => AlarmBridge());
