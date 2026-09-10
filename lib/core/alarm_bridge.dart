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

  /// Stops the ringing foreground service / audio if the user force-closed
  /// the app instead of dismissing normally.
  Future<void> stopAnyRingingService();

  /// Mission passed (or no mission configured): stop audio, stop the
  /// foreground service, close the native ringing Activity.
  Future<void> dismissRinging(int alarmId);

  /// Re-schedules this alarm [snoozeMinutes] from now and closes the ringing
  /// UI without marking the mission complete.
  Future<void> snoozeRinging(int alarmId, int snoozeMinutes);
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
  }) async {
    await _channel.invokeMethod('scheduleAlarm', {
      'id': alarmId,
      'triggerAtMillis': triggerAtMillis,
      'label': label,
      'missionType': missionType,
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
  Future<void> stopAnyRingingService() async {
    await _channel.invokeMethod('stopRingingService');
  }

  @override
  Future<void> dismissRinging(int alarmId) async {
    await _channel.invokeMethod('dismissRinging', {'id': alarmId});
  }

  @override
  Future<void> snoozeRinging(int alarmId, int snoozeMinutes) async {
    await _channel.invokeMethod('snoozeRinging', {
      'id': alarmId,
      'snoozeMinutes': snoozeMinutes,
    });
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
  Future<void> stopAnyRingingService() async {}

  @override
  Future<void> dismissRinging(int alarmId) async {}

  @override
  Future<void> snoozeRinging(int alarmId, int snoozeMinutes) async {}
}

final alarmBridgeProvider = Provider<AlarmBridge>(
  (ref) => kIsWeb ? const FakeAlarmBridge() : const PlatformAlarmBridge(),
);
