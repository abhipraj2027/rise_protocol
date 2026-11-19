import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/alarm_bridge.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/clock_display.dart';
import '../../core/ui/gap.dart';
import '../../core/ui/primary_button.dart';
import '../../core/wake_stats.dart';
import '../../data/alarm.dart';
import '../../data/alarm_repository.dart';
import 'missions/math_mission.dart';
import 'missions/qna_mission.dart';

/// Full-screen ringing UI. Launched two ways:
///  1. As `/ringing` inside the normal app (e.g. a manual "test alarm" button).
///  2. As the sole route of the *second* Flutter engine that
///     AlarmRingingActivity.kt starts when the alarm actually fires — that
///     path is what has to survive a killed app + locked screen.
///
/// Audio + vibration are owned by the native AlarmRingService (so the alarm
/// rings even if this screen never launches). This widget owns the visuals,
/// the mission gate, and the snooze / dismiss calls back through the
/// MethodChannel. It always renders in the fixed-dark ringing theme.
class RingingScreen extends ConsumerStatefulWidget {
  const RingingScreen({
    super.key,
    required this.alarmId,
    required this.label,
    required this.missionType,
    this.qnaQuestion = '',
    this.qnaAnswer = '',
  });

  final int alarmId;
  final String label;
  final MissionType missionType;
  /// Only used when [missionType] is [MissionType.qna].
  final String qnaQuestion;
  final String qnaAnswer;

  @override
  ConsumerState<RingingScreen> createState() => _RingingScreenState();
}

