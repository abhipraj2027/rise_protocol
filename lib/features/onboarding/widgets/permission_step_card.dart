import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/gap.dart';
import '../permission_step.dart';

/// One row in the onboarding checklist: a status dot, the ask, why it
/// matters, and a Grant button until it's satisfied.
class PermissionStepCard extends StatelessWidget {
  const PermissionStepCard({
    super.key,
    required this.step,
    required this.granted,
    required this.onResolve,
  });

  final PermissionStep step;
  final bool? granted; // null while status is still loading
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final isGranted = granted == true;

    final (IconData icon, Color iconColor) = isGranted
        ? (Icons.check_circle_rounded, t.success)
        : step.critical
            ? (Icons.error_outline_rounded, t.danger)
            : (Icons.circle_outlined, t.textFaint);

    return AppCard(
      selected: isGranted,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const Gap.w(AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        step.title,
                        style: text.titleSmall?.copyWith(color: t.textPrimary),
                      ),
                    ),
                    if (!step.critical && !isGranted)
                      Text('OPTIONAL', style: text.labelSmall),
                  ],
                ),
                const Gap(AppTokens.space4),
                Text(step.description, style: text.bodySmall),
                if (!isGranted) ...[
                  const Gap(AppTokens.space12),
                  OutlinedButton(
                    onPressed: onResolve,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.space16,
                      ),
                    ),
                    child: const Text('Grant'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
