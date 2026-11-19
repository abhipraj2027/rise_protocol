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
import '../../core/ui/settings_group.dart';
import '../../core/ui/weekday_selector.dart';
import '../../data/alarm.dart';
import '../../data/alarm_repository.dart';
import 'alarm_formatting.dart';
import 'mission_icons.dart';
import 'widgets/mission_sheet.dart';

/// Create screen when [alarmId] is null, edit screen otherwise.
///
/// Layout: the time wheel, the repeat days, then one grouped settings card —
/// Mission (opens [showMissionSheet]), Snooze with an inline stepper, and
/// Label as an inline field.
class EditAlarmScreen extends ConsumerStatefulWidget {
  const EditAlarmScreen({super.key, this.alarmId});

  final int? alarmId;

  @override
  ConsumerState<EditAlarmScreen> createState() => _EditAlarmScreenState();
}

class _EditAlarmScreenState extends ConsumerState<EditAlarmScreen> {
  late TimeOfDay _time;
  final _labelController = TextEditingController();
  Set<int> _repeatDays = {};
  int _snoozeMinutes = 5;

  /// Holds the mission type, difficulty, problem count and Q&A as last set
  /// in the mission sheet. Only those fields of this alarm are read.
  Alarm _mission = const Alarm(hour: 0, minute: 0);
  Alarm? _existing;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _time = TimeOfDay.now().replacing(minute: 0);
    if (widget.alarmId == null) _loaded = true;
  }

  void _loadExisting(Alarm alarm) {
    if (_loaded) return;
    _existing = alarm;
    _time = TimeOfDay(hour: alarm.hour, minute: alarm.minute);
    _labelController.text = alarm.label;
    _repeatDays = {...alarm.repeatDays};
    _snoozeMinutes = alarm.snoozeMinutes;
    _mission = alarm;
    _loaded = true;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  /// A custom-question mission needs both fields filled in to make sense —
  /// blocks Save rather than shipping a mission with no way to clear it.
  /// The mission sheet enforces this too; this is the backstop.
  bool get _canSave =>
      _mission.missionType != MissionType.qna ||
      (_mission.qnaQuestion.isNotEmpty && _mission.qnaAnswer.isNotEmpty);

  Alarm get _draft => (_existing ?? const Alarm(hour: 0, minute: 0)).copyWith(
        hour: _time.hour,
        minute: _time.minute,
        label: _labelController.text.trim(),
        repeatDays: _repeatDays,
        snoozeMinutes: _snoozeMinutes,
        missionType: _mission.missionType,
        missionDifficulty: _mission.missionDifficulty,
        missionCount: _mission.missionCount,
        qnaQuestion: _mission.qnaQuestion,
        qnaAnswer: _mission.qnaAnswer,
        enabled: true,
      );

  Future<void> _editMission() async {
    final result = await showMissionSheet(context, _draft);
    if (result != null && mounted) setState(() => _mission = result);
  }

  Future<void> _save() async {
    HapticFeedback.lightImpact();
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
    HapticFeedback.mediumImpact();
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

    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final mission = _mission.missionType;

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
                          style: text.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(AppTokens.space24),

                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: mission.icon,
                      iconColor: mission == MissionType.none
                          ? t.textSecondary
                          : t.missionAccent,
                      title: 'Mission',
                      value: missionSummary(_mission),
                      onTap: _editMission,
                    ),
                    SettingsRow(
                      icon: Icons.snooze_rounded,
                      title: 'Snooze',
                      trailing: Align(
                        alignment: Alignment.centerRight,
                        child: _Stepper(
                          value: _snoozeMinutes,
                          min: 1,
                          max: 15,
                          unit: 'min',
                          onChanged: (v) => setState(() => _snoozeMinutes = v),
                        ),
                      ),
                    ),
                    SettingsRow(
                      icon: Icons.label_outline_rounded,
                      title: 'Label',
                      trailing: TextField(
                        controller: _labelController,
                        textAlign: TextAlign.end,
                        textCapitalization: TextCapitalization.sentences,
                        style: text.bodyMedium?.copyWith(color: t.textPrimary),
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Gym, Work, Flight…',
                          filled: false,
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
                if (mission == MissionType.none) ...[
                  const Gap(AppTokens.space8),
                  Padding(
                    padding: const EdgeInsets.only(left: AppTokens.space4),
                    child: Text(
                      'No mission — one tap will stop this alarm.',
                      style: text.bodySmall?.copyWith(color: t.warning),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _SaveBar(
            label: _existing == null ? 'Add alarm' : 'Save changes',
            onSave: _save,
            enabled: _canSave,
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
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    return Text(
      'Rings ${dayAndTime(fireAt, now: now, use24h: use24h)}'
      '  ·  ${humanizeUntil(fireAt.difference(now))}',
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(color: t.brand, fontWeight: FontWeight.w600),
    );
  }
}

/// Hour and minute wheels. Follows the device's 12/24-hour setting: in
/// 12-hour mode the hour wheel runs 12, 1 … 11 and an AM/PM wheel follows.
class _TimeWheel extends StatelessWidget {
  const _TimeWheel({required this.time, required this.onChanged});

  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    final isPm = time.hour >= 12;
    final localizations = MaterialLocalizations.of(context);

    return SizedBox(
      height: 176,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Keyed so flipping the system setting rebuilds the wheel rather
          // than reusing a controller sized for the other mode.
          if (use24h)
            _WheelColumn(
              key: const ValueKey('hour-24'),
              count: 24,
              selected: time.hour,
              labelOf: _two,
              onSelected: (h) => onChanged(time.replacing(hour: h)),
            )
          else
            _WheelColumn(
              key: const ValueKey('hour-12'),
              count: 12,
              selected: time.hour % 12,
              labelOf: (i) => i == 0 ? '12' : '$i',
              onSelected: (i) =>
                  onChanged(time.replacing(hour: i + (isPm ? 12 : 0))),
            ),
          Text(':', style: text.displayMedium?.copyWith(color: context.tokens.textFaint)),
          _WheelColumn(
            count: 60,
            selected: time.minute,
            labelOf: _two,
            onSelected: (m) => onChanged(time.replacing(minute: m)),
          ),
          if (!use24h) ...[
            const Gap.w(AppTokens.space8),
            _WheelColumn(
              count: 2,
              selected: isPm ? 1 : 0,
              width: 72,
              small: true,
              labelOf: (i) => i == 0
                  ? localizations.anteMeridiemAbbreviation
                  : localizations.postMeridiemAbbreviation,
              onSelected: (i) => onChanged(
                time.replacing(hour: time.hour % 12 + (i == 1 ? 12 : 0)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _two(int i) => i.toString().padLeft(2, '0');
}

class _WheelColumn extends StatefulWidget {
  const _WheelColumn({
    super.key,
    required this.count,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.width = 80,
    this.small = false,
  });

  final int count;
  final int selected;
  final String Function(int index) labelOf;
  final ValueChanged<int> onSelected;
  final double width;

  /// Smaller type, for the AM/PM wheel.
  final bool small;

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
    final style = widget.small ? text.titleLarge : text.displaySmall;
    return SizedBox(
      width: widget.width,
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
                widget.labelOf(i),
                style: style?.copyWith(
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
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundIconButton(
          icon: Icons.remove_rounded,
          onTap: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 64,
          child: Text(
            '$value $unit',
            textAlign: TextAlign.center,
            style: text.titleSmall,
          ),
        ),
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
          padding: const EdgeInsets.all(AppTokens.space4 + 2),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? t.textPrimary : t.textFaint,
          ),
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.label,
    required this.onSave,
    this.enabled = true,
  });

  final String label;
  final Future<void> Function() onSave;
  final bool enabled;

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
            child: PrimaryButton(
              label: label,
              onPressed: enabled ? () => onSave() : null,
            ),
          ),
        ),
      ),
    );
  }
}
