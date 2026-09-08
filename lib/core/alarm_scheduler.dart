import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/alarm.dart';
import '../data/alarm_repository.dart';
import 'alarm_bridge.dart';

/// Bridges the alarm list (Dart/DB truth) with the native scheduler.
///
/// Every mutation that should change what the OS is holding a wake-up for —
/// create, edit, delete, enable/disable — funnels through here instead of
/// calling [AlarmBridge] directly from UI code, so the two stay in sync by
/// construction rather than by convention.
class AlarmScheduler {
  AlarmScheduler(this._bridge);

  final AlarmBridge _bridge;

  Future<void> syncOne(Alarm alarm) async {
    if (alarm.id == null) return;
    if (!alarm.enabled) {
      await _bridge.cancel(alarm.id!);
      return;
    }
    await _bridge.schedule(
      alarmId: alarm.id!,
      triggerAtMillis: alarm.nextTriggerMillis(),
      label: alarm.label,
      missionType: alarm.missionType.name,
    );
  }

  Future<void> cancel(int alarmId) => _bridge.cancel(alarmId);

  /// Re-arms every enabled alarm. Called after boot on the Dart side is
  /// *not* how this app survives a reboot (see BootReceiver.kt, which
  /// reschedules natively without waiting for Dart to start) — this is a
  /// belt-and-suspenders resync run once when the app is opened normally,
  /// so any alarm edited while the app was killed is still correct.
  Future<void> resyncAll(List<Alarm> alarms) async {
    for (final alarm in alarms) {
      await syncOne(alarm);
    }
  }
}

final alarmSchedulerProvider = Provider<AlarmScheduler>((ref) {
  return AlarmScheduler(ref.read(alarmBridgeProvider));
});

/// Wraps [AlarmListController] so screens call one controller that updates
/// the DB *and* keeps native scheduling in sync, instead of remembering to
/// call both separately.
final scheduledAlarmActionsProvider = Provider<ScheduledAlarmActions>((ref) {
  return ScheduledAlarmActions(ref);
});

class ScheduledAlarmActions {
  ScheduledAlarmActions(this._ref);
  final Ref _ref;

  Future<void> add(Alarm alarm) async {
    final saved = await _ref.read(alarmListProvider.notifier).add(alarm);
    await _ref.read(alarmSchedulerProvider).syncOne(saved);
  }

  Future<void> save(Alarm alarm) async {
    await _ref.read(alarmListProvider.notifier).save(alarm);
    await _ref.read(alarmSchedulerProvider).syncOne(alarm);
  }

  Future<void> remove(Alarm alarm) async {
    if (alarm.id != null) {
      await _ref.read(alarmSchedulerProvider).cancel(alarm.id!);
    }
    await _ref.read(alarmListProvider.notifier).remove(alarm.id!);
  }

  Future<void> setEnabled(Alarm alarm, bool enabled) async {
    final updated = alarm.copyWith(enabled: enabled);
    await _ref.read(alarmListProvider.notifier).save(updated);
    await _ref.read(alarmSchedulerProvider).syncOne(updated);
  }
}
