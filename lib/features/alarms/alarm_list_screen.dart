import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/alarm_scheduler.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/gap.dart';
import '../../core/ui/stagger_in.dart';
import '../../data/alarm.dart';
import '../../data/alarm_repository.dart';
import '../onboarding/permission_onboarding_screen.dart';
import 'alarm_formatting.dart';
import 'edit_alarm_screen.dart';
import 'widgets/alarm_tile.dart';
import 'widgets/next_alarm_hero.dart';

class AlarmListScreen extends ConsumerWidget {
  const AlarmListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alarmsAsync = ref.watch(alarmListProvider);
    final actions = ref.read(scheduledAlarmActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rise Protocol'),
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: 'Component gallery',
              icon: const Icon(Icons.palette_outlined),
              onPressed: () => Navigator.of(context).pushNamed('/gallery'),
            ),
          IconButton(
            tooltip: 'Permissions',
            icon: const Icon(Icons.shield_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PermissionOnboardingScreen(isReview: true),
              ),
            ),
          ),
        ],
      ),
      body: alarmsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorState(message: '$err'),
        data: (alarms) {
          final sorted = [...alarms]..sort(_byTimeOfDay);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.space16,
              AppTokens.space12,
              AppTokens.space16,
              AppTokens.space56 + AppTokens.space40,
            ),
            children: [
              NextAlarmHero(alarms: sorted),
              const Gap(AppTokens.space24),
              if (sorted.isEmpty)
                const _EmptyState()
              else
                for (final (i, alarm) in sorted.indexed) ...[
                  StaggerIn(
                    key: ValueKey('stagger-${alarm.id}'),
                    index: i,
                    child: _DismissibleAlarm(
                      alarm: alarm,
                      onTap: () => _openEditor(context, alarm.id),
                      onToggle: (v) => actions.setEnabled(alarm, v),
                      onDismissed: () => _deleteWithUndo(context, ref, alarm),
                    ),
                  ),
                  const Gap(AppTokens.space12),
                ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, null),
        icon: const Icon(Icons.add),
        label: const Text('New alarm'),
      ),
    );
  }

  static int _byTimeOfDay(Alarm a, Alarm b) {
    final am = a.hour * 60 + a.minute;
    final bm = b.hour * 60 + b.minute;
    return am.compareTo(bm);
  }

  void _openEditor(BuildContext context, int? id) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditAlarmScreen(alarmId: id)),
    );
  }

  Future<void> _deleteWithUndo(
    BuildContext context,
    WidgetRef ref,
    Alarm alarm,
  ) async {
    final actions = ref.read(scheduledAlarmActionsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final name = alarm.label.trim().isNotEmpty
        ? alarm.label.trim()
        : alarm.clockLabel;
    await actions.remove(alarm);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted $name'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => actions.add(alarm.copyWith(id: null)),
        ),
      ),
    );
  }
}

class _DismissibleAlarm extends StatelessWidget {
  const _DismissibleAlarm({
    required this.alarm,
    required this.onTap,
    required this.onToggle,
    required this.onDismissed,
  });

  final Alarm alarm;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Dismissible(
      key: ValueKey(alarm.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTokens.space24),
        decoration: BoxDecoration(
          color: t.danger.withOpacity(0.16),
          borderRadius: AppTokens.cornerLg,
        ),
        child: Icon(Icons.delete_outline_rounded, color: t.danger),
      ),
      child: AlarmTile(alarm: alarm, onTap: onTap, onToggle: onToggle),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.space56),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.brandMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.alarm_add_rounded, size: 34, color: t.brand),
          ),
          const Gap(AppTokens.space20),
          Text('No alarms yet', style: text.titleMedium),
          const Gap(AppTokens.space8),
          Text(
            'Tap “New alarm” to set your first\nwake-up mission.',
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: context.tokens.danger),
            const Gap(AppTokens.space12),
            Text('Could not load alarms', style: text.titleMedium),
            const Gap(AppTokens.space4),
            Text(message, textAlign: TextAlign.center, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}
