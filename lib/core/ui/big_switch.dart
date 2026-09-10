import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';

/// A larger, springier on/off switch than the stock [Switch] — used on the
/// alarm row where toggling an alarm is the single most common action and
/// deserves to feel deliberate. Fires a selection haptic on change.
class BigSwitch extends StatelessWidget {
  const BigSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 56,
    this.height = 32,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onChanged != null;
    final knob = height - 8;

    return Semantics(
      toggled: value,
      container: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onChanged!(!value);
              }
            : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: AnimatedContainer(
            duration: AppTokens.motionBase,
            curve: AppTokens.easeStandard,
            width: width,
            height: height,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: value ? t.brand : t.surface2,
              borderRadius: BorderRadius.circular(height),
            ),
            child: AnimatedAlign(
              duration: AppTokens.motionBase,
              curve: AppTokens.easeEmphasized,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: knob,
                height: knob,
                decoration: BoxDecoration(
                  color: value ? t.onBrand : t.surface0,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
