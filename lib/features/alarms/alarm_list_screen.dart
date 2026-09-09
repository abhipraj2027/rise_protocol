import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/alarm_scheduler.dart';
import '../../data/alarm_repository.dart';
import '../onboarding/permission_onboarding_screen.dart';
import 'edit_alarm_screen.dart';
import 'widgets/alarm_tile.dart';

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
        error: (err, _) => Center(child: Text('Could not load alarms: $err')),
        data: (alarms) {
          if (alarms.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: alarms.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final alarm = alarms[i];
              return Dismissible(
                key: ValueKey(alarm.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete_outline),
                ),
                onDismissed: (_) => actions.remove(alarm),
                child: AlarmTile(
                  alarm: alarm,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EditAlarmScreen(alarmId: alarm.id),
                    ),
                  ),
                  onToggle: (value) => actions.setEnabled(alarm, value),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EditAlarmScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New alarm'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.alarm_add_outlined,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No alarms yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tap "New alarm" to set your first wake-up mission.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
