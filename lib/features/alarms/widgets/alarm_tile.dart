import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/alarm.dart';

const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class AlarmTile extends StatelessWidget {
  const AlarmTile({
    super.key,
    required this.alarm,
    required this.onTap,
    required this.onToggle,
  });

  final Alarm alarm;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay(hour: alarm.hour, minute: alarm.minute);
    final timeText = DateFormat.jm().format(
      DateTime(2000, 1, 1, time.hour, time.minute),
    );
    final theme = Theme.of(context);
    final dimmed = !alarm.enabled;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeText,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: dimmed
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (alarm.label.isNotEmpty) ...[
                        Text(
                          alarm.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Icon(
                        alarm.missionType == MissionType.none
                            ? Icons.touch_app_outlined
                            : Icons.flag_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        alarm.missionType.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (alarm.isRepeating) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(7, (i) {
                        final weekday = i + 1;
                        final active = alarm.repeatDays.contains(weekday);
                        return Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(right: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest,
                          ),
                          child: Text(
                            _weekdayLabels[i],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: active
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),
            Switch(value: alarm.enabled, onChanged: onToggle),
          ],
        ),
      ),
    );
  }
}
