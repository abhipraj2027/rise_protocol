import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/big_switch.dart';
import '../../../core/ui/weekday_selector.dart';
import '../../../data/alarm.dart';
import '../alarm_formatting.dart';
import '../mission_icons.dart';

/// One alarm in the list. The time leads — big, with a smaller AM/PM — next
/// to the toggle, with the label under it. A footer row carries the mission
/// chip, the repeat days and an overflow menu for edit/delete. Dimmed as a
/// whole when disabled.
class AlarmTile extends StatelessWidget {
  const AlarmTile({
    super.key,
    required this.alarm,
    required this.onTap,
    required this.onToggle,
    this.onDelete,
  });

  final Alarm alarm;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final dim = !alarm.enabled;
    final (clock, period) = clockParts(
      alarm.hour,
      alarm.minute,
      use24h: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final label = alarm.label.trim();

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space20,
        AppTokens.space16,
        AppTokens.space16,
        AppTokens.space8,
      ),
      child: AnimatedOpacity(
        opacity: dim ? 0.5 : 1.0,
        duration: AppTokens.motionBase,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: clock),
                            if (period != null)
                              TextSpan(
                                text: ' $period',
                                style: text.titleMedium?.copyWith(
                                  fontFamily: text.displayMedium?.fontFamily,
                                  color: t.textSecondary,
                                  letterSpacing: 0,
                                ),
                              ),
                          ],
                        ),
                        style: text.displayMedium?.copyWith(
                          color: t.textPrimary,
                        ),
                      ),
                      if (label.isNotEmpty) ...[
                        const SizedBox(height: AppTokens.space4),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(
                            color: t.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppTokens.space12),
                Padding(
                  padding: const EdgeInsets.only(top: AppTokens.space8),
                  child: BigSwitch(
                    value: alarm.enabled,
                    onChanged: onToggle,
                    width: 52,
                    height: 30,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space12),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _MissionChip(mission: alarm.missionType),
                  ),
                ),
                const SizedBox(width: AppTokens.space12),
                if (alarm.isRepeating)
                  WeekdaySelector(
                    selected: alarm.repeatDays,
                    readOnly: true,
                    size: 18,
                  )
                else
                  Text(
                    'Once',
                    style: text.bodySmall?.copyWith(color: t.textSecondary),
                  ),
                if (onDelete != null)
                  PopupMenuButton<_TileAction>(
                    tooltip: 'More',
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: t.textFaint,
                    ),
                    onSelected: (action) {
                      switch (action) {
                        case _TileAction.edit:
                          onTap();
                        case _TileAction.delete:
                          onDelete!();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _TileAction.edit,
                        child: Text('Edit'),
                      ),
                      PopupMenuItem(
                        value: _TileAction.delete,
                        child: Text('Delete'),
                      ),
                    ],
                  )
                else
                  const SizedBox(height: 40),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _TileAction { edit, delete }

/// The small pill naming which mission guards this alarm.
class _MissionChip extends StatelessWidget {
  const _MissionChip({required this.mission});

  final MissionType mission;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = mission == MissionType.none ? t.textFaint : t.missionAccent;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space8,
        AppTokens.space4,
        AppTokens.space12,
        AppTokens.space4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(mission.icon, size: 16, color: color),
          const SizedBox(width: AppTokens.space4),
          Flexible(
            child: Text(
              mission.shortLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
