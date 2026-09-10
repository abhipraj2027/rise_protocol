import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

import '../../core/alarm_bridge.dart';

enum PermissionStepKind { exactAlarm, notifications, batteryOptimization }

/// One row in the onboarding checklist. `critical` steps block "Continue" —
/// without them the app plausibly can't wake the user at all. Battery
/// optimization is strongly recommended but not blocking, since some
/// vendors/ROMs don't offer the exemption at all and the app should still
/// be usable there.
class PermissionStep {
  final PermissionStepKind kind;
  final String title;
  final String description;
  final bool critical;

  const PermissionStep({
    required this.kind,
    required this.title,
    required this.description,
    required this.critical,
  });

  static const all = [
    PermissionStep(
      kind: PermissionStepKind.exactAlarm,
      title: 'Allow exact alarms',
      description:
          'Without this, Android may fire your alarm minutes late — or not at all. '
          'This is the single most important permission for this app.',
      critical: true,
    ),
    PermissionStep(
      kind: PermissionStepKind.notifications,
      title: 'Allow notifications',
      description:
          'The ringing screen is delivered through a notification channel. '
          'On Android 13+, this is required or the alarm can\'t reach you.',
      critical: true,
    ),
    PermissionStep(
      kind: PermissionStepKind.batteryOptimization,
      title: 'Disable battery optimization',
      description:
          'Some phone makers (Samsung, Xiaomi, OnePlus, Huawei) aggressively kill '
          'background apps beyond what stock Android allows. Exempting Rise '
          'Protocol makes a killed-app alarm much more reliable.',
      critical: false,
    ),
  ];

  Future<bool> isGranted(AlarmBridge bridge) async {
    switch (kind) {
      case PermissionStepKind.exactAlarm:
        return bridge.canScheduleExactAlarms();
      case PermissionStepKind.notifications:
        if (kIsWeb) return true;
        return (await Permission.notification.status).isGranted;
      case PermissionStepKind.batteryOptimization:
        return bridge.isIgnoringBatteryOptimizations();
    }
  }

  Future<void> resolve(AlarmBridge bridge) async {
    switch (kind) {
      case PermissionStepKind.exactAlarm:
        await bridge.openExactAlarmSettings();
      case PermissionStepKind.notifications:
        if (!kIsWeb) await Permission.notification.request();
      case PermissionStepKind.batteryOptimization:
        await bridge.requestIgnoreBatteryOptimizations();
    }
  }
}
