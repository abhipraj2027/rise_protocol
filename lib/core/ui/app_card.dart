import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// The standard surface for grouped content: a rounded [AppTokens.surface1]
/// panel with consistent padding. Pass [onTap] to make it pressable (adds a
/// ripple clipped to the corner radius). Pass [selected] to draw the brand
/// hairline used for "this is the active choice" states.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppTokens.space16),
    this.selected = false,
    this.elevated = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool selected;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final decoration = BoxDecoration(
      color: t.surface1,
      borderRadius: AppTokens.cornerLg,
      border: Border.all(
        color: selected ? t.brand : t.hairline,
        width: selected ? 1.5 : 1,
      ),
      boxShadow: elevated ? t.shadowCard : null,
    );

    final content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: content);
    }

    return Material(
      color: Colors.transparent,
      borderRadius: AppTokens.cornerLg,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTokens.cornerLg,
          child: content,
        ),
      ),
    );
  }
}
