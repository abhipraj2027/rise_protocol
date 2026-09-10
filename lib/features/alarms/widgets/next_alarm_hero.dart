import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../data/alarm.dart';
import '../alarm_formatting.dart';

/// The banner at the top of the alarm list: how long until the next alarm
/// rings, or a calm "no alarms set" when nothing is scheduled. Ticks itself
/// once a minute so the countdown stays honest.
class NextAlarmHero extends StatefulWidget {
  const NextAlarmHero({super.key, required this.alarms});

  final List<Alarm> alarms;

  @override
  State<NextAlarmHero> createState() => _NextAlarmHeroState();
}

class _NextAlarmHeroState extends State<NextAlarmHero> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final next = soonestAlarm(widget.alarms, now: now);

    final DateTime? fireAt = next?.nextFire(from: now);
    final bool hasNext = next != null && fireAt != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space20,
        AppTokens.space24,
        AppTokens.space20,
        AppTokens.space24,
      ),
      decoration: BoxDecoration(
        borderRadius: AppTokens.cornerXl,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasNext
              ? [t.brand, Color.lerp(t.brand, Colors.black, 0.28)!]
              : [t.surface1, t.surface1],
        ),
        border: hasNext ? null : Border.all(color: t.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasNext ? Icons.notifications_active_rounded : Icons.bedtime_outlined,
                size: 18,
                color: hasNext ? t.onBrand : t.textSecondary,
              ),
              const SizedBox(width: AppTokens.space8),
              Text(
                hasNext ? 'NEXT ALARM' : 'NO ALARMS SET',
                style: text.labelSmall?.copyWith(
                  color: hasNext ? t.onBrand.withOpacity(0.8) : t.textFaint,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space12),
          if (next != null && fireAt != null) ...[
            Text(
              humanizeUntil(fireAt.difference(now)),
              style: text.displaySmall?.copyWith(color: t.onBrand),
            ),
            const SizedBox(height: AppTokens.space4),
            Text(
              '${dayAndTime(fireAt, now: now)}'
              '${next.label.isNotEmpty ? '  ·  ${next.label}' : ''}',
              style: text.bodyMedium?.copyWith(color: t.onBrand.withOpacity(0.85)),
            ),
          ] else
            Text(
              'Add an alarm to get your mornings back.',
              style: text.bodyMedium?.copyWith(color: t.textSecondary),
            ),
        ],
      ),
    );
  }
}
