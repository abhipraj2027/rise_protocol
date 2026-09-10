import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/alarm_scheduler.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/gap.dart';
import '../../core/ui/glass_surface.dart';
import '../../core/ui/primary_button.dart';
import '../../core/ui/section_header.dart';
import '../../core/ui/weekday_selector.dart';
import '../../data/alarm.dart';
import '../../data/alarm_repository.dart';
import 'alarm_formatting.dart';

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
    _time = TimeOfDay.now().replacing(minute: 0);
    _labelController = TextEditingController();
    _repeatDays = {};
    _missionType = MissionType.math;
    _snoozeMinutes = 5;
    if (widget.alarmId == null) _loaded = true;
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

  Alarm get _draft => (_existing ?? const Alarm(hour: 0, minute: 0)).copyWith(
        hour: _time.hour,
        minute: _time.minute,
        label: _labelController.text.trim(),
        repeatDays: _repeatDays,
        missionType: _missionType,
        snoozeMinutes: _snoozeMinutes,
        enabled: true,
      );

  Future<void> _save() async {
    final actions = ref.read(scheduledAlarmActionsProvider);
    final alarm = _draft;
    if (_existing == null) {
      await actions.add(alarm);
    } else {
      await actions.save(alarm);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final existing = _existing;
    if (existing == null) return;
    await ref.read(scheduledAlarmActionsProvider).remove(existing);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // In edit mode, resolve the alarm from the list provider so this screen
    // stays correct if it changed elsewhere.
    if (widget.alarmId != null) {
      final alarmsAsync = ref.watch(alarmListProvider);
      alarmsAsync.whenData((alarms) {
        final match = alarms.where((a) => a.id == widget.alarmId);
        if (match.isNotEmpty && !_loaded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _loadExisting(match.first));
          });
        }
      });
      if (!_loaded) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? 'New alarm' : 'Edit alarm'),
        actions: [
          if (_existing != null)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Delete alarm',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space20,
                AppTokens.space8,
                AppTokens.space20,
                AppTokens.space24,
              ),
              children: [
                _TimeWheel(
                  time: _time,
                  onChanged: (t) => setState(() => _time = t),
                ),
                const Gap(AppTokens.space8),
                Center(child: _RingsAtLine(draft: _draft)),
                const Gap(AppTokens.space32),

                const SectionHeader('Repeat'),
                const Gap(AppTokens.space12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: WeekdaySelector(
                          selected: _repeatDays,
                          onChanged: (d) => setState(() => _repeatDays = d),
                        ),
                      ),
                      const Gap(AppTokens.space12),
                      Center(
                        child: Text(
                          repeatSummary(_repeatDays),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(AppTokens.space32),

                const SectionHeader(
                  'Mission to dismiss',
                  subtitle: 'What you have to do before the alarm will stop.',
                ),
                const Gap(AppTokens.space12),
                for (final m in MissionType.values) ...[
                  _MissionOption(
                    mission: m,
                    selected: m == _missionType,
                    onTap: m.isImplemented
                        ? () => setState(() => _missionType = m)
                        : null,
                  ),
                  const Gap(AppTokens.space8),
                ],
                const Gap(AppTokens.space24),

                const SectionHeader('Snooze length'),
                const Gap(AppTokens.space12),
                AppCard(
                  child: _Stepper(
                    value: _snoozeMinutes,
                    min: 1,
                    max: 15,
                    unit: 'min',
                    onChanged: (v) => setState(() => _snoozeMinutes = v),
                  ),
                ),
                const Gap(AppTokens.space32),

                const SectionHeader('Label'),
                const Gap(AppTokens.space12),
                TextField(
                  controller: _labelController,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'Gym, Work, Flight…'),
                ),
              ],
            ),
          ),
          _SaveBar(
            label: _existing == null ? 'Add alarm' : 'Save changes',
            onSave: _save,
          ),
        ],
      ),
    );
  }
}

class _RingsAtLine extends StatelessWidget {
  const _RingsAtLine({required this.draft});

