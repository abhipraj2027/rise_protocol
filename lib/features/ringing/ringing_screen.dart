import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/alarm_bridge.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/gap.dart';
import '../../core/ui/primary_button.dart';
import '../../data/alarm.dart';
import 'missions/math_mission.dart';

/// Full-screen ringing UI. Launched two ways:
///  1. As `/ringing` inside the normal app (e.g. a manual "test alarm" button).
///  2. As the sole route of the *second* Flutter engine that
///     AlarmRingingActivity.kt starts when the alarm actually fires — that
///     path is what has to survive a killed app + locked screen.
///
/// Either way this widget owns: looping the alarm sound, snooze (always
/// available, capped by maxSnoozes upstream), and gating dismiss behind the
/// configured mission. It always renders in the fixed-dark ringing theme.
class RingingScreen extends ConsumerStatefulWidget {
  const RingingScreen({
    super.key,
    required this.alarmId,
    required this.label,
    required this.missionType,
  });

  final int alarmId;
  final String label;
  final MissionType missionType;

  @override
  ConsumerState<RingingScreen> createState() => _RingingScreenState();
}

class _RingingScreenState extends ConsumerState<RingingScreen> {
  final _player = AudioPlayer();
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  bool _missionActive = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _startAudio();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  Future<void> _startAudio() async {
    try {
      // Bundle your own alarm tone at assets/sounds/default_alarm.mp3 and
      // register it in pubspec.yaml's flutter: assets: list.
      await _player.setAsset('assets/sounds/default_alarm.mp3');
      await _player.setLoopMode(LoopMode.one);
      await _player.setVolume(0.15);
      await _player.play();
      unawaited(_ramp());
    } catch (_) {
      // Missing asset in this scaffold is expected until you drop in a
      // sound file — the mission flow still works without audio.
    }
  }

  /// Gradual volume ramp so the alarm doesn't detonate at full volume the
  /// instant it fires — mirrors Alarmy's "gentle-then-insistent" escalation.
  Future<void> _ramp() async {
    for (double v = 0.15; v <= 1.0; v += 0.05) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted || !_player.playing) return;
      await _player.setVolume(v.clamp(0.0, 1.0));
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _onMissionComplete() async {
    if (_dismissed) return;
    await _player.stop();
    HapticFeedback.mediumImpact();
    setState(() => _dismissed = true);
    // Hold the "good morning" moment briefly before tearing the screen down.
    await Future.delayed(const Duration(milliseconds: 1100));
    await ref.read(alarmBridgeProvider).dismissRinging(widget.alarmId);
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _snooze() async {
    if (_dismissed) return;
    await _player.stop();
    // TODO(phase D): read the alarm's configured snoozeMinutes/maxSnoozes
    // instead of the hardcoded default once this screen has DB access.
    await ref.read(alarmBridgeProvider).snoozeRinging(widget.alarmId, 5);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final timeText = '${_two(_now.hour)}:${_two(_now.minute)}';
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
            const Positioned.fill(child: _AmbientGlow()),
            Positioned.fill(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space24,
                    vertical: AppTokens.space32,
                  ),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      Text(
                        timeText,
                        style: text.displayLarge?.copyWith(
                          color: t.ringingForeground,
                        ),
                      ),
                      if (widget.label.isNotEmpty) ...[
                        const Gap(AppTokens.space8),
                        Text(
                          widget.label,
                          style: text.titleMedium?.copyWith(
                            color: t.textSecondary,
                          ),
                        ),
                      ],
                      const Spacer(flex: 2),
                      if (!_dismissed)
                        showMission
                            ? _MissionArea(
                                missionType: widget.missionType,
                                onComplete: _onMissionComplete,
                              )
                            : _StartArea(
                                missionType: widget.missionType,
                                onDismissNoMission: _onMissionComplete,
                                onStartMission: () =>
                                    setState(() => _missionActive = true),
                              ),
                      const Spacer(flex: 3),
                      if (!_dismissed) _SnoozeButton(onTap: _snooze),
                      const Gap(AppTokens.space8),
                    ],
                  ),
                ),
              ),
            ),
            if (_dismissed) const Positioned.fill(child: _GoodMorning()),
          ],
        ),
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

/// A very slow drifting radial glow behind the clock — just enough motion to
/// read as "alive" without being distracting to someone half awake.
class _AmbientGlow extends StatefulWidget {
  const _AmbientGlow();

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
                Color.lerp(t.brand, t.ringingBackground, 0.74)!,
                t.ringingBackground,
              ],
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
  const _MissionArea({required this.missionType, required this.onComplete});

  final MissionType missionType;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    switch (missionType) {
      case MissionType.math:
        return MathMissionView(difficulty: 1, onComplete: onComplete);
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
  const _SnoozeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.snooze_rounded, size: 18, color: t.textFaint),
      label: Text('Snooze', style: TextStyle(color: t.textFaint)),
    );
  }
}

/// The full-bleed positive beat shown for ~1s after a mission is cleared,
/// before the ringing screen tears itself down.
class _GoodMorning extends StatelessWidget {
  const _GoodMorning();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: AppTokens.motionSlow,
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(opacity: v, child: child),
      child: ColoredBox(
        color: t.brand,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wb_sunny_rounded, size: 64, color: t.onBrand),
              const Gap(AppTokens.space16),
              Text(
                'Good morning',
                style: text.displaySmall?.copyWith(color: t.onBrand),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
