import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/alarm_bridge.dart';
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
/// configured mission.
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
    await _player.stop();
    await ref.read(alarmBridgeProvider).dismissRinging(widget.alarmId);
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _snooze() async {
    await _player.stop();
    // TODO(phase 2): read the alarm's configured snoozeMinutes/maxSnoozes
    // instead of the hardcoded default once this screen has DB access
    // (the second-engine ringing path launches before the app's normal
    // provider tree is guaranteed warm — plumb alarm details through the
    // initial route query string alongside id/label/mission, same as today).
    await ref.read(alarmBridgeProvider).snoozeRinging(widget.alarmId, 5);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeText =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';

    return PopScope(
      // Back button must not dismiss the alarm — that would defeat the
      // entire point of the app.
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text(
                  timeText,
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w200,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (widget.label.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(widget.label, style: theme.textTheme.titleMedium),
                ],
                const Spacer(),
                if (_missionActive || widget.missionType == MissionType.none)
                  _MissionArea(
                    missionType: widget.missionType,
                    onComplete: _onMissionComplete,
                  )
                else
                  _StartArea(
                    missionType: widget.missionType,
                    onDismissNoMission: _onMissionComplete,
                    onStartMission: () => setState(() => _missionActive = true),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _snooze,
                  icon: const Icon(Icons.snooze),
                  label: const Text('Snooze'),
                ),
              ],
            ),
          ),
        ),
      ),
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
    return FilledButton(
      onPressed: isNone ? onDismissNoMission : onStartMission,
      style: FilledButton.styleFrom(
        minimumSize: const Size(240, 64),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      child: Text(isNone ? 'Dismiss' : 'Start mission'),
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
        // Falls back to a plain dismiss until these ship in Phase 2 —
        // never leave the user stuck against an alarm with no way out.
        return FilledButton(
          onPressed: onComplete,
          child: const Text('Dismiss (mission not yet implemented)'),
        );
    }
  }
}
