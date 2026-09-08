import 'package:flutter/material.dart';

import '../permission_step.dart';

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
    final theme = Theme.of(context);
    final isGranted = granted == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: isGranted
            ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isGranted
                ? Icons.check_circle
                : (step.critical ? Icons.error_outline : Icons.info_outline),
            color: isGranted
                ? theme.colorScheme.primary
                : (step.critical
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(step.title, style: theme.textTheme.titleSmall),
                    ),
                    if (!step.critical && !isGranted)
                      Text(
                        'RECOMMENDED',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 0.6,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  step.description,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (!isGranted) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: onResolve,
                    child: const Text('Fix this'),
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
