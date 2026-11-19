import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/gap.dart';
import '../../core/ui/section_header.dart';
import '../../core/wake_stats.dart';
import '../alarms/alarm_formatting.dart';

final weekStatsProvider = FutureProvider.autoDispose<WeekStats>(
  (ref) => ref.read(wakeStatsProvider).week(),
);

/// The last seven mornings: the streak, a few totals, and when each day's
/// mission was cleared.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(weekStatsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Your mornings')),
      body: week.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Could not load stats\n$err')),
        data: (w) => w.daysUp == 0 && w.streakDays == 0
            ? const _EmptyStats()
            : _StatsBody(week: w),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.week});

  final WeekStats week;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    final avg = week.averageWake;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space20,
        AppTokens.space8,
        AppTokens.space20,
        AppTokens.space40,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(AppTokens.space24),
          decoration: BoxDecoration(
            color: t.surface1,
            borderRadius: AppTokens.cornerXl,
            border: Border.all(color: t.hairline),
            boxShadow: week.streakDays > 0 ? [...t.shadowCard, ...t.glow] : t.shadowCard,
          ),
          child: Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 44,
                color: week.streakDays > 0 ? t.brand : t.textFaint,
              ),
              const Gap.w(AppTokens.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${week.streakDays} ${week.streakDays == 1 ? 'day' : 'days'}',
                      style: text.displaySmall?.copyWith(color: t.textPrimary),
                    ),
                    Text(
                      week.streakDays > 0
                          ? 'in a row you got up and cleared your mission'
                          : 'Clear tomorrow’s mission to start a streak',
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Gap(AppTokens.space16),
        Row(
          children: [
            Expanded(
              child: _Tile(
                value: '${week.daysUp}/7',
                label: 'days up',
              ),
            ),
            const Gap.w(AppTokens.space12),
            Expanded(
              child: _Tile(
                value: avg == null
                    ? '—'
                    : formatClock(
                        DateTime(2000, 1, 1, avg.inHours, avg.inMinutes % 60),
                        use24h: use24h,
                      ),
                label: 'avg wake-up',
              ),
            ),
            const Gap.w(AppTokens.space12),
            Expanded(
              child: _Tile(value: '${week.snoozes}', label: 'snoozes'),
            ),
          ],
        ),
        const Gap(AppTokens.space32),
        const SectionHeader('This week'),
        const Gap(AppTokens.space12),
        AppCard(
          child: Row(
            children: [
              for (var i = 0; i < week.days.length; i++)
                Expanded(
                  child: _DayColumn(
                    day: week.days[i],
                    morning: week.mornings[i],
                    isToday: i == week.days.length - 1,
                    use24h: use24h,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: text.titleLarge?.copyWith(
                fontFamily: text.displaySmall?.fontFamily,
                color: t.textPrimary,
              ),
            ),
          ),
          const Gap(AppTokens.space2),
          Text(label, style: text.bodySmall),
        ],
      ),
    );
  }
}

/// One day in the week strip: the weekday, a sun if the mission was cleared
/// (with a dot per snooze), and the wake-up time.
class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.morning,
    required this.isToday,
    required this.use24h,
  });

  final DateTime day;
  final WakeEntry? morning;
  final bool isToday;
  final bool use24h;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final m = morning;
    final time = m == null
        ? '—'
        : (use24h ? DateFormat.Hm() : DateFormat('h:mm')).format(m.at);

    return Semantics(
      label: m == null
          ? '${DateFormat.EEEE().format(day)}: no wake-up'
          : '${DateFormat.EEEE().format(day)}: up at $time, '
              '${m.snoozes} ${m.snoozes == 1 ? 'snooze' : 'snoozes'}',
      excludeSemantics: true,
      child: Column(
        children: [
          Text(
            DateFormat.E().format(day).substring(0, 1),
            style: text.labelSmall?.copyWith(
              color: isToday ? t.brand : t.textFaint,
            ),
          ),
          const Gap(AppTokens.space8),
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: m == null ? t.surface2 : t.brandMuted,
              border: isToday ? Border.all(color: t.brand, width: 1.5) : null,
            ),
            child: m == null
                ? null
                : Icon(Icons.wb_sunny_rounded, size: 16, color: t.brand),
          ),
          const Gap(AppTokens.space4),
          SizedBox(
            height: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < (m?.snoozes ?? 0).clamp(0, 3); i++)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.warning,
                    ),
                  ),
              ],
            ),
          ),
          const Gap(AppTokens.space4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              time,
              style: text.bodySmall?.copyWith(
                color: m == null ? t.textFaint : t.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStats extends StatelessWidget {
  const _EmptyStats();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.brandMuted, shape: BoxShape.circle),
              child: Icon(Icons.wb_sunny_outlined, size: 34, color: t.brand),
            ),
            const Gap(AppTokens.space20),
            Text('No mornings yet', style: text.titleMedium),
            const Gap(AppTokens.space8),
            Text(
              'Clear an alarm’s mission and your wake-ups, snoozes and streak '
              'show up here.',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
