import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// A frosted panel: blurs whatever sits behind it, then lays a translucent
/// [AppTokens.surface1] wash and a faint hairline over the top. Used for the
/// editor's save bar, bottom sheets, and overlays on the ringing screen.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.blur = 22,
    this.opacity = 0.7,
    this.borderRadius = AppTokens.cornerLg,
    this.bordered = true,
  });

  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius borderRadius;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.surface1.withOpacity(opacity),
            borderRadius: borderRadius,
            border: bordered
                ? Border.all(color: t.textPrimary.withOpacity(0.07))
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
