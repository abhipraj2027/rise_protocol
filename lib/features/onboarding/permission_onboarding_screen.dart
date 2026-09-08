import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/alarm_bridge.dart';
import '../../core/app_prefs.dart';
import 'permission_step.dart';
import 'widgets/permission_step_card.dart';

/// Shown on first launch (see `_HomeBootstrap` in lib/main.dart), and
/// reachable again later from the alarm list's app bar — permissions can be
/// revoked by the user or the OS after the fact, so this isn't a one-time
/// gate, it's a page the user can always come back to and check.
class PermissionOnboardingScreen extends ConsumerStatefulWidget {
  const PermissionOnboardingScreen({super.key, this.isReview = false});

  /// True when opened from the alarm list (already onboarded) rather than
  /// as the first-launch flow — changes the button label and skips writing
  /// the onboarding-complete flag again.
  final bool isReview;

  @override
  ConsumerState<PermissionOnboardingScreen> createState() =>
      _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState
    extends ConsumerState<PermissionOnboardingScreen> with WidgetsBindingObserver {
  Map<PermissionStepKind, bool>? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Catches the user backing out of the system settings screen we sent
    // them to (e.g. "Alarms & reminders" or the battery optimization
    // dialog) and re-checks so the checklist reflects reality immediately.
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    final bridge = ref.read(alarmBridgeProvider);
    final entries = await Future.wait(
      PermissionStep.all.map((step) async {
        final granted = await step.isGranted(bridge);
        return MapEntry(step.kind, granted);
      }),
    );
    if (mounted) setState(() => _status = Map.fromEntries(entries));
  }

  bool get _allCriticalGranted {
    final status = _status;
    if (status == null) return false;
    return PermissionStep.all
        .where((s) => s.critical)
        .every((s) => status[s.kind] == true);
  }

  Future<void> _resolve(PermissionStep step) async {
    await step.resolve(ref.read(alarmBridgeProvider));
    // Some flows (e.g. the notification permission dialog) resolve
    // synchronously without leaving the app, so re-check right away too —
    // didChangeAppLifecycleState covers the ones that do leave the app.
    await _refreshStatus();
  }

  Future<void> _finish() async {
    if (!widget.isReview) {
      await ref.read(appPrefsProvider).setOnboardingComplete(true);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _status;

    return Scaffold(
      appBar: widget.isReview ? AppBar(title: const Text('Permissions')) : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.isReview) ...[
                Icon(Icons.shield_outlined, size: 40, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'A few permissions first',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Android locks down background apps by default. These settings '
                  'are what let Rise Protocol actually wake you up — skip them and '
                  'alarms can silently fail to ring.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
              ],
              Expanded(
                child: status == null
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        itemCount: PermissionStep.all.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final step = PermissionStep.all[i];
                          return PermissionStepCard(
                            step: step,
                            granted: status[step.kind],
                            onResolve: () => _resolve(step),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: (status != null && (_allCriticalGranted || widget.isReview))
                    ? _finish
                    : null,
                style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                child: Text(widget.isReview
                    ? 'Done'
                    : (_allCriticalGranted ? 'Continue' : 'Grant the required permissions above')),
              ),
              if (!widget.isReview && status != null && !_allCriticalGranted) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _finish,
                    child: const Text('Skip for now'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
