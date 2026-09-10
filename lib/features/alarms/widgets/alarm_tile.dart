import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/big_switch.dart';
import '../../../core/ui/weekday_selector.dart';
import '../../../data/alarm.dart';
import '../alarm_formatting.dart';

/// One alarm in the list: big time, a quiet meta line (repeat · mission),
/// day pips when it repeats, and the on/off toggle. Dimmed when disabled.
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
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final dim = !alarm.enabled;

    Color fade(Color c) => dim ? c.withOpacity(0.45) : c;

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alarm.clockLabel,
                  style: text.displaySmall?.copyWith(color: fade(t.textPrimary)),
                ),
                const SizedBox(height: AppTokens.space4),
                Text(
                  _metaLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: fade(t.textSecondary)),
                ),
                if (alarm.isRepeating) ...[
                  const SizedBox(height: AppTokens.space12),
                  Opacity(
                    opacity: dim ? 0.45 : 1.0,
                    child: WeekdaySelector(
                      selected: alarm.repeatDays,
                      readOnly: true,
                      size: 22,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space12),
          Padding(
            padding: const EdgeInsets.only(top: AppTokens.space4),
            child: BigSwitch(value: alarm.enabled, onChanged: onToggle),
          ),
        ],
      ),
    );
  }

  String get _metaLine {
    final repeat = repeatSummary(alarm.repeatDays);
    final mission = alarm.missionType == MissionType.none
        ? 'Tap to dismiss'
        : alarm.missionType.label;
    final label = alarm.label.trim();
    return [
      if (label.isNotEmpty) label,
      repeat,
      mission,
    ].join('  ·  ');
  }
}
