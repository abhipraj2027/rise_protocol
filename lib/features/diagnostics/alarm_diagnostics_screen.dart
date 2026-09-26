import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/alarm_bridge.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/gap.dart';
import '../../core/ui/section_header.dart';

/// What the phone is actually doing with your alarms: the three permissions
/// that decide whether an alarm can ring and take over the screen, plus the
/// on-device event log (scheduled → fired → screen opened → snoozed…).
///
/// Alarms fail silently when the OS blocks something, so a tester can copy
/// this and send it instead of needing adb.
class AlarmDiagnosticsScreen extends ConsumerStatefulWidget {
  const AlarmDiagnosticsScreen({super.key});

  @override
  ConsumerState<AlarmDiagnosticsScreen> createState() =>
      _AlarmDiagnosticsScreenState();
}

class _AlarmDiagnosticsScreenState
    extends ConsumerState<AlarmDiagnosticsScreen> {
  bool _loading = true;
  bool _exact = false;
  bool _fullScreen = false;
  bool _battery = false;
  List<String> _log = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bridge = ref.read(alarmBridgeProvider);
    final exact = await bridge.canScheduleExactAlarms();
    final fullScreen = await bridge.canUseFullScreenIntent();
    final battery = await bridge.isIgnoringBatteryOptimizations();
    final log = await bridge.getAlarmLog();
    if (!mounted) return;
    setState(() {
      _exact = exact;
      _fullScreen = fullScreen;
      _battery = battery;
      _log = log;
      _loading = false;
    });
  }

  String get _report {
    final lines = _log.reversed.join('\n');
    return 'Rise Protocol diagnostics\n'
        'exact alarms: $_exact\n'
        'full-screen alarms: $_fullScreen\n'
        'battery unrestricted: $_battery\n'
        '--- event log (newest first) ---\n'
        '$lines';
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _report));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied — paste it into your message')),
    );
  }

  Future<void> _clear() async {
    await ref.read(alarmBridgeProvider).clearAlarmLog();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Alarm diagnostics')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppTokens.space20),
              children: [
                const SectionHeader(
                  'Permissions',
                  subtitle: 'All three should be green for a reliable alarm.',
                ),
                const Gap(AppTokens.space12),
                AppCard(
                  child: Column(
                    children: [
                      _CheckRow(label: 'Exact alarms', ok: _exact),
                      const Gap(AppTokens.space12),
                      _CheckRow(label: 'Full-screen alarms', ok: _fullScreen),
                      const Gap(AppTokens.space12),
                      _CheckRow(label: 'Battery: unrestricted', ok: _battery),
                    ],
                  ),
                ),
                const Gap(AppTokens.space24),
                const SectionHeader(
                  'Event log',
                  subtitle: 'Newest first. Send this if an alarm misbehaves.',
                ),
                const Gap(AppTokens.space12),
                AppCard(
                  child: _log.isEmpty
                      ? Text('Nothing recorded yet.', style: text.bodySmall)
                      : SelectableText(
                          _log.reversed.join('\n'),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.5,
                            color: t.textSecondary,
                          ),
                        ),
                ),
                const Gap(AppTokens.space16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _load,
                        child: const Text('Refresh'),
                      ),
                    ),
                    const Gap.w(AppTokens.space12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _copy,
                        child: const Text('Copy'),
                      ),
                    ),
                  ],
                ),
                const Gap(AppTokens.space8),
                Center(
                  child: TextButton(
                    onPressed: _clear,
                    child: const Text('Clear log'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: ok ? t.success : t.danger,
          size: 20,
        ),
        const Gap.w(AppTokens.space12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: t.textPrimary),
          ),
        ),
      ],
    );
  }
}