class _RingingScreenState extends ConsumerState<RingingScreen>
    with SingleTickerProviderStateMixin {
  /// How long one mute call silences the alarm natively (see [_quiet]).
  static const _quietFor = Duration(seconds: 15);

  Timer? _clockTimer;
  final DateTime _ringStartedAt = DateTime.now();

  /// Drains over [_quietFor] from the last mute call — the bar that shows
  /// when the sound is coming back.
  late final AnimationController _quietBar =
      AnimationController(vsync: this, duration: _quietFor);

  /// Snoozes already used this ring; null until read.
  int? _snoozesUsed;

  /// Filled in once the cleared mission is recorded.
  WakeSummary? _summary;
  Timer? _autoFinish;
  bool _finishing = false;
  DateTime _now = DateTime.now();
  bool _missionActive = false;
  bool _dismissed = false;
  DateTime? _lastMuteCall;

  /// The alarm's saved settings, for mission difficulty and problem count.
  /// Looked up by id rather than passed through the native intent; null
  /// until loaded, or if the lookup fails, and then the mission uses its
  /// defaults — it must never be what keeps someone from stopping an alarm.
  Alarm? _alarm;

  @override
  void initState() {
    super.initState();
    _loadAlarm();
    _loadSnoozes();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _autoFinish?.cancel();
    _quietBar.dispose();
    super.dispose();
  }

  Future<void> _loadAlarm() async {
    try {
      final alarms = await ref
          .read(alarmRepositoryProvider)
          .getAll()
          .timeout(const Duration(seconds: 2));
      final match = alarms.where((a) => a.id == widget.alarmId);
      if (match.isNotEmpty && mounted) setState(() => _alarm = match.first);
    } catch (_) {
      // Defaults it is.
    }
  }

  Future<void> _loadSnoozes() async {
    try {
      final used = await ref.read(wakeStatsProvider).snoozesUsed(widget.alarmId);
      if (mounted) setState(() => _snoozesUsed = used);
    } catch (_) {
      // Unknown — Snooze stays available.
    }
  }

  /// Null when unknown (alarm or count not loaded): Snooze is then shown
  /// without a count rather than hidden.
  int? get _snoozesLeft {
    final alarm = _alarm;
    final used = _snoozesUsed;
    if (alarm == null || used == null) return null;
    return max(0, alarm.maxSnoozes - used);
  }

  Future<void> _onMissionComplete() async {
    if (_dismissed) return;
    HapticFeedback.mediumImpact();
    // Silence the alarm while the morning screen is up. dismissRinging also
    // closes this screen natively, so it waits for [_finish].
    ref.read(alarmBridgeProvider).muteRinging(_quietFor.inSeconds);
    _quietBar.stop();
    setState(() => _dismissed = true);
    // Leaves well before the mute runs out, even if nobody taps.
    _autoFinish = Timer(const Duration(seconds: 6), _finish);

    // The in-app test route uses id -1; that's not a real morning.
    if (widget.alarmId < 0) return;
    try {
      final summary =
          await ref.read(wakeStatsProvider).recordWake(widget.alarmId);
      if (mounted) setState(() => _summary = summary);
    } catch (_) {
      // The morning screen simply shows no stats.
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _autoFinish?.cancel();
    await ref.read(alarmBridgeProvider).dismissRinging(widget.alarmId);
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _snooze() async {
    if (_dismissed) return;
    HapticFeedback.selectionClick();
    // null = use this alarm's own snooze length (the editor setting, stored
    // natively when the alarm was scheduled).
    await ref.read(alarmBridgeProvider).snoozeRinging(widget.alarmId, null);
    if (mounted) Navigator.of(context).maybePop();
  }

  /// Quiets the alarm while the user works on the mission. Native brings the
  /// sound back by itself after 15s without input, so this is throttled to
  /// one call every few seconds instead of one per keystroke.
  void _quiet() {
    final now = DateTime.now();
    final last = _lastMuteCall;
    if (last != null && now.difference(last) < const Duration(seconds: 5)) {
      return;
    }
    _lastMuteCall = now;
    ref.read(alarmBridgeProvider).muteRinging(_quietFor.inSeconds);
    _quietBar.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final showMission =
        _missionActive || widget.missionType == MissionType.none;

    return PopScope(
      // Back button must not dismiss the alarm — that would defeat the
      // entire point of the app.
      canPop: false,
      child: Scaffold(
        backgroundColor: t.ringingBackground,
        body: Stack(
          children: [
            Positioned.fill(child: _AmbientGlow(startedAt: _ringStartedAt)),
            Positioned.fill(
              child: SafeArea(
                // Scrolls only as a fallback: on short screens the mission
                // keypad plus clock can exceed the viewport, and an overflow
                // here would leave the user unable to stop the alarm.
                child: LayoutBuilder(
                  builder: (context, viewport) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: viewport.maxHeight),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTokens.space24,
                            vertical: AppTokens.space32,
                          ),
                          child: Column(
                            children: [
                              const Spacer(flex: 2),
                              // Steps down while a mission is on screen to give
                              // the keypad room.
                              ClockDisplay(
                                time: _now,
                                style: _missionActive ? text.displayMedium : null,
                              ),
                              // The date only while the clock has room for it;
                              // during a mission the keypad needs the space.
                              if (!_missionActive) ...[
                                const Gap(AppTokens.space8),
                                Text(
                                  DateFormat.MMMMEEEEd().format(_now),
                                  style: text.titleMedium?.copyWith(
                                    color: t.textSecondary,
                                  ),
                                ),
                              ],
                              if (_missionActive && !_dismissed) ...[
                                const Gap(AppTokens.space12),
                                _QuietBar(animation: _quietBar, total: _quietFor),
                              ],
                              if (widget.label.isNotEmpty) ...[
                                const Gap(AppTokens.space8),
                                Text(
                                  widget.label,
                                  textAlign: TextAlign.center,
                                  style: text.titleMedium?.copyWith(
                                    color: t.brand,
                                  ),
                                ),
                              ],
                              const Spacer(flex: 2),
                              if (!_dismissed)
                                showMission
                                    ? _MissionArea(
                                        missionType: widget.missionType,
                                        difficulty:
                                            _alarm?.missionDifficulty ?? 1,
                                        problemCount:
                                            _alarm?.missionCount ?? 3,
                                        qnaQuestion: widget.qnaQuestion,
                                        qnaAnswer: widget.qnaAnswer,
                                        onComplete: _onMissionComplete,
                                        onInteraction: _quiet,
                                      )
                                    : _StartArea(
                                        missionType: widget.missionType,
                                        onDismissNoMission: _onMissionComplete,
                                        onStartMission: () {
                                          setState(() => _missionActive = true);
                                          _quiet();
                                        },
                                      ),
                              const Spacer(flex: 3),
                              if (!_dismissed)
                                _SnoozeButton(onTap: _snooze, left: _snoozesLeft),
                              const Gap(AppTokens.space8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_dismissed)
              Positioned.fill(
                child: _MorningScreen(summary: _summary, onDone: _finish),
              ),
          ],
        ),
      ),
    );
  }

}

/// A very slow drifting radial glow behind the clock — just enough motion to
/// read as "alive" without being distracting to someone half awake.
class _AmbientGlow extends StatefulWidget {
  const _AmbientGlow({required this.startedAt});

  /// When the alarm started ringing: the glow warms up from here.
  final DateTime startedAt;

  /// Time for the "sunrise" to reach full strength.
  static const sunrise = Duration(minutes: 3);

  @override
  State<_AmbientGlow> createState() => _AmbientGlowState();
}

class _AmbientGlowState extends State<_AmbientGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppTokens.motionAmbient,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final a = Curves.easeInOut.transform(_controller.value);
        // 0 → 1 over [_AmbientGlow.sunrise]: the glow strengthens and a warm
        // horizon rises from the bottom the longer the alarm rings.
        final elapsed = DateTime.now().difference(widget.startedAt);
        final warmth = Curves.easeIn.transform(
          (elapsed.inMilliseconds / _AmbientGlow.sunrise.inMilliseconds)
              .clamp(0.0, 1.0),
        );
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.lerp(
                const Alignment(-0.7, -0.9),
                const Alignment(0.7, 0.5),
                a,
              )!,
              radius: 1.4,
              colors: [
                Color.lerp(t.brand, t.ringingBackground, 0.74 - 0.24 * warmth)!,
                t.ringingBackground,
              ],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [
                  t.brand.withValues(alpha: 0.28 * warmth),
                  t.brand.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StartArea extends StatelessWidget {
  const _StartArea({
    required this.missionType,
    required this.onDismissNoMission,
    required this.onStartMission,
  });

  final MissionType missionType;
  final VoidCallback onDismissNoMission;
  final VoidCallback onStartMission;

  @override
  Widget build(BuildContext context) {
    final isNone = missionType == MissionType.none;
    return PrimaryButton(
      label: isNone ? 'Dismiss' : 'Start mission',
      onPressed: isNone ? onDismissNoMission : onStartMission,
    );
  }
}

class _MissionArea extends StatelessWidget {
  const _MissionArea({
    required this.missionType,
    required this.difficulty,
    required this.problemCount,
    required this.onComplete,
    required this.onInteraction,
    this.qnaQuestion = '',
    this.qnaAnswer = '',
  });

  final MissionType missionType;
  final int difficulty;
  final int problemCount;
  final VoidCallback onComplete;
  final VoidCallback onInteraction;
  final String qnaQuestion;
  final String qnaAnswer;

  @override
  Widget build(BuildContext context) {
    switch (missionType) {
      case MissionType.math:
        return MathMissionView(
          difficulty: difficulty.clamp(1, 3),
          problemCount: problemCount.clamp(1, 5),
          onComplete: onComplete,
          onInteraction: onInteraction,
        );
      case MissionType.qna:
        return QnaMissionView(
          question: qnaQuestion,
          answer: qnaAnswer,
          onComplete: onComplete,
          onInteraction: onInteraction,
        );
      case MissionType.none:
        return const SizedBox.shrink();
      case MissionType.shake:
      case MissionType.photo:
      case MissionType.barcode:
        // Falls back to a plain dismiss until these ship in Phase C — never
        // leave the user stuck against an alarm with no way out.
        return PrimaryButton(label: 'Dismiss', onPressed: onComplete);
    }
  }
}

class _SnoozeButton extends StatelessWidget {
  const _SnoozeButton({required this.onTap, required this.left});

  final VoidCallback onTap;

  /// Snoozes remaining, or null if unknown.
  final int? left;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (left == 0) {
      return Padding(
        padding: const EdgeInsets.all(AppTokens.space12),
        child: Text(
          'No snoozes left',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.snooze_rounded, size: 18, color: t.textFaint),
      label: Text(
        left == null ? 'Snooze' : 'Snooze · $left left',
        style: TextStyle(color: t.textFaint),
      ),
    );
  }
}

/// Shown while a mission is in progress: how long until the alarm sound
/// comes back. Refills on every mute call; turns red for the last seconds.
class _QuietBar extends StatelessWidget {
  const _QuietBar({required this.animation, required this.total});

  final Animation<double> animation;
  final Duration total;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final running = animation.value > 0 && animation.value < 1;
        final remaining = 1 - animation.value;
        final seconds = (remaining * total.inSeconds).ceil();
        final urgent = running && seconds <= 3;
        final color = urgent ? t.danger : t.missionAccent;
        return SizedBox(
          width: 200,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                child: LinearProgressIndicator(
                  value: running ? remaining : 0,
                  minHeight: 4,
                  color: color,
                  backgroundColor: t.surface2,
                ),
              ),
              const Gap(AppTokens.space4),
              Text(
                running ? 'Quiet · sound returns in ${seconds}s' : 'Alarm is ringing',
                style: text.bodySmall?.copyWith(
                  color: urgent ? t.danger : t.textFaint,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shown after a mission is cleared, until [onDone] (a tap, or a timer in
/// the ringing screen): a sunrise ground with the wake-up time, the streak
/// and the snooze count. Stats appear once [summary] arrives; without it
/// the screen still works, just quieter.
class _MorningScreen extends StatelessWidget {
  const _MorningScreen({required this.summary, required this.onDone});

  final WakeSummary? summary;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final s = summary;
    final wokeAt = (MediaQuery.alwaysUse24HourFormatOf(context)
            ? DateFormat.Hm()
            : DateFormat.jm())
        .format(s?.wokeAt ?? DateTime.now());

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: AppTokens.motionSlow,
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(opacity: v, child: child),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              t.ringingBackground,
              Color.lerp(t.ringingBackground, t.brand, 0.35)!,
              t.brand,
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.space24),
            child: Column(
              children: [
                const Spacer(flex: 3),
                Icon(Icons.wb_sunny_rounded, size: 56, color: t.brand),
                const Gap(AppTokens.space16),
                Text('Good morning', style: text.displaySmall),
                const Gap(AppTokens.space8),
                Text(
                  'Up at $wokeAt',
                  style: text.titleMedium?.copyWith(color: t.textSecondary),
                ),
                const Gap(AppTokens.space32),
                AnimatedOpacity(
                  opacity: s == null ? 0 : 1,
                  duration: AppTokens.motionBase,
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          icon: Icons.local_fire_department_rounded,
                          value: '${s?.streakDays ?? 0}',
                          label: 'day streak',
                        ),
                      ),
                      const Gap.w(AppTokens.space12),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.snooze_rounded,
                          value: '${s?.snoozes ?? 0}',
                          label: s?.snoozes == 1 ? 'snooze' : 'snoozes',
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 4),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onDone,
                    style: FilledButton.styleFrom(
                      backgroundColor: t.ringingForeground,
                      foregroundColor: t.ringingBackground,
                    ),
                    child: const Text('Start my day'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: t.ringingBackground.withValues(alpha: 0.45),
        borderRadius: AppTokens.cornerLg,
        border: Border.all(color: t.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: t.brand),
          const Gap(AppTokens.space8),
          Text(value, style: text.headlineMedium),
          Text(label, style: text.bodySmall?.copyWith(color: t.textSecondary)),
        ],
      ),
    );
  }
}
