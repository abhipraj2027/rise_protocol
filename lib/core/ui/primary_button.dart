import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../theme/app_tokens.dart';

/// The one primary action on a screen: a filled amber button wrapped in an
/// amber glow, so the brand reads as a halo of light rather than a flat
/// block of colour. Use [FilledButton] directly for secondary actions.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final handler = onPressed == null
        ? null
        : () {
            HapticFeedback.selectionClick();
            onPressed!();
          };
    final button = icon == null
        ? FilledButton(onPressed: handler, child: Text(label))
        : FilledButton.icon(
            onPressed: handler,
            icon: Icon(icon),
            label: Text(label),
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppTokens.cornerMd,
        boxShadow: onPressed == null ? null : t.glow,
      ),
      child: button,
    );
  }
}