  final Alarm draft;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final now = DateTime.now();
    final fireAt = DateTime.fromMillisecondsSinceEpoch(
      draft.nextTriggerMillis(from: now),
    );
    return Text(
      'Rings ${dayAndTime(fireAt, now: now)}  ·  ${humanizeUntil(fireAt.difference(now))}',
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(color: t.brand, fontWeight: FontWeight.w600),
    );
  }
}

class _TimeWheel extends StatelessWidget {
  const _TimeWheel({required this.time, required this.onChanged});

  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 176,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _WheelColumn(
            count: 24,
            selected: time.hour,
            onSelected: (h) => onChanged(time.replacing(hour: h)),
          ),
          Text(':', style: text.displayMedium?.copyWith(color: context.tokens.textFaint)),
          _WheelColumn(
            count: 60,
            selected: time.minute,
            onSelected: (m) => onChanged(time.replacing(minute: m)),
          ),
        ],
      ),
    );
  }
}

class _WheelColumn extends StatefulWidget {
  const _WheelColumn({
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  final int count;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  State<_WheelColumn> createState() => _WheelColumnState();
}

class _WheelColumnState extends State<_WheelColumn> {
  late final FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: widget.selected);
  }

  @override
  void didUpdateWidget(covariant _WheelColumn old) {
    super.didUpdateWidget(old);
    if (widget.selected != old.selected &&
        _controller.hasClients &&
        _controller.selectedItem != widget.selected) {
      _controller.jumpToItem(widget.selected);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 80,
      child: ListWheelScrollView.useDelegate(
        controller: _controller,
        itemExtent: 58,
        perspective: 0.004,
        diameterRatio: 1.5,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (i) {
          HapticFeedback.selectionClick();
          widget.onSelected(i);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: widget.count,
          builder: (context, i) {
            final isSel = i == widget.selected;
            return Center(
              child: Text(
                i.toString().padLeft(2, '0'),
                style: text.displaySmall?.copyWith(
                  color: isSel ? t.brand : t.textFaint,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w300,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MissionOption extends StatelessWidget {
  const _MissionOption({
    required this.mission,
    required this.selected,
    this.onTap,
  });

  final MissionType mission;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final enabled = onTap != null;

    return AppCard(
      onTap: onTap,
      selected: selected,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.55,
        child: Row(
          children: [
            Icon(_iconFor(mission), color: selected ? t.brand : t.textSecondary),
            const Gap.w(AppTokens.space12),
            Expanded(
              child: Text(
                mission == MissionType.none ? 'None (tap to dismiss)' : mission.label,
                style: text.titleSmall?.copyWith(color: t.textPrimary),
              ),
            ),
            if (!mission.isImplemented)
              const _Tag(text: 'Later')
            else if (selected)
              Icon(Icons.check_circle_rounded, color: t.brand, size: 20),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(MissionType m) => switch (m) {
        MissionType.none => Icons.touch_app_outlined,
        MissionType.math => Icons.calculate_outlined,
        MissionType.shake => Icons.vibration,
        MissionType.photo => Icons.photo_camera_outlined,
        MissionType.barcode => Icons.qr_code_scanner,
      };
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space8,
        vertical: AppTokens.space2,
      ),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: AppTokens.cornerSm,
      ),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: t.textFaint),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text('$value $unit', style: text.titleMedium)),
        _RoundIconButton(
          icon: Icons.remove_rounded,
          onTap: value > min ? () => onChanged(value - 1) : null,
        ),
        const Gap.w(AppTokens.space12),
        _RoundIconButton(
          icon: Icons.add_rounded,
          onTap: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onTap != null;
    return Material(
      color: t.surface2,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space8),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? t.textPrimary : t.textFaint,
          ),
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.label, required this.onSave});

  final String label;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GlassSurface(
      borderRadius: BorderRadius.zero,
      bordered: false,
      opacity: 0.6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.hairline)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.space16),
            child: PrimaryButton(label: label, onPressed: () => onSave()),
          ),
        ),
      ),
    );
  }
}
