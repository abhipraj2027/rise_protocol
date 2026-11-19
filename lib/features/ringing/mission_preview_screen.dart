import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/gap.dart';
import '../../data/alarm.dart';
import 'missions/math_mission.dart';
import 'missions/qna_mission.dart';

/// A dry run of an alarm's mission from the editor: the real mission UI in
/// the ringing theme, with no sound and a close button, so people can feel
/// how hard their settings are before they're stuck with them at 6am.
class MissionPreviewScreen extends StatefulWidget {
  const MissionPreviewScreen({super.key, required this.alarm});

  final Alarm alarm;

  static Future<void> open(BuildContext context, Alarm alarm) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Theme(
          data: AppTheme.ringing(),
          child: MissionPreviewScreen(alarm: alarm),
        ),
      ),
    );
  }

  @override
  State<MissionPreviewScreen> createState() => _MissionPreviewScreenState();
}

class _MissionPreviewScreenState extends State<MissionPreviewScreen> {
  bool _passed = false;

  Future<void> _onComplete() async {
    HapticFeedback.mediumImpact();
    setState(() => _passed = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final alarm = widget.alarm;

    final Widget mission = switch (alarm.missionType) {
      MissionType.math => MathMissionView(
          difficulty: alarm.missionDifficulty,
          problemCount: alarm.missionCount,
          onComplete: _onComplete,
        ),
      MissionType.qna => QnaMissionView(
          question: alarm.qnaQuestion,
          answer: alarm.qnaAnswer,
          onComplete: _onComplete,
        ),
      _ => Text(
          'This alarm has no mission — one tap stops it.',
          textAlign: TextAlign.center,
          style: text.bodyMedium,
        ),
    };

    return Scaffold(
      backgroundColor: t.ringingBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space8,
                AppTokens.space8,
                AppTokens.space16,
                0,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close preview',
                    icon: Icon(Icons.close_rounded, color: t.textSecondary),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.space12,
                      vertical: AppTokens.space4,
                    ),
                    decoration: BoxDecoration(
                      color: t.surface2,
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusPill),
                    ),
                    child: Text(
                      'PREVIEW · NO SOUND',
                      style: text.labelSmall?.copyWith(color: t.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppTokens.motionBase,
                child: _passed
                    ? Center(
                        key: const ValueKey('passed'),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 64,
                              color: t.success,
                            ),
                            const Gap(AppTokens.space16),
                            Text('Mission passed', style: text.headlineSmall),
                            const Gap(AppTokens.space4),
                            Text(
                              'That’s what it takes to stop this alarm.',
                              style: text.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : Center(
                        key: const ValueKey('mission'),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(AppTokens.space24),
                          child: mission,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
