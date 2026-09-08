import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/alarm_scheduler.dart';
import '../../data/alarm.dart';
import '../../data/alarm_repository.dart';

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Create screen when [alarmId] is null, edit screen otherwise.
class EditAlarmScreen extends ConsumerStatefulWidget {
  const EditAlarmScreen({super.key, this.alarmId});

  final int? alarmId;

  @override
  ConsumerState<EditAlarmScreen> createState() => _EditAlarmScreenState();
}

class _EditAlarmScreenState extends ConsumerState<EditAlarmScreen> {
  late TimeOfDay _time;
  late TextEditingController _labelController;
  late Set<int> _repeatDays;
  late MissionType _missionType;
  late int _snoozeMinutes;
  Alarm? _existing;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _time = TimeOfDay.now();
    _labelController = TextEditingController();
    _repeatDays = {};
    _missionType = MissionType.math;
    _snoozeMinutes = 5;

    if (widget.alarmId != null) {
      // Alarms are already in memory via alarmListProvider once loaded;
      // pull the matching one in didChangeDependencies-safe build below.
    } else {
      _loaded = true;
    }
  }

  void _loadExisting(Alarm alarm) {
    if (_loaded) return;
    _existing = alarm;
    _time = TimeOfDay(hour: alarm.hour, minute: alarm.minute);
    _labelController.text = alarm.label;
    _repeatDays = {...alarm.repeatDays};
    _missionType = alarm.missionType;
    _snoozeMinutes = alarm.snoozeMinutes;
    _loaded = true;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final actions = ref.read(scheduledAlarmActionsProvider);
    final alarm = (_existing ?? const Alarm(hour: 0, minute: 0)).copyWith(
      hour: _time.hour,
      minute: _time.minute,
      label: _labelController.text.trim(),
      repeatDays: _repeatDays,
      missionType: _missionType,
      snoozeMinutes: _snoozeMinutes,
      enabled: true,
    );

    if (_existing == null) {
      await actions.add(alarm);
    } else {
      await actions.save(alarm);
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (_existing == null) return;
    await ref.read(scheduledAlarmActionsProvider).remove(_existing!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // For edit mode, resolve the current alarm from the list provider so
    // this screen stays correct if the alarm changed elsewhere.
    if (widget.alarmId != null) {
      final alarmsAsync = ref.watch(alarmListProvider);
      alarmsAsync.whenData((alarms) {
        final match = alarms.where((a) => a.id == widget.alarmId);
        if (match.isNotEmpty && !_loaded) {
          // Defer to avoid setState-during-build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _loadExisting(match.first));
          });
        }
      });
      if (!_loaded) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? 'New alarm' : 'Edit alarm'),
        actions: [
          if (_existing != null)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete alarm',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: OutlinedButton(
              onPressed: _pickTime,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text(
                _time.format(context),
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Label',
              hintText: 'e.g. Gym, Work, Flight',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text('Repeat', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(7, (i) {
              final weekday = i + 1;
              final selected = _repeatDays.contains(weekday);
              return ChoiceChip(
                label: Text(_weekdayLabels[i]),
                selected: selected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _repeatDays.add(weekday);
                    } else {
                      _repeatDays.remove(weekday);
                    }
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 24),
          Text('Mission to dismiss', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'What you have to do before the alarm will stop.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          ...MissionType.values.map((m) {
            return RadioListTile<MissionType>(
              value: m,
              // ignore: deprecated_member_use
              groupValue: _missionType,
              // ignore: deprecated_member_use
              onChanged: m.isImplemented ? (v) => setState(() => _missionType = v!) : null,
              title: Text(m.label),
              subtitle: m.isImplemented ? null : const Text('Coming in a later phase'),
              contentPadding: EdgeInsets.zero,
            );
          }),
          const SizedBox(height: 12),
          Text('Snooze length', style: theme.textTheme.titleSmall),
          Slider(
            value: _snoozeMinutes.toDouble(),
            min: 1,
            max: 15,
            divisions: 14,
            label: '$_snoozeMinutes min',
            onChanged: (v) => setState(() => _snoozeMinutes = v.round()),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
            child: const Text('Save alarm'),
          ),
        ],
      ),
    );
  }
}
