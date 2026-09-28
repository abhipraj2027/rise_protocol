import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/big_switch.dart';
import '../../../core/ui/weekday_selector.dart';
import '../../../data/alarm.dart';
import '../alarm_formatting.dart';
import '../mission_icons.dart';

/// One alarm in the list: a weekday row + toggle up top, then the big time
/// next to a small mission-icon badge, with a quiet meta line and an
/// overflow menu for edit/delete. Dimmed as a whole when disabled.
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

    Color fade(Color c) => dim ? c.withValues(alpha: 0.45) : c;

    return AppCard(
      onTap: onTap,
      child: Opacity(
        opacity: dim ? 0.7 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: WeekdaySelector(
                    selected: alarm.repeatDays,
                    readOnly: true,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTokens.space8),
                BigSwitch(
                  value: alarm.enabled,
                  onChanged: onToggle,
                  width: 48,
                  height: 28,
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _MissionBadge(mission: alarm.missionType, dim: dim),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        alarm.clockLabel,
                        style: text.displaySmall?.copyWith(
                          color: fade(t.textPrimary),
                        ),
                      ),
                      const SizedBox(height: AppTokens.space2),
                      Text(
                        _metaLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: fade(t.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  PopupMenuButton<_TileAction>(
                    icon: Icon(Icons.more_vert_rounded, color: fade(t.textFaint)),
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
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _metaLine {
    final repeat = repeatSummary(alarm.repeatDays);
    final label = alarm.label.trim();
    return label.isNotEmpty ? '$label  ·  $repeat' : repeat;
  }
}

enum _TileAction { edit, delete }

/// The small rounded-square badge showing which mission guards this alarm.
class _MissionBadge extends StatelessWidget {
  const _MissionBadge({required this.mission, required this.dim});

  final MissionType mission;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = mission == MissionType.none ? t.textFaint : t.missionAccent;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: dim ? 0.10 : 0.16),
        borderRadius: AppTokens.cornerSm,
      ),
      child: Icon(mission.icon, size: 20, color: dim ? color.withValues(alpha: 0.6) : color),
    );
  }
}
