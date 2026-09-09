import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// The seven day pills used both in the alarm editor (interactive) and on
/// the alarm row (read-only, [readOnly] + smaller [size]).
///
/// Values follow `DateTime.weekday`: 1 = Monday … 7 = Sunday.
class WeekdaySelector extends StatelessWidget {
  const WeekdaySelector({
    super.key,
    required this.selected,
    this.onChanged,
    this.readOnly = false,
    this.size = 40,
  });

  final Set<int> selected;
  final ValueChanged<Set<int>>? onChanged;
  final bool readOnly;
  final double size;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (i) {
        final day = i + 1;
        final on = selected.contains(day);
        return Padding(
          padding: EdgeInsets.only(right: i == 6 ? 0 : size * 0.18),
          child: _Pip(
            label: _labels[i],
            on: on,
            size: size,
            onColor: t.brand,
            onText: t.onBrand,
            offColor: t.surface2,
            offText: t.textSecondary,
            onTap: readOnly || onChanged == null
                ? null
                : () {
                    final next = {...selected};
                    if (on) {
                      next.remove(day);
                    } else {
                      next.add(day);
                    }
                    onChanged!(next);
                  },
          ),
        );
      }),
    );
  }
}

class _Pip extends StatelessWidget {
  const _Pip({
    required this.label,
    required this.on,
    required this.size,
    required this.onColor,
    required this.onText,
    required this.offColor,
    required this.offText,
    this.onTap,
  });

  final String label;
  final bool on;
  final double size;
  final Color onColor;
  final Color onText;
  final Color offColor;
  final Color offText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final circle = AnimatedContainer(
      duration: AppTokens.motionFast,
      curve: AppTokens.easeStandard,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? onColor : offColor,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
          color: on ? onText : offText,
        ),
      ),
    );

    if (onTap == null) return circle;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: circle,
    );
  }
}
