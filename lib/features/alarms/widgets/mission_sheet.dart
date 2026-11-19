import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/gap.dart';
import '../../../core/ui/primary_button.dart';
import '../../../data/alarm.dart';
import '../../ringing/mission_preview_screen.dart';
import '../../ringing/missions/math_mission.dart';
import '../mission_icons.dart';

/// Display names for `Alarm.missionDifficulty` on a math mission.
const mathDifficultyNames = {1: 'Easy', 2: 'Medium', 3: 'Hard'};

/// "Math · Medium · 3", "Question", "None" — the value shown on the editor's
/// Mission row.
String missionSummary(Alarm alarm) => switch (alarm.missionType) {
      MissionType.math => 'Math · '
          '${mathDifficultyNames[alarm.missionDifficulty] ?? 'Easy'} · '
          '${alarm.missionCount}',
      MissionType.none => 'None',
      final m => m.shortLabel,
    };

/// Opens the mission picker over the editor. Resolves to [draft] with the
/// mission fields changed, or null if the sheet was dismissed.
Future<Alarm?> showMissionSheet(BuildContext context, Alarm draft) {
  return showModalBottomSheet<Alarm>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.tokens.surface1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTokens.radiusXl),
      ),
    ),
    builder: (_) => _MissionSheet(draft: draft),
  );
}

class _MissionSheet extends StatefulWidget {
  const _MissionSheet({required this.draft});

  final Alarm draft;

  @override
  State<_MissionSheet> createState() => _MissionSheetState();
}

class _MissionSheetState extends State<_MissionSheet> {
  late MissionType _type = widget.draft.missionType;
  late int _difficulty = widget.draft.missionDifficulty.clamp(1, 3);
  late int _count = widget.draft.missionCount.clamp(1, 5);
  late final _question = TextEditingController(text: widget.draft.qnaQuestion);
  late final _answer = TextEditingController(text: widget.draft.qnaAnswer);

  /// One sample per difficulty, so flipping back and forth doesn't reshuffle.
  final _samples = <int, MathProblem>{};

  @override
  void dispose() {
    _question.dispose();
    _answer.dispose();
    super.dispose();
  }

  Alarm get _result => widget.draft.copyWith(
        missionType: _type,
        missionDifficulty: _difficulty,
        missionCount: _count,
        qnaQuestion: _question.text.trim(),
        qnaAnswer: _answer.text.trim(),
      );

  bool get _valid =>
      _type != MissionType.qna ||
      (_question.text.trim().isNotEmpty && _answer.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final missions =
        MissionType.values.where((m) => m.isImplemented).toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.space20,
          0,
          AppTokens.space20,
          AppTokens.space20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mission', style: text.titleLarge),
            const Gap(AppTokens.space4),
            Text(
              'What you have to do before the alarm will stop.',
              style: text.bodyMedium,
            ),
            const Gap(AppTokens.space20),
            Row(
              children: [
                for (var i = 0; i < missions.length; i++) ...[
                  if (i > 0) const Gap.w(AppTokens.space12),
                  Expanded(
                    child: _MissionTile(
                      mission: missions[i],
                      selected: missions[i] == _type,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _type = missions[i]);
                      },
                    ),
                  ),
                ],
              ],
            ),
            const Gap(AppTokens.space8),
            Text(
              'Shake, photo and barcode missions are coming soon.',
              style: text.bodySmall,
            ),
            const Gap(AppTokens.space24),
            AnimatedSize(
              duration: AppTokens.motionBase,
              curve: AppTokens.easeStandard,
              alignment: Alignment.topCenter,
              child: switch (_type) {
                MissionType.math => _mathSettings(context),
                MissionType.qna => _qnaSettings(context),
                _ => Text(
                    'One tap stops the alarm. Easy to sleep through — pick a '
                    'mission if you mean it.',
                    style: text.bodyMedium?.copyWith(color: t.warning),
                  ),
              },
            ),
            const Gap(AppTokens.space24),
            Row(
              children: [
                if (_type != MissionType.none) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _valid
                          ? () => MissionPreviewScreen.open(context, _result)
                          : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Preview'),
                    ),
                  ),
                  const Gap.w(AppTokens.space12),
                ],
                Expanded(
                  child: PrimaryButton(
                    label: 'Done',
                    onPressed:
                        _valid ? () => Navigator.of(context).pop(_result) : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mathSettings(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final sample =
        _samples.putIfAbsent(_difficulty, () => MathProblem.random(_difficulty));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('DIFFICULTY', style: text.labelSmall),
        const Gap(AppTokens.space8),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            for (final e in mathDifficultyNames.entries)
              ButtonSegment(value: e.key, label: Text(e.value)),
          ],
          selected: {_difficulty},
          onSelectionChanged: (s) {
            HapticFeedback.selectionClick();
            setState(() => _difficulty = s.first);
          },
        ),
        const Gap(AppTokens.space12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppTokens.space16),
          decoration: BoxDecoration(
            color: t.surface2,
            borderRadius: AppTokens.cornerMd,
          ),
          child: Column(
            children: [
              Text('Example', style: text.bodySmall),
              const Gap(AppTokens.space4),
              AnimatedSwitcher(
                duration: AppTokens.motionFast,
                child: Text(
                  '${sample.prompt} = ?',
                  key: ValueKey(_difficulty),
                  style: text.displaySmall?.copyWith(color: t.textPrimary),
                ),
              ),
            ],
          ),
        ),
        const Gap(AppTokens.space20),
        Row(
          children: [
            Expanded(child: Text('PROBLEMS', style: text.labelSmall)),
            Text(
              '$_count to solve',
              style: text.bodyMedium?.copyWith(color: t.textSecondary),
            ),
          ],
        ),
        const Gap(AppTokens.space8),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            for (var n = 1; n <= 5; n++)
              ButtonSegment(value: n, label: Text('$n')),
          ],
          selected: {_count},
          onSelectionChanged: (s) {
            HapticFeedback.selectionClick();
            setState(() => _count = s.first);
          },
        ),
      ],
    );
  }

  Widget _qnaSettings(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Write your own challenge — you’ll have to type the answer back to '
          'dismiss the alarm.',
          style: text.bodyMedium,
        ),
        const Gap(AppTokens.space12),
        TextField(
          controller: _question,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Question',
            hintText: 'e.g. What time is the school run?',
          ),
        ),
        const Gap(AppTokens.space12),
        TextField(
          controller: _answer,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Answer',
            hintText: 'e.g. 7:45',
          ),
        ),
      ],
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({
    required this.mission,
    required this.selected,
    required this.onTap,
  });

  final MissionType mission;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final accent = mission == MissionType.none ? t.textSecondary : t.missionAccent;

    return Material(
      color: selected ? accent.withValues(alpha: 0.14) : t.surface2,
      borderRadius: AppTokens.cornerMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTokens.cornerMd,
        child: AnimatedContainer(
          duration: AppTokens.motionFast,
          padding: const EdgeInsets.symmetric(vertical: AppTokens.space16),
          decoration: BoxDecoration(
            borderRadius: AppTokens.cornerMd,
            border: Border.all(
              color: selected ? accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(mission.icon, size: 28, color: selected ? accent : t.textSecondary),
              const Gap(AppTokens.space8),
              Text(
                mission == MissionType.none ? 'None' : mission.shortLabel,
                style: text.titleSmall?.copyWith(
                  color: selected ? t.textPrimary : t.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
