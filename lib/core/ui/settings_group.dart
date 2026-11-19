import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// An inset grouped list: one rounded [AppTokens.surface1] card holding
/// [SettingsRow]s separated by hairlines that start past the leading icon,
/// in the style of iOS Settings.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.surface1,
        borderRadius: AppTokens.cornerLg,
        border: Border.all(color: t.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: Divider(height: 1, color: t.hairline),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One row in a [SettingsGroup]: a tinted icon, a title, and either a value
/// with a chevron (when [onTap] is set) or a custom [trailing] widget.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String title;

  /// Short summary shown on the right, e.g. "Math · Hard · 3".
  final String? value;

  /// Replaces [value] and the chevron, e.g. an inline stepper or field.
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Defaults to the brand colour.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final color = iconColor ?? t.brand;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space12,
            vertical: AppTokens.space8,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: AppTokens.space12),
              Text(
                title,
                style: text.titleSmall?.copyWith(color: t.textPrimary),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: trailing ??
                    Text(
                      value ?? '',
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(
                        color: t.textSecondary,
                      ),
                    ),
              ),
              if (trailing == null && onTap != null) ...[
                const SizedBox(width: AppTokens.space4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: t.textFaint,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
