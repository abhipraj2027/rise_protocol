import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/alarm_bridge.dart';
import '../../core/app_prefs.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/gap.dart';
import '../../core/ui/primary_button.dart';
import 'permission_step.dart';
import 'widgets/permission_step_card.dart';

/// Shown on first launch (see `_HomeBootstrap` in lib/main.dart), and
/// reachable again later from the alarm list's app bar — permissions can be
/// revoked by the user or the OS after the fact, so this isn't a one-time
/// gate, it's a page the user can always come back to and check.
class PermissionOnboardingScreen extends ConsumerStatefulWidget {
  const PermissionOnboardingScreen({
    super.key,
    this.isReview = false,
    this.onCompleted,
  });

  /// True when opened from the alarm list (already onboarded) rather than as
  /// the first-launch flow — changes the button label and skips writing the
  /// onboarding-complete flag again.
  final bool isReview;

  /// Set on the first-launch flow, where this screen is the home body rather
  /// than a pushed route: called instead of `Navigator.pop()` so the host
  /// can swap to the alarm list. Null in review mode (pop is correct there).
  final VoidCallback? onCompleted;

  @override
  ConsumerState<PermissionOnboardingScreen> createState() =>
      _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState
    extends ConsumerState<PermissionOnboardingScreen>
    with WidgetsBindingObserver {
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
    // them to and re-checks so the checklist reflects reality immediately.
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

  int get _grantedCount =>
      _status?.values.where((v) => v).length ?? 0;

  Future<void> _resolve(PermissionStep step) async {
    await step.resolve(ref.read(alarmBridgeProvider));
    await _refreshStatus();
  }

  Future<void> _finish() async {
    if (!widget.isReview) {
      await ref.read(appPrefsProvider).setOnboardingComplete(true);
    }
    if (!mounted) return;
    final onCompleted = widget.onCompleted;
    if (onCompleted != null) {
      onCompleted();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final status = _status;
    final total = PermissionStep.all.length;

    return Scaffold(
      appBar: widget.isReview ? AppBar(title: const Text('Permissions')) : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space20,
            AppTokens.space24,
            AppTokens.space20,
            AppTokens.space20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.isReview) ...[
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.brandMuted,
                    shape: BoxShape.circle,
                    boxShadow: t.glow,
                  ),
                  child: Icon(Icons.shield_outlined, color: t.brand, size: 28),
                ),
                const Gap(AppTokens.space20),
                Text(
                  'Let’s make sure it can wake you',
                  style: text.headlineSmall?.copyWith(color: t.textPrimary),
                ),
                const Gap(AppTokens.space8),
                Text(
                  'Android muzzles background apps by default. Three settings '
                  'are what let Rise Protocol ring through a locked, sleeping '
                  'phone — without them an alarm can silently no-show.',
                  style: text.bodyMedium,
                ),
                const Gap(AppTokens.space20),
                Text(
                  status == null
                      ? 'Checking…'
                      : '$_grantedCount of $total ready',
                  style: text.labelSmall?.copyWith(
                    color: _allCriticalGranted ? t.success : t.textFaint,
                  ),
                ),
                const Gap(AppTokens.space16),
              ],
              Expanded(
                child: status == null
                    ? Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: t.textFaint,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: total,
                        separatorBuilder: (_, __) =>
                            const Gap(AppTokens.space12),
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
              const Gap(AppTokens.space16),
              PrimaryButton(
                label: widget.isReview
                    ? 'Done'
                    : _allCriticalGranted
                        ? 'Continue'
                        : 'Grant the required ones above',
                onPressed:
                    (status != null && (_allCriticalGranted || widget.isReview))
                        ? _finish
                        : null,
              ),
              if (!widget.isReview && status != null && !_allCriticalGranted) ...[
                const Gap(AppTokens.space8),
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
