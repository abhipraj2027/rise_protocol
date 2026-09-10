import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'gap.dart';

/// A titled break between form/content sections. Optional [subtitle] for the
/// one-line "what this does" explainer, optional [trailing] for an action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: text.titleMedium)),
            if (trailing != null) trailing!,
          ],
        ),
        if (subtitle != null) ...[
          const Gap(AppTokens.space4),
          Text(subtitle!, style: text.bodySmall),
        ],
      ],
    );
  }
}
